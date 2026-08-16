--!strict

--- A numeric slider with an optional label above and a live readout on the
--- right.
---
--- Two events, deliberately: `changed` fires continuously while dragging, and
--- `committed` fires once on release. Save settings on `committed` and preview
--- them on `changed`.
--- @section Elements

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Slider = {}
Slider.__index = Slider

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	minimum: number,
	maximum: number,
	step: number,

	labelText: string,
	showValue: boolean,
	dragging: boolean,
	formatter: ((number) -> string)?,
}

local THUMB = 14

--- Creates a slider. Prefer `panel:slider(label)`.
function Slider.new(app: Types.App): Types.Slider
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control + theme.size.row),
			Name = "Slider",
		},
		children = {
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(0.6, 0, 0, theme.size.row),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,

					Name = "Label",
					Text = "",
				},
			},
			{
				class = "TextLabel",
				ref = "readout",
				props = {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0.4, 0, 0, theme.size.row),

					Font = theme.font.mono,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,

					Name = "Readout",
					Text = "0",
				},
			},
			{
				class = "Frame",
				ref = "rail",
				props = {
					BackgroundColor3 = theme.color.track,
					BackgroundTransparency = theme.transparency.track,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0, theme.size.row + theme.size.control / 2),
					Size = UDim2.new(1, 0, 0, theme.size.rail),

					Name = "Rail",
				},
				children = {
					Create.corner(theme.radius.pill),
					{
						class = "Frame",
						ref = "fill",
						props = {
							BackgroundColor3 = theme.color.accent,
							BorderSizePixel = 0,
							Size = UDim2.fromScale(0, 1),
							Name = "Fill",
						},
						children = { Create.corner(theme.radius.pill) },
					},
					{
						class = "Frame",
						ref = "thumb",
						props = {
							BackgroundColor3 = theme.color.text,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(THUMB, THUMB),

							ZIndex = 3,
							Name = "Thumb",
						},
						children = { Create.corner(theme.radius.pill) },
					},
				},
			},
			{
				class = "TextButton",
				ref = "hit",
				props = {
					BackgroundTransparency = 1,
					AutoButtonColor = false,

					Position = UDim2.fromOffset(0, theme.size.row),
					Size = UDim2.new(1, 0, 0, theme.size.control),

					Name = "Hit",
					Text = "",
					ZIndex = 4,
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

		kind = "slider",
		desired = Vector2.new(0, theme.size.control + theme.size.row),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		minimum = 0,
		maximum = 1,
		step = 0,

		labelText = "",
		showValue = true,
		dragging = false,
		formatter = nil,
	}

	local slider = setmetatable(fields, Slider) :: any

	local hit = refs.hit :: TextButton
	local rail = refs.rail :: Frame
	local thumb = refs.thumb :: Frame

	local function valueAt(x: number): number
		local left = rail.AbsolutePosition.X
		local width = math.max(1, rail.AbsoluteSize.X)

		local fraction = math.clamp((x - left) / width, 0, 1)

		return fields.minimum + (fields.maximum - fields.minimum) * fraction
	end

	Hover.attach(scope, hit, function(hovering)
		if not fields.enabled then
			return
		end

		Motion.animate(
			thumb,
			{ Size = UDim2.fromOffset(if hovering then THUMB + 3 else THUMB, if hovering then THUMB + 3 else THUMB) },
			theme:spec("hover")
		)
	end)

	scope:add(hit.InputBegan:Connect(function(input)
		if not fields.enabled then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		fields.dragging = true

		Slider.commitValue(slider, valueAt(input.Position.X), true)
	end))

	scope:add(UserInputService.InputChanged:Connect(function(input)
		if not fields.dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		Slider.commitValue(slider, valueAt(input.Position.X), true)
	end))

	scope:add(UserInputService.InputEnded:Connect(function(input)
		if not fields.dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		fields.dragging = false

		slider:emit("committed", fields.current)
	end))

	Slider.paint(fields, true)

	return slider
end

--- Snaps a raw value to the slider's range and step.
function Slider.quantise(self: Fields, value: number): number
	local clamped = math.clamp(value, self.minimum, self.maximum)

	if self.step > 0 then
		clamped = self.minimum + math.round((clamped - self.minimum) / self.step) * self.step
	end

	return math.clamp(clamped, self.minimum, self.maximum)
end

--- Moves the fill and thumb to match the current value.
function Slider.paint(self: Fields, immediate: boolean?)
	local span = self.maximum - self.minimum
	local fraction = if span == 0 then 0 else (self.current - self.minimum) / span

	local fill = self.refs.fill :: Frame
	local thumb = self.refs.thumb :: Frame
	local readout = self.refs.readout :: TextLabel

	local fillTarget = { Size = UDim2.fromScale(fraction, 1) }
	local thumbTarget = { Position = UDim2.fromScale(fraction, 0.5) }

	--// dragging is one-to-one; springing it would lag the pointer
	if immediate or self.dragging then
		Motion.set(fill, fillTarget)
		Motion.set(thumb, thumbTarget)
	else
		Motion.animate(fill, fillTarget, self.app.theme:spec("morph"))
		Motion.animate(thumb, thumbTarget, self.app.theme:spec("morph"))
	end

	if self.showValue then
		readout.Text = if self.formatter
			then self.formatter(self.current)
			else string.format(if self.step > 0 and self.step % 1 == 0 then "%d" else "%.2f", self.current)
	end
end

--- Sets the value, painting and firing `changed` if it actually moved.
function Slider.commitValue(self: Fields & Types.Slider, value: number, live: boolean?)
	local next = Slider.quantise(self, value)

	if next == self.current then
		return
	end

	self.current = next

	Slider.paint(self, live)

	self:emit("changed", next)
end

function Slider.setLabel(self: Fields & Types.Slider, label: Types.Bindable<string>): Types.Slider
	local text = self.refs.label :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		self.labelText = value
		text.Text = value
	end)

	return self
