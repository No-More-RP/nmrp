--- stamina.controller.lua: (C) the client stamina module. Owns the "stamina:update" remote:
--- the server pushes an authoritative motion SEGMENT (value, rate, delay) on spawn and at
--- each transition (Server/modules/stamina), and this re-emits it on the bus as "stamina".
--- The HUD consumes it and interpolates the bar; the network stays out of the view.
---
--- ```lua
--- require 'modules/stamina/stamina.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    Events.SubscribeRemote("stamina:update", function(value, rate, delay)
        ctx.events:emit("stamina", value, rate, delay);
    end);
end
