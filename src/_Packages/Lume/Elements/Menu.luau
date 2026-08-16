--!strict

--- A context menu. The element itself takes no space — it is a handle you keep
--- and call `openAt` on; the menu is a popover panel built on demand.
---
--- Items may carry an `action`, in which case picking one runs it before the
--- `picked` event fires. Dividers, shortcuts, disabled rows and a danger tone
--- are all part of the item shape.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Placement = require(script.Parent.Parent.Layout.Placement)
local Element = require(script.Parent.Element)

local Menu = {}
Menu.__index = Menu

export type Fields = Types.NodeFields & Types.ElementFields & {
	items: { Types.MenuItem },
	popover: Types.Panel?,
	built: boolean,
}

--// locals
local function normalise(entry: Types.MenuItem | string): Types.MenuItem
	if type(entry) == "string" then
		if entry == "-" then
			return { text = "", divider = true }
		end

		return { id = entry, text = entry }
	end

	return entry :: Types.MenuItem
end

--- Creates a menu. Prefer `panel:menu()`.
function Menu.new(app: Types.App): Types.Menu
	local scope = app.scope:child()

	local root = Create.node(scope, {
		class = "Frame",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			Visible = false,
			Name = "Menu",
		},
	}) :: Frame

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root,
		refs = { root = root },
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "menu",
		desired = Vector2.zero,
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		items = {},
		popover = nil,
		built = false,
	}

	return setmetatable(fields, Menu) :: any
end

--- Builds the popover contents from the current items.
function Menu.build(self: Fields & Types.Menu): Types.Panel
	local Panel = require(script.Parent.Parent.Panel)
	local theme = self.app.theme

	local popover = self.popover

	if not popover then
		popover = Panel.new(self.app, "popover")

		local created = popover :: Types.Panel

		created:setPadding(theme.space.xs, theme.space.xs)
		created:setGap(1)
		created:setMaxSize(320, 420)

		self.popover = created
	end

	local menu = popover :: Types.Panel

	menu:clear()

	local function wire(button: Types.Button, item: Types.MenuItem)
		button:setVariant("ghost")
		button:setEnabled(item.disabled ~= true)

		if item.icon then
			button:setIcon(item.icon)
		end

		if item.danger then
			button:setColor(theme.color.danger)
		end

		button:onClicked(function()
			if item.action then
				item.action()
			end

			self:emit("picked", item)

			menu:close()
		end)
	end

	for _, item in self.items do
		if item.divider then
			menu:divider()

			continue
		end

		--// an item with a shortcut needs a row: label on the left, key on the
		--// right. Everything else is one full-width button
		if item.shortcut then
			local row = menu:group("horizontal")

			row:setFill(true)
			row:setGap(theme.space.sm)

			local button = row:button(item.text)

			button:setGrow(true)

			wire(button, item)

			local hint = row:label(item.shortcut)

			hint:setTextSize(theme.text.xs)
			hint:setMuted(true)
		else
			local button = menu:button(item.text)

			button:setFill(true)

			wire(button, item)
		end
	end

	self.built = true

	return menu
end

function Menu.setItems(self: Fields & Types.Menu, items: { Types.MenuItem | string }): Types.Menu
	local normalised: { Types.MenuItem } = {}

	for _, entry in items do
		table.insert(normalised, normalise(entry))
	end

	self.items = normalised
	self.built = false

	if self.popover then
		Menu.build(self)
	end

	return self
end

--- Opens the menu at a screen position, flipped and clamped to stay visible.
function Menu.openAt(self: Fields & Types.Menu, position: Vector2): Types.Menu
	local menu = if self.built and self.popover then self.popover :: Types.Panel else Menu.build(self)

	menu:setAnchor("topLeft")
	menu:refreshNow()

	local layer = self.app:surface("popover")
	local viewport = self.app:viewport()

	local clamped = Placement.clamp(
		UDim2.fromOffset(position.X - layer.AbsolutePosition.X, position.Y - layer.AbsolutePosition.Y),
		Vector2.zero,
		menu.target,
		viewport,
		self.app.theme.space.sm
	)

	menu.instance.AnchorPoint = Vector2.zero
	menu.settled = clamped
	menu.instance.Position = clamped

	menu:open()

	return self
end

function Menu.closeMenu(self: Fields & Types.Menu): Types.Menu
	if self.popover then
		self.popover:close()
	end

	return self
end

function Menu.onPicked(self: Fields & Types.Menu, handler: (Types.MenuItem) -> ()): Types.Menu
	return self:on("picked", handler)
end

function Menu.measure(self: Fields & Types.Menu, _available: Vector2): Vector2
	self.desired = Vector2.zero
	self.measured = true

	return self.desired
end

function Menu.destroy(self: Fields & Types.Menu)
	if self.popover then
		self.popover:destroy()

		self.popover = nil
	end

	Node.teardown(self)
end

Element.install(Menu)

return Menu
