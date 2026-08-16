--!strict

--- `CommandResolve` factory — the single shape every execution path returns.
---
--- The error strings are exact, because the specification pins them. Anything
--- that reads console output (a test, a log scraper, a player following a
--- tutorial) sees the same wording every time.

local Types = require(script.Parent.Parent.Types)

type CommandResolve = Types.CommandResolve
type ContentElement = Types.ContentElement

local Resolve = {}

local function make(resolved: boolean, kind: Types.ResolveKind, output: string?, result: any?): CommandResolve
	return {
		Resolved = resolved,
		Kind = kind,
		Output = output,
		Result = result,
		Content = nil,
	}
end

--- Success. `Result` is what a pipe passes on and what `::Kout` remembers.
function Resolve.Ok(output: string?, result: any?): CommandResolve
	return make(true, "Ok", output, result)
end

--- Success carrying a rich element rather than a plain line.
function Resolve.Content(content: ContentElement, result: any?): CommandResolve
	local resolved = make(true, "Ok", nil, result)

	resolved.Content = content

	return resolved
end

function Resolve.Fail(output: string?, result: any?): CommandResolve
	return make(false, "Fail", output, result)
end

--- A warning resolves *false*, so `>>` does not continue past it while `->`
--- does. A cooldown is the motivating case: nothing ran, so nothing succeeded.
function Resolve.Warn(output: string?): CommandResolve
	return make(false, "Warn", output)
end

function Resolve.CommandNotFound(name: string): CommandResolve
	return make(false, "CommandNotFound", `Failed to run Command [{name}]: Command Does Not Exist`)
end

function Resolve.RankDenied(name: string): CommandResolve
	return make(false, "RankDenied", `Failed to run Command [{name}]: No Command Assertion`)
end

function Resolve.OnCooldown(name: string): CommandResolve
	return make(false, "OnCooldown", `Warn: Command [{name}] is on cooldown`)
end

--- `Failed to parse [Arg] (Command): Missing` when nothing was supplied, or
--- `… Type: Expected - Not [Actual]` when something was but of the wrong shape.
function Resolve.ParseFailed(argument: string, command: string, expected: string?, actual: string?): CommandResolve
	if not expected then
		return make(false, "ParseFailed", `Failed to parse [{argument}] ({command}): Missing`)
	end

	return make(
		false,
		"ParseFailed",
		`Failed to parse [{argument}] ({command}): Type: {expected} - Not [{actual or "nil"}]`
	)
end

--- A `@Function` redefinition that collides with an `Astrix.Native` name.
function Resolve.AbsoluteOverwrite(name: string): CommandResolve
	return make(false, "AbsoluteOverwrite", `failed to overwrite :[ function "{name}" is absolute. ]`)
end

--- Normalises whatever a command task returned. A task may return nothing, a
--- bare value, or a real resolve; all three become a resolve.
function Resolve.From(value: any): CommandResolve
	if type(value) == "table" and type(value.Resolved) == "boolean" then
		return value :: CommandResolve
	end

	if value == nil then
		return Resolve.Ok()
	end

	return Resolve.Ok(if type(value) == "string" then value else nil, value)
end

return Resolve
