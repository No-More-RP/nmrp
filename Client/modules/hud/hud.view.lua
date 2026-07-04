--- hud.view.lua: (V) HUD transport to the WebUI. Two parts: the fixed vitals (only health for
--- now) pushed as a partial "hud:update", and a runtime GAUGE REGISTRY, bars added/removed on
--- the fly ("hud:gauges" carries the ordered list, "hud:gauge" a single value). Health is
--- permanent (bound to the Character); everything else is a registered gauge.
--- INTERNAL to the hud module (other modules go through the narrow hud service).
--- Closure-factory style: no class, no singleton, one instance stored in ctx.views.hud.
---
--- ```lua
--- local hud <const> = ctx.views.hud; ---@type HudView
--- hud.set_health(80, 100);
--- hud.register_gauge({ id = "stamina", label = "Stamina", icon = "⚡", color = "#4ea1ff", order = 30 });
--- hud.set_gauge_segment("stamina", 80, -25, 0);
--- ```
---@param ctx ClientAppContext
---@return HudView
return function(ctx)
    local ui <const> = ctx.interface;

    ---@class HudView
    local view <const> = {};

    -- Fixed vitals (mirror of HudData on the TS side): only health for now (permanent, bound
    -- to the Character). Every bar lives in the gauge registry below, not here. Money and ammo
    -- will come back as their own widgets with the economy / weapon modules.
    local state <const> = {
        health = 100, maxHealth = 100,
    };

    ---@alias GaugeValue number | { value: number, rate: number, delay: number }
    ---@class Gauge
    ---@field id string
    ---@field label string
    ---@field icon string
    ---@field color string        CSS color of the fill
    ---@field order integer       sort key (ascending) in the vitals column
    ---@field max number          full value (defaults to 100)
    ---@field value GaugeValue    a number (static) or a motion segment (interpolated)
    ---@field height? "thin"|"normal"

    -- Runtime gauge registry: id -> Gauge. Rendered as bars ordered by `order`.
    local gauges <const> = {}; ---@type table<string, Gauge>

    -- Currently bound Character (for reactive health) + its subscription.
    local character; ---@type Character|nil
    local on_health; ---@type any

    -- Ordered gauge list for the wire (the JS side sorts too, this just keeps it tidy).
    ---@return Gauge[]
    local function gauge_list()
        local list <const> = {}; ---@type Gauge[]
        for _, g in pairs(gauges) do list[#list + 1] = g; end
        table.sort(list, function(a, b) return a.order < b.order; end);
        return list;
    end

    --- Partial push of the fixed vitals: updates local state and sends ONLY what changed.
    ---
    --- ```lua
    --- hud.push({ money = 1540 });
    --- ```
    ---@param partial table
    function view.push(partial)
        for k, v in pairs(partial) do state[k] = v; end
        ui:send("hud:update", partial);
    end

    --- Resend the whole state (fixed vitals + every gauge). Used on the "ui:ready" handshake.
    ---
    --- ```lua
    --- hud.sync();
    --- ```
    function view.sync()
        ui:send("hud:update", state);
        ui:send("hud:gauges", gauge_list());
    end

    --- Set health (and optionally max health).
    ---
    --- ```lua
    --- hud.set_health(80, 100);
    --- ```
    ---@param value number
    ---@param max number?
    function view.set_health(value, max) view.push({ health = value, maxHealth = max or state.maxHealth }); end

    --- Register a gauge (a bar added at runtime). Idempotent by id: registering an existing id
    --- replaces it. `max` defaults to 100 and `value` to `max`. Sends the whole ordered list.
    ---
    --- ```lua
    --- hud.register_gauge({ id = "hunger", label = "Hunger", icon = "🍖", color = "#e0a44b", order = 10 });
    --- ```
    ---@param gauge Gauge
    function view.register_gauge(gauge)
        gauge.max = gauge.max or 100;
        if (gauge.value == nil) then gauge.value = gauge.max; end
        gauges[gauge.id] = gauge;
        ui:send("hud:gauges", gauge_list());
    end

    --- Remove a gauge by id. No-op if it was not registered.
    ---
    --- ```lua
    --- hud.unregister_gauge("hunger");
    --- ```
    ---@param id string
    function view.unregister_gauge(id)
        if (gauges[id] == nil) then return; end
        gauges[id] = nil;
        ui:send("hud:gauges", gauge_list());
    end

    --- Set a gauge's static value.
    ---
    --- ```lua
    --- hud.set_gauge("hunger", 72);
    --- ```
    ---@param id string
    ---@param value number
    function view.set_gauge(id, value)
        local g <const> = gauges[id];
        if (not g) then return; end
        g.value = value;
        ui:send("hud:gauge", { id = id, value = value });
    end

    --- Set a gauge's value as a motion SEGMENT: value now, signed rate (units/s, negative
    --- draining, positive filling, 0 steady), and delay (s) before the rate applies. The UI
    --- interpolates the bar from it, so ~2 packets replace a per-tick stream (see stamina).
    ---
    --- ```lua
    --- hud.set_gauge_segment("stamina", 80, -25, 0);
    --- ```
    ---@param id string
    ---@param value number
    ---@param rate number
    ---@param delay number
    function view.set_gauge_segment(id, value, rate, delay)
        local g <const> = gauges[id];
        if (not g) then return; end
        local seg <const> = { value = value, rate = rate, delay = delay };
        g.value = seg;
        ui:send("hud:gauge", { id = id, value = seg });
    end

    --- Bind a Character: push its initial health and subscribe to HealthChange (reactive,
    --- no polling). Automatically detaches the previous one.
    ---
    --- ```lua
    --- hud.attach_character(ctx.player:GetControlledCharacter());
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
