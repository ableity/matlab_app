function dicom_3plane_viewer
%DICOM_3PLANE_VIEWER Three-plane DICOM volume viewer.
%
% Run in MATLAB:
%   cd('E:\MPS_DATA\...')
%   dicom_3plane_viewer

app = struct();
app.volume = [];
app.allInfoCells = {};
app.allFilePaths = {};
app.currentInfoCells = {};
app.currentFilePaths = {};
app.groupIndex = [];
app.groupTable = table();
app.currentFolder = '';

app.axialIndex = 1;
app.sagittalIndex = 1;
app.coronalIndex = 1;
app.axialRotationK = 0;
app.sagittalRotationK = 0;
app.coronalRotationK = 0;

app.dataLimits = [0 1];
app.displayLimits = [0 1];

app.fig = uifigure('Name', 'DICOM 3-Plane Viewer', 'Position', [80 80 1360 880]);
app.fig.Color = [0.96 0.97 0.98];

main = uigridlayout(app.fig, [3 1]);
main.RowHeight = {106, '1x', 34};
main.ColumnWidth = {'1x'};
main.Padding = [14 12 14 12];
main.RowSpacing = 10;

top = uigridlayout(main, [2 9]);
top.Layout.Row = 1;
top.ColumnWidth = {120, 70, 260, 86, 90, '1x', 90, 90, 86};
top.RowHeight = {34, 54};
top.ColumnSpacing = 8;
top.RowSpacing = 4;
top.Padding = [0 0 0 0];

app.loadButton = uibutton(top, 'push', ...
    'Text', 'Load Folder', ...
    'ButtonPushedFcn', @onLoadFolder);
app.loadButton.Layout.Row = [1 2];
app.loadButton.Layout.Column = 1;

app.folderLabel = uilabel(top, ...
    'Text', 'Choose a folder containing DICOM files', ...
    'FontWeight', 'bold', ...
    'Interpreter', 'none');
app.folderLabel.Layout.Row = 1;
app.folderLabel.Layout.Column = [2 9];

seriesLabel = uilabel(top, 'Text', 'Series', 'HorizontalAlignment', 'right');
seriesLabel.Layout.Row = 2;
seriesLabel.Layout.Column = 2;

app.seriesDropDown = uidropdown(top, ...
    'Items', {'Not loaded'}, ...
    'Enable', 'off', ...
    'ValueChangedFcn', @onSeriesChanged);
app.seriesDropDown.Layout.Row = 2;
app.seriesDropDown.Layout.Column = 3;

minLabel = uilabel(top, 'Text', 'Min', 'HorizontalAlignment', 'right');
minLabel.Layout.Row = 2;
minLabel.Layout.Column = 4;

app.windowMinEdit = uieditfield(top, 'numeric', ...
    'Enable', 'off', ...
    'ValueChangedFcn', @(src, ~) onWindowEditChanged('min', src.Value));
app.windowMinEdit.Layout.Row = 2;
app.windowMinEdit.Layout.Column = 5;

app.windowRange = uihtml(top, ...
    'HTMLSource', dualSliderHtmlPath(), ...
    'DataChangedFcn', @onWindowRangeChanged);
app.windowRange.Layout.Row = 2;
app.windowRange.Layout.Column = 6;

app.windowMaxEdit = uieditfield(top, 'numeric', ...
    'Enable', 'off', ...
    'ValueChangedFcn', @(src, ~) onWindowEditChanged('max', src.Value));
app.windowMaxEdit.Layout.Row = 2;
app.windowMaxEdit.Layout.Column = 7;

maxLabel = uilabel(top, 'Text', 'Max', 'HorizontalAlignment', 'left');
maxLabel.Layout.Row = 2;
maxLabel.Layout.Column = 8;

app.windowLabel = uilabel(top, ...
    'Text', 'Display: - to -', ...
    'HorizontalAlignment', 'right');
app.windowLabel.Layout.Row = 2;
app.windowLabel.Layout.Column = 9;

viewer = uigridlayout(main, [2 3]);
viewer.Layout.Row = 2;
viewer.ColumnWidth = {'1x', '1x', '1x'};
viewer.RowHeight = {'1x', 124};
viewer.ColumnSpacing = 12;
viewer.RowSpacing = 8;
viewer.Padding = [0 0 0 0];

[app.axAxial, app.axialPrevButton, app.axialEdit, app.axialTotalLabel, app.axialNextButton, app.axialSlider, app.axialRotateButton, app.axialSaveButton] = makePlane(viewer, 1, 'Axial');
[app.axSagittal, app.sagittalPrevButton, app.sagittalEdit, app.sagittalTotalLabel, app.sagittalNextButton, app.sagittalSlider, app.sagittalRotateButton, app.sagittalSaveButton] = makePlane(viewer, 2, 'Sagittal');
[app.axCoronal, app.coronalPrevButton, app.coronalEdit, app.coronalTotalLabel, app.coronalNextButton, app.coronalSlider, app.coronalRotateButton, app.coronalSaveButton] = makePlane(viewer, 3, 'Coronal');

