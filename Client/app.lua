--- app.lua: client bootstrap. Builds the client context (WebUI + Interface manager, the
--- domain bus, the local player, the locale, the logger, the DI service container), then
--- boots the client modules through the loader. Counterpart of Server/app.lua: build a ctx,
--- then boot(...). Each module wires its own service (into ctx.services) and controller.
---
--- Source: nmrp-ui repo (pnpm dev -> http://localhost:5173). Build: dist/, deployed to
--- Client/web by the nmrp-ui CI. The file:/// path resolves relative to Client/, so
--- "file:///web/index.html" -> Client/web/index.html.
---
--- Event contract (must stay in sync with the nmrp-ui events.ts):
---   Lua -> JS : hud:update, inventory:set/toggle, chat:message/clear/commands/focus
---   JS -> Lua : ui:ready, inventory:use/drop/move/close, chat:submit/close

local Interface <const> = require 'ui/interface.lua'; ---@type Interface
local bus <const> = require 'core/bus.lua';           ---@type EventEmitter
local make_loader <const> = require 'core/loader.lua'; ---@type fun(ctx: ClientAppContext): ClientLoader
local SharedSettings <const> = require 'lib/constants/shared.settings.lua'; ---@type SharedSettings
local Logger <const> = require 'lib/classes/logger.lua'; ---@type Logger

-- Register client modules here. Adding one = create modules/<name>/<name>.module.lua and
-- add a line to boot(...) below.
local player_module <const>    = require 'modules/player/player.module.lua';       ---@type ClientAppModule
local command_module <const>   = require 'modules/command/command.module.lua';     ---@type ClientAppModule
local hud_module <const>       = require 'modules/hud/hud.module.lua';             ---@type ClientAppModule
local chat_module <const>      = require 'modules/chat/chat.module.lua';           ---@type ClientAppModule
local inventory_module <const> = require 'modules/inventory/inventory.module.lua'; ---@type ClientAppModule

--- Set to `true` to load the Vite dev server directly IN GAME (component hot-reload
--- without a rebuild). Run `pnpm dev` in the nmrp-ui repo first.
local DEV <const> = false;
local DEV_URL <const> = "http://localhost:5173";
local PROD_PATH <const> = "file:///web/index.html";

--- WebUI hosting the main interfaces (HUD + inventory + chat share this browser).
local MainUI <const> = WebUI(
    "MainInterface",                -- debug name: the player's main interfaces
    DEV and DEV_URL or PROD_PATH,
    WidgetVisibility.Visible,
    true,                           -- transparent (overlay)
    true                            -- auto_resize (follows the resolution)
);

-- Push the locale store to the WebUI and keep it in sync. The page consumes it via locale.js.
Locale.Attach(MainUI);

--- The client application context: the single object handed to every module (service +
--- controller). Modules reach each other through ctx.services.<name>.
---@class ClientAppContext
---@field ui Interface                  the WebUI manager (buffered send, focus, router)
---@field events EventEmitter           the client domain bus (player:ready, character:possess, ...)
---@field player Player                 the local player
---@field locale any                    the nmrp locale namespace
---@field logger Logger                 the client logger (F8 console)
---@field views table<string, any>      view container: module name -> its view (WebUI facade)
---@field services table<string, any>   DI container: module name -> its service
---@field settings table<string, any> the shared settings (debug, mode, etc)
---@type ClientAppContext
local ctx <const> = {
    ui = Interface.get(MainUI),
    events = bus,
    player   = nil,
    locale   = Locale.Namespace("nmrp"),
    logger = logger:child('Application'),
    views    = {},
    services = {},
    settings = {},
};

---@param environment 'development' | 'production'
local function set_logger_env(environment)
    local dev <const> = environment == 'development';
    logger:set_level(dev and Logger.LogLevel.DEBUG or Logger.LogLevel.INFO)
        :set_trace(ctx.settings.debug);
end

Client.Subscribe("ValueChange", function(key, value)
    ctx.settings[key] = value;
    ctx.logger:info("setting changed: %s = %s", tostring(key), tostring(value));
    if (key ~= SharedSettings.MODE) then return; end
    ctx.logger:info("environment mode changed to '%s'", tostring(value));
    DEV_MODE = value == 'development';
    set_logger_env(value);
end);

local function load_settings()
    for _, name in pairs(SharedSettings) do
        ctx.settings[name] = Client.GetValue(name);
    end
    DEV_MODE = ctx.settings.mode == 'development';
    set_logger_env(ctx.settings.mode);
end

local loader <const> = make_loader(ctx);
local boot_promise <const> = Promise(function(resolve, reject)
    local player <const> = Client.GetLocalPlayer();
    if (not player or not player:IsValid()) then
        return;
    end
    ctx.player = player;
    load_settings();
    resolve(ctx);
end);

---@param player Player?
local function on_player_spawned(player)
    if (boot_promise:IsSettled()) then
        return;
    end
    player = player or Client.GetLocalPlayer();
    if (not player) then
        ctx.logger:error("no local player found");
        return;
    end
    ctx.player = player;
    load_settings();
    boot_promise:Resolve(ctx);
end

Client.Subscribe("SpawnLocalPlayer", on_player_spawned);

-- Expose the client app to addon packages through the exported NMRP global (mirror of the
-- server side). The client boots synchronously, so `ready` is already resolved here.
NMRP.ctx = ctx;

--- Resolves to `ctx`. The client has no awaited boot, so this is ready immediately; it
--- exists for API symmetry with the server, where addons must await the schema sync.
NMRP.ready = async(function()
    on_player_spawned();
    boot_promise:await();
    return loader.boot(
        player_module,
        command_module,
        hud_module,
        chat_module,
        inventory_module
    );
end);

--- Register one or more addon client modules from another package. Wires the new modules
--- (views -> services -> controllers) and returns a Promise resolving to `ctx`.
---
--- ```lua
--- -- in an addon's Client/Index.lua (Package.json depends on nmrp):
--- NMRP.register(require 'modules/needs/needs.module.lua');
--- ```
---@vararg ClientAppModule
---@return Promise
function NMRP.register(...)
    return async(function(...)
        NMRP.ready:await();
        return loader.register(...);
    end, ...);
end

Package.Export("NMRP", NMRP);

return MainUI;
