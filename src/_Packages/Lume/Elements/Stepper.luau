--!strict

--- A number with a minus and a plus either side of it, and a field in the
--- middle you can type into.
---
--- The slider's sibling, for the cases a slider is wrong for: a quantity where
--- every value matters and the range is short, or one where the range has no
--- meaningful end. Dragging a slider to exactly 7 is fiddly; pressing plus
--- seven times is not.
---
--- Holding a button repeats, and accelerates — slowly at first so a hold meant
--- as a click does not overshoot, then faster, because holding is what you do
--- when the number is far away.
---
--- `changed` fires on every step; `committed` fires when the interaction ends —
--- the button released, the field submitted. A held repeat is one commit, not
--- forty.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Element = require(script.Parent.Element)

local Stepper = {}
Stepper.__index = Stepper

export type Fields = Types.NodeFields & Types.ElementFields & {
	current: number,
	minimum: number,
	maximum: number,
	step: number,

	labelText: string,
	wrap: boolean,
	typing: boolean,
	holding: number?,
	formatter: ((number) -> string)?,
}

--// a hold waits this long before it starts repeating, so a slow click is
--// still one step
local DELAY = 0.4
local FAST = 0.06
local SLOW = 0.18
--// how long the repeat takes to reach full speed
local RAMP = 1.2

--// locals
local function button(theme: Types.Theme, name: string, glyph: string, order: number): any
	return {
		class = "TextButton",
		ref = name,
		props = {
			BackgroundColor3 = theme.color.surfaceHover,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			AutoButtonColor = false,

			Size = UDim2.fromOffset(theme.size.control, theme.size.control),
			LayoutOrder = order,

			Font = theme.font.medium,
			TextSize = theme.text.md,
			TextColor3 = theme.color.text,

			Name = name,
			Text = glyph,
		},
		children = { Create.corner(theme.radius.sm) },
	}
end

--- Creates a stepper. Prefer `panel:stepper(label)`.
function Stepper.new(app: Types.App): Types.Stepper
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.size.control),
			Name = "Stepper",
		},
		children = {
			Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
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
				ref = "spacer",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -(theme.size.control * 2 + 64), 0, 1),
					LayoutOrder = 2,
					Name = "Gap",
				},
			},
			button(theme, "minus", "−", 3),
			{
				class = "TextBox",
				ref = "value",
				props = {
					BackgroundColor3 = theme.color.surfaceSunken,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,

					Size = UDim2.fromOffset(56, theme.size.control),
					LayoutOrder = 4,

					Font = theme.font.mono,
					TextSize = theme.text.sm,
					TextColor3 = theme.color.text,

					Name = "Value",
					Text = "0",
				},
				children = { Create.corner(theme.radius.sm) },
			},
			button(theme, "plus", "+", 5),
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

		kind = "stepper",
		desired = Vector2.new(0, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = 0,
		minimum = 0,
		maximum = 10,
		step = 1,

		labelText = "",
		wrap = false,
		typing = false,
		holding = nil,
		formatter = nil,
	}

	local stepper = setmetatable(fields, Stepper) :: any

	local box = refs.value :: TextBox

	local function press(direction: number, target: TextButton)
		return function()
			if not fields.enabled then
				return
			end

			Stepper.bump(stepper, direction)

			--// a click that never becomes a hold still has to commit, and the
			--// release handler below is what does it. This token is how a
			--// release tells its own hold apart from one that already ended
			local token = os.clock()

			fields.holding = token

			Motion.animate(target, { BackgroundTransparency = 0.7 }, theme:spec("hover"))

			task.spawn(function()
				task.wait(DELAY)

				local started = os.clock()

				while fields.holding == token and not fields.dead do
					Stepper.bump(stepper, direction)

					--// ease from slow to fast over the ramp, so a hold that
					--// overshoots by one is hard to do
					local through = math.clamp((os.clock() - started) / RAMP, 0, 1)

					task.wait(SLOW + (FAST - SLOW) * through)
				end
			end)
		end
	end

	local function release(target: TextButton)
		return function()
			if fields.holding == nil then
				return
			end

			fields.holding = nil

			Motion.animate(target, { BackgroundTransparency = 0.85 }, theme:spec("hover"))

			stepper:emit("committed", fields.current)
		end
	end

	local minus = refs.minus :: TextButton
	local plus = refs.plus :: TextButton

	scope:add(minus.MouseButton1Down:Connect(press(-1, minus)))
	scope:add(plus.MouseButton1Down:Connect(press(1, plus)))
	scope:add(minus.MouseButton1Up:Connect(release(minus)))
	scope:add(plus.MouseButton1Up:Connect(release(plus)))
	--// the pointer leaving mid-hold has to end it too, or the number runs away
	--// after the button is nowhere near it
	scope:add(minus.MouseLeave:Connect(release(minus)))
	scope:add(plus.MouseLeave:Connect(release(plus)))

	for _, target in { minus, plus } do
		Hover.attach(scope, target, function(hovering)
			if not fields.enabled or fields.holding then
				return
			end

			Motion.animate(
				target,
				{ BackgroundTransparency = if hovering then 0.78 else 0.85 },
				theme:spec("hover")
			)
		end)
	end

	scope:add(box.Focused:Connect(function()
		fields.typing = true
	end))

	scope:add(box.FocusLost:Connect(function()
		fields.typing = false

		local typed = tonumber((box.Text:gsub("[^%-%.%d]", "")))

		if typed then
			Stepper.commitValue(stepper, typed)

			stepper:emit("committed", fields.current)
		end

		--// whether it parsed or not, the field goes back to showing the number
		Stepper.paint(fields)
	end))

	Stepper.paint(fields)

	return stepper
