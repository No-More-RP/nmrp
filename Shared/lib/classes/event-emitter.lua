--- event-emitter.lua: a small but complete event emitter built on the project's
--- light-class. Returns the EventEmitter class; instantiate it with:
---     local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
---     local bus <const> = EventEmitter();
--- (Once required, it is also in the `class` registry as `class.EventEmitter`, not in
--- _G, but prefer require.)
---
--- Listeners run SYNCHRONOUSLY, in registration order, in the CALLER's coroutine.
--- So when emit() is called from inside a threadify'd handler, a listener may
--- :await(), it shares that coroutine. emit() iterates a snapshot, so a listener
--- can safely unsubscribe itself or others mid-dispatch.

--- Multi-event fire-and-forget pub/sub.
---
--- ```lua
--- local bus <const> = EventEmitter();
--- ```
---@class EventEmitter : LightClass
---@field private _listeners table<string, function[]>
---@overload fun(): EventEmitter
local EventEmitter <const> = class.new("EventEmitter");

---@private
---@return void
function EventEmitter:__init()
    self._listeners = {};
end

--- Subscribe `fn` to `event`. Returns an unsubscribe function for convenience.
---
--- ```lua
--- local off <const> = bus:on("player:ready", function(player) print(player); end);
--- off(); -- unsubscribe later
--- ```
---@param event string
---@param fn function
---@return fun(): void unsubscribe
function EventEmitter:on(event, fn)
    local bucket <const> = self._listeners[event] or {};
    bucket[#bucket + 1] = fn;
    self._listeners[event] = bucket;
    return function() self:off(event, fn); end
end

--- Subscribe `fn` to fire at most once, then auto-remove. Returns an unsubscribe fn.
---
--- ```lua
--- bus:once("player:ready", function(player) print("first spawn", player); end);
--- ```
---@param event string
---@param fn function
---@return fun(): void unsubscribe
function EventEmitter:once(event, fn)
    local function wrapper(...)
        self:off(event, wrapper);
        return fn(...);
    end
    return self:on(event, wrapper);
end

--- Remove a specific listener from `event` (matched by reference). No-op if absent.
---
--- ```lua
--- bus:off("player:ready", my_listener);
--- ```
---@param event string
---@param fn function
---@return void
function EventEmitter:off(event, fn)
    local bucket <const> = self._listeners[event];
    if (not bucket) then return; end
    for i = 1, #bucket do
        if (bucket[i] == fn) then
            table.remove(bucket, i);
            return;
        end
    end
end

--- Fire `event`, forwarding extra args to each listener in registration order.
---
--- ```lua
--- bus:emit("player:ready", player, player_data); -- each listener runs as fn(player, player_data)
--- ```
---@param event string
---@vararg any
---@return void
function EventEmitter:emit(event, ...)
    local bucket <const> = self._listeners[event];
    if (not bucket) then return; end
    local snapshot <const> = {}; -- copy so a listener may unsubscribe during dispatch
    for i = 1, #bucket do snapshot[i] = bucket[i]; end
    for i = 1, #snapshot do snapshot[i](...); end
end

--- Number of listeners currently registered for `event`.
---
--- ```lua
--- if (bus:listener_count("player:ready") == 0) then return; end
--- ```
---@param event string
---@return integer
function EventEmitter:listener_count(event)
    local bucket <const> = self._listeners[event];
    return bucket and #bucket or 0;
end

--- Drop all listeners for `event`, or every listener on the emitter if omitted.
---
--- ```lua
--- bus:remove_all_listeners("player:ready"); -- one event
--- bus:remove_all_listeners();               -- everything
--- ```
---@param event string?
---@return void
function EventEmitter:remove_all_listeners(event)
    if (event) then
        self._listeners[event] = nil;
    else
        for key in pairs(self._listeners) do self._listeners[key] = nil; end
    end
end

return EventEmitter;
