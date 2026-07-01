--- command.controller.lua: (C) the client command module. Owns the command-registry
--- remotes: when the server pushes the registry (command.get_all / command.get), it emits
--- "command:changed" on the bus so the chat autocomplete refreshes. The command system
--- itself is the Shared `command` global; this only wires its network to the bus.
---
--- ```lua
--- require 'modules/command/command.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    local function changed() ctx.events:emit("command:changed"); end
    Events.SubscribeRemote("command.get_all", changed);
    Events.SubscribeRemote("command.get", changed);
end
