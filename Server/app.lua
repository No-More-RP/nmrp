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

local custom_settings <const> = Server.GetCustomSettings(); ---@type table<string, any>
local make_loader <const>  = require 'core/loader.lua'; ---@type fun(ctx: AppContext): Loader
local events <const> = require 'core/bus.lua'; ---@type EventEmitter
local Logger <const> = require 'lib/classes/logger.lua'; ---@type Logger
local SharedSettings <const> = require 'lib/constants/shared.settings.lua'; ---@type SharedSettings

local db_logger <const> = Logger({
    level = Logger.LogLevel.INFO,
    prefix = "Norm"
});

local adapter <const> = Norm.adapters.nanos.new({
    engine = DatabaseEngine.MySQL,
    connection = custom_settings.database_connection,
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
        db_logger:log(Logger.LogLevel[level] or Logger.LogLevel.INFO, message);
    end,
    log = false,
    queue_until_ready = true,
    promise = Norm.promise.from_class(Promise)
});

local settings <const> = {
    [SharedSettings.DEBUG] = custom_settings.debug or false,
    [SharedSettings.MODE] = custom_settings.mode or 'production'
}; ---@type table<string, any> key -> setting

for key, value in pairs(settings) do
    Server.SetValue(key, value, true);
end

DEV_MODE = settings.mode == 'development';

--- The application container: the single object passed to every module. Models and
--- services populate themselves into it during boot; events is the cross-module bus.
---@class AppContext
---@field db NormOrm
---@field models table<string, any>
---@field services table<string, any>
---@field config table
---@field events EventEmitter
---@field settings table<string, any>
---@field logger Logger
local ctx <const> = {
    db = db,
    models   = {},
    services = {},
    config   = {},
    events = events,
    settings = settings,
    logger = logger:child('Application')
};

---@param environment 'development' | 'production'
local function set_logger_env(environment)
    local dev <const> = environment == 'development';
    logger:set_level(dev and Logger.LogLevel.DEBUG or Logger.LogLevel.INFO)
        :set_trace(ctx.settings.debug);
end

set_logger_env(settings.mode);

Server.Subscribe("ValueChange", function(key, value)
    settings[key] = value;
    ctx.logger:info("setting changed: %s = %s", tostring(key), tostring(value));
    if (key ~= SharedSettings.MODE) then return; end
    ctx.logger:info("environment mode changed to '%s'", tostring(value));
    DEV_MODE = value == 'development';
    set_logger_env(value);
end);

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
    return async(function(...)
        NMRP.ready:await();
        return loader.register(...);
    end, ...);
end

Package.Export("NMRP", NMRP);

return ctx;
