--!strict

--- Inline autocomplete. Filters a source against a query, highlights the
--- matched span in each row, and — when attached to a field — writes the
--- remainder of the best match into that field as a ghost hint.
---
--- The ghost hint is the whole point. Seeing the completion sitting in the
--- input, in place, is what makes an autocomplete feel like it is finishing
--- your sentence rather than offering you a menu.
---
--- Up and Down move the highlight, Tab accepts it, Enter accepts and submits.
--- @section Elements

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)
local Text = require(script.Parent.Parent.Text)

local Suggest = {}
Suggest.__index = Suggest

export type Fields = Types.NodeFields & Types.ElementFields & {
	source: { Types.Option },
	matches: { Types.Option },

	cursor: number,
	limit: number,
	query: string,

	list: Types.List?,
	field: Types.Field?,
	matcher: ((string, string) -> (boolean, number))?,
}

--// locals
local function normalise(entry: Types.Option | string): Types.Option
	if type(entry) == "string" then
		return { id = entry, text = entry }
	end

	local option = entry :: Types.Option

	return { id = option.id or option.text, text = option.text, icon = option.icon, description = option.description }
end

--- Creates a suggestion list. Prefer `panel:suggest()`.
function Suggest.new(app: Types.App): Types.Suggest
	local scope = app.scope:child()

	local root = Create.node(scope, {
		class = "Frame",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			Name = "Suggest",
		},
	}) :: Frame

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root,
		refs = { root = root },
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "suggest",
		desired = Vector2.zero,
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		source = {},
		matches = {},

		cursor = 0,
		limit = 8,
		query = "",

		list = nil,
		field = nil,
		matcher = nil,
	}

	local suggest = setmetatable(fields, Suggest) :: any

	local List = require(script.Parent.List)
	local list = List.new(app)

	list:setMaxRows(fields.limit)
	list:setSelectable(true)
	list:setRenderer(function(item)
		local theme = app.theme

		return Text.highlight(item.text or "", fields.query, theme.rich.muted, theme.rich.accent)
	end)
	list:onActivated(function(item)
		Suggest.acceptItem(suggest, item.id :: string)
	end)

	;(list :: any).owner = suggest
	;(list :: any).instance.Parent = root

	fields.list = list

	return suggest
end

