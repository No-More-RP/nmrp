--- economy.module.lua: feature descriptor. `depends = { "player" }`: the cash account
--- is created on character load (owner = the character).
--- require paths relative to THIS folder; returns typed by hand.
local model <const>      = require 'economy.model.lua';      ---@type fun(db: NormOrm): EconomyModels
local service <const>    = require 'economy.service.lua';    ---@type fun(ctx: AppContext): EconomyService
local controller <const> = require 'economy.controller.lua'; ---@type fun(ctx: AppContext): void

---@type AppModule
return {
    name       = "economy",
    depends    = { "player" },
    models     = model,
    service    = service,
    controller = controller,
};
