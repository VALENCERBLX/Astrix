--!nocheck
--- Docket — generated single-file bundle. Do not edit; regenerate with
--- `lune run scripts/build-bundle` in the Docket repo.
--- Usage: `lune run Docket [path/to/project]` · https://github.com/mkl48/Docket

local __lune_fs = require("@lune/fs")
local __lune_luau = require("@lune/luau")
local __lune_process = require("@lune/process")

local __modules: { [string]: () -> any } = {}
local __cache: { [string]: any } = {}
local function __require(name: string): any
	if __cache[name] == nil then
		__cache[name] = __modules[name]()
	end
	return __cache[name]
end

__modules["Lexer"] = function()
--- Minimal Luau tokenizer shared by [[Scanner]] and [[Highlight]]. Tokens
--- cover the whole source — whitespace and newlines included — so raw text
--- can always be reconstructed from positions, which is how signatures end up
--- in the docs exactly as the code spells them.
---
--- It understands line and long-bracket comments, quoted and long-bracket
--- strings, backtick interpolation, numbers, names vs. keywords, and Luau's
--- compound symbols (`->`, `::`, `..=`, …). It is deliberately *not* a full
--- parser: Docket only needs declaration-level structure.
--- @section Text & Tokens

local Lexer = {}

type TokenType = "comment" | "string" | "number" | "name" | "keyword" | "symbol" | "space" | "newline" | "unknown"

--- One token. `pos` is the 1-based start index into the source, so
--- `string.sub(source, a.pos, b.pos + #b.text - 1)` recovers any raw slice.
type Token = {
	type: TokenType,
	text: string,
	line: number,
	pos: number, -- 1-based start index into the source
}

local KEYWORDS: { [string]: boolean } = {}
for word in string.gmatch(
	"and break continue do else elseif end false for function if in local nil not or repeat return then true until while",
	"%S+"
) do
	KEYWORDS[word] = true
end

