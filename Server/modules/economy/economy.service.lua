--- economy.service.lua: (S) account & ledger logic, closure-factory style.
---
--- Accounts are polymorphic (owner_type + owner_id), so the same code serves
--- characters, companies and factions. Personal money is the character's "cash"
--- account (created on character load); there is no cash/bank column on the player.
---
--- WRITE-BEHIND persistence. deposit/withdraw/transfer mutate the cached record in RAM
--- and BUFFER the change (a dirty account + a pending ledger row), they do NOT touch
--- the DB, so they are synchronous and cheap. flush() later writes everything:
---   - balances COALESCE (a dirty account is one UPDATE no matter how many ops hit it),
---   - ledger rows BATCH (each event is a distinct fact), all put in flight then awaited
---     together (parallel round-trips, like player.store.save_all).
--- The ledger is the source of truth and the balance is a projection, so a crash before
--- a flush loses the same tail of both → they stay consistent, only a small window is
--- lost. flush() runs on a timer + on player release + on shutdown (wired in the
--- controller / release hook), and is public so a caller can force durability on a
--- critical operation.
---
--- Assumes ONE record instance per account (cash accounts are cached singletons); do
--- not load the same account twice and mutate both copies.
---
--- nanos' built-in adapter has no SQL transactions; a transfer is two buffered UPDATEs.
--- A crash before flush loses both legs together (consistent); the norm-database native
--- connector adds real transactions when atomicity is required.
---
---@alias TxOptions { reason?: string, actor?: string, counterparty?: integer }
---@class EconomyService
---@field cash fun(player: Player): integer
---@field cash_account fun(player: Player): NormRecord|nil
---@field accounts_of fun(owner_type: string, owner_id: integer): NormRecord[]
---@field open_account fun(owner_type: string, owner_id: integer, account_type: string, label: string?): NormRecord
---@field balance fun(account: NormRecord?): integer
---@field deposit fun(account: NormRecord, amount: integer, opts: TxOptions?): integer
---@field withdraw fun(account: NormRecord, amount: integer, opts: TxOptions?): boolean
---@field transfer fun(from: NormRecord, to: NormRecord, amount: integer, opts: TxOptions?): boolean
---@field history fun(account: NormRecord, limit: integer?): NormRecord[]
---@field flush fun(): integer

