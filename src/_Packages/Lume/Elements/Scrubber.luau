--!strict

--- A number you drag sideways to change, with no track under it.
---
--- What a slider cannot do: work without a range. A camera's Z has no
--- meaningful minimum or maximum, so there is no rail to draw and no fraction
--- to fill — but dragging still works, because the gesture is *relative*.
---
--- Sensitivity is per-pixel and scales with the step, so a scrubber counting in
--- hundredths does not need a mile of desk to cross a whole unit.
--- @section Elements

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Scrubber = {}
Scrubber.__index = Scrubber

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	minimum: number?,
	maximum: number?,
	step: number,
	sensitivity: number,

	labelText: string,
	dragging: boolean,
	anchor: number,
	origin: number,
	typing: boolean,
	formatter: ((number) -> string)?,
}

--- Wires drag-to-scrub onto a box. Shared with `Vector`, which is three of
--- these in a row and should behave identically.
function Scrubber.attach(
	scope: Types.Scope,
	box: GuiObject,
	read: () -> number,
	write: (number, boolean) -> (),
	rate: () -> number
)
	local dragging = false
	local anchor = 0
	local origin = 0

	scope:add(box.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		anchor = input.Position.X
		origin = read()
	end))

	scope:add(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		--// relative to where the drag started, not to the last frame: a drag
		--// that wanders back to where it began leaves the number where it
		--// began, with no accumulated drift
		write(origin + (input.Position.X - anchor) * rate(), true)
	end))

	scope:add(UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = false

		write(read(), false)
	end))
end

--- Creates a scrubber. Prefer `panel:scrubber(label)`.
function Scrubber.new(app: Types.App): Types.Scrubber
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Scrubber",
		},
		children = {
			Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.control),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,
					TextXAlignment = Enum.TextXAlignment.Left,

					LayoutOrder = 1,
					Visible = false,
					Name = "Label",
					Text = "",
				},
			},
			{
				class = "TextBox",
				ref = "box",
				props = {
					BackgroundColor3 = theme.color.surfaceSunken,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,

					Size = UDim2.new(1, 0, 0, theme.size.control),
					LayoutOrder = 2,

					Font = theme.font.mono,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,

					Name = "Value",
					Text = "0",
				},
				children = { Create.corner(theme.radius.sm) },
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

		kind = "scrubber",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		minimum = nil,
		maximum = nil,
		step = 1,
		sensitivity = 1,

		labelText = "",
		dragging = false,
		anchor = 0,
		origin = 0,
		typing = false,
		formatter = nil,
	}

	local scrubber = setmetatable(fields, Scrubber) :: any
	local box = refs.box :: TextBox

	Scrubber.attach(scope, box, function()
		return fields.current
	end, function(value, live)
		if not fields.enabled then
			return
		end

		Scrubber.commitValue(scrubber, value)

		if not live then
			scrubber:emit("committed", fields.current)
		end
	end, function()
		return fields.step * fields.sensitivity
	end)

	Hover.attach(scope, box, function(hovering)
		if not fields.enabled then
			return
		end

		box.BackgroundTransparency = if hovering then 0.25 else 0.4
	end)

	scope:add(box.Focused:Connect(function()
		fields.typing = true
	end))

	scope:add(box.FocusLost:Connect(function()
		fields.typing = false

		local typed = tonumber((box.Text:gsub("[^%-%.%d]", "")))

		if typed then
			Scrubber.commitValue(scrubber, typed)

			scrubber:emit("committed", fields.current)
		end

		Scrubber.paint(fields)
	end))

	Scrubber.paint(fields)

	return scrubber
end

--- Snaps to the step and clamps to whichever ends exist. Both are optional —
--- that is the point of this element.
function Scrubber.quantise(self: Fields, value: number): number
	if self.step > 0 then
		value = math.round(value / self.step) * self.step
		value = math.round(value * 1e6) / 1e6
	end

	if self.minimum then
		value = math.max(value, self.minimum)
	end

	if self.maximum then
		value = math.min(value, self.maximum)
	end

	return value
end

function Scrubber.paint(self: Fields)
	if self.typing then
		return
	end

	local box = self.refs.box :: TextBox

	box.Text = if self.formatter
		then self.formatter(self.current)
		else string.format(if self.step % 1 == 0 then "%d" else "%g", self.current)
end

function Scrubber.commitValue(self: Fields & Types.Scrubber, value: number)
	local next = Scrubber.quantise(self, value)

	if next == self.current then
		return
	end

	self.current = next

	Scrubber.paint(self)

	self:emit("changed", next)
end

--- Either end may be nil, which means there is no end that way.
function Scrubber.setRange(self: Fields & Types.Scrubber, minimum: number?, maximum: number?): Types.Scrubber
	self.minimum = minimum
	self.maximum = maximum

	Scrubber.commitValue(self, self.current)

	return self
end

function Scrubber.setStep(self: Fields & Types.Scrubber, step: number): Types.Scrubber
	self.step = math.max(0, step)

	Scrubber.paint(self)

	return self
end

--- Steps per pixel of drag. One by default.
function Scrubber.setSensitivity(self: Fields & Types.Scrubber, sensitivity: number): Types.Scrubber
	self.sensitivity = math.max(0.001, sensitivity)

	return self
end

function Scrubber.setValue(self: Fields & Types.Scrubber, value: Types.Bindable<number>): Types.Scrubber
	Node.bind(self, "value", value, function(next: number)
		self.current = Scrubber.quantise(self, next)

		Scrubber.paint(self)
	end)

	return self
end

function Scrubber.setLabel(self: Fields & Types.Scrubber, label: Types.Bindable<string>): Types.Scrubber
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

function Scrubber.setFormat(self: Fields & Types.Scrubber, format: (number) -> string): Types.Scrubber
	self.formatter = format

	Scrubber.paint(self)

	return self
end

function Scrubber.onChanged(self: Fields & Types.Scrubber, handler: (number) -> ()): Types.Scrubber
	return self:on("changed", handler)
end

function Scrubber.onCommitted(self: Fields & Types.Scrubber, handler: (number) -> ()): Types.Scrubber
	return self:on("committed", handler)
end

function Scrubber.value(self: Fields & Types.Scrubber): number
	return self.current
end

function Scrubber.measure(self: Fields & Types.Scrubber, available: Vector2): Vector2
	local theme = self.app.theme
	local width = math.max(1, available.X - self.margin * 2)

	self.desired = Vector2.new(math.ceil(width), theme.size.control)
	self.measured = true

	return self.desired
end

Element.install(Scrubber)

return Scrubber
