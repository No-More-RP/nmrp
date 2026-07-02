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

---@class AnsiColor
local ansi_colors <const> = {};

---@class Ansi : AnsiColor
---@overload fun(color: AnsiColor | string, text: any): string
local ansi <const> = setmetatable({}, {
    __index = ansi_colors;
    __call = function(self, color, text)
        return self.paint(color, text);
    end;
});

ansi_colors.ESC = ESC;         -- the raw escape byte
ansi_colors.CSI = ESC .. '[';  -- Control Sequence Introducer

-- reset
ansi_colors.RESET      = ESC .. '[0m';
ansi_colors.CLEAR      = ansi_colors.RESET; -- alias

-- styles
ansi_colors.BOLD       = ESC .. '[1m';
ansi_colors.DIM        = ESC .. '[2m';
ansi_colors.ITALIC     = ESC .. '[3m';
ansi_colors.UNDERLINE  = ESC .. '[4m';
ansi_colors.BLINK      = ESC .. '[5m';
ansi_colors.BLINK_FAST = ESC .. '[6m';
ansi_colors.INVERSE    = ESC .. '[7m';
ansi_colors.HIDDEN     = ESC .. '[8m';
ansi_colors.STRIKE     = ESC .. '[9m';

-- style resets
ansi_colors.NO_BOLD      = ESC .. '[22m'; -- also clears dim
ansi_colors.NO_DIM       = ESC .. '[22m';
ansi_colors.NO_ITALIC    = ESC .. '[23m';
ansi_colors.NO_UNDERLINE = ESC .. '[24m';
ansi_colors.NO_BLINK     = ESC .. '[25m';
ansi_colors.NO_INVERSE   = ESC .. '[27m';
ansi_colors.NO_HIDDEN    = ESC .. '[28m';
ansi_colors.NO_STRIKE    = ESC .. '[29m';

-- foreground (normal)
ansi_colors.BLACK   = ESC .. '[30m';
ansi_colors.RED     = ESC .. '[31m';
ansi_colors.GREEN   = ESC .. '[32m';
ansi_colors.YELLOW  = ESC .. '[33m';
ansi_colors.BLUE    = ESC .. '[34m';
ansi_colors.MAGENTA = ESC .. '[35m';
ansi_colors.CYAN    = ESC .. '[36m';
ansi_colors.WHITE   = ESC .. '[37m';
ansi_colors.DEFAULT = ESC .. '[39m'; -- reset foreground only

-- foreground (bright)
ansi_colors.BRIGHT_BLACK   = ESC .. '[90m';
ansi_colors.GRAY           = ansi_colors.BRIGHT_BLACK; -- alias
ansi_colors.GREY           = ansi_colors.BRIGHT_BLACK; -- alias
ansi_colors.BRIGHT_RED     = ESC .. '[91m';
ansi_colors.BRIGHT_GREEN   = ESC .. '[92m';
ansi_colors.BRIGHT_YELLOW  = ESC .. '[93m';
ansi_colors.BRIGHT_BLUE    = ESC .. '[94m';
ansi_colors.BRIGHT_MAGENTA = ESC .. '[95m';
ansi_colors.BRIGHT_CYAN    = ESC .. '[96m';
ansi_colors.BRIGHT_WHITE   = ESC .. '[97m';

-- background (normal)
ansi_colors.BG_BLACK   = ESC .. '[40m';
ansi_colors.BG_RED     = ESC .. '[41m';
ansi_colors.BG_GREEN   = ESC .. '[42m';
ansi_colors.BG_YELLOW  = ESC .. '[43m';
ansi_colors.BG_BLUE    = ESC .. '[44m';
ansi_colors.BG_MAGENTA = ESC .. '[45m';
ansi_colors.BG_CYAN    = ESC .. '[46m';
ansi_colors.BG_WHITE   = ESC .. '[47m';
ansi_colors.BG_DEFAULT = ESC .. '[49m'; -- reset background only

-- background (bright)
ansi_colors.BG_BRIGHT_BLACK   = ESC .. '[100m';
ansi_colors.BG_GRAY           = ansi_colors.BG_BRIGHT_BLACK; -- alias
ansi_colors.BG_GREY           = ansi_colors.BG_BRIGHT_BLACK; -- alias
ansi_colors.BG_BRIGHT_RED     = ESC .. '[101m';
ansi_colors.BG_BRIGHT_GREEN   = ESC .. '[102m';
ansi_colors.BG_BRIGHT_YELLOW  = ESC .. '[103m';
ansi_colors.BG_BRIGHT_BLUE    = ESC .. '[104m';
ansi_colors.BG_BRIGHT_MAGENTA = ESC .. '[105m';
ansi_colors.BG_BRIGHT_CYAN    = ESC .. '[106m';
ansi_colors.BG_BRIGHT_WHITE   = ESC .. '[107m';

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
--- print(ansi.paint(ansi.BOLD .. ansi.UNDERLINE .. ansi.RED, "boom")); -- bold underline red "boom" then reset
--- print(ansi.paint(ansi.rgb(255, 128, 0), "orange")); -- orange "orange" then reset
--- print(ansi.paint(ansi.fg256(208), "orange-ish")); -- 256-color orange-ish "orange-ish" then reset
--- print(ansi.paint(ansi.bg_rgb(20, 20, 40), "navy bg")); -- navy background "navy bg" then reset
--- print(ansi.paint(ansi.BOLD .. ansi.bg_rgb(20, 20, 40) .. ansi.rgb(255, 128, 0), "bold orange on navy")); -- bold orange on navy background then reset
--- print(ansi.paint('RED', "boom")); -- string key lookup works too
--- ```
---@param color string | Ansi
---@param text any
---@return string
function ansi.paint(color, text)
    return (ansi_colors[color] or color) .. tostring(text) .. ansi_colors.RESET;
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
