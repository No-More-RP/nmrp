local setTimeout <const> = Timer.SetTimeout;
local assert <const> = assert;

--- Resume a coroutine and log any errors that occur.
---@param thread thread The coroutine to resume
---@vararg any The arguments to pass to the coroutine when resuming
local function resume_thread(thread, ...)
    local success <const>, err <const> = coroutine.resume(thread, ...);
    if (not success) then
        logger:error("thread failed: " .. tostring(err));
    end
end

--- Creates a new coroutine and runs the specified function in it.
---
--- ```lua
--- CreateThread(function() Wait(1000); print("1s later"); end);
--- ```
---@param fn function The function to run in the new coroutine
---@vararg any The arguments to pass to the function when it is called
function _G.CreateThread(fn, ...)
    local thread <const> = coroutine.create(fn);
    resume_thread(thread, ...);
    return thread;
end

--- Waits for the specified amount of milliseconds before resuming the current coroutine.
--- This function can only be called from a coroutine, and will throw an error if called from the main thread.
---
--- ```lua
--- Wait(500); -- yield the current coroutine for 500ms
--- ```
---@param ms number The amount of milliseconds to wait before resuming the coroutine
function _G.Wait(ms)
    assert(type(ms) == "number", "Wait: ms must be a number");
    local thread <const>, is_main_thread <const> = coroutine.running();
    assert(thread, "Wait: must be called from a coroutine");
    assert(not is_main_thread, "Wait: cannot be called from the main thread");
    setTimeout(function()
        resume_thread(thread);
    end, ms);
    coroutine.yield();
end

local create_thread <const> = CreateThread;

--- Wraps a function in a coroutine, so that it can be called from the main thread without blocking it.
--- The wrapped function will be called in a new coroutine, and will be able to use the Wait function to yield and resume without blocking the main thread.
---
--- ```lua
--- Player.Subscribe("Spawn", threadify(function(player) players.load(player); end));
--- ```
---@param fn function The function to wrap
---@return function The wrapped function
function _G.threadify(fn)
    return function(...)
        create_thread(fn, ...);
    end
end
