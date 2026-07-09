--- chat.service.lua: (S) the chat module's public API (ctx.services.chat). Broadcasts chat
--- entries to every client's HUD chat (event "chat:entry"). Two entry points: `message` for
--- a player line (authored by the player's own name, authoritative) and `send` for a
--- server-originated line (default author "SERVER"). The service always broadcasts; whether a
--- player's message is forwarded is decided by the controller (the `forward_chat` setting).
---
--- ```lua
--- local chat <const> = ctx.services.chat;
--- chat.send("announcement", "Restart in 5 minutes.");
--- ```

--- A chat line's category. Drives its styling in the WebUI (see the nmrp-ui ChatMessageKind).
---@alias ChatKind "chat" | "announcement" | "staff" | "system" | "command"

--- Build the chat service.
---
--- ```lua
--- local service <const> = require 'chat.service.lua' (ctx);
--- ```
---@param ctx AppContext
---@return ChatService
return function(ctx)
    ---@class ChatService
    local service <const> = {};

    --- Broadcast a player's chat line to every client, authored by the player's own name.
    --- The name is read server-side, so a client cannot spoof someone else's.
    ---
    --- ```lua
    --- ctx.services.chat.message("chat", player, "hello everyone");
    --- ```
    ---@param kind ChatKind
    ---@param player Player
    ---@param text string
    ---@return void
    function service.message(kind, player, text)
        if (kind == "system" or kind == "command") then return; end
        --- TODO: add a check for player permissions if kind is "staff" or "announcement"
        local author <const> = player:GetName();
        Events.BroadcastRemote("chat:entry", Reliability.Reliable, kind, author, text);
    end

    --- Broadcast a server-originated chat line (no player). The author defaults to "SERVER".
    ---
    --- ```lua
    --- ctx.services.chat.send("announcement", "Event starting now.");
    --- ctx.services.chat.send("staff", "Be nice.", "[STAFF] Admin");
    --- ```
    ---@param kind ChatKind
    ---@param text string
    ---@param author_name string?
    ---@return void
    function service.send(kind, text, author_name)
        local author <const> = author_name or "SERVER";
        Events.BroadcastRemote("chat:entry", Reliability.Reliable, kind, author, text);
    end

    return service;
end
