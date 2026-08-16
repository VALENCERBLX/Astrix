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

	self.Suggestions:Attach(view.Panel)

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

		if not self.Container.Open then
			return
		end

		local code = input.KeyCode
		local visible = self.Suggestions:Visible()

		if code == Enum.KeyCode.Tab then
			if visible then
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
		elseif code == Enum.KeyCode.Escape then
			if visible then
				self.Suggestions:Hide()
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

function Interface.Write(self: Interface, kind: Types.HistoryKind, text: string, content: Types.ContentElement?)
	self.Container:Write(self.Main, kind, text, content)
end

function Interface.Clear(self: Interface)
	self.Container:Clear(self.Main)
end

function Interface.Show(self: Interface)
	self.Container:Show()
	self.Container:FocusWindow(self.Main)
end

function Interface.Hide(self: Interface)
	self.Suggestions:Hide()
	self.Container:Hide()
end

function Interface.Toggle(self: Interface)
	if self.Container.Open then
		Interface.Hide(self)
	else
		Interface.Show(self)
	end
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
