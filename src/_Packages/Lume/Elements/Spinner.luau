--!strict

--- A ring that turns while something is happening.
---
--- Used where a progress bar would be a lie: you know the work has started and
--- nothing more. A bar that fills to a made-up percentage is worse than a
--- spinner, because it promises an ending it cannot see.
---
--- The sweep is a rotating gradient rather than a spritesheet, so it costs one
--- instance and inherits the theme's colours without an asset to ship.
--- @section Elements

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Spinner = {}
Spinner.__index = Spinner

export type Fields = Types.NodeFields & Types.ElementFields & {
	spinning: boolean,
	speed: number,
	diameter: number,
	labelText: string,
	turn: RBXScriptConnection?,
	angle: number,
}

--- Creates a spinner. Prefer `panel:spinner(label)`.
function Spinner.new(app: Types.App): Types.Spinner
	local theme = app.theme
	local scope = app.scope:child()

	local diameter = theme.size.icon + 4

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, diameter),
			Name = "Spinner",
		},
		children = {
			Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "Frame",
				ref = "ring",
				props = {
					BackgroundColor3 = theme.color.accent,
					BorderSizePixel = 0,

					Size = UDim2.fromOffset(diameter, diameter),
					LayoutOrder = 1,
					Name = "Ring",
				},
				children = {
					Create.corner(UDim.new(1, 0)),
					--// the sweep: opaque at one end of the gradient, gone at
					--// the other, and the whole thing rotates
					Create.gradient(
						ColorSequence.new(theme.color.accent),
						0,
						NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.5, 0.6),
							NumberSequenceKeypoint.new(1, 0),
						})
					),
					{
						class = "Frame",
						props = {
							BackgroundColor3 = theme.color.surface,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(diameter - 6, diameter - 6),
							Name = "Hole",
						},
						children = { Create.corner(UDim.new(1, 0)) },
					},
				},
			},
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, diameter),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,
					TextXAlignment = Enum.TextXAlignment.Left,

					LayoutOrder = 2,
					Visible = false,
					Name = "Label",
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

		kind = "spinner",
		desired = Vector2.new(diameter, diameter),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		spinning = false,
		speed = 1.1,
		diameter = diameter,
		labelText = "",
		turn = nil,
		angle = 0,
	}

	local spinner = setmetatable(fields, Spinner) :: any

	Spinner.setSpinning(spinner, true)

	return spinner
end

--- Starts or stops the sweep. A stopped spinner keeps its place rather than
--- snapping back to the top, so stopping and starting does not jump.
function Spinner.setSpinning(self: Fields & Types.Spinner, spinning: boolean?): Types.Spinner
	local next = spinning ~= false

	if next == self.spinning then
		return self
	end

	self.spinning = next

	if self.turn then
		self.turn:Disconnect()

		self.turn = nil
	end

	local ring = self.refs.ring :: Frame

	if not next then
		ring.Visible = false

		return self
	end

	ring.Visible = true

	local gradient = ring:FindFirstChildOfClass("UIGradient")

	local connection = RunService.RenderStepped:Connect(function(delta)
		self.angle = (self.angle + delta * 360 / self.speed) % 360

		if gradient then
			gradient.Rotation = self.angle
		end
	end)

	self.turn = connection
	self.scope:add(connection)

	return self
end

--- Seconds per rotation.
function Spinner.setSpeed(self: Fields & Types.Spinner, seconds: number): Types.Spinner
	self.speed = math.max(0.05, seconds)

	return self
end

function Spinner.setDiameter(self: Fields & Types.Spinner, diameter: number): Types.Spinner
	self.diameter = math.max(8, diameter)

	local ring = self.refs.ring :: Frame

	ring.Size = UDim2.fromOffset(self.diameter, self.diameter)

	local hole = ring:FindFirstChild("Hole")

	if hole then
		(hole :: Frame).Size = UDim2.fromOffset(self.diameter - 6, self.diameter - 6)
	end

	return self:invalidate()
end

function Spinner.setLabel(self: Fields & Types.Spinner, label: Types.Bindable<string>): Types.Spinner
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

function Spinner.measure(self: Fields & Types.Spinner, available: Vector2): Vector2
	local theme = self.app.theme
	local width = self.diameter

	if self.labelText ~= "" then
		width += theme.space.sm + self.app.measure:width(self.labelText, theme.text.sm, theme.font.body)
	end

	self.desired = Vector2.new(
		math.ceil(math.min(width, math.max(1, available.X - self.margin * 2))),
		math.ceil(self.diameter)
	)
	self.measured = true

	return self.desired
end

Element.install(Spinner)

return Spinner
