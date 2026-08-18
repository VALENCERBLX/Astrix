# Getting Started

Astrix is two calls: one on the server, one on the client.

## Install

Astrix ships self-contained — Lume, Switch and Substance are vendored inside
it, so there is nothing else to install.

**With Rojo.** `default.project.json` already maps `src/` to
`ReplicatedStorage.Astrix`. Sync and you are done.

**Without Rojo.** Paste `dist/install.luau` into the Studio **command bar**
(not a script — `ModuleScript.Source` is not writable from one). It builds the
whole tree under `ReplicatedStorage`.

## Start it

A `Script` in `ServerScriptService`:

```lua
local Astrix = require(game:GetService("ReplicatedStorage").Astrix)

Astrix.Start()
```

A `LocalScript` in `StarterPlayerScripts`:

```lua
local Astrix = require(game:GetService("ReplicatedStorage").Astrix)

Astrix.Start({
    Interface = { Keybind = Enum.KeyCode.T },
})
```

Press `T`. A pill appears at the bottom of the screen; click it or press the
key again to open it into a terminal.

## Who can run what

Ranks are numeric, and a command runs when the player's rank is at least the
command's.

**The place creator is Owner automatically.** Everyone else starts at Player,
which is why a fresh install refuses `Teleport` for anybody but you — it is
declared at Admin.

Grant ranks explicitly:

```lua
Astrix.SetRank(player, "admin")   -- or a number
Astrix.SetRank(12345678, 150)
```

Or answer from wherever you already keep them:

```lua
Astrix.BindRanks(function(entity)
    if typeof(entity) == "Instance" and entity:IsA("Player") then
        if entity:GetRankInGroup(1234567) >= 250 then
            return Astrix.Enums.Rank.Admin.Min
        end
    end

    return nil  -- fall through to SetRank, then the default
end)
```

`InterfaceRank` is a separate gate: below it the console will not open at all,
whatever the individual command ranks say.

## Your first command

```lua
Astrix.Define("Heal")
    :Type("Server")
    :Rank(Astrix.Enums.Rank.Admin.Min)
    :Describe("Restores a player to full health")
    :Parsed({
        { Name = "Target", Type = "Player", Required = true },
    })
    :Cooldown(2)
    :Tasks({
        Server = function(context)
            local humanoid = context.Parsed.Target.Character
                and context.Parsed.Target.Character:FindFirstChildOfClass("Humanoid")

            if not humanoid then
                return Astrix.Resolve.Fail("no humanoid")
            end

            humanoid.Health = humanoid.MaxHealth

            return Astrix.Resolve.Ok(`healed {context.Parsed.Target.Name}`)
        end,
    })
    :Register()
```

Define it on the server and it **replicates schema-only** — the client learns
its name, arguments, flags and rank so autocomplete works, while the function
never leaves the server.

## Three kinds of command

| `Type` | Runs | Use it for |
|---|---|---|
| `Local` | the client that typed it | camera, UI, anything client-side |
| `Server` | the server | anything authoritative |
| `Service` | both | server acts, client plays the feedback |

`Service` runs the server first by default so its result is authoritative.
`:LocalFirst(true)` flips it for instant feedback, handing the client's result
to the server.

## Built in

`Help`, `Theme`, `Window`, `Teleport`. Type `Help` to see everything you can
run at your rank.

## Next

- **Kyn** — the language the console speaks.
- **Windows** — more than one console at a time.
