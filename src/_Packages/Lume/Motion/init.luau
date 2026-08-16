--!strict

--- The one motion driver. Every animated property in Lume goes through here,
--- which is what keeps a panel's shell, its shadow and its children from
--- drifting out of sync.
---
--- Two paths, chosen by the spec:
---
--- * **Tween** (`duration` + `easing`) — handed to TweenService. Cheap, no
---   per-frame Lua, correct for one-shot fades and presses.
--- * **Spring** (`stiffness` + `damping`) — stepped here, one channel per
---   instance-property. Retargeting keeps velocity, so a size that changes
---   three times while the panel is still moving bends smoothly instead of
---   restarting. Anything content-driven should be a spring.
---
--- Starting a tween on a property cancels its spring and vice versa, so the
--- two paths can never fight over the same value.
--- @section Motion

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Core.Signal)
local Easing = require(script.Easing)
local Spring = require(script.Spring)

type MotionSpec = Types.MotionSpec

local Motion = {}

--// locals
type Channel = {
	instance: Instance,
	property: string,
	kind: string,
	springs: { Spring.Spring },
	target: any,
	owner: any,
}

type AnimationFields = {
	completed: Types.Signal,
	channels: { Channel },
	pending: number,
	clean: boolean,
	done: boolean,
	tween: Tween?,
	instance: Instance?,
	goals: { [string]: any }?,
}

local Animation = {}
Animation.__index = Animation

--// registry: instance -> property -> channel
local live: { [Instance]: { [string]: Channel } } = {}
local watched: { [Instance]: boolean } = {}

local stepping: RBXScriptConnection? = nil
local channelCount = 0

local function decompose(value: any): ({ number }?, string)
	local kind = typeof(value)

	if kind == "number" then
		return { value }, kind
	elseif kind == "UDim" then
		return { value.Scale, value.Offset }, kind
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }, kind
	elseif kind == "Vector2" then
		return { value.X, value.Y }, kind
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }, kind
	elseif kind == "Color3" then
		return { value.R, value.G, value.B }, kind
	elseif kind == "Rect" then
		return { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }, kind
	end

	return nil, kind
end

local function compose(kind: string, parts: { number }): any
	if kind == "number" then
		return parts[1]
	elseif kind == "UDim" then
		return UDim.new(parts[1], parts[2])
	elseif kind == "UDim2" then
		return UDim2.new(parts[1], parts[2], parts[3], parts[4])
	elseif kind == "Vector2" then
		return Vector2.new(parts[1], parts[2])
	elseif kind == "Vector3" then
		return Vector3.new(parts[1], parts[2], parts[3])
	elseif kind == "Color3" then
		return Color3.new(math.clamp(parts[1], 0, 1), math.clamp(parts[2], 0, 1), math.clamp(parts[3], 0, 1))
	elseif kind == "Rect" then
		return Rect.new(parts[1], parts[2], parts[3], parts[4])
	end

	return nil
end

local function assign(instance: Instance, property: string, value: any)
	local ok, err = pcall(function()
		(instance :: any)[property] = value
	end)

	if not ok then
		warn(`[Lume] motion could not set {instance.ClassName}.{property}: {err}`)
	end
end

local function read(instance: Instance, property: string): any
	local ok, value = pcall(function()
		return (instance :: any)[property]
	end)

	return if ok then value else nil
end

local function drop(channel: Channel)
	local properties = live[channel.instance]

	if not properties then
		return
	end

	if properties[channel.property] == channel then
		properties[channel.property] = nil
		channelCount -= 1
	end

	if next(properties) == nil then
		live[channel.instance] = nil
	end
end

local function release(channel: Channel, finished: boolean)
	local owner = channel.owner

	channel.owner = nil

	if owner then
		Animation.resolve(owner, channel, finished)
	end
end

