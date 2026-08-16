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

local Players = game:GetService("Players")

local LineParser = require(script.Parent.Parent.Parent.Parent._Classes.Line)
local Packages = require(script.Parent.Parent.Parent.Parent._Packages)

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

local Lume = Packages.Lume()

--// context -----------------------------------------------------------------------
export type Context = {
	Kind: "Command" | "Player" | "Reference" | "Argument" | "None",
	Prefix: string,
	Argument: any?,
}

--- Works out what the caret is sitting on.
function Suggestions.Context(raw: string, cursor: number, registry: any): Context
	local upto = string.sub(raw, 1, math.max(0, cursor - 1))
	local segment = LineParser.SegmentAt(raw, cursor)

	local within = string.sub(upto, segment.Start)
	local tokens = LineParser.Tokenize(within)

	--// the word being typed, which is the last token when there is no trailing
	--// space, and an empty prefix when there is
	local trailing = string.sub(upto, -1) == " "
	local current = if trailing then "" else (tokens[#tokens] and tokens[#tokens].Text or "")
	local position = if trailing then #tokens + 1 else #tokens

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
function Suggestions.Update(self: Suggestions, raw: string, cursor: number)
	local context = Suggestions.Context(raw, cursor, self.Registry)
	local options: { string } = {}

	if context.Kind == "Command" then
		options = self.Registry:CommandNames()
	elseif context.Kind == "Player" then
		for _, player in Players:GetPlayers() do
			table.insert(options, player.Name)
		end
	elseif context.Kind == "Reference" then
		--// session variables, session functions, and the natives — which used
		--// to be missing from this list (open item #8)
		for _, name in self.Session:VariableNames() do
			table.insert(options, name)
		end

		for _, name in self.Session:FunctionNames() do
			table.insert(options, name)
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

function Suggestions.Attach(self: Suggestions, anchor: any)
	self.Anchor = anchor
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

function Suggestions.Accept(self: Suggestions)
	self.Suggest:accept()

	Suggestions.Hide(self)
end

function Suggestions.Destroy(self: Suggestions)
	self.Panel:destroy()
end

return Suggestions
