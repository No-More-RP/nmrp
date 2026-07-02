--- player.controller.lua: (C) wires the player module to the world: spawn flow,
--- Player/Package subscriptions, autosave, and player-facing commands. This replaces
--- the gameplay logic that used to live inline in Server/Index.lua (the boat / AWP /
--- sphere-trigger demo code from there was intentionally dropped).
---
--- ```lua
--- require 'player.controller.lua' (ctx);
--- ```
---@param ctx AppContext
return function(ctx)
    local players <const> = ctx.services.player; ---@type PlayerService
    local spawn_points <const> = Server.GetMapSpawnPoints();
    local fallback_spawn_point <const> = { location = Vector(0, 0, 300), rotation = Rotator(0, 0, 0) };
    local default_mesh <const> = "nanos-world::SK_Mannequin";
    local logger <const> = players.logger;
    local command_logger <const> = logger:child('Command');

    logger:debug("spawn points: %d, fallback: %s", #spawn_points, JSON.stringify(fallback_spawn_point));

    --- Create the pawn, load/cache the player's data (runs module loading hooks),
    --- restore world state, possess. Coroutine-only (load awaits).
    ---
    --- ```lua
    --- spawn(player);
    --- ```
    ---@async
    ---@param player Player
    local function spawn(player)
        local account_id <const> = player:GetAccountID();
        logger:debug("spawning player ^y%s^D", account_id);
        local spawn_point <const> = #spawn_points > 0 and spawn_points[math.random(1, #spawn_points)] or fallback_spawn_point;
        local location , rotation = spawn_point.location, spawn_point.rotation;
        local _, character_data <const> = players.load(player, {
            model = default_mesh,
            location = { X = location.X, Y = location.Y, Z = location.Z },
            rotation = { Pitch = rotation.Pitch, Yaw = rotation.Yaw, Roll = rotation.Roll },
        });

        logger:info("player ^y%s^D loaded: db_id=^y%s^D, character_id=^y%s^D", account_id, player.db_id, character_data.id);

        location, rotation = Vector(character_data.location.X, character_data.location.Y, character_data.location.Z),
            Rotator(character_data.rotation.Pitch, character_data.rotation.Yaw, character_data.rotation.Roll);

        local character <const> = Character(location, rotation, character_data.model, CollisionType.Auto, true, 100);
        character:SetLocation(location);
        character:SetRotation(rotation);
        player:Possess(character);
        logger:success("spawned player ^y%s^D character's", account_id);
    end

    Player.Subscribe("Spawn", threadify(spawn));

    -- Disconnect: the save that matters. Runs releasing hooks, final-saves, drops cache.
    Player.Subscribe("Destroy", threadify(players.release));

    -- Relay the load lifecycle to the owning client: once a player's data is loaded (bus
    -- "player:ready"), signal the client so its views react (mirror of the server bus).
    -- Fire-and-forget: each feature pushes its own initial state, no request/reply.
    ctx.events:on("player:ready", function(player)
        Events.CallRemote("player:ready", player, Reliability.Reliable);
    end);

    -- Sync schema, then spawn anyone already connected (e.g. on package reload).
    Package.Subscribe("Load", threadify(function()
        local connected <const> = Player.GetAll(); ---@type Player[]
        for i = 1, #connected do spawn(connected[i]); end
    end));

    -- Autosave: anti-crash net. Dirty-tracked, so unchanged rows cost nothing.
    Timer.SetInterval(threadify(function()
        local n <const> = players.save_all();
        if (n > 0) then logger:success("autosaved ^B%s^D player(s)", n); end
    end), 300000 --[[ DEV: lower to 10000 while testing ]]);

    -- Dev: respawn everyone. threadify'd because spawn() awaits the DB load.
    local respawn_all <const> = threadify(function()
        local connected <const> = Player.GetAll(); ---@type Player[]
        for i = 1, #connected do
            local player <const> = connected[i];
            local character <const> = player:GetControlledCharacter();
            if (character and character:IsValid()) then
                logger:debug("player ^y%s^D already has a character, destroying it for respawn", player:GetAccountID());
                character:Destroy();
            end
            spawn(player);
        end
        command_logger:success("respawned ^B%s^D player(s)", #connected);
    end);

    command({
        name = "respawn",
        description = "Respawn all players (dev)",
        callback = function() respawn_all(); end,
    });

    -- Dev: print the caller's coordinates (no DB, safe on the main thread).
    command({
        name = "coords",
        description = "Print your character's current coordinates",
        callback = function(ctx)
            local player <const> = ctx.player;
            if (not player) then return; end
            local pawn <const> = player:GetControlledCharacter();
            if (not pawn or not pawn:IsValid()) then --[[ @todo Make notification system ]] return; end
            local loc <const>, rot <const> = pawn:GetLocation(), pawn:GetRotation();
            command_logger:info("Player ^y%s^D character's coordinates: ^BVector(^d%f^D, ^d%f^D, ^d%f^D^B)^D, ^BRotator(^d%f^D, ^d%f^D, ^d%f^B)^D",
                player:GetAccountID(), loc.X, loc.Y, loc.Z, rot.Pitch, rot.Yaw, rot.Roll);
        end,
    });
end
