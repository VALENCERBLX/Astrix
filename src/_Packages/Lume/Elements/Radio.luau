--!strict

--- A set of options where exactly one is chosen, each on its own row with a
--- dot beside it.
---
--- A select hides the options behind a click; a radio group shows them all at
--- once. That is the whole difference, and it decides which to use: three
--- options with consequences want to be read side by side, twenty countries do
--- not.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Radio = {}
Radio.__index = Radio

export type Row = {
	option: Types.Option,
	button: TextButton,
	ring: Frame,
	dot: Frame,
}

export type Fields = Types.NodeFields & Types.ElementFields & {
	options: { Types.Option },
	rows: { Row },
	selected: string?,
	labelText: string,
	horizontal: boolean,
	rowHeight: number,
}

local RING = 16

--// locals
local function normalise(entry: Types.Option | string, index: number): Types.Option
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local option = entry :: Types.Option

	return {
		id = option.id or option.text or tostring(index),
		text = option.text or "",
		icon = option.icon,
		description = option.description,
	}
end

--- Creates a radio group. Prefer `panel:radio(label)`.
function Radio.new(app: Types.App): Types.Radio
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.row),
			Name = "Radio",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, theme.space.xs),
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.row),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,
					TextXAlignment = Enum.TextXAlignment.Left,

					LayoutOrder = 1,
					Visible = false,
					Name = "Label",
					Text = "",
				},
			},
			{
				class = "Frame",
				ref = "rows",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = 2,
					Name = "Rows",
				},
				children = {
					Create.list(Enum.FillDirection.Vertical, theme.space.xs, {
						VerticalAlignment = Enum.VerticalAlignment.Top,
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

		kind = "radio",
		desired = Vector2.new(0, theme.size.row),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		options = {},
		rows = {},
		selected = nil,
		labelText = "",
		horizontal = false,
		rowHeight = theme.size.row,
	}

	return setmetatable(fields, Radio) :: any
end

--- Fills the chosen dot and empties the rest.
function Radio.paint(self: Fields, immediate: boolean?)
	local theme = self.app.theme

	for _, row in self.rows do
		local chosen = row.option.id == self.selected
		local target = {
			Size = if chosen then UDim2.fromOffset(8, 8) else UDim2.fromOffset(0, 0),
			BackgroundColor3 = theme.color.accent,
		}

		if immediate then
			Motion.set(row.dot, target)
		else
			Motion.animate(row.dot, target, theme:spec("morph"))
		end

		local stroke = row.ring:FindFirstChildOfClass("UIStroke")

		if stroke then
			stroke.Color = if chosen then theme.color.accent else theme.color.borderStrong
		end

		row.button.TextColor3 = if chosen then theme.color.text else theme.color.textMuted
		row.button.TextTransparency = if chosen then 0 else theme.transparency.muted
	end
end

--- Rebuilds the rows. Called on `setOptions` only.
function Radio.rebuild(self: Fields & Types.Radio)
	local theme = self.app.theme
	local host = self.refs.rows :: Frame
	local layout = host:FindFirstChildOfClass("UIListLayout")

	for _, row in self.rows do
		row.button:Destroy()
	end

	table.clear(self.rows)

	if layout then
		layout.FillDirection = if self.horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
	end

	for index, option in self.options do
		local width = self.app.measure:width(option.text, theme.text.sm, theme.font.body) + RING + theme.space.sm * 2

		local button, refs = Create.tree(self.scope, {
			class = "TextButton",
			ref = "button",
			props = {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = if self.horizontal
					then UDim2.fromOffset(math.ceil(width), self.rowHeight)
					else UDim2.new(1, 0, 0, self.rowHeight),
				LayoutOrder = index,

				Font = theme.font.body,
				TextSize = theme.text.sm,
				TextColor3 = theme.color.textMuted,
				TextTransparency = theme.transparency.muted,
				TextXAlignment = Enum.TextXAlignment.Left,

				Name = `Option_{option.id}`,
				--// the label is padded past the ring rather than being its own
				--// instance: one less object per row, and the hit area is the
				--// whole row either way
				Text = `      {option.text}`,
			},
			children = {
				{
					class = "Frame",
					ref = "ring",
					props = {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,

						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.fromOffset(RING, RING),
						Name = "Ring",
					},
					children = {
						Create.corner(UDim.new(1, 0)),
						Create.stroke(theme.color.borderStrong, 1.5, 0.2),
						{
							class = "Frame",
							ref = "dot",
							props = {
								BackgroundColor3 = theme.color.accent,
								BorderSizePixel = 0,

								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(0, 0),
								Name = "Dot",
							},
							children = { Create.corner(UDim.new(1, 0)) },
						},
					},
				},
			},
		})

		button.Parent = host

		local row: Row = {
			option = option,
			button = button :: TextButton,
			ring = refs.ring :: Frame,
			dot = refs.dot :: Frame,
		}

		table.insert(self.rows, row)

		Hover.attach(self.scope, row.button, function(hovering)
			if not self.enabled or option.id == self.selected then
				return
			end

			Motion.animate(
				row.button,
				{ TextTransparency = if hovering then 0 else theme.transparency.muted },
				theme:spec("hover")
			)
		end)

		self.scope:add(row.button.Activated:Connect(function()
			if not self.enabled then
				return
			end

			Radio.choose(self, option.id)
		end))
	end

	Radio.paint(self, true)
end

--- Selects an option and fires `changed`, unless it was already chosen.
function Radio.choose(self: Fields & Types.Radio, id: string)
	if self.selected == id then
		return
	end

	self.selected = id

	Radio.paint(self)

	self:emit("changed", id)
end

function Radio.setOptions(
	self: Fields & Types.Radio,
	options: Types.Bindable<{ Types.Option | string }>
): Types.Radio
	Node.bind(self, "options", options, function(next: { Types.Option | string })
		local normalised: { Types.Option } = {}

		for index, entry in next do
			table.insert(normalised, normalise(entry, index))
		end

		self.options = normalised

		--// a selection that is no longer on the list is worse than none: the
		--// group would show nothing chosen while still reporting a value
		if self.selected then
			local found = false

			for _, option in normalised do
				if option.id == self.selected then
					found = true

					break
				end
			end

			if not found then
				self.selected = nil
			end
		end

		Radio.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Radio.setValue(self: Fields & Types.Radio, id: Types.Bindable<string?>): Types.Radio
	Node.bind(self, "value", id, function(next: string?)
		if self.selected == next then
			return
		end

		self.selected = next

		Radio.paint(self)
	end)

	return self
end

function Radio.setLabel(self: Fields & Types.Radio, label: Types.Bindable<string>): Types.Radio
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

--- Lays the options out in a row instead of a column. For two or three short
--- ones; a column stays easier to read past that.
function Radio.setHorizontal(self: Fields & Types.Radio, horizontal: boolean?): Types.Radio
	self.horizontal = horizontal ~= false

	Radio.rebuild(self)

	return self:invalidate()
end

function Radio.onChanged(self: Fields & Types.Radio, handler: (string) -> ()): Types.Radio
	return self:on("changed", handler)
end

function Radio.value(self: Fields & Types.Radio): string?
	return self.selected
end

function Radio.measure(self: Fields & Types.Radio, available: Vector2): Vector2
	local theme = self.app.theme
	local width = math.max(1, available.X - self.margin * 2)

	local rows = #self.rows
	local height = 0

	if self.horizontal then
		height = if rows > 0 then self.rowHeight else 0
	else
		height = rows * self.rowHeight + math.max(0, rows - 1) * theme.space.xs
	end

	if self.labelText ~= "" then
		height += theme.size.row + theme.space.xs
	end

	self.desired = Vector2.new(math.ceil(width), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Radio)

return Radio
