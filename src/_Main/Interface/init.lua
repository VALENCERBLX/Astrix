--!strict

--- The interface layer: a `Container` of windows, a suggestion dropdown, and
--- the wiring between them and a Kyn session.
---
--- Everything visual is Lume's. This module's job is deciding *what* to show —
--- when to update completions, which window a result belongs to, what the
--- prompt looks like — not how to draw or animate it.
--- @section Console

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Themes = require(script.Parent.Parent._Themes)

local Container = require(script.Elements.Container)
local Suggestions = require(script.Elements.Suggestions)

local Interface = {}
Interface.__index = Interface

export type Config = {
	Theme: string?,
	Registry: any,
	Session: any,
	Providers: { [string]: any },
	OnSubmit: ((text: string) -> ())?,
	Keybind: Enum.KeyCode?,
	App: any?,
}

export type Fields = {
	Theme: any,
	Container: any,
	Suggestions: any,
	Session: any,
	Registry: any,
	Main: string,
	Bindings: { () -> () },
	LastActivate: number,
	OnSubmit: ((text: string) -> ())?,
}

export type Interface = typeof(setmetatable({} :: Fields, Interface))

local MAIN_WINDOW = "Main"

--// public api ------------------------------------------------------------------
function Interface.new(config: Config): Interface
	local theme = Themes.Resolve(config.Theme)
	local container = Container.new(theme, { App = config.App })

	local self: Fields = {
		Theme = theme,
		Container = container,
		Suggestions = nil :: any,
		Session = config.Session,
		Registry = config.Registry,
		Main = MAIN_WINDOW,
		Bindings = {},
		LastActivate = 0,
		OnSubmit = config.OnSubmit,
	}

	local interface = setmetatable(self, Interface)

	local view = container:Open({ Id = MAIN_WINDOW, Title = "Astrix", Docked = true })

	self.Suggestions = Suggestions.new(
		container.App,
		theme,
		config.Registry,
		config.Session,
		config.Providers
	)

	self.Suggestions:Attach(view.Panel, view.Input.Field)

	container.OnChange = function(_, text)
		local box = view.Input.Field.refs.input :: TextBox

		self.Suggestions:Update(text, box.CursorPosition)
	end

	container.OnSubmit = function(_, text)
		self.Suggestions:Hide()

		if text ~= "" and self.OnSubmit then
			self.OnSubmit(text)
		end
	end

	table.insert(self.Bindings, view.Input:BindLeaping())
	table.insert(self.Bindings, Interface.BindKeys(interface, view))

	return interface
end

local CONSOLE_ACTION = "AstrixConsoleKeys"
local CONSOLE_PRIORITY = 10002

