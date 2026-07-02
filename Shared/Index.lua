IS_SERVER = Server ~= nil; --- Tell whether we're running in server or client context. (Client is nil on the server, Server is nil on the client.)
IS_CLIENT = Client ~= nil; --- Tell whether we're running in server or client context. (Client is nil on the server, Server is nil on the client.)
DEV_MODE = false; --- Enable development mode (hot reload, debug logging, etc). Set to false for production.

Promise.OnUnhandledRejection(function(reason)
    Console.Error(("Unhandled promise rejection: %s"):format(tostring(reason)));
end);

require 'lib/Index.lua'; -- loads the _G globals (table, class, threading, command); classes are indexed below
require 'locales/Index.lua'; -- registers the "nmrp" locale namespace (en/fr)

local Logger <const> = require 'lib/classes/logger.lua'; ---@type Logger

--- Default shared instance. Server terminal in color, client F8 stripped.
logger = Logger({
    level = Logger.LogLevel.INFO,
    trace = false
});

local cache <const> = {}; ---@type table<string, { path: string }> -- module key -> require path

--- Turn a file basename into a PascalCase key: "event-emitter" -> "EventEmitter",
--- "hook" -> "Hook", "ansi" -> "Ansi".
---@param base string
---@return string
local function pascal(base)
    return (base:gsub('[-_]+(%w)', function(c) return c:upper(); end)
                :gsub('^%w', function(c) return c:upper(); end));
end

--- Index every .lua file under `folder` by a PascalCase key derived from its filename, then
--- eagerly require it (main thread: require does not work inside a coroutine, so the whole
--- lib must be loaded now). NMRP.lib.Hook then serves the cached module. The require path is
--- relative to this file's folder (Shared/), like `require 'lib/Index.lua'` above.
---@param folder string a package-relative folder, e.g. "Shared/lib/classes"
---@return void
local function make_cache(folder)
    local files <const> = Package.GetFiles(folder); ---@type string[]
    for i = 1, #files do
        local file <const> = files[i]; ---@type string -- e.g. "Shared/lib/classes/event-emitter.lua"
        local base <const> = file:match('([^/]+)%.lua$'); -- "event-emitter" (nil for non-lua files)
        if (base) then
            local key <const> = pascal(base); -- "EventEmitter"
            assert(not cache[key], "NMRP.lib: duplicate key '" .. key .. "' (" .. file .. ")");
            local path <const> = file:gsub('^Shared/', '');
            cache[key] = { path = path }; -- "lib/classes/event-emitter.lua"
            local ok <const>, mod = pcall(require, cache[key].path);
            if (not ok) then
                error("NMRP.lib: failed to load '" .. tostring(key) .. "' (" .. cache[key].path .. "): " .. tostring(mod));
            end
            cache[key].module = mod; -- store the loaded module for immediate access (see NMRP.lib metatable below)
        end
    end
end

make_cache('Shared/lib/constants');
make_cache('Shared/lib/classes');

---@class NMRP
NMRP = {};
NMRP.IS_SERVER = IS_SERVER;
NMRP.IS_CLIENT = IS_CLIENT;
NMRP.VERSION = Package.GetVersion(); --- The current version of the package.

--- The Logger class. Build a standalone logger from an options table, e.g.
--- `NMRP.Logger({ prefix = "shop", level = NMRP.Logger.LogLevel.INFO })`.
NMRP.Logger = require 'lib/classes/logger.lua'; ---@type Logger
--- The shared logger instance. Derive a prefixed sub-logger with `NMRP.logger:child("shop")`.
NMRP.logger = logger; ---@type Logger
NMRP.command = command;

NMRP.lib = {};
NMRP.lib.class = class;

-- NMRP.lib is read-only: files are eagerly loaded above (cache[key].module), so __index just
-- serves the cached module or errors on an unknown key, and __newindex forbids assignment.
setmetatable(NMRP.lib, {
    __index = function(_, key)
        local data <const> = cache[key];
        if (not data) then
            error("NMRP.lib: unknown module '" .. tostring(key) .. "'");
        end
        return data.module;
    end,
    __newindex = function(_, key)
        error("NMRP.lib: cannot assign to '" .. tostring(key) .. "'");
    end,
});
