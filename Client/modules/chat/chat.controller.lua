--- chat.controller.lua: (C) the client chat module. Owns its view's internal wiring: the
--- input (JS -> Lua), the command autocomplete (bus "command:changed"), the welcome line
--- (bus "player:ready") and the toggle key. Other modules push messages through the narrow
--- ctx.services.chat facade.
---
--- ```lua
--- require 'modules/chat/chat.controller.lua' (ctx);
--- ```
---@param ctx ClientAppContext
---@return void
return function(ctx)
    local service <const> = ctx.services.chat; ---@type CChatService
    local chat <const> = ctx.views.chat; ---@type ChatView
    local ui <const> = ctx.interface;

    Events.SubscribeRemote("chat:entry", function(kind, author, text)
        chat.message(kind, author or "Unknown", text);
    end);

    -- JS -> Lua: a submitted line runs as a command, or is echoed as chat.
    ui:subscribe("chat:submit", function(text)
        chat.focus(false);
        if (command.run(text)) then return; end
        if (ctx.settings.forward_chat) then
            service.send("chat", text);
        end
    end);
    ui:subscribe("chat:close", function() chat.focus(false); end);

    -- /clear: wipe the local chat log. Client-only (the native chat is disabled), so it drives
    -- our WebUI log through the chat service rather than the native Chat.Clear().
    command({
        name = "clear",
        description = ctx.locale:t("chat.clear_description"),
        callback = function() service.clear(); end,
    });

    -- Refresh the autocomplete when the server pushes the command registry.
    ctx.events:on("command:changed", function() chat.set_commands(command.specs()); end);
    chat.set_commands(command.specs());

    -- Welcome once the player is loaded (server-driven, not hardcoded at boot).
    ctx.events:on("player:ready", function() chat.system(ctx.locale:Get("chat.welcome")); end);

    -- Toggle the input on the chat key (Released, so the key char never leaks into it).
    Input.Register("ToggleChat", "T", ctx.locale:t("chat.bind_description"));
    Input.Bind("ToggleChat", InputEvent.Released, function()
        if (chat.is_open()) then return; end
        chat.focus(true);
    end);
end
