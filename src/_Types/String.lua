--!strict

--- Anything is a string. Present for symmetry, so `CommandContext` can look up
--- a provider for every declared type without special-casing.

local Types = require(script.Parent.Parent.Types)

local String: Types.ArgumentTypeProvider<string> = {
	Name = "String",

	Validate = function(raw: string): boolean
		return type(raw) == "string"
	end,

	Resolve = function(raw: string): string?
		return tostring(raw)
	end,

	Suggest = function(): { string }
		return {}
	end,
}

return String
