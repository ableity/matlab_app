classdef showpic_smooth < matlab.apps.AppBase
    % Smooth replacement for showpic.mlapp.
    % Run with: showpic_smooth

    properties (Access = public)
        UIFigure matlab.ui.Figure
        MainGrid matlab.ui.container.GridLayout
        ControlPanel matlab.ui.container.Panel
        ViewPanel matlab.ui.container.Panel
        ViewGrid matlab.ui.container.GridLayout
        ImageAxes matlab.ui.control.UIAxes

        RecPathEdit matlab.ui.control.EditField
        PhotoPathEdit matlab.ui.control.EditField
        LoadButton matlab.ui.control.Button
        BrowseRecButton matlab.ui.control.Button
        BrowsePhotoButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button
        FitHeightCheckBox matlab.ui.control.CheckBox
        ColormapDropDown matlab.ui.control.DropDown

        RowScaleSlider matlab.ui.control.Slider
        ColScaleSlider matlab.ui.control.Slider
        RowScaleSpinner matlab.ui.control.Spinner
        ColScaleSpinner matlab.ui.control.Spinner
        RowOffsetSlider matlab.ui.control.Slider
        ColOffsetSlider matlab.ui.control.Slider
        MinColorSlider matlab.ui.control.Slider
        DualColorSlider matlab.ui.control.HTML
        MaxColorSlider matlab.ui.control.Slider
        MinColorSpinner matlab.ui.control.Spinner
        TransparencySpinner matlab.ui.control.Spinner
        MaxColorSpinner matlab.ui.control.Spinner
        AlphaSlider matlab.ui.control.Slider
        StatusLabel matlab.ui.control.Label
        MinLabel matlab.ui.control.Label
        MaxLabel matlab.ui.control.Label
    end

    properties (Access = private)
        PhotoOriginal uint8 = uint8.empty
        RecOriginal double = double.empty
        RecMin double = 0
        RecMax double = 1
        BaseRecRows double = 0
        BaseRecCols double = 0
        CurrentImage uint8 = uint8.empty
        IsLoaded logical = false
        IsUpdating logical = false
        IsDragging logical = false
        DragStartPoint double = [0, 0]
        DragStartRowOffset double = 0
        DragStartColOffset double = 0
        LastFolder char = ''
        BaseImage = []
        OverlayImage = []
        TransparencyValue double = 0
    end

    methods (Access = private)
        function loadData(app)
            try
                app.setStatus("正在加载数据...");

                photoPath = app.resolvePath(app.PhotoPathEdit.Value);
                recPath = app.resolvePath(app.RecPathEdit.Value);

                photo = imread(photoPath);
                app.PhotoOriginal = app.normalizePhoto(photo);

                recStruct = load(recPath);
                app.RecOriginal = app.pickNumericMatrix(recStruct);
                app.RecOriginal = double(app.RecOriginal);
                app.RecOriginal = squeeze(app.RecOriginal);
                if ~ismatrix(app.RecOriginal)
                    app.RecOriginal = app.RecOriginal(:, :, 1);
                end

                finiteVals = app.RecOriginal(isfinite(app.RecOriginal));
                if isempty(finiteVals)
                    error("重建图像里没有有效数值。");
                end
                app.RecMin = min(finiteVals(:));
                app.RecMax = max(finiteVals(:));
                if app.RecMax <= app.RecMin
                    app.RecMax = app.RecMin + eps(app.RecMin + 1);
                end

                recForSize = app.RecOriginal;
                if app.FitHeightCheckBox.Value
                    targetRows = size(app.PhotoOriginal, 1);
                    targetCols = max(1, floor(size(recForSize, 2) * targetRows / size(recForSize, 1)));
                    recForSize = imresize(recForSize, [targetRows, targetCols]);
                end

                app.BaseRecRows = size(recForSize, 1);
                app.BaseRecCols = size(recForSize, 2);
                app.RecOriginal = recForSize;

                app.IsLoaded = true;
                app.resetTransforms(false);
                app.configureColorControls();
                app.renderImage();
                app.setStatus("已加载: 照片 " + string(size(app.PhotoOriginal, 2)) + " x " + string(size(app.PhotoOriginal, 1)) + ...
                    ", 重建图 " + string(app.BaseRecCols) + " x " + string(app.BaseRecRows));
                app.configureColorSliderTicks();
            catch ME
                app.IsLoaded = false;
                app.setStatus("加载失败: " + ME.message);
                uialert(app.UIFigure, ME.message, "加载失败");
            end
        end

        function renderImage(app)
            if ~app.IsLoaded || app.IsUpdating
                return
            end

            app.IsUpdating = true;
            cleaner = onCleanup(@() setUpdatingFalse(app));

            rowScale = app.RowScaleSlider.Value;
            colScale = app.ColScaleSlider.Value;
            minColorValue = app.MinColorSlider.Value;
            visibleMask = isfinite(app.RecOriginal) & app.RecOriginal >= app.TransparencyValue;
            recRgb = app.grayToRgb(app.RecOriginal, app.ColormapDropDown.Value, ...
                minColorValue, app.MaxColorSlider.Value);
            recRgb = app.boostSaturation(recRgb, 1.5);

            photoRows = size(app.PhotoOriginal, 1);
            photoCols = size(app.PhotoOriginal, 2);
            if isempty(app.BaseImage) || ~isvalid(app.BaseImage)
                cla(app.ImageAxes);
                app.BaseImage = image(app.ImageAxes, 'CData', app.PhotoOriginal, ...
                    'XData', [1, photoCols], 'YData', [1, photoRows]);
                hold(app.ImageAxes, 'on');
                app.OverlayImage = image(app.ImageAxes, 'CData', recRgb);
                hold(app.ImageAxes, 'off');
            else
                app.BaseImage.CData = app.PhotoOriginal;
                app.BaseImage.XData = [1, photoCols];
                app.BaseImage.YData = [1, photoRows];
            end

            [centerRow, centerCol] = app.overlayCenter(app.RowOffsetSlider.Value, app.ColOffsetSlider.Value);
            halfRowSpan = (app.BaseRecRows - 1) * rowScale / 2;
            halfColSpan = (app.BaseRecCols - 1) * colScale / 2;
            app.OverlayImage.CData = recRgb;
            app.OverlayImage.AlphaData = app.AlphaSlider.Value * double(visibleMask);
            app.OverlayImage.XData = [centerCol - halfColSpan, centerCol + halfColSpan];
            app.OverlayImage.YData = [centerRow - halfRowSpan, centerRow + halfRowSpan];

            app.ImageAxes.XLim = [0.5, photoCols + 0.5];
            app.ImageAxes.YLim = [0.5, photoRows + 0.5];
            app.ImageAxes.DataAspectRatio = [1, 1, 1];
            drawnow limitrate

            function setUpdatingFalse(appObj)
                appObj.IsUpdating = false;
            end
        end

        function out = composeCurrentImage(app)
            out = app.PhotoOriginal;
            [targetRows, targetCols, dstR1, dstC1] = app.overlayGeometry( ...
                app.RowScaleSlider.Value, app.ColScaleSlider.Value, ...
                app.RowOffsetSlider.Value, app.ColOffsetSlider.Value);
            recScaled = imresize(app.RecOriginal, [targetRows, targetCols], "bilinear");
            minColorValue = app.MinColorSlider.Value;
            visibleMask = isfinite(recScaled) & recScaled >= app.TransparencyValue;
            recRgb = app.grayToRgb(recScaled, app.ColormapDropDown.Value, ...
                minColorValue, app.MaxColorSlider.Value);
            recRgb = app.boostSaturation(recRgb, 1.5);

            photoRows = size(out, 1);
            photoCols = size(out, 2);
            clippedR1 = max(1, dstR1);
            clippedC1 = max(1, dstC1);
            clippedR2 = min(photoRows, dstR1 + targetRows - 1);
            clippedC2 = min(photoCols, dstC1 + targetCols - 1);
            if clippedR1 > clippedR2 || clippedC1 > clippedC2
                return
            end

            srcR1 = clippedR1 - dstR1 + 1;
            srcC1 = clippedC1 - dstC1 + 1;
            srcR2 = srcR1 + clippedR2 - clippedR1;
            srcC2 = srcC1 + clippedC2 - clippedC1;
            patch = recRgb(srcR1:srcR2, srcC1:srcC2, :);
            patchMask = visibleMask(srcR1:srcR2, srcC1:srcC2);
            base = out(clippedR1:clippedR2, clippedC1:clippedC2, :);
            alpha = app.AlphaSlider.Value * double(patchMask);
            out(clippedR1:clippedR2, clippedC1:clippedC2, :) = uint8( ...
                double(base) .* (1 - alpha) + double(patch) .* alpha);
        end

        function configureColorControls(app)
            app.MinLabel.Text = "最小: " + num2str(app.RecMin, "%.6g");
            app.MaxLabel.Text = "最大: " + num2str(app.RecMax, "%.6g");

            lower = min(0, app.RecMin);
            upper = app.RecMax;
            app.MinColorSlider.Limits = [lower, upper];
            app.MaxColorSlider.Limits = [lower, upper];
            app.MinColorSlider.Value = lower;
            app.MaxColorSlider.Value = upper;
            app.TransparencyValue = lower + 0.1 * (upper - lower);

            app.MinColorSpinner.Limits = [-Inf, Inf];
            app.TransparencySpinner.Limits = [-Inf, Inf];
            app.MaxColorSpinner.Limits = [-Inf, Inf];
            app.MinColorSpinner.Value = lower;
            app.TransparencySpinner.Value = app.TransparencyValue;
            app.MaxColorSpinner.Value = upper;

            step = max((upper - lower) / 100, eps(upper + 1));
            app.MinColorSpinner.Step = step;
            app.TransparencySpinner.Step = step;
            app.MaxColorSpinner.Step = step;
            app.configureColorSliderTicks();
            app.syncDualColorSlider();
        end

        function resetTransforms(app, doRender)
            app.RowScaleSlider.Value = 1;
            app.ColScaleSlider.Value = 1;
            app.RowScaleSpinner.Value = 1;
            app.ColScaleSpinner.Value = 1;
            app.RowOffsetSlider.Value = 0;
            app.ColOffsetSlider.Value = 0;
            app.AlphaSlider.Value = 1;
            if nargin < 2 || doRender
                app.renderImage();
            end
        end

        function colorChanged(app, sourceName, value)
            if ~app.IsLoaded
                return
            end

            minVal = app.MinColorSlider.Value;
            maxVal = app.MaxColorSlider.Value;
            switch sourceName
                case "min"
                    minVal = value;
                    if minVal > maxVal
                        maxVal = minVal;
                    end
                    if minVal > app.TransparencyValue
                        app.TransparencyValue = minVal;
                    end
                case "max"
                    maxVal = max(value, app.TransparencyValue);
            end

            app.extendSliderLimit(app.MinColorSlider, minVal);
            app.extendSliderLimit(app.MaxColorSlider, maxVal);
            app.MinColorSlider.Value = minVal;
            app.MaxColorSlider.Value = maxVal;
            app.configureColorSliderTicks();
            app.MinColorSpinner.Value = minVal;
            app.TransparencySpinner.Value = app.TransparencyValue;
            app.MaxColorSpinner.Value = maxVal;
            app.syncDualColorSlider();
            app.renderImage();
            app.configureColorSliderTicks();
        end

        function transparencyChanged(app, value)
            if ~app.IsLoaded
                return
            end
            minVal = app.MinColorSlider.Value;
            maxVal = app.MaxColorSlider.Value;
            app.TransparencyValue = min(value, maxVal);
            if app.TransparencyValue < minVal
                minVal = app.TransparencyValue;
                app.extendSliderLimit(app.MinColorSlider, minVal);
                app.extendSliderLimit(app.MaxColorSlider, minVal);
                app.MinColorSlider.Value = minVal;
                app.MinColorSpinner.Value = minVal;
                app.configureColorSliderTicks();
            end
            app.TransparencySpinner.Value = app.TransparencyValue;
            app.syncDualColorSlider();
            app.renderImage();
        end

        function dualColorChanged(app, source)
            if ~app.IsLoaded || isempty(source.Data) || ~isstruct(source.Data) || ...
                    ~isfield(source.Data, 'colorMin') || ~isfield(source.Data, 'transparency')
                return
            end

            minVal = double(source.Data.colorMin);
            transparentVal = double(source.Data.transparency);
            maxVal = app.MaxColorSlider.Value;
            minVal = app.clamp(minVal, app.MinColorSlider.Limits(1), maxVal);
            transparentVal = app.clamp(transparentVal, app.MinColorSlider.Limits(1), maxVal);
            sourceName = "";
            if isfield(source.Data, 'source')
                sourceName = string(source.Data.source);
            end
            if transparentVal < minVal
                if sourceName == "transparent"
                    minVal = transparentVal;
                else
                    transparentVal = minVal;
                end
            end

            app.MinColorSlider.Value = minVal;
            app.MinColorSpinner.Value = minVal;
            app.TransparencyValue = transparentVal;
            app.TransparencySpinner.Value = transparentVal;
            app.syncDualColorSlider();
            app.renderImage();
        end

        function syncDualColorSlider(app)
            if isempty(app.DualColorSlider) || ~isvalid(app.DualColorSlider)
                return
            end
            lowerLimit = app.MinColorSlider.Limits(1);
            upperLimit = max([app.MinColorSlider.Limits(2), app.MaxColorSlider.Limits(2), ...
                lowerLimit + eps(lowerLimit + 1)]);
            sliderData = struct( ...
                'minimum', lowerLimit, 'maximum', upperLimit, ...
                'allowedMaximum', app.MaxColorSlider.Value, ...
                'colorMin', app.MinColorSlider.Value, ...
                'transparency', app.TransparencyValue, 'source', 'matlab');
            app.DualColorSlider.Data = sliderData;
            drawnow limitrate
            try
                sendEventToHTMLSource(app.DualColorSlider, 'UpdateSlider', sliderData);
            catch
                % The HTML source can still be loading during app creation.
            end
        end

        function exportImage(app)
            if ~app.IsLoaded
                uialert(app.UIFigure, "请先加载数据。", "未加载");
                return
            end

            app.CurrentImage = app.composeCurrentImage();
            figure("Name", "配准图像预览");
            imshow(app.CurrentImage);
            colormap(app.ColormapDropDown.Value);
            colorbar("Ticks", linspace(0, 1, 5), ...
                "TickLabels", compose("%.4g", linspace(app.MinColorSlider.Value, app.MaxColorSlider.Value, 5)));
        end

        function browsePhoto(app)
            [file, folder] = uigetfile( ...
                {"*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp", "图片文件"; "*.*", "所有文件"}, ...
                "选择动物照片", app.initialFolder());
            if isequal(file, 0)
                return
            end
            app.LastFolder = folder;
            app.PhotoPathEdit.Value = fullfile(folder, file);
        end

        function browseRec(app)
            [file, folder] = uigetfile( ...
                {"*.mat", "MAT 文件"; "*.*", "所有文件"}, ...
                "选择重建图像 MAT 文件", app.initialFolder());
            if isequal(file, 0)
                return
            end
            app.LastFolder = folder;
            app.RecPathEdit.Value = fullfile(folder, file);
        end

        function folder = initialFolder(app)
            if ~isempty(app.LastFolder) && isfolder(app.LastFolder)
                folder = app.LastFolder;
            else
                folder = fileparts(mfilename("fullpath"));
            end
        end

        function setStatus(app, message)
            app.StatusLabel.Text = char(message);
            drawnow limitrate
        end

        function path = resolvePath(~, pathText)
            path = char(strtrim(string(pathText)));
            if isempty(path)
                error("文件路径不能为空。");
            end
            if ~isfile(path)
                candidate = fullfile(fileparts(mfilename("fullpath")), path);
                if isfile(candidate)
                    path = candidate;
                end
            end
            if ~isfile(path)
                error("找不到文件: %s", path);
            end
        end

        function photo = normalizePhoto(~, photo)
            if ismatrix(photo)
                photo = repmat(photo, 1, 1, 3);
            elseif size(photo, 3) > 3
                photo = photo(:, :, 1:3);
            end

            if isa(photo, "uint8")
                return
            elseif isa(photo, "uint16")
                photo = im2uint8(photo);
            else
                photo = im2uint8(mat2gray(photo));
            end
        end

        function rec = pickNumericMatrix(~, recStruct)
            names = fieldnames(recStruct);
            for k = 1:numel(names)
                value = recStruct.(names{k});
                if isnumeric(value) && ~isempty(value)
                    rec = value;
                    return
                end
            end
            error("MAT 文件中没有找到数值矩阵。");
        end

        function rgb = grayToRgb(app, img, cmapName, minValue, maxValue)
            if maxValue <= minValue
                maxValue = minValue + eps(minValue + 1);
            end

            img = double(img);
            img(~isfinite(img)) = minValue;
            scaled = (img - minValue) ./ (maxValue - minValue);
            scaled = min(max(scaled, 0), 1);
            idx = uint16(round(scaled * 255)) + 1;

            cmap = app.getColormap(cmapName);
            rgb = zeros([size(img), 3], "uint8");
            rgb(:, :, 1) = uint8(255 * reshape(cmap(idx, 1), size(img)));
            rgb(:, :, 2) = uint8(255 * reshape(cmap(idx, 2), size(img)));
            rgb(:, :, 3) = uint8(255 * reshape(cmap(idx, 3), size(img)));
        end

        function cmap = getColormap(~, cmapName)
            try
                cmap = feval(char(cmapName), 256);
            catch
                cmap = jet(256);
            end
            cmap = min(max(double(cmap), 0), 1);
        end

        function rgb = boostSaturation(~, rgb, factor)
            hsvImg = rgb2hsv(im2double(rgb));
            hsvImg(:, :, 2) = min(hsvImg(:, :, 2) * factor, 1);
            rgb = im2uint8(hsv2rgb(hsvImg));
        end

        function extendSliderLimit(~, slider, value)
            limits = slider.Limits;
            if value < limits(1)
                limits(1) = value;
            end
            if value > limits(2)
                limits(2) = value;
            end
            if limits(1) == limits(2)
                limits(2) = limits(1) + eps(limits(1) + 1);
            end
            slider.Limits = limits;
        end

        function beginImageDrag(app)
            if ~app.IsLoaded || ~app.pointerIsInViewPanel()
                return
            end

            app.IsDragging = true;
            [photoRow, photoCol] = app.pointerPhotoPoint();
            app.DragStartPoint = [photoCol, photoRow];
            app.DragStartRowOffset = app.RowOffsetSlider.Value;
            app.DragStartColOffset = app.ColOffsetSlider.Value;
        end

        function dragImage(app)
            if ~app.IsDragging || ~app.IsLoaded
                return
            end

            [photoRow, photoCol] = app.pointerPhotoPoint();
            deltaCols = photoCol - app.DragStartPoint(1);
            deltaRows = photoRow - app.DragStartPoint(2);
            photoRows = size(app.PhotoOriginal, 1);
            photoCols = size(app.PhotoOriginal, 2);

            rowValue = app.clamp(app.DragStartRowOffset + deltaRows / photoRows, ...
                app.RowOffsetSlider.Limits(1), app.RowOffsetSlider.Limits(2));
            colValue = app.clamp(app.DragStartColOffset + deltaCols / photoCols, ...
                app.ColOffsetSlider.Limits(1), app.ColOffsetSlider.Limits(2));

            app.RowOffsetSlider.Value = rowValue;
            app.ColOffsetSlider.Value = colValue;
            app.renderImage();
        end

        function scaleChanged(app, sourceName, value)
            value = max(value, realmin);
            if strcmp(sourceName, "row")
                app.expandScaleLimit(app.RowScaleSlider, value);
                app.RowScaleSlider.Value = value;
                app.RowScaleSpinner.Value = value;
            else
                app.expandScaleLimit(app.ColScaleSlider, value);
                app.ColScaleSlider.Value = value;
                app.ColScaleSpinner.Value = value;
            end
            app.renderImage();
        end

        function scaleChanging(app, sourceName, value)
            app.scaleChanged(sourceName, value);
        end

        function endImageDrag(app)
            app.IsDragging = false;
        end

        function scrollImageScale(app, event)
            if ~app.IsLoaded || ~app.pointerIsInViewPanel()
                return
            end

            [mouseRow, mouseCol] = app.pointerPhotoPoint();
            photoRows = size(app.PhotoOriginal, 1);
            photoCols = size(app.PhotoOriginal, 2);

            oldRowScale = app.RowScaleSlider.Value;
            oldColScale = app.ColScaleSlider.Value;
            [oldCenterRow, oldCenterCol] = app.overlayCenter( ...
                app.RowOffsetSlider.Value, app.ColOffsetSlider.Value);
            anchorRecRow = (mouseRow - oldCenterRow) / oldRowScale + (app.BaseRecRows + 1) / 2;
            anchorRecCol = (mouseCol - oldCenterCol) / oldColScale + (app.BaseRecCols + 1) / 2;

            zoomFactor = app.limitedEqualZoomFactor(1.08 ^ (-event.VerticalScrollCount));
            rowValue = oldRowScale * zoomFactor;
            colValue = oldColScale * zoomFactor;
            newCenterRow = mouseRow - (anchorRecRow - (app.BaseRecRows + 1) / 2) * rowValue;
            newCenterCol = mouseCol - (anchorRecCol - (app.BaseRecCols + 1) / 2) * colValue;
            rowOffset = (newCenterRow - (photoRows + 1) / 2) / photoRows;
            colOffset = (newCenterCol - (photoCols + 1) / 2) / photoCols;
            app.expandSymmetricLimit(app.RowOffsetSlider, rowOffset);
            app.expandSymmetricLimit(app.ColOffsetSlider, colOffset);

            app.RowScaleSlider.Value = rowValue;
            app.ColScaleSlider.Value = colValue;
            app.RowScaleSpinner.Value = rowValue;
            app.ColScaleSpinner.Value = colValue;
            app.RowOffsetSlider.Value = rowOffset;
            app.ColOffsetSlider.Value = colOffset;
            app.renderImage();
        end

        function zoomFactor = limitedEqualZoomFactor(app, requestedFactor)
            rowValue = app.RowScaleSlider.Value;
            colValue = app.ColScaleSlider.Value;

            if requestedFactor >= 1
                zoomFactor = requestedFactor;
            else
                minFactor = max(realmin / rowValue, realmin / colValue);
                zoomFactor = max(requestedFactor, minFactor);
            end
            app.expandScaleLimit(app.RowScaleSlider, rowValue * zoomFactor);
            app.expandScaleLimit(app.ColScaleSlider, colValue * zoomFactor);
        end

        function expandScaleLimit(app, slider, requiredValue)
            requiredValue = max(requiredValue, realmin);
            limits = slider.Limits;
            changed = false;
            if requiredValue <= 1.02 * limits(1)
                limits(1) = max(realmin, min(requiredValue / 2, limits(1) / 2));
                changed = true;
            end
            if requiredValue >= 0.98 * limits(2)
                limits(2) = max([requiredValue * 1.5, limits(2) * 2, limits(1) + eps]);
                changed = true;
            end
            if changed
                slider.Limits = limits;
                app.configureDynamicScaleTicks(slider);
            end
        end

        function expandSymmetricLimit(app, slider, requiredValue)
            limits = slider.Limits;
            if requiredValue < limits(1) || requiredValue > limits(2)
                extent = max([abs(requiredValue) * 1.25, abs(limits), 1]);
                slider.Limits = [-extent, extent];
                app.configureSliderTicks(slider, slider.Limits);
            end
        end

        function configureDynamicScaleTicks(~, slider)
            limits = slider.Limits;
            ticks = linspace(limits(1), limits(2), 5);
            slider.MajorTicks = ticks;
            slider.MajorTickLabels = compose('%.3g', ticks);
            slider.MinorTicks = [];
        end

        function [targetRows, targetCols, dstR1, dstC1] = overlayGeometry(app, rowScale, colScale, rowOffset, colOffset)
            photoRows = size(app.PhotoOriginal, 1);
            photoCols = size(app.PhotoOriginal, 2);
            targetRows = max(1, floor(app.BaseRecRows * rowScale));
            targetCols = max(1, floor(app.BaseRecCols * colScale));
            offsetRows = round(photoRows * rowOffset);
            offsetCols = round(photoCols * colOffset);
            dstR1 = round((photoRows - targetRows) / 2) + 1 + offsetRows;
            dstC1 = round((photoCols - targetCols) / 2) + 1 + offsetCols;
        end

        function tf = pointerIsInViewPanel(app)
            point = app.UIFigure.CurrentPoint;
            imagePos = getpixelposition(app.ImageAxes, true);
            tf = point(1) >= imagePos(1) && point(1) <= imagePos(1) + imagePos(3) && ...
                point(2) >= imagePos(2) && point(2) <= imagePos(2) + imagePos(4);
            if tf && app.IsLoaded
                [photoRow, photoCol] = app.pointerPhotoPoint();
                tf = photoCol >= 0.5 && photoCol <= size(app.PhotoOriginal, 2) + 0.5 && ...
                    photoRow >= 0.5 && photoRow <= size(app.PhotoOriginal, 1) + 0.5;
            end
        end

        function [centerRow, centerCol] = overlayCenter(app, rowOffset, colOffset)
            photoRows = size(app.PhotoOriginal, 1);
            photoCols = size(app.PhotoOriginal, 2);
            centerRow = (photoRows + 1) / 2 + photoRows * rowOffset;
            centerCol = (photoCols + 1) / 2 + photoCols * colOffset;
        end

        function [photoRow, photoCol] = pointerPhotoPoint(app)
            point = app.ImageAxes.CurrentPoint;
            photoCol = point(1, 1);
            photoRow = point(1, 2);
        end

        function value = clamp(~, value, minValue, maxValue)
            value = min(max(value, minValue), maxValue);
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = '动物图像与 MPI 图像配准';
            app.UIFigure.Position = [100, 100, 1180, 780];
            app.UIFigure.WindowButtonDownFcn = @(~, ~) app.beginImageDrag();
            app.UIFigure.WindowButtonMotionFcn = @(~, ~) app.dragImage();
            app.UIFigure.WindowButtonUpFcn = @(~, ~) app.endImageDrag();
            app.UIFigure.WindowScrollWheelFcn = @(~, event) app.scrollImageScale(event);

            app.MainGrid = uigridlayout(app.UIFigure, [1, 2]);
            app.MainGrid.ColumnWidth = {410, '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.Padding = [0, 0, 0, 0];
            app.MainGrid.ColumnSpacing = 0;

            app.ControlPanel = uipanel(app.MainGrid, 'Title', '配准控制');
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 1;

            controlGrid = uigridlayout(app.ControlPanel, [21, 3]);
            controlGrid.RowHeight = {24, 28, 28, 28, 30, 24, 22, 40, 22, 40, 22, 40, 22, 40, 22, 40, 22, 42, 22, 42, '1x'};
            controlGrid.ColumnWidth = {82, '1x', 112};
            controlGrid.Padding = [14, 10, 14, 10];
            controlGrid.RowSpacing = 5;
            controlGrid.ColumnSpacing = 8;

            titleLabel = uilabel(controlGrid, 'Text', '动物图像与 MPI 图像叠加', 'FontWeight', 'bold');
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1, 3];

            label = uilabel(controlGrid, 'Text', '重建图像');
            label.Layout.Row = 2;
            label.Layout.Column = 1;
            app.RecPathEdit = uieditfield(controlGrid, 'text', 'Value', 'img.mat');
            app.RecPathEdit.Layout.Row = 2;
            app.RecPathEdit.Layout.Column = 2;
            app.BrowseRecButton = uibutton(controlGrid, 'push', 'Text', '浏览', ...
                "ButtonPushedFcn", @(~, ~) app.browseRec());
            app.BrowseRecButton.Layout.Row = 2;
            app.BrowseRecButton.Layout.Column = 3;

            label = uilabel(controlGrid, 'Text', '动物照片');
            label.Layout.Row = 3;
            label.Layout.Column = 1;
            app.PhotoPathEdit = uieditfield(controlGrid, 'text', 'Value', 'mouse.jpg');
            app.PhotoPathEdit.Layout.Row = 3;
            app.PhotoPathEdit.Layout.Column = 2;
            app.BrowsePhotoButton = uibutton(controlGrid, 'push', 'Text', '浏览', ...
                "ButtonPushedFcn", @(~, ~) app.browsePhoto());
            app.BrowsePhotoButton.Layout.Row = 3;
            app.BrowsePhotoButton.Layout.Column = 3;

            app.FitHeightCheckBox = uicheckbox(controlGrid, 'Text', '加载时匹配重建图高度', 'Value', true);
            app.FitHeightCheckBox.Layout.Row = 4;
            app.FitHeightCheckBox.Layout.Column = [1, 2];

            app.ColormapDropDown = uidropdown(controlGrid, ...
                'Items', {'jet', 'turbo', 'parula', 'hot', 'gray', 'hsv'}, ...
                'Value', 'jet', 'ValueChangedFcn', @(~, ~) app.renderImage());
            app.ColormapDropDown.Layout.Row = 4;
            app.ColormapDropDown.Layout.Column = 3;

            app.LoadButton = uibutton(controlGrid, 'push', 'Text', '加载', ...
                "ButtonPushedFcn", @(~, ~) app.loadData());
            app.LoadButton.Layout.Row = 5;
            app.LoadButton.Layout.Column = 1;
            app.ResetButton = uibutton(controlGrid, 'push', 'Text', '重置', ...
                "ButtonPushedFcn", @(~, ~) app.resetTransforms(true));
            app.ResetButton.Layout.Row = 5;
            app.ResetButton.Layout.Column = 2;

            app.ExportButton = uibutton(controlGrid, 'push', 'Text', '预览', ...
                "ButtonPushedFcn", @(~, ~) app.exportImage());
            app.ExportButton.Layout.Row = 5;
            app.ExportButton.Layout.Column = 3;

            app.MinLabel = uilabel(controlGrid, 'Text', '最小:');
            app.MinLabel.Layout.Row = 6;
            app.MinLabel.Layout.Column = 1;
            app.MaxLabel = uilabel(controlGrid, 'Text', '最大:', 'HorizontalAlignment', 'right');
            app.MaxLabel.Layout.Row = 6;
            app.MaxLabel.Layout.Column = 3;

            app.StatusLabel = uilabel(controlGrid, 'Text', '未加载', 'FontColor', [0.3, 0.3, 0.3]);
            app.StatusLabel.Layout.Row = 6;
            app.StatusLabel.Layout.Column = 2;

            app.RowScaleSlider = app.addScaleControl(controlGrid, 8, "纵向缩放", "row", [0.1, 1.5], 1);
            app.ColScaleSlider = app.addScaleControl(controlGrid, 10, "横向缩放", "col", [0.1, 1.5], 1);
            app.RowOffsetSlider = app.addSlider(controlGrid, 12, "垂直位置", [-1, 1], 0);
            app.ColOffsetSlider = app.addSlider(controlGrid, 14, "水平位置", [-1, 1], 0);
            app.AlphaSlider = app.addSlider(controlGrid, 16, "叠加强度", [0, 1], 1);

            minControls = uigridlayout(controlGrid, [1, 4]);
            minControls.Layout.Row = 17;
            minControls.Layout.Column = [1, 3];
            minControls.Padding = [0, 0, 0, 0];
            minControls.RowSpacing = 0;
            minControls.ColumnSpacing = 5;
            minControls.ColumnWidth = {60, '1x', 70, '1x'};

            label = uilabel(minControls, 'Text', '颜色下限', 'HorizontalAlignment', 'right');
            label.Layout.Column = 1;
            app.MinColorSpinner = uispinner(minControls, ...
                "ValueChangedFcn", @(src, ~) app.colorChanged("min", src.Value), ...
                "ValueChangingFcn", @(~, event) app.colorChanged("min", event.Value));
            app.MinColorSpinner.Layout.Column = 2;
            label = uilabel(minControls, 'Text', '透明阈值', 'HorizontalAlignment', 'right');
            label.Layout.Column = 3;
            app.TransparencySpinner = uispinner(minControls, ...
                "ValueChangedFcn", @(src, ~) app.transparencyChanged(src.Value), ...
                "ValueChangingFcn", @(~, event) app.transparencyChanged(event.Value));
            app.TransparencySpinner.Layout.Column = 4;

            app.MinColorSlider = uislider(controlGrid, 'Visible', 'off');
            app.MinColorSlider.Layout.Row = 18;
            app.MinColorSlider.Layout.Column = [1, 3];
            app.DualColorSlider = uihtml(controlGrid, ...
                'HTMLSource', fullfile(fileparts(mfilename('fullpath')), 'showpic_dual_slider.html'), ...
                'DataChangedFcn', @(src, ~) app.dualColorChanged(src));
            app.DualColorSlider.Layout.Row = 18;
            app.DualColorSlider.Layout.Column = [1, 3];
            app.DualColorSlider.Data = struct('minimum', 0, 'maximum', 1, ...
                'colorMin', 0, 'transparency', 0, 'source', 'matlab');

            label = uilabel(controlGrid, 'Text', '颜色上限', 'HorizontalAlignment', 'center');
            label.Layout.Row = 19;
            label.Layout.Column = [1, 2];
            app.MaxColorSpinner = uispinner(controlGrid, "ValueChangedFcn", @(src, ~) app.colorChanged("max", src.Value), ...
                "ValueChangingFcn", @(~, event) app.colorChanged("max", event.Value));
            app.MaxColorSpinner.Layout.Row = 19;
            app.MaxColorSpinner.Layout.Column = 3;
            app.MaxColorSlider = uislider(controlGrid, "ValueChangedFcn", @(src, ~) app.colorChanged("max", src.Value), ...
                "ValueChangingFcn", @(~, event) app.colorChanged("max", event.Value));
            app.MaxColorSlider.Layout.Row = 20;
            app.MaxColorSlider.Layout.Column = [1, 3];

            creditLabel = uilabel(controlGrid, 'Text', '由 lilei 开发', ...
                'FontColor', [0.4, 0.4, 0.4], 'VerticalAlignment', 'bottom');
            creditLabel.Layout.Row = 21;
            creditLabel.Layout.Column = [1, 3];

            app.ViewPanel = uipanel(app.MainGrid, 'BorderType', 'none');
            app.ViewPanel.Layout.Row = 1;
            app.ViewPanel.Layout.Column = 2;

            app.ViewGrid = uigridlayout(app.ViewPanel, [1, 1]);
            app.ViewGrid.Padding = [10, 10, 10, 10];
            app.ImageAxes = uiaxes(app.ViewGrid);
            app.ImageAxes.Layout.Row = 1;
            app.ImageAxes.Layout.Column = 1;
            app.ImageAxes.XTick = [];
            app.ImageAxes.YTick = [];
            app.ImageAxes.XColor = 'none';
            app.ImageAxes.YColor = 'none';
            app.ImageAxes.Box = 'on';
            app.ImageAxes.YDir = 'reverse';
            app.ImageAxes.Toolbar.Visible = 'off';
            app.ImageAxes.Interactions = [];

            app.UIFigure.Visible = 'on';
        end

        function slider = addScaleControl(app, parent, row, labelText, sourceName, limits, value)
            label = uilabel(parent, 'Text', labelText, 'HorizontalAlignment', 'center');
            label.Layout.Row = row - 1;
            label.Layout.Column = [1, 2];

            spinner = uispinner(parent, 'Limits', [realmin, Inf], 'Value', value, 'Step', 0.01, ...
                "ValueChangedFcn", @(src, ~) app.scaleChanged(sourceName, src.Value), ...
                "ValueChangingFcn", @(~, event) app.scaleChanging(sourceName, event.Value));
            spinner.Layout.Row = row - 1;
            spinner.Layout.Column = 3;

            slider = uislider(parent, 'Limits', limits, 'Value', value, ...
                "ValueChangedFcn", @(src, ~) app.scaleChanged(sourceName, src.Value), ...
                "ValueChangingFcn", @(src, event) app.scaleChanging(sourceName, event.Value));
            app.configureSliderTicks(slider, limits);
            slider.Layout.Row = row;
            slider.Layout.Column = [1, 3];

            if strcmp(sourceName, "row")
                app.RowScaleSpinner = spinner;
            else
                app.ColScaleSpinner = spinner;
            end
        end

        function slider = addSlider(app, parent, row, labelText, limits, value)
            label = uilabel(parent, 'Text', labelText, 'HorizontalAlignment', 'center');
            label.Layout.Row = row - 1;
            label.Layout.Column = [1, 3];
            slider = uislider(parent, 'Limits', limits, 'Value', value, ...
                "ValueChangedFcn", @(~, ~) app.renderImage(), ...
                "ValueChangingFcn", @(src, event) app.sliderChanging(src, event.Value));
            app.configureSliderTicks(slider, limits);
            slider.Layout.Row = row;
            slider.Layout.Column = [1, 3];
        end

        function configureSliderTicks(~, slider, limits)
            if isequal(limits, [0.1, 1.5])
                slider.MajorTicks = [0.1, 0.5, 1.0, 1.5];
                slider.MajorTickLabels = {'0.1', '0.5', '1', '1.5'};
            elseif isequal(limits, [-1, 1])
                slider.MajorTicks = [-1, -0.5, 0, 0.5, 1];
                slider.MajorTickLabels = {'-1', '-0.5', '0', '0.5', '1'};
            elseif isequal(limits, [0, 2])
                slider.MajorTicks = [0, 0.5, 1, 1.5, 2];
                slider.MajorTickLabels = {'0', '0.5', '1', '1.5', '2'};
            elseif isequal(limits, [0, 1])
                slider.MajorTicks = [0, 0.25, 0.5, 0.75, 1];
                slider.MajorTickLabels = {'0', '0.25', '0.5', '0.75', '1'};
            end
            slider.MinorTicks = [];
        end

        function configureColorSliderTicks(app)
            limits = [min(app.MinColorSlider.Limits(1), app.MaxColorSlider.Limits(1)), ...
                max(app.MinColorSlider.Limits(2), app.MaxColorSlider.Limits(2))];
            if limits(2) <= limits(1)
                limits(2) = limits(1) + eps(limits(1) + 1);
            end

            app.MinColorSlider.Limits = limits;
            app.MinColorSlider.MajorTicks = [];
            app.MinColorSlider.MinorTicks = [];

            app.MaxColorSlider.Limits = limits;
            app.MaxColorSlider.MajorTicks = [];
            app.MaxColorSlider.MinorTicks = [];
        end

        function sliderChanging(app, slider, value)
            slider.Value = value;
            app.renderImage();
        end
    end

    methods (Access = public)
        function app = showpic_smooth
            createComponents(app);
            registerApp(app, app.UIFigure);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