--- Re-runs the filter and repaints the list.
function Suggest.refilter(self: Fields & Types.Suggest)
	local scored: { { option: Types.Option, score: number } } = {}
	local match = self.matcher or Text.fuzzy

	for _, option in self.source do
		local ok, score = match(option.text, self.query)

		if ok then
			table.insert(scored, { option = option, score = score })
		end
	end

	table.sort(scored, function(left, right)
		if left.score == right.score then
			return left.option.text < right.option.text
		end

		return left.score < right.score
	end)

	table.clear(self.matches)

	for index = 1, math.min(#scored, self.limit) do
		table.insert(self.matches, scored[index].option)
	end

	self.cursor = if #self.matches > 0 then 1 else 0

	if self.list then
		self.list:setItems(self.matches :: any)
		self.list:setSelected(if self.cursor > 0 then self.matches[self.cursor].id else nil)
	end

	Suggest.pushHint(self)

	self.instance.Visible = #self.matches > 0

	self:emit("highlighted", self.matches[self.cursor])
	self:invalidate()
end

--- Writes the unfinished part of the highlighted match into the attached
--- field, so it appears greyed out right after the caret.
function Suggest.pushHint(self: Fields)
	local field = self.field

	if not field then
		return
	end

	local option = self.matches[self.cursor]

	if not option or self.query == "" then
		field:setHint("")

		return
	end

	local lowered = string.lower(option.text)
	local typed = string.lower(self.query)

	if string.sub(lowered, 1, #typed) ~= typed then
		--// a fuzzy match that is not a prefix has no meaningful remainder
		field:setHint("")

		return
	end

	field:setHint(string.sub(option.text, #self.query + 1))
end

function Suggest.setSource(
	self: Fields & Types.Suggest,
	source: Types.Bindable<{ Types.Option | string }>
): Types.Suggest
	Node.bind(self, "source", source, function(next: { Types.Option | string })
		local normalised: { Types.Option } = {}

		for _, entry in next do
			table.insert(normalised, normalise(entry))
		end

		self.source = normalised

		Suggest.refilter(self)
	end)

	return self
end

function Suggest.setQuery(self: Fields & Types.Suggest, query: Types.Bindable<string>): Types.Suggest
	Node.bind(self, "query", query, function(next: string)
		self.query = tostring(next)

		Suggest.refilter(self)
	end)

	return self
end

function Suggest.setLimit(self: Fields & Types.Suggest, limit: number): Types.Suggest
	self.limit = math.max(1, limit)

	if self.list then
		self.list:setMaxRows(self.limit)
	end

	Suggest.refilter(self)

	return self
end

--- Replaces the default subsequence matcher. Return whether it matched and a
--- score where lower sorts first.
function Suggest.setMatcher(
	self: Fields & Types.Suggest,
	matcher: (string, string) -> (boolean, number)
): Types.Suggest
	self.matcher = matcher

	Suggest.refilter(self)

	return self
end

--- Points the list at a field WITHOUT taking over its filtering.
---
--- `attach` assumes the list drives itself from the field's text. A consumer
--- with its own grammar — deciding that `@Players.` means players and `--` means
--- flags — needs the opposite: it feeds the query itself, but still wants
--- `accept` to write into the field and the ghost hint to appear after the
--- caret. That is what this is for.
function Suggest.setField(self: Fields & Types.Suggest, field: Types.Field): Types.Suggest
	self.field = field

	return self
end

--- Wires a field to this suggestion list: its text drives the query, its ghost
--- hint shows the completion, and the arrow keys drive the highlight.
function Suggest.attach(self: Fields & Types.Suggest, field: Types.Field): Types.Suggest
	self.field = field

	field:onChanged(function(text)
		self.query = text

		Suggest.refilter(self)
	end)

	self.scope:add(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if #self.matches == 0 or not (field :: any).focused then
			return
		end

		if input.KeyCode == Enum.KeyCode.Down then
			Suggest.next(self)
		elseif input.KeyCode == Enum.KeyCode.Up then
			Suggest.previous(self)
		elseif input.KeyCode == Enum.KeyCode.Tab and not processed then
			Suggest.accept(self)
		end
	end))

	return self
end

function Suggest.onAccepted(self: Fields & Types.Suggest, handler: (Types.Option) -> ()): Types.Suggest
	return self:on("accepted", handler)
end

function Suggest.onHighlighted(self: Fields & Types.Suggest, handler: (Types.Option?) -> ()): Types.Suggest
	return self:on("highlighted", handler)
end

--- Moves the highlight, wrapping at the ends.
function Suggest.next(self: Fields & Types.Suggest): Types.Suggest
	if #self.matches == 0 then
		return self
	end

	self.cursor = (self.cursor % #self.matches) + 1

	if self.list then
		self.list:setSelected(self.matches[self.cursor].id)
		self.list:scrollTo(self.cursor)
	end

	Suggest.pushHint(self)

	self:emit("highlighted", self.matches[self.cursor])

	return self
end

function Suggest.previous(self: Fields & Types.Suggest): Types.Suggest
	if #self.matches == 0 then
		return self
	end

	self.cursor = if self.cursor <= 1 then #self.matches else self.cursor - 1

	if self.list then
		self.list:setSelected(self.matches[self.cursor].id)
		self.list:scrollTo(self.cursor)
	end

	Suggest.pushHint(self)

	self:emit("highlighted", self.matches[self.cursor])

	return self
end

--- Accepts by id, used by row clicks.
function Suggest.acceptItem(self: Fields & Types.Suggest, id: string)
	for index, option in self.matches do
		if option.id == id then
			self.cursor = index

			break
		end
	end

	Suggest.accept(self)
end

--- Commits the highlighted match into the attached field.
function Suggest.accept(self: Fields & Types.Suggest): Types.Suggest
	local option = self.matches[self.cursor]

	if not option then
		return self
	end

	if self.field then
		self.field:setText(option.text)
		self.field:setHint("")
	end

	self:emit("accepted", option)

	return self
end

function Suggest.highlighted(self: Fields & Types.Suggest): Types.Option?
	return self.matches[self.cursor]
end

function Suggest.measure(self: Fields & Types.Suggest, available: Vector2): Vector2
	if not self.list or #self.matches == 0 then
		self.desired = Vector2.new(available.X, 0)
		self.measured = true

		return self.desired
	end

	self.desired = self.list:measure(available)
	self.measured = true

	return self.desired
end

function Suggest.commit(self: Fields & Types.Suggest, inner: Vector2, vertical: boolean, share: number)
	local width = if vertical and self.fill then math.max(0, inner.X - self.margin * 2) else self.desired.X
	local height = self.desired.Y + (if self.grow then share else 0)

	self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))

	if self.list then
		self.list:commit(Vector2.new(width, height), true, 0)
	end
end

function Suggest.destroy(self: Fields & Types.Suggest)
	if self.list then
		self.list:destroy()

		self.list = nil
	end

	Node.teardown(self)
end

Element.install(Suggest)

return Suggest
