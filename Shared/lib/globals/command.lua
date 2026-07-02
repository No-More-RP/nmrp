---@class CommandContext
---@field player Player|nil The player who ran the command (nil from the server console or a client-local run)
---@field arguments table<string, CommandExecArgument> Parsed arguments, keyed by argument name
---@field name string The command name
---@alias CommandCallback fun(ctx: CommandContext): void
---@alias CommandExecArgument string|number|boolean|Player|Vector|Rotator
---@alias CommandData { name: string, description: string, parameters: CommandArgument[], server_only: boolean, client: boolean }
---@alias CommandConstructor { name: string, description?: string, parameters?: CommandArgument[], callback: CommandCallback, server_only?: boolean }
---@alias RegisteredCommands table<string, CommandData>

local registered_commands <const> = {}; ---@type RegisteredCommands
local registered_commands_callbacks <const> = {}; ---@type table<string, fun(player: Player|nil, args: string[]): void>
local client_commands <const> = {}; ---@type CommandData[]

---@class CommandArgument
---@field name string @The name of the argument
---@field type string @The type of the argument (e.g. "string", "number", "boolean")
---@field optional boolean @Whether the argument is optional (default: false)
---@field description string @The description of the argument (default: "")

---@param arguments CommandArgument[] The list of command arguments
---@return string[] The list of argument descriptions
local function pack_command_arguments_name(arguments)
    local description_parts <const> = {};
    for i = 1, #arguments do
        description_parts[#description_parts + 1] = arguments[i].description or "No description provided";
    end
    return description_parts;
end

--- Parses the command arguments and returns a table of argument values
---@param command_name string The name of the command
---@param arguments CommandArgument[] The list of command arguments
---@param args string[] The list of argument values
---@return table<string, CommandExecArgument> The table of argument values
local function parse_arguments(command_name, arguments, args)
    local parsed_args <const> = {};
    for i = 1, #arguments do
        local argument <const> = arguments[i];
        local arg_value <const> = args[i];
        if (arg_value == nil) then
            if (argument.optional) then
                parsed_args[argument.name] = nil;
            else
                error(("Missing required argument '%s' for command '%s'"):format(argument.name, command_name));
            end
        else
            if (argument.type == "string") then
                parsed_args[argument.name] = tostring(arg_value);
            elseif (argument.type == "number") then
                parsed_args[argument.name] = tonumber(arg_value);
            elseif (argument.type == "boolean") then
                parsed_args[argument.name] = arg_value == "true" or arg_value == "1";
            elseif (argument.type == "player") then
                local player <const> = Player.GetByIndex(tonumber(arg_value));
                if (not player) then
                    error(("Player with index '%s' not found for command '%s'"):format(arg_value, command_name));
                end
                parsed_args[argument.name] = player;
            elseif (argument.type == "vector") then
                local vector_parts <const> = { string.match(arg_value, "([^,]+),([^,]+),([^,]+)") };
                if (#vector_parts ~= 3) then
                    error(("Invalid vector format for argument '%s' in command '%s'. Expected format: x,y,z"):format(argument.name, command_name));
                end
                parsed_args[argument.name] = Vector(tonumber(vector_parts[1]), tonumber(vector_parts[2]), tonumber(vector_parts[3]));
            elseif (argument.type == "rotator") then
                local rotator_parts <const> = { string.match(arg_value, "([^,]+),([^,]+),([^,]+)") };
                if (#rotator_parts ~= 3) then
                    error(("Invalid rotator format for argument '%s' in command '%s'. Expected format: pitch,yaw,roll"):format(argument.name, command_name));
                end
                parsed_args[argument.name] = Rotator(tonumber(rotator_parts[1]), tonumber(rotator_parts[2]), tonumber(rotator_parts[3]));
            else
                error(("Unknown argument type '%s' for argument '%s' in command '%s'"):format(argument.type, argument.name, command_name));
            end
        end
    end
    return parsed_args;
end

--- Builds the dispatcher stored per command. It takes the raw (player, string args),
--- parses them, and calls the user callback with a single CommandContext. On the client
--- a non-local command is forwarded to the server instead of run here.
---@param name string The command name
---@param callback CommandCallback? The callback invoked with the command context
---@param client boolean? Whether the command runs locally on the client
---@return fun(player: Player|nil, args: string[]): void
local function make_command_callback(name, callback, client)
    return function(player, args)
        args = args or {};
        if (IS_SERVER or client) then
            local command_data <const> = registered_commands[name];
            if (not command_data) then
                Console.Log("[command] make_command_callback: no command data registered for command '%s'", name);
                return;
            end
            local success <const>, parsed_args <const> = pcall(parse_arguments, name, command_data.parameters, args);
            if (not success) then
                Console.Log("[command] make_command_callback: failed to parse arguments for command '%s': %s", name, parsed_args);
                return;
            end
            callback({ player = player, arguments = parsed_args, name = name });
        else
            -- Client, non-local command: forward the raw args to the server.
            Events.CallRemote("command.execute", Reliability.Reliable, name, args);
        end
    end;
end

---@param name string The command name
---@param callback CommandCallback The callback to be called when the command is inputted
---@param description string? The command description to display in the console (Default: "")
---@param parameters CommandArgument[]? The list of command arguments (Default: {})
---@param client boolean? Whether the command callback runs locally on the client (Default: false)
---@return void
local function register_command(name, callback, description, parameters, client)
    local command <const> = {
        name = name,
        description = description or "",
        parameters = parameters or {},
        client = client or false
    };
    registered_commands[name] = command;
    local command_callback <const> = make_command_callback(name, callback, client);
    registered_commands_callbacks[name] = command_callback;
    Console.RegisterCommand(name, function(...)
        command_callback(nil, { ... });
    end, description or "No description provided", pack_command_arguments_name(parameters or {}));
    if (IS_SERVER and not command.server_only) then
        client_commands[#client_commands + 1] = command;
        Events.BroadcastRemote("command.get", Reliability.Reliable, command);
	end
end

--- The command system entry point: call it to register a command. It is a table so it
--- can also expose `command.specs()` (registry snapshot for the chat autocomplete) and
--- `command.run(line)` (dispatch a "/…" line). The callback receives a single
--- CommandContext { player, arguments, name }, `player` is nil from the server console
--- or a client-local run.
---
--- ```lua
--- command({ name = "cash", callback = function(ctx) show_cash(ctx.player); end });
--- ```
---@class CommandLib
---@overload fun(data: CommandConstructor): void
command = setmetatable({}, {
    __name = "CommandLib",
    __call = function(_, data)
        return register_command(data.name, data.callback, data.description, data.parameters, IS_CLIENT);
    end,
});

---@alias CommandSpec { name: string, description: string, params: CommandArgument[] }

--- Snapshot the registered commands as autocomplete specs for the chat UI.
---
--- ```lua
--- chat:set_commands(command.specs());
--- ```
---@return CommandSpec[]
function command.specs()
    local specs <const> = {}; ---@type CommandSpec[]
    for _, cmd in pairs(registered_commands) do
        specs[#specs + 1] = { name = cmd.name, description = cmd.description, params = cmd.parameters };
    end
    return specs;
end

--- Dispatch a "/…" line through the command system (client side). Returns true if it
--- matched a known command (then it ran locally or was forwarded to the server).
---
--- ```lua
--- if (not command.run(text)) then chat:message("chat", name, text); end
--- ```
---@param message string
---@return boolean handled
function command.run(message)
    if (message:sub(1, 1) ~= "/") then return false; end
    local name <const>, rest <const> = message:match("^/(%S+)%s*(.*)$");
    if (not name) then return false; end
    local callback <const> = registered_commands_callbacks[name];
    if (not callback) then return false; end
    local args <const> = {};
    for arg in rest:gmatch("%S+") do args[#args + 1] = arg; end
    callback(nil, args);
    return true;
end

if (IS_SERVER) then
    Player.Subscribe("Ready", function(player)
        Events.CallRemote("command.get_all", player, Reliability.Reliable, registered_commands);
    end);
    Package.Subscribe("Load", threadify(function()
        Wait(5000);
        Events.BroadcastRemote("command.get_all", Reliability.Reliable, registered_commands);
    end));
    Events.SubscribeRemote("command.execute", function(player, command_name, args)
        local callback <const> = registered_commands_callbacks[command_name];
        if (not callback) then
            Console.Log("[command] command.execute: no callback registered for command '%s'", command_name);
            Chat.SendMessage(player, ("Command '%s' not found"):format(command_name));
            return;
        end
        callback(player, args);
    end);
    Chat.Subscribe("PlayerSubmit", function(message, player)
        local is_command <const> = message:sub(1, 1) == "/";
        if (not is_command) then
            return true;
        end
        local command_name <const>, args <const> = message:match("^/(%S+)%s*(.*)$");
        if (not command_name) then
            return false;
        end
        local callback <const> = registered_commands_callbacks[command_name];
        if (not callback) then
            return false;
        end
        local args_table <const> = {};
        for arg in args:gmatch("%S+") do
            args_table[#args_table + 1] = arg;
        end
        callback(player, args_table);
        return false;
    end);
end

if (IS_CLIENT) then
    ---@param commands RegisteredCommands
    Events.SubscribeRemote("command.get_all", function(commands)
        for name, command in pairs(commands) do
            register_command(name, nil, command.description, command.parameters);
        end
    end);
    ---@param command CommandData
    Events.SubscribeRemote("command.get", function(command)
        register_command(command.name, nil, command.description, command.parameters);
    end);
    Chat.Subscribe("PlayerSubmit", function(message)
        if (message:sub(1, 1) ~= "/") then return true; end
        command.run(message);
        return false; -- a slash line never shows in the native chat
    end);

    command({
        name = 'clear',
        description = 'Clears the chat window',
        callback = function()
            Console.Log("[command] clear: clearing chat window");
            Chat.Clear();
        end
    });
end
