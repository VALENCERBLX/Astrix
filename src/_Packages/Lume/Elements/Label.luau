--!strict

--- Text. The most common element and the one that drives most panel sizing,
--- because a panel is usually as wide as its widest line.
---
--- Measurement respects wrapping and `maxLines`: an unwrapped label reports its
--- full single-line width and lets the panel decide whether that fits, while a
--- wrapped one reports the height it needs at the width on offer.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)
local Text = require(script.Parent.Parent.Text)

local Label = {}
Label.__index = Label

export type Fields = Types.NodeFields & Types.ElementFields & {
	value: string,
	textSize: number,
	font: Enum.Font,
	wrapped: boolean,
	rich: boolean,
	maxLines: number,
}

--- Creates a label. Prefer `panel:label(text)`.
function Label.new(app: Types.App): Types.Label
	local theme = app.theme
	local scope = app.scope:child()

	local root = Create.node(scope, {
		class = "TextLabel",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Font = theme.font.body,
			TextSize = theme.text.md,
			TextColor3 = theme.color.text,
			TextTransparency = theme.transparency.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = false,
			RichText = false,

			Size = UDim2.fromOffset(0, theme.text.md),
			Name = "Label",
			Text = "",
		},
	}) :: TextLabel

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root,
		refs = { root = root },
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "label",
		desired = Vector2.zero,
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		value = "",
		textSize = theme.text.md,
		font = theme.font.body,
		wrapped = false,
		rich = false,
		maxLines = 0,
	}

	return setmetatable(fields, Label) :: any
end

function Label.setText(self: Fields & Types.Label, text: Types.Bindable<string>): Types.Label
	Node.bind(self, "text", text, function(next: string)
		local value = tostring(next)

		self.value = value
		;(self.instance :: TextLabel).Text = value

		self:invalidate()
	end)

	return self
end

function Label.setColor(self: Fields & Types.Label, color: Types.Bindable<Color3>): Types.Label
	Node.bind(self, "color", color, function(next: Color3)
		(self.instance :: TextLabel).TextColor3 = next
	end)

	return self
end

function Label.setTextSize(self: Fields & Types.Label, size: number): Types.Label
	self.textSize = size
	;(self.instance :: TextLabel).TextSize = size

	return self:invalidate()
end

function Label.setFont(self: Fields & Types.Label, font: Enum.Font): Types.Label
	self.font = font
	;(self.instance :: TextLabel).Font = font

	return self:invalidate()
end

function Label.setAlign(
	self: Fields & Types.Label,
	horizontal: Enum.TextXAlignment,
	vertical: Enum.TextYAlignment?
): Types.Label
	local label = self.instance :: TextLabel

	label.TextXAlignment = horizontal
	label.TextYAlignment = vertical or label.TextYAlignment

	--// alignment only reads as alignment if the label owns the full width
	if horizontal ~= Enum.TextXAlignment.Left then
		self.fill = true
	end

	return self:invalidate()
end

--- Wrap at the width the panel offers instead of running on in one line.
function Label.setWrapped(self: Fields & Types.Label, wrapped: boolean): Types.Label
	self.wrapped = wrapped ~= false
	;(self.instance :: TextLabel).TextWrapped = self.wrapped

	if self.wrapped then
		self.fill = true
	end

	return self:invalidate()
end

function Label.setRich(self: Fields & Types.Label, rich: boolean): Types.Label
	self.rich = rich ~= false
	;(self.instance :: TextLabel).RichText = self.rich

	return self:invalidate()
end

function Label.setMuted(self: Fields & Types.Label, muted: boolean): Types.Label
	local theme = self.app.theme
	local label = self.instance :: TextLabel

	label.TextColor3 = if muted then theme.color.textMuted else theme.color.text
	label.TextTransparency = if muted then theme.transparency.muted else theme.transparency.text

	return self
end

--- Caps the height at a number of lines. Zero means no cap.
function Label.setMaxLines(self: Fields & Types.Label, lines: number): Types.Label
	self.maxLines = math.max(0, lines)

	return self:invalidate()
end

function Label.text(self: Fields & Types.Label): string
	return self.value
end

function Label.measure(self: Fields & Types.Label, available: Vector2): Vector2
	--// RichText tags are not rendered, so they must not be measured either
	local content = if self.rich then Text.strip(self.value) else self.value
	local width = if self.wrapped then math.max(1, available.X - self.margin * 2) else nil

	local bounds = self.app.measure:text(content, self.textSize, self.font, width)
	local lineHeight = self.app.measure:lineHeight(self.textSize, self.font)

	local height = math.max(bounds.Y, lineHeight)

	if self.maxLines > 0 then
		height = math.min(height, self.maxLines * lineHeight)
	end

	local finalWidth = if self.wrapped then math.min(bounds.X, math.max(1, available.X)) else bounds.X

	self.desired = Vector2.new(math.ceil(finalWidth), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Label)

return Label
