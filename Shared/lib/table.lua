---@param object table
---@return number
function table.size(object)
    local count = 0;
    for _ in pairs(object) do
        count = count + 1;
    end
    return count;
end

---@param object table
---@param value any
---@return boolean
function table.contains(object, value)
    if (type(object) ~= "table") then
        return false;
    end

    local type <const> = table.type(object);

    if (type == "array") then
        for i = 1, #object do
            if (object[i] == value) then
                return true;
            end
        end
    else
        for _, v in pairs(object) do
            if (v == value) then
                return true;
            end
        end
    end

    return false;
end
