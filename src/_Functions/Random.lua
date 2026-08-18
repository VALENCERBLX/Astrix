--!strict

--- `@Random(Min, Max)` — an inclusive integer roll.
---
--- Registered as a native, which makes the name **absolute**: a player writing
--- `@Function Random { … }` gets a refusal rather than a shadowed builtin.
--- @section Kyn

return {
	Name = "Random",

	Run = function(min: any, max: any): number
		local low = tonumber(min) or 0
		local high = tonumber(max) or 1

		if low > high then
			low, high = high, low
		end

		return math.random(math.floor(low), math.floor(high))
	end,
}
