--!strict

--- Every element, by name. Panels and groups look factories up here, and you
--- can too when you want to build an element without a panel to hang it on:
---
--- ```lua
--- local button = Lume.Elements.Button.new(app)
--- panel:add(button)
--- ```
--- @section Elements

return {
	Element = require(script.Element),

	Label = require(script.Label),
	Icon = require(script.Icon),
	Button = require(script.Button),
	Field = require(script.Field),
	Toggle = require(script.Toggle),
	Slider = require(script.Slider),
	Stepper = require(script.Stepper),
	Select = require(script.Select),
	List = require(script.List),
	Divider = require(script.Divider),
	Spacer = require(script.Spacer),
	Group = require(script.Group),
	Accordion = require(script.Accordion),
	Progress = require(script.Progress),
	Tabs = require(script.Tabs),
	Chips = require(script.Chips),
	Suggest = require(script.Suggest),
	Menu = require(script.Menu),
	ColorPicker = require(script.ColorPicker),
	MenuBar = require(script.MenuBar),
	Badge = require(script.Badge),
	Scroll = require(script.Scroll),
	Keybind = require(script.Keybind),

	Radio = require(script.Radio),
	Rating = require(script.Rating),
	Meter = require(script.Meter),
	Spinner = require(script.Spinner),
	Table = require(script.Table),
	Tree = require(script.Tree),
	Avatar = require(script.Avatar),
	Breadcrumb = require(script.Breadcrumb),
	Pagination = require(script.Pagination),
	Scrubber = require(script.Scrubber),
	Vector = require(script.Vector),
	Sparkline = require(script.Sparkline),
	Graph = require(script.Graph),
}
