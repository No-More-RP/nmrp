--- player.model.lua: (M) defines the `players` and `characters` tables.
--- Returned table is injected as ctx.models.player for the service to consume.
---
--- ```lua
--- local models <const> = require 'player.model.lua' (db); -- { players = ..., characters = ... }
--- ```
---@alias PlayerModels { players: NormModel, characters: NormModel }
---@param db NormOrm
---@return PlayerModels
return function(db)
    local players <const> = db:define("players", {
        id        = Norm.types.id(),
        accountId = Norm.types.string({ length = 64, nullable = false, unique = true }),
        character = Norm.types.hasOne("characters", { key = "player_id" }),
    });

    local characters <const> = db:define("characters", {
        id          = Norm.types.id(),
        player_id   = Norm.types.integer({ nullable = false }),
        location    = Norm.types.json({ default = JSON.stringify({ X = 0, Y = 0, Z = 0 }) }),
        rotation    = Norm.types.json({ default = JSON.stringify({ Pitch = 0, Yaw = 0, Roll = 0 }) }),
        model       = Norm.types.string({ length = 64, nullable = false }),
        player      = Norm.types.belongsTo("players", { key = "player_id", onDelete = "CASCADE" }),
    });

    return { players = players, characters = characters };
end
