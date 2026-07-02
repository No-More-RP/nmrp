--- chat.view.lua: (V) chat transport to the WebUI (messages, command specs, focus). Buffers
--- through the Interface. INTERNAL to the chat module (other modules go through the narrow
--- chat service). Closure-factory style: no class, no singleton, one instance in ctx.views.chat.
---
--- ```lua
--- local chat <const> = ctx.views.chat; ---@type ChatView
--- chat.announce("Welcome to the server!");
--- ```
---@param ctx ClientAppContext
---@return ChatView
return function(ctx)
    local ui <const> = ctx.ui;

    -- Disable the native chat (we render our own).
    Chat.SetVisibility(false);

    ---@class ChatView
    local view <const> = {};

    local open = false; -- input box shown / focused

    --- Append a message to the chat log.
    ---
    --- ```lua
    --- chat.message("staff", "[STAFF] Admin", "Event in 5 minutes.");
    --- ```
    ---@param kind "chat"|"announcement"|"staff"|"system"|"command"
    ---@param author string?
    ---@param text string
    function view.message(kind, author, text) ui:send("chat:message", { kind = kind, author = author, text = text }); end

    --- Server-wide announcement.
    ---
    --- ```lua
    --- chat.announce("Restart in 5 minutes.");
    --- ```
    ---@param text string
    function view.announce(text) view.message("announcement", "SERVER", text); end

    --- Staff / admin message.
    ---
    --- ```lua
    --- chat.staff("[STAFF] Admin", "Be nice.");
    --- ```
    ---@param author string
    ---@param text string
    function view.staff(author, text) view.message("staff", author, text); end

    --- System notice (no author).
    ---
    --- ```lua
    --- chat.system("You joined the server.");
    --- ```
    ---@param text string
    function view.system(text) view.message("system", nil, text); end

    --- Command output line (no author).
    ---
    --- ```lua
    --- chat.command_output("Cash: $1540");
    --- ```
    ---@param text string
    function view.command_output(text) view.message("command", nil, text); end

    --- Clear the whole chat log.
    ---
    --- ```lua
    --- chat.clear();
    --- ```
    function view.clear() ui:send("chat:clear"); end

    --- Push the autocomplete command list to the input.
    ---
    --- ```lua
    --- chat.set_commands(command.specs());
    --- ```
    ---@param specs CommandSpec[]
    function view.set_commands(specs) ui:send("chat:commands", specs); end

    --- Whether the input box is currently open.
    ---
    --- ```lua
    --- if (chat.is_open()) then return; end
    --- ```
    ---@return boolean
    function view.is_open() return open; end

    --- Open/close the input box. On open, grabs WebUI focus so the keyboard goes to the chat
    --- (the page itself is pointer-events-off, so the mouse never touches it).
    ---
    --- ```lua
    --- chat.focus(true);  -- open + focus
    --- chat.focus(false); -- close + release
    --- ```
    ---@param is_open boolean
    function view.focus(is_open)
        open = is_open;
        ui:send("chat:focus", is_open);
        if (is_open) then ui:set_focus(); else ui:release_focus(); end
    end

    return view;
end
