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
--- @section Overview

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Types)

local Command = require(script._Classes.Command)
local Session = require(script._Classes.Input)
local Resolve = require(script._Classes.Resolve)
local Content = require(script._Classes.Content)

local Lookup = require(script._Patterns.Lookup)
local Rank = require(script._Patterns.Rank)
local Cooldown = require(script._Patterns.Cooldown)
local Replication = require(script._Patterns.Replication)
local Profile = require(script._Patterns.Profile)

local Themes = require(script._Themes)
local Functions = require(script._Functions)

--// `_Types` is a plain Folder, so its providers are required one by one and
--// assembled here. Add your own by assigning into this table before `Start`.
local Providers: { [string]: any } = {
	String = require(script._Types.String),
	Number = require(script._Types.Number),
	Boolean = require(script._Types.Boolean),
	Player = require(script._Types.Player),
	Vector3 = require(script._Types.Vector3),
	Enum = require(script._Types.Enum),
}

--// `_Commands` is a plain Folder too; each subfolder is its own manifest
local Manifests = {
	require(script._Commands._Local),
	require(script._Commands._Server),
	require(script._Commands._Service),
}

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

--// enums -----------------------------------------------------------------------
--// `Rank` is `_Patterns/Rank`'s own band table, not a copy, so the numbers
--// and the code comparing them cannot drift apart
local Enums = table.freeze({
	Rank = Rank.Bands,

	CommandType = table.freeze({ Local = "Local", Server = "Server", Service = "Service" }),
	FlagKind = table.freeze({ IsValue = "IsValue", IsBool = "IsBool" }),

	ArgumentType = table.freeze({
		String = "String",
		Number = "Number",
		Boolean = "Boolean",
		Player = "Player",
		Vector3 = "Vector3",
		Enum = "Enum",
	}),

	Resolve = table.freeze({
		Ok = "Ok",
		Fail = "Fail",
		Warn = "Warn",
		CommandNotFound = "CommandNotFound",
		RankDenied = "RankDenied",
		OnCooldown = "OnCooldown",
		ParseFailed = "ParseFailed",
		AbsoluteOverwrite = "AbsoluteOverwrite",
	}),

	HistoryKind = table.freeze({
		Input = "Input",
		Output = "Output",
		Ok = "Ok",
		Fail = "Fail",
		Warn = "Warn",
	}),
})

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
local bound = false

--// Konsole used activationPriority 10001, above anything a game is likely to
--// bind, so the console always wins the key
local ACTION = "AstrixToggle"
local ACTION_PRIORITY = 10001

local Astrix = {}

--// locals ----------------------------------------------------------------------
local function registerBuiltins()
	if builtinsRegistered then
		return
	end

	builtinsRegistered = true

	Functions.Install(natives)

	for _, manifest in Manifests do
		for _, define in manifest do
			define(Astrix)
		end
	end
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
		--// kept as a passthrough. Enum *arguments* validate against their
		--// declared `EnumValues`; this constructor is a bare tag with nothing
		--// to check it against, so it hands the name straight back
		Enum = function(name: any): string
			return tostring(name)
		end,
	}
end

--// public api ------------------------------------------------------------------
Astrix.Version = "0.1.0"
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

--- Starts a **sub-command** definition.
---
--- Identical to `Define` but unregistered: the result is handed to a parent's
--- `:Subs{…}` rather than registered on its own. Do not call `:Register()` on
--- one — the parent freezes it.
function Astrix.Sub(name: string)
	return Command.Define(name, nil)
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

	local cycleTimeout = settings.Interface and settings.Interface.CycleTimeout

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

	--// the client learns server-only commands from the published schemas.
	--
	--// Spawned, not awaited: the transport waits on instances the server
	--// creates, so a client that boots first — or a place with no server half
	--// at all — would otherwise stall here before the console ever opened.
	task.spawn(function()
		Network.OnPublish(function(definitions)
			for _, schema in definitions do
				if not registry:Resolve(schema.Name) then
					registry:Add(Replication.Hydrate(schema))
				end
			end
		end)

		--// the client checks rank before dispatching, so it needs the number
		--// the server is using. Without this every player looks like rank zero
		--// client-side and anything above Player is refused locally, before the
		--// server ever hears about it
		Network.OnRank(function(rank: number)
			local player = Players.LocalPlayer

			if player then
				ranks.Assignments[player.UserId] = rank
			end
		end)

		Network.RequestPublish()
	end)

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

	if cycleTimeout then
		interface:SetCycleTimeout(cycleTimeout)
	end

	local keybind = (settings.Interface and settings.Interface.Keybind) or Enum.KeyCode.T

	Astrix.Bind(keybind)
