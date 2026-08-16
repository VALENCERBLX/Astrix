--!strict

--- A button. Five variants over one implementation, with hover, press and
--- loading states driven through the motion driver rather than by swapping
--- properties instantly.
---
--- The press is a `UIScale` dip rather than a colour change: it reads on every
--- variant including the transparent ones, and it costs one number.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Button = {}
Button.__index = Button

export type Variant = "solid" | "soft" | "ghost" | "outline" | "danger"

export type Fields = Types.NodeFields & Types.ElementFields & {
	value: string,
	variant: Variant,
	iconImage: string,
	fixedWidth: number?,
	loading: boolean,

	baseTransparency: number,
	hovering: boolean,
}

--- Per-variant surface: background colour token, resting transparency, the
--- transparency it lifts to on hover, text colour token, and whether it wears
--- a border.
local VARIANTS: { [string]: { color: string, rest: number, hover: number, text: string, stroke: boolean } } = {
	solid = { color = "accent", rest = 0, hover = 0.12, text = "accentText", stroke = false },
	soft = { color = "accent", rest = 0.85, hover = 0.75, text = "accent", stroke = false },
	ghost = { color = "text", rest = 1, hover = 0.92, text = "textMuted", stroke = false },
	outline = { color = "text", rest = 1, hover = 0.94, text = "text", stroke = true },
	danger = { color = "danger", rest = 0, hover = 0.12, text = "textInverse", stroke = false },
}

--- Creates a button. Prefer `panel:button(text)`.
function Button.new(app: Types.App): Types.Button
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "TextButton",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.accent,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,

			AutoButtonColor = false,
			Selectable = true,
			Size = UDim2.fromOffset(96, theme.size.control),

			Name = "Button",
			Text = "",
		},
		children = {
			Create.corner(theme.radius.md),
			{
				class = "UIStroke",
				ref = "stroke",
				props = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = theme.color.border,
					Thickness = theme.stroke.hairline,
					Transparency = theme.transparency.border,
					Enabled = false,
				},
			},
			{
				class = "UIScale",
				ref = "scale",
				props = { Scale = 1 },
			},
			Create.padding(theme.space.md, 0),
			Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			{
				class = "ImageLabel",
				ref = "icon",
				props = {
					BackgroundTransparency = 1,
					ImageColor3 = theme.color.accentText,
					ScaleType = Enum.ScaleType.Fit,

					Size = UDim2.fromOffset(theme.size.icon, theme.size.icon),
					LayoutOrder = 1,
					Visible = false,
					Name = "Icon",
					Image = "",
				},
			},
			{
				class = "TextLabel",
				ref = "text",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.control),

					Font = theme.font.medium,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.accentText,
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

		kind = "button",
		desired = Vector2.new(96, theme.size.control),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		value = "",
		variant = "solid",
		iconImage = "",
		fixedWidth = nil,
		loading = false,

		baseTransparency = 0,
		hovering = false,
	}

	local button = setmetatable(fields, Button) :: any

	local instance = root :: TextButton
	local scale = refs.scale :: UIScale

	Hover.attach(scope, instance, function(hovering)
		fields.hovering = hovering

		if not fields.enabled or fields.loading then
			return
		end

		local surface = VARIANTS[fields.variant]

		Motion.animate(
			instance,
			{ BackgroundTransparency = if hovering then surface.hover else surface.rest },
			theme:spec("hover")
		)

		button:emit("hovered", hovering)
	end)

	Hover.press(scope, instance, function(pressed)
		if not fields.enabled or fields.loading then
			return
		end

		Motion.animate(scale, { Scale = if pressed then 0.97 else 1 }, theme:spec("press"))

		button:emit(if pressed then "pressed" else "released")
	end)

	scope:add(instance.Activated:Connect(function()
		if not fields.enabled or fields.loading then
			return
		end

		button:emit("clicked")
	end))

	Button.setVariant(button, "solid")

	return button
end

