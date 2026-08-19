--!strict

--- Where you are, as a trail you can click back along.
---
--- The last crumb is where you are and is not a link — making it one invites a
--- click that does nothing, which reads as broken rather than as "you are
--- already here".
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Breadcrumb = {}
Breadcrumb.__index = Breadcrumb

export type Fields = Types.NodeFields & Types.ElementFields & {
	crumbs: { Types.Option },
	buttons: { TextButton },
	separator: string,
	widths: { number },
}

--// locals
local function normalise(entry: Types.Option | string, index: number): Types.Option
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local option = entry :: Types.Option

	return { id = option.id or option.text or tostring(index), text = option.text or "", icon = option.icon }
end

--- Creates a breadcrumb trail. Prefer `panel:breadcrumb(crumbs)`.
function Breadcrumb.new(app: Types.App): Types.Breadcrumb
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.row),
			Name = "Breadcrumb",
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

		kind = "breadcrumb",
		desired = Vector2.new(0, theme.size.row),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		crumbs = {},
		buttons = {},
		separator = "/",
		widths = {},
	}

	return setmetatable(fields, Breadcrumb) :: any
end

function Breadcrumb.rebuild(self: Fields & Types.Breadcrumb)
	local theme = self.app.theme

	for _, child in self.instance:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	table.clear(self.buttons)
	table.clear(self.widths)

	local order = 0

	for index, crumb in self.crumbs do
		local last = index == #self.crumbs
		local width = self.app.measure:width(crumb.text, theme.text.sm, theme.font.body) + theme.space.xs * 2

		order += 1

		local button = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(math.ceil(width), theme.size.row),
				LayoutOrder = order,

				Font = if last then theme.font.medium else theme.font.body,
				TextSize = theme.text.sm,
				TextColor3 = if last then theme.color.text else theme.color.textMuted,
				TextTransparency = if last then 0 else theme.transparency.muted,

				Name = `Crumb_{crumb.id}`,
				Text = crumb.text,
			},
		}) :: TextButton

		button.Parent = self.instance

		table.insert(self.buttons, button)
		table.insert(self.widths, width)

		if not last then
			Hover.attach(self.scope, button, function(hovering)
				if not self.enabled then
					return
				end

				button.TextTransparency = if hovering then 0 else theme.transparency.muted
			end)

			self.scope:add(button.Activated:Connect(function()
				if not self.enabled then
					return
				end

				self:emit("picked", crumb.id, index)
			end))

			order += 1

			local gap = self.app.measure:width(self.separator, theme.text.sm, theme.font.body) + 4

			local mark = Create.node(self.scope, {
				class = "TextLabel",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(math.ceil(gap), theme.size.row),
					LayoutOrder = order,

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,

					Name = "Separator",
					Text = self.separator,
				},
			}) :: TextLabel

			mark.Parent = self.instance

			table.insert(self.widths, gap)
		end
	end
end

function Breadcrumb.setCrumbs(
	self: Fields & Types.Breadcrumb,
	crumbs: Types.Bindable<{ Types.Option | string }>
): Types.Breadcrumb
	Node.bind(self, "crumbs", crumbs, function(next: { Types.Option | string })
		local normalised: { Types.Option } = {}

		for index, entry in next do
			table.insert(normalised, normalise(entry, index))
		end

		self.crumbs = normalised

		Breadcrumb.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Breadcrumb.setSeparator(self: Fields & Types.Breadcrumb, separator: string): Types.Breadcrumb
	self.separator = separator

	Breadcrumb.rebuild(self)

	return self:invalidate()
end

function Breadcrumb.onPicked(self: Fields & Types.Breadcrumb, handler: (string, number) -> ()): Types.Breadcrumb
	return self:on("picked", handler)
end

function Breadcrumb.measure(self: Fields & Types.Breadcrumb, available: Vector2): Vector2
	local total = 0

	for _, width in self.widths do
		total += width + 2
	end

	self.desired = Vector2.new(
		math.ceil(math.min(total, math.max(1, available.X - self.margin * 2))),
		self.app.theme.size.row
	)
	self.measured = true

	return self.desired
end

Element.install(Breadcrumb)

return Breadcrumb