end

--- Runs a Kyn line as if it had been typed. Echoes it and prints every resolve.
function Astrix.Run(text: string): CommandResolve
	if not session then
		return Resolve.Fail("Astrix has not been started on this client")
	end

	if interface then
		--// running anything opens the bar into a terminal, the way a console
		--// grows the moment it has something to say
		interface:Reveal()
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
---
--- Bound through ContextActionService at high priority rather than a plain
--- InputBegan listener. A listener sees `gameProcessedEvent` go true whenever
--- anything else in the place has already claimed the key — another admin
--- system, a chat box, a vehicle script — and silently does nothing, which is
--- the usual reason an activation key "doesn't work". Binding an action takes
--- the key first and sinks it, so it neither misses nor leaks through.
function Astrix.Bind(key: Enum.KeyCode)
	if not interface then
		return
	end

	if bound then
		ContextActionService:UnbindAction(ACTION)
	end

	bound = true

	ContextActionService:BindActionAtPriority(
		ACTION,
		function(_, state: Enum.UserInputState)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end

			if not ranks:AllowsInterface(Players.LocalPlayer) then
				return Enum.ContextActionResult.Pass
			end

			interface:Toggle()

			return Enum.ContextActionResult.Sink
		end,
		false,
		ACTION_PRIORITY,
		key
	)
end

--- Releases the activation key.
function Astrix.Unbind()
	if bound then
		ContextActionService:UnbindAction(ACTION)

		bound = false
	end
end

--// windows ----------------------------------------------------------------------
--// `Open` / `Close` / `List`, so a command can spawn its own panel. Inside a
--// task prefer `ctx.Windows`, which is this same table
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

	--- The window that currently has the caret. Output goes here, so this is
	--- also "where the next command's result will appear".
	Focused = function(): string?
		return if interface then interface:Target() else nil
	end,

	--- Moves focus to a window and re-points the completion dropdown at it.
	Focus = function(id: string)
		if interface then
			interface:FocusWindow(id)
		end
	end,

	--- Most-recently-focused first — the order the activation key walks.
	Recency = function(): { string }
		return if interface then interface.Container:Recency() else {}
	end,
}

--- How long a run of activation-key presses counts as one cycle, in seconds.
--- 1.5 by default; set it to zero to switch cycling off entirely.
function Astrix.SetCycleTimeout(seconds: number)
	if interface then
		interface:SetCycleTimeout(seconds)
	end
end

--- How many console windows may exist at once. Three by default; opening past
--- it warns rather than stacking without limit.
function Astrix.SetMaxWindows(count: number)
	if interface then
		interface:SetMaxWindows(count)
	end
end

--// theming ----------------------------------------------------------------------
--- Switches the console theme. Returns false if no theme by that name exists.
function Astrix.SetTheme(name: string): boolean
	if not interface then
		return false
	end

	return interface:SetTheme(name) ~= nil
end

function Astrix.CurrentTheme(): string
	return if interface then interface:ThemeName() else "Default"
end

--- Registers a theme, optionally extending an existing one.
function Astrix.DefineTheme(name: string, tokens: { [string]: any }, extends: string?)
	return Themes.Register(name, tokens, extends)
end

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
	Astrix.Unbind()

	if interface then
		interface:Destroy()

		interface = nil
	end

	session = nil
	started = false
end

export type Api = typeof(Astrix)

return Astrix
