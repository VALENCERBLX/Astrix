--!strict

--- An app is the one piece of shared state: its host gui, its theme, its root
--- scope, its measurement cache, its focus ring and its key binder.
---
--- Layers are full-screen frames ordered by ZIndex, so a dropdown opened from
--- a panel can never be clipped by the panel that spawned it. Ask for one by
--- name and it is created on demand.
--- @section App

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.Types)

local Measure = require(script.Parent.Layout.Measure)
local Stack = require(script.Parent.Layout.Stack)

local Focus = require(script.Parent.Input.Focus)
local Keys = require(script.Parent.Input.Keys)

local Signal = require(script.Parent.Core.Signal)
local Scope = require(script.Parent.Core.Scope)
local Theme = require(script.Parent.Theme)

local App = {}
App.__index = App

export type Options = {
	name: string?,
	gui: LayerCollector?,
	parent: Instance?,
	theme: { [string]: any }?,
	displayOrder: number?,
	ignoreGuiInset: boolean?,
	resetOnSpawn: boolean?,
}

--// locals
--// named layers, lowest first. Anything not listed lands on the default layer.
--- Layer order. A popover sits above the modal and the toast layers on
--- purpose: a dropdown opened *from* a modal, or from inside a notice, has to
--- be readable, and it was not — at 100 it rendered behind both, so a select in
--- a toast opened into nothing.
---
--- Only a tooltip goes higher, because a tooltip can be attached to something
--- in a popover.
local LAYERS: { [string]: number } = {
	background = -10,
	default = 1,
	raised = 10,
	modal = 500,
	toast = 800,
	popover = 900,
	tooltip = 1000,
}

local function hostGui(options: Options, scope: Types.Scope): LayerCollector
	if options.gui then
		return options.gui
	end

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	local gui = Instance.new("ScreenGui")

	gui.Name = options.name or "Lume"
	gui.IgnoreGuiInset = options.ignoreGuiInset ~= false
	gui.ResetOnSpawn = options.resetOnSpawn == true
	gui.DisplayOrder = options.displayOrder or 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = options.parent or playerGui or Workspace

	scope:add(gui)

	return gui
end

--// public api
--- Creates an app. Everything else in Lume hangs off one of these.
function App.new(options: Options?): Types.App
	local settings = options or {}
	local scope = Scope.new()

	local self = {
		gui = nil :: any,
		theme = Theme.new(settings.theme),
		scope = scope,
		measure = Measure.new(),

		layers = {},
		panels = {},

		focus = nil :: any,
		keys = nil :: any,

		resized = Signal.new(),
		themed = Signal.new(),
	}

	local app = setmetatable(self, App) :: any

	app.gui = hostGui(settings, scope)

	app.focus = Focus.new(app)
	app.keys = Keys.new(app)

	scope:add(app.resized)
	scope:add(app.themed)

	local camera = Workspace.CurrentCamera

	if camera then
		scope:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			app.resized:fire(camera.ViewportSize)

			--// every panel re-clamps against the new viewport; a panel that was
			--// at its height ceiling on a tall screen has to give room back on
			--// a short one
			for _, panel in app.panels do
				panel:refresh()
			end
		end))
	end

	return app
end

--- The usable viewport size, in pixels.
function App.viewport(self: Types.App): Vector2
	local camera = Workspace.CurrentCamera

	if camera and camera.ViewportSize.Y > 1 then
		return camera.ViewportSize
	end

	local size = self.gui.AbsoluteSize

	return if size.Y > 1 then size else Vector2.new(1920, 1080)
end

--- Gets or creates a named layer. Unknown names get the default z-order.
function App.surface(self: Types.App, layer: string): Frame
	local existing = self.layers[layer]

	if existing then
		return existing
	end

	local frame = Instance.new("Frame")

	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = LAYERS[layer] or LAYERS.default
	frame.Name = `Layer_{layer}`
	frame.Parent = self.gui

	self.layers[layer] = frame
	self.scope:add(frame)

	return frame
end

--- Deep-merges token overrides, flushes the measurement cache, and refreshes
--- every panel. Sizes are text-derived, so a font change is a layout change.
function App.restyle(self: Types.App, overrides: { [string]: any }): Types.Theme
	self.theme = self.theme:extend(overrides)

	self.measure:flush()
	self.themed:fire(self.theme)

	for _, panel in self.panels do
		panel:refresh()
	end

	return self.theme
end

--- Creates a panel on this app.
function App.panel(self: Types.App, preset: Types.Preset?): Types.Panel
	local Panel = require(script.Parent.Panel)

	return Panel.new(self, preset)
end

--- Creates a stack for laying panels out in sequence.
function App.stack(self: Types.App, anchor: Types.Anchor?): Types.Stack
	return Stack.new(self, anchor)
end

--- Binds a key or chord at the app level.
function App.bind(self: Types.App, keys: { Enum.KeyCode } | Enum.KeyCode, handler: () -> ()): Types.KeyBinding
	return self.keys:bind(keys, handler)
end

--- Drops focus from whatever holds it.
function App.blur(self: Types.App)
	self.focus:clear()
end

--- Tears down every panel, layer, connection and instance this app owns.
function App.destroy(self: Types.App)
	for index = #self.panels, 1, -1 do
		self.panels[index]:destroy()
	end

	table.clear(self.panels)
	table.clear(self.layers)

	self.scope:destroy()
end

return App
