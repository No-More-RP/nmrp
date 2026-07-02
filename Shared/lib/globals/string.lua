--- string.lua: ANSI color and style helpers on the `string` global. Each wraps its input
--- in an SGR escape then resets, so the text renders colored in the server terminal and is
--- a harmless no-op on the client F8 console. They compose and work both as a function and
--- as a method.
---
--- ```lua
--- print(string.red("boom"));
--- print(string.bold(string.green("ok"))); -- bold green, composed
--- print(("warning"):yellow());            -- method form
--- ```
---
--- The full palette (backgrounds, 256-color, rgb, raw builders) lives in
--- lib/constants/ansi.lua; to strip the codes back out, use ansi.strip.
local ansi <const> = require 'lib/constants/ansi.lua'; ---@type Ansi -- require-only palette

-- Foreground colors.

---@param s string
---@return string
function _G.string.black(s) return ansi.paint(ansi.BLACK, s); end

---@param s string
---@return string
function _G.string.red(s) return ansi.paint(ansi.RED, s); end

---@param s string
---@return string
function _G.string.green(s) return ansi.paint(ansi.GREEN, s); end

---@param s string
---@return string
function _G.string.yellow(s) return ansi.paint(ansi.YELLOW, s); end

---@param s string
---@return string
function _G.string.blue(s) return ansi.paint(ansi.BLUE, s); end

---@param s string
---@return string
function _G.string.magenta(s) return ansi.paint(ansi.MAGENTA, s); end

---@param s string
---@return string
function _G.string.cyan(s) return ansi.paint(ansi.CYAN, s); end

---@param s string
---@return string
function _G.string.white(s) return ansi.paint(ansi.WHITE, s); end

---@param s string
---@return string
function _G.string.gray(s) return ansi.paint(ansi.GRAY, s); end

---@param s string
---@return string
function _G.string.grey(s) return ansi.paint(ansi.GREY, s); end

-- Bright foreground colors.

---@param s string
---@return string
function _G.string.bright_black(s) return ansi.paint(ansi.BRIGHT_BLACK, s); end

---@param s string
---@return string
function _G.string.bright_red(s) return ansi.paint(ansi.BRIGHT_RED, s); end

---@param s string
---@return string
function _G.string.bright_green(s) return ansi.paint(ansi.BRIGHT_GREEN, s); end

---@param s string
---@return string
function _G.string.bright_yellow(s) return ansi.paint(ansi.BRIGHT_YELLOW, s); end

---@param s string
---@return string
function _G.string.bright_blue(s) return ansi.paint(ansi.BRIGHT_BLUE, s); end

---@param s string
---@return string
function _G.string.bright_magenta(s) return ansi.paint(ansi.BRIGHT_MAGENTA, s); end

---@param s string
---@return string
function _G.string.bright_cyan(s) return ansi.paint(ansi.BRIGHT_CYAN, s); end

---@param s string
---@return string
function _G.string.bright_white(s) return ansi.paint(ansi.BRIGHT_WHITE, s); end

-- Text styles.

---@param s string
---@return string
function _G.string.bold(s) return ansi.paint(ansi.BOLD, s); end

---@param s string
---@return string
function _G.string.dim(s) return ansi.paint(ansi.DIM, s); end

---@param s string
---@return string
function _G.string.italic(s) return ansi.paint(ansi.ITALIC, s); end

---@param s string
---@return string
function _G.string.underline(s) return ansi.paint(ansi.UNDERLINE, s); end

---@param s string
---@return string
function _G.string.strike(s) return ansi.paint(ansi.STRIKE, s); end

---@param s string
---@return string
function _G.string.inverse(s) return ansi.paint(ansi.INVERSE, s); end
