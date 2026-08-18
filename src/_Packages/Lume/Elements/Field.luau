--!strict

--- A text input: optional leading icon, optional prefix, placeholder, and a
--- ghosted completion hint that sits directly after what you have typed.
---
--- The hint is positioned by measuring the current text, which is the same
--- trick the console command bar uses — it is what makes inline autocomplete
--- read as part of the input rather than as a separate suggestion.
---
--- Masking renders bullets in a mirror label over a transparent input. Roblox
--- has no native masked field, and this is the closest honest approximation;
--- the caret is not visible while masked.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Element = require(script.Parent.Element)

local Field = {}
Field.__index = Field

export type Fields = Types.NodeFields & Types.ElementFields & {
	--// named `current`, not `value`: a field of that name would shadow the
	--// `value()` method, since raw fields win over the metatable
	current: string,
	placeholderText: string,
	prefixText: string,
	hintText: string,
	iconImage: string,

	font: Enum.Font,
	textSize: number,
	trailingImage: string,
	multiline: boolean,
	masked: boolean,
	maxLength: number,
	clearOnSubmit: boolean,

	focused: boolean,
	valid: boolean,
	validator: ((string) -> (boolean, string?))?,
}

--- Creates a field. Prefer `panel:field(placeholder)`.
function Field.new(app: Types.App): Types.Field
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.surfaceSunken,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,

			Size = UDim2.new(1, 0, 0, theme.size.control),
			ClipsDescendants = true,
			Name = "Field",
		},
		children = {
			Create.corner(theme.radius.sm),
			{
				class = "UIStroke",
				ref = "stroke",
				props = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = theme.color.border,
					Thickness = theme.stroke.hairline,
					Transparency = theme.transparency.border,
				},
			},
			Create.padding(theme.space.sm, 0),
			Create.list(Enum.FillDirection.Horizontal, theme.space.xs, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			{
				class = "ImageLabel",
				ref = "icon",
				props = {
					BackgroundTransparency = 1,
					ImageColor3 = theme.color.textGhost,
					ImageTransparency = theme.transparency.ghost,
					ScaleType = Enum.ScaleType.Fit,

					Size = UDim2.fromOffset(theme.size.icon, theme.size.icon),
					LayoutOrder = 1,
					Visible = false,
					Name = "Icon",
					Image = "",
				},
			},
			{
				class = "TextLabel",
				ref = "prefix",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.control),

					Font = theme.font.mono,
					TextSize = theme.text.md,
					TextColor3 = theme.color.accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,

					LayoutOrder = 2,
					Visible = false,
					Name = "Prefix",
					Text = "",
				},
			},
			{
				class = "ImageLabel",
				ref = "trailing",
				props = {
					BackgroundTransparency = 1,
					ImageColor3 = theme.color.textGhost,
					ImageTransparency = theme.transparency.arrow,
					ScaleType = Enum.ScaleType.Fit,

					Size = UDim2.fromOffset(12, 12),

					--// the root has a UIListLayout, which positions every child
					--// and ignores Position entirely. Without a LayoutOrder past
					--// the input box this lands on the LEFT of the row
					LayoutOrder = 4,

					Visible = false,
					Name = "Trailing",
					Image = "",
					ZIndex = 4,
				},
			},
			{
				class = "Frame",
				ref = "box",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,

					Size = UDim2.new(1, -theme.space.sm, 1, 0),
					LayoutOrder = 3,
					Name = "Box",
				},
				children = {
					{
						class = "TextLabel",
						ref = "placeholder",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),

							Font = theme.font.body,
							TextSize = theme.text.md,
							TextColor3 = theme.color.textGhost,
							TextTransparency = theme.transparency.ghost,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							Name = "Placeholder",
							Text = "",
						},
					},
					{
						class = "TextLabel",
						ref = "hint",
						props = {
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.new(0, 0, 1, 0),

							Font = theme.font.body,
							TextSize = theme.text.md,
							TextColor3 = theme.color.textGhost,
							TextTransparency = theme.transparency.ghost,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							Visible = false,
							Name = "Hint",
							Text = "",
						},
					},
					{
						class = "TextLabel",
						ref = "mask",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),

							Font = theme.font.body,
							TextSize = theme.text.md,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							Visible = false,
							Name = "Mask",
							Text = "",
							ZIndex = 3,
						},
					},
					{
						class = "TextBox",
						ref = "input",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),

							Font = theme.font.body,
							TextSize = theme.text.md,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							ClearTextOnFocus = false,
							MultiLine = false,
							TextWrapped = false,
							PlaceholderText = "",

							Name = "Input",
							Text = "",
							ZIndex = 2,
						},
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

		kind = "field",
		desired = Vector2.new(200, theme.size.control),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		current = "",
		placeholderText = "",
		prefixText = "",
		hintText = "",
		iconImage = "",

		font = theme.font.body,
		textSize = theme.text.md,
		trailingImage = "",
		multiline = false,
		masked = false,
		maxLength = 0,
		clearOnSubmit = false,

		focused = false,
		valid = true,
		validator = nil,
	}

	local field = setmetatable(fields, Field) :: any

	local input = refs.input :: TextBox
	local stroke = refs.stroke :: UIStroke

	local function sync()
		local text = input.Text

		if fields.maxLength > 0 and #text > fields.maxLength then
			text = string.sub(text, 1, fields.maxLength)
			input.Text = text

			return
		end

		fields.current = text

		;(refs.placeholder :: TextLabel).Visible = text == ""

		Field.layoutHint(fields)

		if fields.masked then
			(refs.mask :: TextLabel).Text = string.rep("•", #text)
		end

		if fields.validator then
			local ok, message = fields.validator(text)

			fields.valid = ok

			stroke.Color = if ok then theme.color.border else theme.color.danger

			field:emit("validated", ok, message)
		end

		field:emit("changed", text)
	end

	scope:add(input:GetPropertyChangedSignal("Text"):Connect(sync))

	scope:add(input.Focused:Connect(function()
		fields.focused = true

		app.focus:set(field)

		Motion.animate(
			stroke,
			{ Color = theme.color.accent, Transparency = 0 },
			theme:spec("hover")
		)

		field:emit("focused")
	end))

	scope:add(input.FocusLost:Connect(function(submitted)
		fields.focused = false

		if app.focus:owns(field) then
			app.focus:clear()
		end

		Motion.animate(stroke, {
			Color = if fields.valid then theme.color.border else theme.color.danger,
			Transparency = theme.transparency.border,
		}, theme:spec("hover"))

		if submitted then
			field:emit("submitted", fields.current)

			if fields.clearOnSubmit then
				input.Text = ""
			end
		end

		field:emit("blurred")
	end))

	return field
end

--- Places the ghost hint directly after the typed text.
function Field.layoutHint(self: Fields)
	local hint = self.refs.hint :: TextLabel

	if self.hintText == "" or self.current == "" then
		hint.Visible = self.hintText ~= "" and self.current == ""
		hint.Position = UDim2.fromOffset(0, 0)

		return
	end

	local theme = self.app.theme
	local width = self.app.measure:width(self.current, self.textSize, self.font)

	hint.Position = UDim2.fromOffset(math.ceil(width), 0)
	hint.Visible = true
end

function Field.setText(self: Fields & Types.Field, text: Types.Bindable<string>): Types.Field
	local input = self.refs.input :: TextBox

	Node.bind(self, "text", text, function(next: string)
		input.Text = tostring(next)
	end)

	return self
end

function Field.setPlaceholder(self: Fields & Types.Field, placeholder: Types.Bindable<string>): Types.Field
	local label = self.refs.placeholder :: TextLabel

	Node.bind(self, "placeholder", placeholder, function(next: string)
		local value = tostring(next)

		self.placeholderText = value

		label.Text = value
		label.Visible = self.current == ""

		self:invalidate()
	end)

	return self
end

--- A fixed leading token, drawn in the accent colour. The `>` of a prompt.
function Field.setPrefix(self: Fields & Types.Field, prefix: Types.Bindable<string>): Types.Field
	local label = self.refs.prefix :: TextLabel

	Node.bind(self, "prefix", prefix, function(next: string)
		local value = tostring(next)

		self.prefixText = value

		label.Text = value
		label.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

function Field.setIcon(self: Fields & Types.Field, image: Types.Bindable<string>): Types.Field
	local icon = self.refs.icon :: ImageLabel

	Node.bind(self, "icon", image, function(next: string)
		local value = tostring(next)

		self.iconImage = value

		icon.Image = value
		icon.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

--- The ghosted completion shown after the caret.
function Field.setHint(self: Fields & Types.Field, hint: Types.Bindable<string>): Types.Field
	local label = self.refs.hint :: TextLabel

	Node.bind(self, "hint", hint, function(next: string)
		local value = tostring(next)

		self.hintText = value
		label.Text = value

		Field.layoutHint(self)
	end)

	return self
end

--- Sets the font on the input, placeholder, hint and mask together, so the
--- ghost completion still lines up with the text it follows. A terminal wants
--- `Enum.Font.Code` here.
function Field.setFont(self: Fields & Types.Field, font: Enum.Font): Types.Field
	self.font = font

	for _, key in { "input", "placeholder", "hint", "mask" } do
		local label = self.refs[key]

		if label then
			(label :: any).Font = font
		end
	end

	Field.layoutHint(self)

	return self:invalidate()
end

function Field.setTextSize(self: Fields & Types.Field, size: number): Types.Field
	self.textSize = size

	for _, key in { "input", "placeholder", "hint", "mask", "prefix" } do
		local label = self.refs[key]

		if label then
			(label :: any).TextSize = size
		end
	end

	Field.layoutHint(self)

	return self:invalidate()
end

--- A glyph pinned to the right edge — the console's submit arrow. It floats
--- above the input rather than joining the row, so it does not shift the caret.
function Field.setTrailingIcon(self: Fields & Types.Field, image: Types.Bindable<string>): Types.Field
	local icon = self.refs.trailing :: ImageLabel

	Node.bind(self, "trailing", image, function(next: string)
		local value = tostring(next)

		self.trailingImage = value

		icon.Image = value
		icon.Visible = value ~= ""

		self:invalidate()
	end)

	return self
end

--- Recolours the parts independently. Omitted keys are left alone.
function Field.setColors(self: Fields & Types.Field, colors: { [string]: Color3 }): Types.Field
	local map = {
		text = { "input", "mask" },
		placeholder = { "placeholder" },
		prefix = { "prefix" },
		hint = { "hint" },
		icon = { "icon", "trailing" },
	}

	for key, targets in map do
		local colour = colors[key]

		if not colour then
			continue
		end

		for _, name in targets do
			local instance = self.refs[name]

			if not instance then
				continue
			end

			if instance:IsA("ImageLabel") then
				(instance :: ImageLabel).ImageColor3 = colour
			else
				(instance :: any).TextColor3 = colour
			end
		end
	end

	return self
end

--- The input's own corner radius, independent of the panel's.
function Field.setRadius(self: Fields & Types.Field, radius: number | "pill"): Types.Field
	local corner = self.instance:FindFirstChildOfClass("UICorner")

	if corner then
		corner.CornerRadius = if radius == "pill" then UDim.new(1, 0) else UDim.new(0, radius :: number)
	end

	return self
end

--- The well the text sits in. A console wants this invisible, since the panel
--- behind it already is the surface.
function Field.setSurface(self: Fields & Types.Field, color: Color3, transparency: number): Types.Field
	local root = self.instance :: Frame

	root.BackgroundColor3 = color
	root.BackgroundTransparency = transparency

	return self
end

function Field.setBorder(self: Fields & Types.Field, enabled: boolean): Types.Field
	(self.refs.stroke :: UIStroke).Enabled = enabled ~= false

	return self
end

function Field.setMultiline(self: Fields & Types.Field, multiline: boolean): Types.Field
	local input = self.refs.input :: TextBox

	self.multiline = multiline ~= false

	input.MultiLine = self.multiline
	input.TextWrapped = self.multiline
	input.TextYAlignment = if self.multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center

	return self:invalidate()
end

function Field.setMasked(self: Fields & Types.Field, masked: boolean): Types.Field
	local input = self.refs.input :: TextBox
	local mask = self.refs.mask :: TextLabel

	self.masked = masked ~= false

	input.TextTransparency = if self.masked then 1 else 0
	mask.Visible = self.masked
	mask.Text = string.rep("•", #self.current)

	return self
end

function Field.setMaxLength(self: Fields & Types.Field, length: number): Types.Field
	self.maxLength = math.max(0, length)

	return self
end

function Field.setClearOnSubmit(self: Fields & Types.Field, clear: boolean): Types.Field
	self.clearOnSubmit = clear ~= false

	return self
end

--- Runs on every keystroke. Returning false reddens the border and reports the
--- message on the `validated` event.
function Field.setValidator(self: Fields & Types.Field, validator: (string) -> (boolean, string?)): Types.Field
	self.validator = validator

	return self
end

function Field.onChanged(self: Fields & Types.Field, handler: (string) -> ()): Types.Field
	return self:on("changed", handler)
end

function Field.onSubmitted(self: Fields & Types.Field, handler: (string) -> ()): Types.Field
	return self:on("submitted", handler)
end

function Field.onFocused(self: Fields & Types.Field, handler: () -> ()): Types.Field
	return self:on("focused", handler)
end

function Field.onBlurred(self: Fields & Types.Field, handler: () -> ()): Types.Field
	return self:on("blurred", handler)
end

function Field.focus(self: Fields & Types.Field): Types.Field
	(self.refs.input :: TextBox):CaptureFocus()

	return self
end

function Field.blur(self: Fields & Types.Field): Types.Field
	(self.refs.input :: TextBox):ReleaseFocus()

	return self
end

function Field.value(self: Fields & Types.Field): string
	return self.current
end

function Field.measure(self: Fields & Types.Field, available: Vector2): Vector2
	local theme = self.app.theme

	local height = theme.size.control

	if self.multiline then
		local lines = self.app.measure:text(
			if self.current == "" then self.placeholderText else self.current,
			self.textSize,
			self.font,
			math.max(1, available.X - theme.space.sm * 2)
		)

		height = math.max(theme.size.control, lines.Y + theme.space.sm * 2)
	end

	--// natural width: whatever is in the box (or the placeholder standing in
	--// for it), plus the leading furniture. Growing with what you type is what
	--// makes a command bar widen as you use it
	local shown = if self.current ~= "" then self.current else self.placeholderText
	local content = self.app.measure:width(shown .. self.hintText, self.textSize, self.font)

	if self.iconImage ~= "" then
		content += theme.size.icon + theme.space.xs
	end

	if self.prefixText ~= "" then
		content += self.app.measure:width(self.prefixText, self.textSize, theme.font.mono) + theme.space.xs
	end

	if self.trailingImage ~= "" then
		content += 12 + theme.space.xs
	end

	local natural = math.max(160, content + theme.space.sm * 2 + theme.space.md)
	local width = math.min(natural, math.max(1, available.X - self.margin * 2))

	self.desired = Vector2.new(math.ceil(width), math.ceil(height))
	self.measured = true

	return self.desired
end

--- Sizes the inner box to whatever is left after the icon and prefix.
function Field.commit(self: Fields & Types.Field, inner: Vector2, vertical: boolean, share: number)
	local theme = self.app.theme

	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	local used = theme.space.sm * 2

	if self.iconImage ~= "" then
		used += theme.size.icon + theme.space.xs
	end

	if self.prefixText ~= "" then
		used += self.app.measure:width(self.prefixText, self.textSize, theme.font.mono) + theme.space.xs
	end

	if self.trailingImage ~= "" then
		used += 12 + theme.space.xs
	end

	;(self.refs.box :: Frame).Size = UDim2.new(0, math.max(0, width - used), 1, 0)
end

Element.install(Field)

return Field
