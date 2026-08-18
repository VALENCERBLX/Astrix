--!strict

--- Transient notices, stacked in a corner.
---
--- The same surface as the console — the palette, the radius, the motion — so
--- an announcement reads as coming from the same place the console does. What
--- differs is one accent bar down the left edge, coloured by tone, because a
--- toast has to be legible at a glance rather than read.
---
--- Toasts are shown to **everyone**, including players who could never run the
--- command that produced them. That is the point of an announcement.
--- @section Console

local Types = require(script.Parent.Parent.Parent.Parent.Types)
local Lume = require(script.Parent.Parent.Parent.Parent._Packages.Lume)

local Toast = {}
Toast.__index = Toast

export type Tone = "Info" | "Ok" | "Warn" | "Error" | "Announce"

export type Config = {
	Anchor: Types.Anchor?,
	Duration: number?,
	Max: number?,
	Gap: number?,
	Width: number?,
}

export type Live = {
	Panel: any,
	Expires: number,
}

export type Fields = {
	App: any,
	Theme: any,
	Stack: any,
	Live: { Live },

	Anchor: Types.Anchor,
	Duration: number,
	Max: number,
	Width: number,
}

export type Toast = typeof(setmetatable({} :: Fields, Toast))

--// locals ---------------------------------------------------------------------
local function toneColour(theme: any, tone: Tone): Color3
	if tone == "Error" then
		return theme.Color.Error
	elseif tone == "Warn" then
		return theme.Color.Warn
	elseif tone == "Ok" then
		return theme.Color.Success
	elseif tone == "Announce" then
		return theme.Accent.Primary
	end

	return theme.Color.TextMuted
end

--// public api ------------------------------------------------------------------
function Toast.new(app: any, theme: any, config: Config?): Toast
	local settings = config or {}
	local anchor: Types.Anchor = settings.Anchor or "bottomRight"

	local self: Fields = {
		App = app,
		Theme = theme,
		Stack = app:stack(anchor),
		Live = {},

		Anchor = anchor,
		Duration = settings.Duration or 5,
		Max = settings.Max or 4,
		Width = settings.Width or 320,
	}

	self.Stack:setGap(settings.Gap or theme.Spacing.StackGap)

	return setmetatable(self, Toast)
end

--- Shows a notice. Returns the panel, so a caller can hold on to it.
function Toast.Show(self: Toast, text: string, tone: Tone?, duration: number?): any
	local theme = self.Theme
	local resolved: Tone = tone or "Info"

	local panel = self.App:panel("toast")

	panel:setAnchor(self.Anchor)
	panel:setInset(theme.Spacing.ViewportInset)
	panel:setPadding(theme.Spacing.PaddingX, theme.Spacing.PaddingY + 3)
	panel:setGap(theme.Spacing.ItemGap)
	panel:setRadius(theme.Radius.Suggestion)
	panel:setColor(theme.Color.Background)
	panel:setTransparency(theme.Transparency.Panel)
	panel:setBorder(false)
	panel:setShadow(false)
	panel:setMaxSize(self.Width, 400)
	panel:setDraggable(false)

	--// a row: the accent bar, then the message
	local row = panel:group("horizontal")

	row:setFill(true)
	row:setGap(theme.Spacing.ItemGap + 2)

	local bar = row:icon("")

	bar:setIconSize(3)
	bar:setProps({
		BackgroundColor3 = toneColour(theme, resolved),
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(3, 16),
	})

	local label = row:label(text)

	label:setWrapped(true)
	label:setTextSize(theme.TextSize.Suggestion)
	label:setColor(theme.Color.TextPrimary)
	label:setMaxLines(4)

	panel:open()

	self.Stack:add(panel)

	local entry: Live = { Panel = panel, Expires = os.clock() + (duration or self.Duration) }

	table.insert(self.Live, entry)

	--// oldest first, so a burst of announcements does not bury the screen
	while #self.Live > self.Max do
		local oldest = table.remove(self.Live, 1)

		if oldest then
			Toast.Dismiss(self, oldest.Panel)
		end
	end

	task.delay(duration or self.Duration, function()
		Toast.Dismiss(self, panel)
	end)

	return panel
end

--- Fades a toast out and takes it off the stack.
function Toast.Dismiss(self: Toast, panel: any)
	for index, entry in self.Live do
		if entry.Panel == panel then
			table.remove(self.Live, index)

			break
		end
	end

	if not panel:alive() then
		return
	end

	panel:close()

	self.Stack:remove(panel)

	--// destroyed only after the exit animation, or it vanishes rather than
	--// fading
	task.delay(self.Theme.Motion.Collapse, function()
		if panel:alive() then
			panel:destroy()
		end
	end)
end

function Toast.Clear(self: Toast)
	for index = #self.Live, 1, -1 do
		Toast.Dismiss(self, self.Live[index].Panel)
	end
end

function Toast.Restyle(self: Toast, theme: any)
	self.Theme = theme
end

function Toast.Destroy(self: Toast)
	Toast.Clear(self)

	self.Stack:destroy()
end

return Toast
