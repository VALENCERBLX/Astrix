--!strict

--- A level, not a task. Disk space, health, how full a stash is.
---
--- The difference from a progress bar is worth stating, because they look
--- alike: a progress bar goes one way and ends, and its colour means nothing.
--- A meter sits wherever the value happens to be, and its colour is the point —
--- it turns as the level crosses into territory you care about.
---
--- Which direction counts as bad is `optimum`: with it high, low readings are
--- the warning; with it low, high readings are. Health and disk usage are the
--- same widget pointed opposite ways.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Element = require(script.Parent.Element)

local Meter = {}
Meter.__index = Meter

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	minimum: number,
	maximum: number,
	low: number?,
	high: number?,
	optimum: string,

	labelText: string,
	showValue: boolean,
	thickness: number,
	formatter: ((number, number) -> string)?,
}

--- Creates a meter. Prefer `panel:meter(label)`.
function Meter.new(app: Types.App): Types.Meter
	local theme = app.theme
	local scope = app.scope:child()

	local thickness = theme.size.rail + 2

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.row + thickness),
			Name = "Meter",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, theme.space.xs),
			{
				class = "Frame",
				ref = "header",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.row),
					LayoutOrder = 1,
					Visible = false,
					Name = "Header",
				},
				children = {
					{
						class = "TextLabel",
						ref = "label",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.new(0.6, 0, 1, 0),

							Font = theme.font.body,
							TextSize = theme.text.sm,
							TextColor3 = theme.color.textMuted,
							TextTransparency = theme.transparency.muted,
							TextXAlignment = Enum.TextXAlignment.Left,

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
							Size = UDim2.new(0.4, 0, 1, 0),

							Font = theme.font.mono,
							TextSize = theme.text.xs,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Right,

							Name = "Readout",
							Text = "",
						},
					},
				},
			},
			{
				class = "Frame",
				ref = "rail",
				props = {
					BackgroundColor3 = theme.color.track,
					BackgroundTransparency = theme.transparency.track,
					BorderSizePixel = 0,

					Size = UDim2.new(1, 0, 0, thickness),
					LayoutOrder = 2,
					Name = "Rail",
				},
				children = {
					Create.corner(UDim.new(1, 0)),
					{
						class = "Frame",
						ref = "fill",
						props = {
							BackgroundColor3 = theme.color.success,
							BorderSizePixel = 0,
							Size = UDim2.fromScale(0, 1),
							Name = "Fill",
						},
						children = { Create.corner(UDim.new(1, 0)) },
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

		kind = "meter",
		desired = Vector2.new(0, thickness),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		minimum = 0,
		maximum = 1,
		low = nil,
		high = nil,
		optimum = "high",

		labelText = "",
		showValue = true,
		thickness = thickness,
		formatter = nil,
	}

	return setmetatable(fields, Meter) :: any
end

--- Which band the level is in: good, middling, or the one you should look at.
function Meter.zone(self: Fields): string
	local low = self.low
	local high = self.high

	if not low and not high then
		return "ok"
	end

	local below = low ~= nil and self.current < low
	local above = high ~= nil and self.current > high

	if self.optimum == "high" then
		if below then
			return "danger"
		end

		return if above or (high == nil and not below) then "ok" else "warn"
	end

	if above then
		return "danger"
	end

	return if below or (low == nil and not above) then "ok" else "warn"
end

function Meter.paint(self: Fields, immediate: boolean?)
	local theme = self.app.theme
	local span = self.maximum - self.minimum
	local fraction = if span == 0 then 0 else math.clamp((self.current - self.minimum) / span, 0, 1)

	local zone = Meter.zone(self)
	local color = if zone == "danger"
		then theme.color.danger
		elseif zone == "warn" then theme.color.warn
		else theme.color.success

	local fill = self.refs.fill :: Frame
	local target = { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = color }

	if immediate then
		Motion.set(fill, target)
	else
		Motion.animate(fill, target, theme:spec("morph"))
	end

	if self.showValue then
		local readout = self.refs.readout :: TextLabel

		readout.Text = if self.formatter
			then self.formatter(self.current, self.maximum)
			else `{math.round(fraction * 100)}%`
	end
end

function Meter.setValue(self: Fields & Types.Meter, value: Types.Bindable<number>): Types.Meter
	Node.bind(self, "value", value, function(next: number)
		self.current = next

		Meter.paint(self)
	end)

	return self
end

function Meter.setRange(self: Fields & Types.Meter, minimum: number, maximum: number): Types.Meter
	self.minimum = minimum
	self.maximum = math.max(minimum, maximum)

	Meter.paint(self)

	return self
end

--- The thresholds the colour turns on. Either may be left out.
function Meter.setBands(self: Fields & Types.Meter, low: number?, high: number?): Types.Meter
	self.low = low
	self.high = high

	Meter.paint(self)

	return self
end

--- `"high"` means high readings are healthy — ammunition, battery. `"low"`
--- means low ones are — disk usage, ping.
function Meter.setOptimum(self: Fields & Types.Meter, optimum: "high" | "low"): Types.Meter
	self.optimum = optimum

	Meter.paint(self)

	return self
end

function Meter.setLabel(self: Fields & Types.Meter, label: Types.Bindable<string>): Types.Meter
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		;(self.refs.header :: Frame).Visible = self.labelText ~= "" or self.showValue

		self:invalidate()
	end)

	return self
end

function Meter.setShowValue(self: Fields & Types.Meter, shown: boolean?): Types.Meter
	self.showValue = shown ~= false
	;(self.refs.readout :: TextLabel).Visible = self.showValue
	;(self.refs.header :: Frame).Visible = self.labelText ~= "" or self.showValue

	Meter.paint(self)

	return self:invalidate()
end

--- How the readout is written. Given the value and the maximum.
function Meter.setFormat(self: Fields & Types.Meter, format: (number, number) -> string): Types.Meter
	self.formatter = format

	Meter.paint(self)

	return self
end

function Meter.setThickness(self: Fields & Types.Meter, thickness: number): Types.Meter
	self.thickness = math.max(1, thickness)
	;(self.refs.rail :: Frame).Size = UDim2.new(1, 0, 0, self.thickness)

	return self:invalidate()
end

function Meter.value(self: Fields & Types.Meter): number
	return self.current
end

function Meter.measure(self: Fields & Types.Meter, available: Vector2): Vector2
	local theme = self.app.theme
	local height = self.thickness

	if (self.refs.header :: Frame).Visible then
		height += theme.size.row + theme.space.xs
	end

	self.desired = Vector2.new(math.ceil(math.max(1, available.X - self.margin * 2)), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Meter)

return Meter
