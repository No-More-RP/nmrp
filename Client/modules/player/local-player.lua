local subscribe <const>, unsubscribe <const> = Client.Subscribe, Client.Unsubscribe;

--- local-player.lua: resolve the client's local Player, whatever the timing. In nanos the
--- local player is a mess: it does not exist yet at the first script boot but already
--- exists on a package reload, and Player.Subscribe on the CLASS fires for EVERY player.
--- This returns a Promise that resolves with the local Player exactly once (immediately if
--- it already exists, otherwise on SpawnLocalPlayer), so callers await it and subscribe to
--- its INSTANCE events only.
---
--- ```lua
--- async(function()
---     local player <const> = local_player():await();
---     player:Subscribe("Possess", function(self, pawn) ... end);
--- end);
--- ```
---@return Promise
return function()
    local existing <const> = Client.GetLocalPlayer();
    if (existing) then return Promise.resolve(existing); end

    local promise <const> = Promise();
    ---@param player Player
    local function on_spawn(player)
        unsubscribe("SpawnLocalPlayer", on_spawn);
        promise:resolve(player);
    end
    subscribe("SpawnLocalPlayer", on_spawn);
    return promise;
end
