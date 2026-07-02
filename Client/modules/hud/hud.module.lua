--- hud.module.lua: client module descriptor for the HUD (vitals display). Owns a view
--- (ctx.views.hud), exposes a narrow service (ctx.services.hud) over it, and wires the
--- lifecycle in its controller.
local view <const>       = require 'hud.view.lua';       ---@type fun(ctx: ClientAppContext): HudView
local service <const>    = require 'hud.service.lua';    ---@type fun(ctx: ClientAppContext): HudService
local controller <const> = require 'hud.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "hud",
    view = view,
    service = service,
    controller = controller
};
