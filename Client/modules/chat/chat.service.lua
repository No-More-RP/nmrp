--- chat.service.lua: (S) the chat module's public API (ctx.services.chat), a narrow facade
--- over its view (ctx.views.chat). Only the message senders are exposed; the input / focus /
--- autocomplete internals stay in the controller.

--- Build the chat service.
---
--- ```lua
--- local chat <const> = ctx.services.chat;
--- chat.announce("Restart in 5 minutes.");
--- ```
---@param ctx ClientAppContext
---@return ChatService
return function(ctx)
    local view <const> = ctx.views.chat; ---@type ChatView

    ---@class ChatService
    local service <const> = {};

    --- Append a message to the chat log.
    ---
    --- ```lua
    --- ctx.services.chat.message("staff", "[STAFF] Admin", "Event in 5 minutes.");
    --- ```
    ---@param kind "chat"|"announcement"|"staff"|"system"|"command"
    ---@param author string?
    ---@param text string
    function service.message(kind, author, text) view.message(kind, author, text); end

    --- Server-wide announcement.
    ---
    --- ```lua
    --- ctx.services.chat.announce("Restart in 5 minutes.");
    --- ```
    ---@param text string
    function service.announce(text) view.announce(text); end

    --- Staff / admin message.
    ---
    --- ```lua
    --- ctx.services.chat.staff("[STAFF] Admin", "Be nice.");
    --- ```
    ---@param author string
    ---@param text string
    function service.staff(author, text) view.staff(author, text); end

    --- System notice (no author).
    ---
    --- ```lua
    --- ctx.services.chat.system("You joined the server.");
    --- ```
    ---@param text string
    function service.system(text) view.system(text); end

    --- Command output line (no author).
    ---
    --- ```lua
    --- ctx.services.chat.command_output("Cash: $1540");
    --- ```
    ---@param text string
    function service.command_output(text) view.command_output(text); end

    --- Clear the whole chat log.
    ---
    --- ```lua
    --- ctx.services.chat.clear();
    --- ```
    function service.clear() view.clear(); end

    return service;
end