end

function Slider.setRange(self: Fields & Types.Slider, minimum: number, maximum: number): Types.Slider
	self.minimum = minimum
	self.maximum = math.max(maximum, minimum)
	self.current = Slider.quantise(self, self.current)

	Slider.paint(self, true)

	return self
end

function Slider.setStep(self: Fields & Types.Slider, step: number): Types.Slider
	self.step = math.max(0, step)
	self.current = Slider.quantise(self, self.current)

	Slider.paint(self, true)

	return self
end

function Slider.setValue(self: Fields & Types.Slider, value: Types.Bindable<number>): Types.Slider
	Node.bind(self, "value", value, function(next: number)
		Slider.commitValue(self, tonumber(next) or 0)
	end)

	return self
end

--- Formats the readout. Defaults to two decimals, or whole numbers when the
--- step is an integer.
function Slider.setFormat(self: Fields & Types.Slider, format: (number) -> string): Types.Slider
	self.formatter = format

	Slider.paint(self, true)

	return self
end

function Slider.setShowValue(self: Fields & Types.Slider, shown: boolean): Types.Slider
	self.showValue = shown ~= false
	;(self.refs.readout :: TextLabel).Visible = self.showValue

	return self
end

function Slider.onChanged(self: Fields & Types.Slider, handler: (number) -> ()): Types.Slider
	return self:on("changed", handler)
end

function Slider.onCommitted(self: Fields & Types.Slider, handler: (number) -> ()): Types.Slider
	return self:on("committed", handler)
end

function Slider.value(self: Fields & Types.Slider): number
	return self.current
end

function Slider.measure(self: Fields & Types.Slider, available: Vector2): Vector2
	local theme = self.app.theme
	local labelled = self.labelText ~= "" or self.showValue

	local height = theme.size.control + (if labelled then theme.size.row else 0)

	--// a rail needs room to be worth dragging; 180 is the floor, the label can
	--// push it wider, and fill stretches it in commit
	local natural = math.max(180, self.app.measure:width(self.labelText, theme.text.sm, theme.font.body) + 80)
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), height)
	self.measured = true

	return self.desired
end

function Slider.commit(self: Fields & Types.Slider, inner: Vector2, vertical: boolean, share: number)
	local theme = self.app.theme
	local labelled = self.labelText ~= "" or self.showValue

	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	local top = if labelled then theme.size.row else 0

	;(self.refs.label :: TextLabel).Visible = labelled
	;(self.refs.readout :: TextLabel).Visible = labelled and self.showValue

	;(self.refs.rail :: Frame).Position = UDim2.new(0, 0, 0, top + theme.size.control / 2)
	;(self.refs.hit :: TextButton).Position = UDim2.fromOffset(0, top)
end

Element.install(Slider)

return Slider
