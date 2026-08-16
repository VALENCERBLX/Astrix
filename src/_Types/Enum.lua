--!strict

--- A closed set of allowed strings, declared per argument.
---
--- This provider used to be a passthrough that never ran, because `Argument`
--- carried no set to validate against so everything "already matched". The
--- `EnumValues` field on `Argument` is what fixes that: with it declared, an
--- unlisted value is a real parse failure and completion has something to
--- offer. Without it the provider still accepts anything, since an enum with
--- no members cannot reject.

local Types = require(script.Parent.Parent.Types)

type Argument = Types.Argument

local function values(argument: Argument?): { string }?
	if argument and argument.EnumValues and #argument.EnumValues > 0 then
		return argument.EnumValues
	end

	return nil
end

local Provider: Types.ArgumentTypeProvider<string> = {
	Name = "Enum",

	Validate = function(raw: string, argument: Argument?): boolean
		local allowed = values(argument)

		if not allowed then
			return true
		end

		local query = string.lower(tostring(raw))

		for _, option in allowed do
			if string.lower(option) == query then
				return true
			end
		end

		return false
	end,

	Resolve = function(raw: string, argument: Argument?): string?
		local allowed = values(argument)

		if not allowed then
			return tostring(raw)
		end

		local query = string.lower(tostring(raw))

		for _, option in allowed do
			if string.lower(option) == query then
				--// hand back the DECLARED spelling, not what was typed
				return option
			end
		end

		return nil
	end,

	Suggest = function(prefix: string, argument: Argument?): { string }
		local allowed = values(argument)

		if not allowed then
			return {}
		end

		local query = string.lower(tostring(prefix))
		local out = {}

		for _, option in allowed do
			if string.sub(string.lower(option), 1, #query) == query then
				table.insert(out, option)
			end
		end

		return out
	end,
}

return Provider
