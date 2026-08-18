--!strict

--- `speed <player> [amount]` — walk speed, 16 by default.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Speed")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Sets a player's walk speed")
		:Aliases({ "WalkSpeed", "WS" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Amount", Type = "Number", Required = false, Default = 16 },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local humanoid, problem = Shared.Humanoid(target)

				if not humanoid then
					return Astrix.Resolve.Fail(problem)
				end

				humanoid.WalkSpeed = math.clamp(context.Parsed.Amount, 0, 500)

				return Astrix.Resolve.Ok(`{target.Name} speed {humanoid.WalkSpeed}`, humanoid.WalkSpeed)
			end,
		})
		:Register()
end
