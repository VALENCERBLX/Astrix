--!strict

--- `kill <player>` — sets a player's health to zero.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Kill")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Kills a player")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
		})
		:Cooldown(1)
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local humanoid, problem = Shared.Humanoid(target)

				if not humanoid then
					return Astrix.Resolve.Fail(problem)
				end

				humanoid.Health = 0

				return Astrix.Resolve.Ok(`killed {target.Name}`, target.Name)
			end,
		})
		:Register()
end
