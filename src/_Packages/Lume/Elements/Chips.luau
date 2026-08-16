--!strict

--- A wrapping row of small pills: tags, filters, active selections.
---
--- Chips wrap rather than scroll, so the element reports a height that depends
--- on the width it is given — which is exactly the case the measure/commit
--- split exists for.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Chips = {}
Chips.__index = Chips

export type Fields = Types.NodeFields & Types.ElementFields & {
	chips: { Types.Option },
	instances: { TextButton },
	widths: { number },

	chosen: { string },
	removable: boolean,
	selectable: boolean,
	wrapping: boolean,
}

local CHIP_HEIGHT = 24
local REMOVE_WIDTH = 16

--// locals
local function normalise(entry: Types.Option | string): Types.Option
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local option = entry :: Types.Option

	return { id = option.id or option.text, text = option.text, icon = option.icon, description = option.description }
end

--- Creates a chip row. Prefer `panel:chips()`.
function Chips.new(app: Types.App): Types.Chips
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
			Name = "Chips",
		},
		children = {
			{
				class = "UIListLayout",
				ref = "layout",
				props = {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.space.xs),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Wraps = true,
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

		kind = "chips",
		desired = Vector2.new(0, CHIP_HEIGHT),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		chips = {},
		instances = {},
		widths = {},

		chosen = {},
		removable = false,
		selectable = false,
		wrapping = true,
	}

	return setmetatable(fields, Chips) :: any
end

local function isChosen(self: Fields, id: string): boolean
	return table.find(self.chosen, id) ~= nil
end

--- Recolours every chip for the current selection.
function Chips.paint(self: Fields)
	local theme = self.app.theme

	for index, option in self.chips do
		local button = self.instances[index]

		if not button then
			continue
		end

		local selected = self.selectable and isChosen(self, option.id)

		Motion.animate(button, {
			BackgroundColor3 = if selected then theme.color.accent else theme.color.textMuted,
			BackgroundTransparency = if selected then 0 else 0.85,
			TextColor3 = if selected then theme.color.accentText else theme.color.textMuted,
		}, theme:spec("hover"))
	end
end

--- Rebuilds every chip instance and caches their measured widths.
function Chips.rebuild(self: Fields & Types.Chips)
	local theme = self.app.theme

	for _, button in self.instances do
		button:Destroy()
	end

	table.clear(self.instances)
	table.clear(self.widths)

	for index, option in self.chips do
		local textWidth = self.app.measure:width(option.text, theme.text.xs, theme.font.medium)
		local width = math.ceil(textWidth + theme.space.sm * 2 + (if self.removable then REMOVE_WIDTH else 0))

		self.widths[index] = width

		local button = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundColor3 = theme.color.textMuted,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(width, CHIP_HEIGHT),
				LayoutOrder = index,

				Font = theme.font.medium,
				TextSize = theme.text.xs,
				TextColor3 = theme.color.textMuted,
				TextXAlignment = Enum.TextXAlignment.Left,

				Name = `Chip_{option.id}`,
				Text = "",
			},
			children = {
				Create.corner(theme.radius.pill),
				Create.padding(theme.space.sm, 0),
				Create.list(Enum.FillDirection.Horizontal, 2, {
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				{
					class = "TextLabel",
					props = {
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, CHIP_HEIGHT),

						Font = theme.font.medium,
						TextSize = theme.text.xs,
						TextColor3 = theme.color.textMuted,
						TextYAlignment = Enum.TextYAlignment.Center,

						LayoutOrder = 1,
						Name = "Text",
						Text = option.text,
					},
				},
				{
					class = "TextButton",
					props = {
						BackgroundTransparency = 1,
						AutoButtonColor = false,
						Size = UDim2.fromOffset(REMOVE_WIDTH, CHIP_HEIGHT),

						Font = theme.font.medium,
						TextSize = theme.text.sm,
						TextColor3 = theme.color.textMuted,

						LayoutOrder = 2,
						Visible = self.removable,
						Name = "Remove",
						Text = "×",
					},
				},
			},
		}) :: TextButton

		button.Parent = self.instance

		self.instances[index] = button

		local remove = button:FindFirstChild("Remove") :: TextButton?

		Hover.attach(self.scope, button, function(hovering)
			if self.selectable and isChosen(self, option.id) then
				return
			end

			Motion.animate(
				button,
				{ BackgroundTransparency = if hovering then 0.75 else 0.85 },
				theme:spec("hover")
			)
		end)

		if remove then
			self.scope:add(remove.Activated:Connect(function()
				if self.enabled then
					self:emit("removed", option.id)
				end
			end))
		end

		self.scope:add(button.Activated:Connect(function()
			if not self.enabled or not self.selectable then
				return
			end

			local at = table.find(self.chosen, option.id)

			if at then
				table.remove(self.chosen, at)
			else
				table.insert(self.chosen, option.id)
			end

			Chips.paint(self)

			self:emit("selected", table.clone(self.chosen))
		end))
	end

	Chips.paint(self)
