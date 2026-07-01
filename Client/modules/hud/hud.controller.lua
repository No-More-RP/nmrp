--- hud.controller.lua: (C) the client HUD module. Consumes the bus and drives the HUD view
--- (its transport to the WebUI). Health binds reactively to the possessed Character;
--- stamina consumes the server's motion segments; neither is polled. It owns no network:
--- it reads the bus (character:possess/unpossess from player, stamina from stamina).
---
--- ```lua
--- require 'modules/hud/hud.controller.lua' (ctx);
--- ```
local HudView <const> = require 'hud.view.lua'; ---@type HudUI

---@param ctx ClientAppContext
---@return void
return function(ctx)
    local hud <const> = HudView.get(ctx.ui);

    -- Reactive health: (un)bind the Character as the local player (un)possesses it.
    ctx.events:on("character:possess", function(character) hud:attach_character(character); end);
    ctx.events:on("character:unpossess", function() hud:detach_character(); end);

    -- Server-authoritative stamina motion segment.
    ctx.events:on("stamina", function(value, rate, delay) hud:set_stamina(value, rate, delay); end);

    -- Demo vitals until real gameplay drives them. REPLACE.
    hud:push({
        armor = 45, maxArmor = 100,
        hunger = 72, thirst = 58,
        money = 1540,
        ammoInClip = 17, ammoReserve = 102, weaponName = "Glock 17",
    });
end
