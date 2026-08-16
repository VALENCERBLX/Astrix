--!strict

--- Explicit export and import of a player's `Settings` and `Stats`.
---
--- Astrix does **not** persist anything by itself. Plug these into whatever
--- DataStore or ProfileStore flow the game already has.
---
--- `Session` is deliberately excluded: variables, `@Function` definitions and
--- the `::Kout` stack are ephemeral by design. A saved `@Set("Target", …)`
--- would restore a reference to a player who left.

local Types = require(script.Parent.Parent.Types)

type RuntimeEntry = Types.RuntimeEntry
type AstrixProfile = Types.AstrixProfile

local Profile = {}

--- Snapshots the persistable half of a runtime entry.
---
--- The keybind is stored as `Enum.KeyCode.Value`, a plain number, because an
--- EnumItem does not survive a DataStore round trip.
function Profile.Export(entry: RuntimeEntry): AstrixProfile
	return {
		Settings = {
			Theme = entry.Settings.Theme,
			Keybind = if entry.Settings.Keybind then entry.Settings.Keybind.Value else nil,
		},
		Stats = {
			CommandsRun = entry.Stats.CommandsRun,
			LastActiveAt = entry.Stats.LastActiveAt,
		},
	}
end

local function keyCodeFrom(value: number?): Enum.KeyCode?
	if not value then
		return nil
	end

	for _, item in Enum.KeyCode:GetEnumItems() do
		if item.Value == value then
			return item
		end
	end

	return nil
end

--- Applies a saved profile onto a live entry, leaving the session alone.
function Profile.Import(entry: RuntimeEntry, data: AstrixProfile?)
	if type(data) ~= "table" then
		return
	end

	local settings = data.Settings

	if type(settings) == "table" then
		if type(settings.Theme) == "string" then
			entry.Settings.Theme = settings.Theme
		end

		local keybind = keyCodeFrom(settings.Keybind)

		if keybind then
			entry.Settings.Keybind = keybind
		end
	end

	local stats = data.Stats

	if type(stats) == "table" then
		entry.Stats.CommandsRun = tonumber(stats.CommandsRun) or entry.Stats.CommandsRun
		entry.Stats.LastActiveAt = tonumber(stats.LastActiveAt) or entry.Stats.LastActiveAt
	end
end

return Profile
