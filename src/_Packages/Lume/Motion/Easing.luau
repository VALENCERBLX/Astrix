--!strict

--- Easing names, in two forms: the Roblox enum pair used by the tween path,
--- and pure numeric curves used anywhere a value has to be shaped by hand
--- (gradients, indeterminate progress, hand-rolled sweeps).
---
--- Names read `<direction><Style>` — `outQuint`, `inOutQuad`, `inBack` — with
--- `linear` as the one special case.
--- @section Motion

local Easing = {}

--// locals
local STYLES: { [string]: Enum.EasingStyle } = {
	linear = Enum.EasingStyle.Linear,
	sine = Enum.EasingStyle.Sine,
	quad = Enum.EasingStyle.Quad,
	cubic = Enum.EasingStyle.Cubic,
	quart = Enum.EasingStyle.Quart,
	quint = Enum.EasingStyle.Quint,
	expo = Enum.EasingStyle.Exponential,
	exponential = Enum.EasingStyle.Exponential,
	circ = Enum.EasingStyle.Circular,
	circular = Enum.EasingStyle.Circular,
	back = Enum.EasingStyle.Back,
	elastic = Enum.EasingStyle.Elastic,
	bounce = Enum.EasingStyle.Bounce,
}

local DIRECTIONS: { [string]: Enum.EasingDirection } = {
	["in"] = Enum.EasingDirection.In,
	out = Enum.EasingDirection.Out,
	inout = Enum.EasingDirection.InOut,
}

--- Splits `outQuint` into its direction and style enums. Unknown names fall
--- back to `Out` / `Quad` with a warning rather than erroring mid-animation.
function Easing.resolve(name: string?): (Enum.EasingStyle, Enum.EasingDirection)
	if not name or name == "" then
		return Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	end

	local lowered = string.lower(name)

	if lowered == "linear" then
		return Enum.EasingStyle.Linear, Enum.EasingDirection.Out
	end

	local direction = "out"
	local style = lowered

	if string.sub(lowered, 1, 5) == "inout" then
		direction, style = "inout", string.sub(lowered, 6)
	elseif string.sub(lowered, 1, 3) == "out" then
		direction, style = "out", string.sub(lowered, 4)
	elseif string.sub(lowered, 1, 2) == "in" then
		direction, style = "in", string.sub(lowered, 3)
	end

	local resolvedStyle = STYLES[style]

	if not resolvedStyle then
		warn(`[Lume] unknown easing '{name}'`)

		return Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	end

	return resolvedStyle, DIRECTIONS[direction] or Enum.EasingDirection.Out
end

--// numeric curves, all on the unit interval
function Easing.linear(t: number): number
	return t
end

function Easing.outQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

function Easing.outCubic(t: number): number
	local inverse = 1 - t

	return 1 - inverse * inverse * inverse
end

function Easing.outQuint(t: number): number
	local inverse = 1 - t

	return 1 - inverse ^ 5
end

function Easing.outExpo(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

function Easing.outBack(t: number, overshoot: number?): number
	local amount = overshoot or 1.70158
	local inverse = t - 1

	return 1 + (amount + 1) * inverse ^ 3 + amount * inverse ^ 2
end

function Easing.inOutQuad(t: number): number
	if t < 0.5 then
		return 2 * t * t
	end

	return 1 - ((-2 * t + 2) ^ 2) / 2
end

function Easing.inOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

--- Smoothstep, the curve most useful for fades that should not read as linear.
function Easing.smooth(t: number): number
	local clamped = math.clamp(t, 0, 1)

	return clamped * clamped * (3 - 2 * clamped)
end

--- Frame-rate independent exponential approach. `smoothing` is the fraction of
--- the remaining distance left after one second.
function Easing.approach(current: number, target: number, smoothing: number, delta: number): number
	return target + (current - target) * smoothing ^ delta
end

return Easing
