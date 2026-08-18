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

## Cycling between them

The activation key does double duty. Pressed on its own it toggles the console.
Pressed **again within 1.5 seconds** it moves to the next window instead — so
tapping it three times quickly lands you on the third. Pause, and the next
press goes back to toggling.

**This needs more than one window.** With only the default `Main` open there is
nothing to cycle to and every press just toggles, which looks like the feature
is broken. Open a second first:

```
window open Logs
```

Each window keeps its own history, and output goes to whichever one has the
caret. Cycling to a second window and running something there leaves the first
untouched.

## Dragging

Windows drag on a spring rather than pinned to the cursor: they trail the
pointer with a little weight and overshoot slightly when released. Dragging a
window also detaches it from the stack, since otherwise the next reflow would
pull it straight back into line.

```lua
panel:setDraggable(true, { smooth = true, follow = "drag", settle = "toss" })
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
