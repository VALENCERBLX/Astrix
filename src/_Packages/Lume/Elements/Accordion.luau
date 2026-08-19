--!strict

--- Sections with headers you click to fold away.
---
--- A section's body is a **Group**, which is the whole trick: everything that
--- works inside a panel works inside a section, because a group already runs
--- the same layout pass a panel does. `accordion:section("Advanced")` hands you
--- something you can put a toggle, a slider and three labels in.
---
--- Collapsing hides the body rather than animating its height. The panel
--- around it is already a spring that morphs when its content changes size, so
--- the fold you see is the panel doing what it does for every other change —
--- one motion system, not a second one fighting the first.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Accordion = {}
Accordion.__index = Accordion

export type Section = {
	id: string,
	title: string,
	header: TextButton,
	chevron: TextLabel,
	body: Types.Group,
	open: boolean,
}

export type Fields = Types.NodeFields & Types.ElementFields & {
	sections: { Section },
	exclusive: boolean,
	gap: number,
}

--// locals
local function find(self: Fields, id: string): Section?
	for _, section in self.sections do
		if section.id == id then
			return section
		end
	end

	return nil
end

--- Creates an accordion. Prefer `panel:accordion()`.
function Accordion.new(app: Types.App): Types.Accordion
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			Name = "Accordion",
		},
		children = {
			{
				class = "UIListLayout",
				ref = "layout",
				props = {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, theme.space.xs),
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

		kind = "accordion",
		desired = Vector2.new(0, 0),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		sections = {},
		exclusive = false,
		gap = theme.space.xs,
	}

	return setmetatable(fields, Accordion) :: any
end

--- Points the chevron down when open, right when closed.
function Accordion.paint(self: Fields, section: Section, immediate: boolean?)
	local target = { Rotation = if section.open then 90 else 0 }

	if immediate then
		Motion.set(section.chevron, target)
	else
		Motion.animate(section.chevron, target, self.app.theme:spec("morph"))
	end

	section.body.instance.Visible = section.open
end

--- Adds a section and returns its body, which is a group — put whatever you
--- like in it.
function Accordion.section(self: Fields & Types.Accordion, title: string, id: string?): Types.Group
	local theme = self.app.theme
	local Elements = require(script.Parent)

	local order = #self.sections + 1

	local header, refs = Create.tree(self.scope, {
		class = "TextButton",
		ref = "header",
		props = {
			BackgroundColor3 = theme.color.surfaceHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,

			Size = UDim2.new(1, 0, 0, theme.size.row),
			LayoutOrder = order * 2 - 1,

			Name = `Header_{id or title}`,
			Text = "",
		},
		children = {
			Create.corner(theme.radius.sm),
			Create.padding(theme.space.xs, 0),
			Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "TextLabel",
				ref = "chevron",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(theme.size.icon, theme.size.row),

					Font = theme.font.medium,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,

					LayoutOrder = 1,
					Rotation = 0,
					Name = "Chevron",
					Text = "▶",
				},
			},
			{
				class = "TextLabel",
				ref = "title",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.row),

					Font = theme.font.medium,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,

					LayoutOrder = 2,
					Name = "Title",
					Text = title,
				},
			},
		},
	})

	header.Parent = self.instance

	local body = Elements.Group.new(self.app) :: Types.Group

	body:setAxis("vertical")
	body:setGap(theme.space.sm)
	body:setFill(true)
	body:setMargin(theme.space.sm)

	--// the accordion owns the body, so the body's invalidate reaches the panel
	--// through here rather than stopping at a group with no owner
	;(body :: any).owner = self
	body.instance.LayoutOrder = order * 2
	body.instance.Visible = false
	body.instance.Parent = self.instance

	local section: Section = {
		id = id or title,
		title = title,
		header = header :: TextButton,
		chevron = refs.chevron :: TextLabel,
		body = body,
		open = false,
	}

	table.insert(self.sections, section)

	Hover.attach(self.scope, section.header, function(hovering)
		if not self.enabled then
			return
		end

		section.header.BackgroundTransparency = if hovering then 0.9 else 1
	end)

	self.scope:add(section.header.Activated:Connect(function()
		if not self.enabled then
			return
		end

		Accordion.toggleSection(self, section.id)
	end))

	Accordion.paint(self, section, true)

	self:invalidate()

	return body
end

function Accordion.openSection(self: Fields & Types.Accordion, id: string): Types.Accordion
	local section = find(self, id)

	if not section or section.open then
		return self
	end

	if self.exclusive then
		for _, other in self.sections do
			if other.open then
				other.open = false

				Accordion.paint(self, other)

				self:emit("toggled", other.id, false)
			end
		end
	end

	section.open = true

	Accordion.paint(self, section)

	self:emit("toggled", id, true)

	return self:invalidate()
