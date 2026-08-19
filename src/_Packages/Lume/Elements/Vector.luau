--!strict

--- Two or three numbers that belong together: a position, a size, a colour in
--- RGB if you like.
---
--- Each axis is a scrubbable field, and they share one label. Three separate
--- scrubbers would work, but they would drift apart in width and each would
--- carry its own label — and a Vector3 read as three unrelated numbers is
--- exactly the mistake this element exists to prevent.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Scrubber = require(script.Parent.Scrubber)
local Element = require(script.Parent.Element)

local Vector = {}
Vector.__index = Vector

export type Axis = { key: string, box: TextBox, tint: Color3 }

export type Fields = Types.NodeFields & Types.ElementFields & {
	values: { number },
	axes: { Axis },
	count: number,
	step: number,
	sensitivity: number,
	minimum: number?,
	maximum: number?,
	labelText: string,
	typing: number?,
}

local KEYS = { "X", "Y", "Z", "W" }

--- Creates a vector input. Prefer `panel:vector(label, count)`.
function Vector.new(app: Types.App): Types.Vector
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Vector",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, theme.space.xs),
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.row),

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
				class = "Frame",
				ref = "axes",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.control),
					LayoutOrder = 2,
					Name = "Axes",
				},
				children = {
					Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
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

		kind = "vector",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		values = { 0, 0, 0 },
		axes = {},
		count = 3,
		step = 0.1,
		sensitivity = 1,
		minimum = nil,
		maximum = nil,
		labelText = "",
		typing = nil,
	}

	local vector = setmetatable(fields, Vector) :: any

	Vector.rebuild(vector)

	return vector
end

function Vector.quantise(self: Fields, value: number): number
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

function Vector.paint(self: Fields)
	for index, axis in self.axes do
		if self.typing ~= index then
			axis.box.Text = string.format(if self.step % 1 == 0 then "%d" else "%g", self.values[index] or 0)
		end
	end
end

function Vector.rebuild(self: Fields & Types.Vector)
	local theme = self.app.theme
	local host = self.refs.axes :: Frame

	for _, axis in self.axes do
		axis.box.Parent = nil
	end

	for _, child in host:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	table.clear(self.axes)

	--// one tint per axis, the convention every 3D tool shares: X red, Y green,
	--// Z blue. Reading a triple without them is guesswork
	local tints = { theme.color.danger, theme.color.success, theme.color.accent, theme.color.warn }

	for index = 1, self.count do
		local key = KEYS[index] or tostring(index)

		local box, refs = Create.tree(self.scope, {
			class = "TextBox",
			ref = "box",
			props = {
				BackgroundColor3 = theme.color.surfaceSunken,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,

				Size = UDim2.new(1 / self.count, -theme.space.xs, 0, theme.size.control),
				LayoutOrder = index,

				Font = theme.font.mono,
				TextSize = theme.text.sm,
				TextColor3 = theme.color.text,

				Name = key,
				Text = "0",
			},
			children = {
				Create.corner(theme.radius.sm),
				Create.padding(theme.space.md, 0, theme.space.xs, 0),
				{
					class = "Frame",
					ref = "tint",
					props = {
						BackgroundColor3 = tints[index] or theme.color.accent,
						BorderSizePixel = 0,

						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, -theme.space.md + 3, 0.5, 0),
						Size = UDim2.fromOffset(3, theme.size.control - 8),
						Name = "Tint",
					},
					children = { Create.corner(UDim.new(1, 0)) },
				},
			},
		})

		box.Parent = host

		local axis: Axis = { key = key, box = box :: TextBox, tint = tints[index] or theme.color.accent }

		table.insert(self.axes, axis)

		local slot = index

		Scrubber.attach(self.scope, box :: TextBox, function()
			return self.values[slot] or 0
		end, function(value, live)
			if not self.enabled then
				return
			end

			Vector.setAxis(self, slot, value)

			if not live then
				self:emit("committed", Vector.value(self))
			end
		end, function()
			return self.step * self.sensitivity
		end)

		Hover.attach(self.scope, box :: TextBox, function(hovering)
			if not self.enabled then
				return
			end

			;(box :: TextBox).BackgroundTransparency = if hovering then 0.25 else 0.4
		end)

		self.scope:add((box :: TextBox).Focused:Connect(function()
			self.typing = slot
		end))

		self.scope:add((box :: TextBox).FocusLost:Connect(function()
			self.typing = nil

			local typed = tonumber(((box :: TextBox).Text:gsub("[^%-%.%d]", "")))

			if typed then
				Vector.setAxis(self, slot, typed)

				self:emit("committed", Vector.value(self))
			end

			Vector.paint(self)
		end))
	end

	Vector.paint(self)
