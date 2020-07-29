function [priors] = landmark_priors(volume)
%Subject position in T1 scans appear to be all aligned. 
%Nose is located at the upper end of the coronal slice set 
%Top of head is located at the upper end of the axial slice set

numPriors = 0;
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
    subplot(1, 3, 2); plot(sums.sag(sIdx).cor); line([0 numCor], [sums.sag(sIdx).corMeanVals sums.sag(sIdx).corMeanVals]); axis xy
    subplot(1, 3, 3); plot(sums.sag(sIdx).axi); line([0 numAxi], [sums.sag(sIdx).axiMeanVals sums.sag(sIdx).axiMeanVals]); 
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
    S.axi(aIdx).sag = sum(squeeze(volume(:, :, aIdx)));
    S.axi(aIdx).cor = sum(squeeze(volume(:, :, aIdx)), 2);
    S.axi(aIdx).sagMeanVals = mean(S.axi(aIdx).sag);
    S.axi(aIdx).corMeanVals = mean(S.axi(aIdx).cor);
    
    meanVals(count) = mean([S.axi(aIdx).sagMeanVals S.axi(aIdx).corMeanVals]);
    count = count + 1;
    %{
    subplot(1, 3, 1); imagesc(flipud(squeeze(volume(:, :, aIdx))'));
    subplot(1, 3, 2); plot(sums.axi(aIdx).sag); line([0 numSag], [sums.axi(aIdx).sagMeanVals sums.axi(aIdx).sagMeanVals]);
    subplot(1, 3, 3); plot(sums.axi(aIdx).cor); line([0 numCor], [sums.axi(aIdx).corMeanVals sums.axi(aIdx).corMeanVals]); 
    tim = 1;
    %}
end

globalMean = mean(meanVals);



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



    function [voxel] = findApex(plane, start, increment, stop, threshPercent)
        debug = false;
        if (debug), figure; end;
        
        switch (plane)
            case 'sag'
                num = numSag; numP1 = numCor; numP2 = numAxi;
                P1 = 'axi';
                P2 = 'cor';
            case 'cor'
                num = numCor; numP1 = numSag; numP2 = numAxi;
                P1 = 'sag';
                P2 = 'axi';
            case 'axi'
                num = numAxi; numP1 = numSag; numP2 = numCor;
                P1 = 'sag';
                P2 = 'cor';
        end
        
        
        for idx = start:increment:stop
            mp = S.(plane);
            thresh = globalMean*threshPercent;
            [p1Peaks, p1Locs] = findpeaks(mp(idx).(P1));
            [p2Peaks, p2Locs] = findpeaks(mp(idx).(P2));
            
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
                    subplot(1, 3, 3); plot(mp(idx).(P2)); line([0 numP2], [thresh thresh]); hold on; plot(p2Loc(1), p2Peak(1), 'r*'); hold off; title(num2str(p2Loc));
                    tim = 1;
                end
            end
            
            if (any(p1Peaks > thresh) && any(p2Peaks > thresh))
                
                switch (plane)
                    case 'sag'
                        voxel(1) = idx; voxel(2) = p1Loc(1); voxel(3) = p2Loc(1);
                    case 'cor'
                        voxel(1) = p1Loc(1); voxel(2) = idx; voxel(3) = p2Loc(1);
                    case 'axi'
                        voxel(1) = p2Loc(1); voxel(2) = p1Loc(1); voxel(3) = idx;
                end
                tim = 1;
                break;
            end
            
            
            
            
        end

    end


end