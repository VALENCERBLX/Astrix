--!strict

--- A list of rows, virtualised.
---
--- Only the rows on screen exist as instances; a pool of them is recycled as
--- you scroll, so ten thousand items cost the same as ten. The list also
--- reports the width of its widest row when it is not filling, which is how a
--- panel ends up exactly as wide as its longest line.
---
--- New content follows the view down only when you were already at the bottom.
--- Scroll up to read and the list stops chasing you.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Virtual = require(script.Parent.Parent.Layout.Virtual)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)
local Text = require(script.Parent.Parent.Text)

local List = {}
List.__index = List

export type Row = {
	button: TextButton,
	icon: ImageLabel,
	title: TextLabel,
	detail: TextLabel,
	index: number,
}

export type Fields = Types.NodeFields & Types.ElementFields & {
	items: { Types.ListItem },
	rows: { Row },

	rowHeight: number,
	font: Enum.Font,
	textSize: number,
	maxRows: number,
	virtual: boolean,
	selectable: boolean,
	selectedId: string?,

	widest: number,
	pinned: boolean,
	emptyText: string,
	renderer: ((Types.ListItem, number) -> string)?,
}

local MEASURE_BUDGET = 500

--// locals
local function normalise(entry: Types.ListItem | string, index: number): Types.ListItem
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local item = entry :: Types.ListItem

	return {
		id = item.id or item.text or tostring(index),
		text = item.text or "",
		icon = item.icon,
		description = item.description,
		height = item.height,
		data = item.data,
	}
end

--- Creates a list. Prefer `panel:list()`.
function List.new(app: Types.App): Types.List
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "ScrollingFrame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Size = UDim2.new(1, 0, 0, theme.size.row * 3),
			CanvasSize = UDim2.fromOffset(0, 0),

			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarImageColor3 = theme.color.borderStrong,
			ScrollBarImageTransparency = 0.5,
			ScrollBarThickness = 3,

			ClipsDescendants = true,
			Name = "List",

			--// starts empty, so it starts hidden; `setItems` reveals it
			Visible = false,
		},
		children = {
			{
				class = "Frame",
				ref = "canvas",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					Name = "Canvas",
				},
			},
			{
				class = "TextLabel",
				ref = "empty",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,

					Visible = false,
					Name = "Empty",
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

		kind = "list",
		desired = Vector2.new(0, theme.size.row * 3),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		items = {},
		rows = {},

		rowHeight = theme.size.row,
		font = theme.font.body,
		textSize = theme.text.sm,
		maxRows = 8,
		virtual = true,
		selectable = true,
		selectedId = nil,

		widest = 0,
		pinned = true,
		emptyText = "",
		renderer = nil,
	}

	local list = setmetatable(fields, List) :: any

	local scroller = root :: ScrollingFrame

	scope:add(scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		fields.pinned = Virtual.pinned(
			scroller.CanvasPosition.Y,
			scroller.AbsoluteSize.Y,
			scroller.CanvasSize.Y.Offset
		)

		List.render(list)

		list:emit("scrolled", scroller.CanvasPosition.Y)
	end))

	return list
end

--- Builds one recycled row instance.
function List.buildRow(self: Fields, index: number): Row
	local theme = self.app.theme

	local button, refs = Create.tree(self.scope, {
		class = "TextButton",
		ref = "button",
		props = {
			BackgroundColor3 = theme.color.surfaceHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,

			Size = UDim2.new(1, 0, 0, self.rowHeight),
			Name = `Row{index}`,
			Text = "",
		},
		children = {
			Create.corner(theme.radius.sm),
			Create.padding(theme.space.sm, 0),
			Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "ImageLabel",
				ref = "icon",
				props = {
					BackgroundTransparency = 1,
					ImageColor3 = theme.color.textMuted,
					ImageTransparency = theme.transparency.muted,
					ScaleType = Enum.ScaleType.Fit,

					Size = UDim2.fromOffset(theme.size.icon, theme.size.icon),
					LayoutOrder = 1,
					Visible = false,
					Name = "Icon",
					Image = "",
				},
			},
			{
				class = "TextLabel",
				ref = "title",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, self.rowHeight),

					Font = self.font,
					TextSize = self.textSize,
					TextColor3 = theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					RichText = true,

					LayoutOrder = 2,
					Name = "Title",
					Text = "",
				},
			},
			{
				class = "TextLabel",
				ref = "detail",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, self.rowHeight),

					Font = theme.font.body,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,

					LayoutOrder = 3,
					Visible = false,
					Name = "Detail",
					Text = "",
				},
			},
		},
	})

	local row: Row = {
		button = button :: TextButton,
		icon = refs.icon :: ImageLabel,
		title = refs.title :: TextLabel,
		detail = refs.detail :: TextLabel,
		index = 0,
	}

	button.Parent = self.refs.canvas

	Hover.attach(self.scope, row.button, function(hovering)
		local item = self.items[row.index]
		local selected = item ~= nil and item.id == self.selectedId

		row.button.BackgroundTransparency = if selected then 0.82 elseif hovering then 0.9 else 1
	end)

	row.button.Activated:Connect(function()
		local item = self.items[row.index]

		if not item or not self.enabled then
			return
		end

		if self.selectable then
			self.selectedId = item.id

			List.render(self)
		end

		;(self :: any):emit("selected", item, row.index)
		;(self :: any):emit("activated", item, row.index)
	end)

	return row
