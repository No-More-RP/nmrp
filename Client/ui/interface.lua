--- Interface: the single WebUI manager. It owns the main WebUI, buffers outgoing
--- messages until the page signals it is ready (so pushing is always safe, even at
--- startup), centralizes focus, drives the page
--- router (the current route is always kept in sync Lua <-> JS), and exposes the
--- Lua <-> JS transport. Pages and components push through it instead of touching the
--- WebUI directly.
---
--- Extends EventEmitter for Lua-side lifecycle events ("ready", "focus", "blur",
--- "route:changed").
---
--- ```lua
--- local Interface <const> = require 'ui/interface.lua'; ---@type Interface
--- local ui <const> = Interface.get(main_webui);
--- ui:send("hud:update", { health = 100 }); -- queued until the page is ready
--- ui:set_route("/inventory", { focus = true, mouse = true });
--- ```
local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
local hooks <const> = require 'lib/classes/hook.lua'; ---@type HookModule

---@alias RouteOptions { focus?: boolean, mouse?: boolean }

---@class Interface : EventEmitter
---@field ui WebUI
---@field ready boolean
---@field has_focus boolean
---@field current_route string
---@field private _queue { action: string, data: any }[]
---@field private _mouse boolean
---@field private _route_hook BailHook
---@field private _pending { route: string, opts: RouteOptions, promise: Promise }?
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
    self.ui = webui;
    self.ready = false;
    self.has_focus = false;
    self.current_route = "/";
    self._queue = {}; ---@type { action: string, data: any }[]
    self._mouse = false;
    self._route_hook = hooks.BailHook();
    self._pending = nil;

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

    -- The page confirms its current route (after a set_route OR a JS-initiated nav). This
    -- is the single source of truth for `current_route`: focus is applied only once the
    -- page is actually showing the route.
    webui:Subscribe("route:sync", function(route)
        self.current_route = route;
        local p <const> = self._pending;
        if (p and p.route == route) then
            self._pending = nil;
            if (p.opts.focus) then self:set_focus(p.opts.mouse); else self:release_focus(); end
            p.promise:resolve(true);
        elseif (route == "/") then
            self:release_focus(); -- back to the game
        end
        self:emit("route:changed", route);
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
--- ui:send("hud:update", { money = 1540 });
--- ```
---@param action string
---@param data any?
function Interface:send(action, data)
    if (not self.ready) then
        self._queue[#self._queue + 1] = { action = action, data = data };
        return;
    end
    self.ui:CallEvent(action, data);
end

--- Listen for an action coming from the page (JS -> Lua).
---
--- ```lua
--- ui:subscribe("inventory:use", function(slot) use(slot); end);
--- ```
---@param action string
---@param listener function
function Interface:subscribe(action, listener)
    self.ui:Subscribe(action, listener);
end

--- Grab WebUI focus (keyboard). Pass `mouse = true` to also enable the cursor. The state
--- is tracked so it can be restored after an alt-tab.
---
--- ```lua
--- ui:set_focus();     -- keyboard only (chat)
--- ui:set_focus(true); -- + mouse (inventory)
--- ```
---@param mouse boolean?
function Interface:set_focus(mouse)
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
    self.has_focus = false;
    self._mouse = false;
    self.ui:RemoveFocus();
    Input.SetMouseEnabled(false);
end

--- Register a route veto: `fn(route, opts)` returning a non-nil value blocks the change
--- (e.g. "can't open the menu while in a cutscene"). Returns an untap function.
---
--- ```lua
--- ui:on_route(function(route) if (in_cutscene) then return "blocked"; end end);
--- ```
---@param fn fun(route: string, opts: RouteOptions): any
---@return fun(): void untap
function Interface:on_route(fn)
    return self._route_hook:tap(fn);
end

--- Navigate the page to `route` (Lua -> JS) and apply focus once the page confirms it.
--- Vetoable via on_route. Returns a Promise resolving true once the page synced, false if
--- it was vetoed or timed out.
---
--- ```lua
--- ui:set_route("/inventory", { focus = true, mouse = true });
--- ```
---@param route string
---@param opts RouteOptions?
---@return Promise
function Interface:set_route(route, opts)
    opts = opts or {};
    if (route:sub(1, 1) ~= "/") then route = "/" .. route; end
    if (route ~= "/" and self._route_hook:call(route, opts) ~= nil) then
        return Promise.resolve(false);
    end

    local promise <const> = Promise();
    self._pending = { route = route, opts = opts, promise = promise };
    self:send("route:set", route);

    -- Timeout fallback: if the page never confirms, give up.
    Timer.SetTimeout(function()
        if (self._pending and self._pending.route == route) then
            self._pending = nil;
            promise:resolve(false);
        end
    end, 5000);

    return promise;
end

--- Navigate back to the default route ("/", the game), releasing focus.
---
--- ```lua
--- ui:reset_route();
--- ```
---@return Promise
function Interface:reset_route()
    return self:set_route("/", { focus = false });
end

return Interface;
