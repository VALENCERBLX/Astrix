# Commands

## The builder

```lua
Astrix.Define("Kick")
    :Type("Server")                       -- Local | Server | Service
    :Rank(Astrix.Enums.Rank.Admin.Min)
    :Describe("Removes a player")
    :Aliases({ "Boot" })
    :Parsed({ … })                        -- positional arguments
    :Flags({ … })                         -- --named options
    :Cooldown(3)                          -- seconds, per player per command
    :Tasks({ Server = function(ctx) … end })
    :Register()                           -- terminal; validates and freezes
```

## Arguments

Positional, matched in order. A required argument may not follow an optional
one — that is a definition error, caught at `:Register()`, because it could
never be filled.

```lua
:Parsed({
    { Name = "Target", Type = "Player", Required = true },
    { Name = "Reason", Type = "String", Required = false, Default = "None" },
    { Name = "Mode", Type = "Enum", Required = false,
      EnumValues = { "Soft", "Hard" } },
})
```

Types: `String` `Number` `Boolean` `Player` `Vector3` `Enum`.

A value arriving already the right type is used as-is — `@Players.Rin` produced
a real Player, `@Vector3(1, 2, 3)` a real Vector3. Anything else is cast through
that type's provider, and a failed cast is a parse error rather than a nil
inside your task.

`Enum` needs `EnumValues` to be worth anything. With it, an unlisted value is
refused and completion offers the listed ones; the value your task receives is
the **declared** spelling, not what was typed.

## Flags

Two kinds. `IsBool` is present-or-absent, `IsValue` carries one.

```lua
:Flags({
    { Name = "Instant", Extended = "IsBool" },
    { Name = "Speed", Extended = "IsValue", Type = "Number", Default = 1,
      Aliases = { "S" } },
})
```

```
teleport Rin 0,0,0 --Instant
teleport Rin 0,0,0 --Speed=4
teleport Rin 0,0,0 --S=4
```

Read them off `context.Flags`. An absent `IsBool` is `false` (or its `Default`);
an absent `IsValue` is its `Default`. An unknown flag passes through untouched
rather than failing the line, so a typo does not swallow the command.

Flags complete: type `--` after a command and the dropdown lists that command's
own flags and their aliases.

## Sub-commands

A sub-command is a full definition reached by its name as the first word.
Build them with `Astrix.Sub`, which is the same builder without a registrar,
and hand them to the parent's `:Subs{…}`.

```lua
Astrix.Define("Ban")
    :Type("Server")
    :Rank(Astrix.Enums.Rank.Admin.Min)
    :Describe("Ban management")
    :Subs({
        Astrix.Sub("Add")
            :Describe("Bans a player")
            :Parsed({
                { Name = "Target", Type = "Player", Required = true },
                { Name = "Reason", Type = "String", Required = false },
            })
            :Tasks({ Server = function(ctx) … end }),

        Astrix.Sub("Remove")
            :Parsed({ { Name = "UserId", Type = "Number", Required = true } })
            :Tasks({ Server = function(ctx) … end }),

        Astrix.Sub("List")
            :Tasks({ Server = function(ctx) … end }),
    })
    :Tasks({ Server = function(ctx) … end })   -- when no sub is given
    :Register()
```

```
ban add Rin "griefing"
ban remove 12345678
ban
```

**A sub inherits everything it does not declare** — `Type`, `Rank`, `Cooldown`,
`LocalFirst`, and even `Tasks` — so in practice a sub only states what differs.
Give a sub its own `Rank` to make one branch stricter than the rest.

The parent's own `Parsed` never sees the sub's name: `ban add Rin` binds `Rin`
to `Add`'s first argument, not to `Ban`'s.

Sub names complete in the slot straight after the parent, and past that the
dropdown offers the **sub's** arguments rather than the parent's.

Do not call `:Register()` on a sub. The parent freezes it.

## Three kinds

| `Type` | Runs | Notes |
|---|---|---|
| `Local` | the client that typed it | needs `Tasks.Local` |
| `Server` | the server | needs `Tasks.Server` |
| `Service` | both | needs both |

`Service` runs the server first, so its result is authoritative, then hands it
to the client task as `PriorResult`. `:LocalFirst(true)` reverses that for
instant feedback.

## Results

```lua
Astrix.Resolve.Ok(message, result)     -- Resolved = true
Astrix.Resolve.Fail(message)           -- Resolved = false
Astrix.Resolve.Warn(message)           -- Resolved = false, so >> stops
Astrix.Resolve.Content(element, result)
```

`result` is what a pipe passes on and what `::Kout` remembers. A task that
returns nothing counts as `Ok`; one that throws becomes a `Fail` rather than
taking the console down.

## Output

`context.Output.Reply` / `.Error` / `.Success`, and `context.Output.Elements`
for rich output — `Text` `Table` `ProgressBar` `Ascii` `Image` `Divider`.

Server tasks cannot stream: `Reply` and friends are no-ops there, and only the
returned resolve reaches the player.
