--!strict

--- Hover and press state, wired the boring way so it is right on every device.
---
--- Two details this handles that hand-rolled `MouseEnter` wiring usually does
--- not: a pointer that leaves by way of the element being hidden or destroyed
--- still reports "not hovering", and touch reports a press without ever
--- reporting a hover.
--- @section Input

local Types = require(script.Parent.Parent.Types)

type Scope = Types.Scope

local Hover = {}

--- Reports hover changes for a GuiObject. Returns a reader for the current
--- state.
function Hover.attach(scope: Scope, instance: GuiObject, onChange: (boolean) -> ()): () -> boolean
	local hovering = false

	local function report(next: boolean)
		if hovering == next then
			return
		end

		hovering = next

		onChange(next)
	end

	scope:add(instance.MouseEnter:Connect(function()
		report(true)
	end))

	scope:add(instance.MouseLeave:Connect(function()
		report(false)
	end))

	--// an element hidden mid-hover never fires MouseLeave
	scope:add(instance:GetPropertyChangedSignal("Visible"):Connect(function()
		if not instance.Visible then
			report(false)
		end
	end))

	scope:add(function()
		report(false)
	end)

	return function()
		return hovering
	end
end

--- Reports press changes for a GuiObject, on mouse and touch alike.
function Hover.press(scope: Scope, instance: GuiObject, onChange: (boolean) -> ()): () -> boolean
	local pressed = false

	local function report(next: boolean)
		if pressed == next then
			return
		end

		pressed = next

		onChange(next)
	end

	scope:add(instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			report(true)
		end
	end))

	scope:add(instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			report(false)
		end
	end))

	scope:add(instance.MouseLeave:Connect(function()
		report(false)
	end))

	scope:add(function()
		report(false)
	end)

	return function()
		return pressed
	end
end

return Hover
