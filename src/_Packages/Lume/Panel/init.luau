--!strict

--- A panel is every surface Lume draws. Window, command bar, dropdown,
--- tooltip, modal, toast — one implementation, configured by preset.
---
--- It does three things nothing else does:
---
--- * **Sizes itself from its children.** One pass per frame: ask each child
---   what it wants, sum along the axis, clamp against both the panel's own
---   bounds and the room left on screen, animate to the result.
--- * **Grows away from what it is stuck to.** AnchorPoint does the work; a
---   bottom-anchored panel expands upward and its bottom edge never moves.
--- * **Morphs.** A pill-shaped bar becomes a rounded rectangle the moment it
---   has enough content to stop being one row tall.
---
--- Panels are also elements, so nesting one inside another is how stacking,
--- popovers and inline cards are all the same code path.
--- @section Panel

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Types)

local Autosize = require(script.Parent.Layout.Autosize)
local Placement = require(script.Parent.Layout.Placement)

local Element = require(script.Parent.Elements.Element)
local Node = require(script.Parent.Core.Node)
local Motion = require(script.Parent.Motion)
local Drag = require(script.Parent.Input.Drag)

local Presets = require(script.Presets)
local Chrome = require(script.Chrome)

type Panel = Types.Panel
type Bindable<T> = Types.Bindable<T>

local Panel = {}
Panel.__index = Panel

--// locals
local DISMISS_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

--- Resolves a token name against a theme group, passing numbers through.
local function token(group: { [string]: number }, name: string?, fallback: number): number
	if not name then
		return fallback
	end

	return group[name] or fallback
end

local function contains(instance: GuiObject, point: Vector2): boolean
	if not instance.Visible then
		return false
	end

	local position = instance.AbsolutePosition
	local size = instance.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

--- The offset a panel slides in from — a short hop against its growth
--- direction, so it reads as arriving from the edge it is anchored to.
local function entryOffset(anchor: Types.Anchor, distance: number): Vector2
	if anchor == "bottom" or anchor == "bottomLeft" or anchor == "bottomRight" then
		return Vector2.new(0, distance)
	elseif anchor == "top" or anchor == "topLeft" or anchor == "topRight" then
		return Vector2.new(0, -distance)
	elseif anchor == "left" then
		return Vector2.new(-distance, 0)
	elseif anchor == "right" then
		return Vector2.new(distance, 0)
	end

	return Vector2.new(0, distance)
end

local function adopt(self: Panel, element: Types.Element): Types.Element
	element.owner = self

	table.insert(self.children, element)

	element.instance.LayoutOrder = #self.children
	element.instance.Parent = self.content

	self:refresh()

	return element
end