app.axialSlider.ValueChangingFcn = @(~, event) onSliceChanging('axial', event.Value);
app.sagittalSlider.ValueChangingFcn = @(~, event) onSliceChanging('sagittal', event.Value);
app.coronalSlider.ValueChangingFcn = @(~, event) onSliceChanging('coronal', event.Value);
app.axialSlider.ValueChangedFcn = @(src, ~) onSliceChanged('axial', src.Value);
app.sagittalSlider.ValueChangedFcn = @(src, ~) onSliceChanged('sagittal', src.Value);
app.coronalSlider.ValueChangedFcn = @(src, ~) onSliceChanged('coronal', src.Value);

app.axialPrevButton.ButtonPushedFcn = @(~, ~) stepSlice('axial', -1);
app.axialNextButton.ButtonPushedFcn = @(~, ~) stepSlice('axial', 1);
app.sagittalPrevButton.ButtonPushedFcn = @(~, ~) stepSlice('sagittal', -1);
app.sagittalNextButton.ButtonPushedFcn = @(~, ~) stepSlice('sagittal', 1);
app.coronalPrevButton.ButtonPushedFcn = @(~, ~) stepSlice('coronal', -1);
app.coronalNextButton.ButtonPushedFcn = @(~, ~) stepSlice('coronal', 1);

app.axialEdit.ValueChangedFcn = @(src, ~) onSliceEditChanged('axial', src.Value);
app.sagittalEdit.ValueChangedFcn = @(src, ~) onSliceEditChanged('sagittal', src.Value);
app.coronalEdit.ValueChangedFcn = @(src, ~) onSliceEditChanged('coronal', src.Value);

app.axialRotateButton.ButtonPushedFcn = @(~, ~) rotatePlane('axial');
app.sagittalRotateButton.ButtonPushedFcn = @(~, ~) rotatePlane('sagittal');
app.coronalRotateButton.ButtonPushedFcn = @(~, ~) rotatePlane('coronal');
app.axialSaveButton.ButtonPushedFcn = @(~, ~) savePlaneImage('axial');
app.sagittalSaveButton.ButtonPushedFcn = @(~, ~) savePlaneImage('sagittal');
app.coronalSaveButton.ButtonPushedFcn = @(~, ~) savePlaneImage('coronal');

bottom = uigridlayout(main, [1 2]);
bottom.Layout.Row = 3;
bottom.ColumnWidth = {'1x', 72};
bottom.Padding = [0 0 0 0];

app.statusLabel = uilabel(bottom, ...
    'Text', 'Ready', ...
    'Interpreter', 'none');

app.infoButton = uibutton(bottom, 'push', ...
    'Text', 'Info', ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @showDicomInfo);
app.infoButton.Layout.Column = 2;

