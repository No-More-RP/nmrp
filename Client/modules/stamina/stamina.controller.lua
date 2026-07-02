--- stamina.controller.lua: (C) the client stamina module. Owns the "stamina:update" remote
--- and pushes the motion segment into the HUD through the ctx.services.hud facade (which
--- interpolates the bar). `depends = { "hud" }`, so the facade exists at boot.
---
--- ```lua
--- require 'modules/stamina/stamina.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    local hud <const> = ctx.services.hud; ---@type HudService
    Events.SubscribeRemote("stamina:update", function(value, rate, delay)
        hud.set_stamina(value, rate, delay);
    end);
end
