--!strict

local Types = require(script.Parent.Parent.Types)

local TRUE: { [string]: boolean } = { ["true"] = true, yes = true, on = true, ["1"] = true }
local FALSE: { [string]: boolean } = { ["false"] = true, no = true, off = true, ["0"] = true }

local Boolean: Types.ArgumentTypeProvider<boolean> = {
	Name = "Boolean",

	Validate = function(raw: string): boolean
		local key = string.lower(tostring(raw))

		return TRUE[key] ~= nil or FALSE[key] ~= nil
	end,

	Resolve = function(raw: string): boolean?
		local key = string.lower(tostring(raw))

		if TRUE[key] then
			return true
		elseif FALSE[key] then
			return false
		end

		return nil
	end,

	Suggest = function(prefix: string): { string }
		local out = {}

		for _, option in { "true", "false" } do
			if string.sub(option, 1, #prefix) == string.lower(prefix) then
				table.insert(out, option)
			end
		end

		return out
	end,
}

return Boolean
