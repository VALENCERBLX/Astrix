--!strict

--- `bring <player>` — teleports a player to whoever ran it.
--- @section Commands

local Shared = require(script.Parent._Shared)

return function(Astrix: any)
	Astrix.Define("Bring")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Teleports a player to you")
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

				--// a few studs in front, so the two do not end up inside
				--// each other
				targetRoot.CFrame = ownRoot.CFrame * CFrame.new(0, 0, -4)

				return Astrix.Resolve.Ok(`brought {target.Name}`, target.Name)
			end,
		})
		:Register()
end
