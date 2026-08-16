--!strict

--- **Astrix** — an in-game command console for Roblox, driven by **Kyn**, a
--- bash-inspired shell language.
---
--- ```lua
--- local Astrix = require(ReplicatedStorage.Astrix)
---
--- Astrix.Define("Kill")
---     :Type("Server")
---     :Rank(Astrix.Enums.Rank.Admin.Min)
---     :Parsed({ { Name = "Target", Type = "Player", Required = true } })
---     :Tasks({ Server = function(ctx) … end })
---     :Register()
---
--- Astrix.Start()
--- ```
---
--- One `Start` on each side. The server hosts and publishes; the client builds
--- the console and evaluates Kyn. Command definitions replicate schema-only, so
--- a server command is completable on a client that never defined it.
---
--- Part of Valence Libs, by Valence.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Types)
local Enums = require(script.Enums)

local Command = require(script._Classes.Command)
local Session = require(script._Classes.Input)
local Resolve = require(script._Classes.Resolve)
local Content = require(script._Classes.Content)

local Lookup = require(script._Patterns.Lookup)
local Rank = require(script._Patterns.Rank)
local Cooldown = require(script._Patterns.Cooldown)
local Replication = require(script._Patterns.Replication)
local Profile = require(script._Patterns.Profile)

local Providers = require(script._Types)
local Themes = require(script._Themes)
local Functions = require(script._Functions)
local Commands = require(script._Commands)

local Client = require(script._Main.Client)
local Server = require(script._Main.Server)
local Network = require(script._Main.Network)
local Runtime = require(script._Main.Runtime)

--// types
export type CommandDefinition = Types.CommandDefinition
export type ExecutionContext = Types.ExecutionContext
export type CommandResolve = Types.CommandResolve
export type ContentElement = Types.ContentElement
export type AstrixOptions = Types.AstrixOptions
export type AstrixProfile = Types.AstrixProfile
export type Argument = Types.Argument
export type Flag = Types.Flag

--// state -----------------------------------------------------------------------
local registry = Lookup.new()
local ranks = Rank.new()
local cooldowns = Cooldown.new()
local runtime = Runtime.new()

local natives: { [string]: (...any) -> any } = {}
local session: any = nil
local interface: any = nil
local started = false
local builtinsRegistered = false

local Astrix = {}

--// locals ----------------------------------------------------------------------
local function registerBuiltins()
	if builtinsRegistered then
		return
	end

	builtinsRegistered = true

	Functions.Install(natives)
	Commands.Register(Astrix)
end