function Button.setText(self: Fields & Types.Button, text: Types.Bindable<string>): Types.Button
	local label = self.refs.text :: TextLabel

	Node.bind(self, "text", text, function(next: string)
		local value = tostring(next)

		self.value = value
		label.Text = value

		self:invalidate()
	end)

	return self
end

function Button.setIcon(self: Fields & Types.Button, image: Types.Bindable<string>): Types.Button
	local icon = self.refs.icon :: ImageLabel

	Node.bind(self, "icon", image, function(next: string)
		local value = tostring(next)

		self.iconImage = value

		icon.Image = value
		icon.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

function Button.setVariant(self: Fields & Types.Button, variant: Variant): Types.Button
	local theme = self.app.theme
	local surface = VARIANTS[variant] or VARIANTS.solid

	self.variant = variant
	self.baseTransparency = surface.rest

	local instance = self.instance :: TextButton
	local textColor = theme.color[surface.text] or theme.color.text

	instance.BackgroundColor3 = theme.color[surface.color] or theme.color.accent
	instance.BackgroundTransparency = if self.hovering then surface.hover else surface.rest

	;(self.refs.stroke :: UIStroke).Enabled = surface.stroke
	;(self.refs.text :: TextLabel).TextColor3 = textColor
	;(self.refs.icon :: ImageLabel).ImageColor3 = textColor

	return self
end

function Button.setColor(self: Fields & Types.Button, color: Types.Bindable<Color3>): Types.Button
	Node.bind(self, "color", color, function(next: Color3)
		(self.instance :: TextButton).BackgroundColor3 = next
	end)

	return self
end

function Button.setRadius(self: Fields & Types.Button, radius: number | "pill"): Types.Button
	local corner = self.instance:FindFirstChildOfClass("UICorner")

	if corner then
		corner.CornerRadius = if radius == "pill"
			then UDim.new(1, 0)
			else UDim.new(0, radius :: number)
	end

	return self
end

--- Spins the icon and stops accepting clicks.
function Button.setLoading(self: Fields & Types.Button, loading: Types.Bindable<boolean>): Types.Button
	local icon = self.refs.icon :: ImageLabel

	Node.bind(self, "loading", loading, function(next: boolean)
		self.loading = next == true

		icon.Rotation = 0

		Motion.animate(
			self.instance,
			{ BackgroundTransparency = if self.loading then math.max(self.baseTransparency, 0.4) else self.baseTransparency },
			self.app.theme:spec("fade")
		)
	end)

	return self
end

--- Pins the width instead of sizing to the label.
function Button.setFixedWidth(self: Fields & Types.Button, width: number): Types.Button
	self.fixedWidth = width

	return self:invalidate()
end

function Button.onClicked(self: Fields & Types.Button, handler: () -> ()): Types.Button
	return self:on("clicked", handler)
end

function Button.onPressed(self: Fields & Types.Button, handler: () -> ()): Types.Button
	return self:on("pressed", handler)
end

function Button.onReleased(self: Fields & Types.Button, handler: () -> ()): Types.Button
	return self:on("released", handler)
end

function Button.onHovered(self: Fields & Types.Button, handler: (boolean) -> ()): Types.Button
	return self:on("hovered", handler)
end

--- Fires the click handlers as if the button had been pressed.
function Button.click(self: Fields & Types.Button): Types.Button
	if self.enabled and not self.loading then
		self:emit("clicked")
	end

	return self
end

function Button.measure(self: Fields & Types.Button, available: Vector2): Vector2
	local theme = self.app.theme

	local text = if self.value == ""
		then 0
		else self.app.measure:width(self.value, theme.text.sm, theme.font.medium)

	local icon = if self.iconImage ~= "" then theme.size.icon + theme.space.xs else 0
	local natural = self.fixedWidth or (text + icon + theme.space.md * 2)

	--// never `available.X`, even when filling: see the note in Element
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), theme.size.control)
	self.measured = true

	return self.desired
end

Element.install(Button)

return Button
