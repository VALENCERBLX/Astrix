--!strict

--- `jump <player> [amount]` — jump power, 50 by default.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Jump")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Sets a player's jump power")
		:Aliases({ "JumpPower", "JP" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Amount", Type = "Number", Required = false, Default = 50 },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local humanoid, problem = Shared.Humanoid(target)

				if not humanoid then
					return Astrix.Resolve.Fail(problem)
				end

				--// UseJumpPower is off by default on newer rigs, and setting
				--// JumpPower silently does nothing while it is
				humanoid.UseJumpPower = true
				humanoid.JumpPower = math.clamp(context.Parsed.Amount, 0, 1000)

				return Astrix.Resolve.Ok(`{target.Name} jump {humanoid.JumpPower}`, humanoid.JumpPower)
			end,
		})
		:Register()
end
