--!strict

--- A dropdown. The element itself is only the trigger row; the options live in
--- a popover panel created on first open.
---
--- That split is why a dropdown opened from the bottom of a small panel is not
--- clipped by it: the popover lives on the popover layer, positions itself
--- against the trigger, and flips above when there is no room below.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)
local Text = require(script.Parent.Parent.Text)

local Select = {}
Select.__index = Select

export type Fields = Types.NodeFields & Types.ElementFields & {
	options: { Types.Option },
	chosen: { string },

	labelText: string,
	placeholderText: string,
	searchable: boolean,
	multi: boolean,
	query: string,

	popover: Types.Panel?,
	list: Types.List?,
	search: Types.Field?,
	open: boolean,
}

--// locals
local function normalise(entry: Types.Option | string): Types.Option
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local option = entry :: Types.Option

	return { id = option.id or option.text, text = option.text, icon = option.icon, description = option.description }
end

local function find(self: Fields, id: string?): Types.Option?
	if not id then
		return nil
	end

	for _, option in self.options do
		if option.id == id then
			return option
		end
	end

	return nil
end

--- Creates a select. Prefer `panel:select(label)`.
function Select.new(app: Types.App): Types.Select
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "TextButton",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.surfaceSunken,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			AutoButtonColor = false,

			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Select",
			Text = "",
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
			Create.padding(theme.space.sm, 0),
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -20, 1, 0),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					RichText = true,

					Name = "Value",
					Text = "",
				},
			},
			{
				class = "TextLabel",
				ref = "arrow",
				props = {
					BackgroundTransparency = 1,

					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),

					Font = theme.font.body,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,

					Name = "Arrow",
					Text = "▾",
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

		kind = "select",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		options = {},
		chosen = {},

		labelText = "",
		placeholderText = "Select…",
		searchable = false,
		multi = false,
		query = "",

		popover = nil,
		list = nil,
		search = nil,
		open = false,
	}

	local select = setmetatable(fields, Select) :: any

	local button = root :: TextButton

	Hover.attach(scope, button, function(hovering)
		if not fields.enabled then
			return
		end

		Motion.animate(
			refs.stroke :: UIStroke,
			{ Transparency = if hovering then 0.1 else theme.transparency.border },
			theme:spec("hover")
		)
	end)

	scope:add(button.Activated:Connect(function()
		if fields.enabled then
			Select.toggle(select)
		end
	end))

	Select.paint(fields)

	return select
end

--- Writes the current selection into the trigger row.
function Select.paint(self: Fields)
	local theme = self.app.theme
	local label = self.refs.label :: TextLabel

	if #self.chosen == 0 then
		label.Text = Text.color(Text.escape(self.placeholderText), theme.rich.ghost)

		return
	end

	if #self.chosen == 1 then
		local option = find(self, self.chosen[1])

		label.Text = Text.escape(if option then option.text else self.chosen[1])

		return
	end

	label.Text = `{#self.chosen} selected`
end

--- The options visible for the current search query.
function Select.filtered(self: Fields): { Types.ListItem }
	local items: { Types.ListItem } = {}

	for _, option in self.options do
		local matched, score = Text.fuzzy(option.text, self.query)

		if matched then
			table.insert(items, {
				id = option.id,
				text = option.text,
				icon = option.icon,
				description = option.description,
				data = score,
			})
		end
	end

	table.sort(items, function(left, right)
		return (left.data :: number) < (right.data :: number)
	end)

	return items
end

--- Builds the popover on first open and keeps it thereafter.
function Select.ensurePopover(self: Fields & Types.Select): Types.Panel
	if self.popover then
		return self.popover
	end

	local Panel = require(script.Parent.Parent.Panel)

	local popover = Panel.new(self.app, "popover")

	popover:attachTo(self.instance, "bottom", self.app.theme.space.xs)
	popover:setMaxSize(520, 280)

	if self.searchable then
		local search = popover:field("Search…")

		search:onChanged(function(text)
			self.query = text

			if self.list then
				self.list:setItems(Select.filtered(self) :: any)
			end
		end)

		self.search = search
	end

	local list = popover:list()

	list:setMaxRows(8)
	list:setItems(Select.filtered(self) :: any)
	list:onActivated(function(item)
		Select.choose(self, item.id :: string)
	end)

	self.list = list

	popover:on("closed", function()
		self.open = false

		Motion.animate(self.refs.arrow :: TextLabel, { Rotation = 0 }, self.app.theme:spec("morph"))

		self:emit("closed")
	end)

	self.popover = popover

	return popover
