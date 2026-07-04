--- interface.lua: a reusable WebUI manager. Wraps a WebUI to give it buffered messaging
--- (Lua -> JS is queued until the page signals it is ready, so pushing is always safe, even
--- before the page mounts), a focus helper, and the Lua <-> JS transport. Extends
--- EventEmitter for the Lua-side lifecycle ("ready", "focus", "blur").
---
--- NOT a singleton: build one per WebUI. The core wraps its MainInterface; a package with
--- its own frontend wraps its own WebUI the same way through NMRP.Interface, instead of
--- reimplementing the queue / focus / transport.
---
--- ```lua
--- local ui <const> = Interface(my_webui, { name = "Shop", ready_event = "ui:ready" });
--- ui:send("shop:update", data); -- queued until the page is ready
--- ```
local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
local Logger <const> = require 'lib/classes/logger.lua'; ---@type Logger

---@alias InterfaceOptions { name?: string, ready_event?: string, focus_events?: boolean }

---@class Interface : EventEmitter
---@field logger Logger
---@field ui WebUI
---@field ready boolean
---@field has_focus boolean
---@field private _queue { action: string, data: any }[]
---@field private _mouse boolean
---@field private _ready_event string
---@field private _on_focus fun(is_focused: boolean)?
---@overload fun(webui: WebUI, opts?: InterfaceOptions): Interface
local Interface <const> = class.extend("Interface", EventEmitter);

---@private
---@param webui WebUI
---@param opts InterfaceOptions?
---@return void
function Interface:__init(webui, opts)
    EventEmitter.__init(self);
    opts = type(opts) == "table" and opts or {};
    self.logger = Logger(opts.name or "Interface");
    self.ui = webui;
    self.ready = false;
    self.has_focus = false;
    self._queue = {}; ---@type { action: string, data: any }[]
    self._mouse = false;
    self._ready_event = opts.ready_event or "Ready";

    -- The page is mounted: flush everything buffered, then announce ready (Lua side).
    webui:Subscribe(self._ready_event, function()
        if (self.ready) then return; end
        self.ready = true;
        for i = 1, #self._queue do
            local m <const> = self._queue[i];
            webui:CallEvent(m.action, m.data);
        end
        self._queue = {};
        self:emit("ready");
    end);

    -- Window focus lifecycle for the Lua side (opt out with focus_events = false).
    if (opts.focus_events ~= false) then
        self._on_focus = function(is_focused) self:emit(is_focused and "focus" or "blur"); end;
        Client.Subscribe("WindowFocusChange", self._on_focus);
    end
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

--- Tear down: drop the window-focus subscription and the queue. Call it when the wrapped
--- WebUI is destroyed (e.g. a package unloading its own frontend).
---
--- ```lua
--- ui:destroy();
--- ```
function Interface:destroy()
    if (self._on_focus) then
        Client.Unsubscribe("WindowFocusChange", self._on_focus);
        self._on_focus = nil;
    end
    self._queue = {};
end

return Interface;
