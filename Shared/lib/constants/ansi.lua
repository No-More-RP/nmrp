--- ansi.lua: a complete ANSI/SGR escape-code table plus a few builder helpers.
--- Pure data and functions, safe to load on client and server (it only produces
--- strings). The colors only actually render in the server terminal; on the
--- client's F8 console these codes are harmless no-op characters.
---
--- Constant members are UPPER_SNAKE_CASE; the builder helpers stay snake_case.
--- Require-only, sets no global:
---     local ansi <const> = require 'lib/constants/ansi.lua'; ---@type Ansi
---     print(ansi.RED .. "boom" .. ansi.RESET);
---     print(ansi.paint(ansi.GREEN, "ok"));
---     print(ansi.rgb(255, 128, 0) .. "orange" .. ansi.RESET);
---     print(ansi.sgr(1, 4, 31) .. "bold underline red" .. ansi.RESET);

local ESC <const> = string.char(27); -- \27 == \x1b == ESC

---@class Ansi
local ansi <const> = {};

ansi.ESC = ESC;         -- the raw escape byte
ansi.CSI = ESC .. '[';  -- Control Sequence Introducer

-- reset
ansi.RESET      = ESC .. '[0m';
ansi.CLEAR      = ansi.RESET; -- alias

-- styles
ansi.BOLD       = ESC .. '[1m';
ansi.DIM        = ESC .. '[2m';
ansi.ITALIC     = ESC .. '[3m';
ansi.UNDERLINE  = ESC .. '[4m';
ansi.BLINK      = ESC .. '[5m';
ansi.BLINK_FAST = ESC .. '[6m';
ansi.INVERSE    = ESC .. '[7m';
ansi.HIDDEN     = ESC .. '[8m';
ansi.STRIKE     = ESC .. '[9m';

-- style resets
ansi.NO_BOLD      = ESC .. '[22m'; -- also clears dim
ansi.NO_DIM       = ESC .. '[22m';
ansi.NO_ITALIC    = ESC .. '[23m';
ansi.NO_UNDERLINE = ESC .. '[24m';
ansi.NO_BLINK     = ESC .. '[25m';
ansi.NO_INVERSE   = ESC .. '[27m';
ansi.NO_HIDDEN    = ESC .. '[28m';
ansi.NO_STRIKE    = ESC .. '[29m';

-- foreground (normal)
ansi.BLACK   = ESC .. '[30m';
ansi.RED     = ESC .. '[31m';
ansi.GREEN   = ESC .. '[32m';
ansi.YELLOW  = ESC .. '[33m';
ansi.BLUE    = ESC .. '[34m';
ansi.MAGENTA = ESC .. '[35m';
ansi.CYAN    = ESC .. '[36m';
ansi.WHITE   = ESC .. '[37m';
ansi.DEFAULT = ESC .. '[39m'; -- reset foreground only

-- foreground (bright)
ansi.BRIGHT_BLACK   = ESC .. '[90m';
ansi.GRAY           = ansi.BRIGHT_BLACK; -- alias
ansi.GREY           = ansi.BRIGHT_BLACK; -- alias
ansi.BRIGHT_RED     = ESC .. '[91m';
ansi.BRIGHT_GREEN   = ESC .. '[92m';
ansi.BRIGHT_YELLOW  = ESC .. '[93m';
ansi.BRIGHT_BLUE    = ESC .. '[94m';
ansi.BRIGHT_MAGENTA = ESC .. '[95m';
ansi.BRIGHT_CYAN    = ESC .. '[96m';
ansi.BRIGHT_WHITE   = ESC .. '[97m';

-- background (normal)
ansi.BG_BLACK   = ESC .. '[40m';
ansi.BG_RED     = ESC .. '[41m';
ansi.BG_GREEN   = ESC .. '[42m';
ansi.BG_YELLOW  = ESC .. '[43m';
ansi.BG_BLUE    = ESC .. '[44m';
ansi.BG_MAGENTA = ESC .. '[45m';
ansi.BG_CYAN    = ESC .. '[46m';
ansi.BG_WHITE   = ESC .. '[47m';
ansi.BG_DEFAULT = ESC .. '[49m'; -- reset background only

-- background (bright)
ansi.BG_BRIGHT_BLACK   = ESC .. '[100m';
ansi.BG_GRAY           = ansi.BG_BRIGHT_BLACK; -- alias
ansi.BG_GREY           = ansi.BG_BRIGHT_BLACK; -- alias
ansi.BG_BRIGHT_RED     = ESC .. '[101m';
ansi.BG_BRIGHT_GREEN   = ESC .. '[102m';
ansi.BG_BRIGHT_YELLOW  = ESC .. '[103m';
ansi.BG_BRIGHT_BLUE    = ESC .. '[104m';
ansi.BG_BRIGHT_MAGENTA = ESC .. '[105m';
ansi.BG_BRIGHT_CYAN    = ESC .. '[106m';
ansi.BG_BRIGHT_WHITE   = ESC .. '[107m';

--- Build a raw SGR sequence from numeric codes.
---
--- ```lua
--- print(ansi.sgr(1, 4, 31) .. "bold underline red" .. ansi.RESET);
--- ```
---@vararg integer
---@return string
function ansi.sgr(...)
    local codes <const> = { ... }; ---@type integer[]
    return ESC .. '[' .. table.concat(codes, ';') .. 'm';
end

--- 256-color foreground (0-255).
---
--- ```lua
--- print(ansi.fg256(208) .. "orange-ish" .. ansi.RESET);
--- ```
---@param n integer
---@return string
function ansi.fg256(n)
    return ESC .. '[38;5;' .. n .. 'm';
end

--- 256-color background (0-255).
---
--- ```lua
--- print(ansi.bg256(52) .. "dark red bg" .. ansi.RESET);
--- ```
---@param n integer
---@return string
function ansi.bg256(n)
    return ESC .. '[48;5;' .. n .. 'm';
end

--- 24-bit truecolor foreground.
---
--- ```lua
--- print(ansi.rgb(255, 128, 0) .. "orange" .. ansi.RESET);
--- ```
---@param r integer @0-255
---@param g integer @0-255
---@param b integer @0-255
---@return string
function ansi.rgb(r, g, b)
    return ESC .. '[38;2;' .. r .. ';' .. g .. ';' .. b .. 'm';
end

--- 24-bit truecolor background.
---
--- ```lua
--- print(ansi.bg_rgb(20, 20, 40) .. "navy bg" .. ansi.RESET);
--- ```
---@param r integer @0-255
---@param g integer @0-255
---@param b integer @0-255
---@return string
function ansi.bg_rgb(r, g, b)
    return ESC .. '[48;2;' .. r .. ';' .. g .. ';' .. b .. 'm';
end

--- Wrap `text` in `color` (any concatenation of codes) then reset.
---
--- ```lua
--- print(ansi.paint(ansi.GREEN, "ok")); -- green "ok" then reset
--- ```
---@param color string
---@param text any
---@return string
function ansi.paint(color, text)
    return color .. tostring(text) .. ansi.RESET;
end

--- Strip every SGR escape sequence from `s`, for a sink that does not understand
--- ANSI (a log file, the client F8 console).
---
--- ```lua
--- local plain <const> = ansi.strip(ansi.RED .. "hi" .. ansi.RESET); -- "hi"
--- ```
---@param s string
---@return string
function ansi.strip(s)
    return (s:gsub(ESC .. '%[[%d;]*m', ''));
end

return ansi;
