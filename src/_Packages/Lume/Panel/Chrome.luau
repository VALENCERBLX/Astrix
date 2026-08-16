--!strict

--- The panel shell: root surface, corner, border, titlebar, content region and
--- shadow.
---
--- The root is a CanvasGroup so opening and closing is one `GroupTransparency`
--- animation instead of a fade per descendant — which is also why children
--- never have to opt into the panel's own fade.
---
--- The shadow is a *sibling* of the root, not a child. A child would be inside
--- the group's render target and clipped by its corner radius, which is the
--- opposite of what a shadow is for.
--- @section Panel

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)

local Chrome = {}

export type Refs = {
	root: CanvasGroup,
	corner: UICorner,
	stroke: UIStroke,

	titlebar: Frame,
	titleIcon: ImageLabel,
	titleText: TextLabel,
	subtitle: TextLabel,
	close: TextButton,

	content: ScrollingFrame,
	padding: UIPadding,
	layout: UIListLayout,
}

--- Builds the shell and returns the root plus every ref by name.
function Chrome.build(app: Types.App, scope: Types.Scope, titleHeight: number): (CanvasGroup, Types.Refs)
	local theme = app.theme

	local root, refs = Create.tree(scope, {
		class = "CanvasGroup",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.surface,
			BackgroundTransparency = theme.transparency.surface,
			BorderSizePixel = 0,

			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(320, theme.size.control),

			GroupTransparency = 0,
			ClipsDescendants = true,
			Name = "Panel",
			Visible = false,
		},
		children = {
			--// both carry refs: the panel animates the corner every layout pass
			--// (the pill-to-rectangle morph) and toggles the stroke on preset
			{
				class = "UICorner",
				ref = "corner",
				props = { CornerRadius = UDim.new(0, theme.radius.md) },
			},
			{
				class = "UIStroke",
				ref = "stroke",
				props = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					LineJoinMode = Enum.LineJoinMode.Round,
					Color = theme.color.border,
					Thickness = theme.stroke.hairline,
					Transparency = theme.transparency.border,
				},
			},

			{
				class = "Frame",
				ref = "titlebar",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, titleHeight),
					Name = "Titlebar",
					Visible = false,
					ZIndex = 3,
				},
				children = {
					Create.padding(theme.space.md, 0),
					Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					{
						class = "ImageLabel",
						ref = "titleIcon",
						props = {
							BackgroundTransparency = 1,
							ImageTransparency = theme.transparency.muted,
							ImageColor3 = theme.color.textMuted,
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
						ref = "titleText",
						props = {
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, titleHeight),

							Font = theme.font.medium,
							TextSize = theme.text.sm,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							LayoutOrder = 2,
							Name = "Title",
							Text = "",
						},
					},
					{
						class = "TextLabel",
						ref = "subtitle",
						props = {
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, titleHeight),

							Font = theme.font.body,
							TextSize = theme.text.xs,
							TextColor3 = theme.color.textGhost,
							TextTransparency = theme.transparency.ghost,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,

							LayoutOrder = 3,
							Visible = false,
							Name = "Subtitle",
							Text = "",
						},
					},
				},
			},

			{
				class = "TextButton",
				ref = "close",
				props = {
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 0),
					Size = UDim2.fromOffset(titleHeight, titleHeight),

					Font = theme.font.medium,
					TextSize = theme.text.md,
					TextColor3 = theme.color.textMuted,
					TextTransparency = theme.transparency.muted,

					Visible = false,
					Name = "Close",
					Text = "×",
					ZIndex = 5,
				},
			},

			{
				class = "ScrollingFrame",
				ref = "content",
				props = {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,

					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 1, 0),

					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarImageColor3 = theme.color.borderStrong,
					ScrollBarImageTransparency = 1,
					ScrollBarThickness = 0,
					ScrollingEnabled = false,
					CanvasSize = UDim2.fromOffset(0, 0),

					ClipsDescendants = true,
					Name = "Content",
					ZIndex = 2,
				},
				children = {
					{
						class = "UIPadding",
						ref = "padding",
						props = {
							PaddingLeft = UDim.new(0, theme.space.md),
							PaddingRight = UDim.new(0, theme.space.md),
							PaddingTop = UDim.new(0, theme.space.md),
							PaddingBottom = UDim.new(0, theme.space.md),
						},
					},
					{
						class = "UIListLayout",
						ref = "layout",
						props = {
							SortOrder = Enum.SortOrder.LayoutOrder,
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, theme.space.sm),
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						},
					},
				},
			},
		},
	})

	return root :: CanvasGroup, refs
end

--- Creates the shadow, or nothing at all when the theme has no shadow image.
--- Shipping without a baked asset id is deliberate; point `theme.shadow.image`
--- at your own nine-sliced soft shadow and every panel picks it up.
function Chrome.shadow(app: Types.App, scope: Types.Scope): ImageLabel?
	local shadow = app.theme.shadow

	if not shadow.image or shadow.image == "" then
		return nil
	end

	local instance = Instance.new("ImageLabel")

	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0

	instance.Image = shadow.image
	instance.ImageColor3 = shadow.color
	instance.ImageTransparency = shadow.transparency

	instance.ScaleType = Enum.ScaleType.Slice
	instance.SliceCenter = shadow.slice
	instance.SliceScale = 1

	instance.Name = "Shadow"
	instance.ZIndex = 0

	scope:add(instance)

	return instance
end

--- Glues a shadow to its panel. Called whenever the panel's geometry changes.
function Chrome.track(shadow: ImageLabel?, target: GuiObject, spread: number, offset: Vector2)
	if not shadow then
		return
	end

	local position = target.Position
	local anchor = target.AnchorPoint

	shadow.AnchorPoint = anchor
	shadow.Visible = target.Visible

	shadow.Size = UDim2.new(
		target.Size.X.Scale,
		target.Size.X.Offset + spread * 2,
		target.Size.Y.Scale,
		target.Size.Y.Offset + spread * 2
	)

	--// growing by `spread` on all four sides moves the anchor point by
	--// spread * (2a - 1): nothing when centred, a full spread when edge-anchored
	shadow.Position = UDim2.new(
		position.X.Scale,
		position.X.Offset + offset.X + spread * (2 * anchor.X - 1),
		position.Y.Scale,
		position.Y.Offset + offset.Y + spread * (2 * anchor.Y - 1)
	)
end

return Chrome
