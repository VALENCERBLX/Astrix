--!strict

--- Anchoring, growth direction, and viewport-aware room.
---
--- The trick that keeps a growing panel from sliding around is doing nothing
--- clever at all: set `AnchorPoint` to the edge the panel is stuck to, and
--- Roblox keeps that edge fixed while the size changes. A bottom-anchored
--- panel grows upward for free.
---
--- What *does* need arithmetic is knowing how much room a panel has before it
--- runs into the edge of the screen, which is what `room` answers and what
--- every auto-sizing pass clamps against.
--- @section Layout

local Types = require(script.Parent.Parent.Types)

type Anchor = Types.Anchor
type Edge = Types.Edge

local Placement = {}

--// locals
local ANCHORS: { [string]: Vector2 } = {
	topLeft = Vector2.new(0, 0),
	top = Vector2.new(0.5, 0),
	topRight = Vector2.new(1, 0),
	left = Vector2.new(0, 0.5),
	center = Vector2.new(0.5, 0.5),
	right = Vector2.new(1, 0.5),
	bottomLeft = Vector2.new(0, 1),
	bottom = Vector2.new(0.5, 1),
	bottomRight = Vector2.new(1, 1),
}

--- The AnchorPoint for a named anchor.
function Placement.anchorPoint(anchor: Anchor): Vector2
	return ANCHORS[anchor] or ANCHORS.center
end

--- Screen position for a named anchor, `inset` pixels in from the edges.
--- Pairs with `anchorPoint` for the same name.
function Placement.position(anchor: Anchor, inset: number, offset: Vector2?): UDim2
	local point = Placement.anchorPoint(anchor)
	local shift = offset or Vector2.zero

	local x = point.X
	local y = point.Y

	local offsetX = shift.X + (if x == 0 then inset elseif x == 1 then -inset else 0)
	local offsetY = shift.Y + (if y == 0 then inset elseif y == 1 then -inset else 0)

	return UDim2.new(x, offsetX, y, offsetY)
end

--- Whether a GuiObject is anchored to the top half of its parent, and so grows
--- downward.
function Placement.isTop(instance: GuiObject): boolean
	return instance.AnchorPoint.Y < 0.5
end

--- Which edge a GuiObject is stuck to on each axis.
function Placement.growth(instance: GuiObject): (Edge, Edge)
	local point = instance.AnchorPoint

	local horizontal: Edge = if point.X < 0.5 then "left" elseif point.X > 0.5 then "right" else "left"
	local vertical: Edge = if point.Y < 0.5 then "top" elseif point.Y > 0.5 then "bottom" else "top"

	return horizontal, vertical
end

--- How much room a GuiObject has to grow into before it hits the viewport,
--- given where it sits and which edges it is anchored to.
---
--- A bottom-anchored panel 300px up the screen has 300 minus the inset to grow
--- into. A centred one has twice the smaller of its two gaps.
function Placement.room(instance: GuiObject, viewport: Vector2, inset: number): Vector2
	local point = instance.AnchorPoint
	local absolute = instance.AbsolutePosition
	local size = instance.AbsoluteSize

	--// the anchored edge, in viewport space
	local pinX = absolute.X + size.X * point.X
	local pinY = absolute.Y + size.Y * point.Y

	local roomX: number
	local roomY: number

	if point.X == 0 then
		roomX = viewport.X - pinX - inset
	elseif point.X == 1 then
		roomX = pinX - inset
	else
		roomX = 2 * math.min(pinX, viewport.X - pinX) - inset * 2
	end

	if point.Y == 0 then
		roomY = viewport.Y - pinY - inset
	elseif point.Y == 1 then
		roomY = pinY - inset
	else
		roomY = 2 * math.min(pinY, viewport.Y - pinY) - inset * 2
	end

	return Vector2.new(math.max(0, roomX), math.max(0, roomY))
end

--- Keeps the anchored edge fixed when AnchorPoint cannot do it — used when a
--- panel is positioned by a stack rather than by its own anchor.
function Placement.shift(position: UDim2, anchorPoint: Vector2, delta: Vector2): UDim2
	local x = position.X.Offset - delta.X * (1 - anchorPoint.X)
	local y = position.Y.Offset - delta.Y * (1 - anchorPoint.Y)

	return UDim2.new(position.X.Scale, x, position.Y.Scale, y)
end

--- Centres a size in its parent.
function Placement.center(): (UDim2, Vector2)
	return UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
end

--- Positions `size` next to `target` on `side`, flipping to the opposite side
--- when there is not enough room, and sliding along the cross axis to stay on
--- screen. This is popover, dropdown and tooltip placement in one function.
---
--- Coordinates come back relative to `layer`, so the result drops straight
--- into a child of that layer.
function Placement.attach(
	layer: GuiObject,
	target: GuiObject,
	size: Vector2,
	side: Edge,
	gap: number,
	viewport: Vector2,
	inset: number
): (UDim2, Vector2)
	local origin = layer.AbsolutePosition

	local targetPosition = target.AbsolutePosition
	local targetSize = target.AbsoluteSize

	local left = targetPosition.X
	local top = targetPosition.Y
	local right = left + targetSize.X
	local bottom = top + targetSize.Y

	local resolved = side

	--// flip when the preferred side would run off the screen and the opposite
	--// side has more room
	if side == "bottom" and bottom + gap + size.Y > viewport.Y - inset and top - gap - size.Y > inset then
		resolved = "top"
	elseif side == "top" and top - gap - size.Y < inset and bottom + gap + size.Y < viewport.Y - inset then
		resolved = "bottom"
	elseif side == "right" and right + gap + size.X > viewport.X - inset and left - gap - size.X > inset then
		resolved = "left"
	elseif side == "left" and left - gap - size.X < inset and right + gap + size.X < viewport.X - inset then
		resolved = "right"
	end

	local x: number
	local y: number

	if resolved == "bottom" then
		x, y = left, bottom + gap
	elseif resolved == "top" then
		x, y = left, top - gap - size.Y
	elseif resolved == "right" then
		x, y = right + gap, top
	else
		x, y = left - gap - size.X, top
	end

	--// slide along the cross axis to stay inside the viewport
	x = math.clamp(x, inset, math.max(inset, viewport.X - inset - size.X))
	y = math.clamp(y, inset, math.max(inset, viewport.Y - inset - size.Y))

	return UDim2.fromOffset(x - origin.X, y - origin.Y), Vector2.zero
end

--- Pushes a position back inside the viewport, accounting for AnchorPoint.
function Placement.clamp(
	position: UDim2,
	anchorPoint: Vector2,
	size: Vector2,
	viewport: Vector2,
	inset: number
): UDim2
	local pinX = viewport.X * position.X.Scale + position.X.Offset
	local pinY = viewport.Y * position.Y.Scale + position.Y.Offset

	local left = pinX - size.X * anchorPoint.X
	local top = pinY - size.Y * anchorPoint.Y

	local clampedLeft = math.clamp(left, inset, math.max(inset, viewport.X - inset - size.X))
	local clampedTop = math.clamp(top, inset, math.max(inset, viewport.Y - inset - size.Y))

	return UDim2.new(
		position.X.Scale,
		position.X.Offset + (clampedLeft - left),
		position.Y.Scale,
		position.Y.Offset + (clampedTop - top)
	)
end

return Placement