--// public api
--- Creates a panel. Prefer `app:panel(preset)`.
function Panel.new(app: Types.App, preset: Types.Preset?): Panel
	local theme = app.theme
	local scope = app.scope:child()

	local titleHeight = theme.size.title
	local root, refs = Chrome.build(app, scope, titleHeight)

	local initial = Vector2.new(320, theme.size.control)

	local fields: Types.NodeFields & Types.ElementFields & Types.PanelFields = {
		--// node
		app = app,
		scope = scope,
		instance = root,
		refs = refs,
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		--// element
		kind = "panel",
		desired = initial,
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		--// panel
		preset = "plain",
		anchor = "center",
		axis = "vertical",
		layer = "default",

		content = refs.content :: ScrollingFrame,
		children = {},
		panels = {},

		titleHeight = titleHeight,
		hasTitle = false,
		scrollable = true,
		dismissable = false,
		dirty = false,
		mounted = false,

		backdrop = nil,
		hitbox = nil,
		attachTarget = nil,
		attachSide = "bottom",
		attachGap = theme.space.xs,

		gap = theme.space.sm,
		padX = theme.space.md,
		padY = theme.space.md,

		minWidth = 0,
		maxWidth = 9999,
		minHeight = 0,
		maxHeight = 9999,
		fixedWidth = nil,
		fixedHeight = nil,

		inset = theme.space.lg,
		radius = theme.radius.md,
		pill = false,

		opened = false,
		solving = false,
		seq = 0,

		target = initial,
		settled = root.Position,

		stack = nil,
		drag = nil,
		shadow = nil,
	}

	local panel = setmetatable(fields, Panel) :: any

	panel.shadow = Chrome.shadow(app, scope)

	--// the shadow follows the panel by watching its geometry, so it stays glued
	--// through every frame of an animation rather than only at the ends
	if panel.shadow then
		local function track()
			Chrome.track(panel.shadow, root, theme.shadow.spread, theme.shadow.offset)
		end

		scope:add(root:GetPropertyChangedSignal("Size"):Connect(track))
		scope:add(root:GetPropertyChangedSignal("Position"):Connect(track))
		scope:add(root:GetPropertyChangedSignal("Visible"):Connect(track))
		scope:add(root:GetPropertyChangedSignal("AnchorPoint"):Connect(track))
	end

	scope:add(refs.close.Activated:Connect(function()
		panel:close()
	end))

	table.insert(app.panels, panel)

	scope:add(function()
		local index = table.find(app.panels, panel)

		if index then
			table.remove(app.panels, index)
		end
	end)

	Panel.setPreset(panel, preset or "window")

	return panel
end

--// shell
--- Applies a preset's defaults. Anything set afterwards wins.
function Panel.setPreset(self: Panel, preset: Types.Preset): Panel
	local theme = self.app.theme
	local config = Presets.get(preset)

	self.preset = preset

	self.axis = config.axis or "vertical"
	self.layer = config.layer or "default"

	self.gap = token(theme.space, config.gap, theme.space.sm)
	self.padX = token(theme.space, config.padX, theme.space.md)
	self.padY = token(theme.space, config.padY, theme.space.md)
	self.inset = token(theme.space, config.inset, theme.space.lg)

	self.radius = token(theme.radius, config.radius, theme.radius.md)
	self.pill = config.pill == true

	self.minWidth = config.minWidth or 0
	self.maxWidth = config.maxWidth or 9999
	self.minHeight = config.minHeight or 0
	self.maxHeight = config.maxHeight or 9999
	self.fixedWidth = config.width

	self.dismissable = config.dismissable == true

	self.instance.BackgroundColor3 = theme.color[config.color or "surface"] or theme.color.surface
	self.instance.BackgroundTransparency = theme.transparency[config.transparency or "surface"]
		or theme.transparency.surface
	self.instance.ClipsDescendants = config.clip ~= false

	Panel.setAnchor(self, config.anchor or "center")
	Panel.setBorder(self, config.border == true)
	Panel.setShadow(self, config.shadow == true)
	Panel.setDraggable(self, config.draggable == true)
	Panel.setCloseButton(self, config.closeButton == true)

	self.hasTitle = config.title == true
	self.refs.titlebar.Visible = self.hasTitle

	if config.backdrop then
		Panel.ensureBackdrop(self)
	end

	local layout = self.refs.layout :: UIListLayout

	layout.FillDirection = if self.axis == "vertical"
		then Enum.FillDirection.Vertical
		else Enum.FillDirection.Horizontal
	layout.VerticalAlignment = if self.axis == "vertical"
		then Enum.VerticalAlignment.Top
		else Enum.VerticalAlignment.Center

	Panel.applySpacing(self)

	return self:refresh()
end

--- Pushes padding and gap onto the content layout instances.
function Panel.applySpacing(self: Panel)
	local padding = self.refs.padding :: UIPadding
	local layout = self.refs.layout :: UIListLayout

	padding.PaddingLeft = UDim.new(0, self.padX)
	padding.PaddingRight = UDim.new(0, self.padX)
	padding.PaddingTop = UDim.new(0, self.padY)
	padding.PaddingBottom = UDim.new(0, self.padY)

	layout.Padding = UDim.new(0, self.gap)
