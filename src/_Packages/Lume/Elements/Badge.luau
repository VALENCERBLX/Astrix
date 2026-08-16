--!strict

--- A small pill of text: counts, statuses, tags.
---
--- Tones map to the theme's semantic colours rather than taking a colour
--- directly, so a badge stays legible when the palette changes underneath it.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Badge = {}
Badge.__index = Badge

export type Tone = "neutral" | "accent" | "success" | "warn" | "danger"

export type Fields = Types.NodeFields & Types.ElementFields & {
	value: string,
	tone: Tone,
	dot: boolean,
}

local TONES: { [string]: string } = {
	neutral = "textMuted",
	accent = "accent",
	success = "success",
	warn = "warn",
	danger = "danger",
}

--- Creates a badge. Prefer `panel:badge(text)`.
function Badge.new(app: Types.App): Types.Badge
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.textMuted,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,

			Size = UDim2.fromOffset(0, theme.size.hint),
			Name = "Badge",
		},
		children = {
			Create.corner(theme.radius.pill),
			Create.padding(theme.space.sm, 0),
			Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			{
				class = "Frame",
				ref = "dot",
				props = {
					BackgroundColor3 = theme.color.textMuted,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(6, 6),
					LayoutOrder = 1,
					Visible = false,
					Name = "Dot",
				},
				children = { Create.corner(theme.radius.pill) },
			},
			{
				class = "TextLabel",
				ref = "text",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.hint),

					Font = theme.font.medium,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,

					LayoutOrder = 2,
					Name = "Text",
					Text = "",
				},
			},
		},
	})

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root :: GuiObject,
		refs = refs,
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "badge",
		desired = Vector2.new(0, theme.size.hint),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		value = "",
		tone = "neutral",
		dot = false,
	}

	return setmetatable(fields, Badge) :: any
end

function Badge.setText(self: Fields & Types.Badge, text: Types.Bindable<string>): Types.Badge
	local label = self.refs.text :: TextLabel

	Node.bind(self, "text", text, function(next: string)
		local value = tostring(next)

		self.value = value
		label.Text = value

		self:invalidate()
	end)

	return self
end

function Badge.setTone(self: Fields & Types.Badge, tone: Tone): Types.Badge
	local theme = self.app.theme
	local colour = theme.color[TONES[tone] or "textMuted"] or theme.color.textMuted

	self.tone = tone

	local root = self.instance :: Frame

	root.BackgroundColor3 = colour
	;(self.refs.text :: TextLabel).TextColor3 = colour
	;(self.refs.dot :: Frame).BackgroundColor3 = colour

	return self
end

--- Shows a coloured dot before the text — a status light.
function Badge.setDot(self: Fields & Types.Badge, dot: boolean): Types.Badge
	self.dot = dot ~= false
	;(self.refs.dot :: Frame).Visible = self.dot

	return self:invalidate()
end

function Badge.measure(self: Fields & Types.Badge, _available: Vector2): Vector2
	local theme = self.app.theme
	local text = self.app.measure:width(self.value, theme.text.xs, theme.font.medium)

	local width = text + theme.space.sm * 2 + (if self.dot then 6 + theme.space.xs else 0)

	self.desired = Vector2.new(math.ceil(width), theme.size.hint)
	self.measured = true

	return self.desired
end

Element.install(Badge)

return Badge
