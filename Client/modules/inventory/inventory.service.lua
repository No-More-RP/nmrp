--- inventory.service.lua: (S) the inventory module's public API (ctx.services.inventory), a
--- narrow facade over its view (ctx.views.inventory). Only the update methods are exposed;
--- the toggle / routing / action internals stay in the controller.

--- Build the inventory service.
---
--- ```lua
--- local inventory <const> = ctx.services.inventory;
--- inventory.set(data);
--- ```
---@param ctx ClientAppContext
---@return InventoryService
return function(ctx)
    local view <const> = ctx.views.inventory; ---@type InventoryView

    ---@class InventoryService
    local service <const> = {};

    --- Replace the whole inventory and push it to the UI.
    ---
    --- ```lua
    --- ctx.services.inventory.set({ items = {}, maxSlots = 20, maxWeight = 50 });
    --- ```
    ---@param data table
    function service.set(data) view.set(data); end

    --- Re-send the current inventory.
    ---
    --- ```lua
    --- ctx.services.inventory.sync();
    --- ```
    function service.sync() view.sync(); end

    return service;
end
