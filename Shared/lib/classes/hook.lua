--- hook.lua: a small "tapable"-style family of hook classes, built on light-class.
--- Where EventEmitter is multi-event fire-and-forget pub/sub, a Hook is ONE ordered
--- pipeline of callbacks ("taps") for a single extension point. Variants differ only
--- in how :call() combines the taps.
---
--- All taps run SYNCHRONOUSLY in the caller's coroutine, so a tap may :await() when
--- :call() is invoked from a threadify'd handler.
---
--- Once this file is required, the classes are retrievable from the `class` registry
--- (class.Hook, class.BailHook, class.WaterfallHook, class.ParallelHook), these live in
--- light-class's container, NOT in _G. Prefer `require` for typed access (see below).

--- Base hook: run every tap in registration order, forwarding the same args.
---
--- ```lua
--- local hook <const> = hooks.Hook();
--- ```
---@class Hook : LightClass
---@field protected _taps function[]
---@overload fun(): Hook
local Hook <const> = class.new("Hook");

---@private
---@return void
function Hook:__init()
    self._taps = {};
end

--- Add a tap. Returns an untap() function for convenience.
---
--- ```lua
--- local untap <const> = hook:tap(function(player) print(player); end);
--- untap(); -- remove it later
--- ```
---@param fn function
---@return fun(): void untap
function Hook:tap(fn)
    self._taps[#self._taps + 1] = fn;
    return function() self:untap(fn); end
end

--- Remove a tap by reference. No-op if absent.
---
--- ```lua
--- hook:untap(my_fn);
--- ```
---@param fn function
---@return void
function Hook:untap(fn)
    for i = 1, #self._taps do
        if (self._taps[i] == fn) then
            table.remove(self._taps, i);
            return;
        end
    end
end

--- Number of taps currently registered.
---
--- ```lua
--- if (hook:count() == 0) then return; end
--- ```
---@return integer
function Hook:count() return #self._taps; end

--- Remove every tap.
---
--- ```lua
--- hook:clear();
--- ```
---@return void
function Hook:clear() self._taps = {}; end

--- Run all taps in order. Iterates a snapshot so a tap may untap during the call.
---
--- ```lua
--- hook:call(player, data); -- each tap runs as fn(player, data)
--- ```
---@vararg any
---@return void
function Hook:call(...)
    local snapshot <const> = {};
    for i = 1, #self._taps do snapshot[i] = self._taps[i]; end
    for i = 1, #snapshot do snapshot[i](...); end
end

--- Stops at the first tap returning a non-nil value and returns it (veto / lookup).
---
--- ```lua
--- local can_enter <const> = hooks.BailHook();
--- ```
---@class BailHook : Hook
---@overload fun(): BailHook
local BailHook <const> = class.extend("BailHook", Hook);

---@private
---@return void
function BailHook:__init() Hook.__init(self); end -- light-class does not auto-call super __init

--- Run taps until one returns non-nil; return that value (or nil if none do).
---
--- ```lua
--- local denial <const> = can_enter:call(player); -- first veto reason, or nil if allowed
--- ```
---@vararg any
---@return any|nil
function BailHook:call(...)
    for i = 1, #self._taps do
        local result <const> = self._taps[i](...);
        if (result ~= nil) then return result; end
    end
    return nil;
end

--- Threads a value through every tap: each receives the running value (+ extra
--- context args) and returns the next value; a nil return keeps the previous value.
---
--- ```lua
--- local price <const> = hooks.WaterfallHook();
--- ```
---@class WaterfallHook : Hook
---@overload fun(): WaterfallHook
local WaterfallHook <const> = class.extend("WaterfallHook", Hook);

---@private
---@return void
function WaterfallHook:__init() Hook.__init(self); end

--- Run taps as a value pipeline. `value` is the seed; extra args are passed through
--- unchanged to every tap. Returns the final value.
---
--- ```lua
--- local final <const> = price:call(100, item); -- each tap may adjust the price
--- ```
---@param value any
---@vararg any
---@return any
function WaterfallHook:call(value, ...)
    for i = 1, #self._taps do
        local result <const> = self._taps[i](value, ...);
        if (result ~= nil) then value = result; end
    end
    return value;
end

--- Each tap RETURNS an awaitable (a Norm promise) or nil; all returned promises are
--- put in flight first, then awaited together. Use when taps are independent I/O.
--- NOTE the contract: taps must NOT :await() internally, they return the promise.
---
--- ```lua
--- local loaders <const> = hooks.ParallelHook();
--- ```
---@class ParallelHook : Hook
---@overload fun(): ParallelHook
local ParallelHook <const> = class.extend("ParallelHook", Hook);

---@private
---@return void
function ParallelHook:__init() Hook.__init(self); end

--- Call every tap (collecting their promises), then await all of them. Coroutine-only.
---
--- ```lua
--- loaders:call(player); -- every tap's promise is awaited together
--- ```
---@async
---@vararg any
---@return void
function ParallelHook:call(...)
    local promises <const> = {}; ---@type Promise[]
    for i = 1, #self._taps do
        local promise <const> = self._taps[i](...);
        if (promise ~= nil) then promises[#promises + 1] = promise; end
    end
    for i = 1, #promises do promises[i]:await(); end
end

-- Each class above is registered in the `class` registry (class.Hook / class.BailHook /
-- etc.) when this file is required, not in _G. We also return them so callers can do
-- `require 'lib/classes/hook.lua'` for typed access. The four are siblings, returning
-- only Hook would hide the rest.
--
-- LuaLS can't follow the mandatory ".lua" require path, so annotate the require site:
--     local hooks = require 'lib/classes/hook.lua'; ---@type HookModule
-- HookModule (and every Hook class) is indexed workspace-wide, so the annotation is
-- enough, hooks.BailHook() is then typed as a BailHook instance (via the @overload).
---@class HookModule
---@field Hook Hook
---@field BailHook BailHook
---@field WaterfallHook WaterfallHook
---@field ParallelHook ParallelHook
return {
    Hook          = Hook,
    BailHook      = BailHook,
    WaterfallHook = WaterfallHook,
    ParallelHook  = ParallelHook,
};