end

function Accordion.closeSection(self: Fields & Types.Accordion, id: string): Types.Accordion
	local section = find(self, id)

	if not section or not section.open then
		return self
	end

	section.open = false

	Accordion.paint(self, section)

	self:emit("toggled", id, false)

	return self:invalidate()
end

function Accordion.toggleSection(self: Fields & Types.Accordion, id: string): Types.Accordion
	local section = find(self, id)

	if not section then
		return self
	end

	if section.open then
		return Accordion.closeSection(self, id)
	end

	return Accordion.openSection(self, id)
end

--- Only one section open at a time. Turning it on closes all but the first
--- that is already open, because leaving two open under a rule that forbids it
--- is worse than choosing one.
function Accordion.setExclusive(self: Fields & Types.Accordion, exclusive: boolean?): Types.Accordion
	self.exclusive = exclusive ~= false

	if not self.exclusive then
		return self
	end

	local kept = false

	for _, section in self.sections do
		if section.open then
			if kept then
				section.open = false

				Accordion.paint(self, section)

				self:emit("toggled", section.id, false)
			else
				kept = true
			end
		end
	end

	return self:invalidate()
end

function Accordion.setGap(self: Fields & Types.Accordion, gap: number): Types.Accordion
	self.gap = gap
	;(self.refs.layout :: UIListLayout).Padding = UDim.new(0, gap)

	return self:invalidate()
end

--- The ids of every open section, in the order they were added.
function Accordion.openIds(self: Fields & Types.Accordion): { string }
	local out = {}

	for _, section in self.sections do
		if section.open then
			table.insert(out, section.id)
		end
	end

	return out
end

--- The body of a section already added.
function Accordion.bodyOf(self: Fields & Types.Accordion, id: string): Types.Group?
	local section = find(self, id)

	return if section then section.body else nil
end

function Accordion.onToggled(self: Fields & Types.Accordion, handler: (string, boolean) -> ()): Types.Accordion
	return self:on("toggled", handler)
end

function Accordion.clear(self: Fields & Types.Accordion): Types.Accordion
	for _, section in self.sections do
		section.body:destroy()
		section.header:Destroy()
	end

	table.clear(self.sections)

	return self:invalidate()
end

--- Hosting children means answering `refresh` the way a panel does. It bubbles:
--- a slider inside a section invalidating reaches the panel through here.
function Accordion.refresh(self: Fields & Types.Accordion): Types.Accordion
	return self:invalidate()
end

function Accordion.measure(self: Fields & Types.Accordion, available: Vector2): Vector2
	local theme = self.app.theme
	local width = math.max(1, available.X - self.margin * 2)

	local height = 0
	local widest = 0
	local rows = 0

	for _, section in self.sections do
		height += theme.size.row
		rows += 1

		--// a closed section is measured anyway: its natural width is part of
		--// how wide the accordion wants to be, and a panel that widened every
		--// time a section opened would jump under the pointer
		local body = section.body:measure(Vector2.new(width, available.Y))

		widest = math.max(widest, body.X)

		if section.open then
			height += body.Y
			rows += 1
		end
	end

	if rows > 1 then
		height += self.gap * (rows - 1)
	end

	self.desired = Vector2.new(math.ceil(math.min(math.max(widest, 1), width)), math.ceil(height))
	self.measured = true

	return self.desired
end

function Accordion.commit(self: Fields & Types.Accordion, inner: Vector2, vertical: boolean, share: number)
	local width = self.desired.X
	local height = self.desired.Y

	--// same rule as Group: the parent's axis decides which dimension fill and
	--// grow apply to
	if vertical then
		if self.fill then
			width = math.max(0, inner.X - self.margin * 2)
		end

		if self.grow then
			height += share
		end
	else
		if self.fill then
			height = math.max(0, inner.Y - self.margin * 2)
		end

		if self.grow then
			width += share
		end
	end

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	local settled = Vector2.new(width, height)

	for _, section in self.sections do
		section.header.Size = UDim2.new(1, 0, 0, self.app.theme.size.row)

		if section.open then
			section.body:commit(settled, true, 0)
		end
	end
end

function Accordion.destroy(self: Fields & Types.Accordion)
	Accordion.clear(self)

	local Node = require(script.Parent.Parent.Core.Node)

	Node.teardown(self)
end

Element.install(Accordion)

return Accordion