end

function Panel.setTitle(self: Panel, title: Bindable<string>): Panel
	local label = self.refs.titleText :: TextLabel

	self.hasTitle = true
	self.refs.titlebar.Visible = true

	Node.bind(self, "title", title, function(next: string)
		label.Text = tostring(next)
	end)

	return self:refresh()
end

function Panel.setSubtitle(self: Panel, subtitle: Bindable<string>): Panel
	local label = self.refs.subtitle :: TextLabel

	label.Visible = true

	Node.bind(self, "subtitle", subtitle, function(next: string)
		label.Text = tostring(next)
		label.Visible = next ~= nil and next ~= ""
	end)

	return self
end

function Panel.setIcon(self: Panel, image: Bindable<string>): Panel
	local icon = self.refs.titleIcon :: ImageLabel

	Node.bind(self, "titleIcon", image, function(next: string)
		icon.Image = tostring(next)
		icon.Visible = next ~= nil and next ~= ""
	end)

	return self
end

--- Anchors the panel to an edge or the centre of its layer. The AnchorPoint is
--- what makes growth happen in the right direction, so this is a layout call
--- as much as a positioning one.
function Panel.setAnchor(self: Panel, anchor: Types.Anchor, offset: Vector2?): Panel
	self.anchor = anchor

	local point = Placement.anchorPoint(anchor)
	local position = Placement.position(anchor, self.inset, offset)

	self.instance.AnchorPoint = point
	self.instance.Position = position

	self.settled = position

	if self.drag then
		self.drag:setPosition(position)
	end

	return self:refresh()
end

function Panel.setLayer(self: Panel, layer: string): Panel
	self.layer = layer

	if self.mounted and not self.owner then
		self:mount(self.app:surface(layer))
	end

	return self
end

function Panel.setRadius(self: Panel, radius: number | "pill"): Panel
	if radius == "pill" then
		self.pill = true
		self.radius = self.app.theme.radius.lg
	else
		self.pill = false
		self.radius = radius :: number
	end

	return self:refresh()
end

function Panel.setColor(self: Panel, color: Bindable<Color3>): Panel
	Node.bind(self, "color", color, function(next: Color3)
		self.instance.BackgroundColor3 = next
	end)

	return self
end

function Panel.setTransparency(self: Panel, transparency: Bindable<number>): Panel
	Node.bind(self, "transparency", transparency, function(next: number)
		self.instance.BackgroundTransparency = next
	end)

	return self
end

function Panel.setBorder(self: Panel, enabled: boolean): Panel
	local stroke = self.refs.stroke :: UIStroke

	stroke.Enabled = enabled ~= false

	return self
end

function Panel.setShadow(self: Panel, enabled: boolean): Panel
	if self.shadow then
		self.shadow.Visible = enabled ~= false and self.instance.Visible
	end

	return self
end

function Panel.setClip(self: Panel, enabled: boolean): Panel
	self.instance.ClipsDescendants = enabled ~= false

	return self
end

--// layout
function Panel.setAxis(self: Panel, axis: Types.Axis): Panel
	self.axis = axis

	local layout = self.refs.layout :: UIListLayout

	layout.FillDirection = if axis == "vertical" then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	layout.VerticalAlignment = if axis == "vertical" then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center

	self.content.ScrollingDirection = if axis == "vertical"
		then Enum.ScrollingDirection.Y
		else Enum.ScrollingDirection.X

	return self:refresh()
end

function Panel.setGap(self: Panel, gap: number): Panel
	self.gap = gap

	Panel.applySpacing(self)

	return self:refresh()
end

function Panel.setPadding(self: Panel, x: number, y: number?): Panel
	self.padX = x
	self.padY = y or x

	Panel.applySpacing(self)

	return self:refresh()
end

