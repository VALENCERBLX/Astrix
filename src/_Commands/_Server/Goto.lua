--!strict

--- `goto <player>` — teleports whoever ran it to a player.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Goto")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Teleports you to a player")
		:Aliases({ "To" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
		})
		:Cooldown(1)
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player

				local targetRoot, targetProblem = Shared.Root(target)
				local ownRoot, ownProblem = Shared.Root(context.Executor)

				if not targetRoot then
					return Astrix.Resolve.Fail(targetProblem)
				end

				if not ownRoot then
					return Astrix.Resolve.Fail(ownProblem)
				end

				ownRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -4)

				return Astrix.Resolve.Ok(`went to {target.Name}`, target.Name)
			end,
		})
		:Register()
end
