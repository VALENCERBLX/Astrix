--!strict

--- The default token set. Components read from here and never from literals,
--- so one `app:restyle{…}` call restyles the whole tree.
---
--- These values are not an invention and no longer an estimate: they are read
--- straight out of the original console's `config.luau`. Surfaces are pure
--- black at `0.50` transparency, body text is white, and the greys, motion
--- durations, radii and sizes below are that file's literals.
---
--- The green is `successText`, not the body colour — a console shows a lot of
--- green because most of its output succeeded, not because its text is green.
--- @section Theme

return {
	name = "default",

	color = {
		--// pure black surfaces. The separation between layers comes from
		--// transparency, not from lightening each one — which is why the
		--// console reads as glass over the world instead of as grey boxes
		surface = Color3.fromRGB(0, 0, 0),
		surfaceRaised = Color3.fromRGB(0, 0, 0),
		surfaceSunken = Color3.fromRGB(0, 0, 0),
		surfaceHover = Color3.fromRGB(255, 255, 255),
		surfaceActive = Color3.fromRGB(255, 255, 255),
		overlay = Color3.fromRGB(0, 0, 0),

		border = Color3.fromRGB(0, 0, 0),
		borderStrong = Color3.fromRGB(96, 96, 106),

		--// inputText
		text = Color3.fromRGB(255, 255, 255),
		--// mutedText
		textMuted = Color3.fromRGB(159, 159, 159),
		--// hintGhost
		textGhost = Color3.fromRGB(110, 110, 110),
		textInverse = Color3.fromRGB(12, 12, 14),
		--// promptText
		prompt = Color3.fromRGB(210, 210, 210),

		--// the console carries no brand colour of its own; this is a neutral
		--// accent for the controls Lume has and a console does not
		accent = Color3.fromRGB(126, 170, 255),
		accentMuted = Color3.fromRGB(74, 102, 156),
		accentText = Color3.fromRGB(12, 14, 20),

		--// successText / warnText / errorText, exactly
		success = Color3.fromRGB(137, 255, 126),
		warn = Color3.fromRGB(255, 211, 106),
		danger = Color3.fromRGB(255, 126, 126),

		track = Color3.fromRGB(255, 255, 255),
		selection = Color3.fromRGB(102, 209, 140),
	},

	--// hex mirrors of the palette, for RichText spans
	rich = {
		text = "#EEEEF2",
		muted = "#9292A0",
		ghost = "#60606A",
		accent = "#7EAAFF",
		--// successRich / warnRich / errorRich / suggSub / suggMatch
		success = "#89FF7E",
		warn = "#FFD36A",
		danger = "#FF7E7E",
		sub = "#CFCFCF",
		match = "#FFFFFF",
	},

	transparency = {
		--// transparency.panel — half, which is a lot more glass than it sounds
		surface = 0.5,
		--// transparency.suggPanel
		surfaceRaised = 0.42,
		overlay = 0.45,
		border = 0.35,
		text = 0,
		muted = 0.5,
		ghost = 0.6,
		--// transparency.dimText / transparency.arrow
		dim = 0.18,
		arrow = 0.35,
		track = 0.88,
		shadow = 0.8,
		disabled = 0.6,
	},

	font = {
		body = Enum.Font.BuilderSans,
		medium = Enum.Font.BuilderSans,
		bold = Enum.Font.BuilderSansBold,
		mono = Enum.Font.Code,
	},

	text = {
		xs = 11,
		sm = 13,
		md = 14,
		lg = 17,
		xl = 22,
		xxl = 28,
	},

	space = {
		none = 0,
		--// layout.paddingY
		xs = 5,
		--// layout.itemGap
		sm = 6,
		--// layout.paddingX
		md = 12,
		lg = 16,
		--// viewportTopInset — how close a panel comes to the screen edge
		xl = 24,
		xxl = 32,
	},

	radius = {
		xs = 4,
		sm = 6,
		--// suggestionRadius
		md = 10,
		--// outputRadius — what the pill morphs into
		lg = 12,
		xl = 20,
		pill = 999,
	},

	stroke = {
		hairline = 1,
		thick = 2,
	},

	size = {
		--// inputHeight — with paddingY 5 either side this makes a 34px pill
		control = 24,
		--// suggestionHeight
		row = 26,
		--// hintHeight
		hint = 17,
		--// historyLineHeight
		line = 14,
		icon = 18,
		touch = 44,
		--// panel.height
		bar = 34,
		title = 34,
		thumb = 14,
		rail = 4,
	},

	--// shadow: opt-in. point `image` at your own 9-sliced soft shadow and every
	--// surface picks it up; leave it empty and no shadow instance is created.
	shadow = {
		--// the console's own soft shadow; swap it for your own or clear it
		image = "rbxassetid://1316045217",
		slice = Rect.new(10, 10, 118, 118),
		color = Color3.fromRGB(0, 0, 0),
		transparency = 0.8,
		spread = 22,
		offset = Vector2.new(0, 3),
	},

	--// motion: `duration` + `easing` tweens, `stiffness` + `damping` springs.
	--// The tween durations are the console's own smooth times; anything whose
	--// target can change mid-flight stays a spring on purpose.
	motion = {
		instant = { duration = 0 },

		--// openSmoothTime / collapseSmoothTime / expandSmoothTime
		enter = { duration = 0.46, easing = "outQuint" },
		exit = { duration = 0.38, easing = "outQuad" },
		expand = { duration = 0.34, easing = "outQuint" },
		hover = { duration = 0.12, easing = "outQuad" },
		press = { duration = 0.07, easing = "outQuad" },
		--// textFadeTime / exitFadeTime
		fade = { duration = 0.34, easing = "outQuad" },
		--// hintFadeTime
		hint = { duration = 0.22, easing = "outQuad" },
		--// itemSlideSmoothTime
		item = { duration = 0.3, easing = "outQuad" },
		--// listSmoothTime
		list = { duration = 0.28, easing = "outQuad" },

		layout = { stiffness = 190, damping = 24 },
		morph = { stiffness = 210, damping = 26 },
		drag = { stiffness = 420, damping = 34 },
		reveal = { stiffness = 150, damping = 20 },
		snap = { stiffness = 600, damping = 40 },
	},
}
