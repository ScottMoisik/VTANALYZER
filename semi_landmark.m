classdef semi_landmark < landmark
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    properties(Transient)
        axes_handle
        mpoint_handles
        
        copyDataInternal_handle
        resetCallbackHandlers_handle
        callback;
        
        zoomLines
    end
    
    properties
        
        voxelLocations
        mmLocations
        confidences
        
        activePlane
        activeSlice
        activePoint
        activeColor
        
        numPoints
        numLines
        tracingEnabled
        creatingPointFlag
        
        color
        
        constraint
        isConstrained
        constrainedDrawingActiveFlag
    end
    
    methods
        function slm = semi_landmark(name, initialPos, origin, voxelSize, activePlane, handles, index, oldSLM, priorSLM)
            slm@landmark(name, origin, voxelSize, index);
            slm.color = [0 1 0];
            slm.axes_handle = handles.zoom_axes;
            
            %Defines the plane of the trace
            slm.activePlane = activePlane;
            slm.activePoint = 1;
            
            %Indicates whether a drawing constraint is imposed (this sets the default)
            slm.isConstrained = false;
            
            %Construct semilandmarks based on sample pattern specificaiton provided by a template (see load_second_order_landmarks)
            if (~isempty(priorSLM))
                sampleVector = [];
                %start and stop points in the sample pattern (columns 2 and 3) must be one and the same
                for pIdx = 1:size(priorSLM.samplePattern, 1)
                    samples = linspace(priorSLM.samplePattern(pIdx, 2), priorSLM.samplePattern(pIdx, 3), priorSLM.samplePattern(pIdx, 1));
                    sampleVector = [sampleVector samples(2:end)];
                    
                    if (pIdx == 1)
                        sampleVector = [0.0 sampleVector];
                    end
                end
                
                numSamples = length(sampleVector);
                slm.voxelLocations = zeros(numSamples, 3);
                switch (priorSLM.plane)
                    case 'sagittal'
                        avgIdx = 1;
                    case 'coronal'
                        avgIdx = 2;
                    case 'axial'
                        avgIdx = 3;
                end
                
                avg = round(mean([priorSLM.startVoxel(avgIdx) priorSLM.stopVoxel(avgIdx)]));
                priorSLM.startVoxel(avgIdx) = avg;
                priorSLM.stopVoxel(avgIdx) = avg;
                slm.activeSlice = avg;
                diffVector = priorSLM.stopVoxel - priorSLM.startVoxel;
                
                for vIdx = 1:numSamples
                    slm.voxelLocations(vIdx, :) = priorSLM.startVoxel + diffVector*sampleVector(vIdx);
                end
                initialPos = zeros(numSamples, 2);
                
                %Define constraint specific callback functions if this landmark is constrained
                slm.constraint = priorSLM.constraint;
                slm.isConstrained = ~strcmp(slm.constraint, '');
                slm.constrainedDrawingActiveFlag = 0;
            end
            
            %Initialize the semilandmark state
            if (~isempty(initialPos))
                slm.confidences = ones(length(initialPos), 1);
                
                for p = 1:length(initialPos)
                    slm.mpoint_handles = [slm.mpoint_handles mpoint(handles, [0 0], slm.color, slm.constraint, p, @updateVoxelLocation)];
                end
                slm.numPoints = length(initialPos);
                slm.numLines = slm.numPoints - 1;
                axes(handles.zoom_axes);
                for p = 1:slm.numLines
                    slm.zoomLines(p) = line([0 0], [0 0], 'Color', slm.color);
                end
                
            elseif (isempty(oldSLM))
                slm.confidences = [];
                slm.tracingEnabled = true;
                slm.numPoints = 0;
                slm.numLines = 0;
                callback_manager(@newPoint, 'mouse_down');
                callback_manager(@connectPoint, 'mouse_move');
            end
            
            %Copy in old data if possible
            if (~isempty(oldSLM))
                slm.voxelLocations = oldSLM.voxelLocations;
                slm.mmLocations = oldSLM.mmLocations;
                slm.activePlane = oldSLM.activePlane;
                slm.activeSlice = oldSLM.activeSlice;
                slm.confidences = oldSLM.confidences;
                slm.numPoints = oldSLM.numPoints;
                slm.numLines = oldSLM.numLines;
                axes(handles.zoom_axes);
                for p = 1:slm.numLines
                    slm.zoomLines(p) = line([0 0], [0 0], 'Color', slm.color);
                end
                
                slm.constraint = oldSLM.constraint;
                slm.isConstrained = ~strcmp(slm.constraint, '');
                slm.constrainedDrawingActiveFlag = 0;
                
                for vIdx = 1:length(slm.voxelLocations)
                    slm.mpoint_handles = [slm.mpoint_handles mpoint(handles, [0 0], slm.color, slm.constraint, vIdx, @updateVoxelLocation)];
                end
            end
            
            function createPoint(makeLineFlag)
                if (slm.tracingEnabled)
                    slm.numPoints = slm.numPoints + 1;
                    
                    slm.creatingPointFlag = true;
                    slm.confidences = [slm.confidences; 1.0];
                    slm.mpoint_handles = [slm.mpoint_handles mpoint(handles, [], slm.color, '', slm.numPoints, @updateVoxelLocation)];
                    loc = slm.mpoint_handles(slm.numPoints).loc;
                    if (makeLineFlag)
                        slm.numLines = slm.numLines + 1;
                        cp = get(handles.zoom_axes, 'CurrentPoint');
                        cp = cp(1, 1:2);
                        axes(handles.zoom_axes); slm.zoomLines(slm.numLines) = line([loc(1) cp(1)], [loc(2) cp(2)], 'Color', slm.color);
                    end
                    
                    slm.mpoint_handles(slm.numPoints) = updateVoxelLocation(slm.mpoint_handles(slm.numPoints));
                    
                    slm.creatingPointFlag = false;
                end
                %disp(num2str(slm.numPoints));
            end
            
            function newPoint(object, eventdata)
                if (slm.tracingEnabled && strcmp(get(object, 'selectiontype' ), 'normal'))
                    createPoint(true);
                else
                    createPoint(false);
                    slm.tracingEnabled = false;
                end
            end
            
            function connectPoint(object, eventdata)
                if (slm.tracingEnabled && ~isempty(slm.zoomLines) && ~slm.creatingPointFlag)
                    cp = get(handles.zoom_axes, 'CurrentPoint');
                    cp = cp(1, 1:2);
                    loc = slm.mpoint_handles(slm.numPoints).loc;
                    set(slm.zoomLines(slm.numLines), 'XData', [loc(1) cp(1)], 'YData', [loc(2) cp(2)]);
                end
            end
            
            %slm.resetCallbackHandlers_handle = @resetCallbackHandlers;
            
        end
        
        
        function updateVoxelLocation(slm, mp, handles)
            %global currentIdx;
            ad = getappdata(gcf, 'ad');
            %slm = ad.landmarks{currentIdx};
            
            if (isfield(ad.zoom, 'rectangle'))
                idx = mp.index;
                loc = mp.loc;
                
                if (~isempty(slm.zoomLines))
                    if (idx <= length(slm.zoomLines))
                        linePosX = get(slm.zoomLines(idx), 'XData');
                        linePosY = get(slm.zoomLines(idx), 'YData');
                        set(slm.zoomLines(idx), 'XData', [loc(1) linePosX(2)], 'YData', [loc(2) linePosY(2)]);
                        %disp(['updating point ' num2str(idx)]);
                    end
                    
                    if (idx > 1)
                        linePosX = get(slm.zoomLines(idx - 1), 'XData');
                        linePosY = get(slm.zoomLines(idx - 1), 'YData');
                        set(slm.zoomLines(idx - 1), 'XData', [linePosX(1) loc(1)], 'YData', [linePosY(1) loc(2)]);
                    end
                end
                
                xLim = get(handles.zoom_axes, 'XLim');
                yLim = get(handles.zoom_axes, 'YLim');
                
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
                
                switch (slm.activePlane)
                    case 'sagittal'
                        slm.activeSlice = ad.slices.sagittal;
                    case 'coronal'
                        slm.activeSlice = ad.slices.coronal;
                    case 'axial'
                        slm.activeSlice = ad.slices.axial;
                end
                
                slm.activePoint = idx;
                slm.voxelLocations(idx, :) = [lmSag, lmCor, lmAxi]; %max(round([lmSag, lmCor, lmAxi]), 1);
                slm.mmLocations(idx, :) = (double(slm.voxelLocations(idx, :)) - double(slm.origin)).*double(slm.voxelSize);
                
                %ad.landmarks{currentIdx} = slm;
            end
            %setappdata(gcf, 'ad', ad);
            
        end
        
        function resetCallbackHandlers(slm)
            if (~slm.isConstrained)
                for mIdx = 1:length(slm.mpoint_handles)
                    slm.mpoint_handles(mIdx).resetCallbacksExternally();
                end
            else
                callback_manager(@slm.startConstrainedDrawing, 'mouse_down');
                callback_manager(@slm.continueConstrainedDrawing, 'mouse_move');
                callback_manager(@slm.stopConstrainedDrawing, 'mouse_up');
            end
        end
        
        function startConstrainedDrawing(slm, src, ~)
            slm.constrainedDrawingActiveFlag = 1;
            if (strcmp(get(src, 'selectiontype' ), 'normal'))
                slm.doConstrainedDrawing();
            end
        end
        
        function continueConstrainedDrawing(slm, src, ~)
            if (slm.constrainedDrawingActiveFlag)
                if (strcmp(get(src, 'selectiontype' ), 'normal'))
                    slm.doConstrainedDrawing();
                end
            end
        end
        
        function stopConstrainedDrawing(slm, ~, ~)
            slm.constrainedDrawingActiveFlag = 0;
        end
        
        
        function applyConstrainedDrawing(slm, cp, dirIdx, handles)

                coord = cp(dirIdx);
                startRect = get(slm.mpoint_handles(1).rect_handle, 'Position');
                stopRect = get(slm.mpoint_handles(end).rect_handle, 'Position');
                start = startRect(dirIdx) + startRect(dirIdx + 2)*0.5;
                stop = stopRect(dirIdx) + stopRect(dirIdx + 2)*0.5;
                %disp([num2str(coord) ' vs ' num2str(start) ' vs ' num2str(stop)]);
                if (coord > start && coord < stop)
                    prev = start;
                    currRect = get(slm.mpoint_handles(2).rect_handle, 'Position');
                    curr = currRect(dirIdx) + currRect(dirIdx + 2)*0.5;
                    for fIdx = 2:slm.numPoints-1
                        nextRect = get(slm.mpoint_handles(fIdx+1).rect_handle, 'Position');
                        next = nextRect(dirIdx) + nextRect(dirIdx + 2)*0.5;
                        
                        if (coord < next)
                            firstHalfWay = curr - (curr - prev)*0.25;
                            secondHalfWay = curr + (next - curr)*0.25;
                            
                            if (coord >= firstHalfWay && coord <= secondHalfWay)
                                if (dirIdx == 1)
                                    slm.mpoint_handles(fIdx).setPosition(currRect(1) + currRect(3)*0.5, cp(2));
                                else
                                    slm.mpoint_handles(fIdx).setPosition(cp(1), currRect(2) + currRect(4)*0.5);
                                end
                                slm.updateVoxelLocation(slm.mpoint_handles(fIdx), handles);
                                break;
                            end
                        end
                        prev = curr;
                        currRect = nextRect;
                        curr = next;
                        
                    end
                end

        end
        
        
        function doConstrainedDrawing(slm)
            try
                if (slm.numPoints > 2)
                    handles = guidata(gcf);
                    cp = get(handles.zoom_axes, 'CurrentPoint');
                    cp = cp(1, 1:2);
                    
                    %Locate closest mpoint to the current mouse location (excluding first and last (true) landmarks
                    switch (slm.constraint)
                        case 'x-axis'
                            slm.applyConstrainedDrawing(cp, 2, handles);
                        case 'y-axis'
                            slm.applyConstrainedDrawing(cp, 1, handles);
                        case 'proximity'
                            
                            startRect = get(slm.mpoint_handles(1).rect_handle, 'Position');
                            stopRect = get(slm.mpoint_handles(end).rect_handle, 'Position');
                            anchorDist = norm(startRect - stopRect);
                            startDist = norm(startRect(1:2) - cp);
                            stopDist = norm(stopRect(1:2) - cp);
                            
                            distProp = 0;
                            if (startDist < stopDist)
                                distProp = 0.5*startDist/stopDist;
                                
                            else
                                distProp = 1 -0.5*stopDist/startDist;
                                
                            end
                            
                            pointValue = ((slm.numPoints-1)*distProp);
                            pointQuant = floor(pointValue + 0.5);
                            pointUpper = pointQuant + 0.4;
                            pointLower = pointQuant - 0.4;
                            
                            if (pointValue > pointLower) && (pointValue < pointUpper)
                                pointIndex = max(min(floor(pointUpper) + 1, slm.numPoints-1), 2);
                                %disp([num2str(pointLower) ' ' num2str(pointUpper) ' ' num2str(pointValue) ' --> ' num2str(pointIndex)]);
                                slm.mpoint_handles(pointIndex).setPosition(cp(1), cp(2));
                                slm.updateVoxelLocation(slm.mpoint_handles(pointIndex), handles);
                            end
                    end
                end
            catch
            end
        end
        
        
        function updateLocations(slm)
            for sIdx = 1:slm.numPoints
                slm.mmLocations(sIdx, :) = (double(slm.voxelLocations(sIdx, :)) - double(slm.origin)).*double(slm.voxelSize);
            end
        end
        
        function lm = setClass(class)
            lm.class = class;
        end
        
        function centroid = getCentroid(slm)
            centroid = floor(mean(slm.voxelLocations));
        end
        
        function confidence = getConfidence(slm)
            confidence = 1;
            if (slm.activePoint > 0 && slm.activePoint <= length(slm.confidences))
                confidence = slm.confidences(slm.activePoint);
            end
        end
        
        function setConfidence(slm, confidence)
            if (slm.activePoint > 0 && slm.activePoint <= length(slm.confidences))
                slm.confidences(slm.activePoint) = confidence;
                slm.mpoint_handles(slm.activePoint).setConfidenceCircle(confidence);
            end
        end
        
        function shiftPlane(slm, plane, shift, dims)
            
            for vIdx = 1:slm.numPoints
                vl = slm.voxelLocations(vIdx, :);
                
                switch plane
                    case 'sagittal'
                        newSag = min(max(vl(1) + shift, 1), dims.sagittal.number);
                        slm.voxelLocations(vIdx, :) = [newSag vl(2) vl(3)];
                        slm.activeSlice = newSag;
                    case 'coronal'
                        newCor = min(max(vl(2) + shift, 1), dims.coronal.number);
                        slm.voxelLocations(vIdx, :) = [vl(1) newCor vl(3)];
                        slm.activeSlice = newCor;
                    case 'axial'
                        newAxi = min(max(vl(3) + shift, 1), dims.axial.number);
                        slm.voxelLocations(vIdx, :) = [vl(1) vl(2) newAxi];
                        slm.activeSlice = newAxi;
                end
                slm.mmLocations(vIdx, :) = (double(slm.voxelLocations(vIdx, :)) - double(slm.origin)).*double(slm.voxelSize);
            end
        end
        
        function hide(slm)
            for pIdx = 1:slm.numPoints
                try
                    delete(slm.mpoint_handles(pIdx).rect_handle);
                catch
                end
            end
            
            for lIdx = 1:length(slm.zoomLines)
                try
                    delete(slm.zoomLines(lIdx));
                catch
                end
            end
        end
        
        function redraw(slm, slices, activePlane, zoom, zoomAxes)
            updatePlanarViews(slm, slices, activePlane, zoom, zoomAxes);
        end
        
        function updatePlanarViews(slm, slices, activePlane, zoom, zoomAxes)
            slm.resetCallbackHandlers();
            hideFlag = true;
            axes(slm.axes_handle);
            if (~isempty(slm.voxelLocations))
                for p = 1:length(slm.voxelLocations)
                    
                    if (slm.voxelLocations(p, 1) == slices.sagittal)
                        if strcmp(activePlane, 'sagittal')
                            slm = updateInteractivePoints(slm, p, zoom, zoomAxes, 2, 3);
                            hideFlag = false;
                        end
                    end
                    
                    if (slm.voxelLocations(p, 2) == slices.coronal)
                        if strcmp(activePlane, 'coronal')
                            slm = updateInteractivePoints(slm, p, zoom, zoomAxes, 1, 3);
                            hideFlag = false;
                        end
                    end
                    
                    if (slm.voxelLocations(p, 3) == slices.axial)
                        if strcmp(activePlane, 'axial')
                            slm = updateInteractivePoints(slm, p, zoom, zoomAxes, 1, 2);
                            hideFlag = false;
                        end
                    end
                end
            end
            
            
            slm.visibleFlag = 0;
            if (strcmp(slm.activePlane, activePlane))
                switch (slm.activePlane)
                    case 'sagittal'
                        if (slm.activeSlice == slices.sagittal)
                            slm.visibleFlag = 1;
                        end
                    case 'coronal'
                        if (slm.activeSlice == slices.coronal)
                            slm.visibleFlag = 1;
                        end
                    case 'axial'
                        if (slm.activeSlice == slices.axial)
                            slm.visibleFlag = 1;
                        end
                end
            end
            
            
            if (hideFlag)
                slm.hide();
            else
                
                if (~isempty(slm.zoomLines) && ~isempty(slm.mpoint_handles))
                    prev = slm.mpoint_handles(1).loc;
                    for lIdx = 1:length(slm.zoomLines)
                        next = slm.mpoint_handles(lIdx + 1).loc;
                        
                        if (ishandle(slm.zoomLines(lIdx)))
                            set(slm.zoomLines(lIdx), 'XData', [prev(1) next(1)], 'YData', [prev(2) next(2)], 'Color', [1 0 1]);
                        else
                            
                            slm.zoomLines(lIdx) = line([prev(1) next(1)], [prev(2) next(2)], 'Color', [1 0 1]);
                        end
                        
                        prev = next;
                    end
                end
            end
        end
        
        function [slm] = updateInteractivePoints(slm, index, zoom, zoomAxes, v1, v2)
            xLim = get(zoomAxes, 'XLim');
            yLim = get(zoomAxes, 'YLim');
            
            rPos = get(zoom.rectangle, 'Position');
            xRelPos = (slm.voxelLocations(index, v1) - rPos(1))/rPos(3);
            yRelPos = (slm.voxelLocations(index, v2) - rPos(2))/rPos(4);
            
            xPos = xRelPos*(xLim(2) - xLim(1)) + xLim(1);
            yPos = yRelPos*(yLim(2) - yLim(1)) + yLim(1);
            
            slm.activePoint = index;
            slm.mpoint_handles(index).setPosition(xPos, yPos);
        end;
        
        
        
        function [idx] = getLandmarkIndexByHandle(slm, ad)
            idx = [];
            if (~isempty(ad.landmarks))
                for lmIdx = 1:length(ad.landmarks)
                    if (isa(ad.landmarks{lmIdx}, 'semi_landmark'))
                        if (~isempty(ad.landmarks{lmIdx}.sagPoints))
                            if (ad.landmarks{lmIdx}.sagPoints(1) == slm.sagPoints(1))
                                idx = lmIdx;
                                break;
                            end
                        end
                    end
                end
            end
        end;
        
        function delete(slm)
            
            
            if (~isempty(slm.mpoint_handles))
                for p = 1:slm.numPoints
                    delete(slm.mpoint_handles(p));
                end
            end
            
            if (~isempty(slm.zoomLines))
                for lIdx = 1:length(slm.zoomLines)
                    if (ishandle(slm.zoomLines(lIdx)))
                        delete(slm.zoomLines(lIdx));
                    end
                end
            end
        end
        
        function slm = reset_callbacks(slm)
            %slm.resetCallbackHandlers_handle();
            slm = slm.resetCallbackHandlers();
        end
        
        function slm = reassignIndex(slm, newIndex)
            slm.index = newIndex;
        end
    end
end