<div align="center">

# Astrix

**An in-game command console for Roblox, driven by Kyn — a bash-inspired shell language.**

**[Read the docs](https://valencerblx.github.io/Astrix/)**

</div>

---

```lua
local Astrix = require(ReplicatedStorage.Astrix)

Astrix.Define("Kick")
    :Type("Server")
    :Rank(Astrix.Enums.Rank.Admin.Min)
    :Parsed({
        { Name = "Target", Type = "Player", Required = true },
        { Name = "Reason", Type = "String", Required = false, Default = "No reason given" },
    })
    :Cooldown(3)
    :Tasks({
        Server = function(context)
            context.Parsed.Target:Kick(context.Parsed.Reason)

            return Astrix.Resolve.Ok(`kicked {context.Parsed.Target.Name}`)
        end,
    })
    :Register()

Astrix.Start()
```

One `Start` on each side. The server hosts and publishes; the client builds the
console and evaluates Kyn.

## Kyn

A command line is a grammar, not a list of words.

```
@Set("Target", @Players.Rin)
Teleport @Target @Vector3(1, 2, 3) >> echo ::Kout : Notify "done" -> Notify "failed"
```

Chains (`:` `>>` `->`), pipes (`|`), references (`@Name`), a result stack
(`::Kout`), user functions, flags, comments, and `[[ … ]]` multiline blocks.
The whole session is client-side — server commands only ever receive resolved,
typed values.

## The console

Konsole's visual language, transpiled onto [Lume](https://github.com/VALENCERBLX/Lume).
A 204×34 pill you click to open; 252 wide with the prompt showing; 338 once it
has output, then as wide as its longest line. Pill radius morphing to 12 on the
way. Pure black at 0.5 transparency.

Those numbers are Konsole's `config.luau` verbatim, not estimated.

## Install

Self-contained — Lume, Switch and Substance are vendored under
`src/_Packages`. Sync `src/` with Rojo (`default.project.json` maps it to
`ReplicatedStorage.Astrix`), or paste `dist/install.luau` into the Studio
command bar for a no-Rojo install.

## Working on it

```sh
lune run scripts/vendor           # refresh vendored Lume/Switch/Substance
lune run scripts/build-installer  # regenerate dist/install.luau
lune run scripts/Docket           # rebuild docs/index.html
```

The vendored copies are *copies*. Editing upstream Lume does nothing here until
`scripts/vendor` runs — that is the one footgun in this repo.

## Not done yet

- **Rank bands are placeholders.** `Player 0-99`, `Admin 100-199`, `Owner 200`
  was never confirmed. The place creator is granted Owner automatically so a
  solo developer is not locked out; everything else defaults to Player.
- **`Network.lua` is a RemoteFunction/RemoteEvent stand-in.** Substance is
  vendored and intended.
- **Switch is vendored but not wired.** Keybinds are raw connections, gated on
  console focus.
- **Server tasks cannot stream output** — only the returned resolve reaches the
  player.
- **Lifecycle signals** are named in the design but not implemented.
- **No mobile or touch input.**

## Credit

Forked from [Konsole](https://github.com/KYRORBLX/Konsole) by KYRORBLX —
driftingAurora, dullflowerr, alias, kioukaii. MIT, see `THIRD_PARTY_NOTICES.md`.

Part of Valence Libs, by Valence.
