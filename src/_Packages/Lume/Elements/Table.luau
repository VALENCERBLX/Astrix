--!strict

--- Rows and columns with a header.
---
--- A list renders one line per item; a table renders one *cell* per column, so
--- the second column starts at the same x on every row. That alignment is the
--- entire reason to reach for it — without it a table is a list with tabs in
--- the text, which stops being true the moment one value is long.
---
--- Column widths are weights, not pixels. A column with weight 2 takes twice
--- the room of one with weight 1, whatever the table ends up being.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Text = require(script.Parent.Parent.Text)
local Element = require(script.Parent.Element)

local Table = {}
Table.__index = Table

export type Fields = Types.NodeFields & Types.ElementFields & {
	columns: { Types.Column },
	rows: { Types.Row },
	built: { { instance: TextButton, cells: { TextLabel } } },

	rowHeight: number,
	headerShown: boolean,
	selectable: boolean,
	selectedIndex: number?,
	striped: boolean,
}

--// locals
local function weight(column: Types.Column): number
	return column.weight or 1
end

--- Creates a table. Prefer `panel:table()`.
function Table.new(app: Types.App): Types.Table
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.row),
			Name = "Table",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, 0),
			{
				class = "Frame",
				ref = "header",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.row),
					LayoutOrder = 1,
					Name = "Header",
				},
			},
			{
				class = "Frame",
				ref = "rule",
				props = {
					BackgroundColor3 = theme.color.border,
					BackgroundTransparency = theme.transparency.border,
					BorderSizePixel = 0,

					Size = UDim2.new(1, 0, 0, 1),
					LayoutOrder = 2,
					Name = "Rule",
				},
			},
			{
				class = "Frame",
				ref = "body",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = 3,
					Name = "Body",
				},
				children = { Create.list(Enum.FillDirection.Vertical, 0) },
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

		kind = "table",
		desired = Vector2.new(0, theme.size.row),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		columns = {},
		rows = {},
		built = {},

		rowHeight = theme.size.row,
		headerShown = true,
		selectable = false,
		selectedIndex = nil,
		striped = true,
	}

	return setmetatable(fields, Table) :: any
end

--- One cell, sized by its column's share of the row.
function Table.cell(self: Fields, parent: GuiObject, column: Types.Column, index: number, total: number, header: boolean): TextLabel
	local theme = self.app.theme

	return Create.node(self.scope, {
		class = "TextLabel",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Size = UDim2.new(weight(column) / total, -theme.space.sm, 1, 0),
			Position = UDim2.fromScale(0, 0),
			LayoutOrder = index,

			Font = if header then theme.font.medium else theme.font.body,
			TextSize = if header then theme.text.xs else theme.text.sm,
			TextColor3 = if header then theme.color.textMuted else theme.color.text,
			TextTransparency = if header then theme.transparency.muted else 0,
			TextXAlignment = if column.align == "right"
				then Enum.TextXAlignment.Right
				elseif column.align == "center" then Enum.TextXAlignment.Center
				else Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			RichText = true,

			Name = `Cell_{column.key}`,
			Text = "",
		},
	}) :: TextLabel
end

