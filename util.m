classdef util
    %Provides a set of statically accessed support methods for vtanalzer
    methods (Static)
        
        %Initializes the appdata 'ad' structure for vtanalyzer
        function [ad] = init(handles, scroll_wheel_handle, move_mouse_handle, mouse_up_handle, mouse_down_handle, save_state_handle, keyboard_response_handle)
            %Create appdata structure
            ad = struct();
            ad.mainFig = gcf;
            
            ad.isImageDataFlag = 0;
            ad.mouseDownFlag = 0;   %Used for moving crosshairs
            ad.slices.axial = 1;
            ad.slices.sagittal = 1;
            ad.slices.coronal = 1;
            ad.clim = [0 1];
            ad.activePlane = 'sagittal';
            ad.activeAxes = handles.sagittal_axes;
            ad.hoverPlane = [];
            ad.hoverAxes = [];
            ad.currentLocation = [];
            ad.planeSwitchFlag = 1;
            ad.isPanning = false;
            ad.panStart = [0 0];
            
            ad.dims.sagittal.x = 2; ad.dims.sagittal.y = 2;
            ad.dims.coronal.x = 2; ad.dims.coronal.y = 2;
            ad.dims.axial.x = 2; ad.dims.axial.y = 2;
            ad.color_map = gray(256);
            ad.default_color_map = gray(256);
            ad.landmarksHiddenFlag = false;
            ad.landmarks = [];
            
            zoomPos = get(handles.zoom_axes, 'Position');
            ad.zoomPlotRatio = zoomPos(4)/zoomPos(3);
            ad.zoomFactorDefault = 0.3;
            ad.zoomFactor = 0.3;
            ad.zoomMin = 0.1;
            ad.zoomMax = 0.5;
            ad.updatingZoomFlag = false;
            
            ad.pos.voxel = [0 0 0];
            ad.pos.mm = [0 0 0];
            
            ad.xhairs.coronal = [];
            ad.xhairs.sagittal = [];
            ad.xhairs.axial = [];
            
            %Read vtanalyzer state file & populate file list
            ad.rawDataFileName = '';
            ad.rawDataFilePath = pwd;
            ad.landmarksFileName = '';
            ad.landmarksFilePath = pwd;
            
            %Define callback handles and set them in the main figure
            ad.callbacks.scroll_wheel_handle = scroll_wheel_handle;
            ad.callbacks.move_mouse_handle = move_mouse_handle;
            ad.callbacks.mouse_up_handle = mouse_up_handle;
            ad.callbacks.mouse_down_handle = mouse_down_handle;
            ad.callbacks.save_state_handle = save_state_handle;
            ad.callbacks.keyboard_response_handle = keyboard_response_handle;
            
            %Define the prenamed landmark sets
            ad.newPrenamedFlag = false;
            ad.prenamedPointLandmarkNamesFor3D = {'basion', 'odontoid', 'atlas', 'C2 base', 'C3 base', 'C4 base', 'C5 base', 'C6 base', 'C7 base', 'sella', 'nasion', 'nasal spine posterior', 'nasal spine anterior', 'hard palate posterior', 'hard palate anterior', 'uvula', 'prosthion', 'pogonion', 'menton', 'apex inferior', 'apex superior', 'incision inferior', 'incision superior', 'gonion left', 'gonion right', 'condylion left', 'condylion right', 'canine left', 'canine right', 'second premolar left', 'second premolar right', 'endomolare left', 'endomolare right', 'corniculate tubercle', 'nasopharynx', 'epiglottis apex', 'epiglottis petiole', 'hyoid bone body', 'laryngopharynx', 'orbitale left', 'orbitale right'};
            ad.prenamedSemilandmarkNamesFor3D = {'hard palate midsagittal', 'hard palate coronal 2nd molare', 'hard palate coronal 2nd premolar', 'hard palate coronal canine', 'maxillary dental arch', 'pharynx wall'};
            ad.prenamedPointLandmarkNamesForExternalImages = {'nasal spine anterior', 'lips', 'nasion', 'chin', 'gonion', 'helix crus', 'vocal folds suspected', 'neck fold', 'neck curvature','laryngeal prominence', 'vocal folds', 'nasal spine posterior', 'sella', 'basion', 'soft palate', 'tongue', 'laryngopharynx wall', 'oropharynx wall', 'maxillary incisor lingual surface', 'C2 base', 'C3 top', 'C3 base', 'C4 base', 'C5 base', 'hyoid bone body', 'pogonion'};
            ad.prenamedSemilandmarkNamesForExternalImages = {struct('name', 'airway trace (lips to vocal folds)', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [20 0 1.0], 'first_anchor', 'lips', 'second_anchor', 'vocal folds'), struct('name', 'airway trace (lips to vocal folds suspected)', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [20 0 1.0], 'first_anchor', 'lips', 'second_anchor', 'vocal folds suspected')};
            ad.prenamedPointLandmarkNamesForVTProportions = {'nasal spine anterior', 'nasal spine posterior', 'lips', 'nasion', 'sella', 'basion', 'soft palate', 'tongue', 'laryngopharynx wall', 'oropharynx wall', 'maxillary incisor lingual surface', 'chin', 'vocal folds', 'C2 base', 'C3 top', 'C3 base', 'C4 base', 'C5 base', 'hyoid bone body', 'neck curvature', 'pogonion', 'laryngeal prominence'};
            ad.prenamedSemilandmarkNamesForVTProportions = {struct('name', 'airway trace (lips to vocal folds)', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [25 0 1.0], 'first_anchor', 'lips', 'second_anchor', 'vocal folds')};
            ad.prenamedPointLandmarkNamesForLarynxPosition = {'odontoid', 'C2 base', 'C3 base', 'C4 base', 'C5 base', 'corniculate tubercle', 'epiglottis apex', 'epiglottis petiole'};
            ad.prenamedSemilandmarkNamesForLarynxPosition = {''};
            ad.prenamedPointLandmarkNamesForMidsagittalPalateTraces = {'hard palate anterior', 'hard palate posterior'};
            ad.prenamedSemilandmarkNamesForMidsagittalPalateTraces = {struct('name', 'midsagittal hard palate', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [25 0 1.0], 'first_anchor', 'hard palate anterior', 'second_anchor', 'hard palate posterior')};
            ad.prenamedPointLandmarkNamesForLarynxVowels = {'menton', 'atlas tubercle', 'pns', 'ans', 'tongue tip', 'tongue base', 'C2 base', 'C3 base', 'C4 base', 'C5 base', 'C6 base', 'C7 base', 'vocal fold', 'ventricular fold', 'anterior commissure', 'posterior commissure', 'epiglottis apex', 'epiglottis tubercle', 'epiglottis petiole', 'hyoid bone body', 'cricoid lamina superior', 'interarytenoid superior', 'periepiglottic fat superior anterior', 'incisive gingiva', 'uvula'};
            ad.prenamedSemilandmarkNamesForLarynxVowels = {...
                struct('name', 'tongue', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [25 0 1.0], 'first_anchor', 'tongue tip', 'second_anchor', 'tongue base'),...
                struct('name', 'ventricle sagittal', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [10 0 1.0], 'first_anchor', 'anterior commissure', 'second_anchor', 'posterior commissure'),...
                struct('name', 'ventricle axial', 'type', 'semi', 'plane', 'axial', 'constraint', 'proximity', 'samplePattern', [10 0 1.0], 'first_anchor', 'anterior commissure', 'second_anchor', 'posterior commissure'),...
                struct('name', 'periepiglottic fat', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [10 0 1.0], 'first_anchor', 'epiglottis petiole', 'second_anchor', 'periepiglottic fat superior anterior')...
                struct('name', 'posterior epilarynx', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [10 0 1.0], 'first_anchor', 'posterior commissure', 'second_anchor', 'interarytenoid superior')...
                struct('name', 'anterior epilarynx', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [10 0 1.0], 'first_anchor', 'epiglottis petiole', 'second_anchor', 'epiglottis apex'),...
                struct('name', 'palate', 'type', 'semi', 'plane', 'sagittal', 'constraint', 'proximity', 'samplePattern', [20 0 1.0], 'first_anchor', 'incisive gingiva', 'second_anchor', 'uvula')};
            
            util.reset_callbacks(ad, handles);
            
            try
                state = load('vtanalyzer_state.mat');
                ad.rawDataFilePath = state.rawDataFilePath;
                ad.landmarksFilePath = state.landmarksFilePath;
                
                ad.vt_template_FilePath = state.templateFilePath;
                ad.vt_template_FileName = state.templateFileName;
                ad.activePointLandmarkNames = state.activePointLandmarkNames;
                ad.activeSemilandmarkNames = state.activeSemilandmarkNames;
            catch
                ad.vt_template_FilePath = pwd;
                ad.vt_template_FileName = 'vt_template.xml';
                ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesFor3D;
                ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesFor3D;
                
                disp('Could not load previous state, an error occurred.');
            end
            
            
            %Set template
            try
                templates = dir(fullfile(ad.vt_template_FilePath, '*.xml'));
                templateIndex = find(strcmp({templates.name}, ad.vt_template_FileName));
                if (~isempty(templates))
                    set(handles.template_popupmenu, 'String', {templates.name});
                    set(handles.template_popupmenu, 'Value', templateIndex);
                else
                    set(handles.template_popupmenu, 'String', 'NO TEMPLATE FOUND');
                    set(handles.template_popupmenu, 'Value', 1);
                end
            catch
                set(handles.template_popupmenu, 'String', 'NO TEMPLATE FOUND');
                set(handles.template_popupmenu, 'Value', 1);
            end
            
            %Set prenamed landmarks
            set(handles.prenamed_point_landmark_menu, 'String', ad.activePointLandmarkNames);
            try
                semiLMs = [ad.activeSemilandmarkNames{:}];
                set(handles.prenamed_semi_landmark_menu, 'String', {semiLMs.name});
            catch
            end
            
            %Populate file lists
            rawDataList = dir(fullfile(ad.rawDataFilePath, '*.nii'));
            rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.dcb'))];
            rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.jpg'))];
            rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.png'))];
            rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.tif'))];
            
            lmDataList = dir(fullfile(ad.landmarksFilePath, '*.nlm'));
            lmDataList = [lmDataList; dir(fullfile(ad.landmarksFilePath, '*.lmd'))];
            
            util.populate_file_list(rawDataList, ad.rawDataFileName, handles.raw_data_files_listbox, handles.raw_data_files_text, 'Raw Data Files: ');
            util.populate_file_list(lmDataList, ad.landmarksFileName, handles.lmd_files_listbox, handles.landmark_files_text, 'Landmark Data (LMD) Files: ');
            
            %Reset all plots
            ad = util.reset_plot(ad, 'coronal', handles, []);
            ad = util.reset_plot(ad, 'sagittal', handles, []);
            ad = util.reset_plot(ad, 'axial', handles, []);
            
            %Initialize controls
            set(handles.low_contrast_slider, 'Units', 'Normalized', 'Min', 0, 'Max', 1.0, 'SliderStep', [1.00001/1e2 1/10], 'Value', 0.0);
            set(handles.high_contrast_slider, 'Units', 'Normalized', 'Min', 0, 'Max', 1.0, 'SliderStep', [1.00001/1e2 1/10], 'Value', 1.0);
            set(handles.low_brightness_slider, 'Units', 'Normalized', 'Min', 0, 'Max', 1.0, 'SliderStep', [1.00001/1e2 1/10], 'Value', 0.0);
            set(handles.high_brightness_slider, 'Units', 'Normalized', 'Min', 0, 'Max', 1.0, 'SliderStep', [1.00001/1e2 1/10], 'Value', 1.0);
            set(handles.zoom_axes, 'YDir', 'normal', 'XTick', [], 'YTick', []);
            set(handles.colormap_popupmenu, 'String', {'gray', 'jet', 'cool', 'winter'});
            
        end
        
        function [] = populate_file_list(files, fileName, listbox_handle, current_file_text_handle, current_file_base_text)
            if ~isempty(files)
                set(listbox_handle, 'String', {files(:).name});
            end
            
            b = @(str,test) strcmp(str,test);
            selFile = find(b({files(:).name}, fileName));
            if ~isempty(selFile) && length(selFile) == 1
                set(listbox_handle, 'Value', selFile);
            end
            
            set(current_file_text_handle, 'String', [current_file_base_text fileName]);
        end
        
        
        function [] = reset_callbacks(ad, handles)
            %disp('callbacks reset');
            %Define primary callback functions
            set(ad.mainFig, 'WindowScrollWheelFcn', ad.callbacks.scroll_wheel_handle);
            set(ad.mainFig, 'WindowButtonMotionFcn', ad.callbacks.move_mouse_handle);
            set(ad.mainFig, 'WindowButtonUpFcn', ad.callbacks.mouse_up_handle);
            set(ad.mainFig, 'WindowButtonDownFcn', ad.callbacks.mouse_down_handle);
            set(ad.mainFig, 'CloseRequestFcn', ad.callbacks.save_state_handle);
            set(ad.mainFig, 'KeyPressFcn', ad.callbacks.keyboard_response_handle);
            
            set(handles.landmarks_listbox, 'KeyPressFcn', ad.callbacks.keyboard_response_handle);
            set(handles.zoom_text, 'KeyPressFcn', ad.callbacks.keyboard_response_handle);
        end
        
        
        function [ad] = anonymize_data(ad, axiWindow, corWindow)
            %Anonymizes volumetric image data:
            %axiWindow is a 2x1 vector specifying the vertical range of data
            %between the nose tip and the top of the head. This window is specified with proportions (between 0 and 1). The first
            %component is the lower edge of this window and the second component is the upper edge of this window. A window of [0 1]
            %will not destroy anything. A window of [0.25 0.75] will destroy data that falls from 1/4 to 3/4 the way to the top of the head.
            
            %corWindow: if this argument is not empty, then the coronal
            %deletion will be restricted accordingly (see axiWindow)
            %between the sella and the upper coronal edge of the data
            try
                %Find the key landmarks
                %priors = load_key_priors(vt_template_FileName, data.img);
                
                %Locate the nose tip, top of head, and back of head
                %noseTip = util.get_prior_by_name(priors, 'nose tip');
                %{
                headTop = get_prior_by_name(priors, 'head top');
                
                %Get the distance in the axial plane between the nose tip and the top of the head
                noseh = noseTip.voxelLocation(3);
                axiDist = headTop.voxelLocation(3) - noseh;
                
                %Locate the region to destroy by its axial plane coordinates
                axiMax = size(data.img, 3);
                axiLower = max(min(noseh + round(axiWindow(1)*axiDist), axiMax), 1);
                axiUpper = max(min(noseh + round(axiWindow(2)*axiDist), axiMax), 1);
                
                corMax = size(data.img, 3);
                corLower = 1;
                corUpper = corMax;
                
                if (exist('corWindow', 'var'))
                    priorsCell = {};
                    for pIdx = 1:length(priors)
                        priorsCell{pIdx} = priors(pIdx);
                    end
                    
                    %Locate the predicted location of the sella
                    sella = load_first_order_landmarks(vt_template_FileName, priorsCell, {'sella'});
                    sellaDist = corMax - sella.voxelLocation(2);
                    corLower = max(min(sella.voxelLocation(2) + round(corWindow(1)*sellaDist), corMax), 1);
                    corUpper = max(min(sella.voxelLocation(2) + round(corWindow(2)*sellaDist), corMax), 1);
                
                end
                
                %Destroy the data (set it to 0)
                data.img(:, corLower:corUpper, axiLower:axiUpper) = 0;
                %}
                
                %ad.data.img(:, :, 153:end) = 0;
                %{
                ad.data.img(1:41, :, 1:59) = 0;
                ad.data.img(157:end, :, 1:59) = 0;
                ad.data.img(:, 1:70, 1:59) = 0;
                %ad.data.img(:, 156:end, 1:59) = 0;
                %}
                %{
                for sIdx = 1:size(ad.data.img, 1)
                    ad.data.img(sIdx, :, :) = imadjust(mat2gray(squeeze(ad.data.img(sIdx, :, :))), [0 0.1], []);
                end
                %}
                
                %{
                d = size(ad.data.img);
                ad.data.img = cat(3, zeros(d(1), d(2), 50), ad.data.img);
                d = size(ad.data.img);
                ad.data.img = cat(2, ad.data.img, zeros(d(1), 25, d(3)));
                d = size(ad.data.img);
                ad.data.img = cat(3, ad.data.img, zeros(d(1), d(2), 25));
                %}
                
                
                
                [~, name, ext] = fileparts(ad.rawDataFileName);
                ad.data.hdr.dime.dim(2:4) = size(ad.data.img);
                save_nii(ad.data, fullfile(ad.rawDataFilePath, [name '_regTarget' ext]));
            catch
                disp('Failed to anonymize data.');
            end
            
            
        end
        
        function [prior] = get_prior_by_name(priors, name)
            for pIdx = 1:length(priors)
                if (strcmp(priors(pIdx).name, name))
                    prior = priors(pIdx);
                    return;
                end
            end
        end
        
        function [voxelLocation] = convert_point_to_voxel(ad, handles, loc)
            xLim = get(handles.zoom_axes, 'XLim');
            yLim = get(handles.zoom_axes, 'YLim');
            
            xRelPos = (loc(1, 1) - xLim(1))/(xLim(2) - xLim(1));
            yRelPos = (loc(1, 2) - yLim(1))/(yLim(2) - yLim(1));
            
            rPos = get(ad.zoom.rectangle, 'Position');
            switch (ad.activePlane)
                case 'sagittal'
                    sag = ad.slices.sagittal;
                    cor = rPos(1) + rPos(3)*xRelPos;
                    axi = rPos(2) + rPos(4)*yRelPos;
                case 'coronal'
                    sag = rPos(1) + rPos(3)*xRelPos;
                    cor = ad.slices.coronal;
                    axi = rPos(2) + rPos(4)*yRelPos;
                case 'axial'
                    sag = rPos(1) + rPos(3)*xRelPos;
                    cor = rPos(2) + rPos(4)*yRelPos;
                    axi = ad.slices.axial;
            end
            
            sag = min(max(round(sag), 1), ad.dims.sagittal.number);
            cor = min(max(round(cor), 1), ad.dims.coronal.number);
            axi = min(max(round(axi), 1), ad.dims.axial.number);
            voxelLocation = [sag cor axi];
        end
        
        function [pos] = convert_voxel_to_point(ad, handles, voxelLocation)
            xLim = get(handles.zoom_axes, 'XLim');
            yLim = get(handles.zoom_axes, 'YLim');
            
            rPos = get(ad.zoom.rectangle, 'Position');
            xRelPos = (voxelLocation(1) - rPos(1))/rPos(3);
            yRelPos = (voxelLocation(2) - rPos(2))/rPos(4);
            
            xPos = xRelPos*(xLim(2) - xLim(1)) + xLim(1);
            yPos = yRelPos*(yLim(2) - yLim(1)) + yLim(1);
            pos = [xPos yPos];
        end
        
        %==========================================================================
        %PLOTTING FUNCTIONS
        %==========================================================================
        function [] = update_plot(plane, ad, handles)
            img_slice = util.get_image_slice(plane, ad);
            try
                set(ad.images.(plane), 'cdata', img_slice');
                if (isfield(ad, 'clim'))
                    set(handles.([plane '_axes']), 'clim', ad.clim);
                else
                    set(handles.([plane '_axes']), 'clim', [0 255]);
                end
                
                set(handles.([plane '_text']), 'String', [regexprep(plane, '(\<[a-z])','${upper($1)}') ' View: Slice ' num2str(ad.slices.(plane))]);
                set(handles.([plane '_axes']), 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
            catch
                tim = 1;
            end
            %{
            switch (plane)
                case {'coronal', 'axial'}
                    %Set the coronal and axial plots to have uniform axis scaling
                    set(handles.([plane '_axes']), 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
            end
            %}
        end
        
        function [] = plot_all(ad, handles)
            util.update_plot('coronal', ad, handles);
            util.update_plot('sagittal', ad, handles);
            util.update_plot('axial', ad, handles);
        end
        
        function [ad] = reset_plot(ad, plane, handles, loc)
            warning ('off','all');
            axes(handles.([plane '_axes']));
            warning ('on','all');
            try
                set(handles.([plane '_axes']), 'XLim', [1 ad.dims.(plane).x], 'YLim', [1 ad.dims.(plane).y]);
            catch
            end
            
            set(handles.([plane '_axes']), 'DataAspectRatio', [1 1 1]);
            
            if (isfield(ad, 'data'))
                img_slice = util.get_image_slice(plane, ad);
                ad.images.(plane) = imagesc(img_slice');
            end
            
            set(handles.([plane '_axes']), 'YDir', 'normal', 'XTick', [], 'YTick', [], 'clim', [0 255]);
            switch (plane)
                case {'coronal', 'axial'}
                    %Set the coronal and axial plots to have uniform axis scaling
                    set(handles.([plane '_axes']), 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
            end
            ad.xhairs.(plane) = util.crosshairs(ad.xhairs.(plane), handles.([plane '_axes']), loc);
            
        end
        
        function [img_slice] = get_image_slice(plane, ad)
            img_slice = [];
            switch (plane)
                case 'sagittal'
                    img_slice = squeeze(ad.data.img(max(floor(ad.slices.sagittal), 1), :, :, :, ad.setscanid));
                case 'coronal'
                    img_slice = squeeze(ad.data.img(:, max(ad.slices.coronal, 1), :, :, ad.setscanid));
                case 'axial'
                    img_slice = squeeze(ad.data.img(:, :, max(ad.slices.axial, 1), :, ad.setscanid));
            end
        end
        
        function [xhairs] = crosshairs(xhairs, handle, loc)
            if ~isempty(loc)
                if (isempty(xhairs))
                    axes(handle);
                    x_range = get(handle, 'xlim');
                    y_range = get(handle, 'ylim');
                    
                    xhairs.lx = line('xdata', x_range, 'ydata', [loc(2) loc(2)], 'zdata', [11 11], 'color', [1 0 0], 'hittest', 'off');
                    xhairs.ly = line('xdata', [loc(1) loc(1)], 'ydata', y_range, 'zdata', [11 11], 'color', [1 0 0], 'hittest', 'off');
                else
                    if (ishandle(xhairs.lx)), set(xhairs.lx, 'ydata', [loc(2) loc(2)]); end;
                    if (ishandle(xhairs.ly)), set(xhairs.ly, 'xdata', [loc(1) loc(1)]); end;
                    set(handle, 'selected', 'on');
                    set(handle, 'selected', 'off');
                end
            end
        end
        
        function [ad] = adjust_color_maps(ad, handles)
            %disp('color maps adjusted');
            try
                lowContrastVal = get(handles.low_contrast_slider, 'value');
                highContrastVal = get(handles.high_contrast_slider, 'value');%1.0 - (255 - (get(handles.contrast_slider, 'value') - 1))/ (255 + 1);
                lowBrightVal = get(handles.low_brightness_slider, 'Value');
                highBrightVal = get(handles.high_brightness_slider, 'Value');
                
                ad.color_map = imadjust(ad.default_color_map, [lowContrastVal highContrastVal], [lowBrightVal highBrightVal]);
                set(ad.mainFig, 'colormap', ad.color_map);
            catch
                set(handles.message_text, 'String', 'Message: Illegal contrast values.');
            end
        end
        
        
        %==========================================================================
        %ZOOM PLOT FUNCTIONS
        %==========================================================================
        
        function [ad] = reset_zoom_plot(ad, plane, zoom_axes)
            %disp('reset zoom plot');
            if (isfield(ad, 'zoom'))
                if (isfield(ad.zoom, 'rectangle'))
                    if (ishandle(ad.zoom.rectangle))
                        delete(ad.zoom.rectangle);
                    end
                end
                
                if (isfield(ad.zoom, 'xhairs'))
                    if (ishandle(ad.zoom.xhairs.lx))
                        delete(ad.zoom.xhairs.lx);
                    end
                    if (ishandle(ad.zoom.xhairs.ly))
                        delete(ad.zoom.xhairs.ly);
                    end
                end
            end
            
            img_slice = util.get_image_slice(plane, ad);
            
            zoom = struct();
            zoom.x_dim = size(img_slice, 1);
            zoom.y_dim = size(img_slice, 2);
            zoom.x_hWindow = min(floor(zoom.x_dim*ad.zoomFactor), floor(zoom.x_dim*0.5));
            zoom.y_hWindow = min(floor(zoom.y_dim*ad.zoomFactor), floor(zoom.y_dim*0.5)); %*ad.zoomPlotRatio), zoom.y_dim);
            zoom.rectangle = [];
            zoom.xhairs = [];
            
            if (~isfield(ad, 'zoom'))
                %disp('new zoom image');
                axes(zoom_axes);
                if (isfield(ad, 'clim'))
                    zoom.image = imagesc(zeros(zoom.x_hWindow*2, zoom.y_hWindow*2)', ad.clim);
                else
                    zoom.image = imagesc(zeros(zoom.x_hWindow*2, zoom.y_hWindow*2)');%, ad.clim);
                end
            else
                set(ad.zoom.image, 'CData', zeros(zoom.x_hWindow*2, zoom.y_hWindow*2)');
                set(zoom_axes, 'XLim', [1 zoom.x_hWindow*2], 'YLim', [1 zoom.y_hWindow*2]);
                zoom.image = ad.zoom.image;
            end
            
            loc = ad.currentLocation;
            
            %Create zoom rectangle
            axes(ad.activeAxes);
            [minX, ~, minY, ~] = util.calculate_zoom_rectangle(zoom, loc, img_slice);
            zoom.rectangle = rectangle('Position', [minX minY zoom.x_hWindow*2 zoom.y_hWindow*2], 'EdgeColor', [1 1 1]);
            
            %Create zoom crosshairs
            axes(zoom_axes);
            x_range = get(zoom_axes, 'xlim');
            y_range = get(zoom_axes, 'ylim');
            
            zoom.xhairs.lx = line('xdata', x_range, 'ydata', [loc(2) loc(2)], 'zdata', [11 11], 'color', [1 0 0], 'hittest', 'off');
            zoom.xhairs.ly = line('xdata', [loc(1) loc(1)], 'ydata', y_range, 'zdata', [11 11], 'color', [1 0 0], 'hittest', 'off');
            
            if (isfield(ad, 'clim'))
                set(zoom_axes, 'YDir', 'normal', 'ClimMode', 'manual', 'XTick', [], 'YTick', [], 'CLim', ad.clim);
            else
                set(zoom_axes, 'YDir', 'normal', 'ClimMode', 'manual', 'XTick', [], 'YTick', [], 'CLim', [0 255]);
            end
            
            set(zoom_axes, 'DataAspectRatio', [1 1 1]);
            ad.zoom = zoom;
        end
        
        function [minX, maxX, minY, maxY] = calculate_zoom_rectangle(zoom, loc, img_slice)
            minX = loc(1) - zoom.x_hWindow;
            maxX = loc(1) + zoom.x_hWindow;
            
            minY = loc(2) - zoom.y_hWindow;
            maxY = loc(2) + zoom.y_hWindow;
            
            
            
            %Preserve zoom window size
            if (maxX > zoom.x_dim)
                minX = zoom.x_dim - 2*zoom.x_hWindow;
                maxX = zoom.x_dim;
            elseif (minX < 1)
                maxX = loc(1) + zoom.x_hWindow - (1 - loc(1) - zoom.x_hWindow);
                minX = 1;
            end
            
            if (maxY > zoom.y_dim)
                minY = zoom.y_dim - 2*zoom.y_hWindow;
                maxY = zoom.y_dim;
            elseif (minY < 1)
                maxY = loc(2) + zoom.y_hWindow - (1 - loc(2) - zoom.y_hWindow);
                minY = 1;
            end
            
            minX = max(minX, 1);
            minY = max(minY, 1);
            
            maxX = min(maxX, size(img_slice, 1));
            maxY = min(maxY, size(img_slice, 2));
            
            
        end
        
        function [ad] = update_zoom(ad, handles)
            %disp('update zoom');
            img_slice = util.get_image_slice(ad.activePlane, ad);
            loc = ad.currentLocation;
            if (~isempty(loc) && ~isempty(img_slice))
                [minX, maxX, minY, maxY] = util.calculate_zoom_rectangle(ad.zoom, loc, img_slice);
                
                if (~isempty(ad.zoom.image) && ishandle(ad.zoom.image))
                    set(ad.zoom.image, 'cdata', img_slice(minX:maxX, minY:maxY)');
                    
                    if (isfield(ad, 'clim'))
                        set(handles.zoom_axes, 'clim', ad.clim);
                    else
                        set(handles.zoom_axes, 'clim', [0 255]);
                    end
                end
                
                %Draw zoom rectangle
                if ishandle(ad.zoom.rectangle)
                    set(ad.zoom.rectangle, 'Parent', ad.activeAxes);
                    set(ad.zoom.rectangle, 'Position', [minX minY ad.zoom.x_hWindow*2 ad.zoom.y_hWindow*2]);
                    
                    if (~get(handles.delay_rendering_checkbox, 'Value'))
                        ad = util.draw_selected_landmark(ad, handles);
                    end
                end
                
                %Draw zoom cross-hairs
                if (ishandle(ad.zoom.xhairs.lx) && ishandle(ad.zoom.xhairs.ly))
                    loc = util.convert_voxel_to_point(ad, handles, ad.currentLocation);
                    set(ad.zoom.xhairs.lx, 'ydata', [loc(2) loc(2)]);
                    set(ad.zoom.xhairs.ly, 'xdata', [loc(1) loc(1)]);
                end
                
                %Update zoom text
                currentLandmark = ' ';
                currentPlane = ' ';
                if (isfield(ad, 'landmarks'))
                    if (~isempty(ad.landmarks))
                        selIdx = get(handles.landmarks_listbox, 'Value');
                        currentLandmark = ad.landmarks{selIdx}.name;
                    end
                end
                
                if (~isempty(ad.activePlane))
                    currentPlane = ad.activePlane;
                end
                set(handles.zoom_text, 'String', ['Zoom: ' currentPlane ' ' currentLandmark]);
                
            end
        end
        
        function [ad] = hide_landmark(ad, currentIdx)
            if (isfield(ad, 'landmarks'))
                if (currentIdx <= length(ad.landmarks))
                    ad.landmarks{currentIdx}.hide();
                end
            end
        end
        
        
        function [ad] = hide_landmarks(ad, handles, currentIdx)
            if (isfield(ad, 'landmarks'))
                if (~isempty(ad.landmarks) && ~isempty(ad.activePlane))
                    
                    for lmIdx = 1:length(ad.landmarks)
                        ad.landmarks{lmIdx} = ad.landmarks{lmIdx}.hide();
                    end
                end
            end
            ad.landmarksHiddenFlag = true;
        end
        
        
        %==========================================================================
        %INTERACTION FUNCTIONS
        %==========================================================================
        function [ad] = move_to(ad, voxelLocation)
            if (isfield(ad, 'data'))
                handles = guidata(ad.mainFig);
                
                ad.slices.sagittal = max(voxelLocation(1), 1);
                ad.slices.coronal = max(voxelLocation(2), 1);
                ad.slices.axial = max(voxelLocation(3), 1);
                
                if (~isempty(ad.activePlane))
                    switch (ad.activePlane)
                        case 'sagittal'
                            ad.currentLocation = [ad.slices.coronal ad.slices.axial];
                        case 'coronal'
                            ad.currentLocation = [ad.slices.sagittal ad.slices.axial];
                        case 'axial'
                            ad.currentLocation = [ad.slices.sagittal ad.slices.coronal];
                    end
                end
                
                ad.pos.voxel = [ad.slices.sagittal, ad.slices.coronal, ad.slices.axial];
                ad.pos.mm = (ad.pos.voxel - ad.origin).*ad.voxel_size;
                
                %Update location text
                set(handles.cursor_x_text, 'String', ['Sag = ' num2str(ad.pos.mm(1), '%.1f') ' mm']);
                set(handles.cursor_y_text, 'String', ['Cor = ' num2str(ad.pos.mm(2), '%.1f') ' mm']);
                set(handles.cursor_z_text, 'String', ['Axi = ' num2str(ad.pos.mm(3), '%.1f') ' mm']);
                
                %Update crosshairs
                ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, ad.pos.voxel([2 3]));
                ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, ad.pos.voxel([1 3]));
                ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, ad.pos.voxel([1 2]));
                
                %Update sliders
                set(handles.sagittal_slider, 'Value', ad.slices.sagittal);
                set(handles.coronal_slider, 'Value', ad.slices.coronal);
                set(handles.axial_slider, 'Value', ad.slices.axial);
                
                util.plot_all(ad, guidata(ad.mainFig));
                
                ad = util.update_coordinates(ad, handles);
                ad = util.update_zoom(ad, handles);
                
                
                if (~isempty(ad.landmarks))
                    selLandmarkIdx = get(handles.landmarks_listbox, 'Value');
                    set(handles.message_text, 'String', ['Message: current landmark is ' ad.landmarks{selLandmarkIdx}.name]);
                else
                    set(handles.message_text, 'String', 'Message: ');
                end
                
            end
        end
        
        
        function [ad] = update_coordinates(ad, handles)
            ad.hoverAxes = [];
            sagittal = ad.slices.sagittal;
            coronal = ad.slices.coronal;
            axial = ad.slices.axial;
            currentLocation = [];
            
            if (~isempty(ad.hoverPlane))
                hover = ad.hoverPlane;
                if (strcmp(ad.hoverPlane, 'zoom'))
                    hover = ad.activePlane;
                end
                
                switch hover
                    case 'sagittal'
                        currentLocation = get(handles.sagittal_axes, 'CurrentPoint');
                        if (strcmp(ad.hoverPlane, 'zoom'))
                            currentLocation = get(handles.zoom_axes, 'CurrentPoint');
                        end
                        
                        coronal = max(min(round(currentLocation(1,1)), ad.dims.(hover).x), 1);
                        axial =  max(min(round(currentLocation(1,2)), ad.dims.(hover).y), 1);
                        ad.hoverAxes = handles.sagittal_axes;
                        currentLocation = [coronal axial];
                    case 'coronal'
                        currentLocation = get(handles.coronal_axes, 'CurrentPoint');
                        if (strcmp(ad.hoverPlane, 'zoom'))
                            currentLocation = get(handles.zoom_axes, 'CurrentPoint');
                        end
                        sagittal =  max(min(round(currentLocation(1,1)), ad.dims.(hover).x), 1);
                        axial =  max(min(round(currentLocation(1,2)), ad.dims.(hover).y), 1);
                        ad.hoverAxes = handles.coronal_axes;
                        currentLocation = [sagittal axial];
                    case 'axial'
                        currentLocation = get(handles.axial_axes, 'CurrentPoint');
                        if (strcmp(ad.hoverPlane, 'zoom'))
                            currentLocation = get(handles.zoom_axes, 'CurrentPoint');
                        end
                        sagittal = max(min(round(currentLocation(1,1)), ad.dims.(hover).x), 1);
                        coronal = max(min(round(currentLocation(1,2)), ad.dims.(hover).y), 1);
                        ad.hoverAxes = handles.axial_axes;
                        currentLocation = [sagittal coronal];
                end
                
                if (strcmp(ad.hoverPlane, 'zoom'))
                    ad.hoverAxes = handles.zoom_axes;
                    
                end
                
                voxel = [sagittal, coronal, axial];
                mm = (voxel - ad.origin).*ad.voxel_size;
                
                %Update location text
                set(handles.cursor_x_text, 'String', ['Sag = ' num2str(mm(1), '%.1f') ' mm']);
                set(handles.cursor_y_text, 'String', ['Cor = ' num2str(mm(2), '%.1f') ' mm']);
                set(handles.cursor_z_text, 'String', ['Axi = ' num2str(mm(3), '%.1f') ' mm']);
                
                if (ad.mouseDownFlag && ~isempty(currentLocation) && ~strcmp(ad.hoverPlane, 'zoom'))
                    ad.activePlane = ad.hoverPlane;
                    ad.activeAxes = ad.hoverAxes;
                    ad.slices.sagittal = sagittal;
                    ad.slices.coronal = coronal;
                    ad.slices.axial = axial;
                    
                    ad.currentLocation = currentLocation;
                    ad.pos.voxel = voxel;
                    ad.pos.mm = mm;
                    
                    %Update crosshairs
                    ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
                    ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
                    ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
                    
                    %Update sliders
                    set(handles.sagittal_slider, 'Value', ad.slices.sagittal);
                    set(handles.coronal_slider, 'Value', ad.slices.coronal);
                    set(handles.axial_slider, 'Value', ad.slices.axial);
                    
                end
            end
        end
        
        %==========================================================================
        %LANDMARK FUNCTIONS
        %==========================================================================
        function [ad] = create_new_point_landmark(name, initialPos, ad, handles)
            if (~isempty(name))
                index = length(ad.landmarks) + 1;
                ad.landmarks = [ad.landmarks {point_landmark(name, initialPos, ad.origin, ad.voxel_size, handles, index, [])}];
            end
        end
        
        function [ad] = create_new_semi_landmark(name, initialPos, ad, handles)
            if (~isempty(name))
                index = length(ad.landmarks) + 1;
                ad.landmarks = [ad.landmarks {semi_landmark(name, initialPos, ad.origin, ad.voxel_size, ad.activePlane, handles, index, [], [])}];
            end
        end
        
        function [ad] = recreate_point_landmark(ad, handles, plm)
            index = length(ad.landmarks) + 1;
            newPLM = point_landmark(plm.name, [0 0], ad.origin, ad.voxel_size, handles, index, plm);
            ad.landmarks = [ad.landmarks {newPLM}];
        end
        
        function [ad] = recreate_semi_landmark(ad, handles, slm)
            index = length(ad.landmarks) + 1;
            newSLM = semi_landmark(slm.name, zeros(length(slm.mpoint_handles), 2), ad.origin, ad.voxel_size, '', handles, index, slm, []);
            ad.landmarks = [ad.landmarks {newSLM}];
        end
        
        function [ad] = draw_selected_landmark(ad, handles)
            selIdx = get(handles.landmarks_listbox, 'Value');
            
            if (~isempty(ad.landmarks))
                ad.landmarks{selIdx}.redraw(ad.slices, ad.activePlane, ad.zoom, handles.zoom_axes);
            end
            
        end
        
        function [ad] = draw_landmarks(ad, handles)
            %disp('drawing landmarks');
            % util.reset_callbacks(ad, handles);
            if (isfield(ad, 'landmarks'))
                if (~isempty(ad.landmarks) && ~isempty(ad.activePlane))
                    
                    for lmIdx = 1:length(ad.landmarks)
                        ad.landmarks{lmIdx} = ad.landmarks{lmIdx}.redraw(ad.slices, ad.activePlane, ad.zoom, handles.zoom_axes);
                    end
                end
            end
            ad.landmarksHiddenFlag = false;
        end
        
        function [ad] = refresh_landmark_list(ad)
            %disp('refreshing landmark list');
            handles = guidata(ad.mainFig);
            %util.reset_callbacks(ad, handles);
            landmarkList = [];
            pnTypes = get(handles.prenamed_point_landmark_menu, 'String');
            for pnTypeIdx = 1:length(ad.activePointLandmarkNames)
                pnTypes{pnTypeIdx} = ['<HTML><FONT color="black">' ad.activePointLandmarkNames{pnTypeIdx} '</Font></html>'];
            end
            
            if (isfield(ad, 'landmarks'))
                if (~isempty(ad.landmarks) && ~isempty(ad.activePlane))
                    for lmIdx = 1:length(ad.landmarks)
                        landmarkList = [landmarkList {[ad.landmarks{lmIdx}.name ' (' num2str(ad.landmarks{lmIdx}.index) ')']}];
                        
                        %Check if the landmark is in the prenamed point landmark list and color this red if it is otherwise color it black
                        for pnTypeIdx = 1:length(ad.activePointLandmarkNames)
                            if (strcmp(ad.landmarks{lmIdx}.name, ad.activePointLandmarkNames{pnTypeIdx}))
                                pnTypes{pnTypeIdx} = ['<HTML><FONT color="red">' ad.activePointLandmarkNames{pnTypeIdx} '</Font></html>'];
                            end
                        end
                    end
                    selIdx = get(handles.landmarks_listbox, 'Value');
                    set(handles.landmark_confidence_slider, 'Value', ad.landmarks{selIdx}.getConfidence());
                    set(handles.landmark_confidence_text, 'String', ['Landmark Confidence: ' num2str(ad.landmarks{selIdx}.getConfidence()*100.0, '%.0f') '%']);
                end
            end
            %set(handles.landmarks_listbox, 'Value', 1);
            set(handles.prenamed_point_landmark_menu, 'String', pnTypes);
            set(handles.landmarks_listbox, 'String', landmarkList);
        end
    end
end