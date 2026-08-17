--!strict

--- The shell: one Lume app hosting any number of console windows.
---
--- This is a transpile of Konsole's console, not an approximation of it. The
--- behaviour it reproduces:
---
--- **Three widths, not one.** Collapsed the bar is `CollapsedWidth` (204).
--- Expanded with nothing to show it is `Width` (252). Once it has output it is
--- `OutputWidth` (338) — and from there it grows to whatever its longest line
--- needs, clamped by the viewport. That is Konsole's `activeWidth`:
--- `base = hasOutput and outputWidth or width`, then `max(base, measured)`.
---
--- **A collapsed bar is a button.** Click it and it expands, focuses, and
--- reveals its history. Collapsed, the input hides itself when empty so only
--- the placeholder shows.
---
--- **The morph.** Pill while it is one row tall, `OutputRadius` (12) once it
--- has grown. Lume does that; the numbers are Konsole's.
---
--- Konsole hardcoded two channels and branched on `channel == 2` throughout.
--- Here a window is an entry in `Windows`, and nothing asks which one it is.

local Types = require(script.Parent.Parent.Parent.Parent.Types)
local Window = require(script.Parent.Parent.Parent.Parent._Classes.Window)
local Lume = require(script.Parent.Parent.Parent.Parent._Packages.Lume)

--// siblings in Elements/, not children of this file
local Lines = require(script.Parent.Lines)
local ConsoleInput = require(script.Parent.Input)

type WindowConfig = Types.WindowConfig

local Container = {}
Container.__index = Container

export type View = {
	Window: any,
	Panel: any,
	Lines: any,
	Input: any,
	Expanded: boolean,
}

export type Fields = {
	App: any,
	Theme: any,
	Stack: any,
	Windows: { [string]: View },
	Order: { string },
	Focus: string?,
	--// `Shown`, not `Open`: a field of that name would shadow the `Open`
	--// METHOD, since raw fields win over the metatable
	Shown: boolean,
	OnSubmit: ((id: string, text: string) -> ())?,
	OnChange: ((id: string, text: string) -> ())?,
	OnExpand: ((id: string, expanded: boolean) -> ())?,
}

export type Container = typeof(setmetatable({} :: Fields, Container))

--// locals ---------------------------------------------------------------------
--- Applies the console's metrics onto a Lume panel.
local function shape(panel: any, theme: any, config: WindowConfig)
	panel:setAnchor(if config.Docked == false then "center" else "bottom")
	panel:setInset(theme.Spacing.ViewportInset)
	panel:setPadding(theme.Spacing.PaddingX, theme.Spacing.PaddingY)
	panel:setGap(theme.Spacing.PaddingY)
	panel:setRadius("pill")
	panel:setColor(theme.Color.Background)
	panel:setTransparency(theme.Transparency.Panel)
	panel:setBorder(false)
	panel:setDraggable(true)

	--// no shadow. Konsole's was a nine-sliced asset tuned to its own instance
	--// tree; tracked against a Lume panel it reads as a smear behind the bar,
	--// and the console is perfectly legible without it
	panel:setShadow(false)

	--// starts collapsed: a fixed-width pill, no content growth
	panel:setWidth(theme.Size.CollapsedWidth)
	panel:setMaxSize(100000, theme.Size.HistoryMaxHeight + theme.Size.Height)

	if config.Position then
		panel:moveTo(config.Position)
	end
end

--// public api ------------------------------------------------------------------
function Container.new(theme: any, options: { App: any?, DisplayOrder: number? }?): Container
	local settings = options or {}

	local app = settings.App
		or Lume.app({
			name = "Astrix",
			displayOrder = settings.DisplayOrder or theme.Size.DisplayOrder,
		})

	--// the console draws no shadows at all, so the token is cleared once here
	--// rather than switched off per panel
	app:restyle({ shadow = { image = "" } })

	local self: Fields = {
		App = app,
		Theme = theme,
		Stack = app:stack("bottom"),
		Windows = {},
		Order = {},
		Focus = nil,
		Shown = false,
		OnSubmit = nil,
		OnChange = nil,
		OnExpand = nil,
	}

	self.Stack:setGap(theme.Spacing.StackGap)

	return setmetatable(self, Container)
end

--- Opens a window, or returns the existing one with that id.
function Container.Open(self: Container, config: WindowConfig): View
	local existing = self.Windows[config.Id]

	if existing then
		existing.Panel:open()

		return existing
	end

	local theme = self.Theme
	local data = Window.new(config)

	local panel = self.App:panel("bar")

	shape(panel, theme, config)

	--// output above input: the panel stacks children down its axis and grows
	--// upward, so this is the console's reading order
	local lines = Lines.new(panel, data, theme)
	local input = ConsoleInput.new(panel, theme)

	local view: View = {
		Window = data,
		Panel = panel,
		Lines = lines,
		Input = input,
		Expanded = false,
	}

	input.OnSubmit = function(text)
		if self.OnSubmit then
			self.OnSubmit(config.Id, text)
		end
	end

	input.OnChange = function(text)
		if self.OnChange then
			self.OnChange(config.Id, text)
		end
	end

	--// a collapsed bar is a button
	panel:setActivatable(true)
	panel:onActivated(function()
		Container.Expand(self, config.Id)
	end)

	self.Windows[config.Id] = view

	table.insert(self.Order, config.Id)

	if config.Docked ~= false then
		self.Stack:add(panel)
	end

	panel:open()

	Container.Collapse(self, config.Id)

	self.Focus = config.Id
	self.Shown = true

	return view
