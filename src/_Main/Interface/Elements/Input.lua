--!strict

--- The console textbox: prompt glyph, ghost completion, history recall, and
--- Leaping cursor navigation.
---
--- Not `_Classes/Input.lua`, which is the Kyn *session*. Same name, opposite
--- job: that one holds variables and a stack, this one holds a caret.
---
--- Leaping's segment jumps call `Line.SegmentAt` — the parser's own splitter —
--- rather than re-implementing a lightweight `:`/`>>`/`->` split here. Two
--- definitions of where a segment starts would eventually disagree, and the
--- one the user sees would be the wrong one.

local UserInputService = game:GetService("UserInputService")

local LineParser = require(script.Parent.Parent.Parent.Parent._Classes.Line)

local Input = {}
Input.__index = Input

export type Fields = {
	Theme: any,
	Field: any,
	History: { string },
	Cursor: number,
	Draft: string,
	OnSubmit: ((string) -> ())?,
	OnChange: ((string) -> ())?,
}

export type Console = typeof(setmetatable({} :: Fields, Input))

local HISTORY_LIMIT = 100

--// public api ------------------------------------------------------------------
function Input.new(panel: any, theme: any): Console
	local field = panel:field("type a command...")

	field:setPrefix(">")
	field:setFont(theme.Font.Mono)
	field:setTextSize(theme.TextSize.Input)
	field:setClearOnSubmit(true)

	local self: Fields = {
		Theme = theme,
		Field = field,
		History = {},
		Cursor = 0,
		Draft = "",
		OnSubmit = nil,
		OnChange = nil,
	}

	local console = setmetatable(self, Input)

	field:onChanged(function(text)
		if self.OnChange then
			self.OnChange(text)
		end
	end)

	field:onSubmitted(function(text)
		if text ~= "" then
			Input.Remember(console, text)
		end

		if self.OnSubmit then
			self.OnSubmit(text)
		end
	end)

	return console
end

function Input.Text(self: Console): string
	return self.Field:value()
end

function Input.SetText(self: Console, text: string)
	self.Field:setText(text)
end

function Input.SetHint(self: Console, hint: string)
	self.Field:setHint(hint)
end

function Input.Focus(self: Console)
	self.Field:focus()
end

function Input.Blur(self: Console)
	self.Field:blur()
end

--- Records a submitted line for up-arrow recall.
function Input.Remember(self: Console, text: string)
	--// running the same line twice should not fill the buffer with it
	if self.History[#self.History] ~= text then
		table.insert(self.History, text)
	end

	while #self.History > HISTORY_LIMIT do
		table.remove(self.History, 1)
	end

	self.Cursor = 0
	self.Draft = ""
end

--- Steps back through submitted lines. `direction` is -1 for older.
---
--- Stepping off the newest end restores whatever was half-typed before recall
--- started, which is the behaviour every shell has.
function Input.Recall(self: Console, direction: number)
	local count = #self.History

	if count == 0 then
		return
	end

	if self.Cursor == 0 and direction < 0 then
		self.Draft = Input.Text(self)
	end

	local next = math.clamp(self.Cursor - direction, 0, count)

	self.Cursor = next

	if next == 0 then
		Input.SetText(self, self.Draft)

		return
	end

	Input.SetText(self, self.History[count - next + 1])
end

--// leaping -----------------------------------------------------------------------
local function caret(self: Console): number
	local box = self.Field.refs.input :: TextBox

	return box.CursorPosition
end

local function setCaret(self: Console, position: number)
	local box = self.Field.refs.input :: TextBox

	box.CursorPosition = math.max(1, position)
end

--- `Ctrl+Left` / `Ctrl+Right`: jump one space-delimited word.
function Input.LeapWord(self: Console, direction: number)
	local text = Input.Text(self)
	local position = caret(self)

	if direction < 0 then
		local index = position - 1

		while index > 1 and string.sub(text, index - 1, index - 1) == " " do
			index -= 1
		end

		while index > 1 and string.sub(text, index - 1, index - 1) ~= " " do
			index -= 1
		end

		setCaret(self, index)

		return
	end

	local index = position

	while index <= #text and string.sub(text, index, index) ~= " " do
		index += 1
	end

	while index <= #text and string.sub(text, index, index) == " " do
		index += 1
	end

	setCaret(self, index)
end

--- `Ctrl+Up` / `Ctrl+Down`: jump to the start or end of the chain segment the
--- caret is currently in — not the whole line.
function Input.LeapSegment(self: Console, direction: number)
	local text = Input.Text(self)
	local segment = LineParser.SegmentAt(text, caret(self))

	setCaret(self, if direction < 0 then segment.Start else segment.Finish + 1)
end

--- Wires the Ctrl+Arrow shortcuts. Returns a disconnect function.
---
--- These are raw connections; when Switch is wired in they move to an
--- `"AstrixConsole"` context that is pushed on open and popped on close.
function Input.BindLeaping(self: Console): () -> ()
	local connection = UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local held = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		if not held then
			return
		end

		local code = input.KeyCode

		if code == Enum.KeyCode.Left then
			Input.LeapWord(self, -1)
		elseif code == Enum.KeyCode.Right then
			Input.LeapWord(self, 1)
		elseif code == Enum.KeyCode.Up then
			Input.LeapSegment(self, -1)
		elseif code == Enum.KeyCode.Down then
			Input.LeapSegment(self, 1)
		end
	end)

	return function()
		connection:Disconnect()
	end
end

function Input.Destroy(self: Console)
	self.Field:destroy()
end

return Input
