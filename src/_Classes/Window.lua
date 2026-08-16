--!strict

--- One console window's state: its history, its scroll position, its size.
---
--- Konsole hardcoded two channels — a main console and a detached chat pill —
--- and branched on `channel == 2` throughout. A `Window` is that generalised:
--- `Container` holds any number of them keyed by `Id`, and nothing anywhere
--- checks which one it is.
---
--- Which windows exist, which has focus and how they stack are *session*
--- concerns and live on `RuntimeEntry.Interface.State`, not here.

local Types = require(script.Parent.Parent.Types)
local Content = require(script.Parent.Content)

type HistoryEntry = Types.HistoryEntry
type ContentElement = Types.ContentElement
type WindowConfig = Types.WindowConfig

local Window = {}
Window.__index = Window

export type Fields = {
	Id: string,
	Title: string,
	Docked: boolean,
	Position: UDim2?,
	Width: number?,
	Theme: any,

	History: { HistoryEntry },
	Limit: number,
	Scroll: number,
	Pinned: boolean,
	Dirty: boolean,
}

export type Window = typeof(setmetatable({} :: Fields, Window))

local DEFAULT_LIMIT = 500

function Window.new(config: WindowConfig): Window
	local self: Fields = {
		Id = config.Id,
		Title = config.Title or config.Id,
		Docked = config.Docked ~= false,
		Position = config.Position,
		Width = config.Width,
		Theme = config.Theme,

		History = {},
		Limit = DEFAULT_LIMIT,
		Scroll = 0,
		Pinned = true,
		Dirty = true,
	}

	return setmetatable(self, Window)
end

--- Appends an entry, evicting the oldest once past the limit.
function Window.Write(self: Window, kind: Types.HistoryKind, text: string, content: ContentElement?): HistoryEntry
	local entry: HistoryEntry = { Kind = kind, Text = text, Content = content }

	table.insert(self.History, entry)

	while #self.History > self.Limit do
		table.remove(self.History, 1)
	end

	self.Dirty = true

	return entry
end

--- Writes a rich element, expanding it into text lines so a window always has
--- something printable even before a renderer understands the element.
function Window.WriteContent(self: Window, element: ContentElement, kind: Types.HistoryKind?)
	local lines = Content.Lines(element)

	for index, line in lines do
		Window.Write(self, kind or "Output", line, if index == 1 then element else nil)
	end
end

function Window.Clear(self: Window)
	table.clear(self.History)

	self.Scroll = 0
	self.Pinned = true
	self.Dirty = true
end

function Window.Count(self: Window): number
	return #self.History
end

--- The slice of history that is actually on screen.
---
--- `Lines:Render` does not call this yet — it rebuilds every row each render,
--- which is fine at normal volume and is flagged as open item #9. The maths
--- lives here so wiring it up later is a change in one place.
function Window.VisibleLineRange(self: Window, viewHeight: number, lineHeight: number, buffer: number?): (number, number)
	local count = #self.History

	if count == 0 or lineHeight <= 0 or viewHeight <= 0 then
		return 1, 0
	end

	local pad = buffer or 4

	local first = math.max(1, math.floor(self.Scroll / lineHeight) + 1 - pad)
	local last = math.min(count, math.ceil((self.Scroll + viewHeight) / lineHeight) + pad)

	return first, last
end

function Window.SetScroll(self: Window, offset: number, canvasHeight: number, viewHeight: number)
	self.Scroll = math.max(0, offset)
	self.Pinned = self.Scroll + viewHeight >= canvasHeight - 4
end

return Window
