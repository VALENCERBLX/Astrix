--!strict

--- The interface layer: a `Container` of windows, a suggestion dropdown, and
--- the wiring between them and a Kyn session.
---
--- Everything visual is Lume's. This module's job is deciding *what* to show —
--- when to update completions, which window a result belongs to, what the
--- prompt looks like — not how to draw or animate it.

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

--- Tab accepts a completion, the arrows walk the dropdown when it is visible
--- and the command history when it is not, and Escape backs out one level.
---
--- These are raw connections for now; they are the set that moves onto Switch's
--- `"AstrixConsole"` context once it is wired, so they go quiet automatically
--- when the console is closed.
function Interface.BindKeys(self: Interface, view: any): () -> ()
	local connection = UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if not self.Container.Shown then
			return
		end

		--// only while the console owns the keyboard. Without this, Tab and the
		--// arrows would still be driving the dropdown while the player is
		--// typing into some other part of the game
		if not view.Input:Focused() then
			return
		end

		local code = input.KeyCode
		local visible = self.Suggestions:Visible()

		--// Tab autofill. The dropdown and the ghost hint are the same thing seen
		--// two ways — the highlighted match is what is ghosted after the caret —
		--// so accepting either is one call
		if code == Enum.KeyCode.Tab then
			if visible then
				self.Suggestions:Accept()
			elseif self.Suggestions:Highlighted() then
				self.Suggestions:Accept()
			end
		elseif code == Enum.KeyCode.Up then
			if visible then
				self.Suggestions:Previous()
			elseif not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				view.Input:Recall(-1)
			end
		elseif code == Enum.KeyCode.Down then
			if visible then
				self.Suggestions:Next()
			elseif not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				view.Input:Recall(1)
			end
		--// Escape backs out one level at a time: the dropdown, then the
		--// expanded terminal, then the console itself
		elseif code == Enum.KeyCode.Escape then
			if visible then
				self.Suggestions:Hide()
			elseif self.Container:Expanded(self.Main) then
				self.Container:Collapse(self.Main)
			else
				self.Container:Hide()
			end
		end
	end)

	return function()
		connection:Disconnect()
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
