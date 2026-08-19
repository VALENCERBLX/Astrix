--!strict

--- A player's headshot, round, with initials underneath in case it never
--- arrives.
---
--- The initials are not a nicety. A thumbnail that has not loaded is a hole in
--- the layout, and a hole where a face should be reads as an error; two letters
--- read as a person whose picture is still coming.
---
--- Thumbnails are requested through `rbxthumb://`, which resolves without
--- yielding — so an avatar can be built inside a layout pass, which
--- `GetUserThumbnailAsync` cannot.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Avatar = {}
Avatar.__index = Avatar

export type Fields = Types.NodeFields & Types.ElementFields & {
	userId: number?,
	image: string,
	initials: string,
	diameter: number,
	status: string?,
	square: boolean,
}

--// locals
--- Two letters out of a name: the first of the first two words, or the first
--- two letters if there is only one word.
local function shorten(name: string): string
	local words = {}

	for word in name:gmatch("%S+") do
		table.insert(words, word)
	end

	if #words >= 2 then
		return (words[1]:sub(1, 1) .. words[2]:sub(1, 1)):upper()
	end

	return name:sub(1, 2):upper()
end

--- Creates an avatar. Prefer `panel:avatar(userId)`.
function Avatar.new(app: Types.App): Types.Avatar
	local theme = app.theme
	local scope = app.scope:child()

	local diameter = 36

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.surfaceSunken,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,

			Size = UDim2.fromOffset(diameter, diameter),
			Name = "Avatar",
		},
		children = {
			Create.corner(UDim.new(1, 0)),
			{
				class = "TextLabel",
				ref = "initials",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					Font = theme.font.medium,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,

					Name = "Initials",
					Text = "",
				},
			},
			{
				class = "ImageLabel",
				ref = "image",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ScaleType = Enum.ScaleType.Crop,

					Name = "Image",
					Image = "",
					Visible = false,
				},
				children = { Create.corner(UDim.new(1, 0)) },
			},
			{
				class = "Frame",
				ref = "status",
				props = {
					BackgroundColor3 = theme.color.success,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
					Size = UDim2.fromOffset(10, 10),
					Visible = false,
					ZIndex = 2,
					Name = "Status",
				},
				children = {
					Create.corner(UDim.new(1, 0)),
					Create.stroke(theme.color.surface, 2, 0),
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

		kind = "avatar",
		desired = Vector2.new(diameter, diameter),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		userId = nil,
		image = "",
		initials = "",
		diameter = diameter,
		status = nil,
		square = false,
	}

	return setmetatable(fields, Avatar) :: any
end

function Avatar.paint(self: Fields)
	local image = self.refs.image :: ImageLabel
	local initials = self.refs.initials :: TextLabel

	image.Image = self.image
	image.Visible = self.image ~= ""
	initials.Text = self.initials
	initials.Visible = self.initials ~= ""
end

--- Points the avatar at a player. Uses `rbxthumb://`, which does not yield.
function Avatar.setUserId(self: Fields & Types.Avatar, userId: Types.Bindable<number?>): Types.Avatar
	Node.bind(self, "userId", userId, function(next: number?)
		self.userId = next
		self.image = if next and next > 0
			then `rbxthumb://type=AvatarHeadShot&id={next}&w=150&h=150`
			else ""

		Avatar.paint(self)
	end)

	return self
end

--- Any image, for the cases that are not a player.
function Avatar.setImage(self: Fields & Types.Avatar, image: Types.Bindable<string>): Types.Avatar
	Node.bind(self, "image", image, function(next: string)
		self.image = next or ""

		Avatar.paint(self)
	end)

	return self
end

--- The name to fall back to. Two letters are taken from it.
function Avatar.setName(self: Fields & Types.Avatar, name: Types.Bindable<string>): Types.Avatar
	Node.bind(self, "name", name, function(next: string)
		self.initials = if next and next ~= "" then shorten(next) else ""

		Avatar.paint(self)
	end)

	return self
end

function Avatar.setDiameter(self: Fields & Types.Avatar, diameter: number): Types.Avatar
	self.diameter = math.max(12, diameter)
	;(self.refs.initials :: TextLabel).TextSize = math.max(9, math.floor(self.diameter * 0.36))

	self.instance.Size = UDim2.fromOffset(self.diameter, self.diameter)

	return self:invalidate()
end

--- A dot in the corner. `"online"`, `"away"`, `"busy"`, or nil for none.
function Avatar.setStatus(self: Fields & Types.Avatar, status: string?): Types.Avatar
	local theme = self.app.theme
	local dot = self.refs.status :: Frame

	self.status = status
	dot.Visible = status ~= nil

	if status == "away" then
		dot.BackgroundColor3 = theme.color.warn
	elseif status == "busy" then
		dot.BackgroundColor3 = theme.color.danger
	else
		dot.BackgroundColor3 = theme.color.success
	end

	return self
end

--- Rounded square instead of a circle.
function Avatar.setSquare(self: Fields & Types.Avatar, square: boolean?): Types.Avatar
	local theme = self.app.theme

	self.square = square ~= false

	local radius = if self.square then UDim.new(0, theme.radius.sm) else UDim.new(1, 0)

	for _, child in self.instance:GetDescendants() do
		if child:IsA("UICorner") then
			child.CornerRadius = radius
		end
	end

	return self
end

function Avatar.measure(self: Fields & Types.Avatar, _available: Vector2): Vector2
	self.desired = Vector2.new(self.diameter, self.diameter)
	self.measured = true

	return self.desired
end

Element.install(Avatar)

return Avatar
