--!strict

--- The server half: hosts `Tasks.Server` and publishes schema-only definitions.
---
--- Publishing is what makes a server-only command usable from a client that
--- never defined it — the client learns the command's *shape* (name, aliases,
--- arguments, flags, rank, cooldown) so autocomplete and argument hints work,
--- while the function stays here.
--- @section Runtime

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Replication = require(script.Parent.Parent._Patterns.Replication)
local Network = require(script.Parent.Network)
local Client = require(script.Parent.Client)

local Server = {}

export type Fields = {
	Registry: any,
	Ranks: any,
	Cooldowns: any,
	Providers: { [string]: any },
	Runtime: any,
	Started: boolean,
}

--- Stands the server up: binds the invoke handler, publishes to everybody who
--- is already here, and republishes whenever the registry changes or somebody
--- joins.
function Server.Start(deps: Fields)
	assert(RunService:IsServer(), "Astrix.Start with Type Server must run on the server")

	if deps.Started then
		return
	end

	deps.Started = true

	Network.Host(Client.MakeServerHandler({
		Registry = deps.Registry,
		Ranks = deps.Ranks,
		Cooldowns = deps.Cooldowns,
		Providers = deps.Providers,
		Runtime = deps.Runtime,
	}))

	local function publish(player: Player?)
		Network.Publish(Replication.StripAll(deps.Registry:List()), player)
	end

	--- Tells a client its own rank, so its pre-dispatch check has the same
	--- number the server will use.
	local function publishRank(player: Player)
		Network.PublishRank(player, deps.Ranks:Get(player))
	end

	--// pushed whenever anything changes it, not only on join: a rank granted
	--// mid-session has to reach the client or their console keeps refusing
	--// commands the server would happily run
	deps.Ranks.OnChanged = function(player: Player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			publishRank(player)
		end
	end

	--// a client that finishes loading after the first publish would otherwise
	--// never learn the command set
	Players.PlayerAdded:Connect(function(player)
		publish(player)
		publishRank(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if deps.Runtime then
			deps.Runtime:Release(player)
		end
	end)

	deps.Registry:Watch(function()
		publish(nil)
	end)

	for _, player in Players:GetPlayers() do
		publish(player)
		publishRank(player)
	end
end

--- Publishes the current command set on demand.
function Server.Publish(deps: Fields, player: Player?)
	Network.Publish(Replication.StripAll(deps.Registry:List()), player)
end

return Server
