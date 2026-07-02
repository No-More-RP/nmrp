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
---@alias ClientAppModule { name: string, depends?: string[], view?: fun(ctx: ClientAppContext): any, service?: fun(ctx: ClientAppContext): any, controller?: fun(ctx: ClientAppContext): void }

---@param ctx ClientAppContext
---@return { boot: fun(...: ClientAppModule): ClientAppContext }
return function(ctx)
    local modules <const> = {}; ---@type table<string, ClientAppModule> name -> descriptor
    local order <const> = {};   ---@type string[] registration order (tie-break)

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

    local loader <const> = {};

    --- Register every module, then boot them in dependency order: views first (into
    --- ctx.views[name]), services second (ctx.services[name]), controllers last.
    ---
    --- ```lua
    --- loader.boot(player_module, hud_module, stamina_module);
    --- ```
    ---@vararg ClientAppModule
    ---@return ClientAppContext
    function loader.boot(...)
        local list <const> = { ... }; ---@type ClientAppModule[]
        for i = 1, #list do register(list[i]); end
        local names <const> = sorted();

        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (module.view) then ctx.views[module.name] = module.view(ctx); end
        end
        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (module.service) then ctx.services[module.name] = module.service(ctx); end
        end
        for i = 1, #names do
            local module <const> = modules[names[i]];
            if (module.controller) then module.controller(ctx); end
        end

        ctx.logger:info("booted ^G%d^D module(s)", #names);
        return ctx;
    end

    return loader;
end