--- A fixed width, or `"auto"` to size from content.
function Panel.setWidth(self: Panel, width: number | "auto"): Panel
	self.fixedWidth = if width == "auto" then nil else width :: number

	return self:refresh()
end

--- A fixed height, or `"auto"` to size from content.
function Panel.setHeight(self: Panel, height: number | "auto"): Panel
	self.fixedHeight = if height == "auto" then nil else height :: number

	return self:refresh()
end

function Panel.setMinSize(self: Panel, width: number, height: number): Panel
	self.minWidth = width
	self.minHeight = height

	return self:refresh()
end

function Panel.setMaxSize(self: Panel, width: number, height: number): Panel
	self.maxWidth = width
	self.maxHeight = height

	return self:refresh()
end

--- How close the panel may come to the edge of the screen before its own
--- maximum size starts giving way.
function Panel.setInset(self: Panel, inset: number): Panel
	self.inset = inset

	return self:refresh()
end

function Panel.setScroll(self: Panel, enabled: boolean): Panel
	self.scrollable = enabled ~= false

	return self:refresh()
end

--// behaviour
function Panel.setDraggable(self: Panel, enabled: boolean, options: Drag.Options?): Panel
	if not enabled then
		if self.drag then
			self.drag:destroy()

			self.drag = nil
		end

		return self
	end

	--// a preset already created one, so a later call carrying options has to
	--// rebuild rather than return early — otherwise the options are silently
	--// dropped and the panel keeps the preset's plain drag
	if self.drag then
		if not options then
			return self
		end

		self.drag:destroy()

		self.drag = nil
	end

	--// drag by the titlebar when there is one, so content interaction never
	--// moves the panel out from under the pointer
	local handles = if self.hasTitle then { self.refs.titlebar :: GuiObject } else { self.instance :: GuiObject }

	local settings: Drag.Options = {
		handles = handles,
		scope = self.scope,
	}

	for key, value in options or {} do
		(settings :: any)[key] = value
	end

	self.drag = Drag.attach(self.app, self.instance, settings)

	local handle = self.drag :: Types.DragHandle

	self.scope:add(handle.ended:connect(function(position: UDim2)
		self.settled = position

		self:emit("moved", position)
	end))

	return self
end

--- Close when a click lands outside the panel.
function Panel.setDismissable(self: Panel, enabled: boolean): Panel
	self.dismissable = enabled ~= false

	return self
end

function Panel.setCloseButton(self: Panel, enabled: boolean): Panel
	self.refs.close.Visible = enabled ~= false

	return self
end

--- Covers the panel with a click target.
---
--- A collapsed console bar is a button: you click it and it opens. The target
--- sits above the content, so turning it off is what lets the expanded panel's
--- own children take input again.
function Panel.setActivatable(self: Panel, enabled: boolean): Panel
	if not enabled then
		if self.hitbox then
			self.hitbox.Visible = false
		end

		return self
	end

	if self.hitbox then
		self.hitbox.Visible = true

		return self
	end

	local button = Instance.new("TextButton")

	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Name = "Hitbox"
	button.ZIndex = 50
	button.Parent = self.instance

	self.scope:add(button)
	self.scope:add(button.Activated:Connect(function()
		self:emit("activated")
	end))

	self.hitbox = button

	return self
end

function Panel.onActivated(self: Panel, handler: () -> ()): Panel
	return self:on("activated", handler)
end

--- Creates the dimming backdrop a modal sits on.
function Panel.ensureBackdrop(self: Panel): Frame
	if self.backdrop then
		return self.backdrop
	end

	local theme = self.app.theme
	local frame = Instance.new("Frame")

	frame.BackgroundColor3 = theme.color.overlay
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 0
	frame.Visible = false
	frame.Name = "Backdrop"
	frame.Parent = self.app:surface(self.layer)

	self.scope:add(frame)

	self.backdrop = frame

	return frame
end

