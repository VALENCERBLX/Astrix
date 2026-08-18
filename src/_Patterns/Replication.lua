--!strict

--- Strips a `CommandDefinition` down to its schema before it crosses the
--- network.
---
--- This is the piece that lets a server-only command be *known* client-side —
--- its name, arguments, flags and rank reach the client so autocomplete and
--- argument hints work, while the function that actually does the thing never
--- leaves the server. Sending Tasks would be both useless (functions do not
--- serialise) and a disclosure of server logic.
--- @section Patterns

local Types = require(script.Parent.Parent.Types)

type CommandDefinition = Types.CommandDefinition
type ReplicatedDefinition = Types.ReplicatedDefinition

local Replication = {}

--- Schema only — everything but `Tasks`.
function Replication.Strip(definition: CommandDefinition): ReplicatedDefinition
	return {
		Name = definition.Name,
		Aliases = definition.Aliases,
		Type = definition.Type,
		Description = definition.Description,
		Rank = definition.Rank,
		Parsed = definition.Parsed,
		Flags = definition.Flags,
		LocalFirst = definition.LocalFirst,
		Cooldown = definition.Cooldown,
	}
end

function Replication.StripAll(definitions: { CommandDefinition }): { ReplicatedDefinition }
	local out: { ReplicatedDefinition } = {}

	for _, definition in definitions do
		table.insert(out, Replication.Strip(definition))
	end

	return out
end

--- Rebuilds a usable definition on the client from a received schema.
---
--- `Tasks.Server` becomes a marker that returns nothing: the client never runs
--- it, but its presence keeps `Type` checks honest downstream.
function Replication.Hydrate(schema: ReplicatedDefinition): CommandDefinition
	return {
		Name = schema.Name,
		Aliases = schema.Aliases,
		Type = schema.Type,
		Description = schema.Description,
		Rank = schema.Rank,
		Parsed = schema.Parsed or {},
		Flags = schema.Flags,
		LocalFirst = schema.LocalFirst,
		Cooldown = schema.Cooldown,
		Tasks = {
			Server = function()
				return nil
			end,
		},
	}
end

return Replication