disableControls();

    function [ax, prevButton, editField, totalLabel, nextButton, slider, rotateButton, saveButton] = makePlane(parent, col, titleText)
        ax = uiaxes(parent);
        ax.Layout.Row = 1;
        ax.Layout.Column = col;
        ax.Color = [0.08 0.09 0.10];
        ax.XTick = [];
        ax.YTick = [];
        ax.Box = 'on';
        ax.ButtonDownFcn = @(~, ~) onImageClick(lower(titleText));
        title(ax, titleText);
        axis(ax, 'image');

        controls = uigridlayout(parent, [2 1]);
        controls.Layout.Row = 2;
        controls.Layout.Column = col;
        controls.RowHeight = {32, '1x'};
        controls.Padding = [4 0 4 0];
        controls.RowSpacing = 4;

        sliceRow = uigridlayout(controls, [1 8]);
        sliceRow.Layout.Row = 1;
        sliceRow.ColumnWidth = {'1x', 36, 70, 56, 36, 36, 44, '1x'};
        sliceRow.Padding = [0 0 0 0];
        sliceRow.ColumnSpacing = 6;

        prevButton = uibutton(sliceRow, 'push', 'Text', '<', 'Enable', 'off');
        prevButton.Layout.Column = 2;
        editField = uieditfield(sliceRow, 'numeric', ...
            'RoundFractionalValues', 'on', ...
            'Limits', [1 2], ...
            'Value', 1, ...
            'Enable', 'off');
        editField.Layout.Column = 3;
        totalLabel = uilabel(sliceRow, 'Text', '/ -', 'HorizontalAlignment', 'left');
        totalLabel.Layout.Column = 4;
        nextButton = uibutton(sliceRow, 'push', 'Text', '>', 'Enable', 'off');
        nextButton.Layout.Column = 5;
        rotateButton = uibutton(sliceRow, 'push', ...
            'Text', char(8634), ...
            'Enable', 'off');
        rotateButton.Layout.Column = 6;
        rotateButton.Tooltip = 'Rotate 90 degrees';

        saveButton = uibutton(sliceRow, 'push', ...
            'Text', 'Save', ...
            'Enable', 'off');
        saveButton.Layout.Column = 7;
        saveButton.Tooltip = 'Save this view';

        slider = uislider(controls);
        slider.Layout.Row = 2;
        slider.Limits = [1 2];
        slider.Value = 1;
        slider.MajorTicks = [];
        slider.MinorTicks = [];
        slider.Enable = 'off';

    end

    function onLoadFolder(~, ~)
        selectedFolder = uigetdir(app.currentFolder, 'Choose DICOM folder');
        if isequal(selectedFolder, 0)
            return
        end

        app.currentFolder = selectedFolder;
        app.folderLabel.Text = selectedFolder;
        app.statusLabel.Text = 'Scanning DICOM files...';
        drawnow;

        try
            [app.allInfoCells, app.allFilePaths, app.groupIndex, app.groupTable] = scanDicomFolder(selectedFolder);
        catch ME
            uialert(app.fig, ME.message, 'Read failed');
            app.statusLabel.Text = 'Read failed';
            return
        end

        if isempty(app.allFilePaths)
            uialert(app.fig, 'No readable DICOM image files were found.', 'No DICOM');
            app.statusLabel.Text = 'No readable DICOM image files found';
            return
        end

        app.seriesDropDown.Items = buildSeriesItems(app.groupTable);
        [~, defaultGroup] = max(app.groupTable.Count);
        app.seriesDropDown.Value = app.seriesDropDown.Items{defaultGroup};
        app.seriesDropDown.Enable = 'on';

        loadSeries(defaultGroup);
    end

    function onSeriesChanged(src, ~)
        selectedGroup = find(strcmp(src.Items, src.Value), 1);
        if ~isempty(selectedGroup)
            loadSeries(selectedGroup);
        end
    end

    function loadSeries(groupNumber)
        app.statusLabel.Text = 'Loading volume...';
        drawnow;

        try
            [app.volume, app.currentInfoCells, app.currentFilePaths] = readVolumeGroup( ...
                app.allInfoCells, app.allFilePaths, app.groupIndex, groupNumber);
        catch ME
            uialert(app.fig, ME.message, 'Load failed');
            app.statusLabel.Text = 'Load failed';
            return
        end

        app.axialIndex = max(1, round(size(app.volume, 3) / 2));
        app.sagittalIndex = max(1, round(size(app.volume, 2) / 2));
        app.coronalIndex = max(1, round(size(app.volume, 1) / 2));
        app.axialRotationK = 0;
        app.sagittalRotationK = 0;
        app.coronalRotationK = 0;

        app.dataLimits = dataRange(app.volume);
        app.displayLimits = app.dataLimits;

        configureSliceControl('axial', size(app.volume, 3));
        configureSliceControl('sagittal', size(app.volume, 2));
        configureSliceControl('coronal', size(app.volume, 1));
        configureWindowRange();
        enablePlaneButtons();

        updateAllViews();

        selected = app.groupTable(groupNumber, :);
        app.statusLabel.Text = sprintf( ...
            'Loaded: %s, %d files, size %d x %d x %d', ...
            char(selected.Description), selected.Count, ...
            size(app.volume, 1), size(app.volume, 2), size(app.volume, 3));
    end

    function configureSliceControl(planeName, maxValue)
        [slider, editField, totalLabel, prevButton, nextButton] = sliceControls(planeName);
        maxValue = max(1, maxValue);
        currentValue = getPlaneIndex(planeName);

        slider.Limits = [1 max(2, maxValue)];
        slider.Value = currentValue;
        slider.Enable = onOff(maxValue > 1);

        if maxValue <= 12
            slider.MajorTicks = 1:maxValue;
        else
            slider.MajorTicks = round(linspace(1, maxValue, 6));
        end

        editField.Limits = [1 maxValue];
        editField.Value = currentValue;
        editField.Enable = 'on';
        totalLabel.Text = sprintf('/ %d', maxValue);
        prevButton.Enable = onOff(maxValue > 1);
        nextButton.Enable = onOff(maxValue > 1);
    end

    function configureWindowRange()
        minData = app.dataLimits(1);
        maxData = app.dataLimits(2);
        if minData == maxData
            maxData = minData + 1;
        end

        app.windowMinEdit.Limits = [minData maxData];
        app.windowMaxEdit.Limits = [minData maxData];
        app.windowMinEdit.Value = app.displayLimits(1);
        app.windowMaxEdit.Value = app.displayLimits(2);
        app.windowMinEdit.Enable = 'on';
        app.windowMaxEdit.Enable = 'on';
        app.infoButton.Enable = 'on';
        pushWindowRangeToHtml();
        updateWindowLabel();
    end

    function pushWindowRangeToHtml()
        app.windowRange.Data = struct( ...
            'minimum', app.dataLimits(1), ...
            'maximum', app.dataLimits(2), ...
            'allowedMaximum', app.dataLimits(2), ...
            'colorMin', app.displayLimits(1), ...
            'transparency', app.displayLimits(2));
    end

    function onWindowRangeChanged(src, ~)
        if isempty(app.volume) || isempty(src.Data)
            return
        end

        data = src.Data;
        if ~isfield(data, 'colorMin') || ~isfield(data, 'transparency')
            return
        end

        setDisplayLimits(double(data.colorMin), double(data.transparency), false);
    end

    function onWindowEditChanged(whichValue, value)
        if isempty(app.volume)
            return
        end

        switch whichValue
            case 'min'
                setDisplayLimits(value, app.displayLimits(2), true);
            case 'max'
                setDisplayLimits(app.displayLimits(1), value, true);
        end
    end

    function setDisplayLimits(minValue, maxValue, pushToHtml)
        minValue = min(max(minValue, app.dataLimits(1)), app.dataLimits(2));
        maxValue = min(max(maxValue, app.dataLimits(1)), app.dataLimits(2));

        if minValue > maxValue
            tmp = minValue;
            minValue = maxValue;
            maxValue = tmp;
        end

        if minValue == maxValue
            maxValue = min(app.dataLimits(2), minValue + eps(max(abs([app.dataLimits 1]))));
            if minValue == maxValue
                minValue = app.dataLimits(1);
                maxValue = app.dataLimits(2);
            end
        end

        app.displayLimits = [minValue maxValue];
        app.windowMinEdit.Value = minValue;
        app.windowMaxEdit.Value = maxValue;
        updateWindowLabel();

        if pushToHtml
            pushWindowRangeToHtml();
        end

        updateDisplayLimitsOnly();
    end

    function updateWindowLabel()
        app.windowLabel.Text = sprintf('Display: %.4g to %.4g', app.displayLimits(1), app.displayLimits(2));
    end

    function updateDisplayLimitsOnly()
        if isempty(app.volume)
            return
        end

        clim(app.axAxial, app.displayLimits);
        clim(app.axSagittal, app.displayLimits);
        clim(app.axCoronal, app.displayLimits);
        drawnow limitrate;
    end

    function showDicomInfo(~, ~)
        if isempty(app.currentInfoCells)
            return
        end

        infoIndex = min(max(1, app.axialIndex), numel(app.currentInfoCells));
        infoText = formatDicomInfo(app.currentInfoCells{infoIndex}, app.currentFilePaths{infoIndex});

        infoFig = uifigure('Name', 'DICOM Info', ...
            'Position', [160 120 760 680], ...
            'WindowStyle', 'modal');

        infoGrid = uigridlayout(infoFig, [2 1]);
        infoGrid.RowHeight = {'1x', 38};
        infoGrid.Padding = [12 12 12 12];

        textArea = uitextarea(infoGrid, ...
            'Value', infoText, ...
            'Editable', 'off', ...
            'FontName', 'Consolas');
        textArea.Layout.Row = 1;

        closeButton = uibutton(infoGrid, 'push', ...
            'Text', 'Close', ...
            'ButtonPushedFcn', @(~, ~) close(infoFig));
        closeButton.Layout.Row = 2;
    end

    function onSliceChanging(planeName, value)
        setPlaneIndex(planeName, value);
        updatePlane(planeName);
    end

    function onSliceChanged(planeName, value)
        setPlaneIndex(planeName, value);
        syncSliceValues();
        updatePlane(planeName);
    end

    function onSliceEditChanged(planeName, value)
        setPlaneIndex(planeName, value);
        syncSliceValues();
        updatePlane(planeName);
    end

    function stepSlice(planeName, stepValue)
        setPlaneIndex(planeName, getPlaneIndex(planeName) + stepValue);
        syncSliceValues();
        updatePlane(planeName);
    end

    function setPlaneIndex(planeName, value)
        if isempty(app.volume)
            return
        end

        value = max(1, round(value));

        switch planeName
            case 'axial'
                app.axialIndex = min(value, size(app.volume, 3));
            case 'sagittal'
                app.sagittalIndex = min(value, size(app.volume, 2));
            case 'coronal'
                app.coronalIndex = min(value, size(app.volume, 1));
        end
    end

    function value = getPlaneIndex(planeName)
        switch planeName
            case 'axial'
                value = app.axialIndex;
            case 'sagittal'
                value = app.sagittalIndex;
            case 'coronal'
                value = app.coronalIndex;
        end
    end

    function [slider, editField, totalLabel, prevButton, nextButton] = sliceControls(planeName)
        switch planeName
            case 'axial'
                slider = app.axialSlider;
                editField = app.axialEdit;
                totalLabel = app.axialTotalLabel;
                prevButton = app.axialPrevButton;
                nextButton = app.axialNextButton;
            case 'sagittal'
                slider = app.sagittalSlider;
                editField = app.sagittalEdit;
                totalLabel = app.sagittalTotalLabel;
                prevButton = app.sagittalPrevButton;
                nextButton = app.sagittalNextButton;
            case 'coronal'
                slider = app.coronalSlider;
                editField = app.coronalEdit;
                totalLabel = app.coronalTotalLabel;
                prevButton = app.coronalPrevButton;
                nextButton = app.coronalNextButton;
        end
    end

    function rotatePlane(planeName)
        switch planeName
            case 'axial'
                app.axialRotationK = mod(app.axialRotationK + 1, 4);
            case 'sagittal'
                app.sagittalRotationK = mod(app.sagittalRotationK + 1, 4);
            case 'coronal'
                app.coronalRotationK = mod(app.coronalRotationK + 1, 4);
        end

        updateRotationButtonLabels();
        updatePlane(planeName);
    end

    function updateRotationButtonLabels()
        app.axialRotateButton.Text = char(8634);
        app.sagittalRotateButton.Text = char(8634);
        app.coronalRotateButton.Text = char(8634);
    end

    function savePlaneImage(planeName)
        if isempty(app.volume)
            return
        end

        [plane, defaultName] = planeForDisplay(planeName);
        imageData = scaleForExport(plane, app.displayLimits);
        filters = {'*.png', 'PNG image (*.png)'; '*.jpg;*.jpeg', 'JPEG image (*.jpg)'; '*.tif;*.tiff', 'TIFF image (*.tif)'};
        [fileName, folderName, filterIndex] = uiputfile(filters, 'Save current view', defaultName);

        if isequal(fileName, 0)
            return
        end

        filePath = fullfile(folderName, fileName);
        [~, ~, ext] = fileparts(filePath);

        if isempty(ext)
            defaultExts = {'.png', '.jpg', '.tif'};
            filePath = [filePath defaultExts{filterIndex}];
        end

        try
            imwrite(imageData, filePath);
            app.statusLabel.Text = sprintf('Saved: %s', filePath);
        catch ME
            uialert(app.fig, ME.message, 'Save failed');
        end
    end

    function onImageClick(planeName)
        if isempty(app.volume)
            return
        end

        switch planeName
            case 'axial'
                [displayRows, displayCols] = rotatedSize(size(app.volume, 1), size(app.volume, 2), app.axialRotationK);
                point = app.axAxial.CurrentPoint;
                [row, col] = displayedPointToOriginal(point(1, 1), point(1, 2), displayRows, displayCols, app.axialRotationK);
                if isValidIndex(row, size(app.volume, 1)) && isValidIndex(col, size(app.volume, 2))
                    app.coronalIndex = row;
                    app.sagittalIndex = col;
                    syncSliceValues();
                    updatePlane('sagittal');
                    updatePlane('coronal');
                end
            case 'sagittal'
                [displayRows, displayCols] = rotatedSize(size(app.volume, 1), size(app.volume, 3), app.sagittalRotationK);
                point = app.axSagittal.CurrentPoint;
                [row, slice] = displayedPointToOriginal(point(1, 1), point(1, 2), displayRows, displayCols, app.sagittalRotationK);
                if isValidIndex(row, size(app.volume, 1)) && isValidIndex(slice, size(app.volume, 3))
                    app.coronalIndex = row;
                    app.axialIndex = slice;
                    syncSliceValues();
                    updatePlane('axial');
                    updatePlane('coronal');
                end
            case 'coronal'
                [displayRows, displayCols] = rotatedSize(size(app.volume, 2), size(app.volume, 3), app.coronalRotationK);
                point = app.axCoronal.CurrentPoint;
                [col, slice] = displayedPointToOriginal(point(1, 1), point(1, 2), displayRows, displayCols, app.coronalRotationK);
                if isValidIndex(col, size(app.volume, 2)) && isValidIndex(slice, size(app.volume, 3))
                    app.sagittalIndex = col;
                    app.axialIndex = slice;
                    syncSliceValues();
                    updatePlane('axial');
                    updatePlane('sagittal');
                end
        end
    end

    function updateAllViews()
        if isempty(app.volume)
            return
        end

        syncSliceValues();
        updateRotationButtonLabels();
        updatePlane('axial');
        updatePlane('sagittal');
        updatePlane('coronal');
    end

    function syncSliceValues()
        if isempty(app.volume)
            return
        end

        syncOneSlice('axial', app.axialIndex, size(app.volume, 3));
        syncOneSlice('sagittal', app.sagittalIndex, size(app.volume, 2));
        syncOneSlice('coronal', app.coronalIndex, size(app.volume, 1));
    end

    function syncOneSlice(planeName, value, maxValue)
        [slider, editField, totalLabel, prevButton, nextButton] = sliceControls(planeName);
        slider.Value = value;
        editField.Value = value;
        totalLabel.Text = sprintf('/ %d', maxValue);
        prevButton.Enable = onOff(value > 1);
        nextButton.Enable = onOff(value < maxValue);
    end

    function updatePlane(planeName)
        if isempty(app.volume)
            return
        end

        [plane, ~] = planeForDisplay(planeName);

        switch planeName
            case 'axial'
                drawPlane(app.axAxial, plane, 'axial');
            case 'sagittal'
                drawPlane(app.axSagittal, plane, 'sagittal');
            case 'coronal'
                drawPlane(app.axCoronal, plane, 'coronal');
        end
    end

    function [plane, defaultName] = planeForDisplay(planeName)
        switch planeName
            case 'axial'
                plane = rot90(app.volume(:, :, app.axialIndex), app.axialRotationK);
                defaultName = sprintf('axial_slice_%03d.png', app.axialIndex);
            case 'sagittal'
                plane = rot90(squeeze(app.volume(:, app.sagittalIndex, :)), app.sagittalRotationK);
                defaultName = sprintf('sagittal_slice_%03d.png', app.sagittalIndex);
            case 'coronal'
                plane = rot90(squeeze(app.volume(app.coronalIndex, :, :)), app.coronalRotationK);
                defaultName = sprintf('coronal_slice_%03d.png', app.coronalIndex);
        end
    end

    function drawPlane(ax, plane, planeName)
        h = imagesc(ax, plane);
        h.ButtonDownFcn = @(~, ~) onImageClick(planeName);
        h.HitTest = 'on';
        axis(ax, 'image');
        ax.XTick = [];
        ax.YTick = [];
        colormap(ax, gray);
        clim(ax, app.displayLimits);
    end

    function enablePlaneButtons()
        app.axialRotateButton.Enable = 'on';
        app.sagittalRotateButton.Enable = 'on';
        app.coronalRotateButton.Enable = 'on';
        app.axialSaveButton.Enable = 'on';
        app.sagittalSaveButton.Enable = 'on';
        app.coronalSaveButton.Enable = 'on';
    end

    function disableControls()
        app.axialSlider.Enable = 'off';
        app.sagittalSlider.Enable = 'off';
        app.coronalSlider.Enable = 'off';
        app.axialEdit.Enable = 'off';
        app.sagittalEdit.Enable = 'off';
        app.coronalEdit.Enable = 'off';
        app.axialPrevButton.Enable = 'off';
        app.axialNextButton.Enable = 'off';
        app.sagittalPrevButton.Enable = 'off';
        app.sagittalNextButton.Enable = 'off';
        app.coronalPrevButton.Enable = 'off';
        app.coronalNextButton.Enable = 'off';
        app.axialRotateButton.Enable = 'off';
        app.sagittalRotateButton.Enable = 'off';
        app.coronalRotateButton.Enable = 'off';
        app.axialSaveButton.Enable = 'off';
        app.sagittalSaveButton.Enable = 'off';
        app.coronalSaveButton.Enable = 'off';
        app.windowMinEdit.Enable = 'off';
        app.windowMaxEdit.Enable = 'off';
        app.infoButton.Enable = 'off';
    end
