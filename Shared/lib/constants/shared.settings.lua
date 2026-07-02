---@class SharedSettings
local SharedSettings <const> = {
    --- The debug mode setting, which can be used to enable or disable debug features in the application, such as verbose logging or additional checks.
    ---
    --- This setting is typically used during development to help identify issues and ensure that the application is functioning correctly.
    DEBUG = "debug",
    --- The mode setting: the current environment of the application, "development" or
    --- "production". It drives DEV_MODE and the logger verbosity (debug level plus call-site
    --- trace in development), and modules may branch on it to toggle their own dev behavior.
    MODE  = "mode"
};

return SharedSettings;