--- Binds Tab, the arrows and Escape while the console has the keyboard.
---
--- Bound through ContextActionService and **sunk**, not observed. An
--- InputBegan listener runs alongside the TextBox rather than instead of it,
--- so pressing Tab both accepted the completion *and* let Roblox insert a
--- literal tab into the field. Stripping it afterwards is a race the tab
--- sometimes wins; sinking the key means the field never sees it at all.
---
--- Bound only while the console owns the keyboard, so Tab and the arrows
--- behave normally everywhere else in the game.
function Interface.BindKeys(self: Interface, view: any): () -> ()
	local function handle(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if not self.Container.Shown or not view.Input:Focused() then
			return Enum.ContextActionResult.Pass
		end

		local code = input.KeyCode
		local visible = self.Suggestions:Visible()

		if code == Enum.KeyCode.Tab then
			--// accept whether or not the list is showing: the ghost hint after
			--// the caret is the same match, seen a different way
			if visible or self.Suggestions:Highlighted() then
				self.Suggestions:Accept()
			end

			--// sunk either way, so a stray tab never reaches the field
			return Enum.ContextActionResult.Sink
		end

		if code == Enum.KeyCode.Up then
			if visible then
				self.Suggestions:Previous()
			else
				view.Input:Recall(-1)
			end

			return Enum.ContextActionResult.Sink
		end

		if code == Enum.KeyCode.Down then
			if visible then
				self.Suggestions:Next()
			else
				view.Input:Recall(1)
			end

			return Enum.ContextActionResult.Sink
		end

		if code == Enum.KeyCode.Escape then
			if visible then
				self.Suggestions:Hide()
			elseif self.Container:Expanded(self.Main) then
				self.Container:Collapse(self.Main)
			else
				self.Container:Hide()
			end

			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority(
		CONSOLE_ACTION,
		handle,
		false,
		CONSOLE_PRIORITY,
		Enum.KeyCode.Tab,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Escape
	)

	return function()
		ContextActionService:UnbindAction(CONSOLE_ACTION)
	end
end

--- Which window output belongs to: whichever one has focus, falling back to
--- the main one. Every window keeps its own history, so cycling to a second
--- and running something there leaves the first untouched.
function Interface.Target(self: Interface): string
	local focus = self.Container.Focus

	if focus and self.Container:Get(focus) then
		return focus
	end

	return self.Main
end

--- Echoes the line the player typed, the way a shell does.
function Interface.Echo(self: Interface, text: string)
	self.Container:Write(Interface.Target(self), "Input", text)
end

--- Prints a resolve into the main window, choosing its tone from the kind.
function Interface.Resolve(self: Interface, resolve: Types.CommandResolve)
	local kind: Types.HistoryKind = if resolve.Resolved
		then "Ok"
		elseif resolve.Kind == "Warn" or resolve.Kind == "OnCooldown" then "Warn"
		else "Fail"

	local target = Interface.Target(self)

	if resolve.Content then
		self.Container:Write(target, kind, "", resolve.Content)

		return
	end

	if resolve.Output and resolve.Output ~= "" then
		self.Container:Write(target, kind, resolve.Output)
	end
end

--- Output arriving is what turns a bar into a terminal, so anything that
--- writes makes sure the window is expanded to show it.
function Interface.Reveal(self: Interface)
	if not self.Container.Shown then
		self.Container:Show()
	end

	self.Container:Expand(Interface.Target(self))
end

function Interface.Write(self: Interface, kind: Types.HistoryKind, text: string, content: Types.ContentElement?)
	self.Container:Write(Interface.Target(self), kind, text, content)
end

function Interface.Clear(self: Interface)
	self.Container:Clear(self.Main)
end

--- Shows the console and opens it into a terminal.
function Interface.Show(self: Interface)
	self.Container:Show()

	Interface.FocusWindow(self, Interface.Target(self))
end

function Interface.Hide(self: Interface)
	self.Suggestions:Hide()
	self.Container:Hide()
end

--- The activation key.
---
--- Pressed on its own it toggles between a collapsed pill and an open terminal,
--- the way Konsole does — hidden opens, collapsed expands, expanded collapses.
---
--- Pressed **again within `CYCLE_WINDOW`** and with more than one window open,
--- it moves to the next window instead. Tapping it three times quickly lands on
--- the third; pausing resets, so the same key is both "open the console" and
--- "the one after this", without a second binding to remember.
local CYCLE_WINDOW = 1.5

function Interface.Toggle(self: Interface)
	local now = os.clock()
	local rapid = (now - self.LastActivate) <= CYCLE_WINDOW

	self.LastActivate = now

	if not self.Container.Shown then
		Interface.Show(self)

		return
	end

	local order = self.Container:List()

	if rapid and #order > 1 then
		--// step from where focus actually IS, not from a counter. A counter
		--// drifts the moment anything else moves focus — clicking a window,
		--// opening one, closing one — and the first press then jumps somewhere
		--// arbitrary instead of to the next window along
		local current = table.find(order, Interface.Target(self)) or 0

		Interface.FocusWindow(self, order[(current % #order) + 1])

		return
	end

	local target = Interface.Target(self)

	if self.Container:Expanded(target) then
		self.Suggestions:Hide()
		self.Container:Collapse(target)
	else
		Interface.FocusWindow(self, target)
	end
end

--- Focuses a window and re-points the dropdown at its input, so completion
--- happens in the window you are actually typing into.
function Interface.FocusWindow(self: Interface, id: string)
	local view = self.Container:Get(id)

	if not view then
		return
	end

	self.Suggestions:Hide()
	self.Suggestions:Attach(view.Panel, view.Input.Field)

	self.Container:FocusWindow(id)
end

--- Whether the main window is open as a terminal rather than a bar.
function Interface.Expanded(self: Interface): boolean
	return self.Container:Expanded(self.Main)
end

--- How many console windows may exist at once. Three by default.
function Interface.SetMaxWindows(self: Interface, count: number)
	self.Container:SetMaxWindows(count)
end

--- Switches theme at runtime. Returns the applied theme, or nil if unknown.
function Interface.SetTheme(self: Interface, name: string): any
	local resolved = Themes.Resolve(name)

	--// Resolve falls back to Default on an unknown name, so an unrecognised
	--// one is detected by comparing rather than by trusting the return
	if string.lower(resolved.Name) ~= string.lower(name) then
		return nil
	end

	self.Theme = resolved

	self.Container:Restyle(resolved)

	return resolved
end

function Interface.ThemeName(self: Interface): string
	return self.Theme.Name
end

--- `Astrix.Windows` — commands reach this as `ctx.Windows`.
function Interface.Windows(self: Interface)
	local container = self.Container

	return {
		Open = function(config: Types.WindowConfig)
			return container:Open(config)
		end,
		Close = function(id: string)
			container:Close(id)
		end,
		List = function()
			return container:List()
		end,
		Write = function(id: string, text: string, content: Types.ContentElement?)
			container:Write(id, "Output", text, content)
		end,
	}
end

function Interface.Destroy(self: Interface)
	for _, disconnect in self.Bindings do
		disconnect()
	end

	table.clear(self.Bindings)

	self.Suggestions:Destroy()
	self.Container:Destroy()
end

return Interface
