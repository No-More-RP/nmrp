local cache <const> = {};
local flat_cache <const> = {};

function Player:Create()
    cache[self.db_id] = self;
    flat_cache[#flat_cache + 1] = self;
    return self;
end

---@param key string
---@param value any
function Player:newindex(key, value)
    self:SetValue(key, value, Server ~= nil);
end

---@param key string
function Player:index(key)
    return self:GetValue(key);
end

return Player;
