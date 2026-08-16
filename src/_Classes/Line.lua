--!strict

--- The Kyn parser: raw text in, `LineAST` out.
---
--- This module is **pure**. It tokenises, splits on chain operators and pipes,
--- and classifies each word into a typed node. It never resolves a `@Ref`,
--- never touches a session, and never runs a command — that is
--- `_Classes/Input.lua`'s job. Keeping the split means the grammar can be
--- tested without a player, a registry or a network.
---
--- Tokenising is depth-aware: quotes, parentheses and braces all suppress
--- splitting, so `@Vector3(1, 2, 3)` stays one token and
--- `@Function Greet { return "Hi" }` keeps its block intact.

local Types = require(script.Parent.Parent.Types)

type WordNode = Types.WordNode
type FlagNode = Types.FlagNode
type PipelineStage = Types.PipelineStage
type ChainSegment = Types.ChainSegment
type LineAST = Types.LineAST

local Line = {}

export type Token = {
	Text: string,
	Kind: "Word" | "Op",
	Start: number,
	Finish: number,
}

local CHAINERS: { [string]: boolean } = { [":"] = true, [">>"] = true, ["->"] = true }

--// locals ---------------------------------------------------------------------
--- Strips a `#` comment. Deliberately **not** quote-aware — the spec calls this
--- out as naive by design, so `echo "# not a comment"` does lose its tail.
local function stripComment(text: string): string
	local at = string.find(text, "#", 1, true)

	if not at then
		return text
	end

	return string.sub(text, 1, at - 1)
end

local function isSpace(char: string): boolean
	return char == " " or char == "\t" or char == "\n" or char == "\r"
end

--- Splits on a separator at depth zero, respecting quotes and nesting. Used for
--- call arguments, where `@Vector3(1, 2, 3)` inside `@Move(@Vector3(1,2,3), 4)`
--- must not be torn apart by the comma inside it.
local function splitDepth(text: string, separator: string): { string }
	local parts: { string } = {}
	local current = {}

	local depth = 0
	local quoted = false
	local escaped = false

	for index = 1, #text do
		local char = string.sub(text, index, index)

		if escaped then
			table.insert(current, char)
			escaped = false
			continue
		end

		if char == "\\" and quoted then
			table.insert(current, char)
			escaped = true
			continue
		end

		if char == '"' then
			quoted = not quoted
			table.insert(current, char)
			continue
		end

		if not quoted then
			if char == "(" or char == "{" then
				depth += 1
			elseif char == ")" or char == "}" then
				depth -= 1
			end

			if char == separator and depth == 0 then
				table.insert(parts, table.concat(current))
				current = {}
				continue
			end
		end

		table.insert(current, char)
	end

	table.insert(parts, table.concat(current))

	return parts
end

local function trim(text: string): string
	return (string.match(text, "^%s*(.-)%s*$")) or text
end

