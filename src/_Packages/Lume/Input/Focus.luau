--!strict

--- The app's focus ring: which element currently owns keyboard input, and
--- whether a text field is capturing keystrokes.
---
--- Key bindings consult `typing()` before firing, so an activation key bound
--- to `F` does not toggle the console every time somebody types the letter F
--- into a search box.
--- @section Input

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)
local Signal = require(script.Parent.Parent.Core.Signal)

local Focus = {}
Focus.__index = Focus

export type Fields = {
	app: Types.App,
	current: any,
	changed: Types.Signal,
	capturing: boolean,
}

export type Focus = typeof(setmetatable({} :: Fields, Focus))

--- Creates the focus ring for an app.
function Focus.new(app: Types.App): Focus
	local self: Fields = {
		app = app,
		current = nil,
		changed = Signal.new(),
		capturing = false,
	}

	local focus = setmetatable(self, Focus)

	app.scope:add(self.changed)

	app.scope:add(UserInputService.TextBoxFocused:Connect(function()
		self.capturing = true
	end))

	app.scope:add(UserInputService.TextBoxFocusReleased:Connect(function()
		self.capturing = false
	end))

	return focus
end

--- Moves focus. Passing nil clears it.
function Focus.set(self: Focus, element: any)
	if self.current == element then
		return
	end

	local previous = self.current

	self.current = element

	self.changed:fire(element, previous)
end

--- Clears focus.
function Focus.clear(self: Focus)
	Focus.set(self, nil)
end

--- The focused element, if any.
function Focus.get(self: Focus): any
	return self.current
end

--- Whether the element owns focus right now.
function Focus.owns(self: Focus, element: any): boolean
	return self.current == element
end

--- Whether a text field is currently capturing keystrokes.
function Focus.typing(self: Focus): boolean
	return self.capturing
end

return Focus
