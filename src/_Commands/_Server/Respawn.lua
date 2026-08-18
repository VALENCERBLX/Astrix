--!strict

--- `respawn <player>` — reloads a player's character.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Respawn")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Respawns a player")
		:Aliases({ "Re" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
		})
		:Cooldown(2)
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player

				target:LoadCharacter()

				return Astrix.Resolve.Ok(`respawned {target.Name}`, target.Name)
			end,
		})
		:Register()
end
