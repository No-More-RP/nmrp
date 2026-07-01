--- bus.lua: the client's single domain event bus (one shared EventEmitter instance),
--- the mirror of Server/core/bus.lua. Views subscribe to lifecycle / domain signals
--- here (player:ready, character:possess, character:unpossess, stamina, command:changed)
--- instead of being wired imperatively in app.lua. net.lua is the sole producer: it turns
--- engine events and server remotes into bus emits. It is an instance, so call methods
--- with `:` (bus:on, bus:emit).
---
--- ```lua
--- local bus <const> = require 'core/bus.lua'; ---@type EventEmitter
--- bus:on("player:ready", function() hud:sync(); end);
--- ```
local EventEmitter <const> = require 'lib/classes/event-emitter.lua'; ---@type EventEmitter
return EventEmitter();
