--!strict

--- A progress bar, determinate or not.
---
--- The determinate fill is a spring, so a value that jumps from 20% to 80%
--- travels rather than teleports. The indeterminate one is a chunk sweeping
--- the rail, driven by the same driver so it stops cleanly on destroy.
--- @section Elements

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Element = require(script.Parent.Element)

local Progress = {}
Progress.__index = Progress

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	labelText: string,
	showValue: boolean,
	thickness: number,
	indeterminate: boolean,
	sweep: RBXScriptConnection?,
	elapsed: number,
}

--- Creates a progress bar. Prefer `panel:progress()`.
function Progress.new(app: Types.App): Types.Progress
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.rail),
			Name = "Progress",
		},
		children = {
			{
				class = "TextLabel",
				ref = "label",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(0.7, 0, 0, theme.size.row),

					Font = theme.font.body,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,

					Visible = false,
					Name = "Label",
					Text = "",
				},
			},
			{
				class = "TextLabel",
				ref = "readout",
				props = {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0.3, 0, 0, theme.size.row),

					Font = theme.font.mono,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,

					Visible = false,
					Name = "Readout",
					Text = "0%",
				},
			},
			{
				class = "Frame",
				ref = "rail",
				props = {
					BackgroundColor3 = theme.color.track,
					BackgroundTransparency = theme.transparency.track,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, theme.size.rail),

					ClipsDescendants = true,
					Name = "Rail",
				},
				children = {
					Create.corner(theme.radius.pill),
					{
						class = "Frame",
						ref = "fill",
						props = {
							BackgroundColor3 = theme.color.accent,
							BorderSizePixel = 0,
							Size = UDim2.fromScale(0, 1),
							Name = "Fill",
						},
						children = { Create.corner(theme.radius.pill) },
					},
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

		kind = "progress",
		desired = Vector2.new(0, theme.size.rail),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		labelText = "",
		showValue = false,
		thickness = theme.size.rail,
		indeterminate = false,
		sweep = nil,
		elapsed = 0,
	}

	return setmetatable(fields, Progress) :: any
end

--- Clamped to zero-to-one; anything larger is read as a percentage.
function Progress.setValue(self: Fields & Types.Progress, value: Types.Bindable<number>): Types.Progress
	Node.bind(self, "value", value, function(next: number)
		local raw = tonumber(next) or 0
		local normalised = if raw > 1 then raw / 100 else raw

		self.current = math.clamp(normalised, 0, 1)

		if self.indeterminate then
			return
		end

		Motion.animate(
			self.refs.fill :: Frame,
			{ Size = UDim2.fromScale(self.current, 1) },
			self.app.theme:spec("morph")
		)

		;(self.refs.readout :: TextLabel).Text = `{math.round(self.current * 100)}%`
	end)

	return self
end

function Progress.setLabel(self: Fields & Types.Progress, label: Types.Bindable<string>): Types.Progress
	local text = self.refs.label :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		self.labelText = value

		text.Text = value
		text.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

function Progress.setColor(self: Fields & Types.Progress, color: Types.Bindable<Color3>): Types.Progress
	Node.bind(self, "color", color, function(next: Color3)
		(self.refs.fill :: Frame).BackgroundColor3 = next
	end)

	return self
end

--- Sweeps a chunk along the rail for work of unknown duration.
function Progress.setIndeterminate(self: Fields & Types.Progress, indeterminate: boolean): Types.Progress
	self.indeterminate = indeterminate ~= false

	if self.sweep then
		self.sweep:Disconnect()

		self.sweep = nil
	end

	local fill = self.refs.fill :: Frame

	if not self.indeterminate then
		Motion.set(fill, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(self.current, 1) })

		return self
	end

	self.elapsed = 0

	local connection = RunService.RenderStepped:Connect(function(delta)
		self.elapsed += delta

		--// a third-width chunk crossing the rail every 1.2 seconds
		local phase = (self.elapsed / 1.2) % 1

		fill.Size = UDim2.fromScale(0.33, 1)
		fill.Position = UDim2.fromScale(-0.33 + phase * 1.33, 0)
	end)

	self.sweep = connection
	self.scope:add(connection)

	return self
end

function Progress.setThickness(self: Fields & Types.Progress, thickness: number): Types.Progress
	self.thickness = thickness
	;(self.refs.rail :: Frame).Size = UDim2.new(1, 0, 0, thickness)

	return self:invalidate()
end

function Progress.setShowValue(self: Fields & Types.Progress, shown: boolean): Types.Progress
	self.showValue = shown ~= false
	;(self.refs.readout :: TextLabel).Visible = self.showValue

	return self:invalidate()
end

function Progress.measure(self: Fields & Types.Progress, available: Vector2): Vector2
	local theme = self.app.theme
	local header = if self.labelText ~= "" or self.showValue then theme.size.row else 0

	local natural = math.max(160, self.app.measure:width(self.labelText, theme.text.xs, theme.font.body) + 60)
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), header + self.thickness)
	self.measured = true

	return self.desired
end

Element.install(Progress)

return Progress
