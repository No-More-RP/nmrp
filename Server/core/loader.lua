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
---@alias ServerSetting { label: string, type: 'boolean' | 'text' | 'floating' | 'integer' | 'select', default: any, description?: string } | string
---@alias AppModule { name: string, depends?: string[], models?: fun(db: NormOrm): any, service?: fun(ctx: AppContext): any, controller?: fun(ctx: AppContext): void }
---@alias AppContext { db: NormOrm, models: table<string, any>, services: table<string, any>, config: table, events: EventEmitter, settings: table<string, ServerSetting> }
---@alias Loader { boot: fun(...: AppModule): AppContext }

--- Build a loader bound to an app context.
---
--- ```lua
--- local loader <const> = require 'core/loader.lua' (ctx);
--- loader.boot(player_module, money_module);
--- ```
---@param ctx AppContext The app container (DI root): db, models, services, config, events
---@return Loader
return function(ctx)
    local loader <const> = {};
    local modules <const> = {}; ---@type table<string, AppModule> name -> descriptor
    local order <const> = {};   ---@type string[] registration order (tie-break)

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

    --- Register the given modules, then build the whole app: models, then services,
    --- then controllers, in dependency order.
    ---
    --- ```lua
    --- loader.boot(player_module, money_module, stamina_module);
    --- ```
    ---@async
    ---@vararg AppModule
    ---@return AppContext ctx
    function loader.boot(...)
        for i = 1, select("#", ...) do
            local mod <const> = select(i, ...);
            register(mod);
        end
        local sorted <const> = resolve_order();

        for i = 1, #sorted do
            local mod <const> = sorted[i];
            if (mod.models) then ctx.models[mod.name] = mod.models(ctx.db); end
        end
        for i = 1, #sorted do
            local mod <const> = sorted[i];
            if (mod.service) then ctx.services[mod.name] = mod.service(ctx); end
        end
        for i = 1, #sorted do
            local mod <const> = sorted[i];
            if (mod.controller) then mod.controller(ctx); end
        end

        ctx.db:sync():await();

        Console.Log("[nmrp] loader: booted %d module(s)", #sorted);
        return ctx;
    end

    return loader;
end
