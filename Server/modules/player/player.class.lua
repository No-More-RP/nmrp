--- player.class.lua — extends the nanos `Player` class with the player module's core
--- helpers: an online-player registry (Create) and the custom-value metatable hooks
--- (index/newindex) that back `player.<key>` reads/writes (e.g. `player.db_id`).
--- Side-effect require (mutates the global Player); returns Player for convenience.

local cache <const> = {};      ---@type table<number, Player> by db_id
local flat_cache <const> = {}; ---@type Player[]

--- Register this player in the online registry (keyed by db_id). Call once, right
--- after the player's db_id is set.
---
--- ```lua
--- player.db_id = player_data.id;
--- player:Create();
--- ```
---@return Player self
function Player:Create()
    cache[self.db_id] = self;
    flat_cache[#flat_cache + 1] = self;
    return self;
end

--- Metatable write hook: `player.<key> = value` is stored as a networked custom value.
---
--- ```lua
--- player.db_id = 42; -- stored via SetValue, replicated to the client
--- ```
---@param key string
---@param value any
---@return void
function Player:newindex(key, value)
    self:SetValue(key, value, Server ~= nil);
end

--- Metatable read hook: `player.<key>` returns the stored custom value.
---
--- ```lua
--- local id <const> = player.db_id;
--- ```
---@param key string
---@return any
function Player:index(key)
    return self:GetValue(key);
end

return Player;
