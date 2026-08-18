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

--- Echoes the line the player typed, the way a shell does.
function Interface.Echo(self: Interface, text: string)
	self.Container:Write(self.Main, "Input", text)
end

--- Prints a resolve into the main window, choosing its tone from the kind.
function Interface.Resolve(self: Interface, resolve: Types.CommandResolve)
	local kind: Types.HistoryKind = if resolve.Resolved
		then "Ok"
		elseif resolve.Kind == "Warn" or resolve.Kind == "OnCooldown" then "Warn"
		else "Fail"

	if resolve.Content then
		self.Container:Write(self.Main, kind, "", resolve.Content)

		return
	end

	if resolve.Output and resolve.Output ~= "" then
		self.Container:Write(self.Main, kind, resolve.Output)
	end
end

--- Output arriving is what turns a bar into a terminal, so anything that
--- writes makes sure the window is expanded to show it.
function Interface.Reveal(self: Interface)
	if not self.Container.Shown then
		self.Container:Show()
	end

	self.Container:Expand(self.Main)
end

function Interface.Write(self: Interface, kind: Types.HistoryKind, text: string, content: Types.ContentElement?)
	self.Container:Write(self.Main, kind, text, content)
end

function Interface.Clear(self: Interface)
	self.Container:Clear(self.Main)
end

--- Shows the console and opens it into a terminal.
function Interface.Show(self: Interface)
	self.Container:Show()
	self.Container:FocusWindow(self.Main)
end

function Interface.Hide(self: Interface)
	self.Suggestions:Hide()
	self.Container:Hide()
end

--- The activation key. Konsole toggles between a collapsed pill and an open
--- terminal rather than between shown and gone, so that is what this does:
--- hidden opens, collapsed expands, expanded collapses.
function Interface.Toggle(self: Interface)
	if not self.Container.Shown then
		Interface.Show(self)

		return
	end

	if self.Container:Expanded(self.Main) then
		self.Suggestions:Hide()
		self.Container:Collapse(self.Main)
	else
		self.Container:FocusWindow(self.Main)
	end
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
