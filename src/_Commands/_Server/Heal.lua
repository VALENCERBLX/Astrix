--!strict

--- `heal <player> [amount]` — restores health, to full by default.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Heal")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Restores a player's health")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Amount", Type = "Number", Required = false },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local humanoid, problem = Shared.Humanoid(target)

				if not humanoid then
					return Astrix.Resolve.Fail(problem)
				end

				local amount = context.Parsed.Amount

				humanoid.Health = if amount
					then math.clamp(amount, 0, humanoid.MaxHealth)
					else humanoid.MaxHealth

				return Astrix.Resolve.Ok(`healed {target.Name} to {math.floor(humanoid.Health)}`, humanoid.Health)
			end,
		})
		:Register()
end
