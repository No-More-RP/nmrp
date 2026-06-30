--- player.store.lua — (repository/cache) in-memory store for the player module.
---
--- Caches each online player's `players` AND `characters` rows so gameplay code and
--- the autosave loop never re-query the DB just to fetch a record. `record:save()` is
--- dirty-tracked: it writes only changed columns, and runs NO query when nothing
--- changed — so saving "everyone" every few minutes is cheap.
---
--- Factory: pass the player module's two Norm models.
---
--- ```lua
--- local make_store <const> = require 'player.store.lua'; ---@type fun(models: PlayerModels): PlayerStore
--- local store <const> = make_store({ players = player_model, characters = character_model });
--- ```
---@param models PlayerModels
---@return PlayerStore
return function(models)
    local Players <const> = models.players;
    local Characters <const> = models.characters;

    ---@class PlayerStore
    local store <const> = {};
    local online <const> = {}; ---@type table<Player, { player: NormRecord, character: NormRecord }>

    --- The cached pair { player, character } for a player (or nil).
    ---
    --- ```lua
    --- local pair <const> = store.get(player);
    --- ```
    ---@param player Player
    ---@return { player: NormRecord, character: NormRecord }|nil
    function store.get(player) return online[player]; end

    --- The cached character record (or nil).
    ---
    --- ```lua
    --- local character <const> = store.character(player);
    --- ```
    ---@param player Player
    function store.character(player)
        local e <const> = online[player];
        return e and e.character;
    end

    --- The cached player record (or nil).
    ---
    --- ```lua
    --- local record <const> = store.player(player);
    --- ```
    ---@param player Player
    function store.player(player)
        local e <const> = online[player];
        return e and e.player;
    end

    --- Cache an already-loaded pair under a player.
    ---
    --- ```lua
    --- store.bind(player, player_data, character_data);
    --- ```
    ---@param player Player
    ---@param player_data NormRecord
    ---@param character_data NormRecord
    function store.bind(player, player_data, character_data)
        online[player] = { player = player_data, character = character_data };
        return online[player];
    end

    --- Load (or create) the player + character rows for an account and cache them.
    --- Run inside a coroutine (threadify). `defaults` seeds the character on first
    --- creation (model, location, ...). Returns player_data, character_data.
    ---
    --- ```lua
    --- local player_data <const>, character_data <const> =
    ---     store.load(player, player:GetAccountID(), { model = "SK_Mannequin" });
    --- ```
    ---@async
    ---@param player Player
    ---@param account_id string
    ---@param defaults table<string, any>?
    ---@return NormRecord player_data, NormRecord character_data
    function store.load(player, account_id, defaults)
        local player_data <const> = Players:find_or_create({ accountId = account_id }):await();
        local character_data <const> = Characters:find_or_create(
            { player_id = player_data.id },
            defaults or {}
        ):await();
        store.bind(player, player_data, character_data);
        return player_data, character_data;
    end

    --- Copy live world state (location + rotation + mesh) into the cached character
    --- record. A missing/invalid pawn is skipped (keeps the last known values).
    ---
    --- ```lua
    --- store.capture(player); -- pull location/rotation/mesh from the pawn into the cached row
    --- ```
    ---@param player Player
    function store.capture(player)
        local entry <const> = online[player];
        if (entry == nil) then return; end
        local pawn <const> = player:GetControlledCharacter();
        if (not pawn or not pawn:IsValid()) then return; end
        local loc <const> = pawn:GetLocation();
        local rot <const> = pawn:GetRotation();
        entry.character.location = { X = loc.X, Y = loc.Y, Z = loc.Z };
        entry.character.rotation = { Pitch = rot.Pitch, Yaw = rot.Yaw, Roll = rot.Roll };
        entry.character.model = pawn:GetMesh();
    end

    --- Save BOTH rows (player + character) for one player. Captures world state,
    --- fires both writes, then awaits both. nanos has no transactions, so these are
    --- two independent UPDATEs — each dirty-tracked (a no-op when nothing changed).
    --- Run inside a coroutine.
    ---
    --- ```lua
    --- store.save(player);
    --- ```
    ---@async
    ---@param player Player
    function store.save(player)
        local entry <const> = online[player];
        if (entry == nil) then return; end
        store.capture(player);
        local p1 <const> = entry.player:save();    -- usually a no-op
        local p2 <const> = entry.character:save(); -- coords/model written
        p1:await();
        p2:await();
    end

    --- Save every online player+character efficiently: put ALL writes in flight first,
    --- then await them, so the DB round-trips overlap instead of running one after
    --- another. Run inside a coroutine. Returns the number of players saved.
    ---
    --- ```lua
    --- local n <const> = store.save_all(); -- e.g. 12
    --- ```
    ---@async
    ---@return integer count
    function store.save_all()
        local promises <const> = {}; ---@type NormPromise[]
        local count = 0;
        for player, entry in pairs(online) do
            store.capture(player);
            promises[#promises + 1] = entry.player:save();
            promises[#promises + 1] = entry.character:save();
            count = count + 1;
        end
        Promise.all(promises):await();
        return count;
    end

    --- Final save + drop from the cache. Call on disconnect. Run in a coroutine.
    ---
    --- ```lua
    --- store.release(player);
    --- ```
    ---@async
    ---@param player Player
    function store.release(player)
        local entry <const> = online[player];
        if (entry == nil) then return; end
        online[player] = nil;
        store.capture(player);
        entry.player:save():await();
        entry.character:save():await();
    end

    return store;
end