end

--- Clamps to the range and snaps to the step.
function Stepper.quantise(self: Fields, value: number): number
	if self.step > 0 then
		value = self.minimum + math.round((value - self.minimum) / self.step) * self.step

		--// rounding in floating point leaves 0.30000000000000004 lying about,
		--// and it shows up the moment anyone formats it
		value = math.round(value * 1e6) / 1e6
	end

	if self.wrap then
		local span = self.maximum - self.minimum + self.step

		if span > 0 then
			return self.minimum + (value - self.minimum) % span
		end
	end

	return math.clamp(value, self.minimum, self.maximum)
end

function Stepper.paint(self: Fields)
	local box = self.refs.value :: TextBox
	local minus = self.refs.minus :: TextButton
	local plus = self.refs.plus :: TextButton

	if not self.typing then
		box.Text = if self.formatter
			then self.formatter(self.current)
			else string.format(if self.step % 1 == 0 then "%d" else "%g", self.current)
	end

	--// an end of the range that cannot be moved past says so, unless wrapping
	--// means there is no end
	local theme = self.app.theme
	local atFloor = not self.wrap and self.current <= self.minimum
	local atCeiling = not self.wrap and self.current >= self.maximum

	minus.TextTransparency = if atFloor then theme.transparency.disabled else 0
	plus.TextTransparency = if atCeiling then theme.transparency.disabled else 0
end

--- Sets the value, painting and firing `changed` if it actually moved.
function Stepper.commitValue(self: Fields & Types.Stepper, value: number)
	local next = Stepper.quantise(self, value)

	if next == self.current then
		return
	end

	self.current = next

	Stepper.paint(self)

	self:emit("changed", next)
end

--- Moves by whole steps. `bump(-1)` is one press of minus.
function Stepper.bump(self: Fields & Types.Stepper, steps: number): Types.Stepper
	Stepper.commitValue(self, self.current + self.step * steps)

	return self
end

function Stepper.setRange(self: Fields & Types.Stepper, minimum: number, maximum: number): Types.Stepper
	self.minimum = minimum
	self.maximum = math.max(minimum, maximum)

	Stepper.commitValue(self, self.current)
	Stepper.paint(self)

	return self
end

function Stepper.setStep(self: Fields & Types.Stepper, step: number): Types.Stepper
	self.step = math.max(0, step)

	Stepper.paint(self)

	return self
end

function Stepper.setValue(self: Fields & Types.Stepper, value: Types.Bindable<number>): Types.Stepper
	Node.bind(self, "value", value, function(next: number)
		self.current = Stepper.quantise(self, next)

		Stepper.paint(self)
	end)

	return self
end

--- Past the top comes back to the bottom. For anything cyclic — a team, an
--- hour of the day — where the ends are neighbours rather than walls.
function Stepper.setWrap(self: Fields & Types.Stepper, wrap: boolean?): Types.Stepper
	self.wrap = wrap ~= false

	Stepper.paint(self)

	return self
end

function Stepper.setLabel(self: Fields & Types.Stepper, label: Types.Bindable<string>): Types.Stepper
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		text.Visible = self.labelText ~= ""

		self:invalidate()
	end)

	return self
end

--- How the number is written. `"%d kg"`, an hour of the day, a word per value.
function Stepper.setFormat(self: Fields & Types.Stepper, format: (number) -> string): Types.Stepper
	self.formatter = format

	Stepper.paint(self)

	return self
end

function Stepper.onChanged(self: Fields & Types.Stepper, handler: (number) -> ()): Types.Stepper
	return self:on("changed", handler)
end

function Stepper.onCommitted(self: Fields & Types.Stepper, handler: (number) -> ()): Types.Stepper
	return self:on("committed", handler)
end

function Stepper.value(self: Fields & Types.Stepper): number
	return self.current
end

function Stepper.measure(self: Fields & Types.Stepper, available: Vector2): Vector2
	local theme = self.app.theme

	local controls = theme.size.control * 2 + 56 + theme.space.xs * 2
	local natural = controls

	if self.labelText ~= "" then
		natural += self.app.measure:width(self.labelText, theme.text.sm, theme.font.body) + theme.space.md
	end

	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), theme.size.control)
	self.measured = true

	return self.desired
end

Element.install(Stepper)

return Stepper
