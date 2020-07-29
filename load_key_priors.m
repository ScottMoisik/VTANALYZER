function [key_priors] = load_key_priors(xmlTemplateFileName, volume)
%=========================================================================
%PARSE XML TEMPLATE
%=========================================================================
%Parse XML template to discover what priors to load and how they are defined
template = xmlread(fullfile(pwd, xmlTemplateFileName));
root = template.getDocumentElement;
%type(fullfile(pwd, xmlTemplateFileName))
tim = 1;

keys = root.getElementsByTagName('key_landmark');

%=========================================================================
%PRE-PROCESS VOLUME
%=========================================================================
%Subject position in T1 scans appear to be all aligned. 
%Nose is located at the upper end of the coronal slice set 
%Top of head is located at the upper end of the axial slice set

numSag = size(volume, 1);
numCor = size(volume, 2);
numAxi = size(volume, 3);

count = 1;
S = struct();
%figure;
for sIdx = 1:numSag
    S.sag(sIdx).cor = sum(squeeze(volume(sIdx, :, :)));
    S.sag(sIdx).axi = sum(squeeze(volume(sIdx, :, :)), 2);
    S.sag(sIdx).corMeanVals = mean(S.sag(sIdx).cor);
    S.sag(sIdx).axiMeanVals = mean(S.sag(sIdx).axi);
    
    meanVals(count) = mean([S.sag(sIdx).corMeanVals S.sag(sIdx).axiMeanVals]);
    count = count + 1;
    
    %{
    subplot(1, 3, 1); imagesc(flipud(squeeze(volume(sIdx, :, :))'));
    subplot(1, 3, 2); plot(S.sag(sIdx).cor); line([0 numCor], [S.sag(sIdx).corMeanVals S.sag(sIdx).corMeanVals]); axis xy
    subplot(1, 3, 3); plot(S.sag(sIdx).axi); line([0 numAxi], [S.sag(sIdx).axiMeanVals S.sag(sIdx).axiMeanVals]); 
    tim = 1;
    %}
end

%figure;
for cIdx = 1:numCor
    S.cor(cIdx).sag = sum(squeeze(volume(:, cIdx, :)), 2);
    S.cor(cIdx).axi = sum(squeeze(volume(:, cIdx, :)));
    S.cor(cIdx).sagMeanVals = mean(S.cor(cIdx).sag);
    S.cor(cIdx).axiMeanVals = mean(S.cor(cIdx).axi);
    
    meanVals(count) = mean([S.cor(cIdx).sagMeanVals S.cor(cIdx).axiMeanVals]);
    count = count + 1;
    %{
    subplot(1, 3, 1); imagesc(flipud(squeeze(volume(:, cIdx, :))'));
    subplot(1, 3, 2); plot(sums.cor(cIdx).sag); line([0 numSag], [sums.cor(cIdx).sagMeanVals sums.cor(cIdx).sagMeanVals]);
    subplot(1, 3, 3); plot(sums.cor(cIdx).axi); line([0 numAxi], [sums.cor(cIdx).axiMeanVals sums.cor(cIdx).axiMeanVals]); 
    tim = 1;
    %}
end

%figure;
for aIdx = 1:numAxi
    S.axi(aIdx).sag = sum(squeeze(volume(:, :, aIdx)), 2);
    S.axi(aIdx).cor = sum(squeeze(volume(:, :, aIdx)));
    S.axi(aIdx).sagMeanVals = mean(S.axi(aIdx).sag);
    S.axi(aIdx).corMeanVals = mean(S.axi(aIdx).cor);
    
    meanVals(count) = mean([S.axi(aIdx).sagMeanVals S.axi(aIdx).corMeanVals]);
    count = count + 1;
    %{
    subplot(1, 3, 1); imagesc(flipud(squeeze(volume(:, :, aIdx))'));

    subplot(1, 3, 2); plot(S.axi(aIdx).sag); line([0 numSag], [S.axi(aIdx).sagMeanVals S.axi(aIdx).sagMeanVals]);
    subplot(1, 3, 3); plot(S.axi(aIdx).cor); line([0 numCor], [S.axi(aIdx).corMeanVals S.axi(aIdx).corMeanVals]);

    tim = 1;
    %}
end

globalMean = mean(meanVals);


%=========================================================================
%FIND KEY LANDMARK PRIORS
%=========================================================================

numPriors = 0;
symmetrize = [];
for k = 0:keys.getLength-1
   listItem = keys.item(k);
   
   name = char(listItem.getElementsByTagName('name').item(0).getFirstChild.getData);
   type = char(listItem.getElementsByTagName('type').item(0).getFirstChild.getData);
   plane = char(listItem.getElementsByTagName('plane').item(0).getFirstChild.getData);
   dir = char(listItem.getElementsByTagName('dir').item(0).getFirstChild.getData);
   threshold = str2double(listItem.getElementsByTagName('threshold').item(0).getFirstChild.getData);
   try
       search_limit = str2double(listItem.getElementsByTagName('search_limit_from_top').item(0).getFirstChild.getData);
   catch
       search_limit = 1.0;
   end
        
   
   symmetry_mate = [];
   if (listItem.getElementsByTagName('symmetry_mate').item(0).hasChildNodes)
       symmetry_mate = char(listItem.getElementsByTagName('symmetry_mate').item(0).getFirstChild.getData);
   end
   
   %Create prior for based on the specifications in the template
   numPriors = numPriors + 1;
   key_priors(numPriors).name = name;
   key_priors(numPriors).voxelLocation = findApex(plane, dir, threshold, search_limit);
   key_priors(numPriors).symmetryMate = symmetry_mate;
   key_priors(numPriors).symmetrizedFlag = false;
   
   if (~isempty(symmetry_mate))
       symmetrize = [symmetrize numPriors];
   end
end

for sIdx = 1:length(symmetrize)
    symIdx = symmetrize(sIdx);
    if (~key_priors(symIdx).symmetrizedFlag)
        mateIdx = findSymmetryMate(key_priors(symIdx).name, key_priors(symIdx).symmetryMate);
        
        switch (plane)
            case 'sag'
                avgCor = min(max(floor(mean([key_priors(symIdx).voxelLocation(2) key_priors(mateIdx).voxelLocation(2)])), 1), numCor);
                avgAxi = min(max(floor(mean([key_priors(symIdx).voxelLocation(3) key_priors(mateIdx).voxelLocation(3)])), 1), numAxi);
                key_priors(symIdx).voxelLocation = [key_priors(symIdx).voxelLocation(1) avgCor avgAxi];
                key_priors(mateIdx).voxelLocation = [key_priors(mateIdx).voxelLocation(1) avgCor avgAxi];
            case 'cor'
                avgSag = min(max(floor(mean([key_priors(symIdx).voxelLocation(1) key_priors(mateIdx).voxelLocation(1)])), 1), numSag);
                avgAxi = min(max(floor(mean([key_priors(symIdx).voxelLocation(3) key_priors(mateIdx).voxelLocation(3)])), 1), numAxi);
                key_priors(symIdx).voxelLocation = [avgSag key_priors(symIdx).voxelLocation(2) avgAxi];
                key_priors(mateIdx).voxelLocation = [avgSag key_priors(mateIdx).voxelLocation(2) avgAxi];
            case 'axi'
                avgSag = min(max(floor(mean([key_priors(symIdx).voxelLocation(1) key_priors(mateIdx).voxelLocation(1)])), 1), numSag);
                avgCor = min(max(floor(mean([key_priors(symIdx).voxelLocation(2) key_priors(mateIdx).voxelLocation(2)])), 1), numCor);
                key_priors(symIdx).voxelLocation = [avgSag avgCor key_priors(symIdx).voxelLocation(3)];
                key_priors(mateIdx).voxelLocation = [avgSag avgCor  key_priors(mateIdx).voxelLocation(3)];
        end
        
        key_priors(symIdx).symmetrizedFlag = true;
        key_priors(mateIdx).symmetrizedFlag = true;
    end

end

    function mateIdx = findSymmetryMate(name, mateName)
        for kIdx = 1:length(key_priors)
            if (strcmp(key_priors(kIdx).name, mateName) && strcmp(key_priors(kIdx).symmetryMate, name))
                mateIdx = kIdx;
                return;
            end
        end
    end


%{
%Detect top of head
numPriors = numPriors + 1;
priors(numPriors).name = 'head top';
priors(numPriors).voxelLocation = findApex('axi', numAxi, -1, 1, 0.25);

%Detect back of head
numPriors = numPriors + 1;
priors(numPriors).name = 'head back';
priors(numPriors).voxelLocation = findApex('cor', 1, 1, numCor, 0.35);

%Detect tip of nose
numPriors = numPriors + 1;
priors(numPriors).name = 'nose tip';
priors(numPriors).voxelLocation = findApex('cor', numCor, -1, 1, 0.25);

%Detect the sides of the head
leftSideVox = findApex('sag', 1, 1, numSag, 1.3);
rightSideVox = findApex('sag', numSag, -1, 1, 1.3);

avgCor = min(max(floor(mean([leftSideVox(2) rightSideVox(2)])), 1), numCor);
avgAxi = min(max(floor(mean([leftSideVox(3) rightSideVox(3)])), 1), numAxi);

%Detect left side of head
numPriors = numPriors + 1;
priors(numPriors).name = 'head side (left)';
priors(numPriors).voxelLocation = [leftSideVox(1) avgCor avgAxi];

%Detect right side of head
numPriors = numPriors + 1;
priors(numPriors).name = 'head side (right)';
priors(numPriors).voxelLocation = [rightSideVox(1) avgCor avgAxi];
%}


    function [voxel] = findApex(plane, dir, threshPercent, searchLimitFromTop)
        debug = false;
        if (debug), figure; end;
        lim = (1 - searchLimitFromTop); %Axial slice indices are arranged from bottom to top!
        switch (plane)
            case 'sag'
                num = numSag; numP1 = numCor; numP2 = numAxi;
                startP1 = 1; stopP1 = numCor; startP2 = max(min(floor(numAxi*lim), numAxi), 1); stopP2 = numAxi;
                P1 = 'axi';
                P2 = 'cor';
            case 'cor'
                num = numCor; numP1 = numSag; numP2 = numAxi;
                startP1 = 1; stopP1 = numSag; startP2 = max(min(floor(numAxi*lim), numAxi), 1); stopP2 = numAxi;
                P1 = 'sag';
                P2 = 'axi';
            case 'axi'
                num = numAxi; numP1 = numSag; numP2 = numCor;
                startP1 = 1; stopP1 = numSag; startP2 = 1; stopP2 = numCor;
                P1 = 'sag';
                P2 = 'cor';
        end
        
        switch (dir)
            case 'backward'
                start = num;
                increment = -1;
                stop = 1;
            case 'forward'
                start = 1;
                increment = 1;
                stop = num;
        end
        
        for idx = start:increment:stop
            mp = S.(plane);
            thresh = globalMean*threshPercent;
            sig1 = double(mp(idx).(P1));
            sig2 = double(mp(idx).(P2));
            [p1Peaks, p1Locs] = findpeaks(sig1(startP1:stopP1));
            [p2Peaks, p2Locs] = findpeaks(sig2(startP2:stopP2));
            
            %{
            p = (abs(p1Locs - numP1/2));
            peak1 = p1Locs(p == min(p));
            
            p = (abs(p2Locs - numP2/2));
            peak2 = p2Locs(p == min(p));
            %}
            
            p1Loc = p1Locs(p1Peaks == max(p1Peaks));
            p2Loc = p2Locs(p2Peaks == max(p2Peaks));
            
            if (debug)
                if (~isempty(p1Loc) && ~isempty(p2Loc))
                    p1Peak = p1Peaks(p1Locs == p1Loc(1));
                    p2Peak = p2Peaks(p2Locs == p2Loc(1));
                    
                    
                    switch (plane)
                        case 'sag'
                            subplot(1, 3, 1); imagesc(flipud(squeeze(volume(idx, :, :))'));
                        case 'cor'
                            subplot(1, 3, 1); imagesc(flipud(squeeze(volume(:, idx, :))'));
                        case 'axi'
                            subplot(1, 3, 1); imagesc(flipud(squeeze(volume(:, :, idx))'));
                    end
                    
                    subplot(1, 3, 2); plot(mp(idx).(P1)); line([0 numP1], [thresh thresh]); hold on; plot(p1Loc(1), p1Peak(1), 'r*'); hold off; title(num2str(p1Loc));
                    subplot(1, 3, 3); plot(mp(idx).(P2)); line([0 numP2], [thresh thresh]); hold on; plot(p2Loc(1), p2Peak(1) + startP2 - 1, 'r*'); hold off; title(num2str(p2Loc));
                    tim = 1;
                end
            end
            
            if (any(p1Peaks > thresh) && any(p2Peaks > thresh))
                
                switch (plane)
                    case 'sag'
                        voxel(1) = idx; voxel(2) = p1Loc(1); voxel(3) = p2Loc(1) + startP2 - 1;
                    case 'cor'
                        voxel(1) = p1Loc(1); voxel(2) = idx; voxel(3) = p2Loc(1) + startP2 - 1;
                    case 'axi'
                        voxel(1) = p1Loc(1); voxel(2) = p2Loc(1); voxel(3) = idx;
                end
                tim = 1;
                break;
            end
        end
    end
end