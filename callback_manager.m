function [] = callback_manager(callback, type)

switch (type)
    case 'mouse_move'
        oldCallback = get(gcf, 'WindowButtonMotionFcn');
    case 'mouse_down'
        oldCallback = get(gcf, 'WindowButtonDownFcn');
    case 'mouse_up'
        oldCallback = get(gcf, 'WindowButtonUpFcn');
    case 'key_down'
        oldCallback = get(gcf, 'KeyPressFcn');
end

%disp(oldCallback);

fcnlist = [];
if (isa(oldCallback, 'function_handle'))
    fcnlist = [{oldCallback} {callback}];
elseif (iscell(oldCallback))
    fcnlist = [oldCallback{2, 1} {callback}];
end




switch (type)
    case 'mouse_move'
        set(gcf, 'WindowButtonMotionFcn', {@wrapper, fcnlist});
    case 'mouse_down'
        set(gcf, 'WindowButtonDownFcn', {@wrapper, fcnlist});
    case 'mouse_up'
        set(gcf, 'WindowButtonUpFcn', {@wrapper, fcnlist});
    case 'key_down'
        set(gcf, 'KeyPressFcn', {@wrapper, fcnlist});
end

    function wrapper(objh, eventdata, fcnlist)
        for fcnIdx = 1:length(fcnlist)
            %disp('evaluating');
            feval(fcnlist{fcnIdx}, objh, eventdata);
        end
    end

end