--- Positions the panel next to another instance, flipping sides when it would
--- run off screen. This is what makes a dropdown a dropdown.
function Panel.attachTo(
	self: Panel,
	target: GuiObject | Types.Element | Panel,
	side: Types.Edge?,
	gap: number?
): Panel
	local instance: GuiObject

	if typeof(target) == "Instance" then
		instance = target
	else
		instance = (target :: Types.Element).instance
	end

	self.attachTarget = instance
	self.attachSide = side or "bottom"
	self.attachGap = gap or self.app.theme.space.xs

	return self:refresh()
end

--// children
function Panel.add(self: Panel, child: Types.Element | Panel): Panel
	adopt(self, child :: Types.Element)

	if (child :: any).kind == "panel" then
		table.insert(self.panels, child :: Panel)
	end

	return self
end

function Panel.remove(self: Panel, child: Types.Element | Panel): Panel
	local index = table.find(self.children, child :: Types.Element)

	if index then
		table.remove(self.children, index)
	end

	local nested = table.find(self.panels, child :: Panel)

	if nested then
		table.remove(self.panels, nested)
	end

	;(child :: Types.Element).owner = nil
	;(child :: Types.Element).instance.Parent = nil

	return self:refresh()
end

--- Destroys every child. The panel itself survives.
function Panel.clear(self: Panel): Panel
	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	table.clear(self.children)
	table.clear(self.panels)

	return self:refresh()
end

--// lifecycle
function Panel.isOpen(self: Panel): boolean
	return self.opened
end

--- Shows the panel: fades the group in and slides it a short way from the edge
--- it is anchored to.
function Panel.open(self: Panel): Panel
	if self.opened or self.dead then
		return self
	end

	self.opened = true

	if not self.mounted then
		self:mount(self.app:surface(self.layer))
	end

	self.instance.Visible = true

	if self.backdrop then
		self.backdrop.Visible = true

		Motion.set(self.backdrop, { BackgroundTransparency = 1 })
		Motion.animate(
			self.backdrop,
			{ BackgroundTransparency = self.app.theme.transparency.overlay },
			self.app.theme:spec("enter")
		)
	end

	Panel.refreshNow(self)

	local settled = self.settled
	local hop = entryOffset(self.anchor, 12)

	Motion.set(self.instance, {
		GroupTransparency = 1,
		Position = UDim2.new(settled.X.Scale, settled.X.Offset + hop.X, settled.Y.Scale, settled.Y.Offset + hop.Y),
	})

	self:animate({ GroupTransparency = 0 }, "enter")

	Motion.animate(self.instance, { Position = settled }, self.app.theme:spec("reveal"))

	if self.dismissable then
		Panel.armDismiss(self)
	end

	self:emit("opened")

	return self
end

--- Hides the panel. The instance survives; call `destroy` to be rid of it.
function Panel.close(self: Panel): Panel
	if not self.opened or self.dead then
		return self
	end

	self.opened = false

	if self.backdrop then
		local fade = Motion.animate(self.backdrop, { BackgroundTransparency = 1 }, self.app.theme:spec("exit"))

		fade.completed:once(function()
			if not self.opened and self.backdrop then
				self.backdrop.Visible = false
			end
		end)
	end

	local animation = self:animate({ GroupTransparency = 1 }, "exit")

	animation.completed:once(function()
		--// reopened while the fade was still running: leave it visible
		if not self.opened and not self.dead then
			self.instance.Visible = false
		end
	end)

	self:emit("closed")

	return self
end

function Panel.toggleOpen(self: Panel): Panel
	return if self.opened then Panel.close(self) else Panel.open(self)
end

--- Watches for a click outside the panel while it is open.
function Panel.armDismiss(self: Panel)
	local disconnect: Types.Unsubscribe? = nil

	local connection = UserInputService.InputBegan:Connect(function(input)
		if not DISMISS_INPUTS[input.UserInputType] or not self.opened then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)

		if contains(self.instance, point) then
			return
		end

		if self.attachTarget and contains(self.attachTarget, point) then
			return
		end

		self:close()
	end)

	self.scope:add(connection)

	local unsubscribe = Node.signal(self, "closed"):once(function()
		connection:Disconnect()

		if disconnect then
			disconnect()
		end
	end)

	disconnect = unsubscribe
