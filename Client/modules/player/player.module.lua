--- player.module.lua: client module descriptor for the local-player lifecycle. Controller
--- only: it resolves the local player, bridges possess / unpossess onto the bus, and relays
--- the server "player:ready" remote.
local controller <const> = require 'player.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "player",
    controller = controller
};
