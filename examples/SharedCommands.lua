--!strict

--- **Commands both sides know about.**
---
--- Put this in `ReplicatedStorage` as a ModuleScript and require it from *both*
--- startup scripts. That is the whole trick to `Service` commands.
---
--- A `Service` command runs on both sides: the server half does the
--- authoritative thing, the client half does something on the screen of whoever
--- ran it. Both halves have to *exist* on the machine that runs them, and
--- functions do not survive a trip across the network — the client only ever
--- receives a command's schema (its name, arguments, flags and rank) so that
--- autocomplete and argument hints work for server-only commands.
---
--- So a `Service` command defined in a `Script` is a server-only command with a
--- client half that does not exist, and running it fails with exactly that
--- message. Define it here instead and both sides get the real thing.
---
--- ```lua
--- -- ServerScriptService/Startup (a Script)
--- local Astrix = require(ReplicatedStorage.Astrix)
--- require(ReplicatedStorage.SharedCommands)(Astrix)
--- Astrix.Start()
---
--- -- StarterPlayerScripts/Startup (a LocalScript)
--- local Astrix = require(ReplicatedStorage.Astrix)
--- require(ReplicatedStorage.SharedCommands)(Astrix)
--- Astrix.Start({ Interface = { Keybind = Enum.KeyCode.Semicolon } })
--- ```

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flare = require(ReplicatedStorage:WaitForChild("Flare"))

--// the announcement itself goes over a remote, because a Service command's
--// client half only runs on the machine that *ran* the command. Everybody
--// else hears about it the ordinary way.
local function channel(): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild("AstrixAnnounce")

	if existing then
		return existing :: RemoteEvent
	end

	if RunService:IsServer() then
		local made = Instance.new("RemoteEvent")

		made.Name = "AstrixAnnounce"
		made.Parent = ReplicatedStorage

		return made
	end

	return ReplicatedStorage:WaitForChild("AstrixAnnounce") :: RemoteEvent
end

return function(Astrix: any)
	local announce = channel()

	--// every client shows the banner, whoever sent it
	if RunService:IsClient() then
		announce.OnClientEvent:Connect(function(author: string, message: string)
			Flare.Banner(`*{author}*: {message}`)
				:Title("Announcement")
				:Accent()
				:Duration(8)
				:Priority(10)
				:Show()
		end)
	end

	--- A Service command: the server sends it, the caller's own client
	--- acknowledges it. Both halves live here, so both halves exist.
	Astrix.Define("Admit")
		:Type("Service")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Announces a message to every player")
		:Parsed({
			{ Name = "Message", Type = "String", Required = true },
		})
		:Tasks({
			--// runs on the server, once, with a real Player as Executor
			Server = function(context)
				announce:FireAllClients(context.Executor.DisplayName, context.Parsed.Message)

				return Astrix.Resolve.Ok(`Announced: "{context.Parsed.Message}"`)
			end,

			--// runs on the client that typed it, *after* the server half
			--// resolved. `prior` is whatever the server returned as its Result.
			Local = function(context, prior)
				Flare.Toast("Announcement sent"):Ok():Show()

				return Astrix.Resolve.Ok(`Announced: "{context.Parsed.Message}"`)
			end,
		})
		:Register()

	--- `LocalFirst` flips the order: the client half runs immediately for
	--- instant feedback, then the server half decides what really happened.
	--- Reach for it when the local half is a visual acknowledgement and waiting
	--- a round trip for it would feel laggy.
	Astrix.Define("Roundtrip")
		:Type("Service")
		:Rank(0)
		:Describe("Round trip to the server and back")
		:LocalFirst(true)
		:Tasks({
			Local = function()
				Flare.Toast("Pinging…"):Info():Duration(2):Show()

				return Astrix.Resolve.Ok("sent")
			end,
			Server = function()
				return Astrix.Resolve.Ok(`pong from {RunService:IsServer() and "server" or "?"}`)
			end,
		})
		:Register()

	--- Not everything needs both halves. A command that only touches the
	--- screen is `Local`, and never leaves the client.
	Astrix.Define("Celebrate")
		:Type("Local")
		:Rank(0)
		:Describe("Fires a notification, locally")
		:Parsed({
			{ Name = "Reason", Type = "String", Required = false, Default = "No reason" },
		})
		:Tasks({
			Local = function(context)
				Flare.Achievement("Nice", context.Parsed.Reason):Show()

				return Astrix.Resolve.Ok("celebrated")
			end,
		})
		:Register()

	--- And one that only touches the game is `Server`. The client still gets
	--- its schema, so `Heal <tab>` still completes and still argument-hints —
	--- it just never sees the function.
	Astrix.Define("Restore")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Heals a player to full")
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
		})
		:Tasks({
			Server = function(context)
				local character = context.Parsed.Target.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if not humanoid then
					return Astrix.Resolve.Fail("they have no character right now")
				end

				humanoid.Health = humanoid.MaxHealth

				return Astrix.Resolve.Ok(`healed {context.Parsed.Target.DisplayName}`)
			end,
		})
		:Register()
end
