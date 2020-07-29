function varargout = vtanalyzer(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @vtanalyzer_OpeningFcn, ...
    'gui_OutputFcn',  @vtanalyzer_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before vtanalyzer is made visible.
function vtanalyzer_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for vtanalyzer
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

global currentIdx;
currentIdx = 1;
clc
ad = util.init(handles, @scroll_wheel, @move_mouse, @mouse_up, @mouse_down, @save_state, @keyboard_response);
setappdata(gcf, 'ad', ad);

% --- Outputs from this function are returned to the command line.
function varargout = vtanalyzer_OutputFcn(hObject, eventdata, handles)
% Get default command line output from handles structure
varargout{1} = handles.output;

function [saveData] = create_save_data(ad)
saveData.rawDataFilePath = ad.rawDataFilePath;
saveData.rawDataFileName = ad.rawDataFileName;

saveData.landmarksFilePath = ad.landmarksFilePath;
saveData.landmarksFileName = ad.landmarksFileName;
saveData.landmarks = ad.landmarks;

return;

function [] = save_state(src, event)
%Save state file
ad = getappdata(gcf, 'ad');

rawDataFilePath = ad.rawDataFilePath;
landmarksFilePath = ad.landmarksFilePath;
templateFilePath = ad.vt_template_FilePath;
templateFileName = ad.vt_template_FileName;
activePointLandmarkNames = ad.activePointLandmarkNames;
activeSemilandmarkNames = ad.activeSemilandmarkNames;
save('vtanalyzer_state.mat', 'rawDataFilePath', 'landmarksFilePath', 'templateFilePath', 'templateFileName', 'activePointLandmarkNames', 'activeSemilandmarkNames');

saveData = create_save_data(ad);
save('vtanalyzer_backup.mat', 'saveData');
delete(gcf);
return;

% --------------------------------------------------------------------
function file_menu_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function open_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
path = [];
if (~isempty(ad.rawDataFilePath))
    path = fullfile(ad.rawDataFilePath, '*.nii');
end

[rawDataFileName, rawDataFilePath, ~] = uigetfile( {'*.nii', 'NIFTI Files'; '*.dcb', 'DICOM Blob Files'; '*.img', 'IMG-HDR Files'; '*.jpg;*.jpeg;*.png;*.tif;*.tiff', 'Image Files'; '*.*', 'All Files'}, 'Choose Raw Data File to Open...', ad.rawDataFilePath);
try
    if ~(rawDataFileName == 0)
        ad.rawDataFileName = rawDataFileName;
        ad.rawDataFilePath = rawDataFilePath;
        ad = open_data(fullfile(ad.rawDataFilePath, ad.rawDataFileName), ad, handles);
        ad = util.move_to(ad, [floor(ad.dims.sagittal.number*0.5) floor(ad.dims.coronal.number*0.5) floor(ad.dims.axial.number*0.5)]);
        
        setappdata(gcf, 'ad', ad);
    end
catch
end


%==========================================================================
%UTILITY FUNCTIONS
%==========================================================================

function [] = mouse_up(~, ~)
global currentIdx;
    
ad = getappdata(gcf, 'ad');
ad.mouseDownFlag = 0;
ad.isPanning = 0;
handles = guidata(gcf);
if (get(handles.delay_rendering_checkbox, 'Value'))
    %Redraw any visible landmarks
    ad = util.draw_selected_landmark(ad, handles);
end

if ad.newPrenamedFlag
    
    ad.landmarks{currentIdx}.hide();
    util.reset_callbacks(ad, handles);


    %ad = util.move_to(ad, ad.landmarks{currentIdx}.getCentroid());
    ch = get(handles.zoom_axes, 'Children');
    delete(findobj(ch, 'type', 'rectangle'));
    util.reset_callbacks(ad, handles);
    ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
    ad = util.draw_selected_landmark(ad, handles);
    ad = select_landmark(ad, currentIdx);
    ad = util.move_to(ad, ad.landmarks{currentIdx}.getCentroid());
    ad.newPrenamedFlag = false;
    uicontrol(handles.zoom_text);
end

setappdata(gcf, 'ad', ad);
return;

function [] = mouse_down(hobject, ~)
ad = getappdata(gcf, 'ad');
if (isfield(ad, 'data'))
    handles = guidata(gcf);
    
    if ~isempty(ad.hoverPlane) && ~strcmp(ad.hoverPlane, 'zoom')
        
        ad.mouseDownFlag = 1;
        
        if (get(handles.delay_rendering_checkbox, 'Value'))
            ad = util.hide_landmarks(ad, handles);
        end
        
        %If the current major plane has changed, refresh the zoom plot
        if (ad.planeSwitchFlag && ~isempty(ad.hoverPlane) && ~strcmp(ad.hoverPlane, 'zoom'))
            %disp('plane switch');
            util.reset_callbacks(ad, handles);
            ad = util.reset_zoom_plot(ad, ad.hoverPlane, handles.zoom_axes);
            ad.planeSwitchFlag = 0;
        end

        %disp(['current location: ' num2str(ad.currentLocation(1)) ' ' num2str(ad.currentLocation(2))]);
        ad = get_plane(ad, handles);
        ad = util.update_coordinates(ad, handles);
        util.plot_all(ad, handles);
        
        ad = util.update_zoom(ad, handles);
            
    elseif (strcmp(ad.hoverPlane, 'zoom') && strcmp(get(hobject, 'selectiontype' ), 'extend'))
        ad.isPanning = 1;
        if (get(handles.delay_rendering_checkbox, 'Value'))
            ad = util.hide_landmarks(ad, handles);
        end
        ad.panStart = util.convert_point_to_voxel(ad, handles, get(handles.zoom_axes, 'CurrentPoint'));
    end
    setappdata(gcf, 'ad', ad);
end
return;

function [] = move_mouse(~, ~)
ad = getappdata(gcf, 'ad');
%disp(num2str(ad.slices.sagittal));
if (isfield(ad, 'data'))
    
    handles = guidata(ad.mainFig);
    ad = get_plane(ad, handles);
    
    if (~ad.isPanning)
        if (~isempty(ad.hoverPlane))
            ad = util.update_coordinates(ad, handles);
            
            %Update crosshairs and the zoom image, if mouse button is down
            if (ad.mouseDownFlag)
                util.plot_all(ad, handles);
                
                if isfield(ad, 'zoom')
                    ad = util.update_zoom(ad, handles);
                end
            end
        end
    else
        %Panning
        if (strcmp(ad.hoverPlane, 'zoom'))
            curLoc = util.convert_point_to_voxel(ad, handles, get(handles.zoom_axes, 'CurrentPoint'));
            difLoc = ad.panStart - curLoc;
            newLoc = [ad.slices.sagittal ad.slices.coronal ad.slices.axial] + difLoc;
            
            sag = min(max(round(newLoc(1)), 1), ad.dims.sagittal.number);
            cor = min(max(round(newLoc(2)), 1), ad.dims.coronal.number);
            axi = min(max(round(newLoc(3)), 1), ad.dims.axial.number);
            ad = util.move_to(ad, [sag cor axi]);
            
        end
    end
    setappdata(gcf, 'ad', ad);
end

return;


function [ad] = get_plane(ad, handles)
sag = get(handles.sagittal_axes, 'pos');
cor = get(handles.coronal_axes, 'pos');
axi = get(handles.axial_axes, 'pos');
zm = get(handles.zoom_axes, 'pos');

curr = get(gcf, 'currentpoint');

oldPlane = ad.hoverPlane;
if curr(1) >= axi(1) && curr(1) <= axi(1)+axi(3) && curr(2) >= axi(2) && curr(2) <= axi(2)+axi(4)
    ad.hoverPlane = 'axial';
elseif	curr(1) >= cor(1) && curr(1) <= cor(1)+cor(3) && curr(2) >= cor(2) && curr(2) <= cor(2)+cor(4)
    ad.hoverPlane = 'coronal';
elseif	curr(1) >= sag(1) && curr(1) <= sag(1)+sag(3) && curr(2) >= sag(2) && curr(2) <= sag(2)+sag(4)
    ad.hoverPlane = 'sagittal';
elseif	curr(1) >= zm(1) && curr(1) <= zm(1)+zm(3) && curr(2) >= zm(2) && curr(2) <= zm(2)+zm(4)
    ad.hoverPlane = 'zoom';
else
    ad.hoverPlane = [];
end

%Debug
if ~isempty(ad.hoverPlane)
    set(handles.hover_text, 'String', ['Hover: ' ad.hoverPlane]);
else
    set(handles.hover_text, 'String', 'Hover: none');
end;

%Check if the plane has changed
if (~strcmp(oldPlane, ad.hoverPlane) && ~ad.planeSwitchFlag)
    ad.planeSwitchFlag = 1;
end;
return;

function scroll_wheel(~, evnt)
ad = getappdata(gcf, 'ad');

if (isfield(ad, 'data'))
    handles = guidata(gcf);
    
    ad = get_plane(ad, handles);
    
    hover = ad.hoverPlane;
    slider = [ad.hoverPlane '_slider'];
    if (strcmp(ad.hoverPlane, 'zoom'))
        slider = [ad.activePlane '_slider'];
        hover = ad.activePlane;
    end
    
    if (~isempty(ad.hoverPlane))
        step = evnt.VerticalScrollCount;
        step = -sign(step).*round(abs(step).^1.4);
        
            if (get(handles.delay_rendering_checkbox, 'Value'))
                ad = util.hide_landmarks(ad, handles);
            end
            
            val = get(handles.(slider), 'Value');
            minVal = get(handles.(slider), 'Min');
            maxVal = get(handles.(slider), 'Max');
            
            newVal = max(min(val + step, maxVal), minVal);
            set(handles.(slider), 'Value', newVal);
            
            ad.slices.(hover) = max(newVal, 1);
            util.update_plot(hover, ad, handles);
            ad = util.update_coordinates(ad, handles);
            
            %Update
            ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
            ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
            ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
            
            %Update sliders
            set(handles.sagittal_slider, 'Value', ad.slices.sagittal);
            set(handles.coronal_slider, 'Value', ad.slices.coronal);
            set(handles.axial_slider, 'Value', ad.slices.axial);
            
            if (isfield(ad, 'zoom'))% && strcmp(ad.hoverPlane, ad.activePlane))
                ad = util.update_zoom(ad, handles);
            end

        setappdata(gcf, 'ad', ad);
    end
