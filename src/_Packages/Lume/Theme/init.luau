--!strict

--- Themes are token tables with two operations: `extend` (deep-merge overrides
--- into a fresh theme) and `spec` (resolve a motion name to a motion spec).
---
--- Extending never mutates the parent, so a panel can hold a private theme
--- without leaking its overrides back into the app.
--- @section Theme

local Types = require(script.Parent.Types)
local Tokens = require(script.Tokens)

type Theme = Types.Theme
type MotionSpec = Types.MotionSpec

local Theme = {}
Theme.__index = Theme

--// locals
local function isPlain(value: any): boolean
	--// Color3, UDim2, Vector2 and friends are userdata, not tables, so a plain
	--// table here really is a token group worth recursing into
	return type(value) == "table" and getmetatable(value) == nil
end

local function merge(base: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local result: { [string]: any } = {}

	for key, value in base do
		result[key] = if isPlain(value) then merge(value, nil) else value
	end

	for key, value in overrides or {} do
		if isPlain(value) and isPlain(result[key]) then
			result[key] = merge(result[key], value)
		else
			result[key] = value
		end
	end

	return result
end

--// public api
--- Creates a theme from the default tokens plus optional overrides.
function Theme.new(overrides: { [string]: any }?): Theme
	local tokens = merge(Tokens, overrides)

	return setmetatable(tokens, Theme) :: any
end

--- Returns a new theme with `overrides` deep-merged in. The receiver is
--- untouched.
function Theme.extend(self: Theme, overrides: { [string]: any }): Theme
	return setmetatable(merge(self :: any, overrides), Theme) :: any
end

--- Resolves a motion argument. A string names a theme spec, a table is used
--- as-is, and nothing at all falls back to `enter`.
function Theme.spec(self: Theme, named: (MotionSpec | string)?): MotionSpec
	if type(named) == "string" then
		local found = self.motion[named]

		if not found then
			warn(`[Lume] unknown motion spec '{named}'`)

			return self.motion.enter
		end

		return found
	end

	if type(named) == "table" then
		return named :: MotionSpec
	end

	return self.motion.enter
end

return Theme
