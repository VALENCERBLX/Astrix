--!strict

--- The live per-player cache: Kyn session, stats, settings, interface state.
---
--- Nothing here persists. `_Patterns/Profile` exports the half that is worth
--- saving; the session deliberately is not part of it.
--- @section Runtime

local Types = require(script.Parent.Parent.Types)
local Session = require(script.Parent.Parent._Classes.Input)

type RuntimeEntry = Types.RuntimeEntry

local Runtime = {}
Runtime.__index = Runtime

export type Fields = {
	Entries: { [number]: RuntimeEntry },
	SessionConfig: any,
}

export type Runtime = typeof(setmetatable({} :: Fields, Runtime))

local function idOf(player: Player | number): number
	return if type(player) == "number" then player else (player :: Player).UserId
end

function Runtime.new(sessionConfig: any?): Runtime
	local self: Fields = {
		Entries = {},
		SessionConfig = sessionConfig or {},
	}

	return setmetatable(self, Runtime)
end

--- Gets or creates the entry for a player.
function Runtime.Entry(self: Runtime, player: Player | number): RuntimeEntry
	local id = idOf(player)
	local existing = self.Entries[id]

	if existing then
		return existing
	end

	local entry: RuntimeEntry = {
		Session = Session.new(self.SessionConfig),
		Stats = {
			CommandsRun = 0,
			LastActiveAt = os.time(),
		},
		Settings = {
			Theme = "Default",
			Keybind = nil,
		},
		Interface = {
			State = {
				History = {},
				ZOrder = {},
				Focus = nil,
			},
		},
	}

	self.Entries[id] = entry

	return entry
end

function Runtime.Touch(self: Runtime, player: Player | number)
	local entry = Runtime.Entry(self, player)

	entry.Stats.CommandsRun += 1
	entry.Stats.LastActiveAt = os.time()
end

--- Drops a player's entry. Call on `PlayerRemoving`, after exporting anything
--- worth keeping.
function Runtime.Release(self: Runtime, player: Player | number)
	self.Entries[idOf(player)] = nil
end

function Runtime.All(self: Runtime): { [number]: RuntimeEntry }
	return self.Entries
end

return Runtime
