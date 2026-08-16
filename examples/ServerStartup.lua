--!strict

--- Server-side startup. A `Script` in `ServerScriptService`.
---
--- The server hosts the transport, publishes command schemas to clients, and
--- runs every `Tasks.Server`. It never sees raw Kyn — only resolved values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Astrix = require(ReplicatedStorage.Astrix)

--// where ranks come from. Returning nil falls through to explicit SetRank
--// assignments and then the default, so this can answer only the cases it
--// knows about.
Astrix.BindRanks(function(entity)
	if typeof(entity) == "Instance" and entity:IsA("Player") then
		if entity.UserId == game.CreatorId then
			return Astrix.Enums.Rank.Owner.Min
		end

		--// swap for a real group or datastore check
		if entity:GetRankInGroup(0) >= 200 then
			return Astrix.Enums.Rank.Admin.Min
		end
	end

	return nil
end)

--// a Server command: the client sends resolved values, this runs here
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

			target:Kick(context.Parsed.Reason)

			return Astrix.Resolve.Ok(`kicked {target.Name}`, target.Name)
		end,
	})
	:Register()

--// a Service command: the server is authoritative, the client plays the
--// feedback once it has said yes
Astrix.Define("Detonate")
	:Type("Service")
	:Rank(Astrix.Enums.Rank.Admin.Min)
	:Describe("Detonates a player")
	:Parsed({
		{ Name = "Target", Type = "Player", Required = true },
	})
	:Flags({
		{ Name = "Radius", Extended = "IsValue", Type = "Number", Default = 12 },
	})
	:Tasks({
		Server = function(context)
			local target = context.Parsed.Target :: Player
			local character = target.Character

			if not character then
				return Astrix.Resolve.Fail(`{target.Name} has no character`)
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid.Health = 0
			end

			--// the Result is handed to Tasks.Local as PriorResult
			return Astrix.Resolve.Ok(`detonated {target.Name}`, {
				Position = character:GetPivot().Position,
				Radius = context.Flags.Radius,
			})
		end,

		Local = function(context, priorResult)
			if not priorResult then
				return nil
			end

			local explosion = Instance.new("Explosion")

			explosion.Position = priorResult.Position
			explosion.BlastRadius = priorResult.Radius
			explosion.Parent = workspace

			return Astrix.Resolve.Ok()
		end,
	})
	:Register()

Astrix.Start()
