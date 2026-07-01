--- app.lua: client bootstrap. Builds the client context (WebUI + Interface manager, the
--- domain bus, the local player, the locale, the logger), then boots the client module
--- controllers declaratively. Counterpart of Server/app.lua: build a ctx, then boot(...).
--- Each controller wires its own remotes / bus subscriptions / input / view; nothing is
--- wired imperatively here.
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
local boot <const> = require 'core/loader.lua';       ---@type fun(ctx: ClientAppContext, ...: fun(ctx: ClientAppContext): void): void

-- Register client modules here. Adding one = create modules/<name>/<name>.controller.lua
-- and add a line to boot(...) below.
local player_controller <const>    = require 'modules/player/player.controller.lua';       ---@type fun(ctx: ClientAppContext): void
local command_controller <const>   = require 'modules/command/command.controller.lua';     ---@type fun(ctx: ClientAppContext): void
local stamina_controller <const>   = require 'modules/stamina/stamina.controller.lua';     ---@type fun(ctx: ClientAppContext): void
local hud_controller <const>       = require 'modules/hud/hud.controller.lua';             ---@type fun(ctx: ClientAppContext): void
local chat_controller <const>      = require 'modules/chat/chat.controller.lua';           ---@type fun(ctx: ClientAppContext): void
local inventory_controller <const> = require 'modules/inventory/inventory.controller.lua'; ---@type fun(ctx: ClientAppContext): void

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

--- The client application context: the single object handed to every module controller.
---@class ClientAppContext
---@field ui Interface         the WebUI manager (buffered send, focus, router)
---@field events EventEmitter  the client domain bus (player:ready, character:possess, ...)
---@field player Player?       the local player (nil until the player controller resolves it)
---@field locale any           the nmrp locale namespace
---@field logger Logger        the client logger (F8 console)
---@type ClientAppContext
local ctx <const> = {
    ui     = Interface.get(MainUI),
    events = bus,
    player = nil,
    locale = Locale.Namespace("nmrp"),
    logger = Logger({ level = LogLevel.INFO, prefix = "CApplication" }),
};

boot(
    ctx,
    player_controller,
    command_controller,
    stamina_controller,
    hud_controller,
    chat_controller,
    inventory_controller
);

return MainUI;
