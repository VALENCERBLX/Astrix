--!strict

--- A scalar damped-harmonic-oscillator solver, stepped analytically so the
--- result is identical at 30fps and 240fps.
---
--- This is what makes retargeting feel right: changing `target` mid-flight
--- keeps the current position *and velocity*, so the motion bends toward the
--- new destination instead of restarting from a standstill.
--- @section Motion

local Spring = {}
Spring.__index = Spring

export type Fields = {
	position: number,
	velocity: number,
	target: number,

	frequency: number,
	ratio: number,
}

export type Spring = typeof(setmetatable({} :: Fields, Spring))

local EPSILON_POSITION = 0.0005
local EPSILON_VELOCITY = 0.0005

--- Creates a spring resting at `position`.
---
--- `stiffness` sets the frequency, `damping` the damping *coefficient*: a
--- ratio of exactly 1 is critical (no overshoot), below 1 overshoots, above 1
--- crawls in.
function Spring.new(position: number, stiffness: number, damping: number): Spring
	local frequency = math.sqrt(math.max(stiffness, 0.0001))

	local self: Fields = {
		position = position,
		velocity = 0,
		target = position,

		frequency = frequency,
		ratio = damping / (2 * frequency),
	}

	return setmetatable(self, Spring)
end

--- Retunes an in-flight spring without disturbing its state.
function Spring.retune(self: Spring, stiffness: number, damping: number)
	local frequency = math.sqrt(math.max(stiffness, 0.0001))

	self.frequency = frequency
	self.ratio = damping / (2 * frequency)
end

--- Advances the spring. Returns the new position.
function Spring.step(self: Spring, delta: number): number
	if delta <= 0 then
		return self.position
	end

	--// a long frame (streaming hitch, tab restore) integrated in one go reads
	--// as a teleport; cap it so the motion stays continuous instead
	local dt = math.min(delta, 1 / 20)

	local offset = self.position - self.target
	local velocity = self.velocity

	local frequency = self.frequency
	local ratio = self.ratio

	local position: number
	local nextVelocity: number

	if ratio < 1 then
		--// underdamped: oscillates in
		local damped = frequency * math.sqrt(1 - ratio * ratio)
		local decay = math.exp(-ratio * frequency * dt)

		local cosine = math.cos(damped * dt)
		local sine = math.sin(damped * dt)

		local first = offset
		local second = (velocity + ratio * frequency * offset) / damped

		position = decay * (first * cosine + second * sine)
		nextVelocity = decay
			* (-ratio * frequency * (first * cosine + second * sine) + damped * (second * cosine - first * sine))
	elseif ratio == 1 then
		--// critically damped: the fastest approach with no overshoot
		local decay = math.exp(-frequency * dt)

		local first = offset
		local second = velocity + frequency * offset

		position = (first + second * dt) * decay
		nextVelocity = decay * (second - frequency * (first + second * dt))
	else
		--// overdamped: two real roots, no oscillation
		local root = frequency * math.sqrt(ratio * ratio - 1)

		local slow = -frequency * ratio + root
		local fast = -frequency * ratio - root

		local second = (velocity - slow * offset) / (fast - slow)
		local first = offset - second

		local slowDecay = math.exp(slow * dt)
		local fastDecay = math.exp(fast * dt)

		position = first * slowDecay + second * fastDecay
		nextVelocity = first * slow * slowDecay + second * fast * fastDecay
	end

	self.position = position + self.target
	self.velocity = nextVelocity

	return self.position
end

--- Points the spring somewhere new, keeping position and velocity.
function Spring.setTarget(self: Spring, target: number)
	self.target = target
end

--- Adds velocity without moving the spring — a flick.
function Spring.impulse(self: Spring, velocity: number)
	self.velocity += velocity
end

--- Teleports the spring, killing its velocity.
function Spring.reset(self: Spring, position: number)
	self.position = position
	self.velocity = 0
	self.target = position
end

--- Whether the spring has arrived and stopped.
function Spring.settled(self: Spring): boolean
	return math.abs(self.position - self.target) < EPSILON_POSITION and math.abs(self.velocity) < EPSILON_VELOCITY
end

--- Snaps to the target and clears velocity.
function Spring.finish(self: Spring)
	self.position = self.target
	self.velocity = 0
end

return Spring
