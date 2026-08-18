# Windows

Konsole had exactly two consoles: a main one and a detached chat pill, with
`channel == 2` branching throughout. Astrix takes as many as you want.

## From the console

```
window                 -- list them
window open Logs       -- open one
window close Logs      -- close it
window --max=5         -- raise the cap
```

## From code

```lua
Astrix.Windows.Open({ Id = "Logs", Title = "Logs", Docked = true })
Astrix.Windows.Close("Logs")
Astrix.Windows.List()

Astrix.SetMaxWindows(5)
```

Inside a command, prefer `ctx.Windows` — the same table, without the command
body needing to require the whole module:

```lua
:Tasks({
    Local = function(context)
        context.Windows.Open({ Id = "Stats", Title = "Stats" })

        context.Windows.Write("Stats", "", context.Output.Elements.Table(
            { "Stat", "Value" },
            { { "FPS", "60" } }
        ))

        return Astrix.Resolve.Ok()
    end,
})
```

## The cap

**Three by default.** A console that can spawn windows without limit is one
runaway loop away from covering the screen. Opening past the cap warns and
returns the most recent window instead. Lowering the cap closes the oldest
until it fits.

## How a window behaves

Each is a collapsed pill you click to open:

| state | width |
|---|---|
| collapsed | 204 |
| expanded, nothing to show | 252 |
| expanded, with output | 338, then as wide as its longest line |

It grows upward from the bottom edge, which never moves, and morphs from a
pill to a 12px radius on the way. Those numbers are Konsole's.

## Rich output

`ctx.Output.Elements` builds anything a window can show, and the same
renderer draws it in the console and in a custom window:

`Text` · `Table` · `ProgressBar` · `Ascii` · `Image` · `Divider`
