--!strict

--- A colour picker: a saturation/value square, a hue rail under it, and a hex
--- field beside the swatch.
---
--- **Hue, saturation and value are the state — not the Color3.** Drag the
--- cursor into the black corner of an orange square and the colour becomes
--- black, which in RGB has thrown the orange away: let go, drag back out, and
--- you would come back red. Keeping HSV means the square stays orange the whole
--- time, because the hue was never part of what you changed.
---
--- Two events, like the slider: `changed` fires continuously while dragging and
--- `committed` fires once on release. Preview on `changed`, save on `committed`.
--- @section Elements

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Element = require(script.Parent.Element)

local ColorPicker = {}
ColorPicker.__index = ColorPicker

export type Fields = Types.NodeFields & Types.ElementFields & {
	hue: number,
	saturation: number,
	brightness: number,

	labelText: string,
	squareHeight: number,
	showHex: boolean,
	dragging: string?,
	typing: boolean,
}

local RAIL = 12
local CURSOR = 12
local SWATCH = 28

--// the six corners of the wheel, so the rail reads left to right as red,
--// yellow, green, cyan, blue, magenta, red
local HUES = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.1667, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.3333, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.6667, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.8333, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

--// locals
local function hexOf(color: Color3): string
	return `#{string.upper(color:ToHex())}`
end

