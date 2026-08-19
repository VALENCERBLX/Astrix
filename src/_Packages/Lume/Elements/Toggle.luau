--!strict

--- A boolean, as a sliding switch or a checkbox, with an optional description
--- line under the label.
---
--- The switch thumb is a spring, not a tween. Flicking it twice quickly bends
--- the travel instead of restarting it, which is the difference between a
--- control that feels responsive and one that feels queued.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Toggle = {}
Toggle.__index = Toggle

export type Fields = Types.NodeFields & Types.ElementFields & {
	--// `on`, not `value`, so it cannot shadow the `value()` method
	--// **not** `on`: an instance field shadows its metatable, and every
	--// element inherits an `on(event, handler)` method from Node. A field
	--// called `on` made `toggle:onChanged(fn)` fail with *attempt to call a
	--// boolean value*, because `self:on(…)` was reading the boolean.
	checked: boolean,
	labelText: string,
	descriptionText: string,
	style: "switch" | "checkbox",
}

local SWITCH_WIDTH = 40
local SWITCH_HEIGHT = 22
local CHECKBOX_SIZE = 20

--- Creates a toggle. Prefer `panel:toggle(label)`.
function Toggle.new(app: Types.App): Types.Toggle
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Toggle",
		},
		children = {
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, -(SWITCH_WIDTH + theme.space.md), 0, theme.size.row),

					Font = theme.font.body,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,

					Name = "Label",
					Text = "",
				},
			},
			{
				class = "TextLabel",
				ref = "description",
				props = {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, theme.size.row),
					Size = UDim2.new(1, -(SWITCH_WIDTH + theme.space.md), 0, theme.size.hint),

					Font = theme.font.body,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,

					Visible = false,
					Name = "Description",
					Text = "",
				},
			},
			{
				class = "Frame",
				ref = "track",
				props = {
					BackgroundColor3 = theme.color.track,
					BackgroundTransparency = theme.transparency.track,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0, theme.size.row / 2),
					Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT),

					Name = "Track",
				},
				children = {
					Create.corner(theme.radius.pill),
					{
						class = "UIStroke",
						ref = "trackStroke",
						props = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = theme.color.border,
							Thickness = theme.stroke.hairline,
							Transparency = theme.transparency.border,
						},
					},
					{
						class = "Frame",
						ref = "thumb",
						props = {
							BackgroundColor3 = theme.color.textMuted,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 3, 0.5, 0),
							Size = UDim2.fromOffset(theme.size.thumb + 2, theme.size.thumb + 2),

							Name = "Thumb",
						},
						children = { Create.corner(theme.radius.pill) },
					},
				},
			},
			{
				class = "TextButton",
				ref = "hit",
				props = {
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Size = UDim2.fromScale(1, 1),
					Name = "Hit",
					Text = "",
					ZIndex = 4,
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

		kind = "toggle",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		checked = false,
		labelText = "",
		descriptionText = "",
		style = "switch",
	}

	local toggle = setmetatable(fields, Toggle) :: any

	local hit = refs.hit :: TextButton

	Hover.attach(scope, hit, function(hovering)
		if not fields.enabled then
			return
		end

		Motion.animate(
			refs.track :: Frame,
			{ BackgroundTransparency = if hovering then theme.transparency.track - 0.12 else theme.transparency.track },
			theme:spec("hover")
		)
	end)

	scope:add(hit.Activated:Connect(function()
		if fields.enabled then
			Toggle.flip(toggle)
		end
	end))

	Toggle.paint(fields, true)

	return toggle
end

--- Moves the thumb and recolours the track for the current state.
function Toggle.paint(self: Fields, immediate: boolean?)
	local theme = self.app.theme

	local track = self.refs.track :: Frame
	local thumb = self.refs.thumb :: Frame
	local stroke = self.refs.trackStroke :: UIStroke

	if self.style == "checkbox" then
		track.Size = UDim2.fromOffset(CHECKBOX_SIZE, CHECKBOX_SIZE)
		thumb.Size = UDim2.fromOffset(CHECKBOX_SIZE - 8, CHECKBOX_SIZE - 8)
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)

		local target = {
			BackgroundColor3 = if self.checked then theme.color.accent else theme.color.track,
			BackgroundTransparency = if self.checked then 0 else theme.transparency.track,
		}

		local thumbTarget = {
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = if self.checked then 0 else 1,
			BackgroundColor3 = theme.color.accentText,
		}

		if immediate then
			Motion.set(track, target)
			Motion.set(thumb, thumbTarget)
		else
			Motion.animate(track, target, theme:spec("hover"))
			Motion.animate(thumb, thumbTarget, theme:spec("morph"))
		end

		stroke.Transparency = if self.checked then 1 else theme.transparency.border

		return
	end

	track.Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT)
	thumb.AnchorPoint = Vector2.new(0, 0.5)
	thumb.Size = UDim2.fromOffset(theme.size.thumb + 2, theme.size.thumb + 2)

	local travel = SWITCH_WIDTH - (theme.size.thumb + 2) - 3

	local trackTarget = {
		BackgroundColor3 = if self.checked then theme.color.accent else theme.color.track,
		BackgroundTransparency = if self.checked then 0 else theme.transparency.track,
	}

	local thumbTarget = {
		Position = UDim2.new(0, if self.checked then travel else 3, 0.5, 0),
		BackgroundColor3 = if self.checked then theme.color.accentText else theme.color.textMuted,
	}

	if immediate then
		Motion.set(track, trackTarget)
		Motion.set(thumb, thumbTarget)
	else
		Motion.animate(track, trackTarget, theme:spec("hover"))
		Motion.animate(thumb, thumbTarget, theme:spec("morph"))
	end

	stroke.Transparency = if self.checked then 1 else theme.transparency.border
