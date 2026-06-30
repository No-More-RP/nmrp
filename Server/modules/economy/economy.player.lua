--- economy.player.lua — installs cash-account convenience methods on the nanos `Player`
--- class, delegating to the economy service. Defined HERE (not in the player module)
--- because the player module must not depend on economy — economy depends on player.
--- The methods still live on the global Player, so `player:GetCash()` works everywhere.
--- Installed from economy.controller (the service exists by the controller pass).
---
--- ```lua
--- require 'economy.player.lua' (ctx);
--- ```
---@param ctx AppContext
return function(ctx)
    local economy <const> = ctx.services.economy; ---@type EconomyService

    --- This player's cash account record (nil if offline).
    ---
    --- ```lua
    --- local account <const> = player:GetCashAccount();
    --- ```
    ---@return NormRecord|nil
    function Player:GetCashAccount() return economy.cash_account(self); end

    --- This player's current cash on hand (0 if offline).
    ---
    --- ```lua
    --- local n <const> = player:GetCash(); -- 1540
    --- ```
    ---@return integer
    function Player:GetCash() return economy.cash(self); end

    --- Credit this player's cash. Returns the new balance (0 if no cash account).
    ---
    --- ```lua
    --- player:GiveCash(500, { reason = "salary" });
    --- ```
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return integer balance
    function Player:GiveCash(amount, opts)
        local account <const> = economy.cash_account(self);
        return account and economy.deposit(account, amount, opts) or 0;
    end

    --- Debit this player's cash if it has the funds. Returns true on success.
    ---
    --- ```lua
    --- if (player:TakeCash(250, { reason = "shop" })) then give_item(); end
    --- ```
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return boolean ok
    function Player:TakeCash(amount, opts)
        local account <const> = economy.cash_account(self);
        return account ~= nil and economy.withdraw(account, amount, opts);
    end

    --- Pay cash from this player to another player. Returns true on success.
    ---
    --- ```lua
    --- player:PayCash(target, 1000, { reason = "deal" });
    --- ```
    ---@param target Player
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return boolean ok
    function Player:PayCash(target, amount, opts)
        local from <const>, to <const> = economy.cash_account(self), economy.cash_account(target);
        if (not (from and to)) then return false; end
        return economy.transfer(from, to, amount, opts);
    end

    --- Recent cash transactions for this player. Hits the DB, coroutine-only.
    ---
    --- ```lua
    --- local rows <const> = player:CashHistory(10);
    --- ```
    ---@async
    ---@param limit integer?
    ---@return NormRecord[]
    function Player:CashHistory(limit)
        local account <const> = economy.cash_account(self);
        return account and economy.history(account, limit) or {};
    end
end
