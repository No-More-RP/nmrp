--- app.lua — server bootstrap. Builds the DB adapter + Norm instance, assembles the
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
local events <const> = require 'core/emitter.lua'; ---@type EventEmitter

local formatter <const> = "[norm] %s";

local adapter <const> = Norm.adapters.nanos.new({
    engine = DatabaseEngine.MySQL,
    connection = settings.database_connection,
    pool_size = 20,
    on_ready = function(ok, err)
        if (not ok) then
            Console.Error(formatter:format("[adapter] open failed: " .. tostring(err)));
            return;
        end
        Console.Log(formatter:format("[adapter] database opened"));
    end,
});

local db <const> = Norm.new({
    adapter = adapter,
    logger = function(level, message)
        if (level == "ERROR") then
            Console.Error(formatter:format(message));
            return;
        end
        Console.Log(formatter:format(message));
    end,
    log = false,
    queue_until_ready = true,
    promise = Norm.promise.from_class(Promise)
});

--- The application container: the single object passed to every module. Models and
--- services populate themselves into it during boot; events is the cross-module bus.
---@type AppContext
local ctx <const> = {
    db       = db,
    models   = {},
    services = {},
    config   = {},
    events   = events,
    settings = settings,
};

local loader <const> = make_loader(ctx);

-- Register features here. Adding a job/faction later = one line + its module folder.
local player_module <const>  = require 'modules/player/player.module.lua';   ---@type AppModule

CreateThread(loader.boot, player_module);

return ctx;
