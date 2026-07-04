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
    local chat <const> = ctx.views.chat; ---@type ChatView
    local ui <const> = ctx.interface;

    -- JS -> Lua: a submitted line runs as a command, or is echoed as chat.
    ui:subscribe("chat:submit", function(text)
        chat.focus(false);
        if (command.run(text)) then return; end
        chat.message("chat", "You", text);
    end);
    ui:subscribe("chat:close", function() chat.focus(false); end);

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
