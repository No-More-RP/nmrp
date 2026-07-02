--- player.service.lua: (S) player/character lifecycle, closure-factory style.
--- Wraps the player store and exposes a LOADING-PHASE hook API so other modules
--- contribute their own per-player data while a player loads.
---
--- Why hooks and not a "player:loaded" event: loading another module's data (money,
--- job, ...) must happen DURING load and be AWAITED, so everything is present before
--- the player is possessed/ready. An event named "loaded" firing that work is a
--- contradiction. So:
---   - service.on_loading(fn)   -> fn runs (awaited) WHILE loading, before ready
---   - service.on_releasing(fn) -> fn runs (awaited) before the cache is dropped
---   - bus event "player:ready" -> fire-and-forget, AFTER everything is loaded
local make_store <const> = require 'player.store.lua'; ---@type fun(models: PlayerModels): PlayerStore
local hooks <const> = require 'lib/classes/hook.lua'; ---@type HookModule

--- Build the player service.
---
--- ```lua
--- local service <const> = require 'player.service.lua' (ctx);
--- ```
---@param ctx AppContext
---@return PlayerService
return function(ctx)
    local models <const> = ctx.models.player; ---@type PlayerModels
    local events <const> = ctx.events;
    local store <const> = make_store({ players = models.players, characters = models.characters });
    local logger <const> = ctx.logger:child('Player');

    local loading <const> = hooks.Hook();   -- taps: (player, player_data, character_data)
    local releasing <const> = hooks.Hook(); -- taps: (player)

    local cache_ids <const> = {}; ---@type table<integer, Player> -- db_id -> player
    local cache_account_ids <const> = {}; ---@type table<string, Player> -- account_id -> player

    ---@class PlayerService
    local service <const> = {}; ---@type PlayerService
    service.store = store; -- exposed for modules that want the cached records directly
    service.logger = logger; -- exposed for modules that want to log player lifecycle events

    --- Register a loader run (and awaited) while a player loads, before they're ready.
    ---
    --- ```lua
    --- players.on_loading(function(player, player_data) load_account(player_data.id); end);
    --- ```
    ---@param fn fun(player: Player, player_data: NormRecord, character_data: NormRecord)
    function service.on_loading(fn) loading:tap(fn); return service; end

    --- Register a finalizer run (and awaited) before the player's cache is dropped.
    ---
    --- ```lua
    --- players.on_releasing(function(player) save_account(player); end);
    --- ```
    ---@param fn fun(player: Player)
    function service.on_releasing(fn) releasing:tap(fn); return service; end

    --- Load (or create) a player's rows, run every loading hook (awaited, so all
    --- per-player data is present), register the player, then announce readiness.
    --- Coroutine-only.
    ---
    --- ```lua
    --- local player_data <const>, character_data <const> = players.load(player, { model = mesh });
    --- ```
    ---@async
    ---@param player Player
    ---@param defaults table? Seed values for the character row on first creation
    ---@return NormRecord player_data, NormRecord character_data
    function service.load(player, defaults)
        local account_id <const> = player:GetAccountID();
        local player_data <const>, character_data <const> = store.load(player, account_id, defaults);
        player.db_id = player_data.id;
        loading:call(player, player_data, character_data); -- awaited: all per-player data ready
        cache_ids[player_data.id] = player;
        cache_account_ids[account_id] = player;
        events:emit("player:ready", player, player_data, character_data); -- fire-and-forget (HUD, ...)
        return player_data, character_data;
    end

    --- Run releasing hooks (awaited), then final-save + drop the cache. Coroutine-only.
    ---
    --- ```lua
    --- players.release(player); -- on disconnect
    --- ```
    ---@async
    ---@param player Player
    function service.release(player)
        releasing:call(player); -- awaited: modules persist before we drop the cache
        store.release(player);
        local account_id <const> = player:GetAccountID();
        local character <const> = player:GetControlledCharacter();
        if (character and character:IsValid()) then character:Destroy(); end
        cache_ids[player.db_id] = nil;
        cache_account_ids[account_id] = nil;
    end

    --- Save every online player (autosave). Coroutine-only. Returns the count.
    ---
    --- ```lua
    --- local n <const> = players.save_all(); -- e.g. 12
    --- ```
    ---@async
    ---@return integer
    function service.save_all() return store.save_all(); end

    --- Lookup a player by their database ID.
    ---
    --- ```lua
    --- local players <const> = ctx.services.player;
    --- local player <const> = players.get(db_id);
    --- ```
    ---@param db_id integer
    ---@return Player|nil
    function service.get(db_id) return cache_ids[db_id]; end

    --- Lookup a player by their account ID.
    ---
    --- ```lua
    --- local players <const> = ctx.services.player;
    --- local player <const> = players.get_by_account(account_id);
    --- ```
    ---@param account_id string
    ---@return Player|nil
    function service.get_by_account(account_id) return cache_account_ids[account_id]; end

    return service;
end
