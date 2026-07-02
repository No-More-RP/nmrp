--- stamina.module.lua: client module descriptor. `depends = { "hud" }`: the controller
--- drives ctx.services.hud with the server's stamina segments, so the HUD view must exist
--- (its service pass must run) before this controller.
local controller <const> = require 'stamina.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "stamina",
    depends = { "hud" },
    controller = controller
};
