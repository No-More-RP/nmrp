--- player.class.lua: extends the nanos `Player` class with the player module's core
--- helpers: the custom-value metatable hooks
--- (index/newindex) that back `player.<key>` reads/writes (e.g. `player.db_id`).
--- Side-effect require (mutates the global Player); returns Player for convenience.

--- Metatable write hook: `player.<key> = value` is stored as a custom value.
---
--- ```lua
--- player.db_id = 42; -- stored via SetValue
--- ```
---@param key string
---@param value any
---@return void
function Player:newindex(key, value)
    self:SetValue(key, value, false);
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
