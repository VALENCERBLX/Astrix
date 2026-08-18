--!strict

--- Dispatch: the client-side execution pipeline.
---
--- Rank, then cooldown, then binding, then routing by `Type`. The Kyn session
--- calls this and knows none of it — `MakeDispatch` returns a closure that the
--- session treats as an opaque "run this command", which is why rank and
--- cooldown rules can change without touching the evaluator.
---
--- Everything crossing the network is already *resolved*: a `Player`, a
--- `Vector3`, a number. Raw Kyn text never leaves the client.
--- @section Runtime

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Resolve = require(script.Parent.Parent._Classes.Resolve)
local CommandContext = require(script.Parent.Parent._Patterns.CommandContext)
local Network = require(script.Parent.Network)

type CommandResolve = Types.CommandResolve
type CommandDefinition = Types.CommandDefinition

local Client = {}

export type Dependencies = {
	Registry: any,
	Ranks: any,
	Cooldowns: any,
	Providers: { [string]: any },
	Runtime: any,
	Windows: (() -> any)?,
	Sink: ((kind: Types.HistoryKind, message: string, content: Types.ContentElement?) -> ())?,
}

--// locals ---------------------------------------------------------------------
local function executor(): Player
	return Players.LocalPlayer
end

--- Runs a task under `pcall`, so a thrown Luau error becomes a failure result
--- rather than taking the console down with it.
local function protected(task: Types.CommandTask?, context: Types.ExecutionContext, prior: any, name: string): CommandResolve
	if not task then
		return Resolve.Fail(`Failed to run Command [{name}]: the task it routed to does not exist here`)
	end

	local ok, result = pcall(task, context, prior)

	if not ok then
		warn(`[Astrix] '{name}' errored: {result}`)

		return Resolve.Fail(`Failed to run Command [{name}]: {tostring(result)}`)
	end

	return Resolve.From(result)
end

