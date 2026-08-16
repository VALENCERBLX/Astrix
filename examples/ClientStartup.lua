--!strict

--- Client-side startup. A `LocalScript` in `StarterPlayerScripts`.
---
--- The console, the Kyn session and every `Tasks.Local` live here. Server-only
--- commands defined on the server arrive as schemas, so they autocomplete
--- without being redefined.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Astrix = require(ReplicatedStorage.Astrix)

--// a Kyn-callable native. The name is absolute from here on: a player's
--// `@Function Distance { … }` will be refused rather than shadowing it.
Astrix.Native("Distance", function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return 0
	end

	return (a - b).Magnitude
end)

--// a Local command, run entirely on this client
Astrix.Define("Zoom")
	:Type("Local")
	:Rank(Astrix.Enums.Rank.Player.Min)
	:Describe("Sets the camera field of view")
	:Parsed({
		{ Name = "Amount", Type = "Number", Required = false, Default = 70 },
	})
	:Tasks({
		Local = function(context)
			local camera = workspace.CurrentCamera

			if not camera then
				return Astrix.Resolve.Fail("no camera")
			end

			camera.FieldOfView = math.clamp(context.Parsed.Amount, 1, 120)

			return Astrix.Resolve.Ok(`fov {camera.FieldOfView}`, camera.FieldOfView)
		end,
	})
	:Register()

--// a command that opens its own window, using ctx.Windows rather than the
--// module-level Astrix global
Astrix.Define("Stats")
	:Type("Local")
	:Rank(Astrix.Enums.Rank.Player.Min)
	:Describe("Opens a stats panel")
	:Tasks({
		Local = function(context)
			context.Windows.Open({ Id = "Stats", Title = "Stats", Docked = true })

			context.Windows.Write(
				"Stats",
				"",
				context.Output.Elements.Table({ "Stat", "Value" }, {
					{ "FPS", tostring(math.floor(1 / workspace:GetRealPhysicsFPS() * 1000)) },
					{ "Ping", "—" },
				})
			)

			return Astrix.Resolve.Ok()
		end,
	})
	:Register()

Astrix.Start({
	Interface = {
		Theme = "Default",
		Keybind = Enum.KeyCode.T,
		--// below this rank the console will not open at all, whatever the
		--// individual command ranks say
		InterfaceRank = Astrix.Enums.Rank.Player.Min,
	},
})

--// try, once it is open:
--
--   @Set("Target", @Players.Rin)
--   Teleport @Target @Vector3(0, 50, 0) >> Zoom 40 : Help
--   Help | echo