end

--// layout pass
--- Schedules a layout pass. Coalesced to one per frame, so calling it from a
--- keystroke handler is free.
function Panel.refresh(self: Panel): Panel
	if self.dead then
		return self
	end

	self.dirty = true

	if self.solving then
		return self
	end

	self.solving = true

	task.defer(function()
		if self.dead then
			return
		end

		self.solving = false

		if self.dirty then
			Panel.refreshNow(self)
		end
	end)

	return self
end

--- Runs the layout pass immediately.
---
--- Measure every visible child, sum along the axis, clamp against the panel's
--- bounds *and* the room left on screen, then animate the shell to the result
--- while the children are committed into it.
function Panel.refreshNow(self: Panel): Panel
	if self.dead then
		return self
	end

	self.dirty = false
	self.seq += 1

	local theme = self.app.theme
	local vertical = self.axis == "vertical"
	local chromeHeight = if self.hasTitle then self.titleHeight else 0

	--// how much screen is left in the direction this panel grows. Before the
	--// first frame AbsolutePosition is meaningless, so fall back to the whole
	--// viewport rather than clamping everything to zero
	local viewport = self.app:viewport()
	local room = Placement.room(self.instance, viewport, self.inset)

	if room.X < 1 or room.Y < 1 or not self.mounted then
		room = Vector2.new(viewport.X - self.inset * 2, viewport.Y - self.inset * 2)
	end

	local input: Autosize.Input = {
		children = self.children,
		vertical = vertical,

		gap = self.gap,
		padX = self.padX,
		padY = self.padY,

		chrome = Vector2.new(0, chromeHeight),
		room = room,

		minWidth = self.minWidth,
		maxWidth = self.maxWidth,
		minHeight = math.max(self.minHeight, chromeHeight),
		maxHeight = self.maxHeight,

		fixedWidth = self.fixedWidth,
		fixedHeight = self.fixedHeight,
	}

	local solution = Autosize.solve(input)
	local share = Autosize.share(input, solution)

	local inner = Vector2.new(
		math.max(0, solution.clamped.X - self.padX * 2),
		math.max(0, solution.clamped.Y - self.padY * 2 - chromeHeight)
	)

	for _, child in self.children do
		if child.instance.Visible then
			child:commit(inner, vertical, if child.grow then share else 0)
		end
	end

	--// content region sits under the titlebar and owns the scroll
	self.content.Position = UDim2.fromOffset(0, chromeHeight)
	self.content.Size = UDim2.new(1, 0, 1, -chromeHeight)

	self.content.CanvasSize = if vertical
		then UDim2.fromOffset(0, solution.content.Y + self.padY * 2)
		else UDim2.fromOffset(solution.content.X + self.padX * 2, 0)

	local scrolling = solution.overflow and self.scrollable

	self.content.ScrollingEnabled = scrolling
	self.content.ScrollBarThickness = if scrolling then 3 else 0
	self.content.ScrollBarImageTransparency = if scrolling then 0.5 else 1

	self.target = solution.clamped
	self.desired = solution.clamped

	--// a nested panel is placed by its parent's list layout, so it sets its
	--// size directly and leaves position alone
	if self.owner then
		self.instance.Size = UDim2.fromOffset(solution.clamped.X, solution.clamped.Y)
	else
		self:animate({ Size = UDim2.fromOffset(solution.clamped.X, solution.clamped.Y) }, "layout")
	end

	--// the morph: pill while it is one row tall, rounded rectangle once it has
	--// grown into something with content.
	--
	--// "one row tall" is measured against this panel's own padding plus one
	--// control, not against a global token — a panel with roomier padding is
	--// still a single row, and should still be a pill
	local corner = self.refs.corner :: UICorner
	local singleRow = self.padY * 2 + theme.size.control + chromeHeight

	local radius = if self.pill and solution.clamped.Y <= singleRow + 1
		then solution.clamped.Y / 2
		else self.radius

	Motion.animate(corner, { CornerRadius = UDim.new(0, radius) }, theme:spec("morph"))

	if self.attachTarget then
		Panel.reposition(self)
	end

	Chrome.track(self.shadow, self.instance, theme.shadow.spread, theme.shadow.offset)

	if self.stack then
		self.stack:reflow()
	end

	self:emit("resized", solution.clamped)

	return self
