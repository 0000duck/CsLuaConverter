_M = { };
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

local function SetAddMeta(f)
    local mt = { __add = function(self, b) return f(self[1], b) end }
    return setmetatable({}, { __add = function(a, _) return setmetatable({ a }, mt) end })
end


_M.Add = SetAddMeta(function(a, b)
    assert(a, "Add called on a nil value (left).");
    assert(b, "Add called on a nil value (right).");
    if type(a) == "number" and type(b) == "number" then return a + b; end
    return tostring(a)..tostring(b);
end);
 
--============= Argument Matching =============
local ScoreArguments = function(expectedTypes, argTypes, args)
    local sum = 0;
    local str = "";

    for i,argType in ipairs(argTypes) do
        local expectedType = expectedTypes[i];
        if (expectedType == nil) then
            return nil, ", - Skipping candidate. Did not have enough expected types. Expected "..#(expectedTypes).." had: "..#(argTypes);
        end
        
        str = str .. "," .. expectedType.ToString();

        local score = argType.GetMatchScore(expectedType, args[i]);
        if (score == nil) then
            local additional = ""
            for j = i + 1, #(expectedTypes) do
                additional = ", " .. expectedTypes[j].ToString();
            end

            return nil, str .. additional .. " - Skipping candidate. Arg did not match "..argType.ToString();
        end
        sum = sum + score;
    end
    
    return sum, str;
end

local SelectMatchingByTypes = function(list, args, methodGenerics)
    assert(type(list) == "table", "Expected a table as 1th argument to _M.AM, got "..type(list))
    assert(type(args) == "table", "Expected a table as 2th argument to _M.AM, got "..type(args))
    local argTypes = {};
    local argTypeStr = "";

    for i,arg in ipairs(args) do
        argTypes[i] = (arg%_M.DOT).GetType();
        argTypeStr = argTypeStr .. "," .. argTypes[i].FullName;
    end
    
    local bestMatch, bestScore;
    local candidatesStr = "Candidates:";

    for _, element in ipairs(list) do
        local types = {};
        for _, t in ipairs(element.types) do 
            if type(t) == "string" then
                if methodGenerics and methodGenerics[element.generics[t]] then
                    table.insert(types, methodGenerics[element.generics[t]]);
                else
                    table.insert(types, System.Object.__typeof);
                end
            else
                table.insert(types, t);
            end
        end

        local score, scoreStr = ScoreArguments(types, argTypes, args);
        candidatesStr = candidatesStr .. "\n  " .. scoreStr;

        if not(score == nil) and (not(bestScore) or score > bestScore) then
            bestMatch = element;
            bestScore = score;
        end
    end
    
    if not(bestMatch) then
        error(string.format("No match found.\nArgs: %s.\n%s", argTypeStr, candidatesStr));
    end
    
    return bestMatch;
end

_M.AM = SelectMatchingByTypes;
local defaultValues;

local initializeDefaultValues = function()
    if defaultValues then 
        return 
    end

    defaultValues = {
        [System.Int32.__typeof] = 0,
        [System.Boolean.__typeof] = false,
    };
end


local GetDefaultValue = function(type)
    initializeDefaultValues();
    if not(defaultValues[type] == nil) then
        return defaultValues[type];
    end

    if type.IsEnum then
        return type.InteractionElement.__default;
    end
end
_M.DV = GetDefaultValue;


local DotMeta = function(fIndex, fNewIndex, fCall) 
    return setmetatable({}, {
        __mod = function(obj, _) 
            return setmetatable({}, {
                __index = function(_, index)
                    return fIndex(obj,index);
                end,
                __newindex = function(_, index, value)
                    return fNewIndex(obj, index, value);
                end,
                __call = function(_,...)
                    return fCall(obj, ...);
                end
            })
        end
    });
end

local GetType = function(obj, index)
    if type(obj) == "table" then
        if type(obj.type) == "table" and obj.type.__metaType == _M.MetaTypes.TypeObject then
            return obj.type;
        end
        return Lua.NativeLuaTable.__typeof;
    elseif type(obj) == "string" then
        return System.String.__typeof;
    elseif type(obj) == "function" then
        return System.Action.__typeof;
    elseif type(obj) == "boolean" then
        return System.Boolean.__typeof;
    elseif type(obj) == "number" then
        if obj == math.floor(obj) then
            return System.Int.__typeof;
        end
        return System.Double.__typeof;
    else
        error("Could not get type of object "..type(obj)..". Attempting to address index "..tostring(index));
    end
end

