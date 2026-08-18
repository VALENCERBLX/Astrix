--!strict

--- The interface layer: a `Container` of windows, a suggestion dropdown, and
--- the wiring between them and a Kyn session.
---
--- Everything visual is Lume's. This module's job is deciding *what* to show —
--- when to update completions, which window a result belongs to, what the
--- prompt looks like — not how to draw or animate it.
--- @section Console

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
	ActivationKey: Enum.KeyCode?,
	--// when the caret was last captured. The cycling window is measured from
	--// here, not from the last press
	FocusedAt: number,
	CycleTimeout: number,
	Cycling: boolean,
	Step: number,
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
		ActivationKey = nil,
		FocusedAt = 0,
		CycleTimeout = 1.5,
		Cycling = false,
		Step = 1,
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

	--// keyed on the window that fired it, not the one that happened to exist
	--// when the interface was built. Capturing `view` here is why completion
	--// did nothing in any window but the first
	container.OnChange = function(id, text)
		local source = self.Container:Get(id)

		if not source then
			return
		end

		--// a recalled history line is not something the player is typing, so
		--// it neither opens the dropdown nor moves its highlight
		if source.Input.Recalling then
			self.Suggestions:Hide()

			return
		end

		self.Suggestions:Attach(source.Panel, source.Input.Field)

		local box = source.Input.Field.refs.input :: TextBox

		self.Suggestions:Update(text, box.CursorPosition)
	end

	container.OnSubmit = function(id, text)
		self.Suggestions:Hide()

		--// output belongs to the window the line was typed in
		self.Container.Focus = id

		if text ~= "" and self.OnSubmit then
			self.OnSubmit(text)
		end
	end

	table.insert(self.Bindings, Interface.BindKeys(interface))

	return interface
end

--- Binds Tab, the arrows and Escape while the console has the keyboard.
---
--- Back on `InputBegan`, deliberately.
---
--- ContextActionService looked like the right tool — bind high, return Sink,
--- the field never sees the key. It is not: while a TextBox has focus Roblox
--- routes text input below where an action binding reaches, so a CAS action
--- bound to Tab neither sinks it *nor fires at all*. Moving these here made Tab
--- stop doing anything whatsoever.
---
--- An InputBegan listener does fire. It cannot stop the tab being typed, so
--- `Suggestions.Accept` handles that end: focus is dropped before the
--- completion is written and the text re-applied a frame later with tabs
--- stripped.
---
--- The activation key is a different case and stays on CAS — nothing has focus
--- when the console is closed, so sinking works there and keeps the key from
--- leaking into the rest of the game.
function Interface.BindKeys(self: Interface): () -> ()
	local connection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if not self.Container.Shown then
			return
		end

		--// whichever window has the caret right now. Resolving this per press
		--// rather than capturing one view is what makes every window behave
		--// the same
		local view = Interface.FocusedView(self)

		if not view or not view.Input:Focused() then
			return
		end

		local code = input.KeyCode
		local visible = self.Suggestions:Visible()

		if code == Enum.KeyCode.Tab then
			--// accept whether or not the list is showing: the ghost hint after
			--// the caret is the same match, seen a different way
			if visible or self.Suggestions:Highlighted() then
				self.Suggestions:Accept()
			end
		elseif code == Enum.KeyCode.Up then
			if visible then
				self.Suggestions:Previous()
			else
				view.Input:Recall(-1)
			end
		elseif code == Enum.KeyCode.Down then
			if visible then
				self.Suggestions:Next()
			else
				view.Input:Recall(1)
			end
		elseif code == Enum.KeyCode.Escape then
			if visible then
				self.Suggestions:Hide()
			elseif self.Container:Expanded(Interface.Target(self)) then
				self.Container:Collapse(Interface.Target(self))
			else
				self.Container:Hide()
			end
		end
	end)

	return function()
		connection:Disconnect()
	end
end

