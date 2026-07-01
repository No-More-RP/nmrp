--- emitter.lua: the application's single event bus: one shared instance of the
--- EventEmitter class (defined in Shared/lib/classes/event-emitter.lua).
---
--- Modules react to fire-and-forget signals through this instance, e.g. a HUD module
--- does `ctx.events:on("player:ready", ...)`. For lifecycle work that must be AWAITED
--- (loading a player's data), use the player service's on_loading/on_releasing hooks
--- instead, not this bus. It's a class instance, so call methods with `:` (events:emit).
local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
return EventEmitter();
