--!strict

--- `teleport <player> <position>` — the spec's worked example, as a real
--- command.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Teleport")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Teleports a player to a position")
		:Aliases({ "Tp" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Destination", Type = "Vector3", Required = true },
		})
		:Flags({
			{ Name = "Instant", Extended = "IsBool", Description = "skip the fade" },
		})
		:Cooldown(1)
		:Tasks({
			Local = function(context)
				local target = context.Parsed.Target :: Player
				local destination = context.Parsed.Destination :: Vector3

				local character = target.Character

				if not character then
					return Astrix.Resolve.Fail(`{target.Name} has no character`)
				end

				local root = character:FindFirstChild("HumanoidRootPart")

				if not root then
					return Astrix.Resolve.Fail(`{target.Name} has no root part`)
				end

				;(root :: BasePart).CFrame = CFrame.new(destination)

				return Astrix.Resolve.Ok(`teleported {target.Name}`, target)
			end,
		})
		:Register()
end
