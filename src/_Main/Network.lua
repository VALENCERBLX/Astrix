--!strict

--- Transport between client and server.
---
--- **This is the placeholder implementation.** It uses a plain
--- `RemoteFunction` plus a `RemoteEvent`, which works, but Substance is
--- vendored and this is meant to run on Substance channels instead — open
--- item #4. The surface below is deliberately the shape Substance would give,
--- so swapping it is a change in this file only.
---
--- Two directions:
--- * client → server: invoke a command, block for its resolve
--- * server → client: publish schema-only definitions on join and on change

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Resolve = require(script.Parent.Parent._Classes.Resolve)

type CommandResolve = Types.CommandResolve
type ReplicatedDefinition = Types.ReplicatedDefinition

local Network = {}

local FOLDER = "AstrixNetwork"
local INVOKE = "Invoke"
local PUBLISH = "Publish"

--- The transport folder. Nil on a client whose server has not hosted yet —
--- which is a normal state, not an error, so every caller handles it.
local function container(): Folder?
	local existing = ReplicatedStorage:FindFirstChild(FOLDER)

	if existing then
		return existing :: Folder
	end

	if not RunService:IsServer() then
		--// the client waits for the server to build it. Callers run this on a
		--// spawned thread, so the wait never blocks the console from opening
		return ReplicatedStorage:WaitForChild(FOLDER, 10) :: Folder?
	end

	local folder = Instance.new("Folder")

	folder.Name = FOLDER
	folder.Parent = ReplicatedStorage

	return folder
end

local function remote(class: string, name: string): Instance?
	local parent = container()

	if not parent then
		return nil
	end

	local existing = parent:FindFirstChild(name)

	if existing then
		return existing
	end

	if not RunService:IsServer() then
		return parent:WaitForChild(name, 10)
	end

	local instance = Instance.new(class)

	instance.Name = name
	instance.Parent = parent

	return instance
end

--// server ---------------------------------------------------------------------
--- Stands the transport up and binds the handler that runs `Tasks.Server`.
function Network.Host(handler: (player: Player, name: string, args: { any }, flags: { [string]: any }, raw: string, prior: any) -> CommandResolve)
	assert(RunService:IsServer(), "Network.Host is server-only")

	local invoke = remote("RemoteFunction", INVOKE) :: RemoteFunction

	assert(invoke, "Astrix could not create its transport")

	invoke.OnServerInvoke = function(player: Player, payload: any): any
		if type(payload) ~= "table" then
			return Resolve.Fail("malformed request")
		end

		local name = payload.Name

		if type(name) ~= "string" then
			return Resolve.Fail("malformed request")
		end

		--// never trust the client's copy of anything but the values it typed;
		--// rank and cooldown are re-checked server-side by the handler
		local ok, result = pcall(
			handler,
			player,
			name,
			if type(payload.Args) == "table" then payload.Args else {},
			if type(payload.Flags) == "table" then payload.Flags else {},
			tostring(payload.Raw or ""),
			payload.Prior
		)

		if not ok then
			warn(`[Astrix] server task for '{name}' errored: {result}`)

			return Resolve.Fail(`Failed to run Command [{name}]: server error`)
		end

		return result
	end

	remote("RemoteEvent", PUBLISH)
end

--- Sends the schema-only definitions to one player, or everybody.
function Network.Publish(definitions: { ReplicatedDefinition }, player: Player?)
	assert(RunService:IsServer(), "Network.Publish is server-only")

	local publish = remote("RemoteEvent", PUBLISH) :: RemoteEvent?

	if not publish then
		return
	end

	if player then
		publish:FireClient(player, definitions)

		return
	end

	publish:FireAllClients(definitions)
end

--// client ---------------------------------------------------------------------
--- Invokes a server command and blocks for its resolve.
function Network.InvokeServer(name: string, args: { any }, flags: { [string]: any }, raw: string, prior: any?): CommandResolve
	local invoke = remote("RemoteFunction", INVOKE) :: RemoteFunction?

	if not invoke then
		return Resolve.Fail("Astrix is not hosted on the server")
	end

	local ok, result = pcall(function()
		return invoke:InvokeServer({
			Name = name,
			Args = args,
			Flags = flags,
			Raw = raw,
			Prior = prior,
		})
	end)

	if not ok then
		return Resolve.Fail(`Failed to run Command [{name}]: {tostring(result)}`)
	end

	return Resolve.From(result)
end

--- Listens for published definitions.
function Network.OnPublish(handler: (definitions: { ReplicatedDefinition }) -> ()): RBXScriptConnection?
	local publish = remote("RemoteEvent", PUBLISH) :: RemoteEvent?

	if not publish then
		return nil
	end

	return publish.OnClientEvent:Connect(handler)
end

--- Asks the server to resend, for a client that started late.
function Network.RequestPublish()
	local publish = remote("RemoteEvent", PUBLISH) :: RemoteEvent?

	if publish then
		publish:FireServer()
	end
end

return Network