end

function Toggle.setLabel(self: Fields & Types.Toggle, label: Types.Bindable<string>): Types.Toggle
	local text = self.refs.label :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		self.labelText = value
		text.Text = value

		self:invalidate()
	end)

	return self
end

function Toggle.setDescription(self: Fields & Types.Toggle, description: Types.Bindable<string>): Types.Toggle
	local text = self.refs.description :: TextLabel

	Node.bind(self, "description", description, function(next: string)
		local value = tostring(next)

		self.descriptionText = value

		text.Text = value
		text.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

function Toggle.setValue(self: Fields & Types.Toggle, value: Types.Bindable<boolean>): Types.Toggle
	Node.bind(self, "value", value, function(next: boolean)
		local resolved = next == true

		if self.checked == resolved then
			return
		end

		self.checked = resolved

		Toggle.paint(self)

		self:emit("changed", resolved)
	end)

	return self
end

function Toggle.setStyle(self: Fields & Types.Toggle, style: "switch" | "checkbox"): Types.Toggle
	self.style = style

	Toggle.paint(self, true)

	return self:invalidate()
end

function Toggle.onChanged(self: Fields & Types.Toggle, handler: (boolean) -> ()): Types.Toggle
	return self:on("changed", handler)
end

--- Flips the state and fires `changed`.
function Toggle.flip(self: Fields & Types.Toggle): Types.Toggle
	self.checked = not self.checked

	Toggle.paint(self)

	self:emit("changed", self.checked)

	return self
end

function Toggle.value(self: Fields & Types.Toggle): boolean
	return self.checked
end

function Toggle.measure(self: Fields & Types.Toggle, available: Vector2): Vector2
	local theme = self.app.theme
	local control = if self.style == "checkbox" then CHECKBOX_SIZE else SWITCH_WIDTH

	local ceiling = math.max(1, available.X - self.margin * 2)
	local natural = self.app.measure:width(self.labelText, theme.text.sm, theme.font.body)
		+ control
		+ theme.space.md

	local width = math.min(natural, ceiling)
	local height = theme.size.control

	if self.descriptionText ~= "" then
		--// the description wraps, so its height depends on the width we settle
		--// on, not on the width we would have liked
		local textWidth = math.max(1, ceiling - control - theme.space.md)
		local bounds = self.app.measure:text(self.descriptionText, theme.text.xs, theme.font.body, textWidth)

		height = theme.size.row + bounds.Y + theme.space.xs
		width = ceiling
	end

	self.desired = Vector2.new(math.ceil(width), math.ceil(height))
	self.measured = true

	return self.desired
end

--- Keeps the label column clear of the switch at whatever width we ended up.
function Toggle.commit(self: Fields & Types.Toggle, inner: Vector2, vertical: boolean, share: number)
	local theme = self.app.theme

	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	local control = if self.style == "checkbox" then CHECKBOX_SIZE else SWITCH_WIDTH
	local column = math.max(0, width - control - theme.space.md)

	;(self.refs.label :: TextLabel).Size = UDim2.new(0, column, 0, theme.size.row)
	;(self.refs.description :: TextLabel).Size =
		UDim2.new(0, column, 0, math.max(0, height - theme.size.row))
end

Element.install(Toggle)

return Toggle
