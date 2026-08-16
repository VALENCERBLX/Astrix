--!strict

--- Dragging, one-to-one with the pointer.
---
--- Movement is assigned straight to `Position` rather than routed through the
--- motion driver: a dragged panel that lags its cursor by even two frames feels
--- broken. The spring only comes back on release, when the panel settles into
--- the viewport if the throw took it past the edge.
--- @section Input

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Placement = require(script.Parent.Parent.Layout.Placement)
local Signal = require(script.Parent.Parent.Core.Signal)
local Motion = require(script.Parent.Parent.Motion)

type Scope = Types.Scope

local Drag = {}
Drag.__index = Drag

export type Options = {
	handles: { GuiObject }?,
	scope: Scope?,
	bounds: boolean?,
	inset: number?,
	axis: ("x" | "y")?,
}

export type Fields = {
	app: Types.App,
	target: GuiObject,
	scopeRef: Scope,

	moved: Types.Signal,
	started: Types.Signal,
	ended: Types.Signal,

	active: boolean,
	enabled: boolean,

	origin: Vector2,
	anchor: UDim2,
	bounded: boolean,
	inset: number,
	axis: ("x" | "y")?,
}

local DRAG_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local MOVE_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.Touch] = true,
}

--- Makes `target` draggable by the given handles, or by itself if none are
--- given.
function Drag.attach(app: Types.App, target: GuiObject, options: Options?): Types.DragHandle
	local settings = options or {}
	local scope = (settings.scope or app.scope):child()

	local self: Fields = {
		app = app,
		target = target,
		scopeRef = scope,

		moved = Signal.new(),
		started = Signal.new(),
		ended = Signal.new(),

		active = false,
		enabled = true,

		origin = Vector2.zero,
		anchor = target.Position,
		bounded = settings.bounds ~= false,
		inset = settings.inset or app.theme.space.sm,
		axis = settings.axis,
	}

	local handle = setmetatable(self, Drag) :: any

	scope:add(self.moved)
	scope:add(self.started)
	scope:add(self.ended)

	local function begin(input: InputObject)
		if not self.enabled or self.active then
			return
		end

		self.active = true
		self.origin = Vector2.new(input.Position.X, input.Position.Y)
		self.anchor = target.Position

		--// a panel mid-flight would otherwise keep animating out from under
		--// the cursor
		Motion.stop(target, "Position")

		self.started:fire(self.anchor)
	end

	local function move(input: InputObject)
		if not self.active then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)
		local delta = point - self.origin

		if self.axis == "x" then
			delta = Vector2.new(delta.X, 0)
		elseif self.axis == "y" then
			delta = Vector2.new(0, delta.Y)
		end

		local next = UDim2.new(
			self.anchor.X.Scale,
			self.anchor.X.Offset + delta.X,
			self.anchor.Y.Scale,
			self.anchor.Y.Offset + delta.Y
		)

		target.Position = next

		self.moved:fire(next)
	end

	local function finish()
		if not self.active then
			return
		end

		self.active = false

		local settled = target.Position

		if self.bounded then
			settled = Placement.clamp(
				target.Position,
				target.AnchorPoint,
				target.AbsoluteSize,
				app:viewport(),
				self.inset
			)

			if settled ~= target.Position then
				Motion.animate(target, { Position = settled }, app.theme:spec("drag"))
			end
		end

		self.ended:fire(settled)
	end

	for _, region in settings.handles or { target } do
		scope:add(region.InputBegan:Connect(function(input)
			if DRAG_INPUTS[input.UserInputType] then
				begin(input)
			end
		end))
	end

	scope:add(UserInputService.InputChanged:Connect(function(input)
		if MOVE_INPUTS[input.UserInputType] then
			move(input)
		end
	end))

	scope:add(UserInputService.InputEnded:Connect(function(input)
		if DRAG_INPUTS[input.UserInputType] then
			finish()
		end
	end))

	scope:add(function()
		self.active = false
	end)

	return handle
end

--- Whether a drag is in progress.
function Drag.dragging(self: Fields & Types.DragHandle): boolean
	return self.active
end

function Drag.setEnabled(self: Fields & Types.DragHandle, enabled: boolean)
	self.enabled = enabled

	if not enabled then
		self.active = false
	end
end

--- Resyncs the drag origin after the panel was moved by something else (a
--- stack reflow, a viewport resize). Without this the next drag would snap
--- back to where the panel used to be.
function Drag.setPosition(self: Fields & Types.DragHandle, position: UDim2)
	self.anchor = position
end

function Drag.destroy(self: Fields & Types.DragHandle)
	self.active = false
	self.enabled = false

	if self.scopeRef then
		self.scopeRef:destroy()
	end
end

return Drag
