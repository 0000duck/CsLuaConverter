﻿_M = { };
_M.MetaTypes = {
    TypeObject = "TypeObject",
    ClassObject = "ClassObject",
    NameSpace = "NameSpace",
    InteractionElement = "InteractionElement",
    StaticValues = "StaticValues",
    NameSpaceElement = "NameSpaceElement",
    InteractionElement = "InteractionElement",
};
_M.__metaType = _M.MetaTypes.NameSpace

_M.NOT = setmetatable({}, { __add = function(_, value) 
    return not(value); 
end}); 

_M.AddRange = function(t1, t2)
    for i,v in pairs(t2) do
        table.insert(t1, v);
    end
end