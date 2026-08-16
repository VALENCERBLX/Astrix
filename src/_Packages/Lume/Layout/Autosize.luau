--!strict

--- The layout pass. One function, run once per panel per frame, that turns a
--- panel's children into the size that panel should be.
---
--- The rule is: **measure, sum, clamp**. Children report what they want given
--- the room on offer, the panel adds them up along its axis, and the result is
--- clamped by the panel's own bounds and by how much screen is actually left
--- in the direction it grows. Roblox's own UIListLayout then places the
--- children inside that decided size — Lume never positions them itself.
---
--- Everything responsive about the library comes out of this: nothing has a
--- hardcoded size, so nothing has to be re-tuned per screen.
--- @section Layout

local Types = require(script.Parent.Parent.Types)

type Solution = Types.Solution
type Element = Types.Element

local Autosize = {}

export type Input = {
	children: { Element },
	vertical: boolean,

	gap: number,
	padX: number,
	padY: number,

	chrome: Vector2,
	room: Vector2,

	minWidth: number,
	maxWidth: number,
	minHeight: number,
	maxHeight: number,

	fixedWidth: number?,
	fixedHeight: number?,
}

--- Runs one pass and reports the content size, the total size the panel wants,
--- and that total clamped to what it is allowed and what fits.
function Autosize.solve(input: Input): Solution
	local vertical = input.vertical

	--// what a child may occupy, before it is asked what it wants
	local ceilingWidth = math.min(input.maxWidth, math.max(input.minWidth, input.room.X))
	local ceilingHeight = math.min(input.maxHeight, math.max(input.minHeight, input.room.Y))

	local availableWidth = math.max(0, (input.fixedWidth or ceilingWidth) - input.padX * 2)
	local availableHeight = math.max(0, (input.fixedHeight or ceilingHeight) - input.padY * 2 - input.chrome.Y)

	local available = Vector2.new(availableWidth, availableHeight)

	local main = 0
	local cross = 0
	local visible = 0
	local growers = 0

	for _, child in input.children do
		if not child.instance.Visible then
			continue
		end

		local desired = child:measure(available)
		local margin = child.margin * 2

		if vertical then
			main += desired.Y + margin
			cross = math.max(cross, desired.X + margin)
		else
			main += desired.X + margin
			cross = math.max(cross, desired.Y + margin)
		end

		if child.grow then
			growers += 1
		end

		visible += 1
	end

	if visible > 1 then
		main += input.gap * (visible - 1)
	end

	local content = if vertical then Vector2.new(cross, main) else Vector2.new(main, cross)

	local total = Vector2.new(
		content.X + input.padX * 2,
		content.Y + input.padY * 2 + input.chrome.Y
	) + Vector2.new(input.chrome.X, 0)

	local width = input.fixedWidth or math.clamp(total.X, input.minWidth, ceilingWidth)
	local height = input.fixedHeight or math.clamp(total.Y, input.minHeight, ceilingHeight)

	local clamped = Vector2.new(math.floor(width + 0.5), math.floor(height + 0.5))

	local overflow = if vertical then total.Y > clamped.Y + 0.5 else total.X > clamped.X + 0.5

	--// a panel with growers never reports overflow on the main axis: the
	--// growers absorb the difference instead
	if growers > 0 and not overflow then
		overflow = false
	end

	return {
		content = content,
		total = total,
		clamped = clamped,
		overflow = overflow,
	}
end

--- Distributes leftover main-axis space across children that asked to grow.
--- Returns how much each grower gets; zero when nothing grows or nothing is
--- left over.
function Autosize.share(input: Input, solution: Solution): number
	local growers = 0

	for _, child in input.children do
		if child.instance.Visible and child.grow then
			growers += 1
		end
	end

	if growers == 0 then
		return 0
	end

	local used = if input.vertical then solution.content.Y else solution.content.X
	local room = if input.vertical
		then solution.clamped.Y - input.padY * 2 - input.chrome.Y
		else solution.clamped.X - input.padX * 2

	return math.max(0, room - used) / growers
end

return Autosize