end

function htmlPath = dualSliderHtmlPath()
htmlPath = fullfile(fileparts(mfilename('fullpath')), 'showpic_dual_slider.html');
if ~isfile(htmlPath)
    error('Missing dual-slider HTML file: %s', htmlPath);
end
end

function [displayRows, displayCols] = rotatedSize(rows, cols, rotationK)
if mod(rotationK, 2) == 0
    displayRows = rows;
    displayCols = cols;
else
    displayRows = cols;
    displayCols = rows;
end
end

function [row, col] = displayedPointToOriginal(x, y, displayRows, displayCols, rotationK)
displayRow = round(y);
displayCol = round(x);

if ~isValidIndex(displayRow, displayRows) || ~isValidIndex(displayCol, displayCols)
    row = NaN;
    col = NaN;
    return
end

switch mod(rotationK, 4)
    case 0
        row = displayRow;
        col = displayCol;
    case 1
        row = displayCol;
        col = displayRows - displayRow + 1;
    case 2
        row = displayRows - displayRow + 1;
        col = displayCols - displayCol + 1;
    case 3
        row = displayCols - displayCol + 1;
        col = displayRow;
end
end

function tf = isValidIndex(value, maxValue)
tf = isfinite(value) && value >= 1 && value <= maxValue;
end

