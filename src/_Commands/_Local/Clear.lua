--!strict

--- `clear` — empties the console's history.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Clear")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Clears the console output")
		:Aliases({ "Cls" })
		:Tasks({
			Local = function()
				Astrix.Clear()

				return Astrix.Resolve.Ok()
			end,
		})
		:Register()
end
