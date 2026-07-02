--- logger.lua: a small ANSI logger built on the project's light-class.
---
--- Logs on BOTH sides from the same shared `logger` global. The server terminal
--- gets the full ANSI colors; the client's F8 console (which does not render
--- ANSI) gets the same line with the color codes stripped, so it stays readable
--- instead of showing raw escape sequences.
---
--- Two call styles on every level method (info/success/warn/error/fatal/debug):
---   printf : logger:info("player %s joined with $%d", name, cash)
---   values : logger:info("spawned", entity, Vector(1, 2, 3), 42)
--- Rule: the first arg is a format string ONLY when it is a string, there is at
--- least one extra arg, AND it contains a '%'. Then the args run through
--- string.format (falling back to a space-join if that errors). Any other shape
--- space-joins tostring() of every arg, so a bare string first arg with no '%'
--- never swallows the values that follow it.
---
--- The shared `logger` global is the default instance; `Logger` is the class,
--- for prefixed sub-loggers via logger:child("economy").

local ansi <const> = require 'lib/constants/ansi.lua'; ---@type Ansi -- require-only palette
local getinfo <const> = debug.getinfo;
local format <const> = string.format;
local table_concat <const> = table.concat;

--- Minimum-severity thresholds. A message prints when its level >= logger.level.
--- Distinct numbers per level (even where severity is close) so tag lookup is 1:1.
---@enum LogLevel
_G.LogLevel = {
    DEBUG   = 10,
    INFO    = 20,
    SUCCESS = 25,
    WARN    = 30,
    ERROR   = 40,
    FATAL   = 50,
};

--- Fixed-width (7-char) colored tag per level, so columns line up in the console.
local tags <const> = {
    [LogLevel.DEBUG]   = ansi.BRIGHT_BLACK  .. 'DEBUG  ' .. ansi.RESET,
    [LogLevel.INFO]    = ansi.BRIGHT_BLUE   .. 'INFO   ' .. ansi.RESET,
    [LogLevel.SUCCESS] = ansi.BRIGHT_GREEN  .. 'SUCCESS' .. ansi.RESET,
    [LogLevel.WARN]    = ansi.BRIGHT_YELLOW .. 'WARNING' .. ansi.RESET,
    [LogLevel.ERROR]   = ansi.BRIGHT_RED    .. 'ERROR  ' .. ansi.RESET,
    [LogLevel.FATAL]   = ansi.BOLD .. ansi.BRIGHT_RED .. 'FATAL  ' .. ansi.RESET,
}; ---@type table<integer, string>

--- Lowercase level name to its numeric value, for set_level("warn").
local names <const> = {}; ---@type table<string, integer>
for name, value in pairs(LogLevel) do names[name:lower()] = value; end

--- Collapse a call's varargs into one message string (see file header for rules).
---@vararg any
---@return string
local function build(...)
    local n <const> = select('#', ...);
    if (n == 0) then return ''; end

    local first <const> = ...;
    if (type(first) == 'string' and n > 1 and first:find('%%')) then
        local ok <const>, result <const> = pcall(format, ...);
        if (ok) then return result; end
        -- format error (e.g. a literal '%' that is not a real directive): fall
        -- through and space-join instead of crashing the caller.
    end

    if (n == 1) then return tostring(first); end

    local parts <const> = {}; ---@type string[]
    for i = 1, n do parts[i] = tostring((select(i, ...))); end
    return table_concat(parts, ' ');
end

---@class LoggerOptions
---@field public prefix? string  label shown between the level tag and the message
---@field public level? LogLevel  minimum LogLevel to print (default LogLevel.DEBUG)
---@field public trace? boolean  append [source:line] of the call site (default: DEV_MODE)

--- ANSI logger instance. Use the shared `logger` global, or construct one for a
--- custom prefix/level.
---
--- ```lua
--- local log <const> = Logger({ prefix = "economy", level = LogLevel.INFO });
--- log:info("ready");
--- ```
---@class Logger : LightClass
---@field public prefix string
---@field public level integer
---@field public trace boolean
---@overload fun(options: LoggerOptions?): Logger
local Logger <const> = class.new("Logger");

---@static
Logger.ANSI = ansi; ---@type Ansi -- static: expose the palette for custom colorization

---@alias LoggerColorCode '^b' | '^g' | '^y' | '^r' | '^m' | '^c' | '^w' | '^B' | '^G' | '^Y' | '^R' | '^M' | '^C' | '^W' | '^d' | '^D'

---@type table<LoggerColorCode, string>
local ansi_color_map <const> = {
    ['^b'] = ansi.RESET .. ansi.BRIGHT_BLUE,
    ['^g'] = ansi.RESET .. ansi.BRIGHT_GREEN,
    ['^y'] = ansi.RESET .. ansi.BRIGHT_YELLOW,
    ['^r'] = ansi.RESET .. ansi.BRIGHT_RED,
    ['^m'] = ansi.RESET .. ansi.BRIGHT_MAGENTA,
    ['^c'] = ansi.RESET .. ansi.BRIGHT_CYAN,
    ['^w'] = ansi.RESET .. ansi.BRIGHT_WHITE,
    ['^B'] = ansi.RESET .. ansi.BLUE,
    ['^G'] = ansi.RESET .. ansi.GREEN,
    ['^Y'] = ansi.RESET .. ansi.YELLOW,
    ['^R'] = ansi.RESET .. ansi.RED,
    ['^M'] = ansi.RESET .. ansi.MAGENTA,
    ['^C'] = ansi.RESET .. ansi.CYAN,
    ['^W'] = ansi.RESET .. ansi.WHITE,
    ['^d'] = ansi.RESET .. ansi.DIM,
    ['^D'] = ansi.RESET
};