--- The view that currently has the caret, or the focused one if none does.
function Interface.FocusedView(self: Interface): any
	for _, id in self.Container:List() do
		local view = self.Container:Get(id)

		if view and view.Input:Focused() then
			return view
		end
	end

	return self.Container:Get(Interface.Target(self))
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
--- Pressed on its own it opens the console at the window you were last using
--- and puts the caret in it. Pressed **again inside `CycleTimeout`** it steps
--- one further back through the windows you have used — the second press lands
--- on the one before, the third on the one before that.
---
--- The order walked is recency, not creation, so this behaves the way
--- alt-tab does: the window you want is usually one press away. Recency is
--- only rewritten when a cycle *settles*, because updating it on every step
--- would reorder the list underneath you and the second press would take you
--- straight back where you started.
function Interface.Toggle(self: Interface, forceCycle: boolean?)
	--// measured from when the caret was captured, not from the last press.
	--// A run of presses each re-captures focus, so a chain keeps working;
	--// stop for the timeout and the key goes back to being a character
	local rapid = forceCycle == true or (os.clock() - self.FocusedAt) <= self.CycleTimeout

	self.LastActivate = os.clock()

	if not self.Container.Shown then
		self.Cycling = false

		Interface.Show(self)

		return
	end

	local recency = self.Container:Recency()

	if rapid and #recency > 1 then
		--// a run of presses walks the list; the first of the run starts at the
		--// window after the one in use
		self.Step = if self.Cycling then self.Step + 1 else 2
		self.Cycling = true

		local index = ((self.Step - 1) % #recency) + 1

		Interface.FocusWindow(self, recency[index], true)

		return
	end

	self.Cycling = false
	self.Step = 1

	local target = Interface.Target(self)

	if self.Container:Expanded(target) then
		self.Suggestions:Hide()
		self.Container:Collapse(target)
	else
		Interface.FocusWindow(self, target)
	end
end

--- The activation press, however it arrived.
---
--- Whatever field had the caret is snapshotted first and put back a frame
--- later. The key that triggered this is still on its way into that TextBox —
--- Roblox types it regardless of what any binding says — so without this,
--- cycling with `;` leaves a trail of semicolons in whatever you were writing.
function Interface.Activate(self: Interface, forceCycle: boolean?)
	--// snapshot EVERY field, not only the one that currently looks focused.
	--// Focus moves during the cycle, and Roblox delivers the character to
	--// whichever box holds the caret when it processes it — which may be the
	--// one just moved to rather than the one just left
	local snapshot: { [string]: any } = {}

	for _, id in self.Container:List() do
		local view = self.Container:Get(id)

		if view then
			local box = view.Input.Field.refs.input :: TextBox

			snapshot[id] = { Box = box, Text = box.Text }
		end
	end

	Interface.Toggle(self, forceCycle)

	task.defer(function()
		for _, entry in snapshot do
			local box = entry.Box :: TextBox

			if box.Parent and box.Text ~= entry.Text then
				box.Text = entry.Text
			end
		end
	end)
end

--- Watches for the activation key while a console field has focus.
---
--- ContextActionService handles it the rest of the time, sinking it so it
--- cannot leak into the game. But a CAS action does not fire *at all* while a
--- TextBox has focus, which is exactly the state cycling happens in: the first
--- press opens the console and captures the caret, and every press after that
--- was going straight into the field instead of stepping to the next window.
---
--- The two paths cannot double-fire, because each only acts in the state the
--- other is silent in.
function Interface.BindActivation(self: Interface, key: Enum.KeyCode): () -> ()
	self.ActivationKey = key

	local connection = UserInputService.InputBegan:Connect(function(input)
		--// gameProcessed is deliberately ignored: it is always true while
		--// typing, which is when this path is needed
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode ~= self.ActivationKey then
			return
		end

		local view = Interface.FocusedView(self)

		if not view or not view.Input:Focused() then
			--// nothing focused, so ContextActionService is handling it
			return
		end

		local held = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		--// Ctrl always cycles, whenever you ask for it.
		--
		--// The bare key only cycles inside the window that opened when the
		--// caret was captured. After that it is a character again — which
		--// matters because `:` and `;` are the same KeyCode, so a console
		--// bound to `;` would otherwise jump windows every time somebody typed
		--// `::Kout`
		if not held and (os.clock() - self.FocusedAt) > self.CycleTimeout then
			return
		end

		--// Ctrl means "cycle now" regardless of how long ago focus landed
		Interface.Activate(self, held)
	end)

	return function()
		connection:Disconnect()
	end
end

--- How long a run of activation presses counts as one cycle. 1.5s by default.
function Interface.SetCycleTimeout(self: Interface, seconds: number)
	self.CycleTimeout = math.max(0, seconds)
end

--- Focuses a window and re-points the dropdown at its input, so completion
--- happens in the window you are actually typing into.
---
--- `transient` marks a step of a cycle rather than a settled choice, so the
--- recency list is left alone until the run ends.
function Interface.FocusWindow(self: Interface, id: string, transient: boolean?)
	local view = self.Container:Get(id)

	if not view then
		return
	end

	self.Suggestions:Hide()
	self.Suggestions:Attach(view.Panel, view.Input.Field)

	self.FocusedAt = os.clock()

	if transient then
		self.Container.Focus = id

		self.Container:Blur(id)

		view.Panel:front()
		self.Container:Expand(id)

		--// Expand is a no-op on an already-expanded window, so the caret is
		--// moved explicitly; cycling between two open terminals otherwise
		--// leaves it wherever it was
		view.Input:Focus()

		return
	end

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

		--// the same surface as `Astrix.Windows`, so a command body can use
		--// either without discovering they differ
		Focused = function(): string?
			return Interface.Target(self)
		end,
		Focus = function(id: string)
			Interface.FocusWindow(self, id)
		end,
		Recency = function(): { string }
			return container:Recency()
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
