--- player.controller.lua: (C) the client player lifecycle. The local player is already
--- resolved by app.lua (the client boot is gated on it, so ctx.player is guaranteed here);
--- this bridges its character possess / unpossess onto the bus and relays the server
--- "player:ready" remote. Every other module reacts to the bus.
---
--- ```lua
--- require 'modules/player/player.controller.lua' (ctx);
--- ```

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

    ctx.player:Subscribe("Possess", function(_self, pawn)
        on_pawn_update(pawn, "character:possess");
    end);

    ctx.player:Subscribe("UnPossess", function(_self, pawn)
        on_pawn_update(pawn, "character:unpossess");
    end);

    -- Package reload mid-game: a character may already be possessed.
    on_pawn_update(ctx.player:GetControlledCharacter(), "character:possess");

    -- Server -> client: the player's data finished loading (mirror of the server bus).
    Events.SubscribeRemote("player:ready", function()
        events:emit("player:ready");
    end);
end
