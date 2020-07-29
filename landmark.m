classdef landmark < handle
    properties
        name
        index
        visibleFlag
        
        origin
        voxelSize
        class
    end
    
    methods
        function lm = landmark(name, origin, voxelSize, index)
            lm.name = name;
            lm.index = index;
            lm.origin = origin;
            lm.voxelSize = voxelSize;
        end
    end
end
