function [priors] = load_derived_priors(xmlTemplateFileName, landmarks)
%=========================================================================
%PARSE XML TEMPLATE
%=========================================================================
%Parse XML template to discover what priors to load and how they are defined
template = xmlread(fullfile(pwd, xmlTemplateFileName));
root = template.getDocumentElement;
%type(fullfile(pwd, xmlTemplateFileName))

keys = root.getElementsByTagName('key_landmark');
derivs = root.getElementsByTagName('derived_landmark');

keyNameList = [];
for k = 0:keys.getLength-1
    keyNameList = [keyNameList {char(keys.item(k).getElementsByTagName('name').item(0).getFirstChild.getData)}];
end

keyLandmarks = [];
for nIdx = 1:length(keyNameList)
    for lIdx = 1:length(landmarks)
        if (strcmp(keyNameList{nIdx}, landmarks{lIdx}.name))
            keyLandmarks = [keyLandmarks landmarks(lIdx)];
        end
    end
end

priors = [];
if (length(keyLandmarks) == keys.getLength)
    %Create predictor matrix
    P = zeros(length(keyLandmarks), 3);
    
    for lIdx = 1:length(keyLandmarks)
        P(lIdx, :) = keyLandmarks{lIdx}.voxelLocation;
    end   
    P = [ones(1, 3); P]; 
    
    %=========================================================================
    %PREDICT LOCATIONS OF THE PRIORS
    %=========================================================================
    
    for k = 0:derivs.getLength-1
        listItem = derivs.item(k);
        
        % Get the name of the landmark
        priors(k+1).name = char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData);
        priors(k+1).type = char(listItem.getElementsByTagName('type').item(0).getFirstChild.getData);
        regressNode = listItem.getElementsByTagName('regression_coefficients').item(0);
        lmBx = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(0), keys.getLength);
        lmBy = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(1), keys.getLength);
        lmBz = getRegressionCoefficients(regressNode.getElementsByTagName('dimension').item(2), keys.getLength);
        B = [lmBx lmBy lmBz];
        priors(k+1).voxelLocation = max(round([B(:, 1)'*P(:, 1) B(:, 2)'*P(:, 2) B(:, 3)'*P(:, 3)]), 1);
    end
end

    function B = getRegressionCoefficients(dimNode, numCoeffs)
        B = zeros(numCoeffs+1, 1);
        for i = 0:numCoeffs
            B(i+1, 1) = str2double(dimNode.getElementsByTagName(['b' num2str(i)]).item(0).getFirstChild.getData);
        end
    end
end