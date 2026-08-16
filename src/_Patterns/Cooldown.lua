--!strict

--- Per-command, per-entity cooldowns.
---
--- The bucket key is `UserId:CommandName`, so one player's cooldown on
--- `Teleport` says nothing about anybody else's, or about their own `Kill`.

local Types = require(script.Parent.Parent.Types)

type CommandDefinition = Types.CommandDefinition

local Cooldown = {}
Cooldown.__index = Cooldown

export type Fields = {
	Buckets: { [string]: number },
	Clock: () -> number,
}

export type Cooldowns = typeof(setmetatable({} :: Fields, Cooldown))

function Cooldown.new(clock: (() -> number)?): Cooldowns
	local self: Fields = {
		Buckets = {},
		Clock = clock or os.clock,
	}

	return setmetatable(self, Cooldown)
end

local function bucket(entity: any, definition: CommandDefinition): string
	local id = if typeof(entity) == "Instance" and (entity :: Instance):IsA("Player")
		then tostring((entity :: Player).UserId)
		else tostring(entity)

	return `{id}:{definition.Name}`
end

--- Whether this entity is still waiting on this command.
function Cooldown.IsActive(self: Cooldowns, entity: any, definition: CommandDefinition): boolean
	local seconds = definition.Cooldown

	if not seconds or seconds <= 0 then
		return false
	end

	local expires = self.Buckets[bucket(entity, definition)]

	return expires ~= nil and self.Clock() < expires
end

--- Seconds left, or zero.
function Cooldown.Remaining(self: Cooldowns, entity: any, definition: CommandDefinition): number
	local expires = self.Buckets[bucket(entity, definition)]

	if not expires then
		return 0
	end

	return math.max(0, expires - self.Clock())
end

--- Starts the cooldown. Called after the checks pass, before the command runs.
function Cooldown.Trigger(self: Cooldowns, entity: any, definition: CommandDefinition)
	local seconds = definition.Cooldown

	if not seconds or seconds <= 0 then
		return
	end

	self.Buckets[bucket(entity, definition)] = self.Clock() + seconds
end

function Cooldown.Clear(self: Cooldowns, entity: any?, definition: CommandDefinition?)
	if entity and definition then
		self.Buckets[bucket(entity, definition)] = nil

		return
	end

	table.clear(self.Buckets)
end

return Cooldown
