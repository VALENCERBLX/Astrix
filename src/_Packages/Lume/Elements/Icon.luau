--!strict

--- An image at a fixed square size, tinted by the theme.
---
--- Icons never scale with content — a row is easier to read when its icons
--- share one size — so measurement is simply the size you asked for.
--- @section Elements

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Icon = {}
Icon.__index = Icon

export type Fields = Types.NodeFields & Types.ElementFields & {
	iconSize: number,
	spinning: RBXScriptConnection?,
}

--- Creates an icon. Prefer `panel:icon(image)`.
function Icon.new(app: Types.App): Types.Icon
	local theme = app.theme
	local scope = app.scope:child()

	local root = Create.node(scope, {
		class = "ImageLabel",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			ImageColor3 = theme.color.textMuted,
			ImageTransparency = theme.transparency.muted,
			ScaleType = Enum.ScaleType.Fit,

			Size = UDim2.fromOffset(theme.size.icon, theme.size.icon),
			Name = "Icon",
			Image = "",
		},
	}) :: ImageLabel

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root,
		refs = { root = root },
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "icon",
		desired = Vector2.new(theme.size.icon, theme.size.icon),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		iconSize = theme.size.icon,
		spinning = nil,
	}

	return setmetatable(fields, Icon) :: any
end

function Icon.setImage(self: Fields & Types.Icon, image: Types.Bindable<string>): Types.Icon
	Node.bind(self, "image", image, function(next: string)
		(self.instance :: ImageLabel).Image = tostring(next)
	end)

	return self
end

function Icon.setColor(self: Fields & Types.Icon, color: Types.Bindable<Color3>): Types.Icon
	Node.bind(self, "color", color, function(next: Color3)
		(self.instance :: ImageLabel).ImageColor3 = next
	end)

	return self
end

function Icon.setIconSize(self: Fields & Types.Icon, size: number): Types.Icon
	self.iconSize = size

	return self:invalidate()
end

function Icon.setScaleType(self: Fields & Types.Icon, scale: Enum.ScaleType): Types.Icon
	(self.instance :: ImageLabel).ScaleType = scale

	return self
end

--- Uses a region of a sprite sheet rather than the whole image.
function Icon.setRectOffset(self: Fields & Types.Icon, offset: Vector2, size: Vector2): Types.Icon
	local image = self.instance :: ImageLabel

	image.ImageRectOffset = offset
	image.ImageRectSize = size

	return self
end

--- Spins the icon continuously — a loading indicator without a second asset.
function Icon.setSpin(self: Fields & Types.Icon, spinning: boolean): Types.Icon
	if self.spinning then
		self.spinning:Disconnect()

		self.spinning = nil
	end

	if not spinning then
		(self.instance :: ImageLabel).Rotation = 0

		return self
	end

	local connection = RunService.RenderStepped:Connect(function(delta)
		local image = self.instance :: ImageLabel

		image.Rotation = (image.Rotation + delta * 360) % 360
	end)

	self.spinning = connection
	self.scope:add(connection)

	return self
end

function Icon.measure(self: Fields & Types.Icon, _available: Vector2): Vector2
	self.desired = Vector2.new(self.iconSize, self.iconSize)
	self.measured = true

	return self.desired
end

Element.install(Icon)

return Icon