end

--- Re-applies the width rule for a window's current state.
---
--- This is `activeWidth` from Konsole's panel module: collapsed is a fixed
--- pill, expanded starts at `Width`, and having output moves the floor to
--- `OutputWidth` — with Lume free to grow past it for a long line.
function Container.Resize(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	local theme = self.Theme

	if not view.Expanded then
		view.Panel:setWidth(theme.Size.CollapsedWidth)

		return
	end

	local hasOutput = #view.Window.History > 0
	local base = if hasOutput then theme.Size.OutputWidth else theme.Size.Width

	view.Panel:setWidth("auto")
	view.Panel:setMinSize(base, 0)
end

--- Opens the bar into a terminal: history visible, input focused.
function Container.Expand(self: Container, id: string)
	local view = self.Windows[id]

	if not view or view.Expanded then
		return
	end

	view.Expanded = true

	--// the click target sits above the content; it has to step aside for the
	--// input to receive anything
	view.Panel:setActivatable(false)

	view.Input:SetVisible(true)
	view.Lines:SetVisible(#view.Window.History > 0)

	Container.Resize(self, id)

	self.Focus = id

	view.Panel:front()
	view.Input:Focus()

	if self.OnExpand then
		self.OnExpand(id, true)
	end
end

--- Shrinks back to the pill. An empty input hides so only the placeholder
--- shows, which is what makes the collapsed bar read as a prompt.
function Container.Collapse(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	view.Expanded = false

	--// the input ROW stays: collapsed, the console still shows its prompt and
	--// placeholder, which is what makes the pill read as something you can type
	--// into. Konsole hides the TextBox, not the row — the difference is the
	--// caret, not the 34px of height
	view.Input:Blur()
	view.Lines:SetVisible(false)

	Container.Resize(self, id)

	view.Panel:setActivatable(true)

	if self.OnExpand then
		self.OnExpand(id, false)
	end
end

function Container.ToggleExpanded(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	if view.Expanded then
		Container.Collapse(self, id)
	else
		Container.Expand(self, id)
	end
end

function Container.Expanded(self: Container, id: string): boolean
	local view = self.Windows[id]

	return view ~= nil and view.Expanded
end

function Container.Close(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	view.Panel:close()
	view.Panel:destroy()

	self.Windows[id] = nil

	local at = table.find(self.Order, id)

	if at then
		table.remove(self.Order, at)
	end

	if self.Focus == id then
		self.Focus = self.Order[#self.Order]
	end

	if #self.Order == 0 then
		self.Shown = false
	end
end

function Container.Get(self: Container, id: string): View?
	return self.Windows[id]
end

function Container.List(self: Container): { string }
	return table.clone(self.Order)
end

--- Writes into a window and repaints it.
---
--- The first line of output is what turns a bar into a terminal, so the width
--- rule is re-applied on every write.
function Container.Write(
	self: Container,
	id: string,
	kind: Types.HistoryKind,
	text: string,
	content: Types.ContentElement?
)
	local view = self.Windows[id]

	if not view then
		return
	end

	if content then
		view.Window:WriteContent(content, kind)
	else
		view.Window:Write(kind, text)
	end

	view.Lines:Render()

	if view.Expanded then
		view.Lines:SetVisible(#view.Window.History > 0)

		Container.Resize(self, id)
	end
end

function Container.Clear(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	view.Window:Clear()
	view.Lines:Render()
	view.Lines:SetVisible(false)

	Container.Resize(self, id)
end

--- Raises a window, expands it and puts the caret in it.
function Container.FocusWindow(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	self.Focus = id

	view.Panel:front()

	Container.Expand(self, id)
end

--- The stacking order, newest last. Mirrors `RuntimeEntry.Interface.State`.
function Container.ZOrder(self: Container): { string }
	return table.clone(self.Order)
end

function Container.Show(self: Container)
	for _, id in self.Order do
		self.Windows[id].Panel:open()
	end

	self.Shown = true
end

function Container.Hide(self: Container)
	for _, id in self.Order do
		Container.Collapse(self, id)

		self.Windows[id].Panel:close()
	end

	self.Shown = false
end

function Container.Toggle(self: Container)
	if self.Shown then
		Container.Hide(self)
	else
		Container.Show(self)
	end
end

--- Re-applies a theme to every window that already exists.
---
--- Colours and transparencies are pushed onto the live instances rather than
--- rebuilt, so switching themes keeps your history, your scroll position and
--- whatever you were half-way through typing.
function Container.Restyle(self: Container, theme: any)
	self.Theme = theme

	for _, id in self.Order do
		local view = self.Windows[id]

		view.Panel:setColor(theme.Color.Background)
		view.Panel:setTransparency(theme.Transparency.Panel)

		view.Input:Restyle(theme)
		view.Lines:Restyle(theme)

		Container.Resize(self, id)
	end
end

function Container.Destroy(self: Container)
	for id in self.Windows do
		Container.Close(self, id)
	end

	self.App:destroy()
end

return Container