end

--- Points the row pool at the slice of items currently on screen.
function List.render(self: Fields)
	local theme = self.app.theme
	local scroller = self.instance :: ScrollingFrame
	local canvas = self.refs.canvas :: Frame

	local count = #self.items
	local height = Virtual.canvas(count, self.rowHeight)

	scroller.CanvasSize = UDim2.fromOffset(0, height)
	canvas.Size = UDim2.new(1, 0, 0, math.max(height, 1))

	;(self.refs.empty :: TextLabel).Visible = count == 0 and self.emptyText ~= ""

	local first = 1
	local last = count

	if self.virtual then
		first, last = Virtual.range(
			scroller.CanvasPosition.Y,
			math.max(scroller.AbsoluteSize.Y, self.rowHeight),
			self.rowHeight,
			count
		)
	end

	local needed = math.max(0, last - first + 1)

	while #self.rows < needed do
		table.insert(self.rows, List.buildRow(self, #self.rows + 1))
	end

	for offset = 0, needed - 1 do
		local index = first + offset
		local row = self.rows[offset + 1]
		local item = self.items[index]

		if not item then
			row.button.Visible = false
			continue
		end

		local selected = item.id == self.selectedId

		row.index = index
		row.button.Visible = true
		row.button.Position = UDim2.fromOffset(0, Virtual.offset(index, self.rowHeight))
		row.button.Size = UDim2.new(1, 0, 0, self.rowHeight)
		row.button.BackgroundTransparency = if selected then 0.82 else 1

		row.title.Text = if self.renderer then self.renderer(item, index) else Text.escape(item.text or "")
		row.title.TextColor3 = if selected then theme.color.text else theme.color.text

		row.icon.Image = item.icon or ""
		row.icon.Visible = item.icon ~= nil and item.icon ~= ""

		row.detail.Text = item.description or ""
		row.detail.Visible = item.description ~= nil and item.description ~= ""
	end

	for index = needed + 1, #self.rows do
		self.rows[index].button.Visible = false
	end
end

--- An empty list with nothing to say occupies no space at all, and hides so
--- the panel does not leave a gap where it would have been. This is what lets
--- a command bar collapse to exactly one input row.
function List.updateVisibility(self: Fields)
	local blank = #self.items == 0 and self.emptyText == ""

	self.instance.Visible = not blank
end

function List.setItems(self: Fields & Types.List, items: Types.Bindable<{ Types.ListItem | string }>): Types.List
	Node.bind(self, "items", items, function(next: { Types.ListItem | string })
		local normalised: { Types.ListItem } = {}

		for index, entry in next do
			table.insert(normalised, normalise(entry, index))
		end

		self.items = normalised
		self.widest = 0

		List.updateVisibility(self)
		List.render(self)

		--// stay glued to the bottom only if that is where the reader already was
		if self.pinned then
			List.scrollToBottom(self)
		end

		self:invalidate()
	end)

	return self
end

function List.setRowHeight(self: Fields & Types.List, height: number): Types.List
	self.rowHeight = math.max(1, height)

	List.render(self)

	return self:invalidate()
end

--- Sets the row font. A terminal history wants `Enum.Font.Code`; the widths
--- the list reports are measured in whatever is set here, so the panel still
--- sizes to the longest line.
function List.setFont(self: Fields & Types.List, font: Enum.Font): Types.List
	self.font = font
	self.widest = 0

	for _, row in self.rows do
		row.title.Font = font
	end

	return self:invalidate()
end

function List.setTextSize(self: Fields & Types.List, size: number): Types.List
	self.textSize = size
	self.widest = 0

	for _, row in self.rows do
		row.title.TextSize = size
	end

	return self:invalidate()
end

--- Turn virtualisation off for short lists where every row should exist.
function List.setVirtual(self: Fields & Types.List, virtual: boolean): Types.List
	self.virtual = virtual ~= false

	List.render(self)

	return self
end

--- Caps the measured height at this many rows. The list scrolls past it.
function List.setMaxRows(self: Fields & Types.List, rows: number): Types.List
	self.maxRows = math.max(1, rows)

	return self:invalidate()
end

function List.setSelectable(self: Fields & Types.List, selectable: boolean): Types.List
	self.selectable = selectable ~= false

	return self
end

function List.setSelected(self: Fields & Types.List, id: Types.Bindable<string?>): Types.List
	Node.bind(self, "selected", id, function(next: string?)
		self.selectedId = next

		List.render(self)
	end)

	return self
end

function List.setEmptyText(self: Fields & Types.List, text: Types.Bindable<string>): Types.List
	local label = self.refs.empty :: TextLabel

	Node.bind(self, "empty", text, function(next: string)
		local value = tostring(next)

		self.emptyText = value

		label.Text = value
		label.Visible = #self.items == 0 and value ~= ""

		List.updateVisibility(self)
	end)

	return self
end

--- Replaces the default row text with your own RichText. Return escaped
--- content; the row renders it raw.
function List.setRenderer(self: Fields & Types.List, renderer: (Types.ListItem, number) -> string): Types.List
	self.renderer = renderer

	List.render(self)

	return self
end

function List.onSelected(self: Fields & Types.List, handler: (Types.ListItem, number) -> ()): Types.List
	return self:on("selected", handler)
end

function List.onActivated(self: Fields & Types.List, handler: (Types.ListItem, number) -> ()): Types.List
	return self:on("activated", handler)
end

function List.onScrolled(self: Fields & Types.List, handler: (number) -> ()): Types.List
	return self:on("scrolled", handler)
end

function List.scrollTo(self: Fields & Types.List, index: number): Types.List
	local scroller = self.instance :: ScrollingFrame

	scroller.CanvasPosition = Vector2.new(
		0,
		Virtual.scrollTo(index, self.rowHeight, scroller.AbsoluteSize.Y, scroller.CanvasPosition.Y)
	)

	return self
end

function List.scrollToBottom(self: Fields & Types.List): Types.List
	local scroller = self.instance :: ScrollingFrame

	scroller.CanvasPosition = Vector2.new(0, math.max(0, scroller.CanvasSize.Y.Offset - scroller.AbsoluteSize.Y))
	self.pinned = true

	return self
end

function List.count(self: Fields & Types.List): number
	return #self.items
end

--- Height is rows capped by `maxRows`. Width is the widest row when the list
--- is not filling — measurement is bounded so a huge list stays cheap.
function List.measure(self: Fields & Types.List, available: Vector2): Vector2
	local theme = self.app.theme
	local count = #self.items

	if count == 0 and self.emptyText == "" then
		self.desired = Vector2.zero
		self.measured = true

		return self.desired
	end

	local rows = math.min(math.max(count, 1), self.maxRows)
	local height = rows * self.rowHeight

	--// the widest row is what a panel should grow to, so it is measured even
	--// when filling. The budget bounds the cost: a hundred thousand rows do
	--// not get measured to find out the panel wants to be wide
	if self.widest == 0 and count > 0 then
		local budget = math.min(count, MEASURE_BUDGET)

		for index = 1, budget do
			local item = self.items[index]
			local content = Text.strip(item.text or "")

			local line = self.app.measure:width(content, self.textSize, self.font)

			if item.description then
				line += self.app.measure:width(item.description, theme.text.xs, theme.font.body) + theme.space.sm
			end

			if item.icon and item.icon ~= "" then
				line += theme.size.icon + theme.space.sm
			end

			self.widest = math.max(self.widest, line)
		end
	end

	local natural = self.widest + theme.space.sm * 2 + 8
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(List)

return List
