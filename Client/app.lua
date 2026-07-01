--- app.lua: client bootstrap. Creates the WebUI, wraps it in the Interface manager
--- (buffers messages until the page is ready + centralizes focus), instantiates the
--- views, and wires network / input. Counterpart of Server/app.lua: the entry
--- Client/Index.lua only does `require 'app.lua'`.
---
--- Source: UI/ (npm run dev -> http://localhost:5173). Build: Client/web/ (npm run
--- build). Only Client/ and Shared/ are sent to players, so the build must land in
--- Client/ (see UI/vite.config.ts); the file:/// path resolves relative to the script
--- folder (Client/), so "file:///web/index.html" -> Client/web/index.html.
---
--- Event contract (must stay in sync with UI/src/nanos/events.ts):
---   Lua -> JS : hud:update, inventory:set/toggle, chat:message/clear/commands/focus
---   JS -> Lua : ui:ready, inventory:use/drop/move/close, chat:submit/close

local Interface <const> = require 'ui/interface.lua';        ---@type Interface
local HudUI <const> = require 'ui/components/hud.lua';        ---@type HudUI
local InventoryUI <const> = require 'ui/pages/inventory.lua'; ---@type InventoryUI
local ChatUI <const> = require 'ui/components/chat.lua';      ---@type ChatUI
local player <const> = Client.GetLocalPlayer();        ---@type Player

--- Set to `true` to load the Vite dev server directly IN GAME (component hot-reload
--- without a rebuild). Run `npm run dev` in UI/ first.
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

-- Push the locale store (translations + active language) to the WebUI and keep it
-- in sync (re-syncs on Register / language change). The page consumes it via locale.js.
Locale.Attach(MainUI);

local L <const> = Locale.Namespace("nmrp"); -- nmrp translations (Shared/locales)

-- The interface manager (buffers sends until ready, owns focus). Views push through it.
local ui <const> = Interface.get(MainUI);
local hud <const> = HudUI.get(ui);
local inventory <const> = InventoryUI.get(ui);
local chat <const> = ChatUI.get(ui);

-- Demo state. REPLACE with your real gameplay (health already wires to the Character below).
local demo_hud <const> = {
    armor = 45, maxArmor = 100,
    hunger = 72, thirst = 58,
    money = 1540,
    ammoInClip = 17, ammoReserve = 102, weaponName = "Glock 17",
};

local demo_inventory <const> = {
    maxSlots = 20,
    maxWeight = 50,
    items = {
        { slot = 0, id = "glock17",      label = "Glock 17",     category = "weapon", icon = nil, amount = 1,   weight = 1.1,  usable = true },
        { slot = 1, id = "ammo_9mm",     label = "9mm Ammo",     category = "misc",   icon = nil, amount = 102, weight = 0.01, usable = false },
        { slot = 2, id = "water_bottle", label = "Water Bottle", category = "drink",  icon = nil, amount = 3,   weight = 0.5,  usable = true },
        { slot = 3, id = "sandwich",     label = "Sandwich",     category = "food",   icon = nil, amount = 2,   weight = 0.3,  usable = true },
        { slot = 5, id = "lockpick",     label = "Lockpick",     category = "tool",   icon = nil, amount = 5,   weight = 0.05, usable = true },
        { slot = 8, id = "bandage",      label = "Bandage",      category = "tool",   icon = nil, amount = 4,   weight = 0.1,  usable = true },
    },
};

-- Initial state. No ui:ready handshake needed: the Interface buffers these until the
-- page is mounted, so it is safe to push right now.
inventory:set(demo_inventory);
hud:push(demo_hud);
hud:sync();
chat:set_commands(command.specs());
chat:system(L:Get("chat.welcome"));

-- Inventory input (JS -> Lua). Closing the page is handled by the router (route:sync).
ui:subscribe("inventory:use", function(slot) inventory:use(slot); end);
ui:subscribe("inventory:drop", function(slot, amount) inventory:drop(slot, amount); end);
ui:subscribe("inventory:move", function(from, to) inventory:move(from, to); end);

-- Chat input (JS -> Lua). A submitted line runs as a command, or is echoed as chat.
-- TODO: broadcast non-command lines to other players (needs a server chat relay), and
-- route command output to chat:command_output instead of the native Chat.SendMessage.
ui:subscribe("chat:submit", function(text)
    chat:focus(false);
    if (command.run(text)) then return; end
    chat:message("chat", "You", text);
end);
ui:subscribe("chat:close", function() chat:focus(false); end);

-- Keep the chat autocomplete in sync as the server pushes the command registry.
Events.SubscribeRemote("command.get_all", function() chat:set_commands(command.specs()); end);
Events.SubscribeRemote("command.get", function() chat:set_commands(command.specs()); end);

-- Keyboard input.
Input.Subscribe("KeyDown", function(key_name)
    if (key_name == "I") then
        inventory:toggle();
    end
end);

-- Open the chat on KeyUp, NOT KeyDown: focusing the WebUI on the same keydown would feed
-- that key's character ("t") straight into the freshly-focused input.
Input.Subscribe("KeyUp", function(key_name)
    if (key_name == "T" and not chat:is_open()) then
        chat:focus(true);
    end
end);

player:Subscribe('Possess', function(pawn)
    if (pawn:IsA(Character)) then
        hud:attach_character(pawn);
    end
end);

player:Subscribe('UnPossess', function(pawn)
    if (pawn:IsA(Character)) then
        hud:detach_character();
    end
end);

return MainUI;