_M.DOT_LVL = function(level)
    return DotMeta(
        function(obj, index)  -- useage:  a%_M.dot%b
            assert(not(obj == nil), "Attempted to read index "..tostring(index).." on a nil value.");
            --assert(not(type(obj) == "table") or not(obj.__metaType == nil), "Attempted to read index "..tostring(index).." on a obj value with no meta type");

            if (type(obj) == "table" and (obj.__metaType ~= _M.MetaTypes.ClassObject and obj.__metaType ~= _M.MetaTypes.StaticValues) and not(index == "GetType")) then
                return obj[index];
            end

            if (type(obj) == "table" and (obj.__metaType == _M.MetaTypes.NameSpaceElement)) then
                return obj.__index(obj, index, level); 
            end

            local typeObject = GetType(obj, index);
            if (index == "GetType") then
                return function() return typeObject; end
            end

            return typeObject.interactionElement.__index(obj, index, level); 
        end, 
        function(obj, index, value)
            assert(not(obj == nil), "Attempted to write index "..tostring(index).." to a nil value.");
            assert(not(type(obj) == "table") or not(obj.__metaType == nil), "Attempted to write index "..tostring(index).." on a obj value with no meta type");

            if (type(obj) == "table" and (obj.__metaType == _M.MetaTypes.NameSpaceElement)) then
                return obj.__newindex(obj, index, value, level);
            end

            if (type(obj) == "table" and (obj.__metaType == _M.MetaTypes.InteractionElement)) then
                obj[index] = value;
                return;
            end

            local typeObject = GetType(obj, index);
            return typeObject.interactionElement.__newindex(obj, index, value, level); 
        end,
        function(obj, ...)
            assert(type(obj) == "function" or type(obj) == "table", "Attempted to invoke a "..type(obj).." value.");
            return obj(...);
        end
    );
end
_M.DOT = _M.DOT_LVL(nil);


local Enum = function(table, name, namespace)
    table.__typeof = System.Type(name, namespace, System.Object.__typeof, 0, nil, nil, table, 'Enum');

    return table;
end

_M.EN = Enum;


local GenericMethod = function(members, elementOrStaticValues)
    
    local t = {};

    setmetatable(t,{
        __index = function(_, generics)
            return function(...)
                local member = _M.AM(members, {...}, generics);

                if member.generics then
                    return member.func(elementOrStaticValues, member.generics, generics,...);
                else
                    return member.func(elementOrStaticValues,...);
                end
            end
        end,
        __call = function(_, ...)
            local member = _M.AM(members, {...});

            if member.generics then
                return member.func(elementOrStaticValues, member.generics, {},...);
            else
                return member.func(elementOrStaticValues,...);
            end
        end,
    });

    return t;
end

_M.GM = GenericMethod;

