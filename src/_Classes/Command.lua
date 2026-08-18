--!strict

--- The `Define` fluent builder. Every setter returns the builder; `:Register()`
--- is the terminal call that validates, freezes and hands the definition off.
---
--- `Define(Name, OnRegister)` takes its registrar as an argument rather than
--- reaching for the Registry itself, so this module is testable without one.
--- `init.lua` wires `OnRegister` to `Registry:Add`.
--- @section Commands

local Types = require(script.Parent.Parent.Types)

type CommandDefinition = Types.CommandDefinition
type CommandType = Types.CommandType
type Argument = Types.Argument
type Flag = Types.Flag

local Command = {}
Command.__index = Command

export type Fields = {
	Definition: CommandDefinition,
	OnRegister: ((CommandDefinition) -> ())?,
	Registered: boolean,
}

export type Builder = typeof(setmetatable({} :: Fields, Command))

--// locals ---------------------------------------------------------------------
local VALID_TYPES: { [string]: boolean } = { Local = true, Server = true, Service = true }

local function normaliseArgument(raw: any, index: number): Argument
	assert(type(raw) == "table", `argument #{index} must be a table`)
	assert(type(raw.Name) == "string" and raw.Name ~= "", `argument #{index} needs a Name`)
	assert(type(raw.Type) == "string", `argument '{raw.Name}' needs a Type`)

	return {
		Name = raw.Name,
		Type = raw.Type,
		Required = raw.Required ~= false,
		Default = raw.Default,
		Description = raw.Description,
		EnumValues = raw.EnumValues,
	}
end

local function normaliseFlag(raw: any, index: number): Flag
	assert(type(raw) == "table", `flag #{index} must be a table`)
	assert(type(raw.Name) == "string" and raw.Name ~= "", `flag #{index} needs a Name`)

	local extended = raw.Extended or "IsBool"

	assert(extended == "IsBool" or extended == "IsValue", `flag '{raw.Name}' Extended must be IsBool or IsValue`)

	if extended == "IsValue" then
		assert(raw.Type ~= nil, `flag '{raw.Name}' is IsValue and so needs a Type`)
	end

	return {
		Name = raw.Name,
		Aliases = raw.Aliases,
		Extended = extended,
		Type = raw.Type,
		Default = raw.Default,
		Description = raw.Description,
	}
end

--// public api ------------------------------------------------------------------
--- Starts a definition. `OnRegister` receives the finished definition.
function Command.Define(name: string, onRegister: ((CommandDefinition) -> ())?): Builder
	assert(type(name) == "string" and name ~= "", "a command needs a name")

	local self: Fields = {
		Definition = {
			Name = name,
			Aliases = nil,
			Type = nil :: any,
			Description = nil,
			Rank = 0,
			Parsed = {},
			Flags = nil,
			LocalFirst = nil,
			Cooldown = nil,
			Tasks = nil :: any,
			Subs = nil,
			SubOrder = nil,
		},
		OnRegister = onRegister,
		Registered = false,
	}

	return setmetatable(self, Command)
end

function Command.Type(self: Builder, commandType: CommandType): Builder
	assert(VALID_TYPES[commandType], `unknown command Type '{tostring(commandType)}'`)

	self.Definition.Type = commandType

	return self
end

function Command.Rank(self: Builder, rank: number): Builder
	assert(type(rank) == "number", "Rank must be a number")

	self.Definition.Rank = rank

	return self
end

function Command.Describe(self: Builder, description: string): Builder
	self.Definition.Description = description

	return self
end

function Command.Aliases(self: Builder, aliases: { string }): Builder
	self.Definition.Aliases = aliases

	return self
end

function Command.Parsed(self: Builder, arguments: { any }): Builder
	local parsed: { Argument } = {}
	local seenOptional = false

	for index, raw in arguments do
		local argument = normaliseArgument(raw, index)

		--// a required argument after an optional one can never be filled
		--// positionally, so it is a definition error, not a runtime one
		if argument.Required and seenOptional then
			error(`argument '{argument.Name}' is required but follows an optional one`, 0)
		end

		if not argument.Required then
			seenOptional = true
		end

		table.insert(parsed, argument)
	end

	self.Definition.Parsed = parsed

	return self
end

