--!strict

--- Kyn-aware autocomplete.
---
--- Konsole completed command names. Kyn has a grammar, so what to offer depends
--- on where the caret is:
---
--- * a bareword at the start of a segment → command names
--- * `@Players.` → live player names
--- * `@` with no dot → session variables, session functions, and natives
--- * a positional slot on a known command → that argument's type provider
---
--- Everything routes through one `Context` function so the rules live in one
--- readable place instead of being spread across the dropdown's callbacks.
--- @section Console

local Players = game:GetService("Players")

local LineParser = require(script.Parent.Parent.Parent.Parent._Classes.Line)
local Lume = require(script.Parent.Parent.Parent.Parent._Packages.Lume)

local Suggestions = {}
Suggestions.__index = Suggestions

export type Fields = {
	Theme: any,
	Panel: any,
	Suggest: any,
	Registry: any,
	Session: any,
	Providers: { [string]: any },
	Anchor: any,
}

export type Suggestions = typeof(setmetatable({} :: Fields, Suggestions))


--// context -----------------------------------------------------------------------
export type Context = {
	Kind: "Command" | "Player" | "Reference" | "Argument" | "Flag" | "Stack" | "None",
	Prefix: string,
	Argument: any?,
	Command: any?,
}

--// Kyn's own vocabulary. Always offerable after `@`, because these exist
--// whether or not the player has defined anything yet
local BUILTINS = {
	"Set",
	"Unset",
	"Function",
	"Players",
	"Vector3",
	"Color3",
	"Enum",
}