function imageData = scaleForExport(plane, displayLimits)
low = displayLimits(1);
high = displayLimits(2);

if high <= low
    high = low + 1;
end

imageData = (double(plane) - low) ./ (high - low);
imageData = min(max(imageData, 0), 1);
imageData = uint8(round(imageData * 255));
end

function [infoCells, filePaths, groupIndex, groupTable] = scanDicomFolder(folderPath)
files = dir(fullfile(folderPath, '**', '*'));
files = files(~[files.isdir]);

infoCells = {};
filePaths = {};

for k = 1:numel(files)
    filePath = fullfile(files(k).folder, files(k).name);

    try
        info = dicominfo(filePath, 'UseDictionaryVR', true);
    catch
        try
            info = dicominfo(filePath);
        catch
            continue
        end
    end

    if isfield(info, 'Rows') && isfield(info, 'Columns')
        infoCells{end + 1} = info; %#ok<AGROW>
        filePaths{end + 1} = filePath; %#ok<AGROW>
    end
end

if isempty(infoCells)
    groupIndex = [];
    groupTable = table();
    return
end

[groupIndex, groupTable] = groupDicomSeries(infoCells);
end

function [groupIndex, groupTable] = groupDicomSeries(infoCells)
keys = cell(numel(infoCells), 1);
uniqueKeys = {};
groupIndex = zeros(numel(infoCells), 1);

