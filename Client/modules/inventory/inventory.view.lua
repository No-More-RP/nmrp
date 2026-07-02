--- inventory.view.lua: (V) inventory transport to the WebUI, and a PAGE (route "/inventory").
--- Buffers through the Interface; opening/closing drives the router. INTERNAL to the module
--- (other modules go through the narrow inventory service). Closure-factory style: no class,
--- no singleton, one instance in ctx.views.inventory.
---
--- ```lua
--- local inventory <const> = ctx.views.inventory; ---@type InventoryView
--- inventory.set(data);
--- ```
---@param ctx ClientAppContext
---@return InventoryView
return function(ctx)
    local ui <const> = ctx.ui;

    ---@class InventoryView
    local view <const> = {};

    -- IMPORTANT: `slot` is 0-based (aligned with the JS grid).
    local data = { items = {}, maxSlots = 20, maxWeight = 50 }; ---@type table

    --- Replace the whole inventory and push it to the UI.
    ---
    --- ```lua
    --- inventory.set({ items = {}, maxSlots = 20, maxWeight = 50 });
    --- ```
    ---@param new_data table
    function view.set(new_data)
        data = new_data;
        ui:send("inventory:set", new_data);
    end

    --- Re-send the current inventory.
    ---
    --- ```lua
    --- inventory.sync();
    --- ```
    function view.sync() ui:send("inventory:set", data); end

    --- Whether the inventory page is the current route.
    ---
    --- ```lua
    --- if (inventory.is_open()) then return; end
    --- ```
    ---@return boolean
    function view.is_open() return ui.current_route == "/inventory"; end

    --- Open/close the inventory page through the router (focus + mouse on open; closing
    --- returns to the game route).
    ---
    --- ```lua
    --- inventory.toggle();
    --- ```
    function view.toggle()
        if (view.is_open()) then
            ui:reset_route();
        else
            ui:set_route("/inventory", { focus = true, mouse = true });
        end
    end

    --- Swap two slots (local demo authority) then push to the UI.
    ---
    --- ```lua
    --- inventory.move(0, 5);
    --- ```
    ---@param from integer
    ---@param to integer
    function view.move(from, to)
        local a, b;
        for _, it in ipairs(data.items) do
            if (it.slot == from) then a = it; elseif (it.slot == to) then b = it; end
        end
        if (a) then a.slot = to; end
        if (b) then b.slot = from; end
        view.sync();
    end

    --- Gameplay hook (to override / complete). No-op + log by default.
    ---
    --- ```lua
    --- inventory.use(2);
    --- ```
    ---@param slot integer
    function view.use(slot)
        Console.Log("[ui] use slot " .. tostring(slot));
        -- TODO: apply the item effect, decrement, then view.sync()
    end

    --- Gameplay hook (to override / complete). No-op + log by default.
    ---
    --- ```lua
    --- inventory.drop(2, 1);
    --- ```
    ---@param slot integer
    ---@param amount integer
    function view.drop(slot, amount)
        Console.Log(("[ui] drop slot %s x%s"):format(tostring(slot), tostring(amount)));
        -- TODO: remove the item, spawn a pickup, then view.sync()
    end

    return view;
end
