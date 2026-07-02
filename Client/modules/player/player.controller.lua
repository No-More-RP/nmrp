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

    ---@param pawn Actor
    ---@param eventName 'character:possess'|'character:unpossess'
    local function on_pawn_update(pawn, eventName)
        if (not pawn or not pawn:IsA(Character) or not pawn:IsValid()) then
            return;
        end
        events:emit(eventName, pawn);
    end

    -- Resolve the local player, then bridge its character lifecycle to the bus. Async
    -- because it awaits the player to exist (immediate on reload, else on spawn).
    local_player():Then(function(player)
        ctx.player = player;

        player:Subscribe("Possess", function(_self, pawn)
            on_pawn_update(pawn, "character:possess");
        end);

        player:Subscribe("UnPossess", function(_self, pawn)
            on_pawn_update(pawn, "character:unpossess");
        end);

        -- Package reload mid-game: a character may already be possessed.
        on_pawn_update(player:GetControlledCharacter(), "character:possess");
    end);

    -- Server -> client: the player's data finished loading (mirror of the server bus).
    Events.SubscribeRemote("player:ready", function()
        events:emit("player:ready");
    end);
end
