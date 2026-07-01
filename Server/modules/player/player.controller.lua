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

    --- Create the pawn, load/cache the player's data (runs module loading hooks),
    --- restore world state, possess. Coroutine-only (load awaits).
    ---
    --- ```lua
    --- spawn(player);
    --- ```
    ---@async
    ---@param player Player
    local function spawn(player)
        local spawn_point <const> = #spawn_points > 0 and spawn_points[math.random(1, #spawn_points)] or fallback_spawn_point;
        local location <const>, rotation <const> = spawn_point.location, spawn_point.rotation;
        local character <const> = Character(location, rotation);
        local _, character_data <const> = players.load(player, {
            model = character:GetMesh(),
            location = { X = location.X, Y = location.Y, Z = location.Z },
            rotation = { Pitch = rotation.Pitch, Yaw = rotation.Yaw, Roll = rotation.Roll },
        });

        character:SetMesh(character_data.model);
        character:SetLocation(Vector(character_data.location.X, character_data.location.Y, character_data.location.Z));
        character:SetRotation(Rotator(character_data.rotation.Pitch, character_data.rotation.Yaw, character_data.rotation.Roll));
        player:Possess(character);
    end

    Player.Subscribe("Spawn", threadify(spawn));

    -- Disconnect: the save that matters. Runs releasing hooks, final-saves, drops cache.
    Player.Subscribe("Destroy", threadify(players.release));

    -- Sync schema, then spawn anyone already connected (e.g. on package reload).
    Package.Subscribe("Load", threadify(function()
        local connected <const> = Player.GetAll(); ---@type Player[]
        for i = 1, #connected do spawn(connected[i]); end
    end));

    -- Autosave: anti-crash net. Dirty-tracked, so unchanged rows cost nothing.
    Timer.SetInterval(threadify(function()
        local n <const> = players.save_all();
        if (n > 0) then Console.Log("[nmrp] autosaved %d player(s)", n); end
    end), 300000 --[[ DEV: lower to 10000 while testing ]]);

    -- Dev: respawn everyone. threadify'd because spawn() awaits the DB load.
    local respawn_all <const> = threadify(function()
        local connected <const> = Player.GetAll(); ---@type Player[]
        for i = 1, #connected do spawn(connected[i]); end
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
            if (not pawn) then Chat.SendMessage(player, "No controlled character"); return; end
            local loc <const>, rot <const> = pawn:GetLocation(), pawn:GetRotation();
            Console.Log("Player %s: Vector(%f, %f, %f), Rotator(%f, %f, %f)",
                player:GetAccountID(), loc.X, loc.Y, loc.Z, rot.Pitch, rot.Yaw, rot.Roll);
        end,
    });
end
