# Configuration

Everything `Astrix.Start` accepts. All of it optional — the defaults are the
console's own numbers, taken from Konsole's `config.luau`.

```lua
Astrix.Start({
    Interface = {
        Theme = "Default",              -- Default | Tokyonight, or your own
        Keybind = Enum.KeyCode.T,       -- the activation key
        InterfaceRank = 0,              -- below this the console will not open
        CycleTimeout = 1.5,             -- window-cycling window, 0 disables
        MaxWindows = 3,
        Placeholder = "type a command...",
        Prompt = ">",
        Anchor = "bottom",
        DisplayOrder = 8241,
        HistoryLimit = 500,             -- scrollback per window, in lines
        RecallLimit = 100,              -- lines the up-arrow remembers
        StartOpen = true,
    },

    Suggestions = {
        Enabled = true,
        Limit = 5,
    },

    Toast = {
        Enabled = true,
        Anchor = "bottomRight",
        Duration = 5,
        Max = 4,
        Gap = 8,
        Width = 320,
    },

    Kyn = {
        StackLimit = 50,                -- results ::Kout remembers
        MaxDepth = 10,                  -- @Function recursion before it fails
    },

    Rank = {
        Resolver = nil,                 -- answer from your own store
        Default = 0,
        OwnerIsCreator = true,          -- place creator is Owner automatically
    },

    Commands = {
        Builtins = true,                -- register the 26 built-ins
    },
})
```

## Notes on the ones that bite

**`Keybind`** is watched even while a console field has focus, so it acts as
the activation key rather than as a character. Pick one you do not need to
type. `;` and `` ` `` are fine.

**`InterfaceRank`** is separate from every command's own `Rank`. Below it the
console will not open at all; above it, each command is still checked.

**`OwnerIsCreator`** grants the place creator Owner so a solo developer is not
locked out on install. It is a fallback — `SetRank` and a bound `Resolver` both
win. Group-owned places get nothing automatic, since only your game can answer
who owns a group.

**`Commands.Builtins = false`** registers nothing, for a game that wants only
its own command set.

## Changing things later

```lua
Astrix.SetTheme("Tokyonight")
Astrix.SetMaxWindows(5)
Astrix.SetCycleTimeout(0.8)
Astrix.SetRank(player, "admin")
Astrix.BindRanks(resolver)
Astrix.DefineTheme("Mine", { … }, "Default")
Astrix.Notify("message", "Announce", 6)
```

## Themes

A theme is a token table merged over another, so it restates only what differs.
Geometry and motion are not a matter of taste and are usually inherited.

```lua
Astrix.DefineTheme("Crimson", {
    Accent = { Primary = Color3.fromRGB(220, 60, 80) },
    Color = { Background = Color3.fromRGB(18, 8, 10) },
    Transparency = { Panel = 0.25 },
}, "Default")
```

`Accent` is its own top-level group rather than living inside `Color`, so
everything wanting brand colour pulls from one place.

## Notices

`Astrix.Notify` on the **server** broadcasts to every player, or to one if
given. Recipients are **not** rank-checked — an announcement exists for the
people being announced to, almost none of whom could run the command that made
it. On the client it shows locally and goes nowhere.

```lua
Astrix.Notify("Server restarting in 5 minutes", "Announce", 8)
Astrix.Notify("Behave", "Warn", 4, somePlayer)
```

Tones: `Info` `Ok` `Warn` `Error` `Announce`, each colouring the accent bar.