end

--- Applies a choice, respecting single versus multi mode.
function Select.choose(self: Fields & Types.Select, id: string)
	if self.multi then
		local at = table.find(self.chosen, id)

		if at then
			table.remove(self.chosen, at)
		else
			table.insert(self.chosen, id)
		end
	else
		self.chosen = { id }
	end

	Select.paint(self)

	self:emit("changed", if self.multi then nil else id, find(self, id))

	if not self.multi and self.popover then
		self.popover:close()
	end

	self:invalidate()
end

function Select.toggle(self: Fields & Types.Select)
	local popover = Select.ensurePopover(self)

	if self.open then
		popover:close()

		return
	end

	self.open = true

	popover:setWidth(math.max(160, self.instance.AbsoluteSize.X))
	popover:attachTo(self.instance, "bottom", self.app.theme.space.xs)

	if self.list then
		self.list:setItems(Select.filtered(self) :: any)
	end

	popover:open()

	Motion.animate(self.refs.arrow :: TextLabel, { Rotation = 180 }, self.app.theme:spec("morph"))

	self:emit("opened")
end

function Select.setLabel(self: Fields & Types.Select, label: Types.Bindable<string>): Types.Select
	Node.bind(self, "label", label, function(next: string)
		self.labelText = tostring(next)
	end)

	return self
end

function Select.setOptions(
	self: Fields & Types.Select,
	options: Types.Bindable<{ Types.Option | string }>
): Types.Select
	Node.bind(self, "options", options, function(next: { Types.Option | string })
		local normalised: { Types.Option } = {}

		for _, entry in next do
			table.insert(normalised, normalise(entry))
		end

		self.options = normalised

		if self.list then
			self.list:setItems(Select.filtered(self) :: any)
		end

		Select.paint(self)

		self:invalidate()
	end)

	return self
end

function Select.setValue(self: Fields & Types.Select, id: Types.Bindable<string?>): Types.Select
	Node.bind(self, "value", id, function(next: string?)
		self.chosen = if next then { next } else {}

		Select.paint(self)
	end)

	return self
end

function Select.setPlaceholder(self: Fields & Types.Select, placeholder: Types.Bindable<string>): Types.Select
	Node.bind(self, "placeholder", placeholder, function(next: string)
		self.placeholderText = tostring(next)

		Select.paint(self)
	end)

	return self
end

--- Adds a search field to the popover. Set before the first open.
function Select.setSearchable(self: Fields & Types.Select, searchable: boolean): Types.Select
	self.searchable = searchable ~= false

	return self
end

function Select.setMulti(self: Fields & Types.Select, multi: boolean): Types.Select
	self.multi = multi ~= false

	return self
end

function Select.onChanged(self: Fields & Types.Select, handler: (string?, Types.Option?) -> ()): Types.Select
	return self:on("changed", handler)
end

function Select.onOpened(self: Fields & Types.Select, handler: () -> ()): Types.Select
	return self:on("opened", handler)
end

function Select.onClosed(self: Fields & Types.Select, handler: () -> ()): Types.Select
	return self:on("closed", handler)
end

function Select.value(self: Fields & Types.Select): string?
	return self.chosen[1]
end

function Select.values(self: Fields & Types.Select): { string }
	return table.clone(self.chosen)
end

function Select.measure(self: Fields & Types.Select, available: Vector2): Vector2
	local theme = self.app.theme

	--// as wide as the longest option it might have to show, so choosing one
	--// does not resize the row underneath the pointer
	local widest = self.app.measure:width(self.placeholderText, theme.text.sm, theme.font.body)

	for _, option in self.options do
		widest = math.max(widest, self.app.measure:width(option.text, theme.text.sm, theme.font.body))
	end

	local natural = math.max(140, widest + theme.space.sm * 2 + 24)
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), theme.size.control)
	self.measured = true

	return self.desired
end

function Select.destroy(self: Fields & Types.Select)
	if self.popover then
		self.popover:destroy()

		self.popover = nil
	end

	Node.teardown(self)
end

Element.install(Select)

return Select
