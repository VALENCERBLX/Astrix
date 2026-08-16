--!strict

--- The shell: one Lume app hosting any number of console windows.
---
--- Konsole hardcoded two channels and branched on `channel == 2` throughout.
--- Here a window is just an entry in `Windows`, stacked in `Order`, and nothing
--- asks which one it is. Opening a third costs the same as opening the second.
---
--- Each window is a Lume `bar` panel: a collapsed pill that grows upward as
--- output arrives and morphs from pill to rounded rectangle on the way. That
--- behaviour is Lume's, which is why none of Konsole's spring maths came over.

local Types = require(script.Parent.Parent.Parent.Parent.Types)
local Window = require(script.Parent.Parent.Parent.Parent._Classes.Window)
local Packages = require(script.Parent.Parent.Parent.Parent._Packages)

--// siblings in Elements/, not children of this file
local Lines = require(script.Parent.Lines)
local ConsoleInput = require(script.Parent.Input)

type WindowConfig = Types.WindowConfig

local Container = {}
Container.__index = Container

local Lume = Packages.Lume()

export type View = {
	Window: any,
	Panel: any,
	Lines: any,
	Input: any,
}

export type Fields = {
	App: any,
	Theme: any,
	Stack: any,
	Windows: { [string]: View },
	Order: { string },
	Focus: string?,
	Open: boolean,
	OnSubmit: ((id: string, text: string) -> ())?,
	OnChange: ((id: string, text: string) -> ())?,
}

export type Container = typeof(setmetatable({} :: Fields, Container))

--// locals ---------------------------------------------------------------------
--- Applies the console's own metrics onto a Lume panel.
local function shape(panel: any, theme: any, config: WindowConfig)
	panel:setAnchor(if config.Docked == false then "center" else "bottom")
	panel:setInset(theme.Spacing.ViewportInset)
	panel:setPadding(theme.Spacing.PaddingX, theme.Spacing.PaddingY)
	panel:setGap(theme.Spacing.PaddingY)
	panel:setRadius("pill")
	panel:setWidth("auto")
	panel:setMinSize(config.Width or theme.Size.CollapsedWidth, 0)
	panel:setMaxSize(100000, theme.Size.HistoryMaxHeight + theme.Size.Height)
	panel:setColor(theme.Color.Background)
	panel:setTransparency(theme.Transparency.Panel)
	panel:setDraggable(true)
	panel:setShadow(true)

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

	local self: Fields = {
		App = app,
		Theme = theme,
		Stack = app:stack("bottom"),
		Windows = {},
		Order = {},
		Focus = nil,
		Open = false,
		OnSubmit = nil,
		OnChange = nil,
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

	self.Windows[config.Id] = view

	table.insert(self.Order, config.Id)

	if config.Docked ~= false then
		self.Stack:add(panel)
	end

	panel:open()

	self.Focus = config.Id
	self.Open = true

	return view
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
		self.Open = false
	end
end

function Container.Get(self: Container, id: string): View?
	return self.Windows[id]
end

function Container.List(self: Container): { string }
	return table.clone(self.Order)
end

--- Writes into a window and repaints it.
function Container.Write(self: Container, id: string, kind: Types.HistoryKind, text: string, content: Types.ContentElement?)
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
end

function Container.Clear(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	view.Window:Clear()
	view.Lines:Render()
end

--- Raises a window and puts the caret in it.
function Container.FocusWindow(self: Container, id: string)
	local view = self.Windows[id]

	if not view then
		return
	end

	self.Focus = id

	view.Panel:front()
	view.Input:Focus()
end

--- The stacking order, newest last. Mirrors `RuntimeEntry.Interface.State`.
function Container.ZOrder(self: Container): { string }
	return table.clone(self.Order)
end

function Container.Show(self: Container)
	for _, id in self.Order do
		self.Windows[id].Panel:open()
	end

	self.Open = true
end

function Container.Hide(self: Container)
	for _, id in self.Order do
		self.Windows[id].Panel:close()
	end

	self.Open = false
end

function Container.Toggle(self: Container)
	if self.Open then
		Container.Hide(self)
	else
		Container.Show(self)
	end
end

function Container.Destroy(self: Container)
	for id in self.Windows do
		Container.Close(self, id)
	end

	self.App:destroy()
end

return Container