end

function Chips.setChips(self: Fields & Types.Chips, chips: Types.Bindable<{ Types.Option | string }>): Types.Chips
	Node.bind(self, "chips", chips, function(next: { Types.Option | string })
		local normalised: { Types.Option } = {}

		for _, entry in next do
			table.insert(normalised, normalise(entry))
		end

		self.chips = normalised

		Chips.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Chips.setRemovable(self: Fields & Types.Chips, removable: boolean): Types.Chips
	self.removable = removable ~= false

	Chips.rebuild(self)

	return self:invalidate()
end

function Chips.setSelectable(self: Fields & Types.Chips, selectable: boolean): Types.Chips
	self.selectable = selectable ~= false

	Chips.paint(self)

	return self
end

function Chips.setSelected(self: Fields & Types.Chips, ids: Types.Bindable<{ string }>): Types.Chips
	Node.bind(self, "selected", ids, function(next: { string })
		self.chosen = table.clone(next)

		Chips.paint(self)
	end)

	return self
end

function Chips.setWrap(self: Fields & Types.Chips, wrap: boolean): Types.Chips
	self.wrapping = wrap ~= false
	;(self.refs.layout :: UIListLayout).Wraps = self.wrapping

	return self:invalidate()
end

function Chips.onRemoved(self: Fields & Types.Chips, handler: (string) -> ()): Types.Chips
	return self:on("removed", handler)
end

function Chips.onSelected(self: Fields & Types.Chips, handler: ({ string }) -> ()): Types.Chips
	return self:on("selected", handler)
end

function Chips.selected(self: Fields & Types.Chips): { string }
	return table.clone(self.chosen)
end

--- Height depends on the width offered, because wrapping does.
function Chips.measure(self: Fields & Types.Chips, available: Vector2): Vector2
	local theme = self.app.theme
	local width = math.max(1, available.X - self.margin * 2)

	local total = 0

	for index, chipWidth in self.widths do
		total += chipWidth + (if index > 1 then theme.space.xs else 0)
	end

	--// one row is the natural size; only report the full width once the chips
	--// genuinely need to wrap
	if not self.wrapping or total <= width then
		self.desired = Vector2.new(math.min(total, width), CHIP_HEIGHT)
		self.measured = true

		return self.desired
	end

	local rows = 1
	local cursor = 0

	for _, chipWidth in self.widths do
		local advance = chipWidth + (if cursor > 0 then theme.space.xs else 0)

		if cursor + advance > width and cursor > 0 then
			rows += 1
			cursor = chipWidth
		else
			cursor += advance
		end
	end

	local height = rows * CHIP_HEIGHT + (rows - 1) * theme.space.xs

	self.desired = Vector2.new(width, height)
	self.measured = true

	return self.desired
end

Element.install(Chips)

return Chips
