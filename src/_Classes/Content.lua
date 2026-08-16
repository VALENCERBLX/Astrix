--!strict

--- Rich output primitives, shared between the console's own line renderer and
--- any custom window a command opens. One rendering path, not two.

local Types = require(script.Parent.Parent.Types)

type ContentElement = Types.ContentElement

local Content = {}

function Content.Text(value: string, color: Color3?): ContentElement
	return { Kind = "Text", Value = tostring(value), Color = color }
end

--- Headers plus rows. Column widths are the renderer's problem, not yours.
function Content.Table(headers: { string }, rows: { { string } }): ContentElement
	return { Kind = "Table", Headers = headers, Rows = rows }
end

--- `progress` is clamped to 0–1; anything above 1 is read as a percentage.
function Content.ProgressBar(progress: number, label: string?): ContentElement
	local value = tonumber(progress) or 0
	local normalised = if value > 1 then value / 100 else value

	return { Kind = "ProgressBar", Progress = math.clamp(normalised, 0, 1), Label = label }
end

function Content.Ascii(art: string): ContentElement
	return { Kind = "Ascii", Art = art }
end

function Content.Image(assetId: string, size: Vector2?): ContentElement
	return { Kind = "Image", AssetId = assetId, Size = size }
end

function Content.Divider(): ContentElement
	return { Kind = "Divider" }
end

--- Flattens an element into the plain lines a text-only renderer can show.
--- Every element has a textual fallback so nothing is invisible in a log.
function Content.Lines(element: ContentElement): { string }
	local kind = element.Kind

	if kind == "Text" then
		return { (element :: any).Value }
	end

	if kind == "Divider" then
		return { string.rep("─", 24) }
	end

	if kind == "Ascii" then
		return string.split((element :: any).Art, "\n")
	end

	if kind == "Image" then
		return { `[image {(element :: any).AssetId}]` }
	end

	if kind == "ProgressBar" then
		local progress = (element :: any).Progress
		local filled = math.floor(progress * 20 + 0.5)
		local label = (element :: any).Label

		local bar = `[{string.rep("█", filled)}{string.rep("░", 20 - filled)}] {math.floor(progress * 100)}%`

		return { if label then `{label} {bar}` else bar }
	end

	if kind == "Table" then
		local headers = (element :: any).Headers :: { string }
		local rows = (element :: any).Rows :: { { string } }

		local widths: { number } = {}

		for index, header in headers do
			widths[index] = #tostring(header)
		end

		for _, row in rows do
			for index, cell in row do
				widths[index] = math.max(widths[index] or 0, #tostring(cell))
			end
		end

		local function line(cells: { string }): string
			local padded = {}

			for index, width in widths do
				local cell = tostring(cells[index] or "")

				table.insert(padded, cell .. string.rep(" ", width - #cell))
			end

			return table.concat(padded, "  ")
		end

		local out = { line(headers) }

		for _, row in rows do
			table.insert(out, line(row))
		end

		return out
	end

	return { "" }
end

return Content
