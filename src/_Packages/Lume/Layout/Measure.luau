--!strict

--- Cached text measurement. Every element sizes itself through one of these
--- rather than calling TextService directly, so a theme change flushes a single
--- cache and a list of two hundred rows measures each distinct string once.
---
--- The cache is capped; passing it a stream of unique strings (a live clock,
--- say) degrades to plain measurement instead of growing without bound.
--- @section Layout

local TextService = game:GetService("TextService")

local Types = require(script.Parent.Parent.Types)

local Measure = {}
Measure.__index = Measure

local UNBOUNDED = Vector2.new(100000, 100000)
local CAPACITY = 4096

export type Fields = {
	cache: { [string]: Vector2 },
	entries: number,
}

--- Creates an empty measurement cache.
function Measure.new(): Types.Measurer
	local self: Fields = {
		cache = {},
		entries = 0,
	}

	return setmetatable(self, Measure) :: any
end

--- Measures a string. `width` bounds wrapping; omit it for a single line.
function Measure.text(
	self: Fields & Types.Measurer,
	text: string,
	size: number,
	font: Enum.Font,
	width: number?
): Vector2
	if text == "" then
		return Vector2.new(0, size)
	end

	local key = `{size}|{font.Value}|{width or -1}|{text}`
	local hit = self.cache[key]

	if hit then
		return hit
	end

	local bounds = if width then Vector2.new(width, UNBOUNDED.Y) else UNBOUNDED

	local ok, result = pcall(function()
		return TextService:GetTextSize(text, size, font, bounds)
	end)

	local measured = if ok and result then result else Vector2.new(#text * size * 0.5, size)

	if self.entries >= CAPACITY then
		self:flush()
	end

	self.cache[key] = measured
	self.entries += 1

	return measured
end

--- Width of a single unwrapped line.
function Measure.width(self: Fields & Types.Measurer, text: string, size: number, font: Enum.Font): number
	return Measure.text(self, text, size, font).X
end

--- Height of one line in this font and size.
function Measure.lineHeight(self: Fields & Types.Measurer, size: number, font: Enum.Font): number
	--// two lines measured together, halved: dodges the per-font padding that
	--// a single-line measurement folds into its height
	return math.ceil(Measure.text(self, "Ag\nAg", size, font).Y / 2)
end

--- Width of one space. Fonts do not expose this, so it is the difference
--- between a spaced and unspaced pair.
function Measure.spaceWidth(self: Fields & Types.Measurer, size: number, font: Enum.Font): number
	local spaced = Measure.width(self, "a a", size, font)
	local tight = Measure.width(self, "aa", size, font)

	return math.max(0, spaced - tight)
end

--- Drops every cached measurement. Called on restyle.
function Measure.flush(self: Fields & Types.Measurer)
	table.clear(self.cache)

	self.entries = 0
end

return Measure
