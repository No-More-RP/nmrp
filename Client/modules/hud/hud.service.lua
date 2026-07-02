--- hud.service.lua: (S) the HUD module's public API (ctx.services.hud), a narrow facade over
--- its view (ctx.views.hud). Only the setters meant for cross-module use are exposed, never
--- the raw transport (push / sync / attach_character): the view stays internal.

--- Build the HUD service.
---
--- ```lua
--- local hud <const> = ctx.services.hud;
--- hud.set_stamina(80, -25, 0);
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

    --- Set armor (and optionally max armor).
    ---
    --- ```lua
    --- ctx.services.hud.set_armor(45, 100);
    --- ```
    ---@param value number
    ---@param max number?
    function service.set_armor(value, max) view.set_armor(value, max); end

    --- Set the stamina motion segment (value now, signed rate, delay before it applies).
    ---
    --- ```lua
    --- ctx.services.hud.set_stamina(80, -25, 0);
    --- ```
    ---@param value number
    ---@param rate number
    ---@param delay number
    function service.set_stamina(value, rate, delay) view.set_stamina(value, rate, delay); end

    --- Set the money amount.
    ---
    --- ```lua
    --- ctx.services.hud.set_money(1540);
    --- ```
    ---@param value number
    function service.set_money(value) view.set_money(value); end

    --- Set ammo + weapon name.
    ---
    --- ```lua
    --- ctx.services.hud.set_ammo(17, 102, "Glock 17");
    --- ```
    ---@param clip number?
    ---@param reserve number?
    ---@param weapon string?
    function service.set_ammo(clip, reserve, weapon) view.set_ammo(clip, reserve, weapon); end

    return service;
end
