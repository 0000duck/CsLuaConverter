﻿
local InvokeMethod = function(member, element, generics, args, foldOutArray)
    if foldOutArray then
        local i = #(args);

        local value = args[i];
        args[i] = nil;
        for j = 0, (value % _M.DOT).Length - 1 do
            args[i+j] = (value % _M.DOT)[j];
        end
    end

    if member.generics then
        return member.func(element, member.generics, generics, unpack(args));
    else
        return member.func(element, unpack(args));
    end
end

local meta = {};
setmetatable(meta,{
    __index = function(_, index)
        if index == "type" then
            return System.Action.__typeof;
        elseif index == "__metaType" then
            return _M.MetaTypes.ClassObject;
        end
    end
});

local GenericMethod = function(members, elementOrStaticValues)
    
    local t = {};

    setmetatable(t,{
        __index = function(_, generics)
            if meta[generics] then
                return meta[generics];
            end

            return function(...)
                local member, foldOutArray = _M.AM(members, {...}, generics);
                return InvokeMethod(member, elementOrStaticValues, generics, {...}, foldOutArray);
            end
        end,
        __call = function(_, ...)
            local member, foldOutArray = _M.AM(members, {...});
            return InvokeMethod(member, elementOrStaticValues, {}, {...}, foldOutArray);
        end,
    });

    return t;
end

_M.GM = GenericMethod;

local MethodGenerics = function(generics)
    local t = {};
    setmetatable(t, {
        __index = function(self, key)
            for i,v in pairs(generics) do
                if v == key then
                    return i;
                end
            end
        end
    });
    return t;
end

_M.MG = MethodGenerics;