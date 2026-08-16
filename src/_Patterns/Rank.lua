--!strict

--- Numeric ranks. A player may run a command when their rank is at least the
--- command's `Rank`.
---
--- `InterfaceRank` is a **separate** gate: below it a player cannot summon the
--- console at all. Above it, every command is still checked against its own
--- `Rank`. The two are independent on purpose — "can open the console" and
--- "can run this" are different questions.

--- The rank bands.
---
--- **Placeholder values.** `Player 0-99`, `Admin 100-199`, `Owner 200` was
--- never confirmed in design; confirm before shipping, because changing them
--- later silently changes who can run what.
---
--- They live here rather than in a separate Enums module so the numbers and the
--- code that compares them cannot drift apart. `Astrix.Enums.Rank` is this
--- table.
local Bands = {
	Player = { Min = 0, Max = 99 },
	Admin = { Min = 100, Max = 199 },
	Owner = { Min = 200, Max = 200 },
}

local Rank = {}
Rank.__index = Rank

Rank.Bands = Bands

export type Resolver = (Entity: any) -> number?

export type Fields = {
	Assignments: { [number]: number },
	Labels: { [string]: number },
	Resolver: Resolver?,
	Default: number,
	InterfaceRank: number,
}

export type Ranks = typeof(setmetatable({} :: Fields, Rank))

local function userIdOf(entity: any): number?
	if typeof(entity) == "Instance" and (entity :: Instance):IsA("Player") then
		return (entity :: Player).UserId
	end

	return tonumber(entity)
end

function Rank.new(): Ranks
	local self: Fields = {
		Assignments = {},
		Labels = {
			player = Bands.Player.Min,
			admin = Bands.Admin.Min,
			owner = Bands.Owner.Min,
		},
		Resolver = nil,
		Default = Bands.Player.Min,
		InterfaceRank = Bands.Player.Min,
	}

	return setmetatable(self, Rank)
end

--- Assigns a rank by user id. `rank` may be a number or a registered label.
function Rank.Set(self: Ranks, entity: any, rank: number | string): number
	local id = userIdOf(entity)

	assert(id, "cannot resolve that entity to a user id")

	local value = if type(rank) == "number" then rank else self.Labels[string.lower(rank :: string)]

	assert(value, `unknown rank '{tostring(rank)}'`)

	self.Assignments[id] = value

	return value
end

--- Reads a rank. A bound resolver wins; returning nil from it falls through to
--- explicit assignments and then the default.
function Rank.Get(self: Ranks, entity: any): number
	if self.Resolver then
		local ok, value = pcall(self.Resolver, entity)

		if ok and type(value) == "number" then
			return value
		end
	end

	local id = userIdOf(entity)

	if id and self.Assignments[id] then
		return self.Assignments[id]
	end

	return self.Default
end

--- Plugs in your own rank source — a group check, a datastore, a leaderboard.
function Rank.Bind(self: Ranks, resolver: Resolver?)
	self.Resolver = resolver
end

function Rank.Label(self: Ranks, name: string, value: number)
	self.Labels[string.lower(name)] = value
end

function Rank.Allows(self: Ranks, playerRank: number, required: number): boolean
	return playerRank >= required
end

--- Whether this entity may open the console at all.
function Rank.AllowsInterface(self: Ranks, entity: any): boolean
	return Rank.Get(self, entity) >= self.InterfaceRank
end

--- The band a numeric rank falls in, for display.
function Rank.BandOf(self: Ranks, value: number): string
	if value >= Bands.Owner.Min then
		return "Owner"
	elseif value >= Bands.Admin.Min then
		return "Admin"
	end

	return "Player"
end

return Rank
