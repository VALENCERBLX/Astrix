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

### Where to define a Service command

**Both sides.** This is the one thing about `Service` that catches people out.

Functions do not survive a trip across the network, so the client never
receives a command's tasks — only its *schema*: name, aliases, arguments,
flags, rank and cooldown. That is deliberate, and it is what makes autocomplete
and argument hints work for server-only commands without shipping your server
logic to every player.

The consequence: a `Service` command defined in a `Script` is a server-only
command whose client half does not exist on any client. Running it fails with

> Failed to run Command \[Admit]: this is a Service command replicated from the
> server, so its Local task does not exist on this client.

Put the definition in a ModuleScript in `ReplicatedStorage` and require it from
both startup scripts:

```lua
-- ReplicatedStorage/SharedCommands (a ModuleScript)
return function(Astrix)
    Astrix.Define("Admit")
        :Type("Service")
        :Rank(Astrix.Enums.Rank.Admin.Min)
        :Parsed({ { Name = "Message", Type = "String", Required = true } })
        :Tasks({
            Server = function(context)
                announce:FireAllClients(context.Executor.DisplayName, context.Parsed.Message)

                return Astrix.Resolve.Ok("announced")
            end,
            Local = function(context, prior)
                Flare.Toast("Announcement sent"):Ok():Show()

                return Astrix.Resolve.Ok("announced")
            end,
        })
        :Register()
end
```

```lua
-- both startup scripts
require(ReplicatedStorage.SharedCommands)(Astrix)
```

`examples/SharedCommands.lua` is that file, filled in and runnable.

### The client half only runs on the caller

A `Service` command's `Local` task runs on the machine that *typed* it, once —
not on everybody's. To reach every player, fire a `RemoteEvent` from the server
half and let each client react to it. The client half is for acknowledging to
the person who ran the command, not for broadcasting.

### "command 'X' was overwritten"

A warning, not an error: you defined a command with the same name as one that
already exists, and yours replaced it. Astrix ships `Kick`, `Ping`, `Heal` and
about twenty others, so defining your own `Kick` is a legitimate thing to do —
the warning is only there so an accidental collision is not silent. Rename
yours if it was an accident, or ignore it if it was not.

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
