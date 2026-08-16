--!strict

--- Windowing arithmetic for long lists: which rows are on screen, where they
--- sit on the canvas, and how tall the canvas has to be.
---
--- No instances are created here. A list keeps a pool of row instances and
--- asks this module which slice of its data those rows should be showing —
--- which is why scrolling ten thousand items costs the same as scrolling ten.
--- @section Layout

local Virtual = {}

--- The slice of indices to render for a scroll offset, padded by `buffer` rows
--- on each side so a fast scroll does not reveal empty space.
function Virtual.range(
	scrollTop: number,
	viewHeight: number,
	rowHeight: number,
	count: number,
	buffer: number?
): (number, number)
	if count <= 0 or rowHeight <= 0 or viewHeight <= 0 then
		return 1, 0
	end

	local pad = buffer or 4

	local first = math.max(1, math.floor(scrollTop / rowHeight) + 1 - pad)
	local last = math.min(count, math.ceil((scrollTop + viewHeight) / rowHeight) + pad)

	return first, last
end

--- Total canvas height for a uniform-row list.
function Virtual.canvas(count: number, rowHeight: number): number
	return math.max(0, count * rowHeight)
end

--- Y offset of a row index on the canvas.
function Virtual.offset(index: number, rowHeight: number): number
	return (index - 1) * rowHeight
end

--- Which row sits under a canvas Y coordinate.
function Virtual.indexAt(y: number, rowHeight: number, count: number): number
	if rowHeight <= 0 then
		return 1
	end

	return math.clamp(math.floor(y / rowHeight) + 1, 1, math.max(1, count))
end

--- Scroll offset that brings `index` into view, given where the view is now.
--- Scrolls the minimum distance: already-visible rows do not move the view.
function Virtual.scrollTo(index: number, rowHeight: number, viewHeight: number, scrollTop: number): number
	local top = Virtual.offset(index, rowHeight)
	local bottom = top + rowHeight

	if top < scrollTop then
		return top
	end

	if bottom > scrollTop + viewHeight then
		return bottom - viewHeight
	end

	return scrollTop
end

--- How far a variable-height list has to scroll to reach index `target`,
--- summing measured heights. Falls back to `rowHeight` for unmeasured rows.
function Virtual.offsetVariable(heights: { number }, target: number, rowHeight: number): number
	local total = 0

	for index = 1, math.min(target - 1, #heights) do
		total += heights[index] or rowHeight
	end

	if target - 1 > #heights then
		total += (target - 1 - #heights) * rowHeight
	end

	return total
end

--- Whether a scroll position counts as pinned to the bottom, within a
--- tolerance. Lists use this to decide whether new content should follow the
--- view down or leave the user where they were reading.
function Virtual.pinned(scrollTop: number, viewHeight: number, canvasHeight: number, tolerance: number?): boolean
	local slack = tolerance or 4

	return scrollTop + viewHeight >= canvasHeight - slack
end

return Virtual
