--!strict

--- `gravity [amount]` — workspace gravity, 196.2 by default.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Gravity")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Sets workspace gravity")
		:Aliases({ "Grav" })
		:Parsed({
			{ Name = "Amount", Type = "Number", Required = false, Default = 196.2 },
		})
		:Tasks({
			Server = function(context)
				workspace.Gravity = math.clamp(context.Parsed.Amount, 0, 10000)

				return Astrix.Resolve.Ok(`gravity {workspace.Gravity}`, workspace.Gravity)
			end,
		})
		:Register()
end