function Command.Flags(self: Builder, flags: { any }): Builder
	local normalised: { Flag } = {}

	for index, raw in flags do
		table.insert(normalised, normaliseFlag(raw, index))
	end

	self.Definition.Flags = normalised

	return self
end

--- Only meaningful for `Type = "Service"`: run the client task first for
--- instant feedback, then hand its result to the server.
function Command.LocalFirst(self: Builder, enabled: boolean): Builder
	self.Definition.LocalFirst = enabled ~= false

	return self
end

function Command.Cooldown(self: Builder, seconds: number): Builder
	self.Definition.Cooldown = seconds

	return self
end

function Command.Tasks(self: Builder, tasks: Types.CommandTasks): Builder
	assert(type(tasks) == "table", "Tasks must be a table")

	self.Definition.Tasks = tasks

	return self
end

--- Attaches sub-commands.
---
--- A sub-command is a full definition in its own right — its own arguments,
--- flags, cooldown and tasks — reached by its name as the first word:
--- `window open Logs` runs `Window`'s `open` sub with `Logs` as its argument.
---
--- Build them with `Astrix.Sub`, which is this same builder without a
--- registrar. Anything a sub leaves unset is inherited from its parent, so in
--- practice a sub only declares what differs.
function Command.Subs(self: Builder, subs: { any }): Builder
	local map: { [string]: CommandDefinition } = {}
	local order: { string } = {}

	for _, entry in subs do
		local definition = if type(entry) == "table" and entry.Definition
			then (entry :: Builder).Definition
			else entry :: CommandDefinition

		assert(type(definition) == "table", "a sub must be a builder or a definition")
		assert(type(definition.Name) == "string", "a sub needs a name")

		map[string.lower(definition.Name)] = definition

		table.insert(order, definition.Name)

		for _, alias in definition.Aliases or {} do
			map[string.lower(alias)] = definition
		end
	end

	self.Definition.Subs = map
	self.Definition.SubOrder = order

	return self
end

--- Validates, freezes, and registers. Terminal — the builder is spent after.
function Command.Register(self: Builder): CommandDefinition
	assert(not self.Registered, `command '{self.Definition.Name}' was registered twice`)

	local definition = self.Definition

	assert(definition.Type ~= nil, `command '{definition.Name}' has no Type`)
	assert(type(definition.Rank) == "number", `command '{definition.Name}' has no Rank`)
	assert(type(definition.Tasks) == "table", `command '{definition.Name}' has no Tasks`)

	--// a parent that only routes needs no task of its own; its subs carry
	--// them. Anything a sub left unset is filled in from the parent here, so
	--// a sub can declare only what differs
	for _, name in definition.SubOrder or {} do
		local sub = (definition.Subs :: any)[string.lower(name)] :: CommandDefinition

		sub.Type = sub.Type or definition.Type
		sub.Rank = if sub.Rank ~= nil and sub.Rank > 0 then sub.Rank else definition.Rank
		sub.Cooldown = sub.Cooldown or definition.Cooldown
		sub.LocalFirst = if sub.LocalFirst ~= nil then sub.LocalFirst else definition.LocalFirst
		sub.Tasks = sub.Tasks or definition.Tasks

		table.freeze(sub.Parsed)

		if sub.Flags then
			table.freeze(sub.Flags)
		end

		table.freeze(sub)
	end

	if definition.Subs and not definition.Tasks then
		--// routing only: give it a task that explains itself rather than
		--// failing an assertion the author cannot act on
		definition.Tasks = {
			Local = function()
				return nil
			end,
		}
	end

	local tasks = definition.Tasks

	if definition.Type == "Local" then
		assert(type(tasks.Local) == "function", `Local command '{definition.Name}' needs Tasks.Local`)
	elseif definition.Type == "Server" then
		assert(type(tasks.Server) == "function", `Server command '{definition.Name}' needs Tasks.Server`)
	else
		assert(
			type(tasks.Local) == "function" and type(tasks.Server) == "function",
			`Service command '{definition.Name}' needs both Tasks.Local and Tasks.Server`
		)
	end

	self.Registered = true

	table.freeze(definition.Parsed)

	if definition.Flags then
		table.freeze(definition.Flags)
	end

	if definition.Subs then
		table.freeze(definition.Subs)
		table.freeze(definition.SubOrder)
	end

	table.freeze(definition)

	if self.OnRegister then
		self.OnRegister(definition)
	end

	return definition
end

return Command
