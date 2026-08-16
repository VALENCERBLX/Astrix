--!strict

--- A key capture row: a label and a button that, once clicked, binds the next
--- key you press.
---
--- Escape cancels the capture and Backspace clears the binding, which is what
--- every keybind row anybody has ever used does.
--- @section Elements

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Element = require(script.Parent.Element)

local Keybind = {}
Keybind.__index = Keybind

export type Fields = Types.NodeFields & Types.ElementFields & {
	key: Enum.KeyCode?,
	labelText: string,
	capturing: boolean,
	listener: RBXScriptConnection?,
}

local CHIP_WIDTH = 92

--- Creates a keybind row. Prefer `panel:keybind(label)`.
function Keybind.new(app: Types.App): Types.Keybind
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Keybind",
		},
		children = {
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -(CHIP_WIDTH + theme.space.md), 1, 0),

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
				class = "TextButton",
				ref = "chip",
				props = {
					BackgroundColor3 = theme.color.surfaceSunken,
					BackgroundTransparency = 0.3,
					BorderSizePixel = 0,
					AutoButtonColor = false,

					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(CHIP_WIDTH, theme.size.row),

					Font = theme.font.mono,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textMuted,

					Name = "Chip",
					Text = "None",
				},
				children = {
					Create.corner(theme.radius.sm),
					{
						class = "UIStroke",
						ref = "stroke",
						props = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = theme.color.border,
							Thickness = theme.stroke.hairline,
							Transparency = theme.transparency.border,
						},
					},
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

		kind = "keybind",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		key = nil,
		labelText = "",
		capturing = false,
		listener = nil,
	}

	local keybind = setmetatable(fields, Keybind) :: any

	local chip = refs.chip :: TextButton

	scope:add(chip.Activated:Connect(function()
		if fields.enabled then
			Keybind.capture(keybind)
		end
	end))

	return keybind
end

--- Redraws the chip for the current key and capture state.
function Keybind.paint(self: Fields)
	local theme = self.app.theme
	local chip = self.refs.chip :: TextButton
	local stroke = self.refs.stroke :: UIStroke

	if self.capturing then
		chip.Text = "Press a key…"
		chip.TextColor3 = theme.color.accent

		Motion.animate(stroke, { Color = theme.color.accent, Transparency = 0 }, theme:spec("hover"))

		return
	end

	chip.Text = if self.key then self.key.Name else "None"
	chip.TextColor3 = if self.key then theme.color.text else theme.color.textGhost

	Motion.animate(
		stroke,
		{ Color = theme.color.border, Transparency = theme.transparency.border },
		theme:spec("hover")
	)
end

--- Listens for the next key. Escape cancels, Backspace clears.
function Keybind.capture(self: Fields & Types.Keybind)
	if self.capturing then
		return
	end

	self.capturing = true

	Keybind.paint(self)

	local connection: RBXScriptConnection

	connection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		connection:Disconnect()

		self.capturing = false
		self.listener = nil

		if input.KeyCode == Enum.KeyCode.Escape then
			Keybind.paint(self)

			return
		end

		self.key = if input.KeyCode == Enum.KeyCode.Backspace then nil else input.KeyCode

		Keybind.paint(self)

		self:emit("changed", self.key)
	end)

	self.listener = connection
	self.scope:add(connection)
end

function Keybind.setLabel(self: Fields & Types.Keybind, label: Types.Bindable<string>): Types.Keybind
	local text = self.refs.label :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		self.labelText = value
		text.Text = value
	end)

	return self
end

function Keybind.setValue(self: Fields & Types.Keybind, key: Types.Bindable<Enum.KeyCode?>): Types.Keybind
	Node.bind(self, "value", key, function(next: Enum.KeyCode?)
		self.key = next

		Keybind.paint(self)
	end)

	return self
end

function Keybind.onChanged(self: Fields & Types.Keybind, handler: (Enum.KeyCode?) -> ()): Types.Keybind
	return self:on("changed", handler)
end

function Keybind.value(self: Fields & Types.Keybind): Enum.KeyCode?
	return self.key
end

function Keybind.measure(self: Fields & Types.Keybind, available: Vector2): Vector2
	local theme = self.app.theme

	local natural = self.app.measure:width(self.labelText, theme.text.sm, theme.font.body)
		+ CHIP_WIDTH
		+ theme.space.md

	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), theme.size.control)
	self.measured = true

	return self.desired
end

function Keybind.commit(self: Fields & Types.Keybind, inner: Vector2, vertical: boolean, share: number)
	local theme = self.app.theme

	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	;(self.refs.label :: TextLabel).Size =
		UDim2.new(0, math.max(0, width - CHIP_WIDTH - theme.space.md), 1, 0)
end

Element.install(Keybind)

return Keybind
