--- Interface: the single WebUI manager. It owns the main WebUI, buffers outgoing
--- messages until the page signals it is ready (so pushing is always safe, even at
--- startup), centralizes focus, and exposes the Lua <-> JS transport. Pages and components
--- push through it instead of touching the WebUI directly.
---
--- Extends EventEmitter for Lua-side lifecycle events ("ready", "focus", "blur").
---
--- ```lua
--- local Interface <const> = require 'ui/interface.lua'; ---@type Interface
--- local ui <const> = Interface.get(main_webui);
--- ui:send("hud:update", { health = 100 }); -- queued until the page is ready
--- ```
local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
local Logger <const> = require 'lib/classes/logger.lua'; ---@type Logger

---@class Interface : EventEmitter
---@field logger Logger
---@field ui WebUI
---@field ready boolean
---@field has_focus boolean
---@field private _queue { action: string, data: any }[]
---@field private _mouse boolean
---@overload fun(webui: WebUI): Interface
local Interface <const> = class.extend("Interface", EventEmitter);

local instance; ---@type Interface

--- Get the singleton (created on first call with the WebUI).
---
--- ```lua
--- local ui <const> = Interface.get(main_webui);
--- ```
---@param webui WebUI?
---@return Interface
function Interface.get(webui)
    instance = instance or Interface(webui);
    return instance;
end

---@private
---@param webui WebUI
---@return void
function Interface:__init(webui)
    EventEmitter.__init(self);
    self.logger = Logger("Interface");
    self.ui = webui;
    self.ready = false;
    self.has_focus = false;
    self._queue = {}; ---@type { action: string, data: any }[]
    self._mouse = false;

    -- The page is mounted: flush everything buffered, then announce ready (Lua side).
    webui:Subscribe("ui:ready", function()
        if (self.ready) then return; end
        self.ready = true;
        for i = 1, #self._queue do
            local m <const> = self._queue[i];
            webui:CallEvent(m.action, m.data);
        end
        self._queue = {};
        self:emit("ready");
    end);

    -- Emit the window focus lifecycle for the Lua side.
    Client.Subscribe("WindowFocusChange", function(is_focused)
        self:emit(is_focused and "focus" or "blur");
    end);
end

--- Push an action to the page (Lua -> JS). Buffered until the page is ready, so it is
--- always safe to call, even before the handshake.
---
--- ```lua
--- ui:send("hud:update", { health = 100 });
--- ```
---@param action string
---@param data any?
function Interface:send(action, data)
    if (not self.ui:IsValid()) then
        self.logger:warn("WebUI is not valid, cannot send action '%s'", action);
        return;
    end
    if (not self.ready) then
        self._queue[#self._queue + 1] = { action = action, data = data };
        return;
    end
    self.ui:CallEvent(action, data);
end

--- Listen for an action coming from the page (JS -> Lua).
---
--- ```lua
--- ui:subscribe("chat:submit", function(text) send(text); end);
--- ```
---@param action string
---@param listener function
function Interface:subscribe(action, listener)
    if (not self.ui:IsValid()) then
        self.logger:warn("WebUI is not valid, cannot subscribe to action '%s'", action);
        return;
    end
    self.ui:Subscribe(action, listener);
end

--- Grab WebUI focus (keyboard). Pass `mouse = true` to also enable the cursor. The state
--- is tracked so it can be restored after an alt-tab.
---
--- ```lua
--- ui:set_focus();     -- keyboard only (chat)
--- ui:set_focus(true); -- + mouse (an interactive panel)
--- ```
---@param mouse boolean?
function Interface:set_focus(mouse)
    if (not self.ui:IsValid()) then
        self.logger:warn("WebUI is not valid, cannot set focus");
        return;
    end
    self.has_focus = true;
    self._mouse = mouse or false;
    self.ui:SetFocus();
    Input.SetMouseEnabled(self._mouse);
end

--- Release WebUI focus and the mouse.
---
--- ```lua
--- ui:release_focus();
--- ```
function Interface:release_focus()
    if (not self.ui:IsValid()) then
        self.logger:warn("WebUI is not valid, cannot release focus");
        return;
    end
    self.has_focus = false;
    self._mouse = false;
    self.ui:RemoveFocus();
    Input.SetMouseEnabled(false);
end

return Interface;