local function step(delta: number)
	for instance, properties in live do
		for property, channel in properties do
			local parts = table.create(#channel.springs)
			local settled = true

			for index, spring in channel.springs do
				spring:step(delta)

				if not spring:settled() then
					settled = false
				end

				parts[index] = spring.position
			end

			if settled then
				assign(instance, property, channel.target)
				drop(channel)
				release(channel, true)
			else
				assign(instance, property, compose(channel.kind, parts))
			end
		end
	end

	if channelCount <= 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function ensureStepping()
	if stepping then
		return
	end

	local signal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

	stepping = signal:Connect(step)
end

--- Drops every channel on an instance the moment it is destroyed, so a torn
--- down panel cannot keep the stepper alive.
local function watch(instance: Instance)
	if watched[instance] then
		return
	end

	watched[instance] = true

	instance.Destroying:Connect(function()
		watched[instance] = nil

		local properties = live[instance]

		if not properties then
			return
		end

		for _, channel in properties do
			channelCount -= 1
			release(channel, false)
		end

		live[instance] = nil
	end)
end

--// animation
local function newAnimation(): AnimationFields & Types.Animation
	local self: AnimationFields = {
		completed = Signal.new(),
		channels = {},
		pending = 0,
		clean = true,
		done = false,
		tween = nil,
		instance = nil,
		goals = nil,
	}

	return setmetatable(self, Animation) :: any
end

local function finishAnimation(self: AnimationFields & Types.Animation, finished: boolean)
	if self.done then
		return
	end

	self.done = true

	self.completed:fire(finished)
end

function Animation.resolve(self: AnimationFields & Types.Animation, _channel: Channel, finished: boolean)
	if not finished then
		self.clean = false
	end

	self.pending -= 1

	if self.pending <= 0 then
		finishAnimation(self, self.clean)
	end
end

--- Whether the animation is still running.
function Animation.active(self: AnimationFields & Types.Animation): boolean
	return not self.done
end

--- Stops where it is. `completed` fires with `false`.
function Animation.cancel(self: AnimationFields & Types.Animation)
	if self.done then
		return
	end

	if self.tween then
		self.tween:Cancel()
	end

	for _, channel in self.channels do
		if channel.owner == self then
			channel.owner = nil
			drop(channel)
		end
	end

	self.clean = false

	finishAnimation(self, false)
end

--- Jumps straight to the target. `completed` fires with `true`.
function Animation.finish(self: AnimationFields & Types.Animation)
	if self.done then
		return
	end

	if self.tween then
		self.tween:Cancel()
	end

	for _, channel in self.channels do
		if channel.owner == self then
			channel.owner = nil

			assign(channel.instance, channel.property, channel.target)
			drop(channel)
		end
	end

	if self.instance and self.goals then
		for property, value in self.goals do
			assign(self.instance, property, value)
		end
	end

	finishAnimation(self, true)
end

--// public api
--- Stops motion on one property, or on every property of an instance.
function Motion.stop(instance: Instance, property: string?)
	local properties = live[instance]

	if not properties then
		return
	end

	if property then
		local channel = properties[property]

		if channel then
			drop(channel)
			release(channel, false)
		end

		return
	end

	for _, channel in properties do
		drop(channel)
		release(channel, false)
	end
end

--- Assigns properties instantly, cancelling any motion on them first.
function Motion.set(instance: Instance, props: { [string]: any })
	for property, value in props do
		Motion.stop(instance, property)
		assign(instance, property, value)
	end
end

--- Animates `props` toward their targets. The spec decides tween or spring.
function Motion.animate(instance: Instance, props: { [string]: any }, spec: MotionSpec): Types.Animation
	local animation = newAnimation()

	if spec.stiffness then
		local stiffness = spec.stiffness
		local damping = spec.damping or (2 * math.sqrt(stiffness))

		watch(instance)

		local properties = live[instance]

		if not properties then
			properties = {}
			live[instance] = properties
		end

		for property, target in props do
			local parts, kind = decompose(target)

			if not parts then
				--// not a springable datatype (an enum, a string, a boolean);
				--// there is no meaningful midpoint, so it lands immediately
				Motion.stop(instance, property)
				assign(instance, property, target)
				continue
			end

			local channel = properties[property]

			if channel and channel.kind == kind and #channel.springs == #parts then
				--// retarget in place: position and velocity survive, which is
				--// the entire point of the spring path
				if channel.owner and channel.owner ~= animation then
					release(channel, false)
				end

				for index, spring in channel.springs do
					spring:retune(stiffness, damping)
					spring:setTarget(parts[index])
				end

				channel.target = target
				channel.owner = animation
			else
				if channel then
					drop(channel)
					release(channel, false)
				end

				local currentParts = decompose(read(instance, property)) or parts
				local springs = table.create(#parts)

				for index, goal in parts do
					local spring = Spring.new(currentParts[index] or goal, stiffness, damping)

					spring:setTarget(goal)

					springs[index] = spring
				end

				channel = {
					instance = instance,
					property = property,
					kind = kind,
					springs = springs,
					target = target,
					owner = animation,
				}

				properties[property] = channel
				channelCount += 1
			end

			table.insert(animation.channels, channel)
			animation.pending += 1
		end

		if animation.pending == 0 then
			finishAnimation(animation, true)
		else
			ensureStepping()
		end

		return animation
	end

	local duration = spec.duration or 0

	--// tween path: springs on these properties would fight the tween, so they
	--// are cancelled before it starts
	for property in props do
		Motion.stop(instance, property)
	end

	if duration <= 0 then
		for property, value in props do
			assign(instance, property, value)
		end

		finishAnimation(animation, true)

		return animation
	end

	local style, direction = Easing.resolve(spec.easing)

	local ok, tween = pcall(function()
		return TweenService:Create(instance, TweenInfo.new(duration, style, direction), props)
	end)

	if not ok or not tween then
		for property, value in props do
			assign(instance, property, value)
		end

		finishAnimation(animation, true)

		return animation
	end

	animation.tween = tween
	animation.instance = instance
	animation.goals = props

	tween.Completed:Connect(function(state)
		finishAnimation(animation, state == Enum.PlaybackState.Completed)
	end)

	tween:Play()

	return animation
end

--- Adds velocity to a live spring channel without moving it. Use on drag
--- release to carry the throw into the settle.
function Motion.impulse(instance: Instance, property: string, velocity: any)
	local properties = live[instance]
	local channel = properties and properties[property]

	if not channel then
		return
	end

	local parts = decompose(velocity)

	if not parts then
		return
	end

	for index, spring in channel.springs do
		spring:impulse(parts[index] or 0)
	end

	ensureStepping()
end

--- Whether anything is currently animating on this instance.
function Motion.busy(instance: Instance, property: string?): boolean
	local properties = live[instance]

	if not properties then
		return false
	end

	if property then
		return properties[property] ~= nil
	end

	return next(properties) ~= nil
end

return Motion