local SYMBOLS3 = { ["..."] = true, ["..="] = true }
local SYMBOLS2 = {
	["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true,
	["->"] = true, ["::"] = true, ["+="] = true, ["-="] = true, ["*="] = true,
	["/="] = true, ["%="] = true, ["^="] = true, ["//"] = true,
}

--- Tokenizes Luau source. Never errors on malformed input — unterminated
--- strings and brackets just close at the newline or end of file.
--- @param source Luau source text
function Lexer.Scan(source: string): { Token }
	local tokens: { Token } = {}
	local i = 1
	local line = 1
	local n = #source

	local function push(tokenType: TokenType, startIndex: number, endIndex: number)
		tokens[#tokens + 1] = {
			type = tokenType,
			text = string.sub(source, startIndex, endIndex),
			line = line,
			pos = startIndex,
		}
	end

	-- called with `start` on a '['; returns the end index of a [=*[ ... ]=*] bracket, or nil
	local function longBracket(start: number): number?
		local j = start + 1
		local equals = 0
		while string.sub(source, j, j) == "=" do
			equals += 1
			j += 1
		end
		if string.sub(source, j, j) ~= "[" then
			return nil
		end
		local close = "]" .. string.rep("=", equals) .. "]"
		local closeStart = string.find(source, close, j + 1, true)
		return if closeStart then closeStart + #close - 1 else n
	end

	local function countLines(startIndex: number, endIndex: number)
		for _ in string.gmatch(string.sub(source, startIndex, endIndex), "\n") do
			line += 1
		end
	end

	while i <= n do
		local c = string.sub(source, i, i)
		if c == "\n" then
			push("newline", i, i)
			line += 1
			i += 1
		elseif c == " " or c == "\t" or c == "\r" then
			local start = i
			repeat
				i += 1
				c = string.sub(source, i, i)
			until not (c == " " or c == "\t" or c == "\r")
			push("space", start, i - 1)
		elseif c == "-" and string.sub(source, i + 1, i + 1) == "-" then
			local start = i
			local longEnd = if string.sub(source, i + 2, i + 2) == "[" then longBracket(i + 2) else nil
			if longEnd then
				push("comment", start, longEnd)
				countLines(start, longEnd)
				i = longEnd + 1
			else
				local newlineAt = string.find(source, "\n", i, true)
				local commentEnd = if newlineAt then newlineAt - 1 else n
				push("comment", start, commentEnd)
				i = commentEnd + 1
			end
		elseif c == "\"" or c == "'" or c == "`" then
			local start = i
			i += 1
			while i <= n do
				local sc = string.sub(source, i, i)
				if sc == "\\" then
					i += 2
				elseif sc == c or sc == "\n" then
					break
				else
					i += 1
				end
			end
			if string.sub(source, i, i) == c then
				push("string", start, i)
				i += 1
			else
				push("string", start, i - 1) -- unterminated; stop at the newline
			end
		elseif c == "[" and (string.sub(source, i + 1, i + 1) == "[" or string.sub(source, i + 1, i + 1) == "=") then
			local longEnd = longBracket(i)
			if longEnd then
				push("string", i, longEnd)
				countLines(i, longEnd)
				i = longEnd + 1
			else
				push("symbol", i, i)
				i += 1
			end
		elseif string.match(c, "%d") or (c == "." and string.match(string.sub(source, i + 1, i + 1), "%d")) then
			local start = i
			repeat
				i += 1
				c = string.sub(source, i, i)
			until not string.match(c, "[%w_%.]")
			push("number", start, i - 1)
		elseif string.match(c, "[%a_]") then
			local start = i
			repeat
				i += 1
				c = string.sub(source, i, i)
			until not string.match(c, "[%w_]")
			local text = string.sub(source, start, i - 1)
			push(if KEYWORDS[text] then "keyword" else "name", start, i - 1)
		else
			if SYMBOLS3[string.sub(source, i, i + 2)] then
				push("symbol", i, i + 2)
				i += 3
			elseif SYMBOLS2[string.sub(source, i, i + 1)] then
				push("symbol", i, i + 1)
				i += 2
			else
				push("symbol", i, i)
				i += 1
			end
		end
	end

	return tokens
end

return Lexer

end

__modules["Toml"] = function()
--- Just enough TOML to read a `wally.toml`: `[sections]` (dotted paths
--- included) and string / number / boolean keys. Arrays and inline tables are
--- skipped rather than errored on — Docket only needs `package.name`,
--- `package.version`, and `package.license`.
--- @section Support

local Toml = {}

type Table = { [string]: any }

--- Parses TOML source into nested tables.
--- @param source TOML text
function Toml.Parse(source: string): Table
	local root: Table = {}
	local current = root

	for rawLine in string.gmatch(source .. "\n", "(.-)\n") do
		local line = string.match(rawLine, "^%s*(.-)%s*$") :: string
		if line == "" or string.sub(line, 1, 1) == "#" then
			continue
		end

		local sectionPath = string.match(line, "^%[([%w%._%-]+)%]$")
		if sectionPath then
			current = root
			for part in string.gmatch(sectionPath, "[^%.]+") do
				if type(current[part]) ~= "table" then
					current[part] = {}
				end
				current = current[part]
			end
			continue
		end

		local key, rawValue = string.match(line, "^([%w_%-]+)%s*=%s*(.+)$")
		if not key or not rawValue then
			continue
		end

		local quoted = string.match(rawValue, '^"(.-)"') or string.match(rawValue, "^'(.-)'")
		if quoted ~= nil then
			current[key] = quoted
		elseif rawValue == "true" or rawValue == "false" then
			current[key] = rawValue == "true"
		else
			local numeric = tonumber(string.match(rawValue, "^[%d%.%-+eE_]+") :: any)
			if numeric then
				current[key] = numeric
			end
			-- arrays / inline tables: intentionally ignored
		end
	end

	return root
end

return Toml

end

__modules["Highlight"] = function()
--- Syntax highlighting via [[Lexer.Scan]], emitting the template's three
--- semantic spans — keywords, strings/numbers, comments — in the Junky page's
--- restrained style. Everything else renders in plain ink, so signatures and
--- examples stay readable rather than rainbow-colored.
--- @section Text & Tokens

local Lexer = __require("Lexer")

local Highlight = {}

local SOFT_KEYWORDS: { [string]: boolean } = {
	["type"] = true,
	["export"] = true,
	["self"] = true,
}

local function escape(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

--- Highlights Luau source into escaped HTML with `.kw` / `.st` / `.cm` spans.
--- @param source Luau source text (a signature, a type body, an example)
function Highlight.Render(source: string): string
	local parts: { string } = {}
	for _, token in Lexer.Scan(source) do
		local escaped = escape(token.text)
		if token.type == "comment" then
			parts[#parts + 1] = `<span class="cm">{escaped}</span>`
		elseif token.type == "string" or token.type == "number" then
			parts[#parts + 1] = `<span class="st">{escaped}</span>`
		elseif token.type == "keyword" or (token.type == "name" and SOFT_KEYWORDS[token.text]) then
			parts[#parts + 1] = `<span class="kw">{escaped}</span>`
		else
			parts[#parts + 1] = escaped
		end
	end
	return table.concat(parts)
end

return Highlight

end

__modules["Scanner"] = function()
--- Walks a token stream, collects `---` doc blocks, and parses the declaration
--- each block is attached to — this is where "the signature is the truth" happens.
---
--- Attachment is positional. A block followed immediately by a declaration
--- documents that member; a block at the top of a file followed by a blank
--- line (or a `local Name = {}` table) documents the module; anything else
--- floats and is ignored with a warning.
---
--- The scanner understands dotted and method `function` names, generics,
--- balanced multi-line parameter lists, return-type annotations (including
--- union continuations), and multi-line `type` bodies. Function signatures
--- collapse to one line; type definitions keep their shape and are dedented.
--- Documented `local function`s are treated as private and never rendered.
--- @section Pipeline

local Lexer = __require("Lexer")

local Scanner = {}

--- One parsed declaration. `signature` is reconstructed from the raw source —
--- one normalized line for functions, dedented original text for types.
type Declaration = {
	kind: "function" | "type" | "table",
	name: string,
	signature: string,
	line: number,
	isLocal: boolean?,
}

--- A doc block paired with what it documents. `decl` is nil for a floating
--- block (which [[Model.Build]] treats as the module doc when it comes first).
type Entry = {
	docLines: { string },
	decl: Declaration?,
	line: number,
}

type ScanResult = {
	entries: { Entry },
	warnings: { string },
}

type Token = Lexer.Token

local function isDocComment(token: Token): boolean
	return token.type == "comment"
		and string.sub(token.text, 1, 3) == "---"
		and string.sub(token.text, 1, 4) ~= "----"
end

local function stripDocPrefix(text: string): string
	return (string.gsub(text, "^%-%-%-%s?", "", 1))
end

--- collapse a raw source slice into a one-line signature
local function normalize(raw: string): string
	local collapsed = string.gsub(raw, "%s+", " ")
	return (string.match(collapsed, "^%s*(.-)%s*$")) :: string
end

--- strip the common leading indentation from a multi-line slice
local function dedent(raw: string): string
	local minIndent: number? = nil
	for _, indentText in string.gmatch(raw, "\n( *)(%S)") do
		local width = #indentText
		if minIndent == nil or width < minIndent then
			minIndent = width
		end
	end
	if minIndent and minIndent > 0 then
		raw = string.gsub(raw, "\n" .. string.rep(" ", minIndent), "\n")
	end
	return raw
end

--- Scans one file's source into doc [[Entry]] pairs.
--- @param source the file's Luau source text
--- @param path used to prefix warnings, e.g. `src/Chunk.luau:41: …`
function Scanner.Scan(source: string, path: string?): ScanResult
	local tokens = Lexer.Scan(source)
	local entries: { Entry } = {}
	local warnings: { string } = {}
	local where = path or "<source>"

	local function warn(message: string, line: number)
		warnings[#warnings + 1] = `{where}:{line}: {message}`
	end

	-- index helpers -------------------------------------------------------

	local function nextSignificant(index: number, skipNewlines: boolean?): number?
		local k = index
		while k <= #tokens do
			local t = tokens[k].type
			if t == "space" or (skipNewlines and (t == "newline" or t == "comment")) then
				k += 1
			else
				return k
			end
		end
		return nil
	end

	local function sliceEnd(token: Token): number
		return token.pos + #token.text - 1
	end

	-- declaration parsing --------------------------------------------------
	-- each parser returns (declaration?, nextIndex)

	local OPEN = { ["("] = true, ["{"] = true, ["<"] = true, ["["] = true }
	local CLOSE = { [")"] = true, ["}"] = true, [">"] = true, ["]"] = true }

	-- consume a type expression starting at `index` until a newline at depth 0;
	-- keeps going past the newline when the type continues with `|` or `&`
	local function consumeTypeExpression(index: number): (number, number)
		local depth = 0
		local lastCode = index
		local k = index
		while k <= #tokens do
			local token = tokens[k]
			if token.type == "symbol" and OPEN[token.text] then
				depth += 1
			elseif token.type == "symbol" and CLOSE[token.text] then
				depth -= 1
			elseif token.type == "newline" and depth <= 0 then
				local peek = nextSignificant(k + 1, true)
				local continues = peek
					and tokens[peek].type == "symbol"
					and (tokens[peek].text == "|" or tokens[peek].text == "&")
				if not continues then
					return lastCode, k
				end
			end
			if token.type ~= "space" and token.type ~= "newline" and token.type ~= "comment" then
				lastCode = k
			end
			k += 1
		end
		return lastCode, k
	end

	local function parseFunction(startIndex: number): (Declaration?, number)
		-- startIndex sits on `local` or `function`
		local k = startIndex
		local isLocal = false
		if tokens[k].text == "local" then
			isLocal = true
			local afterLocal = nextSignificant(k + 1)
			if not afterLocal or tokens[afterLocal].text ~= "function" then
				return nil, startIndex
			end
			k = afterLocal
		end
		local startToken = tokens[k]

		-- dotted / method name
		local nameParts: { string } = {}
		local j = nextSignificant(k + 1)
		while j and tokens[j].type == "name" do
			nameParts[#nameParts + 1] = tokens[j].text
			local sep = nextSignificant(j + 1)
			if sep and tokens[sep].type == "symbol" and (tokens[sep].text == "." or tokens[sep].text == ":") then
				nameParts[#nameParts + 1] = tokens[sep].text
				j = nextSignificant(sep + 1)
			else
				j = sep
				break
			end
		end
		if #nameParts == 0 or not j then
			return nil, startIndex
		end

		-- optional generics, then the parameter list
		if tokens[j].type == "symbol" and tokens[j].text == "<" then
			local depth = 0
			while j and j <= #tokens do
				if tokens[j].type == "symbol" and tokens[j].text == "<" then
					depth += 1
				elseif tokens[j].type == "symbol" and tokens[j].text == ">" then
					depth -= 1
					if depth == 0 then
						j = nextSignificant(j + 1, true)
						break
					end
				end
				j += 1
			end
		end
		if not j or tokens[j].text ~= "(" then
			return nil, startIndex
		end

		local depth = 0
		local closeIndex: number? = nil
		local k2 = j
		while k2 <= #tokens do
			local token = tokens[k2]
			if token.type == "symbol" and token.text == "(" then
				depth += 1
			elseif token.type == "symbol" and token.text == ")" then
				depth -= 1
				if depth == 0 then
					closeIndex = k2
					break
				end
			end
			k2 += 1
		end
		if not closeIndex then
			return nil, startIndex
		end

		local endIndex = closeIndex
		local afterClose = nextSignificant(closeIndex + 1)
		if afterClose and tokens[afterClose].type == "symbol" and tokens[afterClose].text == ":" then
			local typeStart = nextSignificant(afterClose + 1)
			if typeStart then
				endIndex = consumeTypeExpression(typeStart)
			end
		end

		local raw = string.sub(source, startToken.pos, sliceEnd(tokens[endIndex]))
		return {
			kind = "function" :: "function",
			name = table.concat(nameParts),
			signature = normalize(raw),
			line = startToken.line,
			isLocal = isLocal,
		}, endIndex + 1
	end

	local function parseType(startIndex: number): (Declaration?, number)
		-- startIndex sits on `export` or `type`
		local k = startIndex
		if tokens[k].text == "export" then
			local afterExport = nextSignificant(k + 1)
			if not afterExport or tokens[afterExport].text ~= "type" then
				return nil, startIndex
			end
			k = afterExport
		end
		local nameIndex = nextSignificant(k + 1)
		if not nameIndex or tokens[nameIndex].type ~= "name" then
			return nil, startIndex
		end

		local equalsIndex = nameIndex + 1
		while equalsIndex <= #tokens do
			local token = tokens[equalsIndex]
			if token.type == "symbol" and token.text == "=" then
				break
			elseif token.type == "newline" then
				return nil, startIndex
			end
			equalsIndex += 1
		end
		if equalsIndex > #tokens then
			return nil, startIndex
		end

		local bodyStart = nextSignificant(equalsIndex + 1, true)
		if not bodyStart then
			return nil, startIndex
		end
		local endIndex = consumeTypeExpression(bodyStart)

		local raw = string.sub(source, tokens[startIndex].pos, sliceEnd(tokens[endIndex]))
		return {
			kind = "type" :: "type",
			name = tokens[nameIndex].text,
			signature = dedent(raw),
			line = tokens[startIndex].line,
		}, endIndex + 1
	end

	local function parseDeclaration(index: number): Declaration?
		local token = tokens[index]
		if token.type == "keyword" and (token.text == "function" or token.text == "local") then
			if token.text == "local" then
				local after = nextSignificant(index + 1)
				if after and tokens[after].type == "name" then
					-- `local Name = ...` — a module table; enough for module-doc attachment
					return {
						kind = "table" :: "table",
						name = tokens[after].text,
						signature = "",
						line = token.line,
					}
				end
			end
			local decl = parseFunction(index)
			return decl
		elseif token.type == "name" and (token.text == "type" or token.text == "export") then
			local decl = parseType(index)
			return decl
		end
		return nil
	end

	-- a doc block only starts on a comment that leads its line — a trailing
	-- `--- ...` after code (e.g. `x = 0 ---9`) is an ordinary comment
	local function isLineLeading(index: number): boolean
		local k = index - 1
		while k >= 1 do
			local kind = tokens[k].type
			if kind == "newline" then
				return true
			elseif kind == "space" then
				k -= 1
			else
				return false
			end
		end
		return true
	end

	-- main walk -------------------------------------------------------------

	local i = 1
	while i <= #tokens do
		local token = tokens[i]
		if isDocComment(token) and isLineLeading(i) then
			local docLines = { stripDocPrefix(token.text) }
			local blockLine = token.line
			local k = i + 1
			local declIndex: number? = nil

			while k <= #tokens do
				-- after each doc line: newline, optional indent, then the next thing
				if tokens[k].type ~= "newline" then
					break -- trailing doc comment after code on the same line; treat block as ended
				end
				local afterNewline = nextSignificant(k + 1)
				if not afterNewline then
					break
				end
				local nextToken = tokens[afterNewline]
				if isDocComment(nextToken) then
					docLines[#docLines + 1] = stripDocPrefix(nextToken.text)
					k = afterNewline + 1
				elseif nextToken.type == "newline" then
					break -- blank line: floating block
				else
					declIndex = afterNewline
					break
				end
			end

			local decl = if declIndex then parseDeclaration(declIndex) else nil
			if declIndex and not decl then
				warn("doc comment attached to an unrecognized declaration; ignored", blockLine)
			else
				entries[#entries + 1] = {
					docLines = docLines,
					decl = decl,
					line = blockLine,
				}
			end
			i = if declIndex then declIndex + 1 else k
		else
			i += 1
		end
	end

	return { entries = entries, warnings = warnings }
end

return Scanner

end

__modules["Grammar"] = function()
--- Parses the lines of one doc block into prose and tags. Deliberately small:
--- tags carry **no types**, because types come from the signature.
---
--- Everything that isn't a tag line is markdown prose; the first paragraph
--- becomes the summary. The full tag set:
---
--- - `@param name description` — prose only; validated against the signature
--- - `@return description` — the return *type* comes from the code
--- - `@server` / `@client` / `@shared` — realm badge, inherited module → members
--- - `@since version` — version badge on a member
--- - `@section Name` — module doc only: which sidebar group it lives under
--- - `@class Name` — module doc only: override the display name
---
--- Unknown tags warn. Tag-looking lines inside fenced code are left alone.
---
--- ```lua what a documented member looks like
--- --- Carves a crack through the chunk and detaches whatever disconnects.
--- ---
--- --- @param impulse world-space impulse that crossed the threshold
--- --- @server
--- function Chunk:Fracture(impulse: Vector3): { Model }
--- ```
--- @section Pipeline

local Grammar = {}

type Param = { name: string, desc: string }

--- One parsed doc block. `summary` and `body` hold markdown source — they are
--- rendered to HTML later, by [[Markdown.RenderLines]].
type Doc = {
	summary: string?, -- markdown source, first prose paragraph
	body: { string }, -- markdown source lines, everything after the summary
	params: { Param },
	returns: { string },
	realm: ("server" | "client" | "shared")?,
	since: string?,
	section: string?,
	class: string?,
}

type ParseResult = {
	doc: Doc,
	warnings: { string },
}

local REALMS: { [string]: boolean } = { server = true, client = true, shared = true }
local KNOWN: { [string]: boolean } = {
	param = true, ["return"] = true, since = true, section = true, class = true,
	server = true, client = true, shared = true,
}

--- Parses one block's stripped doc lines (from [[Entry]]) into a [[Doc]].
--- @param docLines the block's lines, `---` prefixes already removed
function Grammar.Parse(docLines: { string }): ParseResult
	local doc: Doc = {
		summary = nil,
		body = {},
		params = {},
		returns = {},
		realm = nil,
		since = nil,
		section = nil,
		class = nil,
	}
	local warnings: { string } = {}
	local prose: { string } = {}
	local inFence = false

	for _, line in docLines do
		if string.match(line, "^```") then
			inFence = not inFence
			prose[#prose + 1] = line
			continue
		end
		if inFence then
			prose[#prose + 1] = line
			continue
		end

		local tag, rest = string.match(line, "^@(%w+)%s*(.*)$")
		if not tag then
			prose[#prose + 1] = line
			continue
		end
		rest = rest :: string

		if tag == "param" then
			local name, desc = string.match(rest, "^([%w_%.]+)%s*(.*)$")
			if name then
				table.insert(doc.params, { name = name, desc = desc :: string })
			else
				warnings[#warnings + 1] = "@param needs a parameter name"
			end
		elseif tag == "return" then
			table.insert(doc.returns, rest)
		elseif REALMS[tag] then
			if doc.realm and doc.realm ~= tag then
				warnings[#warnings + 1] = `conflicting realm tags (@{doc.realm} and @{tag})`
			end
			doc.realm = tag :: any
		elseif tag == "since" then
			doc.since = rest
		elseif tag == "section" then
			doc.section = rest
		elseif tag == "class" then
			doc.class = rest
		elseif not KNOWN[tag] then
			warnings[#warnings + 1] = `unknown tag @{tag}`
		end
	end

	-- split prose into summary (first paragraph) and body
	local paragraphBreak: number? = nil
	local seenText = false
	for index, line in prose do
		if string.match(line, "^%s*$") then
			if seenText then
				paragraphBreak = index
				break
			end
		else
			seenText = true
		end
	end

	if seenText then
		local summaryEnd = if paragraphBreak then paragraphBreak - 1 else #prose
		local summaryLines = table.move(prose, 1, summaryEnd, 1, {})
		doc.summary = string.match(table.concat(summaryLines, " "), "^%s*(.-)%s*$")
		if paragraphBreak then
			doc.body = table.move(prose, paragraphBreak + 1, #prose, 1, {})
		end
	end

	return { doc = doc, warnings = warnings }
end

return Grammar

end

__modules["Markdown"] = function()
--- The small markdown dialect doc prose is written in: paragraphs, headings,
--- `- ` lists, fenced code blocks, inline code, **bold**, *italic*,
--- `[text](url)` links, and `[[CrossLink]]` references resolved at build time.
---
--- Fences become the page's captioned code component — text after the fence
--- language is the caption, and `lua`/`luau` blocks are syntax-highlighted by
--- [[Highlight.Render]]. Raw HTML is always escaped; prose cannot inject markup.
--- @section Text & Tokens

local Highlight = __require("Highlight")

local Markdown = {}

--- How the renderer talks back to the build: `resolve` turns a `[[Target]]`
--- into an href (nil = unresolved, which warns), `warn` collects messages.
type Options = {
	resolve: (target: string) -> string?, -- [[Target]] -> href, nil when unknown
	warn: (message: string) -> (),
}

local function escape(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

--- Renders one run of inline markdown (a summary, a cell, a list item).
--- Code spans are processed first and shield their contents from every later
--- pass, so `[[this]]` inside backticks stays literal.
--- @param text raw markdown source
--- @param opts link resolution + warning sinks
function Markdown.Inline(text: string, opts: Options): string
	local html = escape(text)

	-- code spans first, hidden behind placeholders so later passes skip them
	local stash: { string } = {}
	local function hide(rendered: string): string
		stash[#stash + 1] = rendered
		return "\0" .. #stash .. "\0"
	end

	html = string.gsub(html, "`([^`]+)`", function(code)
		return hide("<code>" .. code .. "</code>")
	end)

	html = string.gsub(html, "%[%[([^%]|]+)|?([^%]]*)%]%]", function(target, label)
		local shown = if label ~= "" then label else target
		local href = opts.resolve(target)
		if href then
			return hide(`<a href="{href}"><code>{shown}</code></a>`)
		end
		opts.warn(`unresolved link [[{target}]]`)
		return hide("<code>" .. shown .. "</code>")
	end)

	html = string.gsub(html, "%[([^%]]+)%]%((%S-)%)", function(label, url)
		return hide(`<a href="{url}">{label}</a>`)
	end)

	html = string.gsub(html, "%*%*([^*]+)%*%*", "<strong>%1</strong>")
	html = string.gsub(html, "%*([^*]+)%*", "<em>%1</em>")

	html = string.gsub(html, "%z(%d+)%z", function(index)
		return stash[tonumber(index) :: number]
	end)

	return html
end

--- one fenced code block -> the template's captioned .code component
local function renderCode(lang: string, caption: string, lines: { string }): string
	local source = table.concat(lines, "\n")
	local body = if lang == "lua" or lang == "luau" or lang == ""
		then Highlight.Render(source)
		else escape(source)
	local cap = if caption ~= "" then escape(caption) else "example"
	return '<div class="code"><div class="cap">' .. cap .. "</div><pre><code>" .. body .. "</code></pre></div>"
end

--- Renders block-level markdown over a [[Doc]] body's lines: paragraphs,
--- lists, and fenced code blocks.
--- @param lines markdown source lines, fences included
--- @param opts link resolution + warning sinks
function Markdown.RenderLines(lines: { string }, opts: Options): string
	local out: { string } = {}
	local paragraph: { string } = {}
	local listItems: { string } = {}

	local function flushParagraph()
		if #paragraph > 0 then
			out[#out + 1] = "<p>" .. Markdown.Inline(table.concat(paragraph, " "), opts) .. "</p>"
			table.clear(paragraph)
		end
	end
	local function flushList()
		if #listItems > 0 then
			out[#out + 1] = "<ul><li>" .. table.concat(listItems, "</li><li>") .. "</li></ul>"
			table.clear(listItems)
		end
	end

	local i = 1
	while i <= #lines do
		local line = lines[i]
		local fenceLang, fenceCaption = string.match(line, "^```(%w*)%s*(.-)%s*$")
		if fenceLang then
			flushParagraph()
			flushList()
			local codeLines: { string } = {}
			i += 1
			while i <= #lines and not string.match(lines[i], "^```") do
				codeLines[#codeLines + 1] = lines[i]
				i += 1
			end
			out[#out + 1] = renderCode(fenceLang, fenceCaption :: string, codeLines)
		elseif string.match(line, "^%s*$") then
			flushParagraph()
			flushList()
		elseif string.match(line, "^#+%s") then
			flushParagraph()
			flushList()
			local text = string.match(line, "^#+%s+(.-)%s*$") :: string
			out[#out + 1] = "<h3>" .. Markdown.Inline(text, opts) .. "</h3>"
		elseif string.match(line, "^%- ") then
			flushParagraph()
			listItems[#listItems + 1] = Markdown.Inline(string.sub(line, 3), opts)
		elseif #listItems > 0 and string.match(line, "^%s+%S") then
			-- indented continuation of the previous list item
			local trimmed = string.match(line, "^%s+(.-)%s*$") :: string
			listItems[#listItems] ..= " " .. Markdown.Inline(trimmed, opts)
		else
			flushList()
			paragraph[#paragraph + 1] = line
		end
		i += 1
	end
	flushParagraph()
	flushList()

	return table.concat(out, "\n")
end

return Markdown

end

__modules["Themes"] = function()
--- Semantic theme palettes, Neovim-colorscheme style: every theme fills the
--- same sixteen CSS variables in a light and a dark variant, so one config
--- line recolors the entire page. Tinted backgrounds are derived in CSS via
--- `color-mix`, keeping palettes small.
---
--- Built-ins: `junky` (the default — the Junky spec page's own colors),
--- `tokyonight`, `gruvbox`, `catppuccin`, and `nord`.
--- @section Support

--- Sixteen variable names to hex colors: backgrounds (`bg`, `surface`,
--- `surface-2`, `code-bg`), borders, ink shades, `accent`, and the semantic
--- badge colors (`net`, `local`, `good`, `danger`).
type Palette = { [string]: string }

--- A complete theme: one [[Palette]] per color scheme.
type Theme = { light: Palette, dark: Palette }

local Palettes: { [string]: Theme } = {}

-- the variable names the template expects, in emit order
local ORDER = {
	"bg", "surface", "surface-2", "code-bg",
	"border", "border-strong",
	"ink", "ink-soft", "muted", "faint",
	"accent", "accent-ink",
	"net", "local", "danger", "good",
}

Palettes.junky = {
	light = {
		["bg"] = "#e9ecef", ["surface"] = "#ffffff", ["surface-2"] = "#f3f5f8", ["code-bg"] = "#f5f7f9",
		["border"] = "#cfd6dd", ["border-strong"] = "#aeb8c2",
		["ink"] = "#12171d", ["ink-soft"] = "#333c45", ["muted"] = "#586470", ["faint"] = "#87919c",
		["accent"] = "#0f7788", ["accent-ink"] = "#0a5c69",
		["net"] = "#0f7788", ["local"] = "#8f5d15", ["danger"] = "#b23a2b", ["good"] = "#2f8f57",
	},
	dark = {
		["bg"] = "#0a0e12", ["surface"] = "#12181f", ["surface-2"] = "#0e141b", ["code-bg"] = "#0d131a",
		["border"] = "#212b35", ["border-strong"] = "#31404b",
		["ink"] = "#e4ebf1", ["ink-soft"] = "#bcc6d0", ["muted"] = "#8492a0", ["faint"] = "#5b6976",
		["accent"] = "#45bccf", ["accent-ink"] = "#63d0e1",
		["net"] = "#45bccf", ["local"] = "#e6ab4c", ["danger"] = "#ec6f62", ["good"] = "#5cc27f",
	},
}

Palettes.tokyonight = {
	light = {
		["bg"] = "#d5d6db", ["surface"] = "#e1e2e7", ["surface-2"] = "#dcdee3", ["code-bg"] = "#dcdee3",
		["border"] = "#c4c8da", ["border-strong"] = "#a8aecb",
		["ink"] = "#343b58", ["ink-soft"] = "#4c505e", ["muted"] = "#6172b0", ["faint"] = "#9699a3",
		["accent"] = "#2e7de9", ["accent-ink"] = "#2e7de9",
		["net"] = "#007197", ["local"] = "#8c6c3e", ["danger"] = "#c64343", ["good"] = "#587539",
	},
	dark = {
		["bg"] = "#16161e", ["surface"] = "#1a1b26", ["surface-2"] = "#1f2335", ["code-bg"] = "#16161e",
		["border"] = "#292e42", ["border-strong"] = "#3b4261",
		["ink"] = "#c0caf5", ["ink-soft"] = "#a9b1d6", ["muted"] = "#565f89", ["faint"] = "#414868",
		["accent"] = "#7aa2f7", ["accent-ink"] = "#7dcfff",
		["net"] = "#7dcfff", ["local"] = "#e0af68", ["danger"] = "#f7768e", ["good"] = "#9ece6a",
	},
}

Palettes.gruvbox = {
	light = {
		["bg"] = "#ebdbb2", ["surface"] = "#fbf1c7", ["surface-2"] = "#f2e5bc", ["code-bg"] = "#f9f5d7",
		["border"] = "#d5c4a1", ["border-strong"] = "#bdae93",
		["ink"] = "#3c3836", ["ink-soft"] = "#504945", ["muted"] = "#665c54", ["faint"] = "#928374",
		["accent"] = "#076678", ["accent-ink"] = "#076678",
		["net"] = "#076678", ["local"] = "#b57614", ["danger"] = "#9d0006", ["good"] = "#79740e",
	},
	dark = {
		["bg"] = "#1d2021", ["surface"] = "#282828", ["surface-2"] = "#32302f", ["code-bg"] = "#1d2021",
		["border"] = "#3c3836", ["border-strong"] = "#504945",
		["ink"] = "#ebdbb2", ["ink-soft"] = "#d5c4a1", ["muted"] = "#928374", ["faint"] = "#7c6f64",
		["accent"] = "#83a598", ["accent-ink"] = "#8ec07c",
		["net"] = "#83a598", ["local"] = "#fabd2f", ["danger"] = "#fb4934", ["good"] = "#b8bb26",
	},
}

Palettes.catppuccin = {
	light = {
		["bg"] = "#dce0e8", ["surface"] = "#eff1f5", ["surface-2"] = "#e6e9ef", ["code-bg"] = "#e6e9ef",
		["border"] = "#ccd0da", ["border-strong"] = "#bcc0cc",
		["ink"] = "#4c4f69", ["ink-soft"] = "#5c5f77", ["muted"] = "#6c6f85", ["faint"] = "#9ca0b0",
		["accent"] = "#1e66f5", ["accent-ink"] = "#1e66f5",
		["net"] = "#179299", ["local"] = "#df8e1d", ["danger"] = "#d20f39", ["good"] = "#40a02b",
	},
	dark = {
		["bg"] = "#11111b", ["surface"] = "#1e1e2e", ["surface-2"] = "#181825", ["code-bg"] = "#181825",
		["border"] = "#313244", ["border-strong"] = "#45475a",
		["ink"] = "#cdd6f4", ["ink-soft"] = "#bac2de", ["muted"] = "#7f849c", ["faint"] = "#585b70",
		["accent"] = "#89b4fa", ["accent-ink"] = "#b4befe",
		["net"] = "#89dceb", ["local"] = "#f9e2af", ["danger"] = "#f38ba8", ["good"] = "#a6e3a1",
	},
}

Palettes.nord = {
	light = {
		["bg"] = "#d8dee9", ["surface"] = "#eceff4", ["surface-2"] = "#e5e9f0", ["code-bg"] = "#e5e9f0",
		["border"] = "#c8cfdb", ["border-strong"] = "#aeb7c9",
		["ink"] = "#2e3440", ["ink-soft"] = "#3b4252", ["muted"] = "#4c566a", ["faint"] = "#7b88a1",
		["accent"] = "#5e81ac", ["accent-ink"] = "#5e81ac",
		["net"] = "#5e81ac", ["local"] = "#8a6116", ["danger"] = "#bf616a", ["good"] = "#587544",
	},
	dark = {
		["bg"] = "#242933", ["surface"] = "#2e3440", ["surface-2"] = "#3b4252", ["code-bg"] = "#272c37",
		["border"] = "#434c5e", ["border-strong"] = "#4c566a",
		["ink"] = "#eceff4", ["ink-soft"] = "#d8dee9", ["muted"] = "#9aa4b8", ["faint"] = "#616e88",
		["accent"] = "#88c0d0", ["accent-ink"] = "#8fbcbb",
		["net"] = "#88c0d0", ["local"] = "#ebcb8b", ["danger"] = "#bf616a", ["good"] = "#a3be8c",
	},
}

local Themes = {
	Palettes = Palettes,
}

--- Renders one [[Palette]] as a CSS custom-property block body, in a fixed
--- emit order so output diffs stay stable between builds.
--- @param palette one variant of a [[Theme]]
function Themes.Variables(palette: Palette): string
	local parts: { string } = {}
	for _, name in ORDER do
		parts[#parts + 1] = "--" .. name .. ":" .. palette[name]
	end
	return table.concat(parts, ";") .. ";"
end

return Themes

end

__modules["Model"] = function()
--- Merges per-file scans into the document model. **A file is a module** —
--- `src/Chunk.luau` (or `src/Chunk/init.luau`) becomes the `Chunk` page
--- section, and the root `src/init.luau` becomes the package module whose
--- summary leads the page. There is no `@within`; position is ownership.
---
--- This is also where honesty is enforced: parameter names and types are
--- parsed out of each signature, then diffed against the `@param` docs — a
--- `@param` naming a parameter the code doesn't have warns, and so does an
--- undocumented parameter once any `@param` is present. Cross-link targets
--- ([[Docket]]-style) are registered here for every module, member, and type.
--- @section Pipeline

local fs = __lune_fs

local Scanner = __require("Scanner")
local Grammar = __require("Grammar")
local Toml = __require("Toml")

local Model = {}

type ParamInfo = { name: string, type: string?, desc: string? }

type Member = {
	kind: "function" | "type",
	name: string,
	signature: string,
	anchor: string,
	doc: Grammar.Doc,
	params: { ParamInfo },
	returnType: string?,
	realm: string?,
	since: string?,
}

type Module = {
	name: string,
	anchor: string,
	number: string,
	section: string,
	file: string,
	summary: string?,
	bodyLines: { string },
	realm: string?,
	members: { Member },
	isRoot: boolean,
	isPage: boolean?,
}

--- One standalone markdown guide page, declared in [[Config]] `Pages`. The
--- file renders as its own sidebar entry; a leading `# Heading` becomes the
--- title unless one is given here.
type PageSpec = {
	file: string,
	title: string?,
	section: string?,
}

type Section = { name: string, modules: { Module } }

--- The finished document model [[Render.Page]] consumes: project facts,
--- ordered sections of modules, the `[[link]]` registry, and every warning
--- gathered along the way.
type Data = {
	title: string,
	version: string?,
	license: string?,
	repo: string?,
	lead: string?,
	theme: string,
	output: string,
	sections: { Section },
	registry: { [string]: string },
	warnings: { string },
}

--- Everything a project's optional `docket.luau` can return. Every field has
--- a zero-config default: `Title`/`Version`/`License` fall back to
--- `wally.toml`, `Lead` to the root module's summary, `Theme` to `junky`,
--- `Source` to `src`, `Output` to `docs`, and `Sections` to first-appearance
--- order of `@section` names.
---
--- ```lua a full docket.luau
--- return {
---     Title    = "Chunkr",
---     Lead     = "A voxel destruction engine.",
---     Theme    = "tokyonight",
---     Sections = { "Foundations", "Runtime", "Reference" },
---     Pages    = { { file = "USAGE.md", section = "Foundations" } },
---     Repo     = "https://github.com/mkl48/Chunkr",
---     Version  = "0.4.0",   -- only needed when there is no wally.toml
---     License  = "MIT",
--- }
--- ```
type Config = {
	Title: string?,
	Lead: string?,
	Theme: string?,
	Source: string?,
	Output: string?,
	Sections: { string }?,
	Pages: { PageSpec }?,
	Repo: string?,
	Version: string?,
	License: string?,
}

local function slug(text: string): string
	local lowered = string.lower(text)
	lowered = string.gsub(lowered, "[^%w]+", "-")
	lowered = string.gsub(lowered, "^%-+", "")
	lowered = string.gsub(lowered, "%-+$", "")
	return lowered
end

--- split a signature's parameter list on top-level commas and read the real types
local function parseSignatureParams(signature: string): ({ ParamInfo }, string?)
	local openAt = string.find(signature, "(", 1, true)
	if not openAt then
		return {}, nil
	end

	local depth = 0
	local closeAt: number? = nil
	local pieces: { string } = {}
	local pieceStart = openAt + 1
	for i = openAt, #signature do
		local c = string.sub(signature, i, i)
		if c == ">" and string.sub(signature, i - 1, i - 1) == "-" then
			-- the `>` of a `->` function-type arrow, not a closing angle bracket
			continue
		end
		if c == "(" or c == "{" or c == "<" or c == "[" then
			depth += 1
		elseif c == ")" or c == "}" or c == ">" or c == "]" then
			depth -= 1
			if depth == 0 and c == ")" then
				pieces[#pieces + 1] = string.sub(signature, pieceStart, i - 1)
				closeAt = i
				break
			end
		elseif c == "," and depth == 1 then
			pieces[#pieces + 1] = string.sub(signature, pieceStart, i - 1)
			pieceStart = i + 1
		end
	end

	local params: { ParamInfo } = {}
	for _, piece in pieces do
		local trimmed = string.match(piece, "^%s*(.-)%s*$") :: string
		if trimmed == "" then
			continue
		end
		local name = string.match(trimmed, "^(%.%.%.)") or string.match(trimmed, "^([%w_]+)")
		if name then
			params[#params + 1] = {
				name = name,
				type = string.match(trimmed, "^[%w_%.]+%s*:%s*(.+)$"),
				desc = nil,
			}
		end
	end

	local returnType: string? = nil
	if closeAt then
		returnType = string.match(signature, "^%s*:%s*(.+)$", closeAt + 1)
	end
	return params, returnType
end

local function listLuauFiles(dir: string, prefix: string, out: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			listLuauFiles(full, prefix .. name .. "/", out)
		elseif string.match(name, "%.luau$") or string.match(name, "%.lua$") then
			out[#out + 1] = prefix .. name
		end
	end
end

--- Builds the [[Data]] model for one project directory.
--- @param root the project directory (contains `wally.toml`, `src/`, …)
--- @param config the loaded `docket.luau` table, or `{}` for zero-config
function Model.Build(root: string, config: Config): Data
	local warnings: { string } = {}
	local function warn(message: string)
		warnings[#warnings + 1] = message
	end

	-- project facts from wally.toml
	local packageName: string? = nil
	local version: string? = nil
	local license: string? = nil
	local wallyPath = root .. "/wally.toml"
	if fs.isFile(wallyPath) then
		local wally = Toml.Parse(fs.readFile(wallyPath))
		local pkg = if type(wally.package) == "table" then wally.package else {}
		local scoped = if type(pkg.name) == "string" then pkg.name else nil
		packageName = if scoped then string.match(scoped, "/(.+)$") or scoped else nil
		version = if type(pkg.version) == "string" then pkg.version else nil
		license = if type(pkg.license) == "string" then pkg.license else nil
	end

	local title = config.Title
		or (packageName and (string.upper(string.sub(packageName, 1, 1)) .. string.sub(packageName, 2)))
		or "Documentation"

	local sourceDir = root .. "/" .. (config.Source or "src")
	local files: { string } = {}
	if fs.isDir(sourceDir) then
		listLuauFiles(sourceDir, "", files)
	else
		warn(`source directory not found: {sourceDir}`)
	end

	-- config.Ignore: path prefixes to leave out, for vendored third-party code
	-- that lives in src/ but is not this package's API.
	-- LOCAL ADDITION -- worth upstreaming into Docket itself.
	if config.Ignore then
		local kept: { string } = {}
		for _, relPath in files do
			local skip = false
			for _, prefix in config.Ignore do
				if string.sub(relPath, 1, #prefix) == prefix then
					skip = true
					break
				end
			end
			if not skip then
				table.insert(kept, relPath)
			end
		end
		files = kept
	end

	-- root init first so the package module leads the page
	table.sort(files, function(a, b)
		local aRoot = a == "init.luau" or a == "init.lua"
		local bRoot = b == "init.luau" or b == "init.lua"
		if aRoot ~= bRoot then
			return aRoot
		end
		return a < b
	end)

	local modules: { Module } = {}
	local usedAnchors: { [string]: boolean } = {}

	for _, relPath in files do
		local source = fs.readFile(sourceDir .. "/" .. relPath)
		local scan = Scanner.Scan(source, relPath)
		for _, warning in scan.warnings do
			warn(warning)
		end

		-- documented local functions are private helpers, not API
		local publicEntries: { Scanner.Entry } = {}
		for _, entry in scan.entries do
			local decl = entry.decl
			if decl and decl.kind == "function" and decl.isLocal then
				continue
			end
			publicEntries[#publicEntries + 1] = entry
		end
		scan.entries = publicEntries

		local isRoot = relPath == "init.luau" or relPath == "init.lua"
		local defaultName: string
		if isRoot then
			defaultName = title
		else
			local stem = string.gsub(relPath, "%.luau?$", "")
			stem = string.gsub(stem, "/init$", "")
			defaultName = string.match(stem, "([^/]+)$") :: string
		end

		local moduleDocLines: { string }? = nil
		local memberEntries: { Scanner.Entry } = {}
		for index, entry in scan.entries do
			if entry.decl == nil or entry.decl.kind == "table" then
				if index == 1 and moduleDocLines == nil then
					moduleDocLines = entry.docLines
				else
					warn(`{relPath}:{entry.line}: floating doc comment ignored`)
				end
			else
				memberEntries[#memberEntries + 1] = entry
			end
		end

		if moduleDocLines == nil and #memberEntries == 0 then
			continue -- nothing documented in this file
		end

		local moduleDoc: Grammar.Doc? = nil
		if moduleDocLines then
			local parsed = Grammar.Parse(moduleDocLines)
			for _, warning in parsed.warnings do
				warn(`{relPath}: {warning}`)
			end
			moduleDoc = parsed.doc
		end

		local moduleName = (moduleDoc and moduleDoc.class) or defaultName
		local anchor = slug(moduleName)
		while usedAnchors[anchor] do
			anchor ..= "-2"
		end
		usedAnchors[anchor] = true

		local moduleRealm = moduleDoc and moduleDoc.realm
		local members: { Member } = {}

		for _, entry in memberEntries do
			local decl = entry.decl :: Scanner.Declaration
			local parsed = Grammar.Parse(entry.docLines)
			for _, warning in parsed.warnings do
				warn(`{relPath}:{entry.line}: {warning}`)
			end
			local doc = parsed.doc

			local params: { ParamInfo } = {}
			local returnType: string? = nil
			if decl.kind == "function" then
				params, returnType = parseSignatureParams(decl.signature)

				local byName: { [string]: ParamInfo } = {}
				for _, param in params do
					byName[param.name] = param
				end
				for _, documented in doc.params do
					local match = byName[documented.name]
					if match then
						match.desc = documented.desc
					else
						warn(`{relPath}:{entry.line}: @param {documented.name} does not match the signature of {decl.name}`)
					end
				end
				if #doc.params > 0 then
					for _, param in params do
						if param.desc == nil then
							warn(`{relPath}:{entry.line}: parameter {param.name} of {decl.name} is undocumented`)
						end
					end
				end
			end

			local lastPart = string.match(decl.name, "([%w_]+)$") or decl.name
			local memberAnchor = anchor .. "-" .. slug(lastPart)
			while usedAnchors[memberAnchor] do
				memberAnchor ..= "-2"
			end
			usedAnchors[memberAnchor] = true

			members[#members + 1] = {
				kind = decl.kind :: any,
				name = decl.name,
				signature = decl.signature,
				anchor = memberAnchor,
				doc = doc,
				params = params,
				returnType = returnType,
				realm = doc.realm or moduleRealm,
				since = doc.since,
			}
		end

		modules[#modules + 1] = {
			name = moduleName,
			anchor = anchor,
			number = "", -- assigned after section ordering
			section = (moduleDoc and moduleDoc.section) or "Reference",
			file = relPath,
			summary = moduleDoc and moduleDoc.summary,
			bodyLines = if moduleDoc then moduleDoc.body else {},
			realm = moduleRealm,
			members = members,
			isRoot = isRoot,
		}
	end

	-- standalone markdown guide pages, after the source modules
	for _, page in config.Pages or {} do
		local pagePath = root .. "/" .. page.file
		if not fs.isFile(pagePath) then
			warn(`page not found: {page.file}`)
			continue
		end
		local text = string.gsub(fs.readFile(pagePath), "\r\n", "\n")
		local lines: { string } = {}
		for line in string.gmatch(text .. "\n", "(.-)\n") do
			lines[#lines + 1] = line
		end

		local title = page.title
		local bodyStart = 1
		local heading = lines[1] and string.match(lines[1], "^#%s+(.-)%s*$")
		if heading then
			title = title or heading
			bodyStart = 2
		end
		title = title or (string.match(page.file, "([^/]+)%.%w+$") or page.file)

		local anchor = slug(title)
		while usedAnchors[anchor] do
			anchor ..= "-2"
		end
		usedAnchors[anchor] = true

		modules[#modules + 1] = {
			name = title,
			anchor = anchor,
			number = "",
			section = page.section or "Guides",
			file = page.file,
			summary = nil,
			bodyLines = table.move(lines, bodyStart, #lines, 1, {}),
			realm = nil,
			members = {},
			isRoot = false,
			isPage = true,
		}
	end

	-- group into sections: configured order first, then first-appearance order
	local sectionOrder: { string } = {}
	local sectionsByName: { [string]: Section } = {}
	for _, name in config.Sections or {} do
		sectionOrder[#sectionOrder + 1] = name
		sectionsByName[name] = { name = name, modules = {} }
	end
	for _, module in modules do
		if not sectionsByName[module.section] then
			sectionOrder[#sectionOrder + 1] = module.section
			sectionsByName[module.section] = { name = module.section, modules = {} }
		end
		local section = sectionsByName[module.section]
		table.insert(section.modules, module)
	end

	local sections: { Section } = {}
	local counter = 0
	for _, name in sectionOrder do
		local section = sectionsByName[name]
		if #section.modules > 0 then
			sections[#sections + 1] = section
			for _, module in section.modules do
				counter += 1
				module.number = string.format("%02d", counter)
			end
		end
	end

	-- link registry: module names, member names, bare type names
	local registry: { [string]: string } = {}
	for _, module in modules do
		registry[module.name] = "#" .. module.anchor
		for _, member in module.members do
			registry[member.name] = "#" .. member.anchor
			if member.kind == "type" then
				registry[module.name .. "." .. member.name] = "#" .. member.anchor
			end
		end
	end

	local rootModule: Module? = nil
	for _, module in modules do
		if module.isRoot then
			rootModule = module
			break
		end
	end

	return {
		title = title,
		version = config.Version or version,
		license = config.License or license,
		repo = config.Repo,
		lead = config.Lead or (rootModule and rootModule.summary),
		theme = config.Theme or "junky",
		output = config.Output or "docs",
		sections = sections,
		registry = registry,
		warnings = warnings,
	}
end

return Model

end

__modules["Render"] = function()
--- Emits the single self-contained HTML page: numbered sidebar with eyebrow
--- groups and scrollspy, titleblock with a meta grid, member components with
--- highlighted signatures, params tables, captioned code blocks, and a
--- light/dark theme toggle.
---
--- Self-contained means *no external requests of any kind* — styles, the
--- search index, and the interaction script are baked into the file, fonts
--- are system stacks, and the favicon is an inline data URI. The output can
--- be opened from disk, attached to a release, or pushed to `gh-pages` as-is.
--- Search is client-side over the baked index; press `/` to focus it.
--- @section Pipeline

local Highlight = __require("Highlight")
local Markdown = __require("Markdown")
local Model = __require("Model")
local Themes = __require("Themes")

local Render = {}

local function escape(text: string): string
	return (string.gsub(text, "[&<>\"]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;" }))
end

local function jsonString(text: string): string
	local escaped = string.gsub(text, "[\\\"\n\r\t<]", {
		["\\"] = "\\\\", ["\""] = "\\\"", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["<"] = "\\u003c",
	})
	return "\"" .. escaped .. "\""
end

local REALM_TAG: { [string]: { class: string, label: string } } = {
	server = { class = "net", label = "Server" },
	client = { class = "loc", label = "Client" },
	shared = { class = "sh", label = "Shared" },
}

local function realmTag(realm: string?): string
	local info = realm and REALM_TAG[realm]
	if not info then
		return ""
	end
	return `<span class="tag {info.class}">{info.label}</span>`
end

-- static template pieces ---------------------------------------------------

local CSS_BODY = [==[
  *{box-sizing:border-box}
  html{scroll-behavior:smooth}
  @media (prefers-reduced-motion: reduce){html{scroll-behavior:auto}*{transition:none!important;animation:none!important}}
  body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--font-sans);font-size:16px;line-height:1.62;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
  a{color:var(--accent-ink);text-decoration:none;text-underline-offset:2px}
  a:hover{text-decoration:underline}
  :focus-visible{outline:2px solid var(--accent);outline-offset:2px}

  .topbar{position:sticky;top:0;z-index:50;display:flex;align-items:center;gap:16px;padding:11px clamp(16px,4vw,40px);background:var(--surface);border-bottom:1px solid var(--border-strong)}
  .brand{font-weight:700;letter-spacing:.03em;line-height:1.05;white-space:nowrap}
  .brand small{display:block;font-family:var(--font-mono);font-weight:600;font-size:.6rem;letter-spacing:.16em;color:var(--muted);text-transform:uppercase;margin-top:2px}
  .topbar .spacer{flex:1}
  .vbadge{font-family:var(--font-mono);font-size:.66rem;letter-spacing:.1em;font-weight:600;padding:4px 8px;border:1px solid var(--border-strong);color:var(--muted);border-radius:2px;white-space:nowrap}
  .toggle{font-family:var(--font-mono);font-size:.68rem;letter-spacing:.06em;background:var(--surface-2);border:1px solid var(--border-strong);color:var(--ink-soft);padding:6px 10px;border-radius:2px;cursor:pointer;display:inline-flex;gap:7px;align-items:center}
  .toggle:hover{border-color:var(--accent);color:var(--accent-ink)}

  .search{position:relative;flex:0 1 340px;min-width:140px}
  .search input{width:100%;font-family:var(--font-mono);font-size:.75rem;padding:6px 10px;background:var(--surface-2);border:1px solid var(--border-strong);border-radius:2px;color:var(--ink)}
  .search input::placeholder{color:var(--faint)}
  .search input:focus{outline:none;border-color:var(--accent)}
  .sresults{position:absolute;top:calc(100% + 6px);left:0;right:0;background:var(--surface);border:1px solid var(--border-strong);border-radius:2px;max-height:340px;overflow-y:auto;display:none;z-index:60}
  .sresults a{display:block;padding:8px 11px;border-bottom:1px solid var(--border);color:var(--ink);font-size:.83rem}
  .sresults a:last-child{border-bottom:none}
  .sresults a .k{font-family:var(--font-mono);font-size:.6rem;letter-spacing:.08em;text-transform:uppercase;color:var(--faint);margin-right:8px}
  .sresults a .sum{display:block;color:var(--muted);font-size:.76rem;margin-top:2px}
  .sresults a:hover,.sresults a.sel{background:var(--surface-2);text-decoration:none}

  .shell{max-width:1180px;margin:0 auto;display:grid;grid-template-columns:236px minmax(0,1fr);gap:clamp(24px,4vw,54px);padding:0 clamp(16px,4vw,40px) 100px}
  .sidebar{position:sticky;top:63px;align-self:start;height:calc(100vh - 63px);overflow-y:auto;padding:26px 0 40px}
  .sidebar .eyebrow{font-family:var(--font-mono);font-size:.62rem;letter-spacing:.16em;text-transform:uppercase;color:var(--faint);padding:0 8px 6px;margin:18px 0 7px;border-bottom:1px solid var(--border)}
  .sidebar .eyebrow:first-child{margin-top:0}
  .nav a{display:flex;gap:9px;align-items:baseline;padding:4px 8px;color:var(--muted);font-size:.88rem;line-height:1.3;border-left:2px solid transparent}
  .nav a .n{font-family:var(--font-mono);font-size:.7rem;color:var(--faint);min-width:1.7em}
  .nav a:hover{color:var(--ink);text-decoration:none;background:var(--surface-2)}
  .nav a.active{color:var(--accent-ink);border-left-color:var(--accent)}
  .nav a.active .n{color:var(--accent-ink)}

  main{padding-top:26px;min-width:0}
  section{padding-top:14px;margin-bottom:30px;scroll-margin-top:72px}
  section > p,section > ul{max-width:70ch}
  .lead{font-size:1.06rem;color:var(--ink-soft)}
  h1{font-size:clamp(1.9rem,4vw,2.5rem);line-height:1.06;letter-spacing:-.02em;margin:.1em 0;text-wrap:balance}
  h2{font-size:clamp(1.32rem,2.4vw,1.6rem);letter-spacing:-.01em;margin:.2em 0 .7em;text-wrap:balance;display:flex;align-items:baseline;gap:.7em;padding-top:.7em;border-top:1px solid var(--border-strong)}
  h2 .sn{font-family:var(--font-mono);font-size:.76rem;font-weight:700;letter-spacing:.12em;color:var(--muted);flex:none}
  h2 .tag{font-size:.64rem;align-self:center}
  h3{font-size:1.06rem;margin:1.7em 0 .35em;color:var(--ink);font-weight:650}
  p{margin:.6em 0}
  strong{color:var(--ink);font-weight:650}
  code{font-family:var(--font-mono);font-size:.85em;background:var(--code-bg);border:1px solid var(--border);padding:.06em .34em;border-radius:2px;color:var(--ink)}
  ul{padding-left:1.3em}
  li{margin:.28em 0}
  li::marker{color:var(--faint)}

  .titleblock{display:grid;grid-template-columns:1.5fr 1fr;gap:26px;align-items:end;padding:12px 0 22px;border-bottom:1px solid var(--border-strong);margin-bottom:10px}
  .titleblock .eyebrow{font-family:var(--font-mono);font-size:.7rem;letter-spacing:.2em;text-transform:uppercase;color:var(--muted)}
  .tb-meta{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:1px;background:var(--border);border:1px solid var(--border);border-radius:2px}
  .tb-meta > div{background:var(--surface-2);padding:8px 11px}
  .tb-meta dt{font-family:var(--font-mono);font-size:.58rem;letter-spacing:.14em;text-transform:uppercase;color:var(--faint)}
  .tb-meta dd{margin:2px 0 0;font-family:var(--font-mono);font-size:.8rem;color:var(--ink);line-height:1.25}
  @media (max-width:760px){.titleblock{grid-template-columns:1fr}}

  .tag{font-family:var(--font-mono);font-weight:600;font-size:.72rem;letter-spacing:.03em;padding:1px 7px;border-radius:2px;display:inline-block;white-space:nowrap;border:1px solid currentColor}
  .tag.net{color:var(--net);background:color-mix(in srgb,var(--net) 11%,transparent)}
  .tag.loc{color:var(--local);background:color-mix(in srgb,var(--local) 12%,transparent)}
  .tag.sh{color:var(--good);background:color-mix(in srgb,var(--good) 12%,transparent)}

  .code{margin:15px 0;border:1px solid var(--border-strong);border-radius:2px;overflow:hidden;background:var(--code-bg)}
  .code .cap{padding:7px 13px;border-bottom:1px solid var(--border);background:var(--surface-2);font-family:var(--font-mono);font-size:.71rem;letter-spacing:.02em;color:var(--muted)}
  pre{margin:0;overflow-x:auto;padding:15px 17px;font-family:var(--font-mono);font-size:.83rem;line-height:1.6;tab-size:4}
  pre code{background:none;border:none;padding:0;font-size:1em;color:var(--ink)}
  .cm{color:var(--faint);font-style:italic}
  .kw{color:var(--accent-ink)}
  .st{color:var(--local)}

  .tbl{margin:14px 0;border:1px solid var(--border-strong);border-radius:2px;overflow:hidden}
  .tbl .scroll{overflow-x:auto}
  table{border-collapse:collapse;width:100%;font-size:.89rem}
  th,td{text-align:left;padding:9px 13px;border-bottom:1px solid var(--border);border-right:1px solid var(--border);vertical-align:top}
  th:last-child,td:last-child{border-right:none}
  thead th{background:var(--surface-2);font-family:var(--font-mono);font-size:.64rem;letter-spacing:.09em;text-transform:uppercase;color:var(--muted);font-weight:600;white-space:nowrap}
  tbody tr:last-child td{border-bottom:none}
  tbody tr:hover{background:var(--surface-2)}
  td code{font-size:.82em}
  td.mono{font-family:var(--font-mono);font-size:.81rem;color:var(--ink);white-space:nowrap}

  .member{border:1px solid var(--border-strong);border-radius:2px;margin:18px 0;background:var(--surface);scroll-margin-top:72px}
  .msig{display:flex;align-items:center;gap:10px;padding:9px 13px;background:var(--code-bg);border-bottom:1px solid var(--border);font-family:var(--font-mono);font-size:.85rem;overflow-x:auto}
  .msig code{background:none;border:none;padding:0;white-space:nowrap}
  .msig .manchor{margin-left:auto;color:var(--faint)}
  .msig .manchor:hover{color:var(--accent-ink);text-decoration:none}
  .mbody{padding:6px 15px 13px}
  .mbody > p{max-width:72ch}
  .vtag{font-family:var(--font-mono);font-size:.64rem;letter-spacing:.06em;color:var(--faint);border:1px solid var(--border);padding:1px 6px;border-radius:2px;white-space:nowrap}
  .rets{font-size:.9rem;max-width:72ch}
  .rets .rlbl{font-family:var(--font-mono);font-size:.62rem;letter-spacing:.12em;color:var(--faint);margin-right:8px}

  footer{max-width:1180px;margin:0 auto;padding:22px clamp(16px,4vw,40px) 60px;color:var(--faint);font-family:var(--font-mono);font-size:.7rem;letter-spacing:.04em;border-top:1px solid var(--border)}

  @media (max-width:900px){
    .shell{grid-template-columns:1fr}
    .sidebar{position:static;height:auto;overflow:visible;border-bottom:1px solid var(--border-strong);padding:16px 0}
    .sidebar .nav{columns:2;column-gap:18px}
    .search{flex:1}
    .vbadge{display:none}
  }

  @media print{
    .topbar,.sidebar,.toggle,.search{display:none!important}
    .shell{grid-template-columns:1fr;max-width:none;padding:0}
    body{background:#fff;color:#000;font-size:11pt}
    .code,.tbl,.member{break-inside:avoid}
    a{color:#000;text-decoration:underline}
  }
]==]

local SCRIPT = [==[
(function(){
  var root=document.documentElement;
  var btn=document.getElementById('themeBtn');
  var icon=document.getElementById('themeIcon');
  var lbl=document.getElementById('themeLbl');
  function sysDark(){return window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches;}
  function apply(t){root.setAttribute('data-theme',t);var d=t==='dark';icon.textContent=d?'☾':'☀';lbl.textContent=d?'Dark':'Light';}
  apply(sysDark()?'dark':'light');
  btn.addEventListener('click',function(){apply(root.getAttribute('data-theme')==='dark'?'light':'dark');});

  var links=[].slice.call(document.querySelectorAll('#toc a'));
  var map={};links.forEach(function(a){map[a.getAttribute('href').slice(1)]=a;});
  if('IntersectionObserver' in window){
    var obs=new IntersectionObserver(function(entries){
      entries.forEach(function(e){if(e.isIntersecting){links.forEach(function(a){a.classList.remove('active');});var a=map[e.target.id];if(a)a.classList.add('active');}});
    },{rootMargin:'-20% 0px -70% 0px',threshold:0});
    document.querySelectorAll('main section[id]').forEach(function(s){obs.observe(s);});
  }

  var input=document.getElementById('searchBox');
  var results=document.getElementById('searchResults');
  var sel=-1;
  function close(){results.style.display='none';results.innerHTML='';sel=-1;}
  function run(){
    var q=input.value.trim().toLowerCase();
    if(!q){close();return;}
    var hits=[];
    for(var i=0;i<DOCKET_INDEX.length&&hits.length<9;i++){
      var e=DOCKET_INDEX[i];
      if(e.t.toLowerCase().indexOf(q)>=0||(e.s&&e.s.toLowerCase().indexOf(q)>=0))hits.push(e);
    }
    if(!hits.length){close();return;}
    results.innerHTML=hits.map(function(e){
      return '<a href="#'+e.a+'"><span class="k">'+e.k+'</span>'+e.t.replace(/</g,'&lt;')+(e.s?'<span class="sum">'+e.s.replace(/</g,'&lt;')+'</span>':'')+'</a>';
    }).join('');
    results.style.display='block';sel=-1;
    [].slice.call(results.children).forEach(function(a){a.addEventListener('click',function(){close();input.blur();});});
  }
  function move(d){
    var items=[].slice.call(results.children);
    if(!items.length)return;
    sel=(sel+d+items.length)%items.length;
    items.forEach(function(a,i){a.classList.toggle('sel',i===sel);});
  }
  input.addEventListener('input',run);
  input.addEventListener('keydown',function(ev){
    if(ev.key==='ArrowDown'){move(1);ev.preventDefault();}
    else if(ev.key==='ArrowUp'){move(-1);ev.preventDefault();}
    else if(ev.key==='Enter'){
      var items=results.children;
      var pick=items[sel>=0?sel:0];
      if(pick){location.hash=pick.getAttribute('href');close();input.blur();}
    }
    else if(ev.key==='Escape'){close();input.blur();}
  });
  document.addEventListener('click',function(ev){if(!ev.target.closest('.search'))close();});
  document.addEventListener('keydown',function(ev){
    if(ev.key==='/'&&document.activeElement!==input){input.focus();ev.preventDefault();}
  });
})();
]==]

-- dynamic pieces ------------------------------------------------------------

local function renderMember(member: Model.Member, mdOpts: Markdown.Options): string
	local out: { string } = {}

	local headerCode: string
	if member.kind == "type" then
		local firstLine = string.match(member.signature, "^[^\n]*")
		headerCode = Highlight.Render(if #member.signature > #(firstLine :: string) then "type " .. member.name else firstLine :: string)
	else
		headerCode = Highlight.Render(member.signature)
	end

	out[#out + 1] = `<div class="member" id="{member.anchor}">`
	out[#out + 1] = `<div class="msig"><code>{headerCode}</code>`
		.. realmTag(member.realm)
		.. (if member.since then `<span class="vtag">since {escape(member.since)}</span>` else "")
		.. `<a class="manchor" href="#{member.anchor}" aria-label="Link to {escape(member.name)}">#</a></div>`
	out[#out + 1] = '<div class="mbody">'

	if member.doc.summary then
		out[#out + 1] = "<p>" .. Markdown.Inline(member.doc.summary, mdOpts) .. "</p>"
	end
	if #member.doc.body > 0 then
		out[#out + 1] = Markdown.RenderLines(member.doc.body, mdOpts)
	end

	if member.kind == "type" and string.find(member.signature, "\n", 1, true) then
		out[#out + 1] = '<div class="code"><div class="cap">definition</div><pre><code>'
			.. Highlight.Render(member.signature)
			.. "</code></pre></div>"
	end

	local documentedParams = 0
	for _, param in member.params do
		if param.desc then
			documentedParams += 1
		end
	end
	if documentedParams > 0 then
		local rows: { string } = {}
		for _, param in member.params do
			rows[#rows + 1] = `<tr><td class="mono">{escape(param.name)}</td><td class="mono">{
				if param.type then escape(param.type) else "—"
			}</td><td>{if param.desc then Markdown.Inline(param.desc, mdOpts) else ""}</td></tr>`
		end
		out[#out + 1] = '<div class="tbl"><div class="scroll"><table><thead><tr><th>Param</th><th>Type</th><th>Description</th></tr></thead><tbody>'
			.. table.concat(rows)
			.. "</tbody></table></div></div>"
	end

	if member.returnType or #member.doc.returns > 0 then
		local piece = '<p class="rets"><span class="rlbl">RETURNS</span>'
		if member.returnType then
			piece ..= " <code>" .. escape(member.returnType) .. "</code>"
		end
		if #member.doc.returns > 0 then
			piece ..= (if member.returnType then " — " else " ") .. Markdown.Inline(table.concat(member.doc.returns, "; "), mdOpts)
		end
		out[#out + 1] = piece .. "</p>"
	end

	out[#out + 1] = "</div></div>"
	return table.concat(out, "\n")
end

local function renderModule(module: Model.Module, mdOpts: Markdown.Options, suppressLead: boolean): string
	local out: { string } = {}
	out[#out + 1] = `<section id="{module.anchor}">`
	out[#out + 1] = `<h2><span class="sn">{module.number}</span> {escape(module.name)}{realmTag(module.realm)}</h2>`
	if module.summary and not suppressLead then
		out[#out + 1] = '<p class="lead">' .. Markdown.Inline(module.summary, mdOpts) .. "</p>"
	end
	if #module.bodyLines > 0 then
		out[#out + 1] = Markdown.RenderLines(module.bodyLines, mdOpts)
	end
	for _, member in module.members do
		out[#out + 1] = renderMember(member, mdOpts)
	end
	out[#out + 1] = "</section>"
	return table.concat(out, "\n")
end

--- Renders a [[Data]] model to the complete HTML document. The theme name is
--- resolved through [[Themes]]; an unknown name warns and falls back to junky.
--- @param model the merged document model from [[Model.Build]]
function Render.Page(model: Model.Data): string
	local theme = Themes.Palettes[model.theme]
	if not theme then
		table.insert(model.warnings, `unknown theme "{model.theme}", using junky`)
		theme = Themes.Palettes.junky
	end

	local mdOpts: Markdown.Options = {
		resolve = function(target: string): string?
			return model.registry[target]
		end,
		warn = function(message: string)
			table.insert(model.warnings, message)
		end,
	}

	-- sidebar + sections + search index
	local nav: { string } = {}
	local body: { string } = {}
	local index: { string } = {}
	for _, section in model.sections do
		nav[#nav + 1] = `<div class="eyebrow">{escape(section.name)}</div>`
		for _, module in section.modules do
			nav[#nav + 1] = `<a href="#{module.anchor}"><span class="n">{module.number}</span> {escape(module.name)}</a>`
			-- the root module's summary already leads the page; don't repeat it
			body[#body + 1] = renderModule(module, mdOpts, module.isRoot and model.lead == module.summary)
			index[#index + 1] = "{t:" .. jsonString(module.name)
				.. ",a:" .. jsonString(module.anchor)
				.. ",s:" .. jsonString(module.summary or "")
				.. ",k:" .. jsonString(if module.isPage then "guide" else "module") .. "}"
			for _, member in module.members do
				index[#index + 1] = "{t:" .. jsonString(member.name)
					.. ",a:" .. jsonString(member.anchor)
					.. ",s:" .. jsonString(member.doc.summary or "")
					.. ",k:" .. jsonString(member.kind) .. "}"
			end
		end
	end

	local accent = string.gsub(theme.dark["accent"], "#", "%%23")
	local versionText = if model.version then "v" .. model.version else ""
	local metaVersion = if model.version then escape(model.version) else "—"
	local titleEscaped = escape(model.title)

	local head = table.concat({
		"<!doctype html>",
		'<html lang="en">',
		"<head>",
		'<meta charset="utf-8">',
		'<meta name="viewport" content="width=device-width, initial-scale=1">',
		`<title>{titleEscaped} · API Reference</title>`,
		`<meta name="description" content="API reference for {titleEscaped}, generated by Docket.">`,
		'<meta name="color-scheme" content="light dark">',
		`<meta name="theme-color" content="{theme.light["surface"]}" media="(prefers-color-scheme: light)">`,
		`<meta name="theme-color" content="{theme.dark["surface"]}" media="(prefers-color-scheme: dark)">`,
		`<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Crect width='16' height='16' rx='2' fill='{accent}'/%3E%3Cpath d='M4 4h5a3 3 0 0 1 0 6H6v2H4z' fill='%23fff'/%3E%3C/svg%3E">`,
		"<style>",
		":root{--font-sans: ui-sans-serif, system-ui, -apple-system, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif;"
			.. "--font-mono: ui-monospace, \"JetBrains Mono\", \"SF Mono\", \"Cascadia Code\", Menlo, Consolas, monospace;"
			.. "color-scheme: light dark;--radius:2px;"
			.. Themes.Variables(theme.light) .. "}",
		"@media (prefers-color-scheme: dark){:root{" .. Themes.Variables(theme.dark) .. "}}",
		':root[data-theme="light"]{color-scheme:light;' .. Themes.Variables(theme.light) .. "}",
		':root[data-theme="dark"]{color-scheme:dark;' .. Themes.Variables(theme.dark) .. "}",
		CSS_BODY,
		"</style>",
		"</head>",
	}, "\n")

	local topbar = table.concat({
		'<div class="topbar">',
		`<div class="brand">{titleEscaped}<small>{escape(versionText)}{if versionText ~= "" then " · " else ""}Docket</small></div>`,
		'<div class="spacer"></div>',
		'<div class="search"><input id="searchBox" type="search" placeholder="Search… ( / )" autocomplete="off" spellcheck="false"><div class="sresults" id="searchResults"></div></div>',
		`<span class="vbadge">API REFERENCE</span>`,
		'<button class="toggle" id="themeBtn" aria-label="Toggle color theme"><span id="themeIcon">&#9680;</span> <span id="themeLbl">Theme</span></button>',
		"</div>",
	}, "\n")

	local titleblock = table.concat({
		'<header class="titleblock">',
		"<div>",
		`<div class="eyebrow">API Reference{if versionText ~= "" then " · " .. escape(versionText) else ""}</div>`,
		`<h1>{titleEscaped}</h1>`,
		if model.lead then '<p class="lead">' .. Markdown.Inline(model.lead, mdOpts) .. "</p>" else "",
		"</div>",
		'<dl class="tb-meta">',
		`<div><dt>Version</dt><dd>{metaVersion}</dd></div>`,
		"<div><dt>Platform</dt><dd>Roblox · Luau</dd></div>",
		`<div><dt>License</dt><dd>{if model.license then escape(model.license) else "—"}</dd></div>`,
		"</dl>",
		"</header>",
	}, "\n")

	local footerRepo = if model.repo then ` · <a href="{escape(model.repo)}">{escape(model.repo)}</a>` else ""

	return table.concat({
		head,
		"<body>",
		topbar,
		'<div class="shell">',
		'<aside class="sidebar" aria-label="Contents"><nav class="nav" id="toc">',
		table.concat(nav, "\n"),
		"</nav></aside>",
		"<main>",
		titleblock,
		table.concat(body, "\n"),
		"</main>",
		"</div>",
		`<footer>{titleEscaped} · API Reference · generated by Docket{footerRepo}</footer>`,
		"<script>",
		"var DOCKET_INDEX=[" .. table.concat(index, ",") .. "];",
		SCRIPT,
		"</script>",
		"</body>",
		"</html>",
	}, "\n")
end

return Render

end

__modules["Docket"] = function()
--- Docket reads real Luau source plus a small `---` doc grammar and emits one
--- self-contained HTML page — the site you are reading right now.
---
--- The core idea: **types are never written in doc comments**. Signatures,
--- parameter types, return types, and `export type` bodies are parsed from the
--- code by [[Scanner.Scan]], so the docs cannot go stale — a `@param` that
--- disagrees with the signature is a build warning.
---
--- One build is four passes over your project:
---
--- - [[Scanner]] tokenizes each file (via [[Lexer]]) and pairs every `---`
---   block with the declaration below it
--- - [[Grammar]] parses each block into prose and tags
--- - [[Model]] merges scans into sections, validates params, resolves links
--- - [[Render]] emits the page: template, theme, search index, no external requests
---
--- ```lua running a build
--- -- lune run Docket [path/to/project], or from another script:
--- local Docket = require("Docket")
--- local result = Docket.Build(".")
--- print(result.moduleCount, "modules ->", result.outputPath)
--- ```
--- @section Overview

local fs = __lune_fs
local luau = __lune_luau

local Model = __require("Model")
local Render = __require("Render")

local Docket = {}

--- What [[Docket.Build]] hands back. `ok` is false when nothing was documented
--- (in that case no output file is written at all).
type BuildResult = {
	ok: boolean,
	outputPath: string?,
	warnings: { string },
	moduleCount: number,
	memberCount: number,
}

local function loadConfig(root: string, warnings: { string }): Model.Config
	local configPath = root .. "/docket.luau"
	if not fs.isFile(configPath) then
		return {}
	end
	local ok, result = pcall(function()
		local chunk = luau.load(fs.readFile(configPath), { debugName = configPath })
		return chunk()
	end)
	if ok and type(result) == "table" then
		return result :: Model.Config
	end
	warnings[#warnings + 1] = `{configPath}: config did not load as a table; using defaults`
	return {}
end

--- Builds the docs for one project: loads `docket.luau` if present, scans the
--- source tree, and writes `<Output>/index.html` plus a `.nojekyll` marker so
--- the folder can be pushed straight to a `gh-pages` branch.
---
--- Zero-config defaults: source `src/`, output `docs/`, title/version/license
--- read from `wally.toml`, lead paragraph from the root module's summary. See
--- [[Config]] for everything a `docket.luau` can override.
---
--- @param root project directory (default: the current directory)
--- @return counts, warnings, and the written path
function Docket.Build(root: string?): BuildResult
	local projectRoot = string.gsub(root or ".", "/+$", "")
	if projectRoot == "" then
		projectRoot = "/"
	end

	local preWarnings: { string } = {}
	local config = loadConfig(projectRoot, preWarnings)
	local model = Model.Build(projectRoot, config)
	for i, warning in preWarnings do
		table.insert(model.warnings, i, warning)
	end

	local moduleCount = 0
	local memberCount = 0
	for _, section in model.sections do
		for _, module in section.modules do
			moduleCount += 1
			memberCount += #module.members
		end
	end

	if moduleCount == 0 then
		table.insert(model.warnings, "no documented modules found — nothing written")
		return {
			ok = false,
			outputPath = nil,
			warnings = model.warnings,
			moduleCount = 0,
			memberCount = 0,
		}
	end

	local html = Render.Page(model)
	local outDir = projectRoot .. "/" .. model.output
	if not fs.isDir(outDir) then
		fs.writeDir(outDir)
	end
	local outputPath = outDir .. "/index.html"
	fs.writeFile(outputPath, html)
	fs.writeFile(outDir .. "/.nojekyll", "")

	return {
		ok = true,
		outputPath = outputPath,
		warnings = model.warnings,
		moduleCount = moduleCount,
		memberCount = memberCount,
	}
end

return Docket

end

local Docket = __require("Docket")

local target = __lune_process.args[1] or "."
local result = Docket.Build(target)

for _, warning in result.warnings do
	print(`  warn  {warning}`)
end
if result.ok then
	print(`docket  {result.moduleCount} modules · {result.memberCount} members -> {result.outputPath}`)
else
	__lune_process.exit(1)
end
