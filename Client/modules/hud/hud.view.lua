--- hud.view.lua: state + transport of vitals to the WebUI. Pushes through the Interface
--- (so messages buffer until the page is ready). Driven by hud.controller. See the event
--- contract in the nmrp-ui events.ts.
---
--- ```lua
--- local HudUI <const> = require 'hud.view.lua'; ---@type HudUI
--- local hud <const> = HudUI.get(interface);
--- ```
---@class HudUI : LightClass
---@field logger Logger
---@field interface Interface
---@field state table
---@field private _character Character|nil
---@field private _on_health any
---@overload fun(interface: Interface): HudUI
local HudUI <const> = class.new("HudUI");

local instance; ---@type HudUI

--- Get the singleton (created on first call with the Interface).
---
--- ```lua
--- local hud <const> = HudUI.get(interface);
--- ```
---@param interface Interface?
---@return HudUI
function HudUI.get(interface)
    instance = instance or HudUI(interface);
    return instance;
end

---@private
---@param interface Interface The interface manager.
---@return void
function HudUI:__init(interface)
    self.interface = interface;
    self.logger = self.interface.logger:child("HUD");
    -- Full HUD state (mirror of HudData on the TS side).
    self.state = {
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
    self._character = nil;
    self._on_health = nil;
end

--- Partial push: updates local state and sends ONLY what changed.
---
--- ```lua
--- hud_ui:push({ money = 1540, armor = 45 });
--- ```
---@param partial table
function HudUI:push(partial)
    for k, v in pairs(partial) do self.state[k] = v; end
    self.interface:send("hud:update", partial);
end

--- Send the whole state (used on the "ui:ready" handshake).
---
--- ```lua
--- hud_ui:sync();
--- ```
function HudUI:sync()
    self.interface:send("hud:update", self.state);
end

--- Set health (and optionally max health).
---
--- ```lua
--- hud_ui:set_health(80, 100);
--- ```
---@param value number
---@param max number?
function HudUI:set_health(value, max)
    self:push({ health = value, maxHealth = max or self.state.maxHealth });
end

--- Set the stamina motion segment: the value now, the signed rate (units/s, negative
--- while draining, positive while regenerating, 0 when steady), and the delay (s) before
--- the rate applies (regen cooldown). The WebUI interpolates the bar from it.
---
--- ```lua
--- hud_ui:set_stamina(80, -25, 0);  -- draining from 80 at 25/s
--- ```
---@param value number
---@param rate number
---@param delay number
function HudUI:set_stamina(value, rate, delay)
    self:push({ stamina = { value = value, rate = rate, delay = delay } });
end

--- Set armor (and optionally max armor).
---
--- ```lua
--- hud_ui:set_armor(45, 100);
--- ```
---@param value number
---@param max number?
function HudUI:set_armor(value, max)
    self:push({ armor = value, maxArmor = max or self.state.maxArmor });
end

--- Set the money amount.
---
--- ```lua
--- hud_ui:set_money(1540);
--- ```
---@param value number
function HudUI:set_money(value)
    self:push({ money = value });
end

--- Set ammo + weapon name.
---
--- ```lua
--- hud_ui:set_ammo(17, 102, "Glock 17");
--- ```
---@param clip number?
---@param reserve number?
---@param weapon string?
function HudUI:set_ammo(clip, reserve, weapon)
    self:push({ ammoInClip = clip, ammoReserve = reserve, weaponName = weapon });
end

--- Bind a Character: push its initial health and subscribe to HealthChange (reactive,
--- no polling). Automatically detaches the previous one.
---
--- ```lua
--- hud_ui:attach_character(local_player:GetControlledCharacter());
--- ```
---@param character Character
function HudUI:attach_character(character)
    self:detach_character();
    self._character = character;

    self:set_health(character:GetHealth(), character:GetMaxHealth());

    self._on_health = character:Subscribe("HealthChange", function(char, _old, new)
        self:set_health(new, char:GetMaxHealth());
    end);
end

--- Detach the current Character and its subscription.
---
--- ```lua
--- hud_ui:detach_character();
--- ```
function HudUI:detach_character()
    if (self._character and self._on_health) then
        self._character:Unsubscribe("HealthChange", self._on_health);
    end
    self._character = nil;
    self._on_health = nil;
end

return HudUI;
