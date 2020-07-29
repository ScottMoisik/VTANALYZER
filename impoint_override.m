classdef impoint_override < impoint
%IMPOINTTEXTUPDATE subclasses impoint to override the delete function
 
  methods
    function obj = impoint_override(varargin)
      obj = obj@impoint(varargin{:});
    end %impointtextupdate
 
    function delete(obj)
        obj.setVisible(false);
    end
  end %methods
end %impointtextupdate