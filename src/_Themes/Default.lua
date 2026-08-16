--!strict

--- The default token set.
---
--- The greys, transparencies, radii, sizes and motion durations are Konsole's
--- `config.luau` verbatim — this is the "exact same UI" half of the brief, and
--- guessing at it would show immediately.
---
--- `Accent` is what Astrix adds. Konsole carries no brand colour anywhere in
--- its chrome; Astrix layers purple onto exactly four things — the mark, the
--- prompt glyph, the focus ring and the active suggestion row. It is its own
--- top-level group rather than living inside `Color` so every element that
--- wants brand colour pulls from one place.
---
--- `Syntax` is new too: Konsole had nothing to highlight, Kyn does.

local rgb = Color3.fromRGB

return {
	Name = "Default",

	Accent = {
		Primary = rgb(108, 62, 244), --// #6C3EF4
		Soft = rgb(167, 139, 250), --// #A78BFA
		Contrast = rgb(255, 255, 255),
	},

	Color = {
		--// panel is pure black; separation comes from transparency, never from
		--// lightening a surface
		Background = rgb(0, 0, 0),
		Surface = rgb(8, 8, 8), --// suggPanel
		Border = rgb(0, 0, 0),

		TextPrimary = rgb(255, 255, 255), --// inputText
		TextMuted = rgb(159, 159, 159), --// mutedText
		TextGhost = rgb(110, 110, 110), --// hintGhost
		TextPrompt = rgb(210, 210, 210), --// promptText
		TextSuggestion = rgb(238, 238, 238), --// suggText

		Success = rgb(137, 255, 126), --// successText
		Error = rgb(255, 126, 126), --// errorText
		Warn = rgb(255, 211, 106), --// warnText

		Shadow = rgb(0, 0, 0),
	},

	--// RichText hex mirrors, for spans inside a line
	Rich = {
		Success = "#89FF7E",
		Error = "#FF7E7E",
		Warn = "#FFD36A",
		Muted = "#9F9F9F",
		Sub = "#CFCFCF",
		Match = "#FFFFFF",
		Accent = "#A78BFA",
	},

	--// Kyn highlighting. Konsole had no language to colour, so all of this is
	--// new: it is what makes a chained line readable at a glance.
	Syntax = {
		Ref = "#A78BFA", --// @Name, @Players.Rin
		Stack = "#7DD3FC", --// ::Kout
		Flag = "#FBBF24", --// --Flag
		String = "#86EFAC", --// "quoted"
		Number = "#F0ABFC",
		Operator = "#94A3B8", --// : >> -> |
		Comment = "#6B7280", --// # to end of line
		Command = "#FFFFFF",
	},

	Font = {
		Title = Enum.Font.BuilderSansBold,
		Body = Enum.Font.BuilderSans,
		Mono = Enum.Font.Code,
	},

	TextSize = {
		Input = 14, --// layout.textSize
		Prompt = 13, --// layout.promptSize
		Hint = 14, --// layout.hintTextSize
		Suggestion = 13, --// layout.suggTextSize
		Line = 14,
	},

	Spacing = {
		PaddingX = 12, --// layout.paddingX
		PaddingY = 5, --// layout.paddingY
		ItemGap = 6, --// layout.itemGap
		StackGap = 8, --// panel.stackGap
		SuggestionGap = 8, --// panel.suggestionGap
		ViewportInset = 24, --// panel.viewportTopInset
	},

	Radius = {
		Output = 12, --// panel.outputRadius
		Suggestion = 10, --// panel.suggestionRadius
		Pill = 999,
	},

	Size = {
		Height = 34, --// panel.height
		CollapsedWidth = 204, --// panel.collapsedWidth
		Width = 252, --// panel.width
		OutputWidth = 338, --// panel.outputWidth
		InputHeight = 24, --// panel.inputHeight
		LineHeight = 14, --// panel.historyLineHeight
		HistoryMaxHeight = 340, --// panel.historyMaxHeight
		SuggestionHeight = 26, --// panel.suggestionHeight
		MaxSuggestions = 5, --// panel.maxSuggestions
		HintHeight = 17, --// panel.hintHeight
		DisplayOrder = 8241, --// panel.displayOrder
	},

	Transparency = {
		Panel = 0.5, --// transparency.panel
		Suggestion = 0.42, --// transparency.suggPanel
		Shadow = 0.8, --// transparency.shadow
		DimText = 0.18, --// transparency.dimText
		Arrow = 0.35, --// transparency.arrow
		Text = 0,
	},

	Motion = {
		Open = 0.46, --// motion.openSmoothTime
		OpenSlideOffset = 44, --// motion.openSlideOffset
		Collapse = 0.38, --// motion.collapseSmoothTime
		Expand = 0.34, --// motion.expandSmoothTime
		Output = 0.24, --// motion.outputSmoothTime
		List = 0.28, --// motion.listSmoothTime
		ItemSlide = 0.3, --// motion.itemSlideSmoothTime
		TextFade = 0.34, --// motion.textFadeTime
		HintFade = 0.22, --// motion.hintFadeTime
		HintSlide = 0.34, --// motion.hintSlideTime
		TextSlideOffset = 10, --// motion.textSlideOffset
	},

	Asset = {
		Shadow = "rbxassetid://1316045217",
		Arrow = "rbxassetid://6031104654",
		AddWindow = "rbxassetid://6035047391",
	},
}
