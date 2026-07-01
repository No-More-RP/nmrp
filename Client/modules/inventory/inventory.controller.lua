--- inventory.controller.lua: (C) the client inventory module. Wires the inventory page: the
--- actions (JS -> Lua), the toggle key, and the initial demo contents.
---
--- ```lua
--- require 'modules/inventory/inventory.controller.lua' (ctx);
--- ```
local InventoryView <const> = require 'inventory.view.lua'; ---@type InventoryUI

---@param ctx ClientAppContext
---@return void
return function(ctx)
    local inventory <const> = InventoryView.get(ctx.ui);
    local ui <const> = ctx.ui;

    -- JS -> Lua actions. Closing the page is handled by the router (route:sync).
    ui:subscribe("inventory:use", function(slot) inventory:use(slot); end);
    ui:subscribe("inventory:drop", function(slot, amount) inventory:drop(slot, amount); end);
    ui:subscribe("inventory:move", function(from, to) inventory:move(from, to); end);

    -- Toggle the panel on I.
    Input.Subscribe("KeyDown", function(key_name)
        if (key_name == "I") then inventory:toggle(); end
    end);

    -- Demo contents until real gameplay drives them. REPLACE.
    inventory:set({
        maxSlots = 20,
        maxWeight = 50,
        items = {
            { slot = 0, id = "glock17",      label = "Glock 17",     category = "weapon", icon = nil, amount = 1,   weight = 1.1,  usable = true },
            { slot = 1, id = "ammo_9mm",     label = "9mm Ammo",     category = "misc",   icon = nil, amount = 102, weight = 0.01, usable = false },
            { slot = 2, id = "water_bottle", label = "Water Bottle", category = "drink",  icon = nil, amount = 3,   weight = 0.5,  usable = true },
            { slot = 3, id = "sandwich",     label = "Sandwich",     category = "food",   icon = nil, amount = 2,   weight = 0.3,  usable = true },
            { slot = 5, id = "lockpick",     label = "Lockpick",     category = "tool",   icon = nil, amount = 5,   weight = 0.05, usable = true },
            { slot = 8, id = "bandage",      label = "Bandage",      category = "tool",   icon = nil, amount = 4,   weight = 0.1,  usable = true },
        },
    });
end
