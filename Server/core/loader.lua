--- loader.lua: module loader / registry. This is the decorator-free replacement
--- for a DI framework: each feature module returns a descriptor instead of using
--- an `@Module` decorator, and the loader wires everything by hand, explicitly.
---
--- A module descriptor (see modules/<name>/<name>.module.lua):
---   {
---     name       = "money",
---     depends    = { "player" },     -- optional; resolved by topological order
---     models     = fun(db): table,   -- (M) define Norm tables, return them
---     service    = fun(ctx): table,  -- (S) build business logic, gets injected into ctx
---     controller = fun(ctx): void,   -- (C) wire commands / events, reads ctx.services
---   }
---
--- boot() runs in THREE passes over the dependency-sorted modules, so every table
--- exists before any service queries it, and every service exists before any
--- controller calls it:
---   1. models     -> ctx.models[name]   = mod.models(db)
---   2. services   -> ctx.services[name] = mod.service(ctx)
---   3. controllers-> mod.controller(ctx)
---
---@class AppModule
---@field name string
---@field depends? string[]
---@field models? fun(db: NormOrm): any
---@field service? fun(ctx: AppContext): any
---@field controller? fun(ctx: AppContext): void

--- Build a loader bound to an app context.
---
--- ```lua
--- local loader <const> = require 'core/loader.lua' (ctx);
--- loader.boot(player_module, money_module);
--- ```
---@param ctx AppContext The app container (DI root): db, models, services, config, events
---@return Loader
return function(ctx)
    ---@class Loader
    local loader <const> = {};
    local modules <const> = {}; ---@type table<string, AppModule> name -> descriptor
    local order <const> = {};   ---@type string[] registration order (tie-break)
    local booted <const> = {};  ---@type table<string, boolean> name -> wired (its 3 passes ran)
    local boot_lock = false;    ---@type boolean

    local logger <const> = ctx.logger:child('Loader');

    --- Register a module descriptor. Duplicates are a hard error.
    ---
    --- ```lua
    --- register(player_module);
    --- ```
    ---@param mod AppModule
    local function register(mod)
        assert(mod and mod.name, "loader.register: a module needs a name");
        assert(not modules[mod.name], ("loader.register: duplicate module '%s'"):format(mod.name));
        modules[mod.name] = mod;
        order[#order + 1] = mod.name;
        return loader;
    end

    --- Depth-first topological sort over `depends`. Registration order breaks ties,
    --- so the boot sequence is deterministic. Raises on cycles and unknown deps.
    ---
    --- ```lua
    --- local sorted <const> = resolve_order(); -- AppModule[] in dependency order
    --- ```
    ---@return AppModule[]
    local function resolve_order()
        local sorted <const> = {};
        local state <const> = {}; ---@type table<string, boolean> true=done, false=visiting

        local function visit(name, trail)
            if (state[name] == true) then return; end
            if (state[name] == false) then
                error(("loader: dependency cycle: %s -> %s"):format(table.concat(trail, " -> "), name));
            end
            local mod <const> = modules[name];
            assert(mod, ("loader: '%s' depends on unknown module '%s'"):format(trail[#trail] or "?", name));
            state[name] = false;
            local deps <const> = mod.depends or {};
            for i = 1, #deps do
                trail[#trail + 1] = name;
                visit(deps[i], trail);
                trail[#trail] = nil;
            end
            state[name] = true;
            sorted[#sorted + 1] = mod;
        end

        for i = 1, #order do visit(order[i], {}); end
        return sorted;
    end

    --- Run the model -> service -> controller passes over `list` (already dependency
    --- sorted), skipping any module already wired, then mark the new ones wired. Does not
    --- sync the db: the caller does that once, after wiring.
    ---
    --- ```lua
    --- wire(resolve_order());
    --- ```
    ---@param list AppModule[]
    ---@param is_addon boolean
    ---@return void
    local function wire(list, is_addon)
        for i = 1, #list do
            local mod <const> = list[i];
            if (not booted[mod.name] and mod.models) then ctx.models[mod.name] = mod.models(ctx.db); end
        end
        for i = 1, #list do
            local mod <const> = list[i];
            if (not booted[mod.name] and mod.service) then ctx.services[mod.name] = mod.service(ctx); end
        end
        for i = 1, #list do
            local mod <const> = list[i];
            if (not booted[mod.name] and mod.controller) then mod.controller(ctx); end
        end
        for i = 1, #list do
            if (not booted[list[i].name]) then
                logger:debug("started %smodule '^B%s^D'", is_addon and "addon " or "", list[i].name);
                booted[list[i].name] = true;
            end
        end
    end

    --- Register the given (core) modules, then build the whole app: models, then services,
    --- then controllers, in dependency order, and finally sync the schema.
    ---
    --- ```lua
    --- loader.boot(player_module, money_module, stamina_module);
    --- ```
    ---@async
    ---@vararg AppModule
    ---@return AppContext ctx
    function loader.boot(...)
        if (boot_lock) then error("loader: boot() already called"); end
        boot_lock = true;
        for i = 1, select("#", ...) do register(select(i, ...)); end
        local sorted <const> = resolve_order();
        wire(sorted, false);
        ctx.db:sync():await();
        logger:success("started ^G%d^D module(s)", #sorted);
        return ctx;
    end

    --- Late-register addon modules AFTER boot. Their descriptors join the graph, only the
    --- new ones are wired (they may depend on already-booted core modules), then the schema
    --- is synced so any new tables are created. Must run in a coroutine (it awaits the sync).
    ---
    --- ```lua
    --- loader.register(require 'modules/needs/needs.module.lua');
    --- ```
    ---@async
    ---@vararg AppModule
    ---@return AppContext ctx
    function loader.register(...)
        local names <const> = {}; ---@type string[]
        for i = 1, select("#", ...) do
            local mod <const> = select(i, ...);
            register(mod);
            names[#names + 1] = mod.name;
        end
        wire(resolve_order(), true);
        ctx.db:sync():await();
        logger:info("registered addon module(s): ^G%s^D", table.concat(names, ", "));
        return ctx;
    end

    return loader;
end