--- Works out what the caret is sitting on.
function Suggestions.Context(raw: string, cursor: number?, registry: any): Context
	--// `CursorPosition` is -1 on an unfocused TextBox and can arrive nil from a
	--// caller that has not got one at all. Either way the sensible reading is
	--// "the caret is at the end", and doing arithmetic on it first is how the
	--// whole change handler used to die
	local caret = if type(cursor) == "number" and cursor >= 1 then cursor else #raw + 1

	local upto = string.sub(raw, 1, math.max(0, caret - 1))
	local segment = LineParser.SegmentAt(raw, caret)

	local within = string.sub(upto, segment.Start)
	local tokens = LineParser.Tokenize(within)

	--// the word being typed, which is the last token when there is no trailing
	--// space, and an empty prefix when there is
	local trailing = string.sub(upto, -1) == " "
	local current = if trailing then "" else (tokens[#tokens] and tokens[#tokens].Text or "")
	local position = if trailing then #tokens + 1 else #tokens

	--// `::Kout`, the stack reference
	if string.sub(current, 1, 2) == "::" then
		return { Kind = "Stack", Prefix = string.sub(current, 3) }
	end

	--// `--Flag`, which needs the command at the head of this segment to know
	--// what flags even exist
	if string.sub(current, 1, 2) == "--" then
		local head = tokens[1] and tokens[1].Text
		local definition = head and registry and registry:Resolve(head)

		return { Kind = "Flag", Prefix = string.sub(current, 3), Command = definition }
	end

	if string.sub(current, 1, 1) == "@" then
		local body = string.sub(current, 2)
		local dot = string.find(body, ".", 1, true)

		if dot then
			local namespace = string.sub(body, 1, dot - 1)

			if string.lower(namespace) == "players" then
				return { Kind = "Player", Prefix = string.sub(body, dot + 1) }
			end

			return { Kind = "None", Prefix = body }
		end

		return { Kind = "Reference", Prefix = body }
	end

	if position <= 1 then
		return { Kind = "Command", Prefix = current }
	end

	--// a positional slot on a command we know about
	local head = tokens[1] and tokens[1].Text
	local definition = head and registry and registry:Resolve(head)

	if definition then
		local index = position - 1
		local argument = definition.Parsed[index]

		if argument then
			return { Kind = "Argument", Prefix = current, Argument = argument }
		end
	end

	return { Kind = "None", Prefix = current }
end

--// public api ---------------------------------------------------------------------
function Suggestions.new(app: any, theme: any, registry: any, session: any, providers: { [string]: any }): Suggestions
	local panel = app:panel("popover")
		:setRadius(theme.Radius.Suggestion)
		:setPadding(0, 4)
		:setMaxSize(100000, theme.Size.MaxSuggestions * theme.Size.SuggestionHeight + 8)
		:setBorder(false)
		:setColor(theme.Color.Surface)
		:setTransparency(theme.Transparency.Suggestion)

	local suggest = panel:suggest()

	suggest:setLimit(theme.Size.MaxSuggestions)

	local self: Fields = {
		Theme = theme,
		Panel = panel,
		Suggest = suggest,
		Registry = registry,
		Session = session,
		Providers = providers,
		Anchor = nil,
	}

	return setmetatable(self, Suggestions)
end

--- Recomputes the source list for the caret's context, then shows or hides.
function Suggestions.Update(self: Suggestions, raw: string, cursor: number?)
	--// nothing typed, nothing to suggest. Without this, submitting a command
	--// clears the field, which fires a change with an empty prefix, which
	--// matches every command — so the dropdown reappears the instant you hit
	--// Enter
	if raw == "" then
		Suggestions.Hide(self)

		return
	end

	local context = Suggestions.Context(raw, cursor, self.Registry)
	local options: { string } = {}

	if context.Kind == "Command" then
		options = self.Registry:CommandNames()
	elseif context.Kind == "Player" then
		for _, player in Players:GetPlayers() do
			table.insert(options, player.Name)
		end
	elseif context.Kind == "Reference" then
		--// Kyn's builtins, then session variables, then session functions and
		--// the natives folded in with them
		for _, name in BUILTINS do
			table.insert(options, name)
		end

		for _, name in self.Session:VariableNames() do
			table.insert(options, name)
		end

		for _, name in self.Session:FunctionNames() do
			table.insert(options, name)
		end
	elseif context.Kind == "Stack" then
		options = { "Kout" }
	elseif context.Kind == "Flag" then
		local definition = context.Command

		for _, flag in (definition and definition.Flags) or {} do
			table.insert(options, flag.Name)

			for _, alias in flag.Aliases or {} do
				table.insert(options, alias)
			end
		end
	elseif context.Kind == "Argument" then
		local argument = context.Argument
		local provider = argument and self.Providers[argument.Type]

		if provider then
			options = provider.Suggest(context.Prefix, argument)
		end
	end

	if #options == 0 then
		Suggestions.Hide(self)

		return
	end

	self.Suggest:setSource(options)
	self.Suggest:setQuery(context.Prefix)

	if #(self.Suggest :: any).matches == 0 then
		Suggestions.Hide(self)

		return
	end

	Suggestions.Show(self)
end

--- Anchors the dropdown to a panel and points it at that window's field.
---
--- `setField` rather than `attach`: attaching would make the list filter itself
--- from the raw text, and Kyn needs the caret's context — `@Players.` means
--- players, `--` means flags. The field reference is still needed so accepting
--- writes into it and the ghost hint lands after the caret.
function Suggestions.Attach(self: Suggestions, anchor: any, field: any)
	self.Anchor = anchor

	if field then
		self.Suggest:setField(field)
	end
end

function Suggestions.Show(self: Suggestions)
	if not self.Anchor then
		return
	end

	local theme = self.Theme

	self.Panel:setWidth(math.max(theme.Size.CollapsedWidth, self.Anchor.instance.AbsoluteSize.X))
	self.Panel:attachTo(self.Anchor.instance, "top", theme.Spacing.SuggestionGap)
	self.Panel:open()
end

function Suggestions.Hide(self: Suggestions)
	self.Panel:close()
end

function Suggestions.Visible(self: Suggestions): boolean
	return self.Panel:isOpen()
end

function Suggestions.Next(self: Suggestions)
	self.Suggest:next()
end

function Suggestions.Previous(self: Suggestions)
	self.Suggest:previous()
end

--- Accepts the highlighted match and puts the caret after it.
---
--- No cleanup pass. The Tab that triggered this is sunk by the console's
--- action binding, so it never reaches the field — an earlier version wrote
--- the completion and then tried to strip the tab that arrived afterwards,
--- which is a race the tab sometimes won.
function Suggestions.Accept(self: Suggestions)
	self.Suggest:accept()

	Suggestions.Hide(self)

	local field = (self.Suggest :: any).field

	if not field then
		return
	end

	--// leave the caret at the end of what was just completed, so typing
	--// continues the line rather than landing mid-word
	local box = (field :: any).refs.input :: TextBox

	box.CursorPosition = #box.Text + 1
end

--- The match currently ghosted after the caret, if any. Tab accepts this even
--- when the dropdown is closed, which is what makes inline completion work
--- without the list in the way.
function Suggestions.Highlighted(self: Suggestions): any
	return self.Suggest:highlighted()
end

function Suggestions.Destroy(self: Suggestions)
	self.Panel:destroy()
end

return Suggestions
