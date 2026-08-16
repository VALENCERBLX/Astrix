--!strict

--- Renders a `Window`'s history, and highlights Kyn.
---
--- Highlighting runs over `Line.Tokenize`, the parser's own tokeniser, rather
--- than a second regex pass. A colour that disagrees with the parser is worse
--- than no colour: it tells you the line means something it does not.

local Types = require(script.Parent.Parent.Parent.Parent.Types)
local LineParser = require(script.Parent.Parent.Parent.Parent._Classes.Line)
local Packages = require(script.Parent.Parent.Parent.Parent._Packages)

type HistoryEntry = Types.HistoryEntry

local Lines = {}
Lines.__index = Lines

export type Fields = {
	Theme: any,
	List: any,
	Items: any,
	Window: any,
}

export type Lines = typeof(setmetatable({} :: Fields, Lines))

--// locals ---------------------------------------------------------------------
local Lume = Packages.Lume()
local Text = Lume.Text

--- Colours one Kyn token by what the parser decided it is.
local function paint(token: string, syntax: { [string]: string }): string
	local escaped = Text.escape(token)

	if token == ":" or token == ">>" or token == "->" or token == "|" then
		return Text.color(escaped, syntax.Operator)
	end

	if string.sub(token, 1, 2) == "--" then
		return Text.color(escaped, syntax.Flag)
	end

	if string.sub(token, 1, 2) == "::" then
		return Text.color(escaped, syntax.Stack)
	end

	if string.sub(token, 1, 1) == "@" then
		return Text.color(escaped, syntax.Ref)
	end

	if string.sub(token, 1, 1) == '"' then
		return Text.color(escaped, syntax.String)
	end

	if tonumber(token) then
		return Text.color(escaped, syntax.Number)
	end

	return escaped
end

--- Highlights a whole Kyn line into RichText.
function Lines.Highlight(raw: string, theme: any): string
	local syntax = theme.Syntax
	local tokens = LineParser.Tokenize(raw)

	if #tokens == 0 then
		return Text.color(Text.escape(raw), syntax.Comment)
	end

	local out = {}
	local head = true

	for _, token in tokens do
		if token.Kind == "Op" then
			head = true

			table.insert(out, Text.color(Text.escape(token.Text), syntax.Operator))
		else
			--// the first word of every segment is the command being run
			table.insert(out, if head then Text.color(Text.escape(token.Text), syntax.Command) else paint(token.Text, syntax))

			head = false
		end
	end

	--// the tokeniser drops comments, so any tail is put back dimmed
	local hash = string.find(raw, "#", 1, true)
	local comment = if hash then Text.color(Text.escape(string.sub(raw, hash)), syntax.Comment) else ""

	return table.concat(out, " ") .. (if comment ~= "" then " " .. comment else "")
end

--- The colour a history entry renders in, by its kind.
local function toneOf(entry: HistoryEntry, theme: any): string
	local kind = entry.Kind

	if kind == "Fail" then
		return theme.Rich.Error
	elseif kind == "Ok" then
		return theme.Rich.Success
	elseif kind == "Warn" then
		return theme.Rich.Warn
	elseif kind == "Input" then
		return theme.Rich.Sub
	end

	return "#FFFFFF"
end

--// public api ------------------------------------------------------------------
--- Builds the list that shows a window's history.
function Lines.new(panel: any, window: any, theme: any): Lines
	local list = panel:list()

	list:setFont(theme.Font.Mono)
	list:setTextSize(theme.TextSize.Line)
	list:setRowHeight(theme.Size.LineHeight)
	list:setSelectable(false)
	list:setEmptyText("")

	--// let the widest line drive the panel's width, the way the console does
	list:setFill(false)
	list:setMaxRows(math.floor(theme.Size.HistoryMaxHeight / theme.Size.LineHeight))

	local self: Fields = {
		Theme = theme,
		List = list,
		Items = Lume.value({}),
		Window = window,
	}

	local rendered = setmetatable(self, Lines)

	list:setItems(self.Items)
	list:setRenderer(function(item)
		local entry = item.data :: HistoryEntry

		if not entry then
			return Text.escape(item.text or "")
		end

		--// an echoed input line is highlighted as Kyn; everything else is
		--// output and takes the colour of its result
		if entry.Kind == "Input" then
			return Lines.Highlight(entry.Text, theme)
		end

		return Text.color(Text.escape(entry.Text), toneOf(entry, theme))
	end)

	return rendered
end

--- Pushes the window's history into the list.
---
--- Rebuilds every row rather than using `Window:VisibleLineRange`. Lume's list
--- is already virtualised — only on-screen rows become instances — so the cost
--- here is rebuilding the item array, not the UI. Open item #9 is about
--- skipping even that for very long histories.
function Lines.Render(self: Lines)
	local window = self.Window
	local items = {}

	for index, entry in window.History do
		table.insert(items, {
			id = tostring(index),
			text = entry.Text,
			data = entry,
		})
	end

	self.Items:set(items)

	window.Dirty = false
end

function Lines.Destroy(self: Lines)
	self.List:destroy()
end

return Lines
