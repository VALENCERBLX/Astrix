--!strict

--- Tokyo Night.
---
--- `Default` already is Konsole — pure black, white text, no brand colour — so
--- a second theme that only removed the purple was not worth having. This is a
--- real alternative instead: a deep blue-grey surface with the Tokyo Night
--- palette, which is what most of these editors are themed in anyway.
---
--- Registered as an override on `Default`, so it inherits every metric and
--- restates only what differs. The console's geometry, motion and spacing are
--- not a matter of taste.
--- @section Themes

local rgb = Color3.fromRGB

return {
	Accent = {
		Primary = rgb(122, 162, 247), --// #7AA2F7 blue
		Soft = rgb(187, 154, 247), --// #BB9AF7 magenta
		Contrast = rgb(26, 27, 38),
	},

	Color = {
		--// #1A1B26. The surface is no longer black, so the transparency below
		--// is pulled in to stop the world washing the colour out
		Background = rgb(26, 27, 38),
		Surface = rgb(36, 40, 59), --// #24283B
		Border = rgb(41, 46, 66),

		TextPrimary = rgb(192, 202, 245), --// #C0CAF5
		TextMuted = rgb(154, 165, 206), --// #9AA5CE
		TextGhost = rgb(86, 95, 137), --// #565F89
		TextPrompt = rgb(125, 207, 255), --// #7DCFFF cyan
		TextSuggestion = rgb(192, 202, 245),

		Success = rgb(158, 206, 106), --// #9ECE6A
		Error = rgb(247, 118, 142), --// #F7768E
		Warn = rgb(224, 175, 104), --// #E0AF68

		Shadow = rgb(0, 0, 0),
	},

	Rich = {
		Success = "#9ECE6A",
		Error = "#F7768E",
		Warn = "#E0AF68",
		Muted = "#9AA5CE",
		Sub = "#565F89",
		Match = "#C0CAF5",
		Accent = "#BB9AF7",
	},

	Syntax = {
		Ref = "#BB9AF7", --// magenta
		Stack = "#7DCFFF", --// cyan
		Flag = "#E0AF68", --// yellow
		String = "#9ECE6A", --// green
		Number = "#FF9E64", --// orange
		Operator = "#89DDFF",
		Comment = "#565F89",
		Command = "#7AA2F7", --// blue
	},

	Transparency = {
		--// a coloured surface needs to be more opaque than a black one, or the
		--// world behind it turns the blue to mud
		Panel = 0.2,
		Suggestion = 0.15,
	},
}
