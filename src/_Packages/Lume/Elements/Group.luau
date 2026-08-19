--!strict

--- A row or column of elements inside a panel. Groups are how you get a
--- horizontal arrangement inside a vertical panel without nesting a whole
--- second panel and its chrome.
---
--- A group runs the same layout pass a panel does, so everything that works in
--- a panel — fill, grow, flexible spacers, measured text — works here too.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Autosize = require(script.Parent.Parent.Layout.Autosize)
local Create = require(script.Parent.Parent.Core.Create)
local Element = require(script.Parent.Element)

local Group = {}
Group.__index = Group

export type Fields = Types.NodeFields & Types.ElementFields & {
	children: { Types.Element },
	vertical: boolean,
	gap: number,
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

--- Creates a group. Prefer `panel:group(axis)`.
function Group.new(app: Types.App): Types.Group
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, theme.size.control),
			Name = "Group",
		},
		children = {
			{
				class = "UIListLayout",
				ref = "layout",
				props = {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.space.sm),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
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

		kind = "group",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		children = {},
		vertical = false,
		gap = theme.space.sm,
	}

	return setmetatable(fields, Group) :: any
end

function Group.setAxis(self: Fields & Types.Group, axis: Types.Axis): Types.Group
	local layout = self.refs.layout :: UIListLayout

	self.vertical = axis == "vertical"

	layout.FillDirection = if self.vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	layout.VerticalAlignment = if self.vertical then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center

	return self:invalidate()
end

function Group.setGap(self: Fields & Types.Group, gap: number): Types.Group
	self.gap = gap
	;(self.refs.layout :: UIListLayout).Padding = UDim.new(0, gap)

	return self:invalidate()
end

function Group.setAlign(
	self: Fields & Types.Group,
	horizontal: Enum.HorizontalAlignment,
	vertical: Enum.VerticalAlignment?
): Types.Group
	local layout = self.refs.layout :: UIListLayout

	layout.HorizontalAlignment = horizontal
	layout.VerticalAlignment = vertical or layout.VerticalAlignment

	return self
end

--- Lets a horizontal group wrap onto more lines instead of overflowing.
function Group.setWrap(self: Fields & Types.Group, wrap: boolean): Types.Group
	(self.refs.layout :: UIListLayout).Wraps = wrap ~= false

	return self:invalidate()
end

function Group.add(self: Fields & Types.Group, child: Types.Element): Types.Group
	adopt(self, child)

	return self
end

function Group.clear(self: Fields & Types.Group): Types.Group
	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	table.clear(self.children)

	return self:invalidate()
end

--- Groups host children, so they answer `refresh` the way a panel does. It
--- bubbles: re-measuring a group re-measures whatever contains it.
function Group.refresh(self: Fields & Types.Group): Types.Group
	return self:invalidate()
end

--// child factories
function Group.label(self: Fields & Types.Group, text: Types.Bindable<string>?): Types.Label
	local element = factory(self.app, "Label")

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element) :: any
end

function Group.icon(self: Fields & Types.Group, image: Types.Bindable<string>?): Types.Icon
	local element = factory(self.app, "Icon")

	if image ~= nil then
		element:setImage(image)
	end

	return adopt(self, element) :: any
end

function Group.button(self: Fields & Types.Group, text: Types.Bindable<string>?): Types.Button
	local element = factory(self.app, "Button")

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element) :: any
end

function Group.field(self: Fields & Types.Group, placeholder: Types.Bindable<string>?): Types.Field
	local element = factory(self.app, "Field")

	if placeholder ~= nil then
		element:setPlaceholder(placeholder)
	end

	return adopt(self, element) :: any
end

