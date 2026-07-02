--- command.module.lua: client module descriptor for the command registry. Controller only:
--- it turns the server's command.* remotes into a "command:changed" bus signal.
local controller <const> = require 'command.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return { name = "command", controller = controller };
