--!strict

--- Accepts `1,2,3` or `1 2 3`. The `@Vector3(1, 2, 3)` constructor form is
--- handled by the Kyn session and arrives here already typed.

local Types = require(script.Parent.Parent.Types)

local function parse(raw: string): Vector3?
	local parts = {}

	for piece in string.gmatch(tostring(raw), "[^,%s]+") do
		local number = tonumber(piece)

		if not number then
			return nil
		end

		table.insert(parts, number)
	end

	if #parts ~= 3 then
		return nil
	end

	return Vector3.new(parts[1], parts[2], parts[3])
end

local Provider: Types.ArgumentTypeProvider<Vector3> = {
	Name = "Vector3",

	Validate = function(raw: string): boolean
		return parse(raw) ~= nil
	end,

	Resolve = function(raw: string): Vector3?
		return parse(raw)
	end,

	Suggest = function(): { string }
		return { "0,0,0" }
	end,
}

return Provider
