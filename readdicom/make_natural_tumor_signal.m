function tumorSignal = make_natural_tumor_signal(inputPngPath, outputMatFile)
%MAKE_NATURAL_TUMOR_SIGNAL Create one natural tumor-like signal matrix.
%
% Usage:
%   tumorSignal = make_natural_tumor_signal('E:\MPS_DATA\猴脑干细胞\162827_1.png');
%   tumorSignal = make_natural_tumor_signal(inputPngPath, outputMatFile);
%
% Input:
%   inputPngPath - one PNG mask path.
%
% Output:
%   tumorSignal - a 2-D double matrix with the same size as the input PNG.
%                 Outside the tumor is 0. Inside the tumor is in [0, 1],
%                 with bright center and darker boundary.
%
% If outputMatFile is provided, it saves one variable named tumorSignal.

if nargin < 1 || isempty(inputPngPath)
    error('Please provide one PNG file path, for example: make_natural_tumor_signal(''E:\path\162827_1.png'')');
end

if nargin < 2
    outputMatFile = '';
end

rng(20260702);

mask = read_mask(inputPngPath);
tumorSignal = mask_to_natural_signal(mask);

if ~isempty(outputMatFile)
    save(outputMatFile, 'tumorSignal');
    fprintf('Saved 2-D matrix tumorSignal to:\n%s\n', outputMatFile);
end
end

function mask = read_mask(filePath)
if ~isfile(filePath)
    error('PNG file does not exist: %s', filePath);
end

img = imread(filePath);

if ndims(img) == 3
    img = rgb2gray(img);
end

img = mat2gray(img);

if max(img(:)) == min(img(:))
    mask = false(size(img));
    return
end

level = graythresh(img);
mask = img > level;

mask = imfill(mask, 'holes');
mask = bwareaopen(mask, max(3, round(numel(mask) * 0.0005)));
mask = imclose(mask, strel('disk', 2));
end

function signal = mask_to_natural_signal(mask)
signal = zeros(size(mask));

if ~any(mask(:))
    return
end

distMap = bwdist(~mask);
distMap = distMap ./ max(distMap(:));
core = distMap .^ 0.65;

noiseA = smooth_noise(size(mask), 10);
noiseB = smooth_noise(size(mask), 28);
texture = 0.16 * noiseA + 0.10 * noiseB;

[yy, xx] = ndgrid(1:size(mask, 1), 1:size(mask, 2));
[rows, cols] = find(mask);
centerRow = mean(rows);
centerCol = mean(cols);
radius = max(sqrt((rows - centerRow).^2 + (cols - centerCol).^2));

lobe = zeros(size(mask));
for k = 1:2
    angle = 2 * pi * rand();
    offset = 0.18 * radius * rand();
    lobeRow = centerRow + offset * sin(angle);
    lobeCol = centerCol + offset * cos(angle);
    sigma = max(2, radius * (0.35 + 0.15 * rand()));
    lobe = lobe + exp(-((yy - lobeRow).^2 + (xx - lobeCol).^2) ./ (2 * sigma^2));
end
lobe = mat2gray(lobe);

inside = 0.72 * core + 0.18 * lobe + texture;
inside = imgaussfilt(inside, 1.2);
inside(~mask) = 0;

values = inside(mask);
low = min(values);
high = max(values);
if high > low
    inside(mask) = (inside(mask) - low) ./ (high - low);
end

inside(mask) = 0.08 + 0.92 * inside(mask);
inside(~mask) = 0;

signal = inside;
end

function noise = smooth_noise(sz, sigma)
noise = randn(sz);
noise = imgaussfilt(noise, sigma);
noise = mat2gray(noise) - 0.5;
end
