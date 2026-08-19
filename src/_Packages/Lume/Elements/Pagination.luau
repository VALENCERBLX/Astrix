--!strict

--- Page numbers, with arrows either side.
---
--- Long runs collapse to an ellipsis so the control stays one row wide at any
--- length. What never collapses is the first page, the last page, and the
--- neighbourhood of where you are — those are the three things anyone actually
--- aims at.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Pagination = {}
Pagination.__index = Pagination

export type Fields = Types.NodeFields & Types.ElementFields & {
	page: number,
	pages: number,
	window: number,
	buttons: { TextButton },
	slots: number,
}

--- Which page numbers to draw, with `0` standing for an ellipsis.
function Pagination.slotsFor(page: number, pages: number, window: number): { number }
	if pages <= window + 4 then
		local all = {}

		for index = 1, pages do
			table.insert(all, index)
		end

		return all
	end

	local out = { 1 }
	local first = math.max(2, page - window)
	local last = math.min(pages - 1, page + window)

	if first > 2 then
		table.insert(out, 0)
	end

	for index = first, last do
		table.insert(out, index)
	end

	if last < pages - 1 then
		table.insert(out, 0)
	end

	table.insert(out, pages)

	return out
end

--- Creates a pager. Prefer `panel:pagination(pages)`.
function Pagination.new(app: Types.App): Types.Pagination
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Pagination",
		},
		children = {
			Create.list(Enum.FillDirection.Horizontal, 2, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
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

		kind = "pagination",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		page = 1,
		pages = 1,
		window = 1,
		buttons = {},
		slots = 0,
	}

	return setmetatable(fields, Pagination) :: any
end

function Pagination.rebuild(self: Fields & Types.Pagination)
	local theme = self.app.theme
	local size = theme.size.control

	for _, child in self.instance:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	table.clear(self.buttons)

	local order = 0

	local function add(text: string, name: string, target: number?, active: boolean?)
		order += 1

		local usable = target ~= nil and self.enabled
		local button = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundColor3 = if active then theme.color.accent else theme.color.surfaceHover,
				BackgroundTransparency = if active then 0 elseif usable then 0.88 else 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(size, size),
				LayoutOrder = order,

				Font = if active then theme.font.medium else theme.font.body,
				TextSize = theme.text.sm,
				TextColor3 = if active then theme.color.accentText else theme.color.text,
				TextTransparency = if usable or active then 0 else theme.transparency.disabled,

				Name = name,
				Text = text,
			},
			children = { Create.corner(theme.radius.sm) },
		}) :: TextButton

		button.Parent = self.instance

		table.insert(self.buttons, button)

		if not usable or active then
			return
		end

		Hover.attach(self.scope, button, function(hovering)
			button.BackgroundTransparency = if hovering then 0.78 else 0.88
		end)

		self.scope:add(button.Activated:Connect(function()
			Pagination.goTo(self, target :: number)
		end))
	end

	add("‹", "Previous", if self.page > 1 then self.page - 1 else nil)

	local slots = Pagination.slotsFor(self.page, self.pages, self.window)

	self.slots = #slots

	for _, slot in slots do
		if slot == 0 then
			add("…", "Ellipsis", nil)
		else
			add(tostring(slot), `Page{slot}`, slot, slot == self.page)
		end
	end

	add("›", "Next", if self.page < self.pages then self.page + 1 else nil)
end

--- Moves to a page and fires `changed`, clamped to what exists.
function Pagination.goTo(self: Fields & Types.Pagination, page: number): Types.Pagination
	local next = math.clamp(math.round(page), 1, math.max(1, self.pages))

	if next == self.page then
		return self
	end

	self.page = next

	Pagination.rebuild(self)

	self:emit("changed", next)

	return self
end

function Pagination.setPages(self: Fields & Types.Pagination, pages: Types.Bindable<number>): Types.Pagination
	Node.bind(self, "pages", pages, function(next: number)
		self.pages = math.max(1, math.round(next))
		self.page = math.min(self.page, self.pages)

		Pagination.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Pagination.setPage(self: Fields & Types.Pagination, page: Types.Bindable<number>): Types.Pagination
	Node.bind(self, "page", page, function(next: number)
		self.page = math.clamp(math.round(next), 1, math.max(1, self.pages))

		Pagination.rebuild(self)
	end)

	return self
end

--- How many pages either side of the current one stay visible.
function Pagination.setWindow(self: Fields & Types.Pagination, window: number): Types.Pagination
	self.window = math.max(0, math.round(window))

	Pagination.rebuild(self)

	return self:invalidate()
end

function Pagination.onChanged(self: Fields & Types.Pagination, handler: (number) -> ()): Types.Pagination
	return self:on("changed", handler)
end

function Pagination.value(self: Fields & Types.Pagination): number
	return self.page
end

function Pagination.measure(self: Fields & Types.Pagination, available: Vector2): Vector2
	local size = self.app.theme.size.control
	local total = #self.buttons * (size + 2)

	self.desired = Vector2.new(math.ceil(math.min(total, math.max(1, available.X - self.margin * 2))), size)
	self.measured = true

	return self.desired
end

Element.install(Pagination)

return Pagination
