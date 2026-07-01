--- loader.lua: the client's declarative boot. `boot(ctx, controller1, controller2, ...)`
--- calls each controller with ctx, in registration order. The direct mirror of the
--- Server/core/loader.lua controller pass: a client "module" is a `fun(ctx): void` that
--- wires its own remotes, bus subscriptions, input and view. The client has no DB /
--- services / models, so there is no 3-pass wiring here, just the controllers.
---
--- ```lua
--- boot(ctx, player_controller, hud_controller, chat_controller);
--- ```
---@param ctx ClientAppContext
---@vararg fun(ctx: ClientAppContext): void
---@return void
return function(ctx, ...)
    local controllers <const> = { ... }; ---@type (fun(ctx: ClientAppContext): void)[]
    for i = 1, #controllers do controllers[i](ctx); end
end
