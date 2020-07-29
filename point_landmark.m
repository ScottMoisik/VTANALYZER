classdef point_landmark < landmark
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    properties(Transient)
        mpoint_handle
        %{
        sagPoint
        corPoint
        axiPoint
        %}
        
        positionCallback
        positionCallbackID
    end
    properties
        voxelLocation
        mmLocation
        
       
        confidence 

    end
    
    methods
        function plm = point_landmark(name, initialPos, origin, voxel_size, handles, landmarkIndex, oldPLM)
            plm@landmark(name, origin, voxel_size, landmarkIndex);

            color = [0 1 0];

            plm.mpoint_handle = mpoint(handles, initialPos, color, '', 0, @(mp, ad)updateVoxelLocation(plm, mp, ad));
            plm.confidence = 1.0;
            
            if (~isempty(oldPLM))
                plm.voxelLocation = oldPLM.voxelLocation;
                plm.mmLocation = oldPLM.mmLocation;
                plm.confidence = oldPLM.confidence;
            end
            
        end
        
        
        function updateVoxelLocation(plm, mp, ad)
            
            %ad = getappdata(gcf, 'ad');
            
            if (isfield(ad.zoom, 'rectangle'))
                
                %disp(['moving ' plm.name]);
                loc = mp.loc;
                xLim = get(mp.axes_handle, 'XLim');
                yLim = get(mp.axes_handle, 'YLim');
                
                xRelPos = (loc(1) - xLim(1))/(xLim(2) - xLim(1));
                yRelPos = (loc(2) - yLim(1))/(yLim(2) - yLim(1));
                
                rPos = get(ad.zoom.rectangle, 'Position');
                switch (ad.activePlane)
                    case 'sagittal'
                        lmSag = ad.slices.sagittal;
                        lmCor = rPos(1) + rPos(3)*xRelPos;
                        lmAxi = rPos(2) + rPos(4)*yRelPos;
                    case 'coronal'
                        lmSag = rPos(1) + rPos(3)*xRelPos;
                        lmCor = ad.slices.coronal;
                        lmAxi = rPos(2) + rPos(4)*yRelPos;
                    case 'axial'
                        lmSag = rPos(1) + rPos(3)*xRelPos;
                        lmCor = rPos(2) + rPos(4)*yRelPos;
                        lmAxi = ad.slices.axial;
                end
                lmSag = min(lmSag, ad.dims.sagittal.number);
                lmCor = min(lmCor, ad.dims.coronal.number);
                lmAxi = min(lmAxi, ad.dims.axial.number);
                plm.voxelLocation = max(round([lmSag, lmCor, lmAxi]), 1);
                plm.mmLocation = (double(plm.voxelLocation) - double(plm.origin)).*double(plm.voxelSize);
                
            end
        end
        
        function plm = setVoxelLocation(plm, voxelLocation)
            plm.voxelLocation = voxelLocation;
            plm.mmLocation = (double(plm.voxelLocation) - double(plm.origin)).*double(plm.voxelSize);
        end
        
        function plm = shiftPlane(plm, plane, shift, dims)
            vl = plm.voxelLocation;
            switch plane
                case 'sagittal'
                    newSag = min(max(vl(1) + shift, 1), dims.sagittal.number);
                    plm = plm.setVoxelLocation([newSag vl(2) vl(3)]);
                case 'coronal'
                    newCor = min(max(vl(2) + shift, 1), dims.coronal.number);
                    plm = plm.setVoxelLocation([vl(1) newCor vl(3)]);
                case 'axial'
                    newAxi = min(max(vl(3) + shift, 1), dims.axial.number);
                    plm = plm.setVoxelLocation([vl(1) vl(2) newAxi]);
            end
        end

        function plm = setClass(plm, class)
            plm.class = class;
        end
        
        function centroid = getCentroid(plm)
            centroid = plm.voxelLocation;
        end
        
        function confidence = getConfidence(plm)
            confidence = plm.confidence;
        end
        
        function setConfidence(plm, confidence)
            plm.confidence = confidence;
            plm.mpoint_handle.setConfidenceCircle(confidence);
        end
        
        function hide(plm)
            try
                delete(plm.mpoint_handle.rect_handle);
            catch
            end
        end
        
        function redraw(plm, slices, activePlane, zoom, zoomAxes)
            updatePlanarViews(plm, slices, activePlane, zoom, zoomAxes);
        end
        
        function updatePlanarViews(plm, slices, activePlane, zoom, zoomAxes)
            hideFlag = true;
            if (~isempty(plm.voxelLocation))
                if (plm.voxelLocation(1) == slices.sagittal)
                    if strcmp(activePlane, 'sagittal')
                        updateInteractivePoint(plm, zoom, zoomAxes, 2, 3);
                        hideFlag = false;
                    end
                end
                
                if (plm.voxelLocation(2) == slices.coronal)
                    if strcmp(activePlane, 'coronal')
                        updateInteractivePoint(plm, zoom, zoomAxes, 1, 3);
                        hideFlag = false;
                    end
                end
                
                if (plm.voxelLocation(3) == slices.axial)
                    if strcmp(activePlane, 'axial')
                        updateInteractivePoint(plm, zoom, zoomAxes, 1, 2);
                        hideFlag = false;
                    end
                end
            end
            if (hideFlag)
                plm.hide();
            end
        end
        
        function updateInteractivePoint(plm, zoom, zoomAxes, v1, v2)
            xLim = get(zoomAxes, 'XLim');
            yLim = get(zoomAxes, 'YLim');
            
            rPos = get(zoom.rectangle, 'Position');
            xRelPos = (plm.voxelLocation(v1) - rPos(1))/rPos(3);
            yRelPos = (plm.voxelLocation(v2) - rPos(2))/rPos(4);
            
            xPos = xRelPos*(xLim(2) - xLim(1)) + xLim(1);
            yPos = yRelPos*(yLim(2) - yLim(1)) + yLim(1);

            axes(plm.mpoint_handle.axes_handle);
            plm.mpoint_handle.setPosition(xPos, yPos);
            plm.mpoint_handle.resetCallbacks();
        end;
               
        
        function [idx] = getLandmarkIndexByHandle(plm, ad)
            idx = [];
            if (~isempty(ad.landmarks))
                for lmIdx = 1:length(ad.landmarks)
                    try
                        if (ad.landmarks{lmIdx}.sagPoint == plm.sagPoint)
                            idx = lmIdx;
                            break;
                        end
                    catch
                    end
                end
            end
        end;
        
        function delete(plm)
            %{
            try
                plm.mpoint_handle.delete();
            catch
                disp(['An error occurred trying to delete a point of landmark ' plm.name]);
            end
           %}
        end
        
        function resetCallbacks(plm)
            disp(['reseting callbacks for ' plm.name]);
            plm.mpoint_handle.resetCallbacksExternally();
        end
        
        function reassignIndex(plm, newIndex)
            plm.index = newIndex;
        end
    end
end

