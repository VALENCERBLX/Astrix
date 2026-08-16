--!strict

--- Presets are configuration, not subclasses. A window, a command bar, a
--- tooltip and a modal are the same Panel with different numbers, which is why
--- they all get content-driven sizing, anchored growth and the morphing radius
--- without any of them implementing it.
---
--- Values are resolved against the theme at apply time, so a preset can say
--- `radius = "lg"` and mean whatever the current theme calls large.
--- @section Presets

local Types = require(script.Parent.Parent.Types)

export type Preset = {
	anchor: Types.Anchor?,
	layer: string?,
	axis: Types.Axis?,

	radius: string?,
	pill: boolean?,

	padX: string?,
	padY: string?,
	gap: string?,
	inset: string?,

	width: number?,
	minWidth: number?,
	maxWidth: number?,
	minHeight: number?,
	maxHeight: number?,

	title: boolean?,
	border: boolean?,
	shadow: boolean?,
	clip: boolean?,
	draggable: boolean?,
	dismissable: boolean?,
	closeButton: boolean?,
	backdrop: boolean?,

	color: string?,
	transparency: string?,
}

--// locals
local Presets: { [string]: Preset } = {
	--// a floating, draggable, titled surface. The default shape.
	window = {
		anchor = "center",
		layer = "default",
		axis = "vertical",

		radius = "lg",
		padX = "md",
		padY = "md",
		gap = "sm",
		inset = "lg",

		width = 360,
		minWidth = 200,
		maxWidth = 720,
		minHeight = 80,
		maxHeight = 640,

		title = true,
		border = true,
		shadow = true,
		clip = true,
		draggable = true,
		dismissable = false,
		closeButton = true,

		color = "surface",
		transparency = "surface",
	},

	--// the command bar: one pill-shaped row that morphs into a rounded panel
	--// the moment it has output to show
	bar = {
		anchor = "bottom",
		layer = "raised",
		axis = "vertical",

		radius = "lg",
		pill = true,
		padX = "md",
		padY = "sm",
		gap = "xs",
		inset = "xl",

		width = 520,
		minWidth = 280,
		maxWidth = 900,
		minHeight = 0,
		maxHeight = 480,

		title = false,
		border = false,
		shadow = true,
		clip = true,
		draggable = true,
		dismissable = false,
		closeButton = false,

		color = "surfaceRaised",
		transparency = "surface",
	},

	--// anchored to something else: dropdowns, autocompletes, pickers
	popover = {
		anchor = "topLeft",
		layer = "popover",
		axis = "vertical",

		radius = "md",
		padX = "xs",
		padY = "xs",
		gap = "none",
		inset = "sm",

		minWidth = 120,
		maxWidth = 520,
		maxHeight = 320,

		title = false,
		border = true,
		shadow = true,
		clip = true,
		draggable = false,
		dismissable = true,
		closeButton = false,

		color = "surfaceRaised",
		transparency = "surfaceRaised",
	},

	tooltip = {
		anchor = "topLeft",
		layer = "tooltip",
		axis = "vertical",

		radius = "sm",
		padX = "sm",
		padY = "xs",
		gap = "none",
		inset = "sm",

		maxWidth = 280,

		title = false,
		border = false,
		shadow = true,
		clip = true,
		draggable = false,
		dismissable = false,
		closeButton = false,

		color = "surfaceRaised",
		transparency = "surfaceRaised",
	},

	modal = {
		anchor = "center",
		layer = "modal",
		axis = "vertical",

		radius = "lg",
		padX = "lg",
		padY = "lg",
		gap = "md",
		inset = "xl",

		width = 420,
		minWidth = 260,
		maxWidth = 640,
		maxHeight = 560,

		title = true,
		border = true,
		shadow = true,
		clip = true,
		draggable = false,
		dismissable = true,
		closeButton = true,
		backdrop = true,

		color = "surface",
		transparency = "surfaceRaised",
	},

	toast = {
		anchor = "bottomRight",
		layer = "toast",
		axis = "horizontal",

		radius = "md",
		padX = "md",
		padY = "sm",
		gap = "sm",
		inset = "lg",

		minWidth = 200,
		maxWidth = 420,

		title = false,
		border = true,
		shadow = true,
		clip = true,
		draggable = false,
		dismissable = true,
		closeButton = false,

		color = "surfaceRaised",
		transparency = "surfaceRaised",
	},

	--// an inline surface: no floating, no drag, meant to be nested
	card = {
		anchor = "topLeft",
		layer = "default",
		axis = "vertical",

		radius = "md",
		padX = "md",
		padY = "md",
		gap = "sm",
		inset = "none",

		minWidth = 0,
		maxWidth = 9999,

		title = false,
		border = true,
		shadow = false,
		clip = true,
		draggable = false,
		dismissable = false,
		closeButton = false,

		color = "surfaceRaised",
		transparency = "surfaceRaised",
	},

	--// edge-attached drawer, full width along its anchor
	sheet = {
		anchor = "bottom",
		layer = "modal",
		axis = "vertical",

		radius = "xl",
		padX = "lg",
		padY = "lg",
		gap = "md",
		inset = "none",

		minWidth = 320,
		maxWidth = 9999,
		maxHeight = 600,

		title = true,
		border = false,
		shadow = true,
		clip = true,
		draggable = false,
		dismissable = true,
		closeButton = true,
		backdrop = true,

		color = "surface",
		transparency = "surface",
	},

	--// no opinions at all
	plain = {
		anchor = "topLeft",
		layer = "default",
		axis = "vertical",

		radius = "none",
		padX = "none",
		padY = "none",
		gap = "none",
		inset = "none",

		title = false,
		border = false,
		shadow = false,
		clip = false,
		draggable = false,
		dismissable = false,
		closeButton = false,

		color = "surface",
		transparency = "surface",
	},
}

local Module = {}

--- Looks a preset up by name, falling back to `window`.
function Module.get(name: Types.Preset): Preset
	return Presets[name] or Presets.window
end

--- Every preset name, for tooling and docs.
function Module.names(): { string }
	local names = {}

	for name in Presets do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

return Module