end

--- Sets one axis and fires `changed` with the whole vector.
function Vector.setAxis(self: Fields & Types.Vector, index: number, value: number): Types.Vector
	local next = Vector.quantise(self, value)

	if self.values[index] == next then
		return self
	end

	self.values[index] = next

	Vector.paint(self)

	self:emit("changed", Vector.value(self))

	return self
end

--- Two axes or three. Four if you have a reason.
function Vector.setCount(self: Fields & Types.Vector, count: number): Types.Vector
	self.count = math.clamp(math.round(count), 1, 4)

	Vector.rebuild(self)

	return self:invalidate()
end

function Vector.setStep(self: Fields & Types.Vector, step: number): Types.Vector
	self.step = math.max(0, step)

	Vector.paint(self)

	return self
end

function Vector.setSensitivity(self: Fields & Types.Vector, sensitivity: number): Types.Vector
	self.sensitivity = math.max(0.001, sensitivity)

	return self
end

function Vector.setRange(self: Fields & Types.Vector, minimum: number?, maximum: number?): Types.Vector
	self.minimum = minimum
	self.maximum = maximum

	for index = 1, self.count do
		self.values[index] = Vector.quantise(self, self.values[index] or 0)
	end

	Vector.paint(self)

	return self
end

--- Takes a Vector2, a Vector3, or a plain list of numbers.
function Vector.setValue(self: Fields & Types.Vector, value: Types.Bindable<any>): Types.Vector
	Node.bind(self, "value", value, function(next: any)
		local read: { number }

		if typeof(next) == "Vector3" then
			read = { next.X, next.Y, next.Z }
		elseif typeof(next) == "Vector2" then
			read = { next.X, next.Y }
		else
			read = next :: { number }
		end

		for index = 1, self.count do
			self.values[index] = Vector.quantise(self, read[index] or 0)
		end

		Vector.paint(self)
	end)

	return self
end

function Vector.setLabel(self: Fields & Types.Vector, label: Types.Bindable<string>): Types.Vector
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

function Vector.onChanged(self: Fields & Types.Vector, handler: ({ number }) -> ()): Types.Vector
	return self:on("changed", handler)
end

function Vector.onCommitted(self: Fields & Types.Vector, handler: ({ number }) -> ()): Types.Vector
	return self:on("committed", handler)
end

--- The axes as a plain list.
function Vector.value(self: Fields & Types.Vector): { number }
	local out = {}

	for index = 1, self.count do
		table.insert(out, self.values[index] or 0)
	end

	return out
end

--- The same thing as a Vector3, for the common case.
function Vector.vector3(self: Fields & Types.Vector): Vector3
	return Vector3.new(self.values[1] or 0, self.values[2] or 0, self.values[3] or 0)
end

function Vector.measure(self: Fields & Types.Vector, available: Vector2): Vector2
	local theme = self.app.theme
	local height = theme.size.control

	if self.labelText ~= "" then
		height += theme.size.row + theme.space.xs
	end

	self.desired = Vector2.new(math.ceil(math.max(1, available.X - self.margin * 2)), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Vector)

return Vector
