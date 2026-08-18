--!strict

--- Panels laid out in sequence from a shared anchor, each one pushed along by
--- the size of the ones before it.
---
--- Because every member keeps its own AnchorPoint, a bottom-anchored stack
--- grows upward and the bottom member never moves — new panels appear above
--- the one you were already looking at rather than shoving it off the screen.
--- @section Layout

local Types = require(script.Parent.Parent.Types)
local Placement = require(script.Parent.Placement)

type Panel = Types.Panel
type Anchor = Types.Anchor
type MotionSpec = Types.MotionSpec

local Stack = {}
Stack.__index = Stack

export type Fields = {
	app: Types.App,
	anchor: Anchor,
	axis: Types.Axis,
	gap: number,
	origin: UDim2?,
	members: { Panel },
	dead: boolean,
}

--// locals
--- Which way members march away from the anchor.
local function direction(anchor: Anchor): Vector2
	if anchor == "bottom" or anchor == "bottomLeft" or anchor == "bottomRight" then
		return Vector2.new(0, -1)
	elseif anchor == "top" or anchor == "topLeft" or anchor == "topRight" then
		return Vector2.new(0, 1)
	elseif anchor == "right" then
		return Vector2.new(-1, 0)
	elseif anchor == "left" then
		return Vector2.new(1, 0)
	end

	return Vector2.new(0, 1)
end

--- Creates a stack anchored to an edge.
function Stack.new(app: Types.App, anchor: Anchor?): Types.Stack
	local resolved: Anchor = anchor or "bottom"

	local self: Fields = {
		app = app,
		anchor = resolved,
		axis = if resolved == "left" or resolved == "right" then "horizontal" else "vertical",
		gap = app.theme.space.sm,
		origin = nil,
		members = {},
		dead = false,
	}

	return setmetatable(self, Stack) :: any
end

--- Adds a panel to the end of the stack and reflows.
function Stack.add(self: Fields & Types.Stack, panel: Panel): Types.Stack
	if table.find(self.members, panel) then
		return self
	end

	table.insert(self.members, panel)

	panel.stack = self :: any
	panel.anchor = self.anchor
	panel.instance.AnchorPoint = Placement.anchorPoint(self.anchor)

	Stack.reflow(self)

	return self
end

--- Removes a panel and reflows the rest.
function Stack.remove(self: Fields & Types.Stack, panel: Panel): Types.Stack
	local index = table.find(self.members, panel)

	if not index then
		return self
	end

	table.remove(self.members, index)

	panel.stack = nil

	Stack.reflow(self)

	return self
end

function Stack.setGap(self: Fields & Types.Stack, gap: number): Types.Stack
	self.gap = gap

	return Stack.reflow(self)
end

--- Overrides where the first member sits. Defaults to the anchor's own
--- position with the app's edge inset.
function Stack.setOrigin(self: Fields & Types.Stack, position: UDim2): Types.Stack
	self.origin = position

	return Stack.reflow(self)
end

--- Repositions every member. Cheap enough to call from any panel resize.
function Stack.reflow(self: Fields & Types.Stack, spec: (MotionSpec | string)?): Types.Stack
	if self.dead then
		return self
	end

	local step = direction(self.anchor)
	local vertical = self.axis == "vertical"

	local origin = self.origin or Placement.position(self.anchor, self.app.theme.space.lg)
	local cursor = 0

	for _, panel in self.members do
		if not panel.instance.Visible then
			continue
		end

		local position = UDim2.new(
			origin.X.Scale,
			origin.X.Offset + step.X * cursor,
			origin.Y.Scale,
			origin.Y.Offset + step.Y * cursor
		)

		panel.settled = position
		panel:moveTo(position)

		--// step by the panel's *target* size, not its current one. AbsoluteSize
		--// is zero on the frame a panel is added — Roblox has not laid it out
		--// yet — and mid-animation while it grows into place, so stepping by it
		--// stacks members on top of each other in both cases. `desired` is the
		--// settled layout size, so positions are final immediately and the
		--// panels animate into them.
		local target = panel.desired
		local absolute = panel.instance.AbsoluteSize

		if target.X <= 0 and target.Y <= 0 then
			target = absolute
		end

		cursor += (if vertical then target.Y else target.X) + self.gap
	end

	return self
end

function Stack.destroy(self: Fields & Types.Stack)
	self.dead = true

	for _, panel in self.members do
		panel.stack = nil
	end

	table.clear(self.members)
end

return Stack