for k = 1:numel(infoCells)
    keys{k} = dicomGroupKey(infoCells{k});
    found = find(strcmp(uniqueKeys, keys{k}), 1);

    if isempty(found)
        uniqueKeys{end + 1} = keys{k}; %#ok<AGROW>
        found = numel(uniqueKeys);
    end

    groupIndex(k) = found;
end

count = accumarray(groupIndex, 1);
seriesNumber = zeros(numel(uniqueKeys), 1);
rows = zeros(numel(uniqueKeys), 1);
cols = zeros(numel(uniqueKeys), 1);
description = strings(numel(uniqueKeys), 1);

for g = 1:numel(uniqueKeys)
    firstIndex = find(groupIndex == g, 1);
    info = infoCells{firstIndex};

    seriesNumber(g) = getNumericField(info, 'SeriesNumber', NaN);
    rows(g) = getNumericField(info, 'Rows', NaN);
    cols(g) = getNumericField(info, 'Columns', NaN);
    description(g) = string(getCharField(info, 'SeriesDescription', 'No description'));
end

groupTable = table(count, seriesNumber, rows, cols, description, ...
    'VariableNames', {'Count', 'SeriesNumber', 'Rows', 'Columns', 'Description'});
end

function key = dicomGroupKey(info)
seriesUid = getCharField(info, 'SeriesInstanceUID', 'NO_SERIES_UID');
seriesNumber = num2str(getNumericField(info, 'SeriesNumber', NaN));
rows = num2str(getNumericField(info, 'Rows', NaN));
cols = num2str(getNumericField(info, 'Columns', NaN));