end

function [] = keyboard_response(hObject, event)
global currentIdx;
handles = guidata(gcf);
ad = getappdata(gcf, 'ad');

if (isempty(event.Modifier))
    if (isfield(ad, 'data'))
        if (isfield(ad, 'landmarks') && ~ad.mouseDownFlag)
            currentIdx = get(handles.landmarks_listbox, 'Value');
            updateLandmarkView = false;
            doNothingFlag = false;  %True if a non-used key is pressed
            
            switch (event.Key)
                case {'delete', 'backspace'}
                    if (~isempty(ad.landmarks))
                        currentIdx = get(handles.landmarks_listbox, 'Value');
                        ad = delete_landmark(ad, handles, currentIdx);
                        updateLandmarkView = true;
                    end
                case 's'
                    ad.activePlane = 'sagittal';
                    ad.activeAxes = handles.sagittal_axes;
                    ad.planeSwitchFlag = true;
                    updateLandmarkView = true;
                case 'c'
                    ad.activePlane = 'coronal';
                    ad.activeAxes = handles.coronal_axes;
                    ad.planeSwitchFlag = true;
                    updateLandmarkView = true;
                case 'a'
                    ad.activePlane = 'axial';
                    ad.activeAxes = handles.axial_axes;
                    ad.planeSwitchFlag = true;
                    updateLandmarkView = true;
                case 'm'
                    ad.landmarks{currentIdx} = ad.landmarks{currentIdx}.setVoxelLocation(ad.pos.voxel);  
                    updateLandmarkView = true;
                case 'g'
                    ad = util.hide_landmark(ad,currentIdx);
                    currentIdx = currentIdx + 1;
                    if (currentIdx > length(ad.landmarks))
                        currentIdx = 1;
                    end
                    set(handles.landmarks_listbox, 'Value', currentIdx);
                    updateLandmarkView = true;         
                case 'k'
                    [ad] = create_prenamed_point_landmark(ad, handles);
                    pnIdx = min(get(handles.prenamed_point_landmark_menu, 'Value') + 1, length(get(handles.prenamed_point_landmark_menu, 'String')));
                    set(handles.prenamed_point_landmark_menu, 'Value', pnIdx);
                    
                case 'l'
                    [ad] = create_prenamed_semi_landmark(ad, handles);
                    numItems = length(get(handles.prenamed_semi_landmark_menu, 'String'));
                    pnIdx = get(handles.prenamed_semi_landmark_menu, 'Value');
                    set(handles.prenamed_semi_landmark_menu, 'Value', min(pnIdx+1, numItems));
                case 'downarrow'
                    ad = util.hide_landmark(ad,currentIdx);
                    currentIdx = currentIdx + 1;
                    if (currentIdx > length(ad.landmarks))
                        currentIdx = 1;
                    end
                    set(handles.landmarks_listbox, 'Value', currentIdx);
                    updateLandmarkView = true;
                case 'uparrow'
                    ad = util.hide_landmark(ad,currentIdx);
                    currentIdx = currentIdx - 1;
                    if (currentIdx < 1)
                        currentIdx = length(ad.landmarks);
                    end
                    set(handles.landmarks_listbox, 'Value', currentIdx);
                    updateLandmarkView = true;
                case {'add', 'equal'}
                    ad = shift_landmark_plane(ad, handles, currentIdx, 1);
                    updateLandmarkView = true;
                case {'subtract', 'hyphen'}
                    ad = shift_landmark_plane(ad, handles, currentIdx, -1);
                    updateLandmarkView = true;
                case 'comma'
                    ad = shift_slice(ad, -1);
                case 'period'
                    ad = shift_slice(ad, 1);
                otherwise
                    doNothingFlag = true;
            end
            
            if (updateLandmarkView)
                voxelLoc = [ad.slices.sagittal ad.slices.coronal ad.slices.axial];
                if (~isempty(ad.landmarks))
                    currentIdx = get(handles.landmarks_listbox, 'Value');
                    voxelLoc = ad.landmarks{currentIdx}.getCentroid();
                    util.reset_callbacks(ad, handles);  %Correcting multi-active lm bug
                    ad = select_landmark(ad, currentIdx);
                end
                
                ad = util.move_to(ad, voxelLoc);
               
                if (isfield(ad, 'zoom') && ad.planeSwitchFlag)
                    ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
                    ad = util.draw_selected_landmark(ad, handles);
                end
                
                
    
            end
            
            if (~doNothingFlag)
                util.plot_all(ad, handles);
                %Update
                ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
                ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
                ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
                
                %Update sliders
                set(handles.sagittal_slider, 'Value', ad.slices.sagittal);
                set(handles.coronal_slider, 'Value', ad.slices.coronal);
                set(handles.axial_slider, 'Value', ad.slices.axial);
                
                ad = util.update_coordinates(ad, handles);
                ad = util.update_zoom(ad, handles);
                %ad = util.update_zoom(ad, util.get_image_slice(ad.activePlane, ad));
                %ad = util.draw_landmarks(ad, handles);
            end
            ad = util.update_zoom(ad, handles);
        end
    end
end
setappdata(gcf, 'ad', ad);
return;

function [ad] = shift_slice(ad, shift)
if (isfield(ad, 'data'))
    switch ad.activePlane
        case 'sagittal'
            ad.slices.sagittal = min(max(ad.slices.sagittal + shift, 1), ad.dims.sagittal.number);
        case 'coronal'
            ad.slices.coronal = min(max(ad.slices.coronal + shift, 1), ad.dims.coronal.number);
        case 'axial'
            ad.slices.axial = min(max(ad.slices.axial + shift, 1), ad.dims.axial.number);
    end
end
return;

%==========================================================================
%LANDMARK FUNCTIONS
%==========================================================================


