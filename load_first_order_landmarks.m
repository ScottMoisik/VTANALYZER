function [priors, unlocatedNames] = load_first_order_landmarks(xmlTemplateFileName, landmarks, dims, lmSet)
%=========================================================================
%PARSE XML TEMPLATE
%=========================================================================
%Parse XML template to discover what priors to load and how they are defined
template = xmlread(fullfile(pwd, xmlTemplateFileName));
root = template.getDocumentElement;
%type(fullfile(pwd, xmlTemplateFileName))

keys = root.getElementsByTagName('key_landmark');
derivs = root.getElementsByTagName('first_order_landmark');

keyNameList = [];
for k = 0:keys.getLength-1
    keyNameList = [keyNameList {char(keys.item(k).getElementsByTagName('name').item(0).getFirstChild.getData)}];
end

keyLandmarks = [];
keyIdx = zeros(keys.getLength, 1);  %Index into the prediction vectors, 0 if a key is missing
for nIdx = 1:length(keyNameList)
    for lIdx = 1:length(landmarks)
        if (strcmp(keyNameList{nIdx}, landmarks{lIdx}.name))
            keyLandmarks = [keyLandmarks landmarks(lIdx)];
            keyIdx(nIdx) = 1;
        end
    end
end
keyIdx = logical([1; keyIdx]);

