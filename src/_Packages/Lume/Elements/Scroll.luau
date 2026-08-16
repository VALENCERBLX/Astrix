--!strict

--- A scrolling region inside a panel, capped at a maximum height.
---
--- Unlike a panel's own scroll — which only appears when the panel has run out
--- of screen — a scroll element caps itself deliberately, which is what you
--- want for one long section inside an otherwise short panel.
---
--- The optional edge fades are gradients over the region, not over the
--- content, so they stay put while the content moves under them.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Autosize = require(script.Parent.Parent.Layout.Autosize)
local Create = require(script.Parent.Parent.Core.Create)
local Element = require(script.Parent.Element)

local Scroll = {}
Scroll.__index = Scroll

export type Fields = Types.NodeFields & Types.ElementFields & {
	children: { Types.Element },
	vertical: boolean,
	gap: number,
	maxHeight: number,
	faded: boolean,
}

--// locals
local function adopt(self: Fields, element: Types.Element): Types.Element
	element.owner = self :: any

	table.insert(self.children, element)

	element.instance.LayoutOrder = #self.children
	element.instance.Parent = self.instance

	local owner = self.owner

	if owner then
		owner:refresh()
	end

	return element
end

local function factory(app: Types.App, name: string): any
	local Elements = require(script.Parent)

	return (Elements :: any)[name].new(app)
end

--- Creates a scroll region. Prefer `panel:scroll()`.
function Scroll.new(app: Types.App): Types.Scroll
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "ScrollingFrame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Size = UDim2.new(1, 0, 0, 120),
			CanvasSize = UDim2.fromOffset(0, 0),

			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarImageColor3 = theme.color.borderStrong,
			ScrollBarImageTransparency = 0.5,
			ScrollBarThickness = 3,

			ClipsDescendants = true,
			Name = "Scroll",
		},
		children = {
			{
				class = "UIListLayout",
				ref = "layout",
				props = {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, theme.space.sm),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
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

		kind = "scroll",
		desired = Vector2.new(0, 120),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		children = {},
		vertical = true,
		gap = theme.space.sm,
		maxHeight = 240,
		faded = false,
	}

	return setmetatable(fields, Scroll) :: any
end

function Scroll.setAxis(self: Fields & Types.Scroll, axis: Types.Axis): Types.Scroll
	local layout = self.refs.layout :: UIListLayout
	local scroller = self.instance :: ScrollingFrame

	self.vertical = axis == "vertical"

	layout.FillDirection = if self.vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	scroller.ScrollingDirection = if self.vertical then Enum.ScrollingDirection.Y else Enum.ScrollingDirection.X

	return self:invalidate()
end

function Scroll.setGap(self: Fields & Types.Scroll, gap: number): Types.Scroll
	self.gap = gap
	;(self.refs.layout :: UIListLayout).Padding = UDim.new(0, gap)

	return self:invalidate()
end

function Scroll.setMaxHeight(self: Fields & Types.Scroll, height: number): Types.Scroll
	self.maxHeight = math.max(1, height)

	return self:invalidate()
end

--- Fades the leading and trailing edges so clipped content reads as continuing
--- rather than as cut off.
function Scroll.setFade(self: Fields & Types.Scroll, enabled: boolean): Types.Scroll
	self.faded = enabled ~= false

	local existing = self.instance:FindFirstChild("Fade")

	if not self.faded then
		if existing then
			existing:Destroy()
		end

		return self
	end

	if existing then
		return self
	end

	local gradient = Instance.new("UIGradient")

	gradient.Name = "Fade"
	gradient.Rotation = if self.vertical then 90 else 0
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.92, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = self.instance

	self.scope:add(gradient)

	return self
end

function Scroll.setBarVisible(self: Fields & Types.Scroll, visible: boolean): Types.Scroll
	local scroller = self.instance :: ScrollingFrame

	scroller.ScrollBarThickness = if visible then 3 else 0

	return self
end

function Scroll.add(self: Fields & Types.Scroll, child: Types.Element): Types.Scroll
	adopt(self, child)

	return self
end

function Scroll.clear(self: Fields & Types.Scroll): Types.Scroll
	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	table.clear(self.children)

	return self:invalidate()
end

function Scroll.refresh(self: Fields & Types.Scroll): Types.Scroll
	return self:invalidate()
end

function Scroll.scrollToBottom(self: Fields & Types.Scroll): Types.Scroll
	local scroller = self.instance :: ScrollingFrame

	scroller.CanvasPosition = Vector2.new(0, math.max(0, scroller.CanvasSize.Y.Offset - scroller.AbsoluteSize.Y))

	return self
end

--// child factories
function Scroll.label(self: Fields & Types.Scroll, text: Types.Bindable<string>?): Types.Label
	local element = factory(self.app, "Label")

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element) :: any
end

function Scroll.group(self: Fields & Types.Scroll, axis: Types.Axis?): Types.Group
	local element = factory(self.app, "Group")

	if axis ~= nil then
		element:setAxis(axis)
	end

	return adopt(self, element) :: any
end

function Scroll.list(self: Fields & Types.Scroll): Types.List
	return adopt(self, factory(self.app, "List")) :: any
end

--// layout
--- `settled` is passed only from commit, once the real width is known.
local function input(self: Fields, available: Vector2, settled: number?): Autosize.Input
	return {
		children = self.children,
		vertical = self.vertical,

		gap = self.gap,
		padX = 0,
		padY = 0,

		--// unbounded on the scrolling axis: the content is allowed to be taller
		--// than the region, that is the entire point of a scroll
		chrome = Vector2.zero,
		room = Vector2.new(available.X, 99999),

		minWidth = 0,
		maxWidth = math.max(1, available.X - self.margin * 2),
		minHeight = 0,
		maxHeight = 99999,

		fixedWidth = settled,
		fixedHeight = nil,
	}
end

function Scroll.measure(self: Fields & Types.Scroll, available: Vector2): Vector2
	local solved = input(self, available)
	local solution = Autosize.solve(solved)

	local height = math.min(solution.content.Y, self.maxHeight)

	self.desired = Vector2.new(solution.clamped.X, math.ceil(height))
	self.measured = true

	return self.desired
end

function Scroll.commit(self: Fields & Types.Scroll, inner: Vector2, vertical: boolean, share: number)
	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	local settled = Vector2.new(width, height)
	local solved = input(self, settled, width)
	local solution = Autosize.solve(solved)
	local childShare = Autosize.share(solved, solution)

	for _, child in self.children do
		if child.instance.Visible then
			child:commit(settled, self.vertical, if child.grow then childShare else 0)
		end
	end

	local scroller = self.instance :: ScrollingFrame

	scroller.CanvasSize = if self.vertical
		then UDim2.fromOffset(0, solution.content.Y)
		else UDim2.fromOffset(solution.content.X, 0)
end

function Scroll.destroy(self: Fields & Types.Scroll)
	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	table.clear(self.children)

	require(script.Parent.Parent.Core.Node).teardown(self)
end

Element.install(Scroll)

return Scroll