---@private
---@param options LoggerOptions?
function Logger:__init(options)
    local opts <const> = type(options) == 'table' and options or {};
    self.prefix = opts.prefix or '';
    self.level  = opts.level or LogLevel.DEBUG;
    if (opts.trace ~= nil) then
        self.trace = opts.trace and true or false;
    else
        self.trace = _ENV.DEV_MODE and true or false;
    end
end

--- Core writer: format the args, gate on the level threshold, then print the
--- colored line (ANSI on the server, stripped on the client). Prefer the level
--- helpers below; they keep the `trace` call-site depth correct. Chainable.
---
--- ```lua
--- logger:log(LogLevel.INFO, "player %s joined", name);
--- ```
---@param level integer
---@vararg any
---@return Logger
function Logger:log(level, ...)
    if (level < self.level) then return self; end

    local segments <const> = { tags[level] or '' }; ---@type string[]

    if (#self.prefix > 0) then
        segments[#segments + 1] = ansi.paint(ansi.CYAN, self.prefix);
    end

    if (self.trace) then
        local ctx <const> = getinfo(3, 'Sl'); -- user -> level helper -> log
        if (ctx) then
            segments[#segments + 1] = ansi.paint(
                ansi.BRIGHT_BLACK,
                format('[%s:%d]', ctx.short_src, ctx.currentline)
            );
        end
    end

    segments[#segments + 1] = ansi.paint(ansi.DIM, '>');
    segments[#segments + 1] = build(...);

    local line = table_concat(segments, ' ');

    line = line:gsub('%^%a', function(code)
        return ansi_color_map[code] or code;
    end);

    -- The client's F8 console does not interpret ANSI, so drop the color codes
    -- there for clean text; the server terminal keeps them.
    if (not IS_SERVER) then line = ansi.strip(line); end

    -- Pass the finished line as a '%s' argument so any '%' already inside the
    -- user's message is not re-interpreted by Console.Log's own formatting.
    Console.Log('%s', line);
    return self;
end

--- Log at DEBUG level (hidden unless the logger level is DEBUG).
---
--- ```lua
--- logger:debug("state", self._state);
--- ```
---@vararg any
---@return Logger
function Logger:debug(...) return self:log(LogLevel.DEBUG, ...); end

--- Log at INFO level. See the file header for the printf vs values call styles.
---
--- ```lua
--- logger:info("player %s joined", name);
--- logger:info("spawned", entity, 42); -- values style, no format string
--- ```
---@vararg any
---@return Logger
function Logger:info(...) return self:log(LogLevel.INFO, ...); end

--- Log at SUCCESS level.
---
--- ```lua
--- logger:success("database opened in %d ms", ms);
--- ```
---@vararg any
---@return Logger
function Logger:success(...) return self:log(LogLevel.SUCCESS, ...); end

--- Log at WARN level.
---
--- ```lua
--- logger:warn("low balance for %s", name);
--- ```
---@vararg any
---@return Logger
function Logger:warn(...) return self:log(LogLevel.WARN, ...); end

--- Log at ERROR level.
---
--- ```lua
--- logger:error("save failed: %s", err);
--- ```
---@vararg any
---@return Logger
function Logger:error(...) return self:log(LogLevel.ERROR, ...); end

--- Log at FATAL level.
---
--- ```lua
--- logger:fatal("unrecoverable: %s", err);
--- ```
---@vararg any
---@return Logger
function Logger:fatal(...) return self:log(LogLevel.FATAL, ...); end

--- Set the minimum level. Accepts a LogLevel number or its name ("warn", "info").
---
--- ```lua
--- logger:set_level("warn");         -- hide debug/info/success
--- logger:set_level(LogLevel.ERROR); -- errors and fatals only
--- ```
---@param level LogLevel|"info"|"success"|"warn"|"error"|"fatal"|"debug"
---@return Logger
function Logger:set_level(level)
    if (type(level) == 'string') then
        level = names[level:lower()] or self.level;
    end
    self.level = level;
    return self;
end

--- Whether a message at `level` would print right now (threshold check). Use it
--- to guard expensive-to-build log arguments.
---
--- ```lua
--- if (logger:is_enabled(LogLevel.DEBUG)) then logger:debug(dump(state)); end
--- ```
---@param level LogLevel
---@return boolean
function Logger:is_enabled(level)
    return level >= self.level;
end

--- Create a prefixed sub-logger. Prefix becomes "<parent>:<prefix>" (or just
--- <prefix> when the parent has none). Level and trace are inherited unless
--- overridden.
---
--- ```lua
--- local db_log <const> = logger:child("norm"); -- prints "norm > ..."
--- ```
---@param prefix string
---@param options LoggerOptions?
---@return Logger
function Logger:child(prefix, options)
    local opts <const> = type(options) == 'table' and options or {};
    local merged <const> = #self.prefix > 0 and (self.prefix .. ':' .. prefix) or prefix;
    local trace = self.trace;
    if (opts.trace ~= nil) then trace = opts.trace and true or false; end
    return Logger({
        prefix = merged,
        level  = opts.level or self.level,
        trace  = trace,
    });
end

_ENV.Logger = Logger;

--- Default shared instance. Server terminal in color, client F8 stripped.
---@type Logger
logger = Logger({ level = LogLevel.DEBUG });

return Logger;
