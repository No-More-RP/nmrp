--- economy.model.lua: (M) the account ledger. `accounts` is polymorphic: an account
--- is owned by some entity (owner_type + owner_id), so the same table serves
--- characters, companies and factions, with any number of accounts per owner and any
--- `type`. Personal money is just an account of type "cash" owned by the character,
--- there is no cash/bank column on the player. `account_transactions` is the immutable
--- ledger (one row per balance change, ordered by id; created_at from the DB clock).
---
--- ```lua
--- local models <const> = require 'economy.model.lua' (db); -- { accounts, transactions }
--- ```
---@alias EconomyModels { accounts: NormModel, transactions: NormModel }
---@param db NormOrm
---@return EconomyModels
return function(db)
    local accounts <const> = db:define("accounts", {
        id         = Norm.types.id(),
        owner_type = Norm.types.string({ length = 32, nullable = false }), -- "character" | "company" | "faction"
        owner_id   = Norm.types.integer({ nullable = false }),
        type       = Norm.types.string({ length = 32, nullable = false }), -- "cash" | "checking" | "savings" | "offshore" | ...
        balance    = Norm.types.bigint({ default = 0 }),
        label      = Norm.types.string({ length = 64, nullable = true }),
        frozen     = Norm.types.boolean({ default = false }),
    });

    local transactions <const> = db:define("account_transactions", {
        id              = Norm.types.id(),
        account_id      = Norm.types.integer({ nullable = false }),
        delta           = Norm.types.bigint({ nullable = false }),        -- signed: + credit, - debit
        balance_after   = Norm.types.bigint({ nullable = false }),
        reason          = Norm.types.string({ length = 64, default = "" }),
        counterparty_id = Norm.types.integer({ nullable = true }),        -- the other account in a transfer
        actor           = Norm.types.string({ length = 64, nullable = true }), -- who initiated (accountId / "system")
        created_at      = Norm.types.datetime({ default = Norm.types.raw("CURRENT_TIMESTAMP") }),
        account         = Norm.types.belongsTo("accounts", { key = "account_id", onDelete = "CASCADE" }),
    });

    return { accounts = accounts, transactions = transactions };
end
