--!strict

--- `god <player> [on]` — makes a player unkillable, or mortal again.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("God")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Toggles invincibility")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "On", Type = "Boolean", Required = false },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local humanoid, problem = Shared.Humanoid(target)

				if not humanoid then
					return Astrix.Resolve.Fail(problem)
				end

				local wanted = context.Parsed.On

				if wanted == nil then
					wanted = humanoid.MaxHealth < math.huge
				end

				if wanted then
					humanoid.MaxHealth = math.huge
					humanoid.Health = math.huge
				else
					humanoid.MaxHealth = 100
					humanoid.Health = 100
				end

				return Astrix.Resolve.Ok(`{target.Name} god {if wanted then "on" else "off"}`, wanted)
			end,
		})
		:Register()
end