function [ad] = shift_landmark_plane(ad, handles, selIdx, shift)
if (~isempty(ad.landmarks))
    ad.landmarks{selIdx} = ad.landmarks{selIdx}.shiftPlane(ad.activePlane, shift, ad.dims);
    
    ad = util.draw_landmarks(ad, handles);
end
return;

function [ad] = delete_landmark(ad, handles, selIdx)
global currentIdx;
ad.landmarks{selIdx}.delete();
ad.landmarks(selIdx) = [];

if (~isempty(ad.landmarks))
    for lmIdx = 1:length(ad.landmarks)
        ad.landmarks{lmIdx}.reassignIndex(lmIdx);
    end
end

util.reset_callbacks(ad, handles);

if (isempty(ad.landmarks))
    currentIdx = 1;
    set(handles.landmarks_listbox, 'Value', 1);
    set(handles.landmarks_listbox, 'String', {' '});
else
    currentIdx = min(selIdx, length(ad.landmarks));
    set(handles.landmarks_listbox, 'Value', currentIdx);
    ad = util.refresh_landmark_list(ad);
    
end
%ad = util.hide_landmarks(ad, handles);
return;


function [ad] = select_landmark(ad, index)

if (~isempty(ad.landmarks) && index <= length(ad.landmarks))
    handles = guidata(gcf);
    set(handles.landmarks_listbox, 'Value', index);
    
    ad = util.move_to(ad, ad.landmarks{index}.getCentroid());

    if (isa(ad.landmarks{index}, 'semi_landmark'))
        if (~strcmp(ad.activePlane, ad.landmarks{index}.activePlane))
            ad.activePlane = ad.landmarks{index}.activePlane;
            ad.planeSwitchFlag = true;
        end
    end
    
    %{
    for lIdx = 1:length(ad.landmarks)
        if (lIdx ~= index)
            if (ad.landmarks{lIdx}.isVisible())
                %disp(['hiding landmark ' ad.landmarks{lIdx}.name]);
                ad.landmarks{lIdx} = ad.landmarks{lIdx}.hide();
            end
        else
            handles = guidata(gcf);
            set(handles.landmarks_listbox, 'Value', lIdx);
            ad = util.move_to(ad, ad.landmarks{lIdx}.getCentroid());
            
            if (isa(ad.landmarks{lIdx}, 'semi_landmark'))
                if (~strcmp(ad.activePlane, ad.landmarks{lIdx}.activePlane))
                    ad.activePlane = ad.landmarks{lIdx}.activePlane;
                    ad.planeSwitchFlag = true;
                end
            end
            %ad = util.draw_selected_landmark(ad, handles);
        end
        ad.landmarks{lIdx}.setSelected(lIdx == index);
    end
    %}
end

return;

function [lm, lmIdx] = get_landmark_by_name(name, landmarks)
lm = [];
lmIdx = [];
for lIdx = 1:length(landmarks)
    if (strcmp(landmarks{lIdx}.name, name))
        lm = landmarks{lIdx};
        lmIdx = lIdx;
        break;
    end
end

return;

%==========================================================================
%GUI CONTROL CALLBACKS
%==========================================================================

