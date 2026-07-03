# NMRP: No More RP

An **open-source roleplay gamemode base for [nanos world](https://nanos.world)**, written
in Lua. NMRP gives server creators a clean, modular foundation (object-oriented **MVC**
wired by a **loader + dependency-injection registry**), so you spend your time on your
gamemode instead of on plumbing.

It is built on the [No More RP](https://github.com/No-More-RP) package ecosystem:

| Package | Role |
|---|---|
| [`nmrp-promise`](https://github.com/No-More-RP/nmrp-promise) | JS-grade promises (`async`/`await`, combinators). |
| [`nmrp-norm`](https://github.com/No-More-RP/nmrp-norm) | Server-side ORM (Norm): models, relations, migrations. |
| [`nmrp-rpc`](https://github.com/No-More-RP/nmrp-rpc) | Promise-based RPC across server and client. |
| [`nmrp-locale`](https://github.com/No-More-RP/nmrp-locale) | Shared localization (i18n) for Lua + WebUI. |

The client UI is built with **Svelte + WebUI** (see [`UI/`](UI/)).

## Installation

This is a **game-mode** package. It declares its dependencies in `Package.toml`:

```toml
[game_mode]
    packages_requirements = [
        "nmrp-promise",
        "nmrp-norm",
        "nmrp-rpc",
        "nmrp-locale",
    ]
```

Make sure those packages exist in your server's `Packages/` folder, then start the
gamemode. The database connection is configured through the game-mode custom setting
`database` (new-game menu, `Config.toml`, or the server command line).

## Architecture

### Realms

- **`Server/`**: authority, database, business logic.
- **`Client/`**: UI (WebUI / Svelte), input, rendering.
- **`Shared/`**: code loaded into **both** VMs (lib, classes, helpers, globals).

### Bootstrap

- `Server/Index.lua` and `Client/Index.lua` contain **only** `require 'app.lua';`.
- `Server/app.lua` builds the DB + the `ctx` container, then `loader.boot(mod1, mod2, ...)`.
- `Client/app.lua` mounts the WebUI + views + network/input wiring.

### MVC + DI (server side)

A **module** is a folder `Server/modules/<name>/` exposing a descriptor
(`<name>.module.lua`). The loader wires it in three passes over the topological order of
`depends`:

| Layer | File | Role |
|---|---|---|
| **Model** | `<name>.model.lua` | `fun(db): models`, defines the Norm tables, returns the models. |
| **Service** | `<name>.service.lua` | `fun(ctx): service`, business logic (closure-factory), stored in `ctx.services[name]`. |
| **Controller** | `<name>.controller.lua` | `fun(ctx): void`, wires the engine: commands, `Events`, `Timer`, `Player.Subscribe`. |
| **Store** (optional) | `<name>.store.lua` | in-memory repository / cache. |

`ctx` (`AppContext`) is the injection container: `{ db, models, services, config, events }`.
A service reaches others through `ctx.services.x` (and declares `depends = { "x" }`).

> **Layer rule**: the **controller** owns everything that touches the engine (timers,
> subscriptions, inbound RPC, commands); the **service** is logic + lifecycle hooks.

The reference module is [`Server/modules/player`](Server/modules/player).

## Add a module

1. Create `Server/modules/<name>/` with `<name>.module.lua` (+ `model` / `service` /
   `controller` as needed).
2. Write requires **relative to the folder** and type them by hand (nanos resolves
   `require` per caller directory; paths end with `.lua`).
3. `service` is a closure-factory; the `controller` wires the engine; use the lifecycle
   hooks on `ctx.services.player`.
4. Declare `depends` if the module relies on another.
5. Add the module to `loader.boot(...)` in `Server/app.lua`.

A module with no persistence (runtime state only) has no `model`.

## Conventions

All new code follows the same conventions: English-only comments, `;`-terminated
statements, `<const>` on every non-reassigned local, parenthesized conditions, full
LuaCATS annotations, and an example on every public function. No user-facing string is
hardcoded, everything goes through `nmrp-locale`.

## Contributing

Contributions are welcome. Pick a task, follow the conventions above, and open a pull
request against the relevant repository.

## License

[MIT](LICENSE) © 2026 JustGod.
