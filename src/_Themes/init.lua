--!strict

--- Theme registry. Resolves a theme name to a token table.
---
--- Only `Default` exists so far — `AstrixOptions.Interface.Theme` is accepted
--- and the registry takes as many as you register, but no second theme has been
--- designed (open item #10). Registering one is a single call.
--- @section Themes

local Default = require(script.Default)

local Themes = {}

export type Theme = typeof(Default)

local registry: { [string]: Theme } = {
	default = Default,
}

local function key(name: string): string
	return string.lower(name)
end

--- Deep-merges `overrides` onto a base theme without touching the base.
local function merge(base: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local out: { [string]: any } = {}

	for name, value in base do
		--// Color3, UDim2 and friends are userdata, so a plain table really is
		--// a token group worth recursing into
		out[name] = if type(value) == "table" and getmetatable(value) == nil then merge(value, nil) else value
	end

	for name, value in overrides or {} do
		if type(value) == "table" and getmetatable(value) == nil and type(out[name]) == "table" then
			out[name] = merge(out[name], value)
		else
			out[name] = value
		end
	end

	return out
end

--- Looks a theme up. Unknown names warn and fall back to Default rather than
--- erroring, so a bad saved setting cannot lock a player out of the console.
function Themes.Resolve(name: string?): Theme
	if not name then
		return Default
	end

	local found = registry[key(name)]

	if not found then
		warn(`[Astrix] unknown theme '{name}', using Default`)

		return Default
	end

	return found
end

--- Registers a theme, optionally by extending an existing one.
function Themes.Register(name: string, tokens: { [string]: any }, extends: string?): Theme
	local base = if extends then Themes.Resolve(extends) else Default
	local built = merge(base :: any, tokens) :: Theme

	built.Name = name
	registry[key(name)] = built

	return built
end

function Themes.List(): { string }
	local names = {}

	for name in registry do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

Themes.Default = Default

--// `Konsole` ships alongside `Default`: the same console with the brand
--// layer taken off. Registered here rather than in `init.lua` so the registry
--// is populated the moment anything requires this module
Themes.Konsole = Themes.Register("Konsole", require(script.Konsole), "Default")

return Themes
