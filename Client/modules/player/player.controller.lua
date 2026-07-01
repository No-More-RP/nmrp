--- player.controller.lua: (C) the client player lifecycle. Resolves the local player (a
--- nanos timing mess, see local-player.lua), bridges its character possess/unpossess onto
--- the bus, and relays the server "player:ready" remote. This is the only owner of the
--- local-player plumbing; every other module reacts to the bus.
---
--- ```lua
--- require 'modules/player/player.controller.lua' (ctx);
--- ```
local local_player <const> = require 'local-player.lua'; ---@type fun(): Promise

---@param ctx ClientAppContext
---@return void
return function(ctx)
    local events <const> = ctx.events;

    -- Server -> client: the player's data finished loading (mirror of the server bus).
    Events.SubscribeRemote("player:ready", threadify(function()
        -- Resolve the local player, then bridge its character lifecycle to the bus. Async
        -- because it awaits the player to exist (immediate on reload, else on spawn).
        local player <const> = local_player():await();
        ctx.player = player;

        events:emit("player:ready");

        player:Subscribe("Possess", function(_self, pawn)
            if (pawn:IsA(Character)) then events:emit("character:possess", pawn); end
        end);

        player:Subscribe("UnPossess", function(_self, pawn)
            if (pawn:IsA(Character)) then events:emit("character:unpossess", pawn); end
        end);

        -- Package reload mid-game: a character may already be possessed.
        local pawn <const> = player:GetControlledCharacter();
        if (pawn and pawn:IsA(Character)) then events:emit("character:possess", pawn); end
    end));
end
