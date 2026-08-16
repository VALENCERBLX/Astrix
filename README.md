# Astrix

An in-game command console for Roblox, driven by **Kyn** — a bash-inspired
shell language.

Forked from [Konsole](https://github.com/KYRORBLX/Konsole) (MIT) as its engine
foundation, rendered through [Lume](https://github.com/VALENCERBLX/Lume), and
rebuilt around a real grammar instead of a token splitter.

```lua
local Astrix = require(ReplicatedStorage.Astrix)

Astrix.Define("Kick")
    :Type("Server")
    :Rank(Astrix.Enums.Rank.Admin.Min)
    :Describe("Removes a player from the server")
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
@Function Greet {
    return "Hi"
}

@Set("Target", @Players.Rin)
Teleport @Target @Vector3(1, 2, 3) >> echo ::Kout : Notify "done" -> Notify "failed"
```

| | |
|---|---|
| `@Name` | a reference — variable, function, or namespaced lookup |
| `@Players.Rin` | the only way to name a player |
| `@Vector3(1, 2, 3)` | type constructor |
| `@Set("Name", Value)` | assignment; the name must be quoted |
| `@Function Name { return … }` | define; `@Name()` calls it, `@Name` is its value |
| `::Kout`, `::Kout(n)` | the last result, or `n` steps further back |
| `--Flag`, `--Flag=Value` | boolean and valued flags |
| `:` `>>` `->` | chain always / on success / on failure |
| `\|` | pipe the previous result in as the first argument |
| `#` | comment to end of line |

The `::Kout` stack keeps the last 50 results per session. Recursion is capped at
10 and returns a failure rather than overflowing. Names registered through
`Astrix.Native` are **absolute** — redefining one is refused.

**The entire session is client-side.** `Server` and `Service` commands never
receive raw Kyn, only already-resolved typed values.

## Commands

Three types. `Local` runs on the client, `Server` on the server, `Service` runs
both — the server first and authoritative by default, or `:LocalFirst(true)` to
run the client first for instant feedback and hand its result to the server.

Definitions replicate **schema-only**: a server command's name, arguments,
flags, rank and cooldown reach the client so autocomplete works, while the
function that does the work never leaves the server.

## The console

Konsole's visual language, unchanged: a collapsed 204×34 pill at the bottom of
the screen that expands upward as output accumulates, morphing from pill to a
12px rounded rectangle on the way, on a pure-black surface at 0.5 transparency.

Those numbers, and the greys, motion durations and sizes in `_Themes/Default`,
are Konsole's `config.luau` verbatim rather than approximated.

What Astrix adds on top is one layer of brand colour — `Accent` is its own
top-level token group, used on the mark, the prompt glyph, the focus ring and
the active suggestion — plus `Syntax` tokens, since Konsole had no language to
highlight and Kyn does.

Windows are an arbitrary list rather than Konsole's hardcoded two channels.
`ctx.Windows:Open(…)` lets a command spawn its own panel.

## Install

```toml
# wally.toml
[dependencies]
Astrix = "valence/astrix@0.1.0"
Lume = "kr3ative/lume@0.1.0"
```

Or drop `src/` in as a ModuleScript tree — requires are real instance requires,
so no build step is involved.

There is also a no-Rojo path: paste `dist/install.luau` into the Studio command
bar. Regenerate it with `lune run scripts/build-installer` after changing
`src/`.

## Not done yet

Honest list, so nothing reads as finished when it is not:

- **Rank bands are placeholders.** `Player 0-99`, `Admin 100-199`, `Owner 200`
  was never confirmed. Changing them later silently changes who can run what.
- **`Network.lua` is a RemoteFunction/RemoteEvent stand-in.** Substance is the
  intended transport; the surface is already the shape Substance would give, so
  it is a change in one file.
- **Switch is not wired.** Keybinds are raw `UserInputService` connections.
  They are the set that moves onto an `"AstrixConsole"` context so they go
  quiet when the console is closed.
- **Server tasks cannot stream output.** `ctx.Output.Reply/Error/Success` are
  no-ops on the server; only the returned resolve reaches the player.
- **Lifecycle signals** (`PreExecute`, `PostExecute`, `PreSend`, `PostSend`,
  `Runtime`, `Fail`) are named in the design but not implemented.
- **`Window:VisibleLineRange` is unused.** Lume's list is already virtualised,
  so only on-screen rows become instances; what is not skipped yet is rebuilding
  the item array.
- **One theme.** The registry takes more; none has been designed.
- **No mobile or touch input.** Out of scope for v1.
- **No `Server` or `Service` example commands in `_Commands/`.** Both shapes are
  demonstrated in `examples/ServerStartup.lua` instead.

## Credit

Konsole by KYRORBLX — driftingAurora, dullflowerr, alias, kioukaii. MIT, see
`THIRD_PARTY_NOTICES.md`.

Part of Valence Libs, by Valence.
