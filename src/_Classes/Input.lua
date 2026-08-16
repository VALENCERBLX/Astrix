--!strict

--- A player's live Kyn session: their variables, their `@Function`
--- definitions, their `::Kout` stack, and the evaluator that walks a `LineAST`.
---
--- This is the DATA half of the pair — `Interface/Elements/Input.lua` is the
--- textbox. Similar names, opposite jobs.
---
--- The session knows nothing about rank, cooldowns or networking. Running a
--- command goes through an injected `Dispatch`, the same way `Command.lua`
--- takes an injected registrar, so the evaluator can be tested without a
--- registry, a player or a remote.

local Types = require(script.Parent.Parent.Types)
local Resolve = require(script.Parent.Resolve)
local Line = require(script.Parent.Line)

type WordNode = Types.WordNode
type PipelineStage = Types.PipelineStage
type CommandResolve = Types.CommandResolve

local Input = {}
Input.__index = Input

export type Config = {
	--- Runs one command. Receives the head name, resolved positional values,
	--- resolved flags, and the raw line for context.
	Dispatch: ((Head: string, Args: { any }, Flags: { [string]: any }, Raw: string) -> CommandResolve)?,

	--- `Astrix.Native` functions. Reserved: a `@Function` may not shadow one.
	Natives: { [string]: (...any) -> any }?,

	--- Namespaced lookups: `@Players.Rin` calls `Namespaces.Players("Rin")`.
	Namespaces: { [string]: (key: string) -> any }?,

	--- `@Vector3(1, 2, 3)` and friends.
	Constructors: { [string]: (...any) -> any }?,

	MaxDepth: number?,
	StackLimit: number?,
}

export type Fields = {
	Variables: { [string]: any },
	Functions: { [string]: WordNode },
	Natives: { [string]: (...any) -> any },
	Namespaces: { [string]: (key: string) -> any },
	Constructors: { [string]: (...any) -> any },

	Stack: { any },
	StackLimit: number,
	MaxDepth: number,
	Depth: number,

	Dispatch: ((Head: string, Args: { any }, Flags: { [string]: any }, Raw: string) -> CommandResolve)?,
}

export type Session = typeof(setmetatable({} :: Fields, Input))

local DEFAULT_STACK_LIMIT = 50
local DEFAULT_MAX_DEPTH = 10

--// public api ------------------------------------------------------------------
function Input.new(config: Config?): Session
	local settings = config or {}

	local self: Fields = {
		Variables = {},
		Functions = {},
		Natives = settings.Natives or {},
		Namespaces = settings.Namespaces or {},
		Constructors = settings.Constructors or {},

		Stack = {},
		StackLimit = settings.StackLimit or DEFAULT_STACK_LIMIT,
		MaxDepth = settings.MaxDepth or DEFAULT_MAX_DEPTH,
		Depth = 0,

		Dispatch = settings.Dispatch,
	}

	return setmetatable(self, Input)
end

--// stack ------------------------------------------------------------------------
--- Remembers a result. The stack is capped; the oldest entry falls off.
function Input.Push(self: Session, value: any)
	table.insert(self.Stack, 1, value)

	while #self.Stack > self.StackLimit do
		table.remove(self.Stack)
	end
end

--- `::Kout` is depth 0 and means the most recent result; `::Kout(n)` is `n`
--- *additional* steps back, so bare and `(0)` are the same thing.
function Input.Recall(self: Session, depth: number): any
	return self.Stack[math.max(1, depth + 1)]
end

--// variables and functions --------------------------------------------------------
function Input.Set(self: Session, name: string, value: any)
	self.Variables[name] = value
end

function Input.Unset(self: Session, name: string)
	self.Variables[name] = nil
end

function Input.VariableNames(self: Session): { string }
	local names = {}

	for name in self.Variables do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

function Input.FunctionNames(self: Session): { string }
	local names = {}

	for name in self.Functions do
		table.insert(names, name)
	end

	for name in self.Natives do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

--- Defines a `@Function`. A name already taken by a native is absolute and
--- cannot be shadowed.
function Input.DefineFunction(self: Session, name: string, body: WordNode): CommandResolve
	if self.Natives[name] then
		return Resolve.AbsoluteOverwrite(name)
	end

	self.Functions[name] = body

	return Resolve.Ok(`defined function "{name}"`)
end

--// word resolution -----------------------------------------------------------------
--- Turns a `WordNode` into a real value. Returns the value and, on failure, a
--- message; the two are never both meaningful.
function Input.Word(self: Session, node: WordNode): (any, string?)
	local kind = node.Kind

	if kind == "String" or kind == "Number" or kind == "Boolean" then
		return (node :: any).Value, nil
	end

	if kind == "Bareword" then
		return (node :: any).Value, nil
	end

	if kind == "StackRef" then
		return Input.Recall(self, (node :: any).Depth), nil
	end

	if kind == "Ref" then
		return Input.Reference(self, node)
	end

	return nil, `cannot resolve a {tostring(kind)}`
end

local function resolveAll(self: Session, nodes: { WordNode }): ({ any }, string?)
	local values = {}

	for index, node in nodes do
		local value, err = Input.Word(self, node)

		if err then
			return values, err
		end

		values[index] = value
	end

	return values, nil
end