% --------------------------------------------------------------------
function save_landmarks_menu_item_Callback(hObject, eventdata, handles)
% hObject    handle to save_landmarks_menu_item (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

ad = getappdata(gcf, 'ad');

if (~isempty(ad.landmarksFileName) && ~isempty(ad.landmarksFilePath))
    saveData = create_save_data(ad);
    save(fullfile(ad.landmarksFilePath, ad.landmarksFileName), 'saveData');

    set(handles.message_text, 'String', ['Message: landmark files saved successfully to ' ad.landmarksFileName]);
    setappdata(gcf, 'ad', ad);
    
    %Check if there are semilandmarks and force an update to mmLocation if so
    for lmIdx = 1:length(ad.landmarks)
        if (isa(ad.landmarks{lmIdx}, 'semi_landmark'))
            ad.landmarks{lmIdx}.updateLocations();
        end
    end
    
    
    %Save data in CSV and XML formats
    [path, name, ~] = fileparts(fullfile(ad.landmarksFilePath, ad.landmarksFileName));
    save_data(ad, path, name, 'xml');
    save_data(ad, path, name, 'csv');
end

% --------------------------------------------------------------------
function save_landmarks_as_menu_item_Callback(hObject, eventdata, handles)
% hObject    handle to save_landmarks_as_menu_item (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

ad = getappdata(gcf, 'ad');

[path, name, ext] = fileparts(fullfile(pwd, ad.rawDataFileName));

if (~isempty(ad.landmarksFilePath))
    pathName = ad.landmarksFilePath;
else
    pathName = pwd;
end

%Save landmark file
nameSuffix = '_landmarks.lmd';
%nameSuffix = ['_landmarks_' num2str(ad.slices.sagittal) '.lmd'];
[landmarksFileName, pathName] = uiputfile('*.lmd', 'Save Landmark Data', [pathName name nameSuffix]);

if (~isempty(landmarksFileName) && sum(landmarksFileName == 0) == 0)
    ad.landmarksFilePath = pathName;
    ad.landmarksFileName = landmarksFileName;
    saveData = create_save_data(ad);
    save(fullfile(pathName, landmarksFileName), 'saveData');

    set(handles.message_text, 'String', 'Message: landmark files saved successfully.');
    setappdata(gcf, 'ad', ad);
    util.populate_file_list(dir(fullfile(ad.landmarksFilePath, '*.lmd')), ad.landmarksFileName, handles.lmd_files_listbox, handles.landmark_files_text, 'Landmark Data (LMD) Files: ');
    
    %Save data in CSV and XML formats
    [path, name, ~] = fileparts(fullfile(pathName, landmarksFileName));
    
    %Check if there are semilandmarks and force an update to mmLocation if so
    for lmIdx = 1:length(ad.landmarks)
        if (isa(ad.landmarks{lmIdx}, 'semi_landmark'))
            ad.landmarks{lmIdx}.updateLocations();
        end
    end
    
    
    save_data(ad, path, name, 'xml');
    save_data(ad, path, name, 'csv');
    
    set(handles.save_landmarks_menu_item, 'Enable', 'On');
end

% --------------------------------------------------------------------
function load_landmarks_menu_item_Callback(hObject, eventdata, handles)
% hObject    handle to load_landmarks_menu_item (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%Read landmark file
[landmarksFileName, pathName] = uigetfile('*.lmd; *.nlm');
if (sum(landmarksFileName == 0) == 0)
    ad = getappdata(gcf, 'ad');
    ad.landmarksFilePath = pathName;
    ad.landmarksFileName = landmarksFileName;
    ad = open_data(fullfile(ad.landmarksFilePath, landmarksFileName), ad, handles);
    %ad = open_data(fullfile(pathName, landmarksFileName), ad, handles);
    setappdata(gcf, 'ad', ad);
    set(handles.save_landmarks_menu_item, 'Enable', 'On');
end



% --- Executes on button press in move_to_origin_button.
function move_to_origin_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
if (isfield(ad, 'data'))

    ad = util.move_to(ad, ad.origin);
end
setappdata(gcf, 'ad', ad);

% --- Executes on button press in move_to_current_location_button.
function move_to_current_location_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
if (~isempty(ad.landmarks))
    selIdx = get(handles.landmarks_listbox, 'Value');
    ad.landmarks{selIdx} = ad.landmarks{selIdx}.setVoxelLocation(ad.pos.voxel);        
    ad = util.draw_selected_landmark(ad, handles);
end
setappdata(gcf, 'ad', ad);

% --- Executes on button press in finalize_landmark_button.
function finalize_landmark_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

if (~isempty(ad.landmarks))
    selIdx = get(handles.landmarks_listbox, 'Value');
    ad.landmarks{selIdx} = ad.landmarks{selIdx}.setVoxelLocation(ad.pos.voxel);        
    ad = util.draw_landmarks(ad, handles);
end

setappdata(gcf, 'ad', ad);


% --- Executes on slider movement.
function sagittal_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

ad.slices.sagittal = min(max(floor(get(hObject, 'Value')), 1), ad.dims.sagittal.number);
util.plot_all(ad, handles);
ad = util.update_zoom(ad, handles);
%Update crosshairs
ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
setappdata(gcf, 'ad', ad);

% --- Executes on slider movement.
function coronal_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

ad.slices.coronal = min(max(floor(get(hObject, 'Value')), 1), ad.dims.coronal.number);
util.plot_all(ad, handles);
ad = util.update_zoom(ad, handles);
%Update crosshairs
ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
setappdata(gcf, 'ad', ad);

% --- Executes on slider movement.
function axial_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

ad.slices.axial = min(max(floor(get(hObject, 'Value')), 1), ad.dims.axial.number);
util.plot_all(ad, handles);
ad = util.update_zoom(ad, handles);
%Update crosshairs
ad.xhairs.sagittal = util.crosshairs(ad.xhairs.sagittal, handles.sagittal_axes, [ad.slices.coronal ad.slices.axial]);
ad.xhairs.coronal = util.crosshairs(ad.xhairs.coronal, handles.coronal_axes, [ad.slices.sagittal ad.slices.axial]);
ad.xhairs.axial = util.crosshairs(ad.xhairs.axial, handles.axial_axes, [ad.slices.sagittal ad.slices.coronal]);
setappdata(gcf, 'ad', ad);


% --- Executes on selection change in colormap_popupmenu.
function colormap_popupmenu_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
cmaps = get(hObject, 'String');
switch cmaps{get(hObject, 'Value')}
    case 'gray'
        ad.default_color_map = gray(256);
    case 'jet'
        ad.default_color_map = jet(256);
    case 'cool'
        ad.default_color_map = cool(256);
    case 'winter'
        ad.default_color_map = winter(256);
end

ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);


% --- Executes on slider movement.
function low_contrast_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

% --- Executes on slider movement.
function low_brightness_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

% --- Executes on slider movement.
function high_contrast_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

function high_brightness_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

% --- Executes on button press in reset_contrast_button.
function reset_contrast_button_Callback(hObject, eventdata, handles)
set(handles.low_contrast_slider, 'Value', 0.0);
set(handles.high_contrast_slider, 'Value', 1.0);
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

% --- Executes on button press in reset_brightness_button.
function reset_brightness_button_Callback(hObject, eventdata, handles)
set(handles.low_brightness_slider, 'Value', 0.0);
set(handles.high_brightness_slider, 'Value', 1.0);
ad = getappdata(gcf, 'ad');
ad = util.adjust_color_maps(ad, handles);
setappdata(gcf, 'ad', ad);

% --- Executes on selection change in raw_data_files_listbox.
function raw_data_files_listbox_Callback(hObject, eventdata, handles)

if strcmp(get(gcf,'selectiontype'),'open')
    ad = getappdata(gcf, 'ad');
    files = get(handles.raw_data_files_listbox, 'String');
    rawDataFileName = files{get(handles.raw_data_files_listbox, 'Value')};
    
    if ~isempty(rawDataFileName)
        ad.rawDataFileName = rawDataFileName;
        ad.landmarksFileName = ' ';
        ad = open_data(fullfile(ad.rawDataFilePath, ad.rawDataFileName), ad, handles);
        setappdata(gcf, 'ad', ad);
    end
    
    uicontrol(handles.zoom_text);
    
    %disp('Raw data file listbox callback disabled');
end


% --- Executes on selection change in lmd_files_listbox.
function lmd_files_listbox_Callback(hObject, eventdata, handles)
if strcmp(get(gcf,'selectiontype'),'open')
    ad = getappdata(gcf, 'ad');
    files = get(handles.lmd_files_listbox, 'String');
    if (~isempty(files))
        landmarksFileName = files{get(handles.lmd_files_listbox, 'Value')};
        
        if ~isempty(landmarksFileName)
            ad.landmarksFileName = landmarksFileName;
            ad = open_data(fullfile(ad.landmarksFilePath, landmarksFileName), ad, handles);
            %ad = util.move_to(ad, [floor(ad.dims.sagittal.number*0.5) floor(ad.dims.coronal.number*0.5) floor(ad.dims.axial.number*0.5)]);
            %ad = util.draw_landmarks(ad, handles);
            setappdata(gcf, 'ad', ad);
            uicontrol(handles.zoom_text);
            set(handles.save_landmarks_menu_item, 'Enable', 'On');
        end
    end
end

% --- Executes on button press in new_landmark_button.
function new_landmark_button_Callback(hObject, eventdata, handles)
lmTypes = get(handles.landmark_types_popupmenu, 'String');
currentType = lmTypes{get(handles.landmark_types_popupmenu, 'Value')};
ad = getappdata(gcf, 'ad');
%ad = util.hide_landmarks(ad, handles, currentIdx);

switch (strtrim(currentType))
    case 'Point Landmark'
        name = inputdlg('Name:', 'New point landmark...', [1 50]);
        if (~isempty(name))
            ad = util.create_new_point_landmark(name{1}, [], ad, handles);
        end
    case 'Semilandmarks (Trace)'
        name = inputdlg('Name:', 'New semilandmarks...', [1 50]);
        if (~isempty(name))
            ad = util.create_new_semi_landmark(name{1}, [], ad, handles);
        end
end
ad = util.refresh_landmark_list(ad);
set(handles.landmarks_listbox, 'Value', length(ad.landmarks));
setappdata(gcf, 'ad', ad);

% --- Executes on button press in prenamed_point_landmark_button.
function prenamed_point_landmark_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad = create_prenamed_point_landmark(ad, handles);
setappdata(gcf, 'ad', ad);


function [ad] = create_prenamed_point_landmark(ad, handles)
global currentIdx;

pnIdx = get(handles.prenamed_point_landmark_menu, 'Value');
name = ad.activePointLandmarkNames{pnIdx};
landmarkNames = get(handles.landmarks_listbox, 'String');

if (~isempty(ad.landmarks))
    lmIdx = get(handles.landmarks_listbox, 'Value');
    ad.landmarks{lmIdx}.hide();
    util.reset_callbacks(ad, handles);
    %ad = util.update_zoom(ad, handles);
end

%Check if a landmark with this name already exists
createLandmarkFlag = 1;
if (~isempty(landmarkNames))
   createLandmarkFlag = (~any(cellfun(@(listName) strcmp(name, listName), landmarkNames)));
end

if (createLandmarkFlag)
    ad.newPrenamedFlag = true;
    currentIdx = length(ad.landmarks) + 1;
    ad = util.create_new_point_landmark(name, [], ad, handles);
    ad = util.refresh_landmark_list(ad);
    set(handles.landmarks_listbox, 'Value', currentIdx);
    
    %ad = select_landmark(ad, currentIdx);
    set(handles.landmarks_listbox, 'Value', length(ad.landmarks));
else
    %beep
    waitfor(msgbox(['Message: A prenamed point landmark with the name ' name ' already exists']));
    set(handles.message_text, 'String', ['Message: A prenamed point landmark with the name ' name ' already exists']);
end



% --- Executes on button press in prenamed_semi_landmark_button.
function prenamed_semi_landmark_button_Callback(hObject, eventdata, handles)

ad = getappdata(gcf, 'ad');
ad = create_prenamed_semi_landmark(ad, handles);
setappdata(gcf, 'ad', ad);

function [ad] = create_prenamed_semi_landmark(ad, handles)
global currentIdx;
pnTypes = get(handles.prenamed_semi_landmark_menu, 'String');

if (iscell(pnTypes))
    name = pnTypes{get(handles.prenamed_semi_landmark_menu, 'Value')};
else
    name = pnTypes;
end

%Check if the landmark exists, and, if it does, warn about it being deleted
choice = 'Yes';
[lm, lmIdx] = get_landmark_by_name(name, ad.landmarks);
if (~isempty(lm))
   choice = questdlg(['Warning: This will replace existing landmark named "' name '". Continue?'], 'Landmark Replacement', 'Yes', 'Cancel', 'Cancel');
   if (strcmp(choice, 'Yes'))
       %Delete the old landmark
       ad = delete_landmark(ad, handles, lmIdx);
   end
end


if (strcmp(choice, 'Yes'))
    %ad = util.hide_landmarks(ad, handles);

    firstAnchorName = '';
    secondAnchorName = '';
    try
        %Find the key landmarks
        second_order = load_second_order_landmarks(ad.vt_template_FileName, ad.landmarks);
        prior = util.get_prior_by_name(second_order, name);
        
        firstAnchorName = prior.first_anchor;
        secondAnchorName = prior.second_anchor;
        
        if (~isempty(prior))
            firstAnchor = get_landmark_by_name(prior.first_anchor, ad.landmarks);
            secondAnchor = get_landmark_by_name(prior.second_anchor, ad.landmarks);
            
            if (~isempty(firstAnchor)) && ~isempty(secondAnchor)
                currentIdx = length(ad.landmarks) + 1;
                prior.startVoxel = firstAnchor.voxelLocation;
                prior.stopVoxel = secondAnchor.voxelLocation;
                ad.landmarks = [ad.landmarks {semi_landmark(prior.name, [], ad.origin, ad.voxel_size, prior.plane, handles, currentIdx, [], prior)}];
                
                ad = util.refresh_landmark_list(ad);
                set(handles.landmarks_listbox, 'Value', length(ad.landmarks));
    
                set(handles.message_text, 'String', ['Message: Successfully created ' name]);
            end
        end
    catch
        if (~isempty(ad.activeSemilandmarkNames))
            
            slIdx = get(handles.prenamed_semi_landmark_menu, 'Value');
            prior = ad.activeSemilandmarkNames{slIdx};
            firstAnchor = get_landmark_by_name(prior.first_anchor, ad.landmarks);
            secondAnchor = get_landmark_by_name(prior.second_anchor, ad.landmarks);
            if (~isempty(firstAnchor)) && ~isempty(secondAnchor)
                currentIdx = length(ad.landmarks) + 1;
                prior.startVoxel = firstAnchor.voxelLocation;
                prior.stopVoxel = secondAnchor.voxelLocation;
                
                ad.landmarks = [ad.landmarks {semi_landmark(prior.name, [], ad.origin, ad.voxel_size, prior.plane, handles, currentIdx, [], prior)}];
                
                ad = util.refresh_landmark_list(ad);
                set(handles.landmarks_listbox, 'Value', length(ad.landmarks));
                set(handles.message_text, 'String', ['Message: Successfully created ' name]);
            else
                set(handles.message_text, 'String', ['Message: Make sure required anchor points are present (' prior.first_anchor ' & ' prior.second_anchor ')']);
            end
        else
            set(handles.message_text, 'String', ['Message: Could not load ' name '. See MATLAB console.']);
            disp('Make sure the following dependencies are defined:');
            disp(firstAnchorName);
            disp(secondAnchorName);
        end
    end
end


% --- Executes on selection change in landmarks_listbox.
function landmarks_listbox_Callback(hObject, eventdata, handles)
global currentIdx;
ad = getappdata(gcf, 'ad');

if (~isempty(ad.landmarks))
    %tic
    ad = util.hide_landmark(ad,currentIdx);
    currentIdx = get(hObject, 'Value');
    set(handles.landmark_confidence_slider, 'Value', ad.landmarks{currentIdx}.getConfidence());
    set(handles.landmark_confidence_text, 'String', ['Landmark Confidence: ' num2str(ad.landmarks{currentIdx}.getConfidence()*100, '%.0f') '%']);
    util.reset_callbacks(ad, handles);

    if (isa(ad.landmarks{currentIdx}, 'semi_landmark'))
        ad.activePlane = ad.landmarks{currentIdx}.activePlane;
        ad.planeSwitchFlag = true;
        switch (ad.activePlane)
            case 'sagittal'
                ad.activeAxes = handles.sagittal_axes;
            case 'coronal'
                ad.activeAxes = handles.coronal_axes;
            case 'axial'
                ad.activeAxes = handles.axial_axes;
        end
        %ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
        %ad = util.update_zoom(ad, handles);
    end

    ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
    ad = select_landmark(ad, currentIdx);

    %ad = util.move_to(ad, ad.landmarks{currentIdx}.getCentroid());
    %ad = util.draw_selected_landmark(ad, handles);
    %toc
end
setappdata(gcf, 'ad', ad);
uicontrol(handles.zoom_text);

% --- Executes on button press in rename_button.
function rename_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
if (~isempty(ad.landmarks))
    selIdx = get(handles.landmarks_listbox, 'Value');
    name = inputdlg('Name:', 'Rename landmark...', [1 50], {ad.landmarks{selIdx}.name});
    if (~isempty(name))
        ad.landmarks{selIdx}.name = name{1};
        ad = util.refresh_landmark_list(ad);
    end
end

setappdata(gcf, 'ad', ad);


% --- Executes on slider movement.
function landmark_confidence_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

if (~isempty(ad.landmarks))
    %contents = cellstr(get(hObject,'String'));
    selIdx = get(handles.landmarks_listbox, 'Value');
    ad.landmarks{selIdx} = ad.landmarks{selIdx}.setConfidence(double(get(hObject, 'Value')));
    set(handles.landmark_confidence_text, 'String', ['Landmark Confidence: ' num2str(ad.landmarks{selIdx}.getConfidence()*100, '%.0f') '%']);
end
setappdata(gcf, 'ad', ad);



% --------------------------------------------------------------------
function set_vt_template_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');

[vtTemplateFileName, vtTemplateFilePath, ~] = uigetfile( {'*.xml', 'XML Files'}, 'Choose VT Template (XML) Data File to Open...', ad.rawDataFilePath);
if ~(vtTemplateFileName == 0)
    ad.vt_template_FilePath = vtTemplateFilePath;
    ad.vt_template_FileName = vtTemplateFileName;
    
    templates = dir(fullfile(vtTemplateFilePath, '*.xml'));
    templateIndex = find(strcmp({templates.name}, vtTemplateFileName));
    set(handles.template_popupmenu, 'String', {templates.name});
    set(handles.template_popupmenu, 'Value', templateIndex);
end
setappdata(gcf, 'ad', ad);


% --- Executes on selection change in template_popupmenu.
function template_popupmenu_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
templates = get(handles.template_popupmenu, 'String');
templateIdx = get(handles.template_popupmenu, 'Value');
ad.vt_template_FileName = templates{templateIdx};
setappdata(gcf, 'ad', ad);


% --- Executes on button press in load_key_landmarks_button.
function load_key_landmarks_button_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
%set(handles.load_key_landmarks_button, 'Enable', 'off');
set(handles.load_first_order_button, 'Enable', 'off');
set(handles.load_second_order_button, 'Enable', 'off');

try
    if (isfield(ad, 'data'))
        lastLandmarkIdx = length(ad.landmarks);
        priors = load_key_priors(ad.vt_template_FileName, ad.data.img);
        for pIdx = 1:length(priors)
            %statusbar(gcf, ['Loading key landmarks. Progress: ' num2str(pIdx/length(priors)*100, '%.f') '%']);
            lmName = priors(pIdx).name;
            set(handles.message_text, 'String', ['Message: loading landmark ' lmName]);
            ad = util.create_new_point_landmark(priors(pIdx).name, [0 0], ad, handles);
            ad.landmarks{end} = ad.landmarks{end}.setClass('key');
            ad.landmarks{end} = ad.landmarks{end}.setVoxelLocation(priors(pIdx).voxelLocation);
        end
        
        util.reset_callbacks(ad, handles);
        util.refresh_landmark_list(ad);
        ad = select_landmark(ad, lastLandmarkIdx + 1);
        
    else
        set(handles.message_text, 'String', 'Message: load NIFTI file first.');
    end
catch
    set(handles.message_text, 'String', 'Message: An error occurred when attempting to find key landmarks.');
end
set(handles.load_key_landmarks_button, 'Enable', 'on');
set(handles.load_first_order_button, 'Enable', 'on');
set(handles.load_second_order_button, 'Enable', 'on');
%statusbar(gcf, '');
setappdata(gcf, 'ad', ad);

% --- Executes on button press in load_first_order_button.
function load_first_order_button_Callback(hObject, eventdata, handles)
global currentIdx;
ad = getappdata(gcf, 'ad');
%set(handles.load_key_landmarks_button, 'Enable', 'off');
%set(handles.load_first_order_button, 'Enable', 'off');
%set(handles.load_second_order_button, 'Enable', 'off');

try
    if (~isempty(ad.landmarks))
        lastLandmarkIdx = length(ad.landmarks);
        [first_order, unlocatedNames] = load_first_order_landmarks(ad.vt_template_FileName, ad.landmarks, ad.dims, ad.activePointLandmarkNames);
        
        if (~isempty(unlocatedNames))
            unlocatedString = '';
            for ulIdx = 1:length(unlocatedNames)
                unlocatedString = [unlocatedString unlocatedNames{ulIdx} ', ' ];
            end
            waitfor(msgbox(['Some landmarks were predicted to be outside of the volume: ' unlocatedString]));
        end
        
        if (~isempty(first_order))
            for pIdx = 1:length(first_order)
                lmName = strrep(first_order(pIdx).name, '_', ' ');
                set(handles.message_text, 'String', ['Message: loading landmark ' lmName]);
                ad = util.create_new_point_landmark(lmName, [0 0], ad, handles);
                ad.landmarks{end} = ad.landmarks{end}.setClass('first_order');
                ad.landmarks{end} = ad.landmarks{end}.setVoxelLocation(first_order(pIdx).voxelLocation);
                %statusbar(gcf, ['Loading key landmarks. Progress: ' num2str(pIdx/length(first_order)*100, '%.f') '%']);
            end
            
            %ad = util.draw_landmarks(ad, handles);
            util.reset_callbacks(ad, handles);
            util.refresh_landmark_list(ad);
            
            ad = util.hide_landmark(ad,currentIdx);
            currentIdx = lastLandmarkIdx + 1;
            ad = select_landmark(ad, currentIdx);
        else
            set(handles.message_text, 'String', 'Message: failed to load first order landmarks. Could not locate all required keys.');
        end
    else
        set(handles.message_text, 'String', 'Message: load key landmarks first.');
    end
catch
    set(handles.message_text, 'String', 'Message: an error occurred when attempting to load first order landmarks.');
end
%statusbar(gcf, '');
set(handles.load_key_landmarks_button, 'Enable', 'on');
set(handles.load_first_order_button, 'Enable', 'on');
set(handles.load_second_order_button, 'Enable', 'on');
setappdata(gcf, 'ad', ad);

% --- Executes on button press in load_second_order_button.
function load_second_order_button_Callback(hObject, eventdata, handles)
global currentIdx;
ad = getappdata(gcf, 'ad');
%set(handles.load_key_landmarks_button, 'Enable', 'off');
%set(handles.load_first_order_button, 'Enable', 'off');
%set(handles.load_second_order_button, 'Enable', 'off');

if (~isempty(ad.landmarks))
    
    lastLandmarkIdx = length(ad.landmarks);
    second_order = load_second_order_landmarks(ad.vt_template_FileName, ad.landmarks);    
    if (~isempty(second_order))
        
        ad = util.hide_landmark(ad,currentIdx);
        nonExistingList = '';
        for sIdx = 1:length(second_order)
            firstAnchor = get_landmark_by_name(second_order(sIdx).first_anchor, ad.landmarks);
            secondAnchor = get_landmark_by_name(second_order(sIdx).second_anchor, ad.landmarks);
            
            if (~isempty(firstAnchor)) && ~isempty(secondAnchor)
                index = length(ad.landmarks) + 1;
                second_order(sIdx).startVoxel = firstAnchor.voxelLocation;
                second_order(sIdx).stopVoxel = secondAnchor.voxelLocation;
                ad.landmarks = [ad.landmarks {semi_landmark(strrep(second_order(sIdx).name, '_', ' '), [], ad.origin, ad.voxel_size, second_order(sIdx).plane, handles, index, [], second_order(sIdx))}];
            else
                
                if (isempty(firstAnchor))
                    nonExistingList = [nonExistingList sprintf([second_order(sIdx).first_anchor '\n'])];
                end
                
                if (isempty(secondAnchor))
                    nonExistingList = [nonExistingList sprintf([second_order(sIdx).second_anchor '\n'])];
                end
            end
            
            
        end
        util.refresh_landmark_list(ad);
        util.reset_callbacks(ad, handles);

        currentIdx = lastLandmarkIdx + 1;
        ad = select_landmark(ad, currentIdx);
        set(handles.message_text, 'String', 'Message: succesfully loaded semi-landmarks.');
        if (~isempty(nonExistingList))
            disp(sprintf(['Warning: The following landmarks could not be located:\n' nonExistingList]));
            set(handles.message_text, 'String', 'Message: Some landmarks could not be loaded. See console.');
        end
        
    end
end

set(handles.load_key_landmarks_button, 'Enable', 'on');
set(handles.load_first_order_button, 'Enable', 'on');
set(handles.load_second_order_button, 'Enable', 'on');
setappdata(gcf, 'ad', ad);

% --------------------------------------------------------------------
function delete_all_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
if (~isempty(ad.landmarks))
    for sIdx = 1:length(ad.landmarks)
        ad = delete_landmark(ad, handles, 1);
    end
    set(handles.landmarks_listbox, 'Value', 1);
    set(handles.landmarks_listbox, 'String', {' '});
    drawnow;
    %ad = util.refresh_landmark_list(ad);
end
setappdata(gcf, 'ad', ad);



% --------------------------------------------------------------------
function anonymize_data_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
button = questdlg('This will strip data in the region of the eyes from the file.', 'Warning', 'OK', 'Cancel', 'Cancel');

if (isfield(ad, 'data') && strcmp(button, 'OK'))
    ad = util.anonymize_data(ad, [0.15 0.85], [0.45 0.85]);    
    util.plot_all(ad, handles);
end
    
setappdata(gcf, 'ad', ad);

% --------------------------------------------------------------------
function clear_command_window_menu_item_Callback(hObject, eventdata, handles)
clc

function [] = extract_image(plane, handles)
ad = getappdata(gcf, 'ad');
if (~isempty(ad.data))
    img_slice = util.get_image_slice(plane, ad);
    fig = figure();    
    imagesc(img_slice');
    set(gca, 'YDir', 'normal', 'XTick', [], 'YTick', []);
    switch (plane)
        case {'coronal', 'axial'}
            %Set the coronal and axial plots to have uniform axis scaling
            set(gca, 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
    end
    set(fig, 'colormap', ad.color_map);
    scaleW = size(img_slice', 1);
    scaleH = size(img_slice', 2);
    ratio = scaleW/scaleH;
    val = 8;
    set(gca, 'Position', [0 0 1 1]);
    set(fig, 'PaperPosition', [0 0 val val*ratio]); %Position plot at left hand corner with width 5 and height 5.
    set(fig, 'PaperSize', [val val*ratio]); %Set the paper to have width 5 and height 5.
    picFileName = fullfile(pwd, ['extracted_' plane '_image']);
    saveas(fig, picFileName, 'jpg'); %Save figure
    close(fig);
    
    set(handles.message_text, 'String', 'Message: Image successfully extracted. Check console for directory.');
    disp([picFileName '.jpg']);
end


% --------------------------------------------------------------------
function extract_image_figure_designer_menu_item_Callback(hObject, eventdata, handles)
    ad = getappdata(gcf, 'ad');
    
    if (isfield(ad, 'data'))
        
        figAD = [];
        figAD.fig = figure('Position', [100 100 800 400], 'Name', 'Figure Designer');
        figAD.planes = {'sagittal', 'axial', 'coronal'};
        figAD.currentPlane = find(strcmp(ad.activePlane, figAD.planes));
        figAD.numImageCols = min(ad.slices.(figAD.planes{figAD.currentPlane}), 3);
        figAD.numImageRows = 1;
        figAD.numImageColsPopup = uicontrol(figAD.fig, 'Style', 'popup', 'String', {'1', '2', '3', '4', '5'}, 'value', figAD.numImageCols, 'Units', 'Normalized', 'Position', [0.0 0.9 0.1 0.05], 'Callback', @figdes_set_number_of_images);
        figAD.numImageRowsPopup = uicontrol(figAD.fig, 'Style', 'popup', 'String', {'1', '2', '3', '4', '5'}, 'value', figAD.numImageRows, 'Units', 'Normalized', 'Position', [0.0 0.95 0.1 0.05], 'Callback', @figdes_set_number_of_images);
        figAD.contrastSlider = uicontrol(figAD.fig, 'Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 1, 'SliderStep', [1/100 1/100], 'Units', 'Normalized', 'Position', [0.5 0.9 0.5 0.05], 'Callback', @figdes_change_contrast);
        
        figAD.saveScalingPopup = uicontrol(figAD.fig, 'Style', 'popup', 'String', {'2', '3', '4', '5', '10'}, 'value', 1, 'Units', 'Normalized', 'Position', [0.2 0.95 0.1 0.05]);
        figAD.activePlanePopup = uicontrol(figAD.fig, 'Style', 'popup', 'String', figAD.planes, 'value', figAD.currentPlane, 'Units', 'Normalized', 'Position', [0.0 0.85 0.1 0.05], 'Callback', @figdes_set_number_of_images);
        figAD.flushImagesToFirstButton = uicontrol(figAD.fig, 'Style', 'pushbutton', 'String', 'Flush', 'Units', 'Normalized', 'Position', [0.1 0.95 0.1 0.05], 'Callback', @figdes_flush_images);
        
        figAD.saveImageButton = uicontrol(figAD.fig, 'Style', 'pushbutton', 'String', 'Save', 'Units', 'Normalized', 'Position', [0.1 0.9 0.1 0.05], 'Callback', @figdes_save_image);
        figAD.imageLabelField = uicontrol(figAD.fig, 'Style', 'edit', 'String', '', 'Units', 'Normalized', 'Position', [0.3 0.9 0.2 0.1]);%, 'Callback', @figdes_edit_text);
        figAD.axesH = [];
        figAD.slidersH = [];
        ad.figAD = figAD;
        setappdata(gcf, 'ad', ad);
        figdes_set_number_of_images(figAD.numImageRowsPopup, [],[]);
        
    end
    
    
    
function img_slice = figdes_change_contrast(hObject, eventdata, ~)
ad = getappdata(gcf, 'ad');
figAD = ad.figAD;

for aIdx = 1:length(figAD.axesH)
    imH = findobj(get(figAD.axesH(aIdx), 'Children'), 'type', 'image');
    img_slice = figdes_get_image(figAD.planes{figAD.currentPlane}, ad, aIdx);
    imAdj = imadjust(mat2gray(img_slice'), [0 get(figAD.contrastSlider, 'Value')], []);
    set(imH, 'CData', imAdj);
end
    
function img_slice = figdes_flush_images(hObject, eventdata, ~)
ad = getappdata(gcf, 'ad');
figAD = ad.figAD;
firstImageIndex = floor(get(figAD.slidersH(1), 'Value'));
count = 1;
for aIdx = 1:length(figAD.axesH)
    imNum = firstImageIndex + aIdx - 1;
    set(figAD.slidersH(aIdx), 'Value', imNum);
    
    imH = findobj(get(figAD.axesH(aIdx), 'Children'), 'type', 'image');
    img_slice = figdes_get_image(figAD.planes{figAD.currentPlane}, ad, imNum);
    imAdj = imadjust(mat2gray(img_slice'), [0 get(figAD.contrastSlider, 'Value')], []);
    set(imH, 'CData', imAdj);
    
    imT = findobj(get(figAD.axesH(aIdx), 'Children'), 'type', 'text');
    set(imT, 'String', [get(figAD.imageLabelField, 'String') num2str(imNum)]);
    count = count + 1;
end



function img_slice = figdes_get_image(plane, ad, imageIdx)
switch (plane)
    case 'sagittal'
        img_slice = squeeze(ad.data.img(max(imageIdx, 1), :, :, :, ad.setscanid));
    case 'coronal'
        img_slice = squeeze(ad.data.img(:, max(imageIdx, 1), :, :, ad.setscanid));
    case 'axial'
        img_slice = squeeze(ad.data.img(:, :, max(imageIdx, 1), :, ad.setscanid));
end
        
function figdes_set_number_of_images(hObject, eventdata, ~)
ad = getappdata(gcf, 'ad');
figAD = ad.figAD;

if ~isempty(figAD.axesH)
    try
    for aIdx = 1:length(figAD.axesH)
        delete(figAD.axesH(aIdx));
        delete(figAD.slidersH(aIdx));
    end
    catch
        figAD.axesH = [];
        figAD.slidersH = [];
    end
end

xOffset = 0.05;
yOffset = 0.05;
figAD.numImageRows = get(figAD.numImageRowsPopup, 'Value');
figAD.numImageCols = get(figAD.numImageColsPopup, 'Value');
dX = 0.9 / figAD.numImageCols;
dY = 0.7 / figAD.numImageRows;
set(figAD.fig, 'Position', [100 50 800 min(400*figAD.numImageRows*0.8, 1000)]);
count = 1;
for rIdx = figAD.numImageRows:-1:1
    for cIdx = 1:figAD.numImageCols
        figAD.axesH(count) = axes('Parent', figAD.fig, 'Position', [xOffset + (cIdx-1)*dX yOffset + (rIdx-1)*dY + ((rIdx-1)*dY*0.25) dX - (dX*0.05) dY - (dY*0.05)]);
        img_slice = figdes_get_image(figAD.planes{figAD.currentPlane}, ad, count);
        imAdj = imadjust(mat2gray(img_slice'), [0 get(figAD.contrastSlider, 'Value')], []);
        imagesc(imAdj); 
        colormap(gray); set(figAD.axesH(count), 'YDir', 'normal', 'xtick', [], 'ytick', [], 'xticklabel', {}, 'yticklabel', {}, 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
        numSlices = ad.dims.(figAD.planes{figAD.currentPlane}).number;
        figAD.slidersH(count) = uicontrol(figAD.fig, 'Style', 'slider', 'Min', 1, 'Max', numSlices, 'Value', count, 'SliderStep', [1/numSlices 1/numSlices], 'UserData', count, 'Units', 'Normalized', 'Position', [xOffset + (cIdx-1)*dX (rIdx-1)*dY + ((rIdx-1)*dY*0.25) dX - (dX*0.05) (dY*0.1)], 'Callback', @figdes_change_image);
        
        text(size(img_slice, 1)*0.1, size(img_slice, 2)*0.1, [get(figAD.imageLabelField, 'String') num2str(count)], 'Color', [1 1 1], 'FontSize', 18, 'FontName', 'Times New Roman');
        count = count + 1;
    end
end
ad.figAD = figAD;
setappdata(gcf, 'ad', ad);

function figdes_save_image(hObject, eventdata, ~)
ad = getappdata(gcf, 'ad');
figAD = ad.figAD;
dims = get(figAD.axesH(1), 'PlotBoxAspectRatio');
scalingOptions = get(figAD.saveScalingPopup, 'String');
scalingFactor = str2double(scalingOptions{get(figAD.saveScalingPopup, 'Value')});
figWidth = figAD.numImageCols*dims(2)*scalingFactor;
figHeight = figAD.numImageRows*dims(1)*scalingFactor;
saveFig = figure('Position', [100 100 figWidth figHeight], 'Name', 'Save Figure');
xOffset = 0;
yOffset = 0;
dX = 1.0 / figAD.numImageCols;
dY = 1.0 / figAD.numImageRows;
count = 1;
for rIdx = figAD.numImageRows:-1:1
    for cIdx = 1:figAD.numImageCols
        imageIndex = floor(get(figAD.slidersH(count), 'Value'));
        ax = axes('Parent', saveFig, 'Position', [(cIdx-1)*dX (rIdx-1)*dY dX dY]);
        img_slice = figdes_get_image(figAD.planes{figAD.currentPlane}, ad, imageIndex);
        imAdj = imadjust(mat2gray(img_slice'), [0 get(figAD.contrastSlider, 'Value')], []);
        imagesc(imAdj); colormap(gray); set(ax, 'YDir', 'normal', 'xtick', [], 'ytick', [], 'xticklabel', {}, 'yticklabel', {}, 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1]);
        
        text(size(img_slice, 1)*0.1, size(img_slice, 2)*0.1, [get(figAD.imageLabelField, 'String') num2str(imageIndex)], 'Color', [1 1 1], 'FontSize', 10*scalingFactor, 'FontName', 'Times New Roman');
        count = count + 1;
    end
end

[~, fileName, ~] = fileparts(ad.rawDataFileName);
savefig([fileName '_frames.jpg'], saveFig);
close(saveFig);
t = 1;
            
function figdes_change_image(hObject, eventdata, ~)
ad = getappdata(gcf, 'ad');
figAD = ad.figAD;
ax = figAD.axesH(get(hObject, 'UserData'));
axes(ax);
imageIndex = floor(get(hObject, 'Value'));
numSlices = ad.slices.(figAD.planes{figAD.currentPlane});
img_slice = figdes_get_image(figAD.planes{figAD.currentPlane}, ad, imageIndex);

imAdj = imadjust(mat2gray(img_slice'), [0 get(figAD.contrastSlider, 'Value')], []);
imagesc(imAdj);
text(size(img_slice, 1)*0.1, size(img_slice, 2)*0.1, [get(figAD.imageLabelField, 'String') num2str(imageIndex)], 'Color', [1 1 1], 'FontSize', 18, 'FontName', 'Times New Roman'); 
set(ax, 'YDir', 'normal', 'DataAspectRatioMode', 'manual', 'DataAspectRatio', [1 1 1], 'xtick', [], 'ytick', [], 'xticklabel', {}, 'yticklabel', {});
t = 1;                
  

% --------------------------------------------------------------------
function extract_sagittal_image_menu_item_Callback(hObject, eventdata, handles)
extract_image('sagittal', handles);

% --------------------------------------------------------------------
function extract_coronal_image_menu_item_Callback(hObject, eventdata, handles)
extract_image('coronal', handles);

% --------------------------------------------------------------------
function extract_axial_image_menu_item_Callback(hObject, eventdata, handles)
extract_image('axial', handles);

% --------------------------------------------------------------------
function change_landmark_set_to_3D_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesFor3D);
set(handles.prenamed_semi_landmark_menu, 'String', ad.prenamedSemilandmarkNamesFor3D);
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesFor3D;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesFor3D;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);

% --------------------------------------------------------------------
function change_landmark_set_to_VT_proportions_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesForVTProportions);
set(handles.prenamed_semi_landmark_menu, 'String', {ad.prenamedSemilandmarkNamesForVTProportions{1}.name});
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesForVTProportions;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesForVTProportions;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);


% --------------------------------------------------------------------
function change_landmark_set_to_larynx_position_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesForLarynxPosition);
set(handles.prenamed_semi_landmark_menu, 'String', ad.prenamedSemilandmarkNamesForLarynxPosition);
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesForLarynxPosition;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesForLarynxPosition;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);


% --------------------------------------------------------------------
function change_landmark_set_to_larynx_vowels_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesForLarynxVowels);
semiLMs = [ad.prenamedSemilandmarkNamesForLarynxVowels{:}];
set(handles.prenamed_semi_landmark_menu, 'String', {semiLMs.name});
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesForLarynxVowels;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesForLarynxVowels;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);


% --------------------------------------------------------------------
function change_landmark_set_to_external_images_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesForExternalImages);
semiLMs = [ad.prenamedSemilandmarkNamesForExternalImages{:}];
set(handles.prenamed_semi_landmark_menu, 'String', {semiLMs.name});
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesForExternalImages;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesForExternalImages;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);


% --------------------------------------------------------------------
function change_landmark_set_to_midsagittal_traces_menu_item_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
set(handles.prenamed_point_landmark_menu, 'String', ad.prenamedPointLandmarkNamesForMidsagittalPalateTraces);
semiLMs = [ad.prenamedSemilandmarkNamesForMidsagittalPalateTraces{:}];
set(handles.prenamed_semi_landmark_menu, 'String', {semiLMs.name});
ad.activePointLandmarkNames = ad.prenamedPointLandmarkNamesForMidsagittalPalateTraces;
ad.activeSemilandmarkNames = ad.prenamedSemilandmarkNamesForMidsagittalPalateTraces;
ad = util.refresh_landmark_list(ad);
setappdata(gcf, 'ad', ad);


% --- Executes on slider movement.
function zoom_slider_Callback(hObject, eventdata, handles)
ad = getappdata(gcf, 'ad');
ad.updatingZoomFlag = true;
setappdata(gcf, 'ad', ad);
%Zoom using the mouse wheel
ad.zoomFactor = get(hObject, 'value');
ad.zoomFactor = min(max(ad.zoomFactor, ad.zoomMin), ad.zoomMax);

ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
ad = util.update_zoom(ad, handles);
if (get(handles.delay_rendering_checkbox, 'Value'))
    ad = util.draw_selected_landmark(ad, handles);
end

ad.updatingZoomFlag = false;
        %else
            %{
            if (~ad.updatingZoomFlag && ~(((step > 0) && ad.zoomFactor == 0.1) || ((step < 0) && ad.zoomFactor == 0.4)))
                ad.updatingZoomFlag = true;
                setappdata(gcf, 'ad', ad);
                %Zoom using the mouse wheel
                ad.zoomFactor = ad.zoomFactor - 0.01*step;
                ad.zoomFactor = min(max(ad.zoomFactor, 0.1), 0.5);
                
                ad = util.reset_zoom_plot(ad, ad.activePlane, handles.zoom_axes);
                ad = util.update_zoom(ad, handles);
                if (get(handles.delay_rendering_checkbox, 'Value'))
                    ad = util.draw_selected_landmark(ad, handles);
                end
                
                ad.updatingZoomFlag = false;
            end
            %}
        %end
 setappdata(gcf, 'ad', ad);       

%==========================================================================
%GUI CONTROL CREATE FUNCTIONS
%==========================================================================

% --- Executes during object creation, after setting all properties.
function raw_data_files_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to raw_data_files_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function low_brightness_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low_brightness_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function low_contrast_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low_contrast_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function axial_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axial_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function coronal_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to coronal_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function sagittal_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sagittal_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function landmarks_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to landmarks_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in landmark_types_popupmenu.
function landmark_types_popupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to landmark_types_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns landmark_types_popupmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from landmark_types_popupmenu


% --- Executes during object creation, after setting all properties.
function landmark_types_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to landmark_types_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function zoom_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoom_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --------------------------------------------------------------------
function debug_menu_Callback(hObject, eventdata, handles)
% hObject    handle to debug_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function lmd_files_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lmd_files_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function landmark_confidence_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to landmark_confidence_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end




% --- Executes on selection change in prenamed_point_landmark_menu.
function prenamed_point_landmark_menu_Callback(hObject, eventdata, handles)
% hObject    handle to prenamed_point_landmark_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns prenamed_point_landmark_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from prenamed_point_landmark_menu


% --- Executes during object creation, after setting all properties.
function prenamed_point_landmark_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to prenamed_point_landmark_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function landmarks_menu_Callback(hObject, eventdata, handles)
% hObject    handle to landmarks_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in prenamed_semi_landmark_menu.
function prenamed_semi_landmark_menu_Callback(hObject, eventdata, handles)
% hObject    handle to prenamed_semi_landmark_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns prenamed_semi_landmark_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from prenamed_semi_landmark_menu


% --- Executes during object creation, after setting all properties.
function prenamed_semi_landmark_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to prenamed_semi_landmark_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in delay_rendering_checkbox.
function delay_rendering_checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to delay_rendering_checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of delay_rendering_checkbox



% --- Executes during object creation, after setting all properties.
function colormap_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to colormap_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function edit_menu_Callback(hObject, eventdata, handles)
% hObject    handle to edit_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function high_contrast_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high_contrast_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end




% --- Executes during object creation, after setting all properties.
function high_brightness_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high_brightness_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --------------------------------------------------------------------
function extract_image_menu_Callback(hObject, eventdata, handles)
% hObject    handle to extract_image_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function change_prenamed_set_menu_item_Callback(hObject, eventdata, handles)
% hObject    handle to change_prenamed_set_menu_item (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function template_popupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to template_popupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
