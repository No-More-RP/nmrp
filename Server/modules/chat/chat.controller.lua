--- chat.controller.lua: (C) the chat module's server wiring. Forwards a player's chat line
--- ("chat:send" remote) to every client through the service when the `forward_chat` setting
--- is on, and registers the server-only /chat and /announce commands.
---
--- Security: on "chat:send" only the `text` is trusted from the client. The kind is forced to
--- "chat" and the author is read from the Player server-side, so a player cannot broadcast a
--- fake announcement / staff line or impersonate someone.
---
--- ```lua
--- require 'chat.controller.lua' (ctx);
--- ```
---@param ctx AppContext
---@return void
return function(ctx)
    local service <const> = ctx.services.chat; ---@type ChatService

    -- Player -> server: a submitted chat line. Reliability is consumed by the engine;
    -- the server will broadcast it to every client reliably.
    ---@param player Player
    ---@param kind ChatKind
    ---@param text string
    Events.SubscribeRemote("chat:send", function(player, kind, text)
        if (not ctx.settings.forward_chat and kind == "chat") then return; end
        service.message(kind, player, text);
    end);

    -- Broadcast a plain system line from the server console.
    command({
        name = "say",
        description = "Broadcast a system message to the chat.",
        parameters = {
            { name = "message", type = "merge", description = "The message to send." },
        },
        callback = function(c)
            local text <const> = c.arguments.message;
            if (not text or #text == 0) then return; end
            service.send("system", text);
        end,
        server_only = true,
    });

    -- Broadcast an announcement from the server console.
    command({
        name = "announce",
        description = "Announce a message to all players.",
        parameters = {
            { name = "message", type = "merge", description = "The message to announce." },
        },
        callback = function(c)
            local text <const> = c.arguments.message;
            if (not text or #text == 0) then return; end
            service.send("announcement", text);
        end,
        server_only = true,
    });
end