--// public api ------------------------------------------------------------------
--- Builds the dispatcher injected into a Kyn session.
function Client.MakeDispatch(deps: Dependencies): (string, { any }, { [string]: any }, string) -> CommandResolve
	return function(head: string, args: { any }, flags: { [string]: any }, raw: string): CommandResolve
		local definition: CommandDefinition? = deps.Registry:Resolve(head)

		if not definition then
			return Resolve.CommandNotFound(head)
		end

		--// route to a sub-command before anything is bound: `window open Logs`
		--// is the `open` sub with `Logs` as its first argument, so the parent's
		--// own Parsed never sees the word `open`
		local routed = definition

		if definition.Subs and type(args[1]) == "string" then
			local sub = (definition.Subs :: any)[string.lower(args[1])]

			if sub then
				routed = sub

				args = table.move(args, 2, #args, 1, {})
			end
		end

		definition = routed

		local player = executor()

		--// 1. rank
		if not deps.Ranks:Allows(deps.Ranks:Get(player), definition.Rank) then
			return Resolve.RankDenied(definition.Name)
		end

		--// 2. cooldown
		if deps.Cooldowns:IsActive(player, definition) then
			return Resolve.OnCooldown(definition.Name)
		end

		--// 3 and 4. binding
		local okArgs, parsed, argFailure = CommandContext.BindArgs(definition, args, deps.Providers)

		if not okArgs then
			return argFailure :: CommandResolve
		end

		local okFlags, bound, flagFailure = CommandContext.BindFlags(definition, flags, deps.Providers)

		if not okFlags then
			return flagFailure :: CommandResolve
		end

		--// 5. context
		local context = CommandContext.Build(
			player,
			parsed,
			bound,
			raw,
			if deps.Windows then deps.Windows() else nil,
			deps.Sink
		)

		--// 6. the cooldown starts once the command is definitely going to run
		deps.Cooldowns:Trigger(player, definition)

		if deps.Runtime then
			deps.Runtime:Touch(player)
		end

		--// 7. routing
		local tasks = definition.Tasks

		if definition.Type == "Local" then
			if not tasks.Local then
				return Resolve.Fail(`Failed to run Command [{definition.Name}]: no local task`)
			end

			return protected(tasks.Local, context, nil, definition.Name)
		end

		if definition.Type == "Server" then
			return Network.InvokeServer(definition.Name, args, flags, raw, nil)
		end

		--// Service means both halves run, so the client needs a local task it
		--// can actually call. A definition that only ever existed in a server
		--// script arrives here as a replicated *schema* — name, arguments and
		--// rank, but no functions, because functions do not serialise. Calling
		--// the missing half is what used to raise "attempt to call a nil
		--// value" from inside the dispatcher, which said nothing about why.
		if not tasks.Local then
			if definition.Replicated then
				return Resolve.Fail(
					`Failed to run Command [{definition.Name}]: this is a Service command replicated from the server, `
						.. `so its Local task does not exist on this client. Define it on both sides — put the `
						.. `Define call in a ModuleScript both your server and client startup scripts require.`
				)
			end

			return Resolve.Fail(
				`Failed to run Command [{definition.Name}]: Type is "Service" but no Local task was given. `
					.. `Use Type "Server" if it only has a server half.`
			)
		end

		--// LocalFirst puts the client first for instant feedback; the default
		--// puts the server first so its result is authoritative before
		--// anything is shown
		if definition.LocalFirst then
			local localResult = protected(tasks.Local :: Types.CommandTask, context, nil, definition.Name)
			local serverResult = Network.InvokeServer(definition.Name, args, flags, raw, localResult.Result)

			return serverResult
		end

		local serverResult = Network.InvokeServer(definition.Name, args, flags, raw, nil)

		if not serverResult.Resolved then
			--// the server refused, so the client half never happens
			return serverResult
		end

		return protected(tasks.Local :: Types.CommandTask, context, serverResult.Result, definition.Name)
	end
end

--- Re-checks a request that arrived from a client and runs `Tasks.Server`.
---
--- The client already checked rank and cooldown, which is a courtesy, not a
--- guarantee — both are checked again here because only this side is trusted.
function Client.MakeServerHandler(deps: Dependencies)
	assert(RunService:IsServer(), "the server handler is server-only")

	return function(player: Player, name: string, args: { any }, flags: { [string]: any }, raw: string, prior: any): CommandResolve
		local definition: CommandDefinition? = deps.Registry:Resolve(name)

		if not definition then
			return Resolve.CommandNotFound(name)
		end

		--// the same routing as the client, or a sub would never reach its
		--// server task
		if definition.Subs and type(args[1]) == "string" then
			local sub = (definition.Subs :: any)[string.lower(args[1])]

			if sub then
				definition = sub

				args = table.move(args, 2, #args, 1, {})
			end
		end

		if not deps.Ranks:Allows(deps.Ranks:Get(player), definition.Rank) then
			return Resolve.RankDenied(definition.Name)
		end

		if deps.Cooldowns:IsActive(player, definition) then
			return Resolve.OnCooldown(definition.Name)
		end

		local okArgs, parsed, argFailure = CommandContext.BindArgs(definition, args, deps.Providers)

		if not okArgs then
			return argFailure :: CommandResolve
		end

		local okFlags, bound, flagFailure = CommandContext.BindFlags(definition, flags, deps.Providers)

		if not okFlags then
			return flagFailure :: CommandResolve
		end

		--// no sink: there is nowhere to stream output to from here, so
		--// ctx.Output.Reply/Error/Success are no-ops server-side and only the
		--// returned resolve reaches the player (open item #5)
		local context = CommandContext.Build(player, parsed, bound, raw, nil, nil)

		deps.Cooldowns:Trigger(player, definition)

		local task = definition.Tasks.Server

		if not task then
			return Resolve.Fail(`Failed to run Command [{definition.Name}]: no server task`)
		end

		return protected(task, context, prior, definition.Name)
	end
end

return Client