end

--- Recomputes an attached panel's position against its target.
function Panel.reposition(self: Panel)
	local target = self.attachTarget

	if not target or not target.Parent then
		return
	end

	local layer = self.instance.Parent

	if not layer or not layer:IsA("GuiObject") then
		return
	end

	local position, anchor = Placement.attach(
		layer,
		target,
		self.target,
		self.attachSide,
		self.attachGap,
		self.app:viewport(),
		self.inset
	)

	self.instance.AnchorPoint = anchor
	self.settled = position

	if self.opened then
		Motion.animate(self.instance, { Position = position }, self.app.theme:spec("layout"))
	else
		self.instance.Position = position
	end
end

--// placement
function Panel.mount(self: Panel, parent: Instance | Panel): Panel
	if typeof(parent) == "Instance" then
		self.instance.Parent = parent

		if self.shadow then
			self.shadow.Parent = parent
		end
	else
		local host = parent :: Panel

		self.instance.AnchorPoint = Vector2.zero
		self.instance.Position = UDim2.fromOffset(0, 0)

		host:add(self)

		if self.shadow then
			self.shadow.Parent = host.content
		end
	end

	self.mounted = true

	return self:refresh()
end

function Panel.center(self: Panel): Panel
	return Panel.setAnchor(self, "center")
end

function Panel.moveTo(self: Panel, position: UDim2): Panel
	self.settled = position

	if self.drag then
		self.drag:setPosition(position)
	end

	Motion.animate(self.instance, { Position = position }, self.app.theme:spec("layout"))

	return self
end

--- Raises the panel above its siblings on the same layer.
function Panel.front(self: Panel): Panel
	local parent = self.instance.Parent

	if not parent then
		return self
	end

	local highest = 0

	for _, sibling in parent:GetChildren() do
		if sibling:IsA("GuiObject") and sibling ~= self.instance then
			highest = math.max(highest, sibling.ZIndex)
		end
	end

	self.instance.ZIndex = highest + 1

	if self.shadow then
		self.shadow.ZIndex = highest
	end

	return self
end

--// element interface: a panel nested in a panel is just an element
function Panel.measure(self: Panel, available: Vector2): Vector2
	if self.dirty then
		Panel.refreshNow(self)
	end

	if self.fill then
		return Vector2.new(available.X, self.target.Y)
	end

	return self.target
end

function Panel.commit(self: Panel, inner: Vector2, vertical: boolean, _share: number)
	if not self.fill then
		return
	end

	local width = if vertical then math.max(0, inner.X - self.margin * 2) else self.target.X
	local height = if vertical then self.target.Y else math.max(0, inner.Y - self.margin * 2)

	self.instance.Size = UDim2.fromOffset(width, height)
end

--// factories
local Elements = nil :: any

local function elements()
	if not Elements then
		Elements = require(script.Parent.Elements)
	end

	return Elements
end

function Panel.label(self: Panel, text: Bindable<string>?): Types.Label
	local element = elements().Label.new(self.app)

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element :: any) :: any
end

function Panel.icon(self: Panel, image: Bindable<string>?): Types.Icon
	local element = elements().Icon.new(self.app)

	if image ~= nil then
		element:setImage(image)
	end

	return adopt(self, element :: any) :: any
end

