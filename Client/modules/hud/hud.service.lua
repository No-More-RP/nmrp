--- hud.service.lua: (S) the HUD module's public API (ctx.services.hud), a narrow facade over
--- its view (ctx.views.hud). Exposes the health setter and the runtime gauge registry
--- (register / unregister / set / set_segment), never the raw transport (push / sync /
--- attach_character): the view stays internal.

--- Build the HUD service.
---
--- ```lua
--- local hud <const> = ctx.services.hud;
--- hud.register_gauge({ id = "stamina", label = "Stamina", icon = "⚡", color = "#4ea1ff", order = 30 });
--- hud.set_gauge_segment("stamina", 80, -25, 0);
--- ```
---@param ctx ClientAppContext
---@return HudService
return function(ctx)
    local view <const> = ctx.views.hud; ---@type HudView

    ---@class HudService
    local service <const> = {};

    --- Set health (and optionally max health).
    ---
    --- ```lua
    --- ctx.services.hud.set_health(80, 100);
    --- ```
    ---@param value number
    ---@param max number?
    function service.set_health(value, max) view.set_health(value, max); end

    --- Register a HUD gauge (a bar added at runtime). Idempotent by id.
    ---
    --- ```lua
    --- ctx.services.hud.register_gauge({ id = "hunger", label = "Hunger", icon = "🍖", color = "#e0a44b", order = 10 });
    --- ```
    ---@param gauge Gauge
    function service.register_gauge(gauge) view.register_gauge(gauge); end

    --- Remove a HUD gauge by id.
    ---
    --- ```lua
    --- ctx.services.hud.unregister_gauge("hunger");
    --- ```
    ---@param id string
    function service.unregister_gauge(id) view.unregister_gauge(id); end

    --- Set a gauge's static value.
    ---
    --- ```lua
    --- ctx.services.hud.set_gauge("hunger", 72);
    --- ```
    ---@param id string
    ---@param value number
    function service.set_gauge(id, value) view.set_gauge(id, value); end

    --- Set a gauge's value as an interpolated motion segment (value, signed rate, delay).
    ---
    --- ```lua
    --- ctx.services.hud.set_gauge_segment("stamina", 80, -25, 0);
    --- ```
    ---@param id string
    ---@param value number
    ---@param rate number
    ---@param delay number
    function service.set_gauge_segment(id, value, rate, delay) view.set_gauge_segment(id, value, rate, delay); end

    return service;
end