--- Build the economy service.
---
--- ```lua
--- local service <const> = require 'economy.service.lua' (ctx);
--- ```
---@param ctx AppContext
---@return EconomyService
return function(ctx)
    local models <const> = ctx.models.economy; ---@type EconomyModels
    local Accounts <const> = models.accounts;
    local Transactions <const> = models.transactions;
    local players <const> = ctx.services.player; ---@type PlayerService

    local OWNER_CHARACTER <const> = "character";
    local TYPE_CASH <const> = "cash";

    -- Cached cash account per online player (owner = their character): fast reads, and a
    -- stable record instance shared by deposit/withdraw/transfer.
    local cash_accounts <const> = {}; ---@type table<Player, NormRecord>

    -- Write-behind buffers (reassigned on flush, so not <const>):
    --   dirty: account id -> record (deduped -> coalesced balance writes)
    --   pending_tx: ordered ledger rows to insert
    local dirty = {};      ---@type table<integer, NormRecord>
    local pending_tx = {}; ---@type table[]

    -- Frozen guard. Norm may decode booleans as 0/1, and 0 is truthy in Lua, so test
    -- explicitly rather than `if (account.frozen)`.
    local function is_frozen(account) return account.frozen == true or account.frozen == 1; end

    -- Mark an account's balance as needing a write, and buffer one ledger row for the
    -- change (balance_after is read now, after the in-RAM mutation).
    local function record(account, delta, opts)
        dirty[account.id] = account;
        pending_tx[#pending_tx + 1] = {
            account_id      = account.id,
            delta           = delta,
            balance_after   = account.balance,
            reason          = opts.reason or "",
            counterparty_id = opts.counterparty,
            actor           = opts.actor,
        };
    end

    local service <const> = {}; ---@type EconomyService

    --- Current cash on hand for a player (0 if offline / no cash account cached).
    ---
    --- ```lua
    --- local n <const> = economy.cash(player); -- 1540
    --- ```
    ---@param player Player
    ---@return integer
    function service.cash(player)
        local acc <const> = cash_accounts[player];
        return acc and acc.balance or 0;
    end

    --- The player's cached cash account record (or nil if offline).
    ---
    --- ```lua
    --- local account <const> = economy.cash_account(player);
    --- ```
    ---@param player Player
    ---@return NormRecord|nil
    function service.cash_account(player) return cash_accounts[player]; end

    --- Balance of any account.
    ---
    --- ```lua
    --- local n <const> = economy.balance(account);
    --- ```
    ---@param account NormRecord
    ---@return integer
    function service.balance(account) return account.balance; end

    --- All accounts owned by an entity. Hits the DB, coroutine-only.
    ---
    --- ```lua
    --- local accounts <const> = economy.accounts_of("character", character.id);
    --- ```
    ---@async
    ---@param owner_type string
    ---@param owner_id integer
    ---@return NormRecord[]
    function service.accounts_of(owner_type, owner_id)
        return Accounts:where("owner_type", "=", owner_type):where("owner_id", "=", owner_id):all():await();
    end

    --- Open a new account for an owner. Hits the DB, coroutine-only.
    ---
    --- ```lua
    --- local savings <const> = economy.open_account("character", character.id, "savings", "Main savings");
    --- ```
    ---@async
    ---@param owner_type string
    ---@param owner_id integer
    ---@param account_type string
    ---@param label string?
    ---@return NormRecord
    function service.open_account(owner_type, owner_id, account_type, label)
        return Accounts:create({
            owner_type = owner_type,
            owner_id   = owner_id,
            type       = account_type,
            balance    = 0,
            label      = label,
        }):await();
    end

    --- Credit an account and buffer the change. Synchronous (no DB until flush).
    --- Returns the new balance.
    ---
    --- ```lua
    --- local balance <const> = economy.deposit(account, 500, { reason = "salary" }); -- 2040
    --- ```
    ---@param account NormRecord
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return integer balance
    function service.deposit(account, amount, opts)
        assert(amount >= 0, "economy.deposit: amount must be >= 0");
        account.balance = account.balance + amount;
        record(account, amount, opts or {});
        return account.balance;
    end

    --- Debit an account if it is not frozen and has the funds, then buffer the change.
    --- Synchronous (no DB until flush). Returns true on success.
    ---
    --- ```lua
    --- if (economy.withdraw(account, 250, { reason = "shop" })) then give_item(); end
    --- ```
    ---@param account NormRecord
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return boolean ok
    function service.withdraw(account, amount, opts)
        assert(amount >= 0, "economy.withdraw: amount must be >= 0");
        if (is_frozen(account) or account.balance < amount) then return false; end
        account.balance = account.balance - amount;
        record(account, -amount, opts or {});
        return true;
    end

    --- Move money between two accounts (debit `from`, credit `to`), buffering both legs
    --- with each other as counterparty. Synchronous. Returns false if `from` is frozen
    --- or short.
    ---
    --- ```lua
    --- economy.transfer(from, to, 1000, { reason = "pay", actor = player:GetAccountID() });
    --- ```
    ---@param from NormRecord
    ---@param to NormRecord
    ---@param amount integer
    ---@param opts TxOptions?
    ---@return boolean ok
    function service.transfer(from, to, amount, opts)
        assert(amount >= 0, "economy.transfer: amount must be >= 0");
        if (is_frozen(from) or from.balance < amount) then return false; end
        opts = opts or {};
        from.balance = from.balance - amount;
        to.balance = to.balance + amount;
        record(from, -amount, { reason = opts.reason, actor = opts.actor, counterparty = to.id });
        record(to, amount, { reason = opts.reason, actor = opts.actor, counterparty = from.id });
        return true;
    end

    --- Recent ledger rows for an account, newest first. Hits the DB, coroutine-only.
    --- Rows still buffered (not yet flushed) are not included.
    ---
    --- ```lua
    --- local rows <const> = economy.history(account, 10);
    --- ```
    ---@async
    ---@param account NormRecord
    ---@param limit integer?
    ---@return NormRecord[]
    function service.history(account, limit)
        return Transactions:where("account_id", "=", account.id):order("id", "DESC"):limit(limit or 20):all():await();
    end

    --- Flush the write-behind buffer: snapshot it, then write every dirty account and
    --- every buffered ledger row in parallel (all in flight, then await). Returns the
    --- number of ledger rows written. Coroutine-only. Snapshots before awaiting, so
    --- mutations made during the flush land in the next batch.
    ---
    --- ```lua
    --- economy.flush(); -- force durability after a critical operation
    --- ```
    ---@async
    ---@return integer written
    function service.flush()
        if (next(dirty) == nil and pending_tx[1] == nil) then return 0; end
        local accounts <const> = dirty;
        local txs <const> = pending_tx;
        dirty = {};
        pending_tx = {};

        local promises <const> = {}; ---@type NormPromise[]
        for _, account in pairs(accounts) do
            promises[#promises + 1] = account:save();
        end
        for i = 1, #txs do
            promises[#promises + 1] = Transactions:create(txs[i]);
        end
        Promise.all(promises):await();
        return #txs;
    end

    -- Lifecycle: ensure/cache the character's cash account on load (owner = the
    -- character, not the player account); flush then drop on release so the leaving
    -- player's buffered money is persisted.
    players.on_loading(function(player, player_data, character_data)
        cash_accounts[player] = Accounts:find_or_create(
            { owner_type = OWNER_CHARACTER, owner_id = character_data.id, type = TYPE_CASH },
            { balance = 0 }
        ):await();
    end);
    players.on_releasing(function(player)
        service.flush();
        cash_accounts[player] = nil;
    end);

    return service;
end
