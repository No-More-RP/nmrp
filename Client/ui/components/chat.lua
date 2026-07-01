--- Chat: transport of chat messages + command specs to the WebUI, plus focus on open.
--- Pushes through the Interface (messages buffer until the page is ready). See the event
--- contract in UI/src/nanos/events.ts:
---   Lua -> JS : chat:message, chat:clear, chat:commands, chat:focus
---   JS -> Lua : chat:submit, chat:close
---
--- ```lua
--- local chat <const> = require 'ui/components/chat.lua'.get(interface);
--- chat:announce("Welcome to the server!");
--- ```
---@class ChatUI : LightClass
---@field ui Interface
---@field open boolean
---@overload fun(interface: Interface): ChatUI
local ChatUI <const> = class.new("ChatUI");

--- Disable native chat.
Chat.SetVisibility(false);

local instance; ---@type ChatUI

--- Get the singleton (created on first call with the Interface).
---
--- ```lua
--- local chat <const> = ChatUI.get(interface);
--- ```
---@param interface Interface?
---@return ChatUI
function ChatUI.get(interface)
    instance = instance or ChatUI(interface);
    return instance;
end

---@private
---@param interface Interface The interface manager.
---@return void
function ChatUI:__init(interface)
    self.ui = interface;
    self.open = false;
end

--- Append a message to the chat log.
---
--- ```lua
--- chat:message("staff", "[STAFF] Admin", "Event in 5 minutes.");
--- ```
---@param kind "chat"|"announcement"|"staff"|"system"|"command"
---@param author string?
---@param text string
function ChatUI:message(kind, author, text)
    self.ui:send("chat:message", { kind = kind, author = author, text = text });
end

--- Server-wide announcement.
---
--- ```lua
--- chat:announce("Restart in 5 minutes.");
--- ```
---@param text string
function ChatUI:announce(text) self:message("announcement", "SERVER", text); end

--- Staff/admin message.
---
--- ```lua
--- chat:staff("[STAFF] Admin", "Be nice.");
--- ```
---@param author string
---@param text string
function ChatUI:staff(author, text) self:message("staff", author, text); end

--- System notice (no author).
---
--- ```lua
--- chat:system("You joined the server.");
--- ```
---@param text string
function ChatUI:system(text) self:message("system", nil, text); end

--- Command output line (no author).
---
--- ```lua
--- chat:command_output("Cash: $1540");
--- ```
---@param text string
function ChatUI:command_output(text) self:message("command", nil, text); end

--- Clear the whole chat log.
---
--- ```lua
--- chat:clear();
--- ```
function ChatUI:clear() self.ui:send("chat:clear"); end

--- Push the autocomplete command list to the input.
---
--- ```lua
--- chat:set_commands(command.specs());
--- ```
---@param specs CommandSpec[]
function ChatUI:set_commands(specs) self.ui:send("chat:commands", specs); end

--- Whether the input box is currently open.
---
--- ```lua
--- if (chat:is_open()) then return; end
--- ```
---@return boolean
function ChatUI:is_open() return self.open; end

--- Open/close the input box. On open, grabs WebUI focus so the keyboard goes to the chat
--- (the page itself is pointer-events-off, so the mouse never touches it).
---
--- ```lua
--- chat:focus(true);  -- open + focus
--- chat:focus(false); -- close + release
--- ```
---@param open boolean
function ChatUI:focus(open)
    self.open = open;
    self.ui:send("chat:focus", open);
    if (open) then self.ui:set_focus(); else self.ui:release_focus(); end
end

return ChatUI;