local MethodGenerics = function(generics)
    local t = {};
    setmetatable(t,{
        __index = function(_, key)
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

--============= Interaction Element =============

local expectOneMember = function(members, key)
    assert(type(members) == "table", "A table of one member was expected for key '"..tostring(key).."'. Got no table.");
    assert(#(members) == 1, "A table of one member was expected for key '"..tostring(key).."'. Got "..#(members).." members");
end

local clone;
clone = function(t,dept)
    local t2 = {};
    for i,v in pairs(t) do
        if dept > 1 and type(v) == "table" then
            t2[i] = clone(v, dept-1);
        else
            t2[i] = v;
        end
    end
    return t2;
end

local InteractionElement = function(metaProvider, generics)
    local element = { __metaType = _M.MetaTypes.InteractionElement };
    local staticValues = {__metaType = _M.MetaTypes.StaticValues};
    local extendedMethods = {};

    local catagory, typeObject, members, constructors, elementGenerator, implements, initialize = metaProvider(element, generics, staticValues);
    staticValues.type = typeObject;

    local where = function(list, evaluator, otherList)
        local t = {};
        for _, value in ipairs(list) do
            if evaluator(value) then
                table.insert(t, value);
            end
        end
        for _, value in ipairs(otherList) do
            if evaluator(value) then
                table.insert(t, value);
            end
        end
        return t;
    end

    local getMembers = function(key, level, staticOnly)
        return where(members[key] or {}, function(member)
            assert(member.memberType, "Member without member type in "..typeObject.FullName..". Key: "..key.." Level: "..tostring(member.level));
            local static = member.static;
            local public = member.scope == "Public";
            local protected = member.scope == "Protected";
            local memberLevel = member.level;
            local levelProvided = not(level == nil);
            local typeLevel = typeObject.level;

            return (not(staticOnly) or static) and
            (
                (levelProvided and memberLevel <= level) or
                (not(levelProvided) and (public or protected) and memberLevel <= typeLevel) or
                (not(levelProvided) and not(public or protected) and memberLevel == typeLevel)
            );

            --return (not(staticOnly) or member.static == true) and (member.scope == "Public" or (member.scope == "Protected" and level) or member.level == level or (not(level) and member.level == typeObject.level)) and (not(level) or level >= member.level);
        end, extendedMethods[key] or {});
    end

    local matchesAll = function(t1, t2)
        if not(#(t1) == #(t2)) then
            return false;
        end

        for i,_ in ipairs(t1) do
            if not(t1[i] == t2[i]) then
                return false;
            end
        end

        return true;
    end

    local orderByLevel = function(members)
        local t = {};

        for _,member in ipairs(members) do
            local inserted = false;

            for i,v in ipairs(t) do
                if member.level > v.level then
                    table.insert(t, i, member);
                    inserted = true;
                    break;
                end
            end

            if (inserted == false) then
                table.insert(t, member);
            end
        end

        return t;
    end

    local filterOverrides = function(fittingMembers, level)
        if #(fittingMembers) == 1 then
            return fittingMembers;
        end
        
        fittingMembers = orderByLevel(fittingMembers);

        local skippedMembers = {};
        local acceptedMembers = {};

        for i,member in ipairs(fittingMembers) do
            if not(acceptedMembers[i]) and not(skippedMembers[i]) then
                acceptedMembers[i] = true;
                if member.override then
                    for j,otherMember in ipairs(fittingMembers) do
                        if not(j == i) and matchesAll(member.types, otherMember.types) then
                            if member.level > otherMember.level then
                                acceptedMembers[i] = true;
                                skippedMembers[j] = true;
                                acceptedMembers[j] = false;
                            else
                                acceptedMembers[j] = true;
                                skippedMembers[i] = true;
                                acceptedMembers[i] = false;
                            end
                        end
                    end
                end
            end
        end

        local result = {};
        for i,v in pairs(acceptedMembers) do
            if v then
                table.insert(result, fittingMembers[i]);
            end
        end

        return result;
    end

    local index = function(self, key, level)
        if (key == "__metaType") then return _M.MetaTypes.InteractionElement; end

        if (key == "__Initialize") and initialize then
            return function(values) initialize(self, values); return self; end
        end

        local fittingMembers = filterOverrides(getMembers(key, level, false), level or typeObject.level);

        if #(fittingMembers) == 0 then
            fittingMembers = getMembers("#", level, false); -- Look up indexers
        end

        if #(fittingMembers) == 0 then
            error("Could not find member. Key: "..tostring(key)..". Object: "..typeObject.FullName.." Level: "..tostring(level));
        end

        for i=1,#(fittingMembers) do
            assert(type(fittingMembers[i].memberType) == "string", "Missing member type on member. Object: "..typeObject.FullName..". Key: "..tostring(key).." Level: "..tostring(level).." Member #: "..tostring(i))
        end

        if fittingMembers[1].memberType == "Field" or fittingMembers[1].memberType == "AutoProperty" then
            expectOneMember(fittingMembers, key);

            if fittingMembers[1].static then
                return staticValues[fittingMembers[1].level][key];
            end

            return self[fittingMembers[1].level][key];
        end

        if fittingMembers[1].memberType == "Indexer" then
            expectOneMember(fittingMembers, "#");
            return self[fittingMembers[1].level][key];
        end

        if fittingMembers[1].memberType == "Method" then
            return _M.GM(fittingMembers, self);
        end

        if fittingMembers[1].memberType == "Property" then
            return fittingMembers[1].get(self);
        end

        error("Could not handle member (get). Object: "..typeObject.FullName.." Type: "..tostring(fittingMembers[1].memberType)..". Key: "..tostring(key));
    end;

    local newIndex = function(self, key, value, level)
        local fittingMembers = getMembers(key, level, false);

        if #(fittingMembers) == 0 then
            fittingMembers = getMembers("#", level, false); -- Look up indexers
        end

        if #(fittingMembers) == 0 then
            error("Could not find member (set). Key: "..tostring(key)..". Object: "..typeObject.FullName.." Level: "..tostring(level));
        end

        if fittingMembers[1].memberType == "Field" or fittingMembers[1].memberType == "AutoProperty" then
            expectOneMember(fittingMembers, key);

            if (fittingMembers[1].static) then
                staticValues[fittingMembers[1].level][key] = value;
                return;
            end

            self[fittingMembers[1].level][key] = value;
            return
        end

        if fittingMembers[1].memberType == "Indexer" then
            expectOneMember(fittingMembers, "#");
            self[fittingMembers[1].level][key] = value;
            return
        end

        if fittingMembers[1].memberType == "Property" then
            expectOneMember(fittingMembers, key);
            fittingMembers[1].set(self, value);
            return 
        end

        error("Could not handle member (set). Object: "..typeObject.FullName.." Type: "..tostring(fittingMembers[1].memberType)..". Key: "..tostring(key)..". Num members: "..#(fittingMembers));
    end

    local meta = {
        __typeof = typeObject,
        __is = function(value) return typeObject.IsInstanceOfType(value); end,
        __meta = function(inheritingStaticValues) 
            for i = 1, typeObject.level do
                inheritingStaticValues[i] = staticValues[i];
            end

            return typeObject, clone(members, 2), clone(constructors or {},2), elementGenerator, clone(implements or {},1), initialize; 
        end,
        __index = index,
        __newindex = newIndex,
        __metaType = _M.MetaTypes.InteractionElement,
        __extend = function(extensions) 
            for _,v in ipairs(extensions) do
                if not(extendedMethods[v.name]) then
                    extendedMethods[v.name] = {};
                end
                v.level = typeObject.level;
                table.insert(extendedMethods[v.name], v);
            end
        end,
    };

    
    setmetatable(element, { 
        __index = function(_, key)
            if not(meta[key] == nil) then 
                return meta[key];
            end

            if (key == "type") then
                return nil;
            end

            if not(catagory == "Class") then
                if (key == "GetType") then
                    return nil;
                end

                error(string.format("Could not find key on a non class element. Category: %s. Key: %s.", tostring(catagory), tostring(key)));
            end

            local fittingMembers = getMembers(key, nil, true);

            if #(fittingMembers) == 0 then
                error("Could not find static member. Key: "..tostring(key)..". Object: "..typeObject.FullName);
            end

            if (fittingMembers[1].memberType == "Method") then
                return _M.GM(fittingMembers, staticValues);
            end

            expectOneMember(fittingMembers, key);
            local member = fittingMembers[1];

            if member.memberType == "Property" then
                return member.get(staticValues);
            end

            if member.memberType == "AutoProperty" then
                return staticValues[member.level][key];
            end

            assert(member.memberType == "Field", "Expected field member for key "..tostring(key)..". Got "..tostring(member.memberType)..". Object: "..typeObject.FullName..".");
            return staticValues[member.level][key];
        end,
        __newindex = function(_, key, value)
            if not(catagory == "Class") then
                error(string.format("Could not set key on a non class element. Category: %s. Key: %s.", tostring(catagory), tostring(key)));
            end

            local fittingMembers = getMembers(key, nil, true);
            expectOneMember(fittingMembers, key);
            local member = fittingMembers[1];

            if member.memberType == "Property" then
                member.set(staticValues, value);
                return 
            end

            if member.memberType == "AutoProperty" then
                staticValues[member.level][key] = value;
                return;
            end

            assert(member.memberType == "Field", "Expected field member for key "..tostring(key)..". Got "..tostring(member.memberType)..". Object: "..typeObject.FullName..".");
            staticValues[member.level][key] = value;
        end,
        __call = function(_, ...)
            assert(type(constructors)=="table" and #(constructors) > 0, "Class did not provide any constructors. Type: "..typeObject.FullName);
            -- Generate the base class element from constructor.GenerateBaseClass
            local classElement = elementGenerator();
            -- find the constructor fitting the arguments.
            local constructor = _M.AM(constructors, {...});
            -- Call the constructor
            constructor.func(classElement, ...);

            return classElement;
        end,
    });

    return element;
end

_M.IE = InteractionElement;

local InsertMember = function(members, key, member)
    if not(members[key]) then
        members[key] = {};
    end

    table.insert(members[key], member);
end
_M.IM = InsertMember;

local BaseCstor = function(classElement, baseConstructors, ...)
    local constructor = _M.AM(baseConstructors, {...});
    constructor.func(classElement, ...);
end
_M.BC = BaseCstor;

--============= Namespace Element =============

local getHashOfGenerics = function(generics)
    local i = 1;
    for _,v in ipairs(generics) do
        i = i*v.GetHashCode();
    end
    return i;
end

local isGenericsTable = function(t)
    if not(type(t) == "table") then
        return false;
    end
    
    for _,v in ipairs(t) do
        if not(type(v) == "table") or not(System.Type.__is(v)) then
            return false;
        end
    end
    return true;
end

local NamespaceElement = function(metaProviders)
    local interactionElements = {};
    
    local getInteractionElement = function(generics)
        generics = generics or {};
        local hash = getHashOfGenerics(generics);
        if not(interactionElements[hash]) then
            assert(metaProviders[#(generics)] or metaProviders["#"], string.format("Could not find meta provider fitting number of generics: %s or '#'", #(generics)));
            interactionElements[hash] = _M.IE(metaProviders[#(generics)] or metaProviders["#"], generics);
        end
        
        return interactionElements[hash];
    end

    local element = {};
    setmetatable(element, { 
        __index = function(_, key)
            if key == "__metaType" then
                return _M.MetaTypes.NameSpaceElement;
            end

            if not(isGenericsTable(key)) then
                return getInteractionElement()[key];
            end
            return getInteractionElement(key);
        end,
        __newindex = function(_, key, value)
            getInteractionElement()[key] = value;
        end,
        __call = function(_, ...)
            return getInteractionElement()(...);
        end,
    });

    return element;
end

_M.NE = NamespaceElement;

_M.Throw = function(exception)
    if not(System.Exception.__is(exception)) then
        error("Non exception thrown.");
    end

    _M._CurrentException = exception;
    error((exception % _M.DOT).ToString(), 2);
end

_M.Try = function(try, catch, finally)
    _M._CurrentException = nil;
    local success, err = pcall(try)
    local exception = _M._CurrentException;
    _M._CurrentException = nil;

    if not(success) then
        exception = exception or System.Exception("Lua error:\n" .. (err or "nil"));
        
        local matchFound = false;
        for _, catchCase in ipairs(catch or {}) do
            if catchCase.type == nil or catchCase.type.interactionElement.__is(exception) then
                catchCase.func(exception)
                matchFound = true;
                break;
            end
        end

        if (matchFound == false) then -- rethrow
            if finally then
                finally();
            end

            __CurrentException = exception;
            error(err, 2);
        end
    end

    if finally then
        finally();
    end
end
System = { __metaType = _M.MetaTypes.NameSpace };
local actionTypeObject;
System.Action = _M.NE({["#"] = function(interactionElement, generics, staticValues)
    -- Note: System.Action is throwing away all generics, as it is not possible for lua to distingush between them.
    local typeObject = actionTypeObject or System.Type('Action','System',System.Object.__typeof,0,nil,nil,interactionElement);
    actionTypeObject = typeObject;
    local level = 2;
    local members = {
        
    };
    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
System.Array = _M.NE({[1] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Array','System', baseTypeObject,#(generics),generics,nil,interactionElement);

    local len = function(element)
        return (element[typeObject.level][0] and 1 or 0) + #(element[typeObject.level]);
    end

    _M.IM(members,'GetEnumerator',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {},
        func = function(element)
            return function(_, prevKey) 
                local key;
                if prevKey == nil then
                    key = 0;
                else
                    key = prevKey + 1;
                end

                if key < len(element) then
                    return key, element[typeObject.level][key];
                end
                return nil, nil;
            end;
        end,
    });

    _M.IM(members,'Length',{
        level = typeObject.Level,
        memberType = 'Property',
        scope = 'Public',
        types = {},
        get = function(element)
            return len(element);
        end,
    });

    _M.IM(members,'#',{
        level = typeObject.Level,
        memberType = 'Indexer',
        scope = 'Public',
        types = {generics[1]},
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };

    local initialize = function(self, values)
        for i,v in pairs(values) do
            self[typeObject.Level][i] = v;
        end
    end;
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator, nil, initialize;
end})

local areAllOfType = function(objs, type)
    for _,v in pairs(objs) do
        if not(type.IsInstanceOfType(v)) then
            return false;
        end
    end
    return true;
end

local getHighestCommonType = function(objs)
    local type;
    for i,v in pairs(objs) do
        type = (v %_M.DOT).GetType();
        break;
    end

    while (type) do
        if areAllOfType(objs, type) then
            return type;
        end
        type = type.BaseType;
    end

    error("No common type found");
end

ImplicitArray = function(t)
    local type = getHighestCommonType(t);
    return (System.Array[{type}]() % _M.DOT).__Initialize(t);
end
System.Boolean = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Boolean','System',baseTypeObject,0,nil,nil,interactionElement);

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})

System.Collections = System.Collections or { __metaType = _M.MetaTypes.NameSpace };
System.Collections.Generic = System.Collections.Generic or { __metaType = _M.MetaTypes.NameSpace };

System.Collections.Generic.Dictionary = _M.NE({[2] = function(interactionElement, generics, staticValues)
    local implements = {};
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Dictionary','System.Collections.Generic',baseTypeObject,2,generics,implements,interactionElement);
    
    _M.IM(members,'Keys',{
        level = typeObject.Level,
        memberType = 'Property',
        scope = 'Public',
        get = function(element)
            return System.Collections.Generic.KeyCollection[generics](element);
        end,
    });

    _M.IM(members,'GetEnumerator',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {},
        func = function(element)
            return pairs(element[2]);
        end,
    });

    _M.IM(members,'#',{
        level = typeObject.Level,
        memberType = 'Indexer',
        scope = 'Public',
        types = {generics[1], generics[2]},
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };

    local initialize = function(element, values)
        for i,v in pairs(values) do
            element[2][i] = v;
        end
    end

    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end

    return "Class", typeObject, members, constructors, objectGenerator, implements, initialize;
end})

System.Collections.Generic.KeyCollection = _M.NE({[2] = function(interactionElement, generics, staticValues)
    local implements = {};
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('KeyCollection','System.Collections.Generic',baseTypeObject,1,generics,implements,interactionElement);
    
    _M.IM(members,'GetEnumerator',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {},
        func = function(element)
            return pairs(element[2]);
        end,
    });

    local constructors = {
        {
            types = {System.Collections.Generic.Dictionary[generics].__typeof},
            func = function(element, dictionary) 
                for key,_ in pairs(dictionary[2]) do
                    table.insert(element[2],key);
                end
            end,
        }
    };

    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end

    return "Class", typeObject, members, constructors, objectGenerator;
end})

System.Collections.Generic.List = _M.NE({[1] = function(interactionElement, generics, staticValues)
    local implements = {};
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('List','System.Collections.Generic',baseTypeObject,1,generics,implements,interactionElement);

    local getCount = function(element)
        return not(element[2][0] == nil) and (#(element[2]) + 1) or 0;
    end

    _M.IM(members,'ForEach',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {System.Action[{generics[1]}].__typeof},
        func = function(element,action)
            for i = 0,getCount(element)-1 do
                (action%_M.DOT)(element[2][i]);
            end
        end,
    });

    _M.IM(members,'Count',{
        level = typeObject.Level,
        memberType = 'Property',
        scope = 'Public',
        types = {},
        get = function(element)
            return getCount(element);
        end,
    });

    _M.IM(members,'#',{
        level = typeObject.Level,
        memberType = 'Indexer',
        scope = 'Public',
        types = {generics[1]},
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };

    local initialize = function(element, values)
        for i=1,#(values) do
            element[2][i-1] = values[i];
        end
    end

    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end

    return "Class", typeObject, members, constructors, objectGenerator, implements, initialize;
end})
System.Double = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Double','System',baseTypeObject,0,nil,nil,interactionElement);

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
System.Enum = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Enum','System',baseTypeObject,0,nil,nil,interactionElement);

    _M.IM(members,'Parse',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {System.Type.__typeof, System.String.__typeof},
        func = function(staticValues, typeObj, str)
            for _,v in pairs(typeObj.interactionElement) do
                if type(v) == "string" and string.lower(str) == string.lower(v) then
                    return v;
                end
            end
            return nil;
        end,
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})

System.Exception = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('Exception','System',baseTypeObject,0,nil,nil,interactionElement);
    local level = 2;

    _M.IM(members,'Message',{
        level = typeObject.Level,
        memberType = 'AutoProperty',
        scope = 'Public',
    });

    _M.IM(members,'ToString',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {typeObject},
        func = function(element)
            return (element % _M.DOT).Message;
        end,
    });

    local constructors = {
        {
            types = {System.String.__typeof},
            func = function(element, msg)
                (element %_M.DOT).Message = msg;
            end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
local actionTypeObject;
System.Func = _M.NE({["#"] = function(interactionElement, generics, staticValues)
    -- Note: System.Func is throwing away all generics, as it is not possible for lua to distingush between them.
    local typeObject = actionTypeObject or System.Type('Func','System',System.Object.__typeof,0,nil,nil,interactionElement);
    actionTypeObject = typeObject;
    local level = 2;
    local members = {
        
    };
    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
System.Int = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Double.__meta(staticValues);
    local typeObject = System.Type('Int','System',baseTypeObject,0,nil,nil,interactionElement);

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return 0; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})

System.Int32 = _M.NE({["#"] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta({});
    local typeObject = System.Type('Int32','System',baseTypeObject,0,nil,nil,interactionElement);
    local level = 2;
    members[level] = {};

    _M.IM(members,'Parse',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {System.Object.__typeof},
        func = function(_, value)
            return math.floor(tonumber(value));
        end,
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return 0; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
System.Int = System.Int32;

System.Int64 = _M.NE({["#"] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta({});
    local typeObject = System.Type('Int64','System',baseTypeObject,0,nil,nil,interactionElement);
    local level = 2;
    members[level] = {};

    _M.IM(members,'Parse',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {System.Object.__typeof},
        func = function(_, value)
            return math.floor(tonumber(value));
        end,
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return 0; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
System.Long = System.Int64;

local ext = {
};
System.Object = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local typeObject = System.Type('Object','System',nil,0,nil,nil,interactionElement);
    local members = {
        {
            -- Note: GetType is implemented as a shortcut inside DOT, to avoid additional looks through AM.
        },
    };

    _M.IM(members,'Equals',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {typeObject},
        func = function(element, obj)
            return element == obj;
        end,
    });

    _M.IM(members,'ToString',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {},
        func = function(element)
            if type(element) == "table" then
                return ((element %_M.DOT).GetType() %_M).FullName;
            elseif type(element) == "boolean" then
                return element and "True" or "False";
            end

            return tostring(element);
        end,
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };

    local elementGenerator = function() 
        return {
            [1] = {},
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end

    return "Class", typeObject, members, constructors, elementGenerator;
end})
System.String = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('String','System',baseTypeObject,0,nil,nil,interactionElement);

    _M.IM(members,'Split',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        types = {typeObject},
        func = function(element, delimiter)
            local t = {string.split(delimiter, element)};
            t[0] = t[1];
            table.remove(t,1);
            return (System.Array[{typeObject}]()%_M.DOT).__Initialize(t);
        end,
    });

    _M.IM(members,'IsNullOrEmpty',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {typeObject},
        func = function(_, str)
            return str == nil or str == "";
        end,
    });

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return "";
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})
local hashString = function(str, hash)
    hash = hash or 7;
    for i=1, string.len(str) do
        hash = math.mod(hash*31 + string.byte(str,i), 1000000);
    end
    return hash;
end

local typeType;
local objectType;

local GetMatchScore = function(self, otherType, otherValue)
    if otherType.GetHashCode() == self.hash then
        return self.level;
    end
    
    if self.implements then
        local bestScore;
        for _,interfaceType in ipairs(self.implements) do
            local score = interfaceType.GetMatchScore(otherType);
            if score then
                bestScore = bestScore and math.max(bestScore, score) or score;
            end
        end
        
        if bestScore then
            return math.min(bestScore, self.Level-1);
        end
    end
    
    if otherType.catagory == "Enum" and self.Equals(System.String.__typeof) then
        if (System.Enum % _M.DOT).Parse(otherType, otherValue) then
            return 0;
        end
    end

    if self.baseType then
        return self.baseType.GetMatchScore(otherType);
    end
    
    return nil;
end

local meta = {
    __index = function(self, index)
        if index == "__metaType" then
            return _M.MetaTypes.TypeObject;
        elseif index == "GetType" then
            return function()
                return typeType;
            end
        elseif index == "GetHashCode" then
            return function()
                return self.hash;
            end
        elseif index == "ToString" then
            return function()
                local fullName = self.namespace .. "." .. self.name;

                if self.generics then
                    local genericsNames = {};
                    for i,v in pairs(self.generics) do
                        genericsNames[i] = v.ToString();
                    end
                    return fullName.."<"..string.join(",", unpack(genericsNames))..">";
                end
                return fullName;
            end;
        elseif index == "Equals" then
            return function(otherType)
                return self.hash == otherType.GetHashCode();
            end
        elseif index == "IsInstanceOfType" then
            return function(instance)
                local otherType = (instance % _M.DOT).GetType();
                if self.hash == otherType.hash then
                    return true;
                end

                if otherType.baseType and self.IsInstanceOfType({type = otherType.baseType}) then
                    return true;
                end

                for _,imp in ipairs(otherType.implements or {}) do
                    if self.IsInstanceOfType({type = imp}) then
                        return true;
                    end
                end
                return false;
            end
        elseif index == "Name" then
            return self.name;
        elseif index == "Namespace" then
            return self.namespace;
        elseif index == "BaseType" then
            return self.baseType;
        elseif index == "Level" then
            return self.level;
        elseif index == "GetMatchScore" then
            return function(otherType, otherValue) return GetMatchScore(self, otherType, otherValue); end;
        elseif index == "InteractionElement" then
            return self.interactionElement;
        elseif index == "FullName" then
            local generic = "";
            if self.numberOfGenerics > 1 then
                generic = "´" .. self.numberOfGenerics;
            end

            return self.namespace .. "." .. self.name .. generic;
        elseif index == "IsEnum" then
            return self.catagory == "Enum";
        elseif index == "type" then
            return typeType;
        end
    end,
};

local getHash = function(name, namespace, numberOfGenerics, generics)
    local genericsHash = 1;
    if generics then
        for i,v in pairs(generics) do
            genericsHash = genericsHash * v.GetHashCode();
        end
    end

    return hashString(namespace .. "." .. name .. "´".. numberOfGenerics, genericsHash);
end

local typeCache = {};


local typeCall = function(name, namespace, baseType, numberOfGenerics, generics, implements, interactionElement, catagory)
    assert(interactionElement, "Type cannot be created without an interactionElement.");

    catagory = catagory or "Class";
    numberOfGenerics = numberOfGenerics or 0;
    local hash = getHash(name, namespace, numberOfGenerics, generics);
    if typeCache[hash] then 
        error("The type object "..tostring(name).." was already created.");
    end

    local self = {
        catagory = catagory, 
        namespace = namespace,
        name = name, 
        numberOfGenerics = numberOfGenerics,
        hash = hash,
        generics = generics,
        baseType = baseType,
        level = (baseType and baseType.Level or 0) + 1,
        implements = implements,
        interactionElement = interactionElement,
    };
    
    setmetatable(self, meta);
    typeCache[hash] = self;
    return self;
end

GetTypeFromHash = function(hash)
    return typeCache[hash];
end

--objectType = typeCall("Object", "System"); -- TODO: Initialize in a way that does not require the type cache
typeType = typeCall("Type", "System", nil, 0, nil, nil, {});

local meta = {
    __typeof = typeType,
    __is = function(value) return type(value) == "table" and type(value.GetType) == "function" and value.GetType() == typeType; end,
    __meta = function() return typeType; end,
};

local element = {};
setmetatable(element, { 
    __index = function(_, key)
        if meta[key] then 
            return meta[key];
        end
    end,
    __newindex = function(_, key, value)
    end,
    __call = function(_, ...)
        return typeCall(...);
    end,
});

System.Type = element;

CsLuaFramework = { };
CsLuaFramework.Serializer = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('CsLuaFramework','Serializer',baseTypeObject,0,nil,nil,interactionElement);

    local replaceTypeRefs;
    replaceTypeRefs = function(obj)
        local t = {};
        for i,v in ipairs(obj) do
            for index, value in pairs(v) do
                local strPrefix = type(index) == "string" and i.."_" or i.."#_";

                if type(value) == "table" and value.__metaType == _M.MetaTypes.ClassObject then
                    t[strPrefix..index] = replaceTypeRefs(value);
                else
                    t[strPrefix..index] = value;
                end
            end
        end

        t.type = obj.type.hash;

        return t;
    end

    local replaceHashsWithTypes;
    replaceHashsWithTypes = function(obj)
        if type(obj) == "table" then
            local t = {[1] = {}};
            for i,v in pairs(obj) do
                if i == "type" and type(v) == "number" then
                    t[i] = GetTypeFromHash(v);
                    t.__metaType = _M.MetaTypes.ClassObject;
                else
                    local level, isNum, index = string.match(i,"^(%d*)(#?)_(.*)");
                    level = tonumber(level);
                    index = not(isNum == nil) and tonumber(index) or index;
                    t[level] = t[level] or {};
                    t[level][index] = replaceHashsWithTypes(v);
                end
            end
            return t;
        else
            return obj;
        end
    end

    _M.IM(members,'Serialize',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {System.Object.__typeof},
        func = function(_, obj)
            return replaceTypeRefs(obj);
        end,
    });

    _M.IM(members,'Deserialize',{
        level = typeObject.Level,
        memberType = 'Method',
        scope = 'Public',
        static = true,
        types = {System.Object.__typeof},
        func = function(_, obj)
            return replaceHashsWithTypes(obj);
        end,
    });


    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {
            [1] = {},
            [2] = {}, 
            ["type"] = typeObject,
            __metaType = _M.MetaTypes.ClassObject,
        }; 
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end})

table.Foreach = foreach;
table.contains = tcontains;

_G.__isNamespace = true;
Lua = {
    __isNamespace = true;
    Core = _G,
    Strings = _G,
    LuaMath = _G,
    Table = table,

    NativeLuaTable = function() return {__Cstor = function() return {}; end}; end,    
};

Lua.NativeLuaTable = _M.NE({[0] = function(interactionElement, generics, staticValues)
    local baseTypeObject, members = System.Object.__meta(staticValues);
    local typeObject = System.Type('NativeLuaTable','Lua',baseTypeObject,0,nil,nil,interactionElement);

    local constructors = {
        {
            types = {},
            func = function() end,
        }
    };
    local objectGenerator = function() 
        return {};
    end
    return "Class", typeObject, members, constructors, objectGenerator;
end});

Lua.Strings.format = function(str,...)
    -- TODO: replace {0} with %1$s
    str =  gsub(str,"{(%d)}", function(n) return "%"..(tonumber(n)+1).."$s" end);
    return string.format(str,...)
end

strsplittotable = function(d, str)
    return {strsplit(d, str)};
end
strjoinfromtable = function(d, t)
    return strjoin(d, unpack(t));
end
function strsubutf8(str, a, b) -- modified from http://wowprogramming.com/snippets/UTF-8_aware_stringsub_7
    assert(type(str) == "string" and type(a) == "number", "incorrect input strsubutf8");
    assert(not (b) or (type(b) == "number" and b <= strlenutf8(str)), "end pos larger than string lenght", b, strlenutf8(str));

    b = (b or strlenutf8(str));


    local start, _end = #str + 1, #str + 1;
    local currentIndex = 1
    local numChars = 0;
    if a <= 1 then
        start = a;
    end
    if b <= 1 then
        _end = b;
    end

    while currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        if char > 240 then
            currentIndex = currentIndex + 4
        elseif char > 225 then
            currentIndex = currentIndex + 3
        elseif char > 192 then
            currentIndex = currentIndex + 2
        else    
            currentIndex = currentIndex + 1
        end

        numChars = numChars + 1;

        if numChars == a - 1 then
            start = currentIndex;
        end
        if numChars == b then
            _end = currentIndex - 1;
        end
    end
    return str:sub(start, _end)
end

function IsStringNullOrEmpty(str)
    return str == nil or str == "";
end
