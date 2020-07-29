function [] = save_data(ad, savePath, saveName, format)

if (~isempty(ad.landmarks))
    
    switch (format)
        case 'csv'
            save_csv();
        case 'xml'
            save_xml();
    end
end

    function [] = save_csv()
        FID = fopen(fullfile(savePath, [saveName '.csv']), 'w');
        if (isfield(ad, 'data'))
            writeLine('General - original raw data file name', ad.rawDataFileName);
        end
        
        writeLine('General - voxel origin (sag-cor-axi)', ad.origin);
        writeLine('General - voxel size (sag-cor-axi)', ad.voxel_size);
        
        for lIdx = 1:length(ad.landmarks)
            if (isa(ad.landmarks{lIdx}, 'point_landmark'))
                writePointLandmark(lIdx, ad.landmarks{lIdx});
            elseif (isa(ad.landmarks{lIdx}, 'semi_landmark'))
                writeSemiLandmark(lIdx, ad.landmarks{lIdx});
            end
        end
        
        fclose(FID);
        
        function [] = writePointLandmark(index, plm)
            writeLine(['Point Landmark ' num2str(index) ' - name'], plm.name);
            writeLine(['Point Landmark ' num2str(index) ' - class'], plm.class);
            writeLine(['Point Landmark ' num2str(index) ' - index'], num2str(plm.index));
            writeLine(['Point Landmark ' num2str(index) ' - voxel location (sag-cor-axi)'], plm.voxelLocation);
            writeLine(['Point Landmark ' num2str(index) ' - mm location (sag-cor-axi)'], plm.mmLocation);
        end
        
        function [] = writeSemiLandmark(index, slm)
            writeLine(['Semilandmarks ' num2str(index) ' - name'], slm.name);
            writeLine(['Semilandmarks ' num2str(index) ' - class'], slm.class);
            writeLine(['Semilandmarks ' num2str(index) ' - index'], num2str(slm.index));
            writeLine(['Semilandmarks ' num2str(index) ' - number of points'], num2str(slm.numPoints));
            
            for sIdx = 1:slm.numPoints
                writeLine(['Semilandmarks ' num2str(index) ' - #' num2str(sIdx)  ' - confidence'], slm.confidences(sIdx));
                writeLine(['Semilandmarks ' num2str(index) ' - #' num2str(sIdx)  ' - voxel location (sag-cor-axi)'], slm.voxelLocations(sIdx, :));
                writeLine(['Semilandmarks ' num2str(index) ' - #' num2str(sIdx)  ' - mm location (sag-cor-axi)'], slm.mmLocations(sIdx, :));
            end
        end
        
        %Row data must be a 1-D vector of values
        function [] = writeLine(rowName, rowData)
            line = rowName;
            
            for rIdx = 1:length(rowData)
                if (ischar(rowData))
                    line = [line ', ' rowData];
                    break;
                else
                    line = [line ', ' num2str(rowData(rIdx))];
                end
            end
            
            line = [line '\n'];
            fprintf(FID, line);
        end
    end

    function [] = save_xml()
        %========================================================================
        %Create XML template from the regression equations
        %========================================================================
        fileName = saveName;
        docNode = com.mathworks.xml.XMLUtils.createDocument(['doc_name_' strrep(strrep(fileName, '[', ''), ']', '')]);
        docRootNode = docNode.getDocumentElement;
        
        generalInfoNode = docNode.createElement('general_info');
        
        if (isfield(ad, 'data'))
            createNode(generalInfoNode, 'original_file', ad.rawDataFileName);
        end
        
        create3DNode(generalInfoNode, 'voxel_origin', ad.origin);
        create3DNode(generalInfoNode, 'voxel_size', ad.voxel_size);
        
        pointLandmarksNode = docNode.createElement('point_landmarks_list');
        semiLandmarksNode = docNode.createElement('semi_landmarks_list');
        
        for lIdx = 1:length(ad.landmarks)
            if (isa(ad.landmarks{lIdx}, 'point_landmark'))
                addPointLandmarkNode(pointLandmarksNode, ad.landmarks{lIdx});
            elseif (isa(ad.landmarks{lIdx}, 'semi_landmark'))
                addSemiLandmarkNode(semiLandmarksNode, ad.landmarks{lIdx});
            end
        end
        
        
        docRootNode.appendChild(generalInfoNode);
        docRootNode.appendChild(pointLandmarksNode);
        docRootNode.appendChild(semiLandmarksNode);
        fileName = fullfile(savePath, [saveName '.xml']);
        xmlwrite(fileName, docNode);
        type(fileName);
        
        function newNode = createNode(parent, nodeName, nodeTextData)
            newNode = docNode.createElement(nodeName);
            newNode.appendChild(docNode.createTextNode(nodeTextData));
            parent.appendChild(newNode);
        end
        
        function create3DNode(parent, parent3DNodeName, data3D)
            parent3DNode = docNode.createElement(parent3DNodeName);
            planes = {'sagittal', 'coronal', 'axial'};

            for cIdx = 1:3
                createNode(parent3DNode, planes{cIdx}, num2str(data3D(cIdx)));
            end
            parent.appendChild(parent3DNode);
        end
        
        function [plmNode] = addPointLandmarkNode(parent, plm)
            plmNode = docNode.createElement('point_landmark');
            createNode(plmNode, 'name', plm.name);
            createNode(plmNode, 'type', 'point_landmark');
            createNode(plmNode, 'class', plm.class);
            createNode(plmNode, 'index', num2str(plm.index));
            createNode(plmNode, 'confidence', num2str(plm.confidence));
            
            create3DNode(plmNode, 'voxel_location', plm.voxelLocation);
            create3DNode(plmNode, 'mm_location', plm.mmLocation);
            parent.appendChild(plmNode);
        end
        
        function [slmNode] = addSemiLandmarkNode(parent, slm)
            slmNode = docNode.createElement('semi_landmark');
            createNode(slmNode, 'name', slm.name);
            createNode(slmNode, 'type', 'semilandmarks');
            createNode(slmNode, 'class', slm.class);
            createNode(slmNode, 'index', num2str(slm.index));
            createNode(slmNode, 'number_of_points', num2str(slm.numPoints));
            
            semilandmarkPointList = docNode.createElement('semi_landmark_point_list');
            for sIdx = 1:slm.numPoints
                semilandmarkPointNode = docNode.createElement('semi_landmark_point');
                createNode(semilandmarkPointNode, 'number', num2str(sIdx));
                createNode(semilandmarkPointNode, 'confidence', num2str(slm.confidences(sIdx)));
                create3DNode(semilandmarkPointNode, 'voxel_location', slm.voxelLocations(sIdx, :));
                create3DNode(semilandmarkPointNode, 'mm_location', slm.mmLocations(sIdx, :));
                semilandmarkPointList.appendChild(semilandmarkPointNode);
            end
            slmNode.appendChild(semilandmarkPointList);
            
            parent.appendChild(slmNode);
        end
    end


end
