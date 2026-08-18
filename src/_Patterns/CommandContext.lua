--!strict

--- Binds resolved Kyn values onto a command's declared arguments and flags, and
--- builds the `ExecutionContext` a task receives.
---
--- Values arriving from Kyn are often *already* the right type — `@Players.Rin`
--- produced a real Player, `@Vector3(1, 2, 3)` a real Vector3 — so binding
--- checks that first and only falls back to casting a string through the
--- matching `_Types/` provider.
--- @section Patterns

local Types = require(script.Parent.Parent.Types)
local Resolve = require(script.Parent.Parent._Classes.Resolve)
local Content = require(script.Parent.Parent._Classes.Content)

type CommandDefinition = Types.CommandDefinition
type ExecutionContext = Types.ExecutionContext
type CommandResolve = Types.CommandResolve
type ContentElement = Types.ContentElement
type Argument = Types.Argument

local CommandContext = {}

--// locals ---------------------------------------------------------------------
--- Whether a value is already the declared type, so no cast is needed.
---
--- `Enum` is deliberately not a blanket yes: a string only "already matches"
--- when it is one of the declared `EnumValues`. Treating every string as a
--- valid enum is what stopped the Enum provider from ever running.
local function alreadyMatches(value: any, argument: Argument, providers: { [string]: any }): boolean
	local declared = argument.Type

	if declared == "String" then
		return type(value) == "string"
	elseif declared == "Number" then
		return type(value) == "number"
	elseif declared == "Boolean" then
		return type(value) == "boolean"
	elseif declared == "Vector3" then
		return typeof(value) == "Vector3"
	elseif declared == "Player" then
		return typeof(value) == "Instance" and (value :: Instance):IsA("Player")
	elseif declared == "Enum" then
		--// only an EXACT match counts as already-bound. `Validate` is
		--// case-insensitive, so accepting it here would store "instant" as
		--// typed and skip the cast that canonicalises it to "Instant" —
		--// leaving commands to compare against a spelling they never declared
		if type(value) ~= "string" or not argument.EnumValues then
			return false
		end

		return table.find(argument.EnumValues, value) ~= nil
	end

	return false
end

local function cast(value: any, argument: Argument, providers: { [string]: any }): (boolean, any)
	local provider = providers[argument.Type]

	if not provider then
		return false, nil
	end

	local resolved = provider.Resolve(tostring(value), argument)

	if resolved == nil then
		return false, nil
	end

	return true, resolved
end

--// public api ------------------------------------------------------------------
--- Matches positional values against `definition.Parsed`, in order.
function CommandContext.BindArgs(
	definition: CommandDefinition,
	args: { any },
	providers: { [string]: any }
): (boolean, { [string]: any }, CommandResolve?)
	local parsed: { [string]: any } = {}

	for index, argument in definition.Parsed do
		local value = args[index]

		if value == nil then
			if argument.Required then
				return false, parsed, Resolve.ParseFailed(argument.Name, definition.Name)
			end

			parsed[argument.Name] = argument.Default

			continue
		end

		if alreadyMatches(value, argument, providers) then
			parsed[argument.Name] = value

			continue
		end

		local ok, resolved = cast(value, argument, providers)

		if not ok then
			return false,
				parsed,
				Resolve.ParseFailed(argument.Name, definition.Name, argument.Type, typeof(value))
		end

		parsed[argument.Name] = resolved
	end

	return true, parsed, nil
end

--- Binds flags. `IsBool` flags default to false (or their `Default`) when
--- absent; `IsValue` flags cast the same way arguments do.
function CommandContext.BindFlags(
	definition: CommandDefinition,
	flags: { [string]: any },
	providers: { [string]: any }
): (boolean, { [string]: any }, CommandResolve?)
	local bound: { [string]: any } = {}

	--// alias -> canonical, so `--i` can stand for `--Instant`
	local byName: { [string]: Types.Flag } = {}

	for _, flag in definition.Flags or {} do
		byName[string.lower(flag.Name)] = flag

		for _, alias in flag.Aliases or {} do
			byName[string.lower(alias)] = flag
		end
	end

	for name, raw in flags do
		local flag = byName[string.lower(name)]

		if not flag then
			--// unknown flags pass through rather than failing the command; a
			--// typo should not swallow the whole line
			bound[name] = raw

			continue
		end

		if flag.Extended == "IsBool" then
			if type(raw) == "boolean" then
				bound[flag.Name] = raw
			else
				local provider = providers.Boolean
				local resolved = provider and provider.Resolve(tostring(raw))

				bound[flag.Name] = if resolved == nil then true else resolved
			end

			continue
		end

		local argument: Argument = {
			Name = flag.Name,
			Type = flag.Type or "String",
			Required = false,
			Default = flag.Default,
		}

		if alreadyMatches(raw, argument, providers) then
			bound[flag.Name] = raw

			continue
		end

		local ok, resolved = cast(raw, argument, providers)

		if not ok then
			return false,
				bound,
				Resolve.ParseFailed(flag.Name, definition.Name, argument.Type, typeof(raw))
		end

		bound[flag.Name] = resolved
	end

	--// fill in whatever was not supplied
	for _, flag in definition.Flags or {} do
		if bound[flag.Name] == nil then
			bound[flag.Name] = if flag.Extended == "IsBool" then (flag.Default or false) else flag.Default
		end
	end

	return true, bound, nil
end

--- Builds the context handed to a task.
---
--- `Sink` receives anything the task writes. On the client it appends to the
--- console; on the server there is nowhere to stream to, so it is dropped —
--- see open item #5.
function CommandContext.Build(
	executor: Player,
	parsed: { [string]: any },
	flags: { [string]: any },
	raw: string,
	windows: any,
	sink: ((kind: Types.HistoryKind, message: string, content: ContentElement?) -> ())?
): ExecutionContext
	local function emit(kind: Types.HistoryKind, message: string | ContentElement)
		if not sink then
			return
		end

		if type(message) == "table" then
			sink(kind, "", message :: ContentElement)
		else
			sink(kind, tostring(message), nil)
		end
	end

	return {
		Executor = executor,
		Parsed = parsed,
		Flags = flags,
		RawInput = raw,
		Windows = windows,

		Output = {
			Reply = function(message: string | ContentElement)
				emit("Output", message)
			end,
			Error = function(message: string)
				emit("Fail", message)
			end,
			Success = function(message: string)
				emit("Ok", message)
			end,
			Elements = Content,
		},
	}
end

return CommandContext
