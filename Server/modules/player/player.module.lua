--- player.module.lua: feature descriptor (the @Module-free registration unit).
--- require paths are relative to THIS folder (nanos resolves require per caller dir).
--- The return values of require() can't be inferred through the mandatory ".lua",
--- so each one is typed by hand below.
require 'player.class.lua'; -- side-effect: installs the index / newindex extensions
local models <const>     = require 'player.model.lua';      ---@type fun(db: Norm): PlayerModels
local service <const>    = require 'player.service.lua';    ---@type fun(ctx: AppContext): PlayerService
local controller <const> = require 'player.controller.lua'; ---@type fun(ctx: AppContext): void

---@type AppModule
return {
    name = "player",
    models = models,
    service = service,
    controller = controller,
};
