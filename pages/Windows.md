# Windows

Konsole had exactly two consoles: a main one and a detached chat pill, with
`channel == 2` branching throughout. Astrix takes as many as you want.

## From the console

```
window                 -- list them
window open Logs       -- open one
window close Logs      -- close it
window max 5           -- raise the cap
```

Those are real sub-commands, so `window ` completes them and `window open `
completes that sub's own arguments.

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

The activation key does double duty. Pressed on its own it opens the console at
the window you were last using and puts the caret in it. Pressed **again inside
the timeout** it steps one further back through the windows you have used — the
second press lands on the one before, the third on the one before that.

The order walked is **recency, not creation**, so it behaves the way alt-tab
does: the window you want is usually one press away. Recency is only rewritten
when a run of presses settles, since updating it on every step would reorder
the list underneath you and the second press would take you straight back where
you started.

The timeout is 1.5 seconds and configurable:

```lua
Astrix.Start({ Interface = { CycleTimeout = 1.5 } })
Astrix.SetCycleTimeout(0.8)   -- or later
```

Set it to zero to switch cycling off entirely.

### When the key cycles, and when it types

The activation key is watched even while a console field has focus — it has to
be, since that is the only state cycling ever happens in. But it cannot swallow
the key forever, or a console bound to `;` could never type `::Kout`: `:` and
`;` are the same `KeyCode`.

So the rule is:

- **Inside the timeout, measured from when the caret was captured**, a bare
  press cycles. That covers opening the console and immediately tapping through
  to the window you wanted.
- **After that**, a bare press is just a character. Type freely.
- **`Ctrl` + the key cycles whenever you ask**, however long ago focus landed.

Each cycle re-captures focus, so a run of quick presses keeps working; pause,
and the key goes back to being a character.

Whatever the key does manage to type is taken back out. The field is watched
rather than restored on a timer — Roblox may not have inserted the character
yet when the handler finishes, so a fixed delay is a race — and the watch lets
go after the first change or a fifth of a second, whichever comes first. Your
next real keystroke is never touched.

### Knowing where you landed

The window that takes focus flashes: its surface lifts quickly toward opaque
and settles back more slowly. With three consoles stacked, "the caret moved" is
otherwise a one-pixel cue.

The asymmetry is deliberate and shared with every other transition here — a
symmetric flash reads as a glitch, while a fast rise and slow fall reads as
something being handed to you.

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
