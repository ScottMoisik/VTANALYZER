classdef mpoint < handle
    properties(Transient)
        axes_handle
        rect_handle
        confidence_rect_handle
        confidence_slider_handle
        resetCallbacksHandle
        updateLandmarkLocationCallback
        setPositionHandle
    end
    properties
        newFlag
        movingFlag
        confidenceAdjustFlag
        confidenceStartPoint
        hoverFlag
        visibleFlag
        
        loc
        index
        conf
        constraint
        isConstrained
        
        isActiveFlag
        
        defaultColor
        selectedColor
    end
    
    methods
        function mp = mpoint(handles, initialPos, defaultColor, constraint, index, updateLandmarkLocationCallback)
            mp.axes_handle = handles.zoom_axes;
            mp.confidence_slider_handle = handles.landmark_confidence_slider;
            mp.confidenceAdjustFlag = false;
            mp.isActiveFlag = true;
            mp.visibleFlag = true;
            mp.hoverFlag = false;
            mp.index = index;
            mp.defaultColor = defaultColor;
            mp.constraint = constraint;
            mp.selectedColor = [1 0 1];
            mp.conf = [0.5 1.0];
            mp.isConstrained = ~strcmp(mp.constraint, '');
            
            if (~isempty(initialPos))
                mp.newFlag = false;
                mp.movingFlag = false;
                mp.loc = initialPos;
                cp = mp.loc;% rectangle('Position', [cp(1)-0.5 cp(2)-0.5 1.0 1.0], 'EdgeColor', defaultColor, 'FaceColor', defaultColor, 'Curvature', [1 1], 'userData', defaultColor);
                
                axes(mp.axes_handle);
                mp.rect_handle = -1;
            else
                mp.newFlag = true;
                mp.movingFlag = true;
                cp = get(mp.axes_handle, 'CurrentPoint');
                cp = cp(1, 1:2);
                mp.loc = cp;
                axes(mp.axes_handle);
                mp.rect_handle = rectangle('Position', [mp.loc(1)-0.5 mp.loc(2)-0.5 1.0 1.0], 'EdgeColor', mp.selectedColor, 'FaceColor', mp.selectedColor, 'Curvature', [1 1], 'userData', mp.selectedColor);
            end
            
            
            mp.resetCallbacksHandle = @resetCallbacks;
            mp.updateLandmarkLocationCallback = updateLandmarkLocationCallback;
            %If the motion is constrained, then all movement manipulation is handled by the class owning the point
           
            if ~mp.isConstrained
                mp.resetCallbacks();
            end
        end
        
        
        function resetCallbacks(mp)
            callback_manager(@mp.movePoint, 'mouse_move');
            callback_manager(@mp.getPoint, 'mouse_down');
            callback_manager(@mp.setPoint, 'mouse_up');
            %disp('callbacks for mpoint created');
        end
        
        function movePoint(mp, object, eventdata)
            ad = getappdata(gcf, 'ad');
            %disp(['attempting to update: ' num2str(double(mp.visibleFlag))]);
            if (isstruct(ad))
                if (strcmp(ad.hoverPlane, 'zoom'))
                    if (ishandle(mp.rect_handle))
                        if (mp.visibleFlag)
                            cp = get(mp.axes_handle, 'CurrentPoint');
                            cp = cp(1, 1:2);
                            
                            if (~mp.confidenceAdjustFlag)
                                if (mp.movingFlag)
                                    mp.loc = cp;
                                    set(mp.rect_handle, 'Position', [cp(1)-0.5 cp(2)-0.5 1.0 1.0]);
                                    %set(mp.confidence_rect_handle, 'Position', [cp(1)-mp.conf(1) cp(2)-mp.conf(1) mp.conf(2) mp.conf(2)]);
                                    mp.updateLandmarkLocationCallback(mp, ad);
                                else
                                    rPos = get(mp.rect_handle, 'Position');
                                    mp.loc = [rPos(1) rPos(2)];
                                    if ((cp(1) >= (mp.loc(1) - 1) && cp(1) <= (mp.loc(1) + 1)) && (cp(2) >= (mp.loc(2) - 1) && cp(2) <= (mp.loc(2) + 1)))
                                        mp.hoverFlag = true;
                                        set(mp.rect_handle, 'LineWidth', 4);
                                    else
                                        mp.hoverFlag = false;
                                        set(mp.rect_handle, 'LineWidth', 0.5);
                                        %disp(['target x = ' num2str(mp.loc(1)) ' actual x = ' num2str(cp(1))]);
                                    end
                                end
                            else
                                disp('Confidence adjustment disabled.');
                                %{
                                confidenceFactor = norm(mp.confidenceStartPoint - cp);
                                if (confidenceFactor < 1.0)
                                    confidenceFactor = 0.0;
                                end
                                
                                confidenceFactor = 1.0 - (min(confidenceFactor, 10.0) / 10.0);
                                
                                %disp(confidenceFactor);
                                
                                set(handles.landmark_confidence_slider, 'Value', confidenceFactor);
                                mp.setConfidenceCircle(confidenceFactor);
                                set(handles.landmark_confidence_text, 'String', ['Landmark Confidence: ' num2str(confidenceFactor*100, '%.0f') '%']);
                                %}
                            end
                        end
                    end
                end
            end
        end
        
        %CHANGE MADE (OCT 2015) TO MAKE MOVEMENT OF POINT IMMEDIATE UPON CLICKING ON ZOOM AXES
        function getPoint(mp, object, eventData)
            ad = getappdata(gcf, 'ad');
            
            if (strcmp(ad.hoverPlane, 'zoom')) && ~strcmp(get(object, 'selectiontype' ), 'extend')
                
                if (~ishandle(mp.rect_handle))
                    axes(mp.axes_handle);
                    mp.rect_handle = rectangle('Position', [mp.loc(1)-0.5 mp.loc(2)-0.5 1.0 1.0], 'EdgeColor', mp.selectedColor, 'FaceColor', mp.selectedColor, 'Curvature', [1 1], 'userData', mp.selectedColor);
                end
                
                mp.visibleFlag = true;
                mp.movingFlag = true;
                cp = get(mp.axes_handle, 'CurrentPoint');
                cp = cp(1, 1:2);
                
                mp.loc = cp;
                set(mp.rect_handle, 'Position', [cp(1)-0.5 cp(2)-0.5 1.0 1.0]);
                mp.updateLandmarkLocationCallback(mp, ad);
                
                %ad.landmarks{idx}.mpoint_handle = mp;
                %setappdata(gcf, 'ad', ad);
                %{
                if (mp.hoverFlag && mp.visibleFlag && strcmp(get(object, 'selectiontype' ), 'normal'))
                    mp.movingFlag = true;
                elseif (strcmp(get(object, 'selectiontype'), 'alt'))
                    mp.confidenceAdjustFlag = true;
                    cp = get(mp.axes_handle, 'CurrentPoint');
                    cp = cp(1, 1:2);
                    mp.confidenceStartPoint = cp;
                end
                %}
            end
        end
        
        function setPoint(mp, object, eventData)
            global currentIdx;
            ad = getappdata(gcf, 'ad');
            
            if (strcmp(ad.hoverPlane, 'zoom'))
                if (mp.movingFlag && mp.visibleFlag)
                    mp.movingFlag = false;
                    
                    %ad = util.move_to(ad, ad.landmarks{currentIdx}.getCentroid());
                    %setappdata(gcf, 'ad', ad);
                end
                %mp.confidenceAdjustFlag = false;
                %set(mp.confidence_rect_handle, 'Visible', 'off');
            end
            
        end
        

        function setConfidenceCircle(mp, confidence)
            pos = get(mp.rect_handle, 'Position');
            x = pos(1) + pos(3)*0.5;
            y = pos(2) + pos(4)*0.5;
            cVal = 1.0 + 25.0*(1.0 - confidence);
            hcVal = cVal*0.5;
            set(mp.confidence_rect_handle, 'Position', [x-hcVal y-hcVal cVal cVal], 'Visible', 'on');
            mp.conf = [cVal hcVal];
        end
        
        function setPosition(mp, x, y)
            mp.loc = [x y];
            %if (~mp.movingFlag)
                if (~ishandle(mp.rect_handle))
                    mp.rect_handle = rectangle('Position', [x-0.5 y-0.5 1.0 1.0], 'EdgeColor', mp.selectedColor, 'FaceColor', mp.selectedColor, 'Curvature', [1 1]);
                else
                    set(mp.rect_handle, 'Position', [x-0.5 y-0.5 1.0 1.0]);
                end
            %end
            
            %{
                c = mp.conf;
                set(mp.confidence_rect_handle, 'Position', [x-c(1) y-c(1) c(2) c(2)]);
            %}
            %mpOut = mp;
            %mp = mp.setPositionHandle(x, y);
        end
        
        function delete(mp)
            if (ishandle(mp.rect_handle))
                delete(mp.rect_handle);
            end
            %delete(mp.confidence_rect_handle);
        end
        
        function resetCallbacksExternally(mp)
            mp.resetCallbacksHandle();
        end
    end
end
