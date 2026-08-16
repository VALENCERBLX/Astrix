--!strict

--- Text helpers shared by the elements: RichText escaping, tag stripping for
--- measurement, truncation, and match highlighting.
---
--- Stripping matters more than it looks. `GetTextSize` does not parse RichText,
--- so measuring `<b>hello</b>` measures seventeen characters and the element
--- comes out a third too wide. Every element that renders rich text measures
--- the stripped form instead.
--- @section Core

local Text = {}

local ESCAPES: { [string]: string } = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&apos;",
}

--- Escapes a string so RichText renders it literally.
function Text.escape(text: string): string
	return (string.gsub(text, "[&<>\"']", ESCAPES))
end

--- Removes RichText tags, leaving what the user will actually see. Used for
--- measurement, never for display.
function Text.strip(text: string): string
	local without = string.gsub(text, "<[^<>]->", "")

	without = string.gsub(without, "&lt;", "<")
	without = string.gsub(without, "&gt;", ">")
	without = string.gsub(without, "&quot;", '"')
	without = string.gsub(without, "&apos;", "'")
	without = string.gsub(without, "&amp;", "&")

	return without
end

--- Cuts a string to `limit` characters, ending in an ellipsis.
function Text.truncate(text: string, limit: number): string
	if limit <= 0 or #text <= limit then
		return text
	end

	return string.sub(text, 1, math.max(1, limit - 1)) .. "…"
end

--- Wraps a span in a RichText colour tag.
function Text.color(text: string, hex: string): string
	return `<font color="{hex}">{text}</font>`
end

function Text.bold(text: string): string
	return `<b>{text}</b>`
end

--- Highlights the first case-insensitive occurrence of `match` inside `text`,
--- dimming the rest. This is the autocomplete look.
function Text.highlight(text: string, match: string, base: string, accent: string): string
	if match == "" then
		return Text.color(Text.escape(text), base)
	end

	local from, to = string.find(string.lower(text), string.lower(match), 1, true)

	if not from then
		return Text.color(Text.escape(text), base)
	end

	return Text.color(Text.escape(string.sub(text, 1, from - 1)), base)
		.. Text.color(Text.bold(Text.escape(string.sub(text, from, to))), accent)
		.. Text.color(Text.escape(string.sub(text, to + 1)), base)
end

--- A simple subsequence score: does every character of `query` appear in
--- `candidate` in order, and how tightly packed are they? Returns whether it
--- matched and a score where lower is better.
function Text.fuzzy(candidate: string, query: string): (boolean, number)
	if query == "" then
		return true, 0
	end

	local haystack = string.lower(candidate)
	local needle = string.lower(query)

	local cursor = 1
	local score = 0
	local previous = 0

	for index = 1, #needle do
		local character = string.sub(needle, index, index)
		local found = string.find(haystack, character, cursor, true)

		if not found then
			return false, math.huge
		end

		--// gaps between matched characters cost; a prefix match scores zero
		score += (found - previous - 1)
		previous = found
		cursor = found + 1
	end

	return true, score
end

return Text
