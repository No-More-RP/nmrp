--- hud.view.lua: (V) HUD vitals transport to the WebUI. Buffers through the Interface (so
--- messages queue until the page is ready). INTERNAL to the hud module (other modules go
--- through the narrow hud service). Closure-factory style, like a server model: no class,
--- no singleton, one instance stored in ctx.views.hud.
---
--- ```lua
--- local hud <const> = ctx.views.hud; ---@type HudView
--- hud.set_health(80, 100);
--- ```
---@param ctx ClientAppContext
---@return HudView
return function(ctx)
    local ui <const> = ctx.ui;

    ---@class HudView
    local view <const> = {};

    -- Full HUD state (mirror of HudData on the TS side).
    local state <const> = {
        health = 100, maxHealth = 100,
        armor = 0, maxArmor = 100,
        hunger = 100, thirst = 100,
        -- Stamina is a motion segment (see set_stamina): value now, signed rate (units/s),
        -- and delay (s) before the rate applies. The WebUI interpolates the bar from it.
        stamina = { value = 100, rate = 0, delay = 0 },
        money = 0,
        ammoInClip = nil, ammoReserve = nil, weaponName = nil,
    };
    -- Currently bound Character (for reactive health) + its subscription.
    local character; ---@type Character|nil
    local on_health; ---@type any

    --- Partial push: updates local state and sends ONLY what changed.
    ---
    --- ```lua
    --- hud.push({ money = 1540, armor = 45 });
    --- ```
    ---@param partial table
    function view.push(partial)
        for k, v in pairs(partial) do state[k] = v; end
        ui:send("hud:update", partial);
    end

    --- Send the whole state (used on the "ui:ready" handshake).
    ---
    --- ```lua
    --- hud.sync();
    --- ```
    function view.sync() ui:send("hud:update", state); end

    --- Set health (and optionally max health).
    ---
    --- ```lua
    --- hud.set_health(80, 100);
    --- ```
    ---@param value number
    ---@param max number?
    function view.set_health(value, max) view.push({ health = value, maxHealth = max or state.maxHealth }); end

    --- Set the stamina motion segment: the value now, the signed rate (units/s, negative
    --- draining, positive regenerating, 0 steady), and the delay (s) before the rate applies.
    ---
    --- ```lua
    --- hud.set_stamina(80, -25, 0);
    --- ```
    ---@param value number
    ---@param rate number
    ---@param delay number
    function view.set_stamina(value, rate, delay) view.push({ stamina = { value = value, rate = rate, delay = delay } }); end

    --- Set armor (and optionally max armor).
    ---
    --- ```lua
    --- hud.set_armor(45, 100);
    --- ```
    ---@param value number
    ---@param max number?
    function view.set_armor(value, max) view.push({ armor = value, maxArmor = max or state.maxArmor }); end

    --- Set the money amount.
    ---
    --- ```lua
    --- hud.set_money(1540);
    --- ```
    ---@param value number
    function view.set_money(value) view.push({ money = value }); end

    --- Set ammo + weapon name.
    ---
    --- ```lua
    --- hud.set_ammo(17, 102, "Glock 17");
    --- ```
    ---@param clip number?
    ---@param reserve number?
    ---@param weapon string?
    function view.set_ammo(clip, reserve, weapon) view.push({ ammoInClip = clip, ammoReserve = reserve, weaponName = weapon }); end

    --- Bind a Character: push its initial health and subscribe to HealthChange (reactive,
    --- no polling). Automatically detaches the previous one.
    ---
    --- ```lua
    --- hud.attach_character(local_player:GetControlledCharacter());
    --- ```
    ---@param char Character
    function view.attach_character(char)
        view.detach_character();
        character = char;
        view.set_health(char:GetHealth(), char:GetMaxHealth());
        on_health = char:Subscribe("HealthChange", function(c, _old, new) view.set_health(new, c:GetMaxHealth()); end);
    end

    --- Detach the current Character and its subscription.
    ---
    --- ```lua
    --- hud.detach_character();
    --- ```
    function view.detach_character()
        if (character and on_health) then character:Unsubscribe("HealthChange", on_health); end
        character = nil;
        on_health = nil;
    end

    return view;
end
