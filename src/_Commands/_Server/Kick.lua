--!strict

--- `kick <player> [reason]` — removes a player from the server.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Kick")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Removes a player from the server")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Reason", Type = "String", Required = false, Default = "No reason given" },
		})
		:Cooldown(3)
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player

				--// refuse to kick somebody who outranks you, or an admin can
				--// remove the owner
				if Astrix.GetRank(target) >= Astrix.GetRank(context.Executor) and target ~= context.Executor then
					return Astrix.Resolve.Fail(`{target.Name} outranks you`)
				end

				local name = target.Name

				target:Kick(context.Parsed.Reason)

				return Astrix.Resolve.Ok(`kicked {name}`, name)
			end,
		})
		:Register()
end
