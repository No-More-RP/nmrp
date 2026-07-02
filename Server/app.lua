--- app.lua: server bootstrap. Builds the DB adapter + Norm instance, assembles the
--- app context (the DI container), registers every feature module, then boots them
--- in dependency order: models (M) -> services (S) -> controllers (C).
---
--- To switch the package onto this architecture, make Server/Index.lua contain only:
---     require 'app.lua';
--- (the old inline spawn/db/trigger code now lives in modules/player + this file).
---
--- nanos resolves require relative to THIS file's folder (Server/), so the 'core/...'
--- and 'modules/...' paths below are correct. require()'s return type can't be
--- inferred through the mandatory ".lua", so each one is typed by hand.

local settings <const> = Server.GetCustomSettings(); ---@type table<string, ServerSetting>
local make_loader <const>  = require 'core/loader.lua'; ---@type fun(ctx: AppContext): Loader
local events <const> = require 'core/bus.lua'; ---@type EventEmitter
local Logger <const> = require 'lib/globals/logger.lua'; ---@type Logger

local db_logger <const> = Logger({
    level = LogLevel.INFO,
    prefix = "Norm"
});

local adapter <const> = Norm.adapters.nanos.new({
    engine = DatabaseEngine.MySQL,
    connection = settings.database_connection,
    pool_size = 20,
    on_ready = function(ok, err)
        if (not ok) then
            db_logger:error("[adapter] open failed: " .. tostring(err));
            return;
        end
        db_logger:success("[adapter] database opened");
    end,
});

local db <const> = Norm.new({
    adapter = adapter,
    logger = function(level, message)
        db_logger:log(LogLevel[level] or LogLevel.INFO, message);
    end,
    log = false,
    queue_until_ready = true,
    promise = Norm.promise.from_class(Promise)
});

--- The application container: the single object passed to every module. Models and
--- services populate themselves into it during boot; events is the cross-module bus.
---@class AppContext
---@field db NormOrm
---@field models table<string, any>
---@field services table<string, any>
---@field config table
---@field events EventEmitter
---@field settings table<string, ServerSetting>
---@field logger Logger
local ctx <const> = {
    db       = db,
    models   = {},
    services = {},
    config   = {},
    events   = events,
    settings = settings,
    logger  = Logger({
        level = LogLevel.INFO,
        prefix = "Application"
    })
};

local loader <const> = make_loader(ctx);

-- Register features here. Adding a job/faction later = one line + its module folder.
local player_module <const>  = require 'modules/player/player.module.lua';   ---@type AppModule
local economy_module <const> = require 'modules/economy/economy.module.lua'; ---@type AppModule

-- Expose the app to addon packages through the exported NMRP global (Package.Export in
-- Shared/Index.lua). An addon that depends on nmrp sees these injected as globals.
NMRP.ctx = ctx;

--- Resolves to `ctx` once every core module is booted (models -> services -> controllers)
--- and the schema is synced. Starting the boot here is what starts the whole app.
NMRP.ready = async(function() return loader.boot(player_module, economy_module); end);

--- Register one or more addon modules from another package. Waits for the core to be ready,
--- then wires the new modules and syncs their tables. Returns a Promise resolving to `ctx`,
--- so an addon never has to worry about whether the core has finished booting.
---
--- ```lua
--- -- in an addon's Server/Index.lua (Package.json depends on nmrp):
--- NMRP.register(require 'modules/needs/needs.module.lua');
--- ```
---@vararg AppModule
---@return Promise
function NMRP.register(...)
    local mods <const> = { ... }; ---@type AppModule[]
    return async(function()
        NMRP.ready:await();
        return loader.register(table.unpack(mods));
    end);
end

Package.Export("NMRP", NMRP);

return ctx;
