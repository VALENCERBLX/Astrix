--!strict

--- **Lume** — a panel-and-element UI standard for Roblox.
---
--- Two primitives. A **Panel** is every surface: window, command bar, dropdown,
--- tooltip, modal, toast. An **Element** is everything a surface hosts. Panels
--- size themselves from their elements, grow away from whatever edge they are
--- anchored to, and morph as their content changes.
---
--- Every setter returns the receiver, and every setter takes a plain value or a
--- reactive one:
---
--- ```lua
--- local Lume = require(path.to.Lume)
---
--- local app = Lume.app({ name = "Inspector" })
--- local count = Lume.value(0)
---
--- local panel = app:panel("window")
---     :setTitle("Inspector")
---     :setAnchor("bottomRight")
---     :setWidth(320)
---
--- panel:label(Lume.format(count, "%d selected"))
---     :setMuted(true)
---
--- panel:field("Search")
---     :onSubmitted(print)
---
--- panel:button("Refresh")
---     :onClicked(function()
---         count:update(function(n) return n + 1 end)
---     end)
---
--- panel:open()
--- ```
--- @section Overview

local App = require(script.App)
local Types = require(script.Types)

local Elements = require(script.Elements)
local Panel = require(script.Panel)
local Presets = require(script.Panel.Presets)

local Autosize = require(script.Layout.Autosize)
local Measure = require(script.Layout.Measure)
local Placement = require(script.Layout.Placement)
local Stack = require(script.Layout.Stack)
local Virtual = require(script.Layout.Virtual)

local Create = require(script.Core.Create)
local Node = require(script.Core.Node)
local Scope = require(script.Core.Scope)
local Signal = require(script.Core.Signal)
local State = require(script.Core.State)

local Drag = require(script.Input.Drag)
local Focus = require(script.Input.Focus)
local Hover = require(script.Input.Hover)
local Keys = require(script.Input.Keys)

local Motion = require(script.Motion)
local Easing = require(script.Motion.Easing)
local Spring = require(script.Motion.Spring)

local Theme = require(script.Theme)
local Tokens = require(script.Theme.Tokens)
local Text = require(script.Text)

--// types
export type App = Types.App
export type Panel = Types.Panel
export type Element = Types.Element
export type Theme = Types.Theme
export type Scope = Types.Scope
export type Signal = Types.Signal
export type Stack = Types.Stack
export type Animation = Types.Animation
export type MotionSpec = Types.MotionSpec

export type Value<T> = Types.Value<T>
export type Computed<T> = Types.Computed<T>
export type Bindable<T> = Types.Bindable<T>

export type Anchor = Types.Anchor
export type Axis = Types.Axis
export type Edge = Types.Edge
export type Preset = Types.Preset

export type Option = Types.Option
export type ListItem = Types.ListItem
export type MenuItem = Types.MenuItem
export type MenuGroup = Types.MenuGroup
export type Tab = Types.Tab

export type Label = Types.Label
export type Icon = Types.Icon
export type Button = Types.Button
export type Field = Types.Field
export type Toggle = Types.Toggle
export type Slider = Types.Slider
export type Stepper = Types.Stepper
export type Select = Types.Select
export type List = Types.List
export type Divider = Types.Divider
export type Spacer = Types.Spacer
export type Group = Types.Group
export type Progress = Types.Progress
export type Tabs = Types.Tabs
export type Chips = Types.Chips
export type Suggest = Types.Suggest
export type ColorPicker = Types.ColorPicker
export type Menu = Types.Menu
export type MenuBar = Types.MenuBar
export type Badge = Types.Badge
export type Scroll = Types.Scroll
export type Keybind = Types.Keybind

--// public api
local Lume = {
	version = "0.1.0",

	--// entry point
	app = App.new,

	--// reactivity
	value = State.value,
	computed = State.computed,
	observe = State.observe,
	batch = State.batch,
	format = State.format,
	pick = State.pick,
	unwrap = State.unwrap,
	isSource = State.is,

	--// primitives, for building outside an app's factories
	Panel = Panel,
	Elements = Elements,
	Presets = Presets,

	--// systems
	App = App,
	State = State,
	Theme = Theme,
	Tokens = Tokens,
	Motion = Motion,
	Text = Text,

	Layout = {
		Autosize = Autosize,
		Measure = Measure,
		Placement = Placement,
		Stack = Stack,
		Virtual = Virtual,
	},

	Core = {
		Create = Create,
		Node = Node,
		Scope = Scope,
		Signal = Signal,
		State = State,
	},

	Input = {
		Drag = Drag,
		Focus = Focus,
		Hover = Hover,
		Keys = Keys,
	},

	Easing = Easing,
	Spring = Spring,

	--// escape hatches
	scope = Scope.new,
	signal = Signal.new,
	create = Create.node,
	tree = Create.tree,
	theme = Theme.new,
}

return table.freeze(Lume)