function Panel.button(self: Panel, text: Bindable<string>?): Types.Button
	local element = elements().Button.new(self.app)

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element :: any) :: any
end

function Panel.field(self: Panel, placeholder: Bindable<string>?): Types.Field
	local element = elements().Field.new(self.app)

	if placeholder ~= nil then
		element:setPlaceholder(placeholder)
	end

	return adopt(self, element :: any) :: any
end

function Panel.toggle(self: Panel, label: Bindable<string>?): Types.Toggle
	local element = elements().Toggle.new(self.app)

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element :: any) :: any
end

function Panel.slider(self: Panel, label: Bindable<string>?): Types.Slider
	local element = elements().Slider.new(self.app)

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element :: any) :: any
end

function Panel.select(self: Panel, label: Bindable<string>?): Types.Select
	local element = elements().Select.new(self.app)

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element :: any) :: any
end

function Panel.list(self: Panel): Types.List
	return adopt(self, elements().List.new(self.app) :: any) :: any
end

function Panel.divider(self: Panel): Types.Divider
	return adopt(self, elements().Divider.new(self.app) :: any) :: any
end

function Panel.spacer(self: Panel, size: number?): Types.Spacer
	local element = elements().Spacer.new(self.app)

	if size ~= nil then
		element:setAmount(size)
	end

	return adopt(self, element :: any) :: any
end

function Panel.group(self: Panel, axis: Types.Axis?): Types.Group
	local element = elements().Group.new(self.app)

	if axis ~= nil then
		element:setAxis(axis)
	end

	return adopt(self, element :: any) :: any
end

function Panel.progress(self: Panel): Types.Progress
	return adopt(self, elements().Progress.new(self.app) :: any) :: any
end

function Panel.tabs(self: Panel): Types.Tabs
	return adopt(self, elements().Tabs.new(self.app) :: any) :: any
end

function Panel.chips(self: Panel): Types.Chips
	return adopt(self, elements().Chips.new(self.app) :: any) :: any
end

function Panel.suggest(self: Panel): Types.Suggest
	return adopt(self, elements().Suggest.new(self.app) :: any) :: any
end

function Panel.menu(self: Panel): Types.Menu
	return adopt(self, elements().Menu.new(self.app) :: any) :: any
end

function Panel.badge(self: Panel, text: Bindable<string>?): Types.Badge
	local element = elements().Badge.new(self.app)

	if text ~= nil then
		element:setText(text)
	end

	return adopt(self, element :: any) :: any
end

function Panel.scroll(self: Panel): Types.Scroll
	return adopt(self, elements().Scroll.new(self.app) :: any) :: any
end

function Panel.keybind(self: Panel, label: Bindable<string>?): Types.Keybind
	local element = elements().Keybind.new(self.app)

	if label ~= nil then
		element:setLabel(label)
	end

	return adopt(self, element :: any) :: any
end

--- Nests a panel inside this one. The child is laid out by this panel's list
--- layout and keeps its own content-driven sizing.
function Panel.panel(self: Panel, preset: Types.Preset?): Panel
	local child = Panel.new(self.app, preset or "card")

	child:mount(self)
	child.instance.Visible = true
	child.opened = true

	return child
end

--- Destroys the panel and everything in it. Children are taken down first so
--- their own teardown still sees a live parent.
function Panel.destroy(self: Panel)
	if self.dead then
		return
	end

	for index = #self.children, 1, -1 do
		local child = self.children[index]

		if child ~= (self :: any) then
			child:destroy()
		end
	end

	table.clear(self.children)
	table.clear(self.panels)

	if self.stack then
		self.stack:remove(self)
	end

	if self.drag then
		self.drag:destroy()

		self.drag = nil
	end

	if self.shadow then
		self.shadow:Destroy()

		self.shadow = nil
	end

	if self.backdrop then
		self.backdrop:Destroy()

		self.backdrop = nil
	end

	Node.teardown(self)
end

Element.install(Panel)

return Panel
