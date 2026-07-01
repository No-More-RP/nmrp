--- Inventory: a PAGE (route "/inventory"). State + transport of the inventory to the
--- WebUI; opening/closing drives the router (the page shows while its route is active).
--- Pushes through the Interface (messages buffer until the page is ready). See the event
--- contract in UI/src/nanos/events.ts:
---   Lua -> JS : inventory:set
---   JS -> Lua : inventory:use, inventory:drop, inventory:move
---
--- ```lua
--- local inventory <const> = require 'ui/pages/inventory.lua'.get(interface);
--- ```
---@class InventoryUI : LightClass
---@field ui Interface
---@field data table
---@overload fun(interface: Interface): InventoryUI
local InventoryUI <const> = class.new("InventoryUI");

local instance; ---@type InventoryUI

--- Get the singleton (created on first call with the Interface).
---
--- ```lua
--- local inventory <const> = InventoryUI.get(interface);
--- ```
---@param interface Interface?
---@return InventoryUI
function InventoryUI.get(interface)
    instance = instance or InventoryUI(interface);
    return instance;
end

---@private
---@param interface Interface The interface manager.
---@return void
function InventoryUI:__init(interface)
    self.ui = interface;
    -- IMPORTANT: `slot` is 0-based (aligned with the JS grid).
    self.data = { items = {}, maxSlots = 20, maxWeight = 50 };
end

--- Replace the whole inventory and push it to the UI.
---
--- ```lua
--- inventory:set({ items = {}, maxSlots = 20, maxWeight = 50 });
--- ```
---@param data table
function InventoryUI:set(data)
    self.data = data;
    self.ui:send("inventory:set", data);
end

--- Re-send the current inventory.
---
--- ```lua
--- inventory:sync();
--- ```
function InventoryUI:sync()
    self.ui:send("inventory:set", self.data);
end

--- Whether the inventory page is the current route.
---
--- ```lua
--- if (inventory:is_open()) then return; end
--- ```
---@return boolean
function InventoryUI:is_open()
    return self.ui.current_route == "/inventory";
end

--- Open/close the inventory page through the router (focus + mouse on open; the page
--- shows while its route is active, and closing returns to the game route).
---
--- ```lua
--- inventory:toggle();
--- ```
---@return void
function InventoryUI:toggle()
    if (self:is_open()) then
        self.ui:reset_route();
    else
        self.ui:set_route("/inventory", { focus = true, mouse = true });
    end
end

--- Swap two slots (local demo authority) then push to the UI.
---
--- ```lua
--- inventory:move(0, 5);
--- ```
---@param from integer
---@param to integer
function InventoryUI:move(from, to)
    local a, b;
    for _, it in ipairs(self.data.items) do
        if (it.slot == from) then a = it; elseif (it.slot == to) then b = it; end
    end
    if (a) then a.slot = to; end
    if (b) then b.slot = from; end
    self:sync();
end

--- Gameplay hook (to override / complete). No-op + log by default.
---
--- ```lua
--- inventory:use(2);
--- ```
---@param slot integer
function InventoryUI:use(slot)
    Console.Log("[ui] use slot " .. tostring(slot));
    -- TODO: apply the item effect, decrement, then self:sync()
end

--- Gameplay hook (to override / complete). No-op + log by default.
---
--- ```lua
--- inventory:drop(2, 1);
--- ```
---@param slot integer
---@param amount integer
function InventoryUI:drop(slot, amount)
    Console.Log(("[ui] drop slot %s x%s"):format(tostring(slot), tostring(amount)));
    -- TODO: remove the item, spawn a pickup, then self:sync()
end

return InventoryUI;
