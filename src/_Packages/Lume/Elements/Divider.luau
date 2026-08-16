--!strict

--- A hairline rule, optionally with a caption.
---
--- A labelled divider hides its rule and shows only the caption. The usual
--- trick — floating the caption on an opaque chip over the line — needs an
--- opaque surface to hide behind, and Lume's surfaces are translucent by
--- default, so the line would ghost through the text.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Divider = {}
Divider.__index = Divider

export type Fields = Types.NodeFields & Types.ElementFields & {
	thickness: number,
	labelled: boolean,
}

--- Creates a divider. Prefer `panel:divider()`.
function Divider.new(app: Types.App): Types.Divider
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.stroke.hairline),
			Name = "Divider",
		},
		children = {
			{
				class = "Frame",
				ref = "line",
				props = {
					BackgroundColor3 = theme.color.border,
					BackgroundTransparency = theme.transparency.border,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, theme.stroke.hairline),

					Name = "Line",
				},
			},
			{
				class = "TextLabel",
				ref = "caption",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.hint),

					Font = theme.font.medium,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Left,

					Visible = false,
					Name = "Caption",
					Text = "",
					ZIndex = 2,
				},
				children = {
					Create.padding(theme.space.xs, 0),
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

		kind = "divider",
		desired = Vector2.new(0, theme.stroke.hairline),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		thickness = theme.stroke.hairline,
		labelled = false,
	}

	return setmetatable(fields, Divider) :: any
end

function Divider.setLabel(self: Fields & Types.Divider, label: Types.Bindable<string>): Types.Divider
	local caption = self.refs.caption :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		caption.Text = value
		caption.Visible = value ~= ""

		self.labelled = value ~= ""

		--// the rule and the caption are alternatives, not neighbours
		;(self.refs.line :: Frame).Visible = not self.labelled

		self:invalidate()
	end)

	return self
end

function Divider.setThickness(self: Fields & Types.Divider, thickness: number): Types.Divider
	self.thickness = thickness
	;(self.refs.line :: Frame).Size = UDim2.new(1, 0, 0, thickness)

	return self:invalidate()
end

function Divider.setColor(self: Fields & Types.Divider, color: Types.Bindable<Color3>): Types.Divider
	Node.bind(self, "color", color, function(next: Color3)
		(self.refs.line :: Frame).BackgroundColor3 = next
	end)

	return self
end

function Divider.measure(self: Fields & Types.Divider, available: Vector2): Vector2
	local height = if self.labelled then self.app.theme.size.hint else self.thickness

	--// a rule wants no width of its own; it takes whatever the panel settles
	--// on during commit, so it never drags a panel wider
	self.desired = Vector2.new(0, height)
	self.measured = true

	return self.desired
end

Element.install(Divider)

return Divider
