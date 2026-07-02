--- inventory.module.lua: client module descriptor for the inventory page. Owns a view
--- (ctx.views.inventory), exposes a narrow service (ctx.services.inventory) over it, and
--- wires the actions / toggle in its controller.
local view <const>       = require 'inventory.view.lua';       ---@type fun(ctx: ClientAppContext): InventoryView
local service <const>    = require 'inventory.service.lua';    ---@type fun(ctx: ClientAppContext): InventoryService
local controller <const> = require 'inventory.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "inventory",
    view = view,
    service = service,
    controller = controller
};