--- Rebuilds header and rows. Called on `setColumns` and `setRows`.
function Table.rebuild(self: Fields & Types.Table)
	local theme = self.app.theme
	local header = self.refs.header :: Frame
	local body = self.refs.body :: Frame

	for _, child in header:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for _, row in self.built do
		row.instance:Destroy()
	end

	table.clear(self.built)

	local total = 0

	for _, column in self.columns do
		total += weight(column)
	end

	total = math.max(total, 1)

	--// the header is laid out by hand rather than by a list layout, because a
	--// cell has to sit at the same x as the cell under it, and a list layout
	--// would pack them instead
	local offset = 0

	for index, column in self.columns do
		local cell = Table.cell(self, header, column, index, total, true)

		cell.Text = column.title or column.key
		cell.Position = UDim2.fromScale(offset, 0)
		cell.Parent = header

		offset += weight(column) / total
	end

	header.Visible = self.headerShown
	;(self.refs.rule :: Frame).Visible = self.headerShown

	for index, row in self.rows do
		local instance = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundColor3 = theme.color.surfaceHover,
				BackgroundTransparency = if self.striped and index % 2 == 0 then 0.94 else 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.new(1, 0, 0, self.rowHeight),
				LayoutOrder = index,

				Name = `Row{index}`,
				Text = "",
			},
		}) :: TextButton

		instance.Parent = body

		local cells = {}
		local at = 0

		for column, definition in self.columns do
			local cell = Table.cell(self, instance, definition, column, total, false)
			local value = row[definition.key]

			cell.Text = Text.escape(if value == nil then "" else tostring(value))
			cell.Position = UDim2.fromScale(at, 0)
			cell.Parent = instance

			table.insert(cells, cell)

			at += weight(definition) / total
		end

		table.insert(self.built, { instance = instance, cells = cells })

		Hover.attach(self.scope, instance, function(hovering)
			if not self.selectable or not self.enabled then
				return
			end

			local selected = self.selectedIndex == index

			instance.BackgroundTransparency = if selected
				then 0.82
				elseif hovering then 0.9
				elseif self.striped and index % 2 == 0 then 0.94
				else 1
		end)

		self.scope:add(instance.Activated:Connect(function()
			if not self.enabled then
				return
			end

			if self.selectable then
				self.selectedIndex = index

				Table.paint(self)
			end

			self:emit("activated", row, index)
		end))
	end

	Table.paint(self)
end

function Table.paint(self: Fields)
	for index, row in self.built do
		local selected = self.selectedIndex == index

		row.instance.BackgroundTransparency = if selected and self.selectable
			then 0.82
			elseif self.striped and index % 2 == 0 then 0.94
			else 1
	end
end

function Table.setColumns(self: Fields & Types.Table, columns: { Types.Column }): Types.Table
	self.columns = columns

	Table.rebuild(self)

	return self:invalidate()
end

function Table.setRows(self: Fields & Types.Table, rows: Types.Bindable<{ Types.Row }>): Types.Table
	Node.bind(self, "rows", rows, function(next: { Types.Row })
		self.rows = next

		--// a selection past the end of the new data would highlight a row that
		--// is not there
		if self.selectedIndex and self.selectedIndex > #next then
			self.selectedIndex = nil
		end

		Table.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Table.setRowHeight(self: Fields & Types.Table, height: number): Types.Table
	self.rowHeight = math.max(1, height)

	Table.rebuild(self)

	return self:invalidate()
end

function Table.setHeaderShown(self: Fields & Types.Table, shown: boolean?): Types.Table
	self.headerShown = shown ~= false
	;(self.refs.header :: Frame).Visible = self.headerShown
	;(self.refs.rule :: Frame).Visible = self.headerShown

	return self:invalidate()
end

function Table.setSelectable(self: Fields & Types.Table, selectable: boolean?): Types.Table
	self.selectable = selectable ~= false

	Table.paint(self)

	return self
end

--- Alternating row tints. On by default: without them the eye loses its place
--- crossing a wide row.
function Table.setStriped(self: Fields & Types.Table, striped: boolean?): Types.Table
	self.striped = striped ~= false

	Table.paint(self)

	return self
end

function Table.setSelected(self: Fields & Types.Table, index: number?): Types.Table
	self.selectedIndex = index

	Table.paint(self)

	return self
end

function Table.selected(self: Fields & Types.Table): Types.Row?
	return if self.selectedIndex then self.rows[self.selectedIndex] else nil
end

function Table.onActivated(self: Fields & Types.Table, handler: (Types.Row, number) -> ()): Types.Table
	return self:on("activated", handler)
end

function Table.measure(self: Fields & Types.Table, available: Vector2): Vector2
	local height = #self.rows * self.rowHeight

	if self.headerShown then
		height += self.rowHeight + 1
	end

	self.desired = Vector2.new(math.ceil(math.max(1, available.X - self.margin * 2)), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Table)

return Table