function Group.toggle(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Toggle
	local element = factory(self.app, "Toggle")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

--// a group runs the same layout pass a panel does, so it hosts the same
--// elements. Anything missing here is a control you cannot put in an accordion
--// section or a row, for no reason anyone could defend
function Group.slider(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Slider
	local element = factory(self.app, "Slider")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.stepper(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Stepper
	local element = factory(self.app, "Stepper")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.select(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Select
	local element = factory(self.app, "Select")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.colorPicker(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.ColorPicker
	local element = factory(self.app, "ColorPicker")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.keybind(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Keybind
	local element = factory(self.app, "Keybind")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.list(self: Fields & Types.Group): Types.List
	return adopt(self, factory(self.app, "List")) :: any
end

function Group.divider(self: Fields & Types.Group): Types.Divider
	return adopt(self, factory(self.app, "Divider")) :: any
end

function Group.progress(self: Fields & Types.Group): Types.Progress
	return adopt(self, factory(self.app, "Progress")) :: any
end

function Group.tabs(self: Fields & Types.Group): Types.Tabs
	return adopt(self, factory(self.app, "Tabs")) :: any
end

function Group.chips(self: Fields & Types.Group): Types.Chips
	return adopt(self, factory(self.app, "Chips")) :: any
end

function Group.accordion(self: Fields & Types.Group): Types.Accordion
	return adopt(self, factory(self.app, "Accordion")) :: any
end

function Group.menuBar(self: Fields & Types.Group, menus: { Types.MenuGroup }?): Types.MenuBar
	local element = factory(self.app, "MenuBar")

	if menus then
		element:setMenus(menus)
	end

	return adopt(self, element) :: any
end

function Group.radio(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Radio
	local element = factory(self.app, "Radio")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.rating(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Rating
	local element = factory(self.app, "Rating")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.meter(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Meter
	local element = factory(self.app, "Meter")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.spinner(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Spinner
	local element = factory(self.app, "Spinner")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.scrubber(self: Fields & Types.Group, label: Types.Bindable<string>?): Types.Scrubber
	local element = factory(self.app, "Scrubber")

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.table(self: Fields & Types.Group): Types.Table
	return adopt(self, factory(self.app, "Table")) :: any
end

function Group.tree(self: Fields & Types.Group): Types.Tree
	return adopt(self, factory(self.app, "Tree")) :: any
end

function Group.avatar(self: Fields & Types.Group, userId: number?): Types.Avatar
	local element = factory(self.app, "Avatar")

	if userId then
		element:setUserId(userId)
	end

	return adopt(self, element) :: any
end

function Group.breadcrumb(self: Fields & Types.Group, crumbs: { Types.Option | string }?): Types.Breadcrumb
	local element = factory(self.app, "Breadcrumb")

	if crumbs then
		element:setCrumbs(crumbs)
	end

	return adopt(self, element) :: any
end

function Group.pagination(self: Fields & Types.Group, pages: number?): Types.Pagination
	local element = factory(self.app, "Pagination")

	if pages then
		element:setPages(pages)
	end

	return adopt(self, element) :: any
end

function Group.vector(self: Fields & Types.Group, label: Types.Bindable<string>?, count: number?): Types.Vector
	local element = factory(self.app, "Vector")

	if count then
		element:setCount(count)
	end

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element) :: any
end

function Group.sparkline(self: Fields & Types.Group, points: { number }?): Types.Sparkline
	local element = factory(self.app, "Sparkline")

	if points then
		element:setPoints(points)
	end

	return adopt(self, element) :: any
end

function Group.badge(self: Fields & Types.Group, text: Types.Bindable<string>?): Types.Badge
	local element = factory(self.app, "Badge")

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element) :: any
end

function Group.spacer(self: Fields & Types.Group, size: number?): Types.Spacer
	local element = factory(self.app, "Spacer")

	if size ~= nil then
		element:setAmount(size)
	end

	return adopt(self, element) :: any
end

function Group.group(self: Fields & Types.Group, axis: Types.Axis?): Types.Group
	local element = factory(self.app, "Group")

	if axis ~= nil then
		element:setAxis(axis)
	end

	return adopt(self, element) :: any
end

--// layout
--- `settled` is passed only from commit, once the real width is known. During
--- measure it is nil so the group reports what its children actually want
--- rather than claiming the whole row.
local function input(self: Fields, available: Vector2, settled: number?): Autosize.Input
	return {
		children = self.children,
		vertical = self.vertical,

		gap = self.gap,
		padX = 0,
		padY = 0,

		chrome = Vector2.zero,
		room = available,

		minWidth = 0,
		maxWidth = math.max(1, available.X - self.margin * 2),
		minHeight = 0,
		maxHeight = 9999,

		fixedWidth = settled,
		fixedHeight = nil,
	}
end

function Group.measure(self: Fields & Types.Group, available: Vector2): Vector2
	local solution = Autosize.solve(input(self, available))

	self.desired = solution.clamped
	self.measured = true

	return self.desired
end

function Group.commit(self: Fields & Types.Group, inner: Vector2, vertical: boolean, share: number)
	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	--// children are measured against the size the group actually got, not the
	--// size it asked for
	local settled = Vector2.new(width, height)
	local solved = input(self, settled, width)
	local solution = Autosize.solve(solved)
	local childShare = Autosize.share(solved, solution)

	for _, child in self.children do
		if child.instance.Visible then
			child:commit(settled, self.vertical, if child.grow then childShare else 0)
		end
	end
end

function Group.destroy(self: Fields & Types.Group)
	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	table.clear(self.children)

	require(script.Parent.Parent.Core.Node).teardown(self)
end

Element.install(Group)

return Group
