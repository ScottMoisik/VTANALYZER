function [ad] = open_data(fullFileName, ad, handles)

[path, name, ext] = fileparts(fullFileName);
ext = lower(ext);


switch (ext)
    case '.dcb' %Opens a DICOM scan stored as a 'DICOM blob' produced by dicombrowse.m
        ad = open_dcb(ad, fullFileName);
    case '.img'
        ad = open_img(ad, fullFileName);
    case '.nii' %Opens a NIFTI file
        ad = open_nii(ad, fullFileName);
    case {'.lmd', '.nlm'}  %Opens a landmark data (LMD) file produced by vtanalzer.m
        ad = open_landmarks(ad, fullFileName);
    case {'.jpg', '.jpeg', '.png', '.tif', '.tiff'}
        ad.isImageDataFlag = 1;
        ad = open_image(ad, fullFileName);
end

    function [ad] = reset(ad)
        global currentIdx;
        currentIdx = 1;
        
        %Reset certain properties of the appdata
        ad.xhairs.coronal = [];
        ad.xhairs.sagittal = [];
        ad.xhairs.axial = [];
        ad.color_map = gray(256);
        ad.default_color_map = gray(256);
        set(gcf, 'colormap', ad.color_map);
        
        %Update sliders
        sagDim = ad.dims.sagittal.number;
        corDim = ad.dims.coronal.number;
        axiDim = ad.dims.axial.number;
        
        if (sagDim > 1)
            set(handles.sagittal_slider, 'Value', 1, 'Min', 1, 'Max', sagDim, 'SliderStep', [1/(sagDim) 1.00001/(sagDim)]);
        else
            set(handles.sagittal_slider, 'Enable', 'off');
        end
        
        set(handles.coronal_slider, 'Value', 1, 'Min', 1, 'Max', corDim, 'SliderStep', [1/(corDim) 1.00001/(corDim)]);
        set(handles.axial_slider, 'Value', 1, 'Min', 1, 'Max', axiDim, 'SliderStep', [1/(axiDim) 1.00001/(axiDim)]);
        set(handles.zoom_slider, 'Value', ad.zoomFactorDefault, 'Min', ad.zoomMin, 'Max', ad.zoomMax, 'SliderStep', [(ad.zoomMax - ad.zoomMin) (ad.zoomMax - ad.zoomMin)]);
        set(handles.landmark_confidence_slider, 'Value', 1);
        set(handles.landmark_confidence_text, 'String', ['Landmark Confidence: ' num2str(100.0, '%.0f') '%']);
        
        %Reset buttons
        set(handles.load_key_landmarks_button, 'Enable', 'on');
        set(handles.load_first_order_button, 'Enable', 'on');
        set(handles.load_second_order_button, 'Enable', 'on');

        %Define primary callback functions
        util.reset_callbacks(ad, handles);
        
        %Reset all plots
        %[ad] = util.adjust_color_maps(ad, handles);
        ad = util.reset_plot(ad, 'sagittal', handles, ad.pos.voxel([2 3]));
        ad = util.reset_plot(ad, 'coronal', handles, ad.pos.voxel([1 3]));
        ad = util.reset_plot(ad, 'axial', handles, ad.pos.voxel([1 2]));
        
        %Populate file lists
        rawDataList = dir(fullfile(ad.rawDataFilePath, '*.nii'));
        rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.dcb'))];
        rawDataList = [rawDataList; dir(fullfile(ad.rawDataFilePath, '*.img'))];
        
        if (ad.isImageDataFlag)
            rawDataList = [dir(fullfile(ad.rawDataFilePath, '*.jpg')); dir(fullfile(ad.rawDataFilePath, '*.png')); dir(fullfile(ad.rawDataFilePath, '*.tif'))];
        end
        
        lmDataList = dir(fullfile(ad.landmarksFilePath, '*.nlm'));
        lmDataList = [lmDataList; dir(fullfile(ad.landmarksFilePath, '*.lmd'))];
        
        util.populate_file_list(rawDataList, ad.rawDataFileName, handles.raw_data_files_listbox, handles.raw_data_files_text, 'Raw Data Files: ');
        util.populate_file_list(lmDataList, ad.landmarksFileName, handles.lmd_files_listbox, handles.landmark_files_text, 'Landmark Data (LMD) Files: ');
        
        ad = util.refresh_landmark_list(ad);
        set(handles.prenamed_point_landmark_menu, 'Value', 1);
        set(handles.prenamed_semi_landmark_menu, 'Value', 1);
        
        centerVoxel = [max(floor(ad.dims.sagittal.number*0.5), 1) max(floor(ad.dims.coronal.number*0.5), 1) max(floor(ad.dims.axial.number*0.5), 1)];
        ad.activeAxes = handles.sagittal_axes;
        ad.activePlane = 'sagittal';
        ad.currentLocation = [centerVoxel(2) centerVoxel(3)];
        
        
        ad = util.reset_zoom_plot(ad, 'sagittal', handles.zoom_axes);
        ad = util.move_to(ad, centerVoxel);
        ad = util.adjust_color_maps(ad, handles);
    end

    %OPEN DCB FILE (DICOM DATABLOB FILE)
    %====================================
    function [ad] = open_dcb(ad, fileName)
        try
            %The input is a dicomDataBlob.dcb file. Parse it as such
            dcb = load(fileName, '-mat');
            
            %Store NIFTI in app data and set initial values
            ad.setscanid = 1;
            minvalue = double(dcb.img(:,:,:,ad.setscanid));
            minvalue = min(minvalue(~isnan(minvalue)));
            maxvalue = double(dcb.img(:,:,:,ad.setscanid));
            maxvalue = max(maxvalue(~isnan(maxvalue)));
            
            ad.clim = [minvalue maxvalue];
            
            sagittalDim = size(dcb.img, 1);
            coronalDim = size(dcb.img, 2);
            axialDim = size(dcb.img, 3);
            
            ad.dims.sagittal.x = coronalDim; ad.dims.sagittal.y = axialDim; ad.dims.sagittal.number = sagittalDim;
            ad.dims.coronal.x = sagittalDim; ad.dims.coronal.y = axialDim; ad.dims.coronal.number = coronalDim;
            ad.dims.axial.x = sagittalDim; ad.dims.axial.y = coronalDim; ad.dims.axial.number = axialDim;
            ad.activePlane = 'sagittal';
            ad.activeAxes = handles.sagittal_axes;
            ad.hoverPlane = [];
            ad.hoverAxes = [];
            ad.currentLocation = [];
            ad.planeSwitchFlag = 1;
            
            ad.slices.sagittal = max(floor(sagittalDim*0.5), 1);
            ad.slices.coronal = max(floor(coronalDim*0.5), 1);
            ad.slices.axial = max(floor(axialDim*0.5), 1);
                        
            %Delete any landmarks (which contain graphics objects) before proceeding
            if (~isempty(ad.landmarks))
                for lmIdx = 1:length(ad.landmarks)
                    ad.landmarks{lmIdx}.delete();
                end
            end
            set(handles.landmarks_listbox, 'String', {' '});
            set(handles.landmarks_listbox, 'Value', 1);
            ad.landmarks = [];
            
            fovX = dcb.header.PixelSpacing(1)*dcb.header.Rows;
            fovY = dcb.header.PixelSpacing(2)*dcb.header.Columns;
            voxelX = double(fovX)/double(dcb.header.AcquisitionMatrix(2));
            voxelY = double(fovY)/double(dcb.header.AcquisitionMatrix(3));
            voxelZ = dcb.header.SliceThickness;
            
            s = max(floor(sagittalDim*0.5), 1);
            c = max(floor(coronalDim*0.5), 1);
            a = max(floor(axialDim*0.5), 1);
            ad.origin = [s c a];
            ad.voxel_size = [voxelZ voxelX voxelY];		% vol in mm (sag-cor-axi), z used as x-axis (sagittal) because of midsagittal orientation of most ArtiVark scans
            
            ad.pos.voxel = [ad.slices.sagittal, ad.slices.coronal, ad.slices.axial];
            ad.pos.mm = (ad.pos.voxel - ad.origin).*ad.voxel_size;
            
            ad.data = dcb;
            ad = reset(ad);
            set(handles.message_text, 'String', 'Message: Successfully loaded DCB file.');
        catch
            set(handles.message_text, 'String', 'Message: Failed to load IMAGE file.');
        end
    end


    %OPEN IMG-HDR FILE PAIR
    %====================================
    function [ad] = open_img(ad, fileName)
        try
            %The input is a IMG-HDR file pair. This requires the Image Processing Toolbox
            [fPath, fName, fExt] = fileparts(fileName); 
            
            try
                %i = robot;
                metadata = analyze75info([fPath '\' fName '.hdr']);
                dcb = analyze75read(metadata);
                %dcb = flip(permute(dcb, [2 3 1]), 2);
                dcb = permute(dcb, [2 3 1]);
                dcb = fliplr(dcb);
                
                
            catch
                %metadata = analyze75info([fPath '\' fName '.hdr']);
                [dcb, pixdim, dtype] = readanalyze([fPath '\' fName '.hdr']);
                
                metadata.PixelDimensions = pixdim(2:4)'; 
                metadata.Height = size(dcb, 1);
                metadata.Width = size(dcb, 2);
                dcb = flip(permute(dcb, [1 3 2]), 2);
                %fovY = double(metadata.PixelDimensions(2))*double(metadata.Width
            end
            
            
            
            %Store NIFTI in app data and set initial values
            ad.setscanid = 1;
            minvalue = double(dcb);
            minvalue = min(minvalue(~isnan(minvalue)));
            maxvalue = double(dcb);
            maxvalue = max(maxvalue(~isnan(maxvalue)));
            
            ad.clim = [minvalue maxvalue];
            
            sagittalDim = size(dcb, 1);
            coronalDim = size(dcb, 2);
            axialDim = size(dcb, 3);
            
            ad.dims.sagittal.x = coronalDim; ad.dims.sagittal.y = axialDim; ad.dims.sagittal.number = sagittalDim;
            ad.dims.coronal.x = sagittalDim; ad.dims.coronal.y = axialDim; ad.dims.coronal.number = coronalDim;
            ad.dims.axial.x = sagittalDim; ad.dims.axial.y = coronalDim; ad.dims.axial.number = axialDim;
            ad.activePlane = 'sagittal';
            ad.activeAxes = handles.sagittal_axes;
            ad.hoverPlane = [];
            ad.hoverAxes = [];
            ad.currentLocation = [];
            ad.planeSwitchFlag = 1;
            
            ad.slices.sagittal = max(floor(sagittalDim*0.5), 1);
            ad.slices.coronal = max(floor(coronalDim*0.5), 1);
            ad.slices.axial = max(floor(axialDim*0.5), 1);
                        
            %Delete any landmarks (which contain graphics objects) before proceeding
            if (~isempty(ad.landmarks))
                for lmIdx = 1:length(ad.landmarks)
                    ad.landmarks{lmIdx}.delete();
                end
            end
            set(handles.landmarks_listbox, 'String', {' '});
            set(handles.landmarks_listbox, 'Value', 1);
            ad.landmarks = [];
            
            fovX = double(metadata.PixelDimensions(1))*double(metadata.Height);
            fovY = double(metadata.PixelDimensions(2))*double(metadata.Width);
            voxelX = double(metadata.PixelDimensions(1));
            voxelY = double(metadata.PixelDimensions(2));
            voxelZ = double(metadata.PixelDimensions(3));
            
            s = max(floor(sagittalDim*0.5), 1);
            c = max(floor(coronalDim*0.5), 1);
            a = max(floor(axialDim*0.5), 1);
            ad.origin = [s c a];
            ad.voxel_size = [voxelZ voxelX voxelY];		% vol in mm (sag-cor-axi), z used as x-axis (sagittal) because of midsagittal orientation of most ArtiVark scans
            
            ad.pos.voxel = [ad.slices.sagittal, ad.slices.coronal, ad.slices.axial];
            ad.pos.mm = (ad.pos.voxel - ad.origin).*ad.voxel_size;
            
            ad.data.img = dcb;
            ad = reset(ad);
            set(handles.message_text, 'String', 'Message: Successfully loaded DCB file.');
        catch
            set(handles.message_text, 'String', 'Message: Failed to load IMAGE file.');
        end
    end

    %OPEN NII FILE (NIFTI FILE)
    %====================================
    function [ad] = open_nii(ad, fileName)
        
        %Read the dataset header
        [nii.hdr, nii.filetype, nii.fileprefix, nii.machine] = nii_load_hdr(fileName);
        
        %Read the dataset body
        [nii.img,nii.hdr] = nii_load_img(nii.hdr, nii.filetype, nii.fileprefix, nii.machine);
        
        %Read NIFTI data (NIFTI data format can be found on: http://nifti.nimh.nih.gov)
        nii = nii_xform(nii, 1.0);
        
        %Store NIFTI in app data and set initial values
        ad.setscanid = 1;
        minvalue = double(nii.img(:,:,:,ad.setscanid));
        minvalue = min(minvalue(~isnan(minvalue)));
        maxvalue = double(nii.img(:,:,:,ad.setscanid));
        maxvalue = max(maxvalue(~isnan(maxvalue)));
        
        ad.clim = [minvalue maxvalue];
        
        sagittalDim = size(nii.img, 1);
        coronalDim = size(nii.img, 2);
        axialDim = size(nii.img, 3);
        
        ad.dims.sagittal.x = coronalDim; ad.dims.sagittal.y = axialDim; ad.dims.sagittal.number = sagittalDim;
        
        ad.dims.coronal.x = sagittalDim; ad.dims.coronal.y = axialDim; ad.dims.coronal.number = coronalDim;
        ad.dims.axial.x = sagittalDim; ad.dims.axial.y = coronalDim; ad.dims.axial.number = axialDim;
        ad.activePlane = 'sagittal';
        ad.activeAxes = handles.sagittal_axes;
        ad.hoverPlane = [];
        ad.hoverAxes = [];
        ad.currentLocation = [];
        ad.planeSwitchFlag = 1;
        
        %Delete any landmarks (which contain graphics objects) before proceeding
        if (~isempty(ad.landmarks))
            for lmIdx = 1:length(ad.landmarks)
                ad.landmarks{lmIdx}.delete();
            end
        end
        set(handles.landmarks_listbox, 'String', {' '});
        set(handles.landmarks_listbox, 'Value', 1);
        ad.landmarks = [];
        
        ad.origin = round(abs(nii.hdr.hist.originator(1:3)));
        ad.voxel_size = abs(nii.hdr.dime.pixdim(2:4));		% vol in mm
        %ad.voxel_size = [ad.voxel_size(1) ad.voxel_size(3) ad.voxel_size(2)];
        ad.pos.voxel = [ad.slices.sagittal, ad.slices.coronal, ad.slices.axial];
        ad.pos.mm = (ad.pos.voxel - ad.origin).*ad.voxel_size;
        
        ad.data = nii;
        ad = reset(ad);
    end


    %OPEN LMD FILE (Landmark data FILE)
    %====================================
    function [ad] = open_landmarks(ad, fileName)
        try
            savedData = load(fileName, '-mat');
            sd = savedData.saveData;
            if exist(fullfile(sd.rawDataFilePath, sd.rawDataFileName), 'file') == 2
                ad.rawDataFilePath = sd.rawDataFilePath;
                ad.landmarksFilePath = sd.landmarksFilePath;
                ad.rawDataFileName = sd.rawDataFileName;
                ad.landmarksFileName = sd.landmarksFileName;
                
                ad = do_load(ad);
            else
                %Try to find the raw data file in the current directory
                [suspectedPath, ~, ~] = fileparts(fileName);
                dirContents = dir(suspectedPath);
                
                dataIdx = find(cellfun(@(name) strcmp(sd.rawDataFileName, name), {dirContents.name}), 1);
                if (~isempty(dataIdx))
                    ad.rawDataFilePath = suspectedPath;
                    ad.landmarksFilePath = suspectedPath;
                    ad.rawDataFileName = sd.rawDataFileName;
                    ad.landmarksFileName = sd.landmarksFileName;
                    
                    ad = do_load(ad);
                    
                else
                    rawDataFilePath = uigetdir(suspectedPath, 'Could not locate raw data file, please locate its directory');% ( {'*.nii', 'NIFTI Files'; '*.dcb', 'DICOM Blob Files'; '*.*', 'All Files'}, 'Could not automatically locate the raw data file. Please locate it...', ad.rawDataFilePath);
                    dirContents = dir(rawDataFilePath);
                
                    dataIdx = find(cellfun(@(name) strcmp(sd.rawDataFileName, name), {dirContents.name}), 1);
                    if (~isempty(dataIdx))
                        
                        ad.rawDataFileName = sd.rawDataFileName;
                        ad.rawDataFilePath = rawDataFilePath;
                        
                        ad.landmarksFilePath = suspectedPath;
                        ad.landmarksFileName = sd.landmarksFileName;
                        ad = do_load(ad);
                    else
                        disp('Could not locate raw data.');
                    end
                end
            end
            
            dataList = dir(fullfile(ad.landmarksFilePath, '*.nlm'));
            dataList = [dataList; dir(fullfile(ad.landmarksFilePath, '*.lmd'))];
            
            util.populate_file_list(dataList, ad.landmarksFileName, handles.lmd_files_listbox, handles.landmark_files_text, 'Landmark (LMD) Files: ');
            
            set(handles.message_text, 'String', 'Message: landmarks file loaded successfully.', 'ForegroundColor', [0 0 0]);
        catch
            set(handles.message_text, 'String', 'Message: failed to load landmarks.', 'ForegroundColor', [1 0 0]);
        end
        
        function [ad] = do_load(ad)
            global currentIdx;
            rawFileName = fullfile(ad.rawDataFilePath, ad.rawDataFileName);
                [~, ~, ext] = fileparts(rawFileName);
                ext = lower(ext);
                switch (ext)
                    case '.dcb' %Opens a DICOM scan stored as a 'DICOM blob' produced by dicombrowse.m
                        ad = open_dcb(ad, rawFileName);
                    case '.nii' %Opens a NIFTI file
                        ad = open_nii(ad, rawFileName);
                    case {'.jpg', '.jpeg', '.png', '.tif', '.tiff'}
                        ad.isImageDataFlag = 1;
                        ad = open_image(ad, rawFileName);
                end
                
                for lmIdx = 1:length(sd.landmarks)
                    if (isa(sd.landmarks{lmIdx}, 'point_landmark'))
                        ad = util.recreate_point_landmark(ad, handles, sd.landmarks{lmIdx});
                    elseif (isa(sd.landmarks{lmIdx}, 'semi_landmark'))
                        ad = util.recreate_semi_landmark(ad, handles, sd.landmarks{lmIdx});
                    end
                end
                
                ad = util.refresh_landmark_list(ad);
                util.reset_callbacks(ad, handles);  %Correcting multi-active lm bug
        end
    end


    %OPEN IMAGE FILE (JPEG, PNG, TIFF)
    %====================================
    function [ad] = open_image(ad, fileName)
        try
            %Read the image data
            img = rgb2gray(imread(fileName));

            %Store the image data in app data
            ad.setscanid = 1;
            minvalue = double(img);
            minvalue = min(minvalue(~isnan(minvalue)));
            maxvalue = double(img);
            maxvalue = max(maxvalue(~isnan(maxvalue)));
            
            ad.clim = [minvalue maxvalue];
            
            sagittalDim = 1;
            coronalDim = size(img, 2);
            axialDim = size(img, 1);
            
            ad.dims.sagittal.x = coronalDim; ad.dims.sagittal.y = axialDim; ad.dims.sagittal.number = sagittalDim;
            ad.dims.coronal.x = sagittalDim; ad.dims.coronal.y = axialDim; ad.dims.coronal.number = coronalDim;
            ad.dims.axial.x = sagittalDim; ad.dims.axial.y = coronalDim; ad.dims.axial.number = axialDim;
            
            ad.slices.sagittal = max(floor(sagittalDim*0.5), 1);
            ad.slices.coronal = max(floor(coronalDim*0.5), 1);
            ad.slices.axial = max(floor(axialDim*0.5), 1);
            
            ad.activePlane = 'sagittal';
            ad.activeAxes = handles.sagittal_axes;
            ad.hoverPlane = [];
            ad.hoverAxes = [];
            ad.currentLocation = [];
            ad.planeSwitchFlag = 1;
                        
            %Delete any landmarks (which contain graphics objects) before proceeding
            if (~isempty(ad.landmarks))
                for lmIdx = 1:length(ad.landmarks)
                    ad.landmarks{lmIdx}.delete();
                end
            end
            set(handles.landmarks_listbox, 'String', {' '});
            set(handles.landmarks_listbox, 'Value', 1);
            ad.landmarks = [];
            
            fovX = 1;
            fovY = 1;
            voxelX = 1;
            voxelY = 1;
            voxelZ = 1;
            
            s = max(floor(sagittalDim*0.5), 1);
            c = max(floor(coronalDim*0.5), 1);
            a = max(floor(axialDim*0.5), 1);
            ad.origin = [s c a];
            ad.voxel_size = [voxelX voxelY voxelZ];		% vol in mm
            
            ad.pos.voxel = [ad.slices.sagittal, ad.slices.coronal, ad.slices.axial];
            ad.pos.mm = (ad.pos.voxel - ad.origin).*ad.voxel_size;
            
            data.img = zeros(1, size(img, 2), size(img, 1), 1, 1);
            data.img(1, :, :) = flipud(img)';
            
            ad.data = data;
            ad = reset(ad);
            set(handles.message_text, 'String', 'Message: Successfully loaded IMAGE file.');
        catch
            set(handles.message_text, 'String', 'Message: Failed to load IMAGE file.');
        end
    end
end