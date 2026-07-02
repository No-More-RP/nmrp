--- Minimum-severity thresholds. A message prints when its level >= logger.level.
--- Distinct numbers per level (even where severity is close) so tag lookup is 1:1.
---@class LogLevel
local LogLevel <const> = {
    DEBUG   = 10,
    INFO    = 20,
    SUCCESS = 25,
    WARN    = 30,
    ERROR   = 40,
    FATAL   = 50,
};

return LogLevel;
