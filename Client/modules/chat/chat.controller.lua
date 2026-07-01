--- chat.controller.lua: (C) the client chat module. Wires the chat view: the input (JS ->
--- Lua), the command autocomplete (refreshed on the bus "command:changed"), the welcome
--- line (on "player:ready", not hardcoded at boot) and the toggle key.
---
--- ```lua
--- require 'modules/chat/chat.controller.lua' (ctx);
--- ```
local ChatView <const> = require 'chat.view.lua'; ---@type ChatUI

---@param ctx ClientAppContext
---@return void
return function(ctx)
    local chat <const> = ChatView.get(ctx.ui);
    local ui <const> = ctx.ui;

    -- JS -> Lua: a submitted line runs as a command, or is echoed as chat.
    ui:subscribe("chat:submit", function(text)
        chat:focus(false);
        if (command.run(text)) then return; end
        chat:message("chat", "You", text);
    end);
    ui:subscribe("chat:close", function() chat:focus(false); end);

    -- Refresh the autocomplete when the server pushes the command registry.
    ctx.events:on("command:changed", function() chat:set_commands(command.specs()); end);
    chat:set_commands(command.specs());

    -- Welcome once the player is loaded (server-driven, not hardcoded at boot).
    ctx.events:on("player:ready", function() chat:system(ctx.locale:Get("chat.welcome")); end);

    -- Toggle the input on the chat key (Released, so the key char never leaks into it).
    Input.Register("ToggleChat", "T", ctx.locale:t("chat.bind_description"));
    Input.Bind("ToggleChat", InputEvent.Released, function()
        if (chat:is_open()) then return; end
        chat:focus(true);
    end);
end
