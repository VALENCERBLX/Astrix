--!strict

--- The command registry. Names and aliases both resolve, case-insensitively,
--- to the same `CommandDefinition`.
---
--- Overwriting warns rather than errors — a game that hot-reloads a command
--- module during development should not be brought down by it, which is the
--- behaviour Konsole had and worth keeping.
--- @section Patterns

local Types = require(script.Parent.Parent.Types)

type CommandDefinition = Types.CommandDefinition

local Lookup = {}
Lookup.__index = Lookup

export type Fields = {
	Definitions: { [string]: CommandDefinition },
	Names: { [string]: CommandDefinition },
	Order: { string },
	Watchers: { () -> () },
}

export type Registry = typeof(setmetatable({} :: Fields, Lookup))

local function key(value: string): string
	return string.lower(value)
end

function Lookup.new(): Registry
	local self: Fields = {
		Definitions = {},
		Names = {},
		Order = {},
		Watchers = {},
	}

	return setmetatable(self, Lookup)
end

--- Registers a definition under its name and every alias.
function Lookup.Add(self: Registry, definition: CommandDefinition): CommandDefinition
	local name = key(definition.Name)

	if self.Definitions[name] then
		warn(`[Astrix] command '{definition.Name}' was overwritten`)
	else
		table.insert(self.Order, definition.Name)
	end

	self.Definitions[name] = definition
	self.Names[name] = definition

	for _, alias in definition.Aliases or {} do
		local aliased = key(alias)

		if self.Names[aliased] and self.Names[aliased] ~= definition then
			warn(`[Astrix] alias '{alias}' now points at '{definition.Name}'`)
		end

		self.Names[aliased] = definition
	end

	Lookup.Notify(self)

	return definition
end

--- Resolves a name or alias. Returns nil rather than erroring.
function Lookup.Resolve(self: Registry, name: string): CommandDefinition?
	if type(name) ~= "string" then
		return nil
	end

	return self.Names[key(name)]
end

function Lookup.Unregister(self: Registry, name: string): boolean
	local definition = Lookup.Resolve(self, name)

	if not definition then
		return false
	end

	self.Definitions[key(definition.Name)] = nil
	self.Names[key(definition.Name)] = nil

	for _, alias in definition.Aliases or {} do
		if self.Names[key(alias)] == definition then
			self.Names[key(alias)] = nil
		end
	end

	local at = table.find(self.Order, definition.Name)

	if at then
		table.remove(self.Order, at)
	end

	Lookup.Notify(self)

	return true
end

--- Every registered definition, in registration order.
function Lookup.List(self: Registry): { CommandDefinition }
	local out: { CommandDefinition } = {}

	for _, name in self.Order do
		local definition = self.Definitions[key(name)]

		if definition then
			table.insert(out, definition)
		end
	end

	return out
end

--- Canonical names only — no aliases. Feeds the suggestion dropdown.
function Lookup.CommandNames(self: Registry): { string }
	return table.clone(self.Order)
end

--- Called whenever the set of commands changes, so the interface can refresh
--- its completions without polling.
function Lookup.Watch(self: Registry, watcher: () -> ()): () -> ()
	table.insert(self.Watchers, watcher)

	return function()
		local at = table.find(self.Watchers, watcher)

		if at then
			table.remove(self.Watchers, at)
		end
	end
end

function Lookup.Notify(self: Registry)
	for _, watcher in table.clone(self.Watchers) do
		local ok, err = pcall(watcher)

		if not ok then
			warn(`[Astrix] registry watcher errored: {err}`)
		end
	end
end

return Lookup
