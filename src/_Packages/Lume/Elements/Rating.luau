--!strict

--- A row of stars you click to score something.
---
--- Hovering previews the score rather than only highlighting one star, because
--- the question is "how many", not "which". Clicking the star already showing
--- clears it — otherwise a five-star rating given by accident can only be
--- lowered to one.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Rating = {}
Rating.__index = Rating

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	maximum: number,
	preview: number?,
	stars: { TextButton },
	labelText: string,
	glyph: string,
	clearable: boolean,
	starSize: number,
}

--- Creates a rating. Prefer `panel:rating(label)`.
function Rating.new(app: Types.App): Types.Rating
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Rating",
		},
		children = {
			Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.control),

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
				ref = "stars",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.control),
					LayoutOrder = 2,
					Name = "Stars",
				},
				children = {
					Create.list(Enum.FillDirection.Horizontal, 2, {
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

		kind = "rating",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		maximum = 5,
		preview = nil,
		stars = {},
		labelText = "",
		glyph = "★",
		clearable = true,
		starSize = theme.text.lg,
	}

	local rating = setmetatable(fields, Rating) :: any

	Rating.rebuild(rating)

	return rating
end

--- Lights every star up to the score, or up to whatever is being hovered.
function Rating.paint(self: Fields, immediate: boolean?)
	local theme = self.app.theme
	local showing = self.preview or self.current

	for index, star in self.stars do
		local lit = index <= showing
		local target = {
			TextColor3 = if lit then theme.color.warn else theme.color.textGhost,
			TextTransparency = if lit then 0 else theme.transparency.ghost,
		}

		if immediate then
			Motion.set(star, target)
		else
			Motion.animate(star, target, theme:spec("hover"))
		end
	end
end

function Rating.rebuild(self: Fields & Types.Rating)
	local theme = self.app.theme
	local host = self.refs.stars :: Frame

	for _, star in self.stars do
		star:Destroy()
	end

	table.clear(self.stars)

	for index = 1, self.maximum do
		local star = Create.node(self.scope, {
			class = "TextButton",
			props = {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.fromOffset(self.starSize + 6, self.starSize + 6),
				LayoutOrder = index,

				Font = theme.font.body,
				TextSize = self.starSize,
				TextColor3 = theme.color.textGhost,
				TextTransparency = theme.transparency.ghost,

				Name = `Star{index}`,
				Text = self.glyph,
			},
		}) :: TextButton

		star.Parent = host

		table.insert(self.stars, star)

		Hover.attach(self.scope, star, function(hovering)
			if not self.enabled then
				return
			end

			--// the preview is the whole run up to this star, not this star
			--// alone: the question is how many, not which
			self.preview = if hovering then index else nil

			Rating.paint(self)
		end)

		self.scope:add(star.Activated:Connect(function()
			if not self.enabled then
				return
			end

			Rating.setScore(self, if self.clearable and self.current == index then 0 else index)
		end))
	end

	Rating.paint(self, true)
end

--- Sets the score and fires `changed` if it moved.
function Rating.setScore(self: Fields & Types.Rating, score: number): Types.Rating
	local next = math.clamp(math.round(score), 0, self.maximum)

	if next == self.current then
		return self
	end

	self.current = next

	Rating.paint(self)

	self:emit("changed", next)

	return self
end

function Rating.setValue(self: Fields & Types.Rating, score: Types.Bindable<number>): Types.Rating
	Node.bind(self, "value", score, function(next: number)
		self.current = math.clamp(math.round(next), 0, self.maximum)

		Rating.paint(self)
	end)

	return self
end

--- How many stars there are. Five unless you say otherwise.
function Rating.setMaximum(self: Fields & Types.Rating, maximum: number): Types.Rating
	self.maximum = math.max(1, math.round(maximum))
	self.current = math.min(self.current, self.maximum)

	Rating.rebuild(self)

	return self:invalidate()
end

--- The character each star is drawn with. Hearts, skulls, whatever suits.
function Rating.setGlyph(self: Fields & Types.Rating, glyph: string): Types.Rating
	self.glyph = glyph

	for _, star in self.stars do
		star.Text = glyph
	end

	return self
end

function Rating.setStarSize(self: Fields & Types.Rating, size: number): Types.Rating
	self.starSize = size

	Rating.rebuild(self)

	return self:invalidate()
end

--- Whether clicking the current score clears it back to nothing.
function Rating.setClearable(self: Fields & Types.Rating, clearable: boolean?): Types.Rating
	self.clearable = clearable ~= false

	return self
end

function Rating.setLabel(self: Fields & Types.Rating, label: Types.Bindable<string>): Types.Rating
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

function Rating.onChanged(self: Fields & Types.Rating, handler: (number) -> ()): Types.Rating
	return self:on("changed", handler)
end

function Rating.value(self: Fields & Types.Rating): number
	return self.current
end

function Rating.measure(self: Fields & Types.Rating, available: Vector2): Vector2
	local theme = self.app.theme
	local stars = self.maximum * (self.starSize + 6) + math.max(0, self.maximum - 1) * 2
	local width = stars

	if self.labelText ~= "" then
		width += self.app.measure:width(self.labelText, theme.text.sm, theme.font.body) + theme.space.sm
	end

	self.desired = Vector2.new(
		math.ceil(math.min(width, math.max(1, available.X - self.margin * 2))),
		math.ceil(math.max(theme.size.control, self.starSize + 6))
	)
	self.measured = true

	return self.desired
end

Element.install(Rating)

return Rating