--- Creates a colour picker. Prefer `panel:colorPicker(label)`.
function ColorPicker.new(app: Types.App): Types.ColorPicker
	local theme = app.theme
	local scope = app.scope:child()

	local squareHeight = 120

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, squareHeight),
			Name = "ColorPicker",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, theme.space.sm),
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
				ref = "square",
				props = {
					BackgroundColor3 = Color3.fromRGB(255, 0, 0),
					BorderSizePixel = 0,
					ClipsDescendants = false,

					Size = UDim2.new(1, 0, 0, squareHeight),
					LayoutOrder = 2,
					Name = "Square",
				},
				children = {
					Create.corner(theme.radius.sm),
					{
						class = "Frame",
						props = {
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
							Name = "Saturation",
						},
						children = {
							Create.corner(theme.radius.sm),
							--// white on the left fading out to the right: the
							--// saturation axis
							Create.gradient(
								ColorSequence.new(Color3.fromRGB(255, 255, 255)),
								0,
								NumberSequence.new(0, 1)
							),
						},
					},
					{
						class = "Frame",
						props = {
							BackgroundColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
							Name = "Value",
						},
						children = {
							Create.corner(theme.radius.sm),
							--// and black at the bottom fading up: the value axis
							Create.gradient(ColorSequence.new(Color3.fromRGB(0, 0, 0)), 90, NumberSequence.new(1, 0)),
						},
					},
					{
						class = "Frame",
						ref = "cursor",
						props = {
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(CURSOR, CURSOR),
							ZIndex = 3,
							Name = "Cursor",
						},
						children = {
							Create.corner(UDim.new(1, 0)),
							Create.stroke(Color3.fromRGB(255, 255, 255), 2, 0),
						},
					},
				},
			},
			{
				class = "Frame",
				ref = "rail",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,

					Size = UDim2.new(1, 0, 0, RAIL),
					LayoutOrder = 3,
					Name = "Hue",
				},
				children = {
					Create.corner(UDim.new(1, 0)),
					{
						class = "Frame",
						props = {
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
							Name = "Spectrum",
						},
						children = { Create.corner(UDim.new(1, 0)), Create.gradient(HUES, 0) },
					},
					{
						class = "Frame",
						ref = "thumb",
						props = {
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0, 0, 0.5, 0),
							Size = UDim2.fromOffset(RAIL + 4, RAIL + 4),
							ZIndex = 3,
							Name = "Thumb",
						},
						children = {
							Create.corner(UDim.new(1, 0)),
							Create.stroke(theme.color.borderStrong, 1, 0.2),
						},
					},
				},
			},
			{
				class = "Frame",
				ref = "row",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,

					Size = UDim2.new(1, 0, 0, SWATCH),
					LayoutOrder = 4,
					Name = "Readout",
				},
				children = {
					Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					{
						class = "Frame",
						ref = "swatch",
						props = {
							BackgroundColor3 = Color3.fromRGB(255, 0, 0),
							BorderSizePixel = 0,

							Size = UDim2.fromOffset(SWATCH, SWATCH),
							LayoutOrder = 1,
							Name = "Swatch",
						},
						children = {
							Create.corner(theme.radius.sm),
							Create.stroke(theme.color.border, 1, theme.transparency.border),
						},
					},
					{
						class = "TextBox",
						ref = "hex",
						props = {
							BackgroundColor3 = theme.color.surfaceSunken,
							BackgroundTransparency = 0.4,
							BorderSizePixel = 0,
							ClearTextOnFocus = false,

							Size = UDim2.new(1, -(SWATCH + theme.space.sm), 0, SWATCH),
							LayoutOrder = 2,

							Font = theme.font.mono,
							TextSize = theme.text.sm,
							TextColor3 = theme.color.text,

							Name = "Hex",
							Text = "#FF0000",
						},
						children = {
							Create.corner(theme.radius.sm),
							Create.padding(theme.space.sm, 0),
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

		kind = "colorpicker",
		desired = Vector2.new(0, squareHeight),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		hue = 0,
		saturation = 1,
		brightness = 1,

		labelText = "",
		squareHeight = squareHeight,
		showHex = true,
		dragging = nil,
		typing = false,
	}

	local picker = setmetatable(fields, ColorPicker) :: any

	local square = refs.square :: Frame
	local rail = refs.rail :: Frame
	local hex = refs.hex :: TextBox

	local function fraction(position: number, origin: number, size: number): number
		return math.clamp((position - origin) / math.max(1, size), 0, 1)
	end

	local function apply(input: InputObject)
		local point = Vector2.new(input.Position.X, input.Position.Y)

		if fields.dragging == "square" then
			fields.saturation = fraction(point.X, square.AbsolutePosition.X, square.AbsoluteSize.X)
			fields.brightness = 1 - fraction(point.Y, square.AbsolutePosition.Y, square.AbsoluteSize.Y)
		else
			fields.hue = fraction(point.X, rail.AbsolutePosition.X, rail.AbsoluteSize.X)
		end

		ColorPicker.paint(fields)

		picker:emit("changed", ColorPicker.value(fields))
	end

	local function grab(target: string)
		return function(input: InputObject)
			if not fields.enabled then
				return
			end

			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			fields.dragging = target

			apply(input)
		end
	end

	scope:add(square.InputBegan:Connect(grab("square")))
	scope:add(rail.InputBegan:Connect(grab("rail")))

	scope:add(UserInputService.InputChanged:Connect(function(input)
		if not fields.dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		apply(input)
	end))

	scope:add(UserInputService.InputEnded:Connect(function(input)
		if not fields.dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		fields.dragging = nil

		picker:emit("committed", ColorPicker.value(fields))
	end))

	--// while the field has focus its text is whatever is being typed, not the
	--// colour — repainting over a half-finished "#7EA" would be maddening
	scope:add(hex.Focused:Connect(function()
		fields.typing = true
	end))

	scope:add(hex.FocusLost:Connect(function()
		fields.typing = false

		local typed = hex.Text:gsub("%s", "")
		local ok, parsed = pcall(Color3.fromHex, typed)

		if ok then
			ColorPicker.assign(fields, parsed :: Color3)

			picker:emit("changed", ColorPicker.value(fields))
			picker:emit("committed", ColorPicker.value(fields))
		end

		--// a colour it could not read, or one it could: either way the field
		--// goes back to showing the truth
		ColorPicker.paint(fields)
	end))

	ColorPicker.paint(fields)

	return picker
end

--- The colour the three components add up to.
function ColorPicker.value(self: Fields): Color3
	return Color3.fromHSV(self.hue, self.saturation, self.brightness)
end

--- Takes a Color3 apart into the components the picker actually holds.
function ColorPicker.assign(self: Fields, color: Color3)
	local hue, saturation, brightness = color:ToHSV()

	--// pure black and pure white have no meaningful hue, and reading the zero
	--// back would swing the square to red for no reason the user can see
	if saturation > 0 then
		self.hue = hue
	end

	self.saturation = saturation
	self.brightness = brightness
end

--- Moves the cursor, the thumb and the swatch to match the state.
function ColorPicker.paint(self: Fields)
	local color = ColorPicker.value(self)

	local square = self.refs.square :: Frame
	local cursor = self.refs.cursor :: Frame
	local thumb = self.refs.thumb :: Frame
	local swatch = self.refs.swatch :: Frame
	local hex = self.refs.hex :: TextBox

	square.BackgroundColor3 = Color3.fromHSV(self.hue, 1, 1)
	cursor.Position = UDim2.fromScale(self.saturation, 1 - self.brightness)
	thumb.Position = UDim2.new(self.hue, 0, 0.5, 0)
	thumb.BackgroundColor3 = Color3.fromHSV(self.hue, 1, 1)
	swatch.BackgroundColor3 = color

	--// a light colour needs a dark cursor to stay visible on it, and the other
	--// way round
	local stroke = cursor:FindFirstChildOfClass("UIStroke")

	if stroke then
		stroke.Color = if self.brightness > 0.6 and self.saturation < 0.6
			then Color3.fromRGB(0, 0, 0)
			else Color3.fromRGB(255, 255, 255)
	end

	if not self.typing then
		hex.Text = hexOf(color)
	end
end

function ColorPicker.setValue(self: Fields & Types.ColorPicker, color: Types.Bindable<Color3>): Types.ColorPicker
	Node.bind(self, "value", color, function(next: Color3)
		ColorPicker.assign(self, next)
		ColorPicker.paint(self)
	end)

	return self
end

function ColorPicker.setLabel(self: Fields & Types.ColorPicker, label: Types.Bindable<string>): Types.ColorPicker
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

--- How tall the saturation square is. The rail and the readout are fixed.
function ColorPicker.setSquareHeight(self: Fields & Types.ColorPicker, height: number): Types.ColorPicker
	self.squareHeight = math.max(40, height)
	;(self.refs.square :: Frame).Size = UDim2.new(1, 0, 0, self.squareHeight)

	return self:invalidate()
end

--- Hides the swatch and hex field, leaving the square and the rail.
function ColorPicker.setHexField(self: Fields & Types.ColorPicker, shown: boolean?): Types.ColorPicker
	self.showHex = shown ~= false
	;(self.refs.row :: Frame).Visible = self.showHex

	return self:invalidate()
end

function ColorPicker.onChanged(self: Fields & Types.ColorPicker, handler: (Color3) -> ()): Types.ColorPicker
	return self:on("changed", handler)
end

function ColorPicker.onCommitted(self: Fields & Types.ColorPicker, handler: (Color3) -> ()): Types.ColorPicker
	return self:on("committed", handler)
end

--- Sets the colour without firing anything. For loading a saved value.
function ColorPicker.setSilent(self: Fields & Types.ColorPicker, color: Color3): Types.ColorPicker
	ColorPicker.assign(self, color)
	ColorPicker.paint(self)

	return self
end

--- The hex string, `#RRGGBB`.
function ColorPicker.hex(self: Fields & Types.ColorPicker): string
	return hexOf(ColorPicker.value(self))
end

function ColorPicker.measure(self: Fields & Types.ColorPicker, available: Vector2): Vector2
	local theme = self.app.theme
	local gap = theme.space.sm

	local height = self.squareHeight + gap + RAIL

	if self.labelText ~= "" then
		height += theme.size.row + gap
	end

	if self.showHex then
		height += gap + SWATCH
	end

	local width = math.max(1, available.X - self.margin * 2)

	self.desired = Vector2.new(math.ceil(math.min(240, width)), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(ColorPicker)

return ColorPicker
