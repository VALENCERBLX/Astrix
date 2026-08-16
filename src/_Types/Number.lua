--!strict

local Types = require(script.Parent.Parent.Types)

local Number: Types.ArgumentTypeProvider<number> = {
	Name = "Number",

	Validate = function(raw: string): boolean
		return tonumber(raw) ~= nil
	end,

	Resolve = function(raw: string): number?
		return tonumber(raw)
	end,

	Suggest = function(): { string }
		return {}
	end,
}

return Number
