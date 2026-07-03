--- hud.controller.lua: (C) the client HUD module. Owns its view's internal wiring: binds
--- health reactively to the possessed Character (bus lifecycle). Health is permanent; every
--- other bar is a runtime gauge that its own feature registers through ctx.services.hud
--- (e.g. the stamina addon). Other modules push their data through the narrow facade.
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

    -- Nothing else registered here on purpose: every bar (stamina, hunger, thirst, ...) is
    -- owned by its feature (an addon) and registered through ctx.services.hud. Money and ammo
    -- widgets will come back with the economy / weapon modules.
end
