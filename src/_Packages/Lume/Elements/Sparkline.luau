--!strict

--- A line chart the size of a line of text.
---
--- No axes, no grid, no legend — the shape is the whole message. Used inline
--- next to a number, where a full chart would be a change of subject.
---
--- Drawn as rotated segments rather than an image, so it costs one frame per
--- point and inherits the theme's colours.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Sparkline = {}
Sparkline.__index = Sparkline

export type Fields = Types.NodeFields & Types.ElementFields & {
	points: { number },
	segments: { Frame },
	color: Color3?,
	thickness: number,
	height: number,
	minimum: number?,
	maximum: number?,
	area: boolean,
}

--- Creates a sparkline. Prefer `panel:sparkline(points)`.
function Sparkline.new(app: Types.App): Types.Sparkline
	local theme = app.theme
	local scope = app.scope:child()

	local height = 28

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,

			Size = UDim2.new(1, 0, 0, height),
			Name = "Sparkline",
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

		kind = "sparkline",
		desired = Vector2.new(0, height),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		points = {},
		segments = {},
		color = nil,
		thickness = 2,
		height = height,
		minimum = nil,
		maximum = nil,
		area = false,
	}

	return setmetatable(fields, Sparkline) :: any
end

--- Rebuilds the segments. Positions are fractions of the frame, so the line
--- follows the element's width without being redrawn when it changes.
function Sparkline.rebuild(self: Fields & Types.Sparkline)
	local theme = self.app.theme

	for _, segment in self.segments do
		segment:Destroy()
	end

	table.clear(self.segments)

	local count = #self.points

	if count < 2 then
		return
	end

	local low = self.minimum
	local high = self.maximum

	if not low or not high then
		low = self.points[1]
		high = self.points[1]

		for _, point in self.points do
			low = math.min(low :: number, point)
			high = math.max(high :: number, point)
		end
	end

	local span = (high :: number) - (low :: number)
	local color = self.color or theme.color.accent

	--// a flat line has no span to divide by, and sits down the middle rather
	--// than at the bottom, where it would read as zero
	local function at(index: number): (number, number)
		local x = (index - 1) / (count - 1)
		local y = if span == 0 then 0.5 else 1 - ((self.points[index] - (low :: number)) / span)

		return x, y
	end

	for index = 1, count - 1 do
		local x1, y1 = at(index)
		local x2, y2 = at(index + 1)

		--// pixel geometry is not known until the element is laid out, so the
		--// segment is positioned in scale and rotated by the angle between the
		--// two points in the element's own aspect
		local width = self.instance.AbsoluteSize.X
		local height = self.instance.AbsoluteSize.Y

		local dx = (x2 - x1) * math.max(width, 1)
		local dy = (y2 - y1) * math.max(height, 1)
		local length = math.sqrt(dx * dx + dy * dy)

		local segment = Create.node(self.scope, {
			class = "Frame",
			props = {
				BackgroundColor3 = color,
				BorderSizePixel = 0,

				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(x1, y1),
				Size = UDim2.fromOffset(math.max(length, 1), self.thickness),
				Rotation = math.deg(math.atan2(dy, dx)),

				Name = `Segment{index}`,
			},
			children = { Create.corner(UDim.new(1, 0)) },
		}) :: Frame

		segment.Parent = self.instance

		table.insert(self.segments, segment)
	end
end

function Sparkline.setPoints(self: Fields & Types.Sparkline, points: Types.Bindable<{ number }>): Types.Sparkline
	Node.bind(self, "points", points, function(next: { number })
		self.points = next

		Sparkline.rebuild(self)
	end)

	return self
end

--- Fixes the vertical scale. Without it the line uses its own low and high,
--- which makes a flat-ish series look dramatic.
function Sparkline.setRange(self: Fields & Types.Sparkline, minimum: number?, maximum: number?): Types.Sparkline
	self.minimum = minimum
	self.maximum = maximum

	Sparkline.rebuild(self)

	return self
end

function Sparkline.setColor(self: Fields & Types.Sparkline, color: Color3): Types.Sparkline
	self.color = color

	Sparkline.rebuild(self)

	return self
end

function Sparkline.setThickness(self: Fields & Types.Sparkline, thickness: number): Types.Sparkline
	self.thickness = math.max(1, thickness)

	Sparkline.rebuild(self)

	return self
end

function Sparkline.setHeight(self: Fields & Types.Sparkline, height: number): Types.Sparkline
	self.height = math.max(8, height)

	return self:invalidate()
end

--- The last point, which is usually the one being written about.
function Sparkline.last(self: Fields & Types.Sparkline): number?
	return self.points[#self.points]
end

function Sparkline.measure(self: Fields & Types.Sparkline, available: Vector2): Vector2
	self.desired = Vector2.new(math.ceil(math.max(1, available.X - self.margin * 2)), self.height)
	self.measured = true

	return self.desired
end

function Sparkline.commit(self: Fields & Types.Sparkline, inner: Vector2, vertical: boolean, share: number)
	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), self.height)

	--// the segments are sized in pixels, so they are rebuilt once the element
	--// knows how wide it actually is
	Sparkline.rebuild(self)
end

Element.install(Sparkline)

return Sparkline