key = sprintf('%s|%s|%s|%s', seriesUid, seriesNumber, rows, cols);
end

function items = buildSeriesItems(groupTable)
items = cell(height(groupTable), 1);

for g = 1:height(groupTable)
    items{g} = sprintf('%d: Series %g, %s, %dx%d, %d files', ...
        g, groupTable.SeriesNumber(g), char(groupTable.Description(g)), ...
        groupTable.Rows(g), groupTable.Columns(g), groupTable.Count(g));
end
end

function [volume, selectedInfos, selectedFiles] = readVolumeGroup(infoCells, filePaths, groupIndex, groupNumber)
selected = find(groupIndex == groupNumber);
selectedInfos = infoCells(selected);
selectedFiles = filePaths(selected);

order = dicomSliceOrder(selectedInfos);
selectedInfos = selectedInfos(order);
selectedFiles = selectedFiles(order);

firstInfo = selectedInfos{1};
rows = double(firstInfo.Rows);
cols = double(firstInfo.Columns);
numSlices = numel(selectedFiles);
volume = zeros(rows, cols, numSlices);

for k = 1:numSlices
    info = selectedInfos{k};
    raw = dicomread(info);

    if ~ismatrix(raw)
        raw = squeeze(raw(:, :, 1));
    end

    slice = double(raw);
    slope = getNumericField(info, 'RescaleSlope', 1);
    intercept = getNumericField(info, 'RescaleIntercept', 0);
    slice = slice .* slope + intercept;

    if isfield(info, 'PhotometricInterpretation') && strcmpi(info.PhotometricInterpretation, 'MONOCHROME1')
        slice = max(slice(:)) + min(slice(:)) - slice;
    end

    if ~isequal(size(slice), [rows cols])
        error('Matrix size is not consistent inside this DICOM series.');
    end

    volume(:, :, k) = slice;
end
end

function order = dicomSliceOrder(infoCells)
numSlices = numel(infoCells);
positions = nan(numSlices, 1);
instances = nan(numSlices, 1);
normal = [];

for k = 1:numSlices
    info = infoCells{k};

    if isfield(info, 'ImageOrientationPatient') && numel(info.ImageOrientationPatient) >= 6
        rowDirection = double(info.ImageOrientationPatient(1:3));
        colDirection = double(info.ImageOrientationPatient(4:6));
        normal = cross(rowDirection, colDirection);
        break
    end
end

for k = 1:numSlices
    info = infoCells{k};

    if isfield(info, 'ImagePositionPatient') && numel(info.ImagePositionPatient) >= 3
        imagePosition = double(info.ImagePositionPatient(1:3));

        if ~isempty(normal)
            positions(k) = dot(imagePosition, normal);
        else
            positions(k) = imagePosition(3);
        end
    elseif isfield(info, 'SliceLocation')
        positions(k) = double(info.SliceLocation);
    end

    if isfield(info, 'InstanceNumber')
        instances(k) = double(info.InstanceNumber);
    end
end

if any(~isnan(positions))
    fillValues = positions;
    fillValues(isnan(fillValues)) = inf;
    [~, order] = sort(fillValues, 'ascend');
elseif any(~isnan(instances))
    fillValues = instances;
    fillValues(isnan(fillValues)) = inf;
    [~, order] = sort(fillValues, 'ascend');
else
    order = 1:numSlices;
end
end

function limits = dataRange(volume)
finiteValues = volume(isfinite(volume));

if isempty(finiteValues)
    limits = [0 1];
    return
end

limits = [min(finiteValues) max(finiteValues)];

if limits(1) == limits(2)
    limits = limits + [-0.5 0.5];
end
end

function state = onOff(condition)
if condition
    state = 'on';
else
    state = 'off';
end
end

function lines = formatDicomInfo(info, filePath)
lines = {};
lines{end + 1} = 'DICOM 信息（不含像素数据）'; %#ok<AGROW>
lines{end + 1} = '================================'; %#ok<AGROW>
lines{end + 1} = sprintf('文件路径: %s', filePath); %#ok<AGROW>
lines{end + 1} = ''; %#ok<AGROW>
lines{end + 1} = '常用信息'; %#ok<AGROW>
lines{end + 1} = '--------'; %#ok<AGROW>

