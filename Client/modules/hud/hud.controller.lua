--- hud.controller.lua: (C) the client HUD module. Owns its view's internal wiring: binds
--- health reactively to the possessed Character (bus lifecycle) and pushes the initial
--- vitals. Other modules push their data through the narrow ctx.services.hud facade.
---
--- ```lua
--- require 'modules/hud/hud.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    local view <const> = ctx.views.hud; ---@type HudView

    -- Reactive health: (un)bind the Character as the local player (un)possesses it.
    ctx.events:on("character:possess", function(character) view.attach_character(character); end);
    ctx.events:on("character:unpossess", function() view.detach_character(); end);

    -- Demo vitals until real gameplay drives them. REPLACE.
    view.push({
        armor = 45, maxArmor = 100,
        hunger = 72, thirst = 58,
        money = 1540,
        ammoInClip = 17, ammoReserve = 102, weaponName = "Glock 17",
    });
end
