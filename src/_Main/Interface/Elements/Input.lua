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
--- @section Console

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
	Multiline: boolean,
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

	--// the panel behind it already is the surface, so the input draws neither
	--// a well nor a border — that is what makes the row read as a prompt
	--// rather than as a text box sitting on a panel
	field:setSurface(theme.Color.Background, 1)
	field:setBorder(false)
	field:setRadius(0)

	field:setColors({
		text = theme.Color.TextPrimary,
		placeholder = theme.Color.TextPrompt,
		prefix = theme.Color.TextPrompt,
		hint = theme.Color.TextGhost,
		icon = theme.Color.TextPrompt,
	})

	field:setTrailingIcon(theme.Asset.Arrow)

	local self: Fields = {
		Theme = theme,
		Field = field,
		History = {},
		Cursor = 0,
		Draft = "",
		Multiline = false,
		OnSubmit = nil,
		OnChange = nil,
	}

	local console = setmetatable(self, Input)

	field:onChanged(function(text)
		Input.SyncMultiline(console, text)

		if self.OnChange then
			self.OnChange(text)
		end
	end)

	field:onSubmitted(function(text)
		--// inside a [[ block Enter is a newline, not a submit
		if self.Multiline then
			return
		end

		local body = Input.Unwrap(text)

		if body ~= "" then
			Input.Remember(console, body)
		end

		if self.OnSubmit then
			self.OnSubmit(body)
		end
	end)

	return console
end

--- Re-applies a theme's colours to the live field.
function Input.Restyle(self: Console, theme: any)
	self.Theme = theme

	self.Field:setColors({
		text = theme.Color.TextPrimary,
		placeholder = theme.Color.TextPrompt,
		prefix = theme.Color.TextPrompt,
		hint = theme.Color.TextGhost,
		icon = theme.Color.TextPrompt,
	})

	self.Field:setTrailingIcon(theme.Asset.Arrow)
end

--- Hides the whole input row. Konsole hides it when the bar is collapsed and
--- empty, leaving just the placeholder.
function Input.SetVisible(self: Console, visible: boolean)
	self.Field:setVisible(visible)
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

--- Deferred on purpose.
---
--- Capturing focus during the same `InputBegan` that opened the console makes
--- the TextBox eat that keystroke, so pressing the activation key types its
--- own letter into the prompt. Waiting a frame lets the key finish being a
--- keybind before the field starts being a field.
function Input.Focus(self: Console)
	task.defer(function()
		self.Field:focus()
	end)
end

--- Whether this input owns the keyboard. Console shortcuts check it so they
--- cannot fire while the player is typing somewhere else in the game.
function Input.Focused(self: Console): boolean
	return (self.Field :: any).focused == true
end

function Input.Blur(self: Console)
	self.Field:blur()
end

--- `[[` opens an inline multiline block and `]]` closes it.
---
--- While the block is open Enter inserts a newline instead of submitting, so a
--- long chain can be written across lines. Closing it submits immediately —
--- typing `]]` is the submit.
function Input.SyncMultiline(self: Console, text: string)
	local opens = select(2, string.gsub(text, "%[%[", ""))
	local closes = select(2, string.gsub(text, "%]%]", ""))

	local inside = opens > closes

	if inside == self.Multiline then
		return
	end

	self.Multiline = inside

	self.Field:setMultiline(inside)

	--// the block just closed: submit what was inside it
	if not inside and opens > 0 then
		local body = Input.Unwrap(text)

		if body ~= "" then
			Input.Remember(self, body)

			if self.OnSubmit then
				self.OnSubmit(body)
			end
		end

		Input.SetText(self, "")
	end
end

--- Strips the `[[` / `]]` markers, leaving the command inside.
function Input.Unwrap(text: string): string
	local inner = string.match(text, "^%s*%[%[(.*)%]%]%s*$")

	if inner then
		--// trim BOTH ends: `[[ Help ]]` is the command `Help`, and a trailing
		--// space would make it a different token stream
		return (string.match(inner, "^%s*(.-)%s*$")) or inner
	end

	return (string.match(text, "^%s*(.-)%s*$")) or text
end

--- Whether a multiline block is currently open.
function Input.InBlock(self: Console): boolean
	return self.Multiline
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

		--// only while this input owns the keyboard, or Ctrl+Arrow would move a
		--// caret that is not on screen
		if not Input.Focused(self) then
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
