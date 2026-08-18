--!strict

--- `rank <player> [level]` — reads or sets a player's rank.
---
--- Owner only, and it will not hand out a rank at or above your own. A console
--- that can promote is a console that can be used to promote whoever borrowed
--- it.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Rank")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Owner.Min)
		:Describe("Reads or sets a player's rank")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Level", Type = "String", Required = false, Description = "a number or a rank name" },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player
				local level = context.Parsed.Level

				if not level then
					local rank = Astrix.GetRank(target)

					return Astrix.Resolve.Ok(`{target.Name} is {rank}`, rank)
				end

				local numeric = tonumber(level)
				local mine = Astrix.GetRank(context.Executor)

				if numeric and numeric >= mine then
					return Astrix.Resolve.Fail("you cannot grant a rank at or above your own")
				end

				local ok, applied = pcall(function()
					return Astrix.SetRank(target, numeric or level)
				end)

				if not ok then
					return Astrix.Resolve.Fail(`unknown rank "{level}"`)
				end

				if applied >= mine then
					--// a named rank could still land too high, so it is checked
					--// again after resolving rather than only before
					Astrix.SetRank(target, 0)

					return Astrix.Resolve.Fail("you cannot grant a rank at or above your own")
				end

				return Astrix.Resolve.Ok(`{target.Name} is now {applied}`, applied)
			end,
		})
		:Register()
end