commonFields = {
    'PatientName', '受试者姓名'
    'PatientID', '受试者编号'
    'PatientSex', '性别'
    'PatientAge', '年龄'
    'PatientBirthDate', '出生日期'
    'StudyDate', '检查日期'
    'StudyTime', '检查时间'
    'StudyDescription', '检查描述'
    'StudyInstanceUID', '检查 UID'
    'StudyID', '检查 ID'
    'AccessionNumber', '登记号'
    'SeriesDate', '序列日期'
    'SeriesTime', '序列时间'
    'SeriesDescription', '序列描述'
    'SeriesNumber', '序列号'
    'SeriesInstanceUID', '序列 UID'
    'InstanceNumber', '图像编号'
    'Modality', '成像类型'
    'Manufacturer', '厂家'
    'ManufacturerModelName', '设备型号'
    'InstitutionName', '机构名称'
    'StationName', '工作站名称'
    'MagneticFieldStrength', '磁场强度'
    'ProtocolName', '扫描协议'
    'SequenceName', '序列名称'
    'ScanningSequence', '扫描序列'
    'SequenceVariant', '序列变体'
    'ScanOptions', '扫描选项'
    'MRAcquisitionType', 'MR 采集类型'
    'RepetitionTime', '重复时间 TR'
    'EchoTime', '回波时间 TE'
    'InversionTime', '反转时间 TI'
    'FlipAngle', '翻转角'
    'EchoTrainLength', '回波链长度'
    'Rows', '行数'
    'Columns', '列数'
    'PixelSpacing', '像素间距'
    'SliceThickness', '层厚'
    'SpacingBetweenSlices', '层间距'
    'SliceLocation', '层位置'
    'ImagePositionPatient', '图像位置'
    'ImageOrientationPatient', '图像方向'
    'RescaleSlope', '像素缩放斜率'
    'RescaleIntercept', '像素缩放截距'
    'PhotometricInterpretation', '灰度解释'
    'BitsAllocated', '分配位数'
    'BitsStored', '存储位数'
    'HighBit', '最高位'
    'PixelRepresentation', '像素表示'
    };

shown = false(size(commonFields, 1), 1);
for k = 1:size(commonFields, 1)
    fieldName = commonFields{k, 1};
    if isfield(info, fieldName)
        valueText = fieldValueToText(info.(fieldName));
        if ~isempty(valueText)
            lines{end + 1} = sprintf('%s (%s): %s', commonFields{k, 2}, fieldName, valueText); %#ok<AGROW>
            shown(k) = true;
        end
    end
end

lines{end + 1} = ''; %#ok<AGROW>
lines{end + 1} = '其它 DICOM 字段'; %#ok<AGROW>
lines{end + 1} = '---------------'; %#ok<AGROW>

commonNames = commonFields(:, 1);
allFields = sort(fieldnames(info));
otherCount = 0;
maxOtherFields = 260;

for k = 1:numel(allFields)
    fieldName = allFields{k};
    if any(strcmp(commonNames, fieldName)) || isImagePayloadField(fieldName)
        continue
    end

    valueText = fieldValueToText(info.(fieldName));
    if isempty(valueText)
        continue
    end

    lines{end + 1} = sprintf('%s: %s', fieldName, valueText); %#ok<AGROW>
    otherCount = otherCount + 1;
    if otherCount >= maxOtherFields
        lines{end + 1} = '... 其它字段较多，已截断显示。'; %#ok<AGROW>
        break
    end
end

if ~any(shown)
    lines{end + 1} = '未找到常用 DICOM 字段。'; %#ok<AGROW>
end
end

function tf = isImagePayloadField(fieldName)
payloadFields = {'PixelData', 'OverlayData', 'FloatPixelData', 'DoubleFloatPixelData', ...
    'RedPaletteColorLookupTableData', 'GreenPaletteColorLookupTableData', ...
    'BluePaletteColorLookupTableData', 'IconImageSequence'};
tf = any(strcmp(fieldName, payloadFields));
end

function valueText = fieldValueToText(value)
valueText = '';

if isempty(value)
    return
end

if ischar(value)
    valueText = strtrim(value);
elseif isstring(value)
    valueText = char(strjoin(value, ', '));
elseif isnumeric(value) || islogical(value)
    if numel(value) <= 16
        valueText = mat2str(double(value(:).'));
    else
        valueText = sprintf('[%s %s, numeric]', num2str(size(value, 1)), num2str(size(value, 2)));
    end
elseif isstruct(value)
    valueText = sprintf('[sequence/struct, %d item(s)]', numel(value));
elseif iscell(value)
    try
        pieces = cellfun(@fieldValueToText, value, 'UniformOutput', false);
        pieces = pieces(~cellfun(@isempty, pieces));
        valueText = strjoin(pieces(1:min(numel(pieces), 8)), ', ');
    catch
        valueText = sprintf('[cell, %d item(s)]', numel(value));
    end
else
    try
        valueText = char(value);
    catch
        valueText = sprintf('[%s]', class(value));
    end
end

if strlength(string(valueText)) > 260
    valueText = extractBefore(string(valueText), 261) + "...";
    valueText = char(valueText);
end
end

function value = getNumericField(info, fieldName, defaultValue)
if isfield(info, fieldName) && ~isempty(info.(fieldName))
    value = double(info.(fieldName));
else
    value = defaultValue;
end
end

function value = getCharField(info, fieldName, defaultValue)
if isfield(info, fieldName) && ~isempty(info.(fieldName))
    value = char(info.(fieldName));
else
    value = defaultValue;
end
end
