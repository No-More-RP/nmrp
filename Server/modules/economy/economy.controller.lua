--- economy.controller.lua — (C) economy commands + write-behind flush wiring.
--- cash/givecash/pay are synchronous (the service buffers in RAM); only /transactions
--- hits the DB, so it runs in a coroutine. The flush timer + shutdown flush live here
--- (engine wiring); per-player flush on disconnect is handled by the service.
---
--- ```lua
--- require 'economy.controller.lua' (ctx);
--- ```
-- Required at file top-level (main thread): nanos `require` does NOT work inside a
-- coroutine, and the controller body runs inside loader.boot's coroutine.
local install_player <const> = require 'economy.player.lua'; ---@type fun(ctx: AppContext): void

---@param ctx AppContext
return function(ctx)
    local economy <const> = ctx.services.economy; ---@type EconomyService

    install_player(ctx); -- install Player:GetCash / GiveCash / TakeCash / ...

    -- Write-behind: persist buffered balances + ledger rows on an interval and on
    -- shutdown. A shorter window means less lost on a crash (money flushes faster than
    -- the player world-state autosave). Player disconnect flushes via the service hook.
    Timer.SetInterval(threadify(economy.flush), 5000 --[[ flush window (ms) ]]);
    Package.Subscribe("Unload", threadify(economy.flush));

    command({
        name = "cash",
        description = "Show your cash balance",
        callback = function(c)
            local player <const> = c.player;
            if (not player) then return; end
            Chat.SendMessage(player, ("Cash: $%d"):format(economy.cash(player)));
        end,
    });

    command({
        name = "givecash",
        description = "Give cash to a player (admin)",
        parameters = {
            { name = "target", type = "player", optional = false, description = "Target player" },
            { name = "amount", type = "number", optional = false, description = "Amount" },
        },
        callback = function(c)
            local target <const> = c.arguments.target; ---@type Player
            local amount <const> = math.floor(c.arguments.amount or 0);
            local account <const> = economy.cash_account(target);
            if (amount <= 0 or not account) then return; end
            local balance <const> = economy.deposit(account, amount, { reason = "givecash", actor = "system" });
            Chat.SendMessage(target, ("You received $%d (balance: $%d)"):format(amount, balance));
        end,
    });

    command({
        name = "pay",
        description = "Pay cash to another player",
        parameters = {
            { name = "target", type = "player", optional = false, description = "Target player" },
            { name = "amount", type = "number", optional = false, description = "Amount" },
        },
        callback = function(c)
            local player <const> = c.player;
            if (not player) then return; end
            local target <const> = c.arguments.target; ---@type Player
            local amount <const> = math.floor(c.arguments.amount or 0);
            local from <const>, to <const> = economy.cash_account(player), economy.cash_account(target);
            if (amount <= 0 or not (from and to) or from == to) then return; end
            if (economy.transfer(from, to, amount, { reason = "pay", actor = player:GetAccountID() })) then
                Chat.SendMessage(player, ("You paid $%d to %s"):format(amount, target:GetAccountID()));
                Chat.SendMessage(target, ("You received $%d"):format(amount));
            else
                Chat.SendMessage(player, "Transfer failed: insufficient funds.");
            end
        end,
    });

    command({
        name = "transactions",
        description = "Show your recent cash transactions",
        callback = function(c)
            local player <const> = c.player;
            if (not player) then return; end
            local account <const> = economy.cash_account(player);
            if (not account) then return; end
            CreateThread(function()
                local rows <const> = economy.history(account, 5);
                Chat.SendMessage(player, ("Last %d transaction(s):"):format(#rows));
                for i = 1, #rows do
                    local t <const> = rows[i];
                    local label <const> = (t.reason ~= nil and t.reason ~= "") and t.reason or "?";
                    Chat.SendMessage(player, ("  %+d (%s) -> $%d"):format(t.delta, label, t.balance_after));
                end
            end);
        end,
    });
end
