--- chat.module.lua: client module descriptor for the chat. Owns a view (ctx.views.chat),
--- exposes a narrow service (ctx.services.chat) over it, and wires the input / autocomplete /
--- toggle in its controller.
local view <const>       = require 'chat.view.lua';       ---@type fun(ctx: ClientAppContext): ChatView
local service <const>    = require 'chat.service.lua';    ---@type fun(ctx: ClientAppContext): ChatService
local controller <const> = require 'chat.controller.lua'; ---@type fun(ctx: ClientAppContext): void

---@type ClientAppModule
return {
    name = "chat",
    view = view,
    service = service,
    controller = controller
};