--- Resolves an `@Ref`: a namespaced lookup, a type constructor, a native, a
--- user function, or a plain variable.
function Input.Reference(self: Session, node: WordNode): (any, string?)
	local path = (node :: any).Path :: { string }
	local call = (node :: any).Call :: { WordNode }?

	if #path == 0 then
		return nil, "empty reference"
	end

	local head = path[1]

	--// `@Players.Rin` — a namespaced lookup, the only way to name a player
	if #path > 1 then
		local namespace = self.Namespaces[head]

		if not namespace then
			return nil, `unknown namespace "{head}"`
		end

		local value = namespace(path[2])

		if value == nil then
			return nil, `{head}.{path[2]} matched nothing`
		end

		return value, nil
	end

	--// builtins that mutate the session
	if head == "Set" and call then
		local values, err = resolveAll(self, call)

		if err then
			return nil, err
		end

		local name = values[1]

		if type(name) ~= "string" or call[1].Kind ~= "String" then
			return nil, "@Set expects a quoted name"
		end

		Input.Set(self, name, values[2])

		return values[2], nil
	end

	if head == "Unset" and call then
		local values, err = resolveAll(self, call)

		if err then
			return nil, err
		end

		if type(values[1]) ~= "string" then
			return nil, "@Unset expects a quoted name"
		end

		Input.Unset(self, values[1])

		return nil, nil
	end

	--// `@Vector3(1, 2, 3)`, `@Enum(Idle)`
	local constructor = self.Constructors[head]

	if constructor and call then
		local values, err = resolveAll(self, call)

		if err then
			return nil, err
		end

		local ok, result = pcall(constructor, table.unpack(values))

		if not ok then
			return nil, `@{head} failed: {result}`
		end

		return result, nil
	end

	--// a call: native first, since natives are absolute
	if call then
		local native = self.Natives[head]

		if native then
			local values, err = resolveAll(self, call)

			if err then
				return nil, err
			end

			local ok, result = pcall(native, table.unpack(values))

			if not ok then
				return nil, `@{head} errored: {result}`
			end

			return result, nil
		end

		local body = self.Functions[head]

		if body then
			if self.Depth >= self.MaxDepth then
				--// a failure, not a stack overflow
				return nil, `@{head} exceeded the recursion limit of {self.MaxDepth}`
			end

			self.Depth += 1

			local value, err = Input.Word(self, body)

			self.Depth -= 1

			return value, err
		end

		return nil, `unknown function "{head}"`
	end

	--// no call: the VALUE. A variable, or the function itself
	if self.Variables[head] ~= nil then
		return self.Variables[head], nil
	end

	if self.Functions[head] then
		return self.Functions[head], nil
	end

	if self.Natives[head] then
		return self.Natives[head], nil
	end

	return nil, `unknown reference "@{head}"`
end

--// evaluation --------------------------------------------------------------------
--- Whether the segment after `previous` should run, given the operator that
--- joined them. `:` always continues, `>>` needs success, `->` needs failure.
local function shouldRunNext(operator: string?, previous: CommandResolve?): boolean
	if not operator or not previous then
		return true
	end

	if operator == ":" then
		return true
	elseif operator == ">>" then
		return previous.Resolved
	elseif operator == "->" then
		return not previous.Resolved
	end

	return true
end

--- Runs one pipeline stage. `piped` is the previous stage's result, which
--- becomes the first positional argument.
function Input.Stage(self: Session, stage: PipelineStage, piped: any, raw: string): CommandResolve
	if stage.Kind == "FunctionDecl" then
		return Input.DefineFunction(self, (stage :: any).Name, (stage :: any).Body)
	end

	if stage.Kind == "RefCall" then
		local value, err = Input.Word(self, (stage :: any).Ref)

		if err then
			return Resolve.Fail(err)
		end

		return Resolve.Ok(nil, value)
	end

	local head = (stage :: any).Head :: string
	local argNodes = (stage :: any).Args :: { WordNode }
	local flagNodes = (stage :: any).Flags :: { Types.FlagNode }

	local args, err = resolveAll(self, argNodes)

	if err then
		return Resolve.Fail(err)
	end

	if piped ~= nil then
		table.insert(args, 1, piped)
	end

	local flags: { [string]: any } = {}

	for _, flag in flagNodes do
		if flag.Value then
			local value, flagErr = Input.Word(self, flag.Value)

			if flagErr then
				return Resolve.Fail(flagErr)
			end

			flags[flag.Name] = value
		else
			flags[flag.Name] = true
		end
	end

	if not self.Dispatch then
		return Resolve.Fail("no dispatcher is bound to this session")
	end

	return (self.Dispatch :: any)(head, args, flags, raw)
end

--- Parses and runs a line. Returns the last resolve, and every resolve along
--- the way so the console can print each one.
function Input.Evaluate(self: Session, raw: string): (CommandResolve, { CommandResolve })
	local ast = Line.Parse(raw)
	local results: { CommandResolve } = {}

	if ast.Error then
		local failure = Resolve.Fail(ast.Error)

		return failure, { failure }
	end

	local last: CommandResolve? = nil
	local previousOperator: string? = nil

	for _, segment in ast.Segments do
		if not shouldRunNext(previousOperator, last) then
			--// skipped, but the operator that follows THIS segment still
			--// governs the next one
			previousOperator = segment.Op
			continue
		end

		local piped: any = nil
		local stageResult: CommandResolve? = nil

		for _, stage in segment.Pipeline do
			stageResult = Input.Stage(self, stage, piped, raw)

			table.insert(results, stageResult :: CommandResolve)

			piped = (stageResult :: CommandResolve).Result

			if not (stageResult :: CommandResolve).Resolved then
				break
			end
		end

		last = stageResult
		previousOperator = segment.Op

		if last and last.Result ~= nil then
			Input.Push(self, last.Result)
		end
	end

	return last or Resolve.Ok(), results
end

--- Drops variables, functions and the stack. The session instance survives.
function Input.Reset(self: Session)
	table.clear(self.Variables)
	table.clear(self.Functions)
	table.clear(self.Stack)

	self.Depth = 0
end

return Input