--// tokenising ------------------------------------------------------------------
--- Splits a line into word and operator tokens, carrying each token's character
--- range so the interface can map a cursor position back onto a segment.
function Line.Tokenize(raw: string): { Token }
	local text = stripComment(raw)
	local tokens: { Token } = {}

	local current = {}
	local start = 1

	local depth = 0
	local quoted = false
	local escaped = false

	local index = 1

	local function flush(finish: number)
		if #current == 0 then
			return
		end

		table.insert(tokens, {
			Text = table.concat(current),
			Kind = "Word",
			Start = start,
			Finish = finish,
		})

		current = {}
	end

	while index <= #text do
		local char = string.sub(text, index, index)
		local nextChar = string.sub(text, index + 1, index + 1)

		if escaped then
			table.insert(current, char)
			escaped = false
			index += 1
			continue
		end

		if char == "\\" and quoted then
			table.insert(current, char)
			escaped = true
			index += 1
			continue
		end

		if char == '"' then
			if #current == 0 then
				start = index
			end

			quoted = not quoted
			table.insert(current, char)
			index += 1
			continue
		end

		if quoted then
			table.insert(current, char)
			index += 1
			continue
		end

		if char == "(" or char == "{" then
			if #current == 0 then
				start = index
			end

			depth += 1
			table.insert(current, char)
			index += 1
			continue
		end

		if char == ")" or char == "}" then
			depth -= 1
			table.insert(current, char)
			index += 1
			continue
		end

		if depth > 0 then
			if #current == 0 then
				start = index
			end

			table.insert(current, char)
			index += 1
			continue
		end

		--// operators, longest first so `->` never reads as `-`
		if char == "-" and nextChar == ">" then
			flush(index - 1)
			table.insert(tokens, { Text = "->", Kind = "Op", Start = index, Finish = index + 1 })
			index += 2
			continue
		end

		if char == ">" and nextChar == ">" then
			flush(index - 1)
			table.insert(tokens, { Text = ">>", Kind = "Op", Start = index, Finish = index + 1 })
			index += 2
			continue
		end

		--// `::Kout` also begins with a colon. Consume the pair outright rather
		--// than only skipping the first one, or the SECOND colon reads as the
		--// chain operator and splits the stack ref in half
		if char == ":" and nextChar == ":" then
			if #current == 0 then
				start = index
			end

			table.insert(current, "::")
			index += 2
			continue
		end

		if char == ":" then
			flush(index - 1)
			table.insert(tokens, { Text = ":", Kind = "Op", Start = index, Finish = index })
			index += 1
			continue
		end

		if char == "|" then
			flush(index - 1)
			table.insert(tokens, { Text = "|", Kind = "Op", Start = index, Finish = index })
			index += 1
			continue
		end

		if isSpace(char) then
			flush(index - 1)
			index += 1
			continue
		end

		if #current == 0 then
			start = index
		end

		table.insert(current, char)
		index += 1
	end

	flush(#text)

	return tokens
end

--// word classification ----------------------------------------------------------
local function unquote(text: string): string
	local inner = string.sub(text, 2, #text - 1)

	inner = string.gsub(inner, '\\"', '"')
	inner = string.gsub(inner, "\\\\", "\\")

	return inner
end

--- Turns one token into a typed `WordNode`.
function Line.Word(token: string): WordNode
	if token == "" then
		return { Kind = "Bareword", Value = "" }
	end

	if string.sub(token, 1, 1) == '"' and string.sub(token, -1) == '"' and #token >= 2 then
		return { Kind = "String", Value = unquote(token) }
	end

	local number = tonumber(token)

	if number then
		return { Kind = "Number", Value = number }
	end

	local lowered = string.lower(token)

	if lowered == "true" then
		return { Kind = "Boolean", Value = true }
	elseif lowered == "false" then
		return { Kind = "Boolean", Value = false }
	end

	--// `::Kout` and `::Kout(n)`. Bare and `(0)` mean the same thing: n counts
	--// ADDITIONAL steps back from the most recent result
	if string.sub(token, 1, 2) == "::" then
		local name, argument = string.match(token, "^::(%a+)%((%-?%d+)%)$")

		if name and string.lower(name) == "kout" then
			return { Kind = "StackRef", Depth = tonumber(argument) or 0 }
		end

		if string.lower(string.sub(token, 3)) == "kout" then
			return { Kind = "StackRef", Depth = 0 }
		end
	end

	if string.sub(token, 1, 1) == "@" then
		local body = string.sub(token, 2)
		local call: { WordNode }? = nil

		local open = string.find(body, "(", 1, true)

		if open and string.sub(body, -1) == ")" then
			local inner = string.sub(body, open + 1, #body - 1)

			body = string.sub(body, 1, open - 1)
			call = {}

			if trim(inner) ~= "" then
				for _, piece in splitDepth(inner, ",") do
					table.insert(call :: { WordNode }, Line.Word(trim(piece)))
				end
			end
		end

		local path: { string } = {}

		for piece in string.gmatch(body, "[^%.]+") do
			table.insert(path, piece)
		end

		return { Kind = "Ref", Path = path, Call = call }
	end

	return { Kind = "Bareword", Value = token }
end

--// stage parsing -----------------------------------------------------------------
local function parseStage(tokens: { Token }): PipelineStage?
	if #tokens == 0 then
		return nil
	end

	local head = tokens[1].Text

	--// `@Function Name { return Word }`
	if string.lower(head) == "@function" then
		local name = tokens[2] and tokens[2].Text or ""
		local block = tokens[3] and tokens[3].Text or ""

		local inner = string.match(block, "^%{(.*)%}$") or ""
		local returned = string.match(inner, "^%s*return%s+(.-)%s*$")

		return {
			Kind = "FunctionDecl",
			Name = name,
			Body = Line.Word(returned or trim(inner)),
		}
	end

	--// a stage that is only a reference is a call, not a command
	if string.sub(head, 1, 1) == "@" and #tokens == 1 then
		return { Kind = "RefCall", Ref = Line.Word(head) }
	end

	local args: { WordNode } = {}
	local flags: { FlagNode } = {}

	for index = 2, #tokens do
		local token = tokens[index].Text

		if string.sub(token, 1, 2) == "--" then
			local body = string.sub(token, 3)
			local name, value = string.match(body, "^([^=]+)=(.*)$")

			if name then
				table.insert(flags, { Name = name, Value = Line.Word(value) })
			else
				table.insert(flags, { Name = body, Value = nil })
			end
		else
			table.insert(args, Line.Word(token))
		end
	end

	return {
		Kind = "Command",
		Head = head,
		Args = args,
		Flags = flags,
	}
end

--// public api ---------------------------------------------------------------------
--- Parses a line into its AST. Never throws; a malformed line comes back with
--- `Error` set and whatever segments were recoverable.
function Line.Parse(raw: string): LineAST
	local tokens = Line.Tokenize(raw or "")

	local segments: { ChainSegment } = {}

	local stages: { PipelineStage } = {}
	local pending: { Token } = {}

	local function closeStage()
		local stage = parseStage(pending)

		if stage then
			table.insert(stages, stage)
		end

		pending = {}
	end

	--// `Op` belongs to the segment BEFORE the operator, because that is the
	--// question the evaluator asks: did the previous segment resolve, and what
	--// joined it to this one?
	local function closeSegment(operator: string?)
		closeStage()

		if #stages > 0 then
			table.insert(segments, { Pipeline = stages, Op = operator })
		end

		stages = {}
	end

	for _, token in tokens do
		if token.Kind == "Op" then
			if token.Text == "|" then
				closeStage()
			elseif CHAINERS[token.Text] then
				closeSegment(token.Text)
			end
		else
			table.insert(pending, token)
		end
	end

	closeSegment(nil)

	local ast: LineAST = { Segments = segments }

	if #segments == 0 and trim(stripComment(raw or "")) ~= "" then
		ast.Error = "nothing to run"
	end

	return ast
end

--- Character ranges of each chain segment, for cursor navigation.
---
--- `Interface/Elements/Input.lua` uses this for `Ctrl+Up`/`Ctrl+Down` so that
--- "jump to the start of this segment" uses the same `:` / `>>` / `->` split
--- the parser does, instead of a second lightweight copy that can drift.
function Line.SegmentRanges(raw: string): { { Start: number, Finish: number } }
	local tokens = Line.Tokenize(raw or "")
	local ranges = {}

	local first: Token? = nil
	local last: Token? = nil

	local function close()
		if first and last then
			table.insert(ranges, { Start = first.Start, Finish = last.Finish })
		end

		first, last = nil, nil
	end

	for _, token in tokens do
		if token.Kind == "Op" and CHAINERS[token.Text] then
			close()
		elseif token.Kind == "Word" then
			first = first or token
			last = token
		end
	end

	close()

	if #ranges == 0 then
		table.insert(ranges, { Start = 1, Finish = math.max(1, #(raw or "")) })
	end

	return ranges
end

--- The segment containing a cursor position, as a range. Falls back to the
--- nearest segment when the cursor sits on an operator between two of them.
function Line.SegmentAt(raw: string, cursor: number): { Start: number, Finish: number }
	local ranges = Line.SegmentRanges(raw)

	for _, range in ranges do
		if cursor >= range.Start and cursor <= range.Finish + 1 then
			return range
		end
	end

	for index = #ranges, 1, -1 do
		if ranges[index].Start <= cursor then
			return ranges[index]
		end
	end

	return ranges[1]
end

return Line
