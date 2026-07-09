--- loader.lua: the client module loader / registry, the mirror of Server/core/loader.lua.
--- `make_loader(ctx).boot(mod1, mod2, ...)` registers each ClientAppModule, orders them by
--- `depends` (topological), then runs three passes (like the server's model / service /
--- controller passes):
---   1. views       -> each module.view(ctx) is stored in ctx.views[name];
---   2. services    -> each module.service(ctx) is stored in ctx.services[name];
---   3. controllers -> each module.controller(ctx) wires the engine / UI.
--- Synchronous: the client has no awaited DB sync, so no coroutine is needed.
---
--- ```lua
--- make_loader(ctx).boot(
---     require 'modules/hud/hud.module.lua',
---     require 'modules/stamina/stamina.module.lua'
--- );
--- ```
---
---@class ClientAppModule
---@field name string
---@field depends? string[]
---@field view? fun(ctx: ClientAppContext): any
---@field service? fun(ctx: ClientAppContext): any
---@field controller? fun(ctx: ClientAppContext): void
---@field destroy? fun(ctx: ClientAppContext): void   -- teardown hook, run on unregister

---@param ctx ClientAppContext
---@return ClientLoader
return function(ctx)
    local modules <const> = {}; ---@type table<string, ClientAppModule> name -> descriptor
    local order <const> = {};   ---@type string[] registration order (tie-break)
    local booted <const> = {};  ---@type table<string, boolean> name -> wired (its 3 passes ran)
    local boot_lock = false;    ---@type boolean

    local logger <const> = ctx.logger:child('Loader');

    ---@param module ClientAppModule
    local function register(module)
        assert(module and module.name, "client module: missing name");
        assert(not modules[module.name], "client module: duplicate name '" .. tostring(module.name) .. "'");
        modules[module.name] = module;
        order[#order + 1] = module.name;
    end

    -- Depth-first topological sort by `depends`. Hard errors on a missing dep or a cycle.
    ---@return string[]
    local function sorted()
        local result <const> = {}; ---@type string[]
        local state <const> = {};  ---@type table<string, "visiting"|"done">
        local function visit(name)
            if (state[name] == "done") then return; end
            assert(state[name] ~= "visiting", "client module: dependency cycle at '" .. name .. "'");
            local module <const> = modules[name];
            assert(module, "client module: unknown dependency '" .. name .. "'");
            state[name] = "visiting";
            local deps <const> = module.depends;
            if (deps) then for i = 1, #deps do visit(deps[i]); end end
            state[name] = "done";
            result[#result + 1] = name;
        end
        for i = 1, #order do visit(order[i]); end
        return result;
    end

    ---@class ClientLoader
    local loader <const> = {};

    --- Run the view -> service -> controller passes over `names` (already dependency
    --- sorted), skipping any module already wired, then mark the new ones wired.
    ---
    --- ```lua
    --- wire(sorted());
    --- ```
    ---@param names string[]
    ---@param is_addon boolean
    ---@return void
    local function wire(names, is_addon)
        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (not booted[module.name] and module.view) then ctx.views[module.name] = module.view(ctx); end
        end
        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (not booted[module.name] and module.service) then ctx.services[module.name] = module.service(ctx); end
        end
        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (not booted[module.name] and module.controller) then module.controller(ctx); end
        end
        for i = 1, #names do
            if (not booted[names[i]]) then
                logger:debug("started %smodule '^B%s^D'", is_addon and "addon " or "", names[i]);
                booted[names[i]] = true;
            end
        end
    end

    --- Register every module, then boot them in dependency order: views first (into
    --- ctx.views[name]), services second (ctx.services[name]), controllers last.
    ---
    --- ```lua
    --- loader.boot(player_module, hud_module, stamina_module);
    --- ```
    ---@vararg ClientAppModule
    ---@return ClientAppContext
    function loader.boot(...)
        if (boot_lock) then error("client loader: boot() already called"); end
        boot_lock = true;
        local list <const> = { ... }; ---@type ClientAppModule[]
        for i = 1, #list do register(list[i]); end
        local names <const> = sorted();
        wire(names, false);
        logger:success("started ^G%d^D module(s)", #names);
        return ctx;
    end

    --- Late-register addon modules AFTER boot. Their descriptors join the graph and only the
    --- new ones are wired (they may depend on already-booted core modules). Synchronous: the
    --- client has no awaited work.
    ---
    --- ```lua
    --- loader.register(require 'modules/needs/needs.module.lua');
    --- ```
    ---@vararg ClientAppModule
    ---@return ClientAppContext
    function loader.register(...)
        local list <const> = { ... }; ---@type ClientAppModule[]
        local added <const> = {}; ---@type string[]
        for i = 1, #list do register(list[i]); added[#added + 1] = list[i].name; end
        wire(sorted(), true);
        logger:info("registered addon module(s): ^G%s^D", table.concat(added, ", "));
        return ctx;
    end

    --- Tear down addon modules added with `register` (the inverse). For each descriptor, in
    --- reverse order (a dependent is dropped before what it depends on): run its optional
    --- `destroy(ctx)` hook, drop its view/service from the ctx, and remove it from the
    --- registry so the same name is free to register again on a package hot-reload. Without
    --- this, reloading an addon hits the duplicate-name assert in register() and its HUD
    --- gauges / views linger in the (still-loaded) core. Call it from the addon's Package
    --- "Unload" (see NMRP.unregister). Unknown names are ignored.
    ---
    --- ```lua
    --- loader.unregister(require 'modules/needs/needs.module.lua');
    --- ```
    ---@vararg ClientAppModule
    ---@return ClientAppContext
    function loader.unregister(...)
        local list <const> = { ... }; ---@type ClientAppModule[]
        for i = #list, 1, -1 do
            local module <const> = list[i];
            local name <const> = module and module.name; ---@type string?
            if (name and modules[name]) then
                -- Guarded: on a full gamemode reload the core may already be gone, so a
                -- destroy reaching back into it (e.g. a HUD gauge) must not hard-error.
                if (booted[name] and module.destroy) then
                    local ok <const>, err <const> = pcall(module.destroy, ctx);
                    if (not ok) then logger:warn("addon module '%s' destroy failed: %s", name, tostring(err)); end
                end
                ctx.services[name] = nil;
                ctx.views[name] = nil;
                modules[name] = nil;
                booted[name] = nil;
                for j = #order, 1, -1 do
                    if (order[j] == name) then table.remove(order, j); break; end
                end
                logger:debug("unregistered addon module '^B%s^D'", name);
            end
        end
        return ctx;
    end

    return loader;
end
