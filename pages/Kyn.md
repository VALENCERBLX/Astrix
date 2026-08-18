# Kyn

A command line is a grammar, not a list of words. The whole Kyn session lives
**client-side** — server commands only ever receive resolved, typed values.

## Chaining

| | |
|---|---|
| `:` | run the next thing regardless |
| `>>` | only if the previous succeeded |
| `->` | only if the previous failed |
| `\|` | pipe the previous result in as the first argument |

```
Teleport @Target @Vector3(1, 2, 3) >> Notify "done" -> Notify "failed"
```

## References

Everything behind `@` is a reference.

```
@Set("Target", @Players.Rin)     -- assign; the name must be quoted
@Target                          -- read it back
@Unset("Target")                 -- remove it
```

`@Players.Rin` is the **only** way to name a player. A bare `@Rin` is a
variable lookup, never a player.

Type constructors use the same sigil: `@Vector3(1, 2, 3)`, `@Color3(255, 0, 0)`.

## Functions

```
@Function Greet {
    return "Hi"
}

@Greet()    -- calls it
@Greet      -- the function itself, not its result
```

Recursion is capped at 10 and returns a failure rather than overflowing.

Names registered with `Astrix.Native` are **absolute** — redefining one is
refused:

```
failed to overwrite :[ function "Random" is absolute. ]
```

## The result stack

Every result is remembered. `::Kout` is the most recent; `::Kout(n)` is `n`
*additional* steps back, so bare and `::Kout(0)` are the same thing.

```
Help : echo ::Kout
```

The stack keeps the last 50 results per session.

## Flags

```
Teleport Rin 0,0,0 --Instant           -- a bool flag, present means true
Teleport Rin 0,0,0 --Speed=4           -- a valued flag
```

## Multiline

`[[` opens an inline block and `]]` closes it. Inside, Enter is a newline
rather than a submit, so a long chain can be written across lines. Typing `]]`
**is** the submit.

```
[[
  @Set("Target", @Players.Rin)
  Teleport @Target @Vector3(0, 50, 0)
    >> Notify "moved"
]]
```

## Comments

`#` to end of line. Deliberately naive and not quote-aware, so
`echo "# hi"` does lose its tail.

## Completion

Tab accepts whatever is ghosted after the caret. What gets offered depends on
where the caret is:

- a bareword at the start of a segment → command names
- `@` → Kyn's builtins, your variables, your functions, the natives
- `@Players.` → whoever is in the server
- `--` → that command's flags
- a positional slot → that argument's type

Up and Down walk the list when it is showing, and your command history when it
is not — oldest as you keep pressing Up, and back to whatever you had
half-typed when you come past the newest end. Recalling a line does not reopen
the dropdown, so the arrows keep walking history rather than getting stuck on
the first line that happened to match a command. `Ctrl+Left` / `Ctrl+Right` jump by word; `Ctrl+Up` / `Ctrl+Down` jump
to the ends of the chain segment the caret is in.
