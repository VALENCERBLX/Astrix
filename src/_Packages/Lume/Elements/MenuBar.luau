--!strict

--- A row of titled menus — File, Edit, View — each dropping its own list.
---
--- One menu popover is shared by every title rather than one per title. That is
--- what makes the bar feel like a bar: with a menu already open, moving the
--- pointer across the strip switches to the neighbour without a click, because
--- there is a single surface being re-aimed rather than one being closed and
--- another opened.
---
--- Picking is reported with the id of the menu it came from, so one handler can
--- serve the whole bar instead of one per title.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Menu = require(script.Parent.Menu)
local Element = require(script.Parent.Element)

local MenuBar = {}
MenuBar.__index = MenuBar

export type Fields = Types.NodeFields & Types.ElementFields & {
	menus: { Types.MenuGroup },
	buttons: { TextButton },
	widths: { number },
	open: string?,
	menu: Types.Menu?,
	wired: boolean,
}

--// locals
local function identify(group: Types.MenuGroup, index: number): Types.MenuGroup
	return {
		id = group.id or group.text or tostring(index),
		text = group.text,
		icon = group.icon,
		disabled = group.disabled,
		items = group.items,
	}
end

local function find(self: Fields, id: string): (Types.MenuGroup?, number)
	for index, group in self.menus do
		if group.id == id then
			return group, index
		end
	end

	return nil, 0
end

--- Creates a menu bar. Prefer `panel:menuBar()`.
function MenuBar.new(app: Types.App): Types.MenuBar
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "MenuBar",
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

		kind = "menubar",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		menus = {},
		buttons = {},
		widths = {},
		open = nil,
		menu = nil,
		wired = false,
	}

	return setmetatable(fields, MenuBar) :: any
end

--- The shared popover menu, built on first use.
function MenuBar.ensureMenu(self: Fields & Types.MenuBar): Types.Menu
	if self.menu then
		return self.menu
	end

	local menu = Menu.new(self.app)

	self.menu = menu
	self.scope:add(menu)

	menu:onPicked(function(item)
		self:emit("picked", item, self.open)
	end)

	return menu
end

--- Highlights whichever title is open and dims the rest.
function MenuBar.paint(self: Fields)
	local theme = self.app.theme

	for index, group in self.menus do
		local button = self.buttons[index]

		if not button then
			continue
		end

		local active = group.id == self.open
		local off = group.disabled == true

		button.BackgroundTransparency = if active then 0.85 else 1
		button.TextColor3 = if active then theme.color.text else theme.color.textMuted
		button.TextTransparency = if off
			then theme.transparency.disabled
			elseif active then 0
			else theme.transparency.muted
	end
end

--- Opens one title's menu under its button.
function MenuBar.openMenu(self: Fields & Types.MenuBar, id: string): Types.MenuBar
	local group, index = find(self, id)

	if not group or group.disabled or not self.enabled then
		return self
	end

	local button = self.buttons[index]

	if not button then
		return self
	end

	local menu = MenuBar.ensureMenu(self)

	menu:setItems(group.items)
	menu:openUnder(button, "bottom")

	self.open = id

	--// the popover only exists after the first open, so this is the earliest
	--// the bar can learn when it closes — including closes it did not ask for,
	--// like a click landing somewhere else entirely
	if not self.wired then
		local surface = menu:surface()

		if surface then
			surface:setDismissable(true)

			self.scope:add(Node.signal(surface, "closed"):connect(function()
				self.open = nil

				MenuBar.paint(self)
			end))

			self.wired = true
		end
	end

	MenuBar.paint(self)

	self:emit("opened", id)

	return self
end

function MenuBar.closeMenu(self: Fields & Types.MenuBar): Types.MenuBar
	if self.menu then
		self.menu:closeMenu()
	end

	self.open = nil

	MenuBar.paint(self)

	return self
end

--- Click behaviour: open, or close the one already open.
function MenuBar.toggle(self: Fields & Types.MenuBar, id: string)
	if self.open == id then
		MenuBar.closeMenu(self)

		return
	end

	MenuBar.openMenu(self, id)
end

--- Rebuilds the strip. Called on `setMenus` only.
function MenuBar.rebuild(self: Fields & Types.MenuBar)
	local theme = self.app.theme

	for _, button in self.buttons do
		button:Destroy()
	end

	table.clear(self.buttons)
	table.clear(self.widths)

	for index, group in self.menus do
		local width = self.app.measure:width(group.text, theme.text.sm, theme.font.medium) + theme.space.md * 2

		if group.icon and group.icon ~= "" then
			width += theme.size.icon + theme.space.xs
		end

		self.widths[index] = math.ceil(width)

		local button = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundColor3 = theme.color.surfaceHover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(self.widths[index], theme.size.control),
				LayoutOrder = index,

				Font = theme.font.medium,
				TextSize = theme.text.sm,
				TextColor3 = theme.color.textMuted,
				TextTransparency = theme.transparency.muted,

				Name = `Menu_{group.id}`,
				Text = group.text,
			},
			children = { Create.corner(theme.radius.sm) },
		}) :: TextButton

		button.Parent = self.instance

		self.buttons[index] = button

		Hover.attach(self.scope, button, function(hovering)
			if not self.enabled or group.disabled then
				return
			end

			--// with one menu already down, crossing the strip switches to the
			--// neighbour. That is the behaviour every menu bar has had for
			--// thirty years, and its absence is felt immediately
			if hovering and self.open and self.open ~= group.id then
				MenuBar.openMenu(self, group.id :: string)

				return
			end

			if group.id ~= self.open then
				button.BackgroundTransparency = if hovering then 0.92 else 1
			end
		end)

		self.scope:add(button.Activated:Connect(function()
			if not self.enabled or group.disabled then
				return
			end

			MenuBar.toggle(self, group.id :: string)
		end))
	end

	MenuBar.paint(self)
end

function MenuBar.setMenus(self: Fields & Types.MenuBar, menus: { Types.MenuGroup }): Types.MenuBar
	local normalised: { Types.MenuGroup } = {}

	for index, group in menus do
		table.insert(normalised, identify(group, index))
	end

	self.menus = normalised

	--// the open menu may not exist any more, and a highlighted title that is
	--// gone is worse than a closed menu
	MenuBar.closeMenu(self)
	MenuBar.rebuild(self)

	return self:invalidate()
end

--- Which menu is down, if any.
function MenuBar.openId(self: Fields & Types.MenuBar): string?
	return self.open
end

function MenuBar.onPicked(self: Fields & Types.MenuBar, handler: (Types.MenuItem, string) -> ()): Types.MenuBar
	return self:on("picked", handler)
end

function MenuBar.onOpened(self: Fields & Types.MenuBar, handler: (string) -> ()): Types.MenuBar
	return self:on("opened", handler)
end

function MenuBar.measure(self: Fields & Types.MenuBar, available: Vector2): Vector2
	local total = 0

	for index, width in self.widths do
		total += width + (if index > 1 then 2 else 0)
	end

	local width = math.min(total, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), self.app.theme.size.control)
	self.measured = true

	return self.desired
end

function MenuBar.destroy(self: Fields & Types.MenuBar)
	if self.menu then
		self.menu:destroy()

		self.menu = nil
	end

	Node.teardown(self)
end

Element.install(MenuBar)

return MenuBar
