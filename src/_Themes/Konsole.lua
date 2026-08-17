--!strict

--- The console with no brand colour at all — Konsole exactly as it was.
---
--- Astrix's `Default` is this palette plus one purple layer on the mark, the
--- prompt glyph, the focus ring and the active suggestion. This theme takes
--- that layer back off: `Accent` becomes the same white the suggestion
--- highlight already used, so nothing on screen is Valence-branded.
---
--- Registered as an override on `Default`, so it inherits every metric and
--- only restates what differs.

local rgb = Color3.fromRGB

return {
	Accent = {
		Primary = rgb(255, 255, 255),
		Soft = rgb(207, 207, 207), --// suggSub
		Contrast = rgb(0, 0, 0),
	},

	Rich = {
		Accent = "#FFFFFF",
	},

	--// Kyn still needs highlighting, but in greys rather than a palette
	Syntax = {
		Ref = "#EEEEEE",
		Stack = "#CFCFCF",
		Flag = "#FFD36A",
		String = "#89FF7E",
		Number = "#CFCFCF",
		Operator = "#9F9F9F",
		Comment = "#6E6E6E",
		Command = "#FFFFFF",
	},
}