--- Namespaced lookups available to Kyn. `@Players.Rin` lands here.
local function namespaces(): { [string]: (key: string) -> any }
	return {
		Players = function(name: string): Player?
			local query = string.lower(name)

			for _, player in Players:GetPlayers() do
				if string.lower(player.Name) == query or string.lower(player.DisplayName) == query then
					return player
				end
			end

			for _, player in Players:GetPlayers() do
				if string.sub(string.lower(player.Name), 1, #query) == query then
					return player
				end
			end

			return nil
		end,
	}
end

--- Type constructors available to Kyn: `@Vector3(1, 2, 3)`, `@Enum(Idle)`.
local function constructors(): { [string]: (...any) -> any }
	return {
		Vector3 = function(x: any, y: any, z: any): Vector3
			return Vector3.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
		end,
		Color3 = function(r: any, g: any, b: any): Color3
			return Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
		end,
		--- Kept as a passthrough. Enum *arguments* validate against their
		--- declared `EnumValues`; this constructor is a bare tag with nothing
		--- to check it against, so it hands the name straight back.
		Enum = function(name: any): string
			return tostring(name)
		end,
	}
end

--// public api ------------------------------------------------------------------
Astrix.Enums = Enums
Astrix.Registry = registry
Astrix.Resolve = Resolve
Astrix.Content = Content
Astrix.Themes = Themes
Astrix.Profile = Profile
Astrix.Providers = Providers
Astrix.Replication = Replication
Astrix.Types = Types

--- Starts a definition. Terminate with `:Register()`.
function Astrix.Define(name: string)
	return Command.Define(name, function(definition)
		registry:Add(definition)
	end)
end

--- Registers a Kyn-callable native. The name becomes **absolute** — a player's
--- `@Function` may not shadow it.
function Astrix.Native(name: string, callback: (...any) -> any)
	natives[name] = callback

	if session then
		session.Natives[name] = callback
	end
end

--- Boots Astrix. Call on both sides; each does its own half.
function Astrix.Start(options: AstrixOptions?)
	local settings = options or {}

	registerBuiltins()

	if settings.Rank and settings.Rank.Resolver then
		ranks:Bind(settings.Rank.Resolver)
	end

	if settings.Interface and settings.Interface.InterfaceRank then
		ranks.InterfaceRank = settings.Interface.InterfaceRank
	end

	if RunService:IsServer() then
		Server.Start({
			Registry = registry,
			Ranks = ranks,
			Cooldowns = cooldowns,
			Providers = Providers,
			Runtime = runtime,
			Started = false,
		})

		return
	end

	if started then
		return
	end

	started = true

	--// the client learns server-only commands from the published schemas
	Network.OnPublish(function(definitions)
		for _, schema in definitions do
			if not registry:Resolve(schema.Name) then
				registry:Add(Replication.Hydrate(schema))
			end
		end
	end)

	Network.RequestPublish()

	local Interface = require(script._Main.Interface)

	session = Session.new({
		Natives = natives,
		Namespaces = namespaces(),
		Constructors = constructors(),
	})

	interface = Interface.new({
		Theme = settings.Interface and settings.Interface.Theme,
		Registry = registry,
		Session = session,
		Providers = Providers,
		OnSubmit = function(text)
			Astrix.Run(text)
		end,
	})

	session.Dispatch = Client.MakeDispatch({
		Registry = registry,
		Ranks = ranks,
		Cooldowns = cooldowns,
		Providers = Providers,
		Runtime = runtime,
		Windows = function()
			return interface:Windows()
		end,
		Sink = function(kind, message, content)
			interface:Write(kind, message, content)
		end,
	})

	local keybind = (settings.Interface and settings.Interface.Keybind) or Enum.KeyCode.T

	Astrix.Bind(keybind)
end

--- Runs a Kyn line as if it had been typed. Echoes it and prints every resolve.
function Astrix.Run(text: string): CommandResolve
	if not session then
		return Resolve.Fail("Astrix has not been started on this client")
	end

	if interface then
		interface:Echo(text)
	end

	local last, all = session:Evaluate(text)

	if interface then
		for _, resolve in all do
			interface:Resolve(resolve)
		end
	end

	return last
end

--- Binds the activation key. Below `InterfaceRank` the console will not open.
function Astrix.Bind(key: Enum.KeyCode)
	if not interface then
		return
	end

	interface.Container.App:bind(key, function()
		if not ranks:AllowsInterface(Players.LocalPlayer) then
			return
		end

		interface:Toggle()
	end)
end

--// windows ----------------------------------------------------------------------
--- `Open` / `Close` / `List`, so a command can spawn its own panel. Inside a
--- task prefer `ctx.Windows`, which is this same table.
Astrix.Windows = {
	Open = function(config: Types.WindowConfig)
		return interface and interface.Container:Open(config)
	end,
	Close = function(id: string)
		if interface then
			interface.Container:Close(id)
		end
	end,
	List = function(): { string }
		return if interface then interface.Container:List() else {}
	end,
}

--// ranks -------------------------------------------------------------------------
function Astrix.SetRank(entity: any, rank: number | string): number
	return ranks:Set(entity, rank)
end

function Astrix.GetRank(entity: any): number
	return ranks:Get(entity)
end

function Astrix.BindRanks(resolver: ((entity: any) -> number?)?)
	ranks:Bind(resolver)
end

function Astrix.DefineRank(name: string, value: number)
	ranks:Label(name, value)
end

--// console -----------------------------------------------------------------------
function Astrix.Show()
	if interface then
		interface:Show()
	end
end

function Astrix.Hide()
	if interface then
		interface:Hide()
	end
end

function Astrix.Toggle()
	if interface then
		interface:Toggle()
	end
end

function Astrix.Clear()
	if interface then
		interface:Clear()
	end
end

--- The live Kyn session, for inspecting variables or seeding one.
function Astrix.Session(): any
	return session
end

--- The per-player runtime cache. `Profile.Export` takes an entry from here.
function Astrix.Runtime(): any
	return runtime
end

function Astrix.Destroy()
	if interface then
		interface:Destroy()

		interface = nil
	end

	session = nil
	started = false
end

export type Api = typeof(Astrix)

return Astrix
