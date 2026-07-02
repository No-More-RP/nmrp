--- player.module.lua: client module descriptor for the player lifecycle. Controller only:
--- it bridges the local player's possess / unpossess onto the bus and relays the server
--- "player:ready" remote (the local player itself is resolved by app.lua before boot).
local controller <const> = require 'player.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "player",
    controller = controller
};