priors = [];
unlocatedNames = [];
if (~isempty(keyLandmarks))
    %Create predictor matrix
    P = zeros(keys.getLength, 3);
    
    for lIdx = 1:keys.getLength
        for kIdx = 1:length(keyLandmarks)
            if (strcmp(keyLandmarks{kIdx}.name, keyNameList{lIdx}))
                P(lIdx, :) = keyLandmarks{kIdx}.voxelLocation;
            end
        end
    end
    P = [ones(1, 3); P];
    
    %=========================================================================
    %READ MEAN POSITIONS OF KEY LANDMARKS FROM TEMPLATE, IF AVAILABLE
    %=========================================================================
    meanKeyLocs = zeros(keys.getLength, 3)*NaN;
    PT = [];
    doProcrustes = true;
    oldP = P;
    if (doProcrustes)
        try
            for kIdx = 1:keys.getLength
                meanKeyLocs(kIdx, 1) = str2double(keys.item(kIdx-1).getElementsByTagName('mean_x').item(0).getFirstChild.getData);
                meanKeyLocs(kIdx, 2) = str2double(keys.item(kIdx-1).getElementsByTagName('mean_y').item(0).getFirstChild.getData);
                meanKeyLocs(kIdx, 3) = str2double(keys.item(kIdx-1).getElementsByTagName('mean_z').item(0).getFirstChild.getData);
            end
            
            %Compute procrustes superimposition of mean key locations on the current (this sample's) key locations
            [~, Z, PT] = procrustes(meanKeyLocs, P(2:end, :), 'reflection', false);
            
            %Plot
            %{
            figure;
            colors = jet(size(meanKeyLocs, 1));
            scatter3(meanKeyLocs(:, 1), meanKeyLocs(:, 2), meanKeyLocs(:, 3), 100, colors, '.'); hold on;
            scatter3(P(2:end, 1), P(2:end, 2), P(2:end, 3), 100, colors, 'o');
            scatter3(Z(:, 1), Z(:, 2), Z(:, 3), 100, colors, 's');
            %}
            P(2:end, :) = Z;
        catch
        end
    end
    
    
    %=========================================================================
    %PREDICT LOCATIONS OF THE PRIORS
    %=========================================================================
    
    %If only a subset is requested, load those, otherwise, load all priors
    %{
    if (exist('subset', 'var'))
        count = 1;
        for ssIdx = 1:length(subset)
            for k = 0:derivs.getLength-1
                listItem = derivs.item(k);
                if (strcmp(subset{ssIdx}, char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData)))
                    priors(count).name = char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData);
                    priors(count).type = char(listItem.getElementsByTagName('type').item(0).getFirstChild.getData);
                    regressNode = listItem.getElementsByTagName('regression_coefficients').item(0);
                    lmBx = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(0), keys.getLength);
                    lmBy = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(1), keys.getLength);
                    lmBz = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(2), keys.getLength);
                    B = [lmBx lmBy lmBz];
                    priors(count).voxelLocation = max(round([B(:, 1)'*P(:, 1) B(:, 2)'*P(:, 2) B(:, 3)'*P(:, 3)]), 1);
                    count = count + 1;
                    break;
                end
            end
        end
    else
    %}
    debugPlot = false;
    if (debugPlot)
        
        recovP = round((PT.T*((1/PT.b)*(P(2:end, :) - PT.c)')))';
        figure;
        colors = jet(size(meanKeyLocs, 1));
        scatter3(meanKeyLocs(:, 1), meanKeyLocs(:, 2), meanKeyLocs(:, 3), 100, colors, '.'); hold on;
        scatter3(oldP(2:end, 1), oldP(2:end, 2), oldP(2:end, 3), 100, colors, 'o');
        scatter3(recovP(:, 1), recovP(:, 2), recovP(:, 3), 100, colors, '*');
        scatter3(Z(:, 1), Z(:, 2), Z(:, 3), 100, colors, 's');
    end
    
    count = 1;
    for sIdx = 1:length(lmSet)
        lmIdx = NaN;
        for k = 0:derivs.getLength-1
            listItem = derivs.item(k);
            lmName = char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData);
            lmName = strrep(lmName, '_', ' ');
            if (strcmp(lmSet{sIdx}, lmName))
                lmIdx = k;
                break;
            end
        end
        
        if (~isnan(lmIdx))
            listItem = derivs.item(lmIdx);
            
            %Test if the landmark is visible
            regressNode = listItem.getElementsByTagName('regression_coefficients').item(0);
            lmBx = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(0), keys.getLength);
            lmBy = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(1), keys.getLength);
            lmBz = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(2), keys.getLength);
            B = [lmBx lmBy lmBz];
            tempVoxelLoc = [B(keyIdx, 1)'*P(keyIdx, 1) B(keyIdx, 2)'*P(keyIdx, 2) B(keyIdx, 3)'*P(keyIdx, 3)];
            
            %Apply procrustes transform if available (accounts for rotation of data away from template standard)
            if (~isempty(PT))
                
                if (debugPlot)
                    scatter3(tempVoxelLoc(1), tempVoxelLoc(2), tempVoxelLoc(3), 100, [1 0 1], 's'); hold on;
                end
                
                transformedLoc = round((PT.T*((1/PT.b)*(tempVoxelLoc - PT.c(1, :))')))';
                %transformedLoc = round(((1/PT.b)*PT.T\tempVoxelLoc') - PT.c(1, :)')';
                
                if (debugPlot)
                    scatter3(transformedLoc(1), transformedLoc(2), transformedLoc(3), 100, [1 0 1], 'o');
                    
                    set(gca, 'DataAspectRatio', [1 1 1]); view(90, 0); title(lmName);
                end
                
                tempVoxelLoc = transformedLoc; 
            else
                tempVoxelLoc = round(tempVoxelLoc);
            end
            
            lmName = char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData);
            if (((tempVoxelLoc(1) >= 1) && tempVoxelLoc(1) <= dims.sagittal.number) && ((tempVoxelLoc(2) >= 1) && tempVoxelLoc(2) <= dims.coronal.number) && ((tempVoxelLoc(3) >= 1) && tempVoxelLoc(3) <= dims.axial.number))
                % Get the name of the landmark
                priors(count).name = lmName;
                priors(count).type = char(listItem.getElementsByTagName('type').item(0).getFirstChild.getData);
                priors(count).voxelLocation = tempVoxelLoc; %max(round([B(:, 1)'*P(:, 1) B(:, 2)'*P(:, 2) B(:, 3)'*P(:, 3)]), 1);
                count = count + 1;
            else
                unlocatedNames = [unlocatedNames; {lmName}];
                disp(['Landmark ' lmName ' predicted to be outside of volume.']);
            end
        else
            %unlocatedNames = [unlocatedNames; {lmName}];
            disp(['Could not find landmark ' lmSet{sIdx} ' in the template']);
        end
    end
    %{end%}
end

    function B = getRegressionCoefficients(dimNode, numCoeffs)
        B = zeros(numCoeffs+1, 1);
        for i = 0:numCoeffs
            B(i+1, 1) = str2double(dimNode.getElementsByTagName(['b' num2str(i)]).item(0).getFirstChild.getData);
        end
    end
end