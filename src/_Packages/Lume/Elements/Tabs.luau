--!strict

--- A row of tabs in one of three shapes: an underline, a pill, or a segmented
--- control.
---
--- All three share one indicator that springs between tabs rather than
--- redrawing. Watching the marker travel is what tells you which way you moved.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Tabs = {}
Tabs.__index = Tabs

export type Variant = "underline" | "pill" | "segmented"

export type Fields = Types.NodeFields & Types.ElementFields & {
	tabs: { Types.Tab },
	buttons: { TextButton },
	active: string?,
	variant: Variant,
	widths: { number },
}

--// locals
local function normalise(entry: Types.Tab | string): Types.Tab
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	return entry :: Types.Tab
end

--- Creates a tab strip. Prefer `panel:tabs()`.
function Tabs.new(app: Types.App): Types.Tabs
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Tabs",
		},
		children = {
			{
				class = "Frame",
				ref = "indicator",
				props = {
					BackgroundColor3 = theme.color.accent,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.fromOffset(0, 2),

					Name = "Indicator",
					ZIndex = 2,
				},
				children = { Create.corner(theme.radius.pill) },
			},
			{
				class = "Frame",
				ref = "strip",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Name = "Strip",
					ZIndex = 3,
				},
				children = {
					Create.list(Enum.FillDirection.Horizontal, 0, {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
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

		kind = "tabs",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		tabs = {},
		buttons = {},
		active = nil,
		variant = "underline",
		widths = {},
	}

	return setmetatable(fields, Tabs) :: any
end

--- Measures every tab label so the indicator can be placed exactly.
function Tabs.measureTabs(self: Fields)
	local theme = self.app.theme

	table.clear(self.widths)

	for index, tab in self.tabs do
		local width = self.app.measure:width(tab.text, theme.text.sm, theme.font.medium) + theme.space.md * 2

		if tab.icon and tab.icon ~= "" then
			width += theme.size.icon + theme.space.xs
		end

		self.widths[index] = math.ceil(width)
	end
end

--- Moves the indicator to the active tab and recolours the labels.
function Tabs.paint(self: Fields, immediate: boolean?)
	local theme = self.app.theme
	local indicator = self.refs.indicator :: Frame

	local offset = 0
	local target: { number }? = nil

	for index, tab in self.tabs do
		local width = self.widths[index] or 0
		local button = self.buttons[index]

		if button then
			local selected = tab.id == self.active

			button.TextColor3 = if selected then theme.color.text else theme.color.textMuted
			button.TextTransparency = if selected then 0 else theme.transparency.muted

			if self.variant == "segmented" then
				button.BackgroundTransparency = 1
			end
		end

		if tab.id == self.active then
			target = { offset, width }
		end

		offset += width
	end

	if not target then
		indicator.Visible = false

		return
	end

	indicator.Visible = true

	local geometry: { [string]: any }

	if self.variant == "underline" then
		indicator.AnchorPoint = Vector2.new(0, 1)

		geometry = {
			Position = UDim2.new(0, target[1], 1, 0),
			Size = UDim2.fromOffset(target[2], 2),
		}
	else
		indicator.AnchorPoint = Vector2.new(0, 0.5)

		geometry = {
			Position = UDim2.new(0, target[1], 0.5, 0),
			Size = UDim2.new(0, target[2], 1, 0),
		}
	end

	if immediate then
		Motion.set(indicator, geometry)
	else
		Motion.animate(indicator, geometry, theme:spec("morph"))
	end
end

--- Rebuilds the tab buttons. Called on `setTabs` only, not on selection.
function Tabs.rebuild(self: Fields & Types.Tabs)
	local theme = self.app.theme
	local strip = self.refs.strip :: Frame

	for _, button in self.buttons do
		button:Destroy()
	end

	table.clear(self.buttons)

	Tabs.measureTabs(self)

	for index, tab in self.tabs do
		local button = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundColor3 = theme.color.surfaceHover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(self.widths[index] or 0, theme.size.control),
				LayoutOrder = index,

				Font = theme.font.medium,
				TextSize = theme.text.sm,
				TextColor3 = theme.color.textMuted,
				TextTransparency = theme.transparency.muted,

				Name = `Tab_{tab.id}`,
				Text = tab.text,
			},
			children = { Create.corner(theme.radius.sm) },
		}) :: TextButton

		button.Parent = strip

		self.buttons[index] = button

		Hover.attach(self.scope, button, function(hovering)
			if tab.id == self.active then
				return
			end

			Motion.animate(
				button,
				{ TextTransparency = if hovering then 0 else theme.transparency.muted },
				theme:spec("hover")
			)
		end)

		self.scope:add(button.Activated:Connect(function()
			if not self.enabled or self.active == tab.id then
				return
			end

			self.active = tab.id

			Tabs.paint(self)

			self:emit("changed", tab.id)
		end))
	end

	if not self.active and self.tabs[1] then
		self.active = self.tabs[1].id
	end

	Tabs.paint(self, true)
end

function Tabs.setTabs(self: Fields & Types.Tabs, tabs: Types.Bindable<{ Types.Tab | string }>): Types.Tabs
	Node.bind(self, "tabs", tabs, function(next: { Types.Tab | string })
		local normalised: { Types.Tab } = {}

		for _, entry in next do
			table.insert(normalised, normalise(entry))
		end

		self.tabs = normalised

		Tabs.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Tabs.setValue(self: Fields & Types.Tabs, id: Types.Bindable<string>): Types.Tabs
	Node.bind(self, "value", id, function(next: string)
		if self.active == next then
			return
		end

		self.active = next

		Tabs.paint(self)

		self:emit("changed", next)
	end)

	return self
end

function Tabs.setVariant(self: Fields & Types.Tabs, variant: Variant): Types.Tabs
	local theme = self.app.theme
	local indicator = self.refs.indicator :: Frame

	self.variant = variant

	local corner = indicator:FindFirstChildOfClass("UICorner")

	if corner then
		corner.CornerRadius = if variant == "pill" then UDim.new(1, 0) else UDim.new(0, theme.radius.sm)
	end

	if variant == "segmented" then
		local root = self.instance :: Frame

		root.BackgroundColor3 = theme.color.surfaceSunken
		root.BackgroundTransparency = 0.4

		if not root:FindFirstChildOfClass("UICorner") then
			Create.node(self.scope, Create.corner(theme.radius.md)).Parent = root
		end
	else
		(self.instance :: Frame).BackgroundTransparency = 1
	end

	Tabs.paint(self, true)

	return self
end

function Tabs.onChanged(self: Fields & Types.Tabs, handler: (string) -> ()): Types.Tabs
	return self:on("changed", handler)
end

function Tabs.value(self: Fields & Types.Tabs): string?
	return self.active
end

function Tabs.measure(self: Fields & Types.Tabs, available: Vector2): Vector2
	local total = 0

	for _, width in self.widths do
		total += width
	end

	local width = math.min(total, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), self.app.theme.size.control)
	self.measured = true

	return self.desired
end

Element.install(Tabs)

return Tabs
