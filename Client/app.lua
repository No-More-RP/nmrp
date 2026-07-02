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
local make_loader <const> = require 'core/loader.lua'; ---@type fun(ctx: ClientAppContext): { boot: fun(...: ClientAppModule): ClientAppContext }

-- Register client modules here. Adding one = create modules/<name>/<name>.module.lua and
-- add a line to boot(...) below.
local player_module <const>    = require 'modules/player/player.module.lua';       ---@type ClientAppModule
local command_module <const>   = require 'modules/command/command.module.lua';     ---@type ClientAppModule
local stamina_module <const>   = require 'modules/stamina/stamina.module.lua';     ---@type ClientAppModule
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
---@field player Player?                the local player (nil until the player module resolves it)
---@field locale any                    the nmrp locale namespace
---@field logger Logger                 the client logger (F8 console)
---@field views table<string, any>      view container: module name -> its view (WebUI facade)
---@field services table<string, any>   DI container: module name -> its service
---@type ClientAppContext
local ctx <const> = {
    ui       = Interface.get(MainUI),
    events   = bus,
    player   = nil,
    locale   = Locale.Namespace("nmrp"),
    logger   = Logger({ level = LogLevel.INFO, prefix = "CApplication" }),
    views    = {},
    services = {},
};

make_loader(ctx).boot(
    player_module,
    command_module,
    stamina_module,
    hud_module,
    chat_module,
    inventory_module
);

return MainUI;
