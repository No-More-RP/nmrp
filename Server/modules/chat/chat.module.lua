--- chat.module.lua: server module descriptor for the chat. Exposes the chat service
--- (ctx.services.chat) and wires the controller (player-message forward + /chat, /announce).
--- No Norm model: chat is transient.
--- require paths relative to THIS folder; returns typed by hand.
local service <const>    = require 'chat.service.lua';    ---@type fun(ctx: AppContext): ChatService
local controller <const> = require 'chat.controller.lua'; ---@type fun(ctx: AppContext): void

---@type AppModule
return {
    name = "chat",
    service = service,
    controller = controller,
};
