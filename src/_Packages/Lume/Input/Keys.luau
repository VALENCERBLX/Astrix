--!strict

--- Keyboard bindings, single keys or chords.
---
--- A chord fires when its last key goes down while the rest are already held,
--- so `{LeftControl, K}` triggers on K and not on Control. Bindings are skipped
--- while a text field is capturing input unless they opt out.
--- @section Input

local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Types)

local Keys = {}
Keys.__index = Keys

export type Binding = {
	keys: { Enum.KeyCode },
	handler: () -> (),
	whileTyping: boolean,
	live: boolean,
}

export type Fields = {
	app: Types.App,
	bindings: { Binding },
}

export type Keys = typeof(setmetatable({} :: Fields, Keys))

--- Creates the key binder for an app.
function Keys.new(app: Types.App): Keys
	local self: Fields = {
		app = app,
		bindings = {},
	}

	local binder = setmetatable(self, Keys)

	app.scope:add(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local typing = app.focus and app.focus:typing()

		for _, binding in table.clone(self.bindings) do
			if not binding.live then
				continue
			end

			if typing and not binding.whileTyping then
				continue
			end

			--// `processed` is true whenever the engine already consumed the
			--// key, which includes every keystroke typed into a TextBox
			if processed and not binding.whileTyping then
				continue
			end

			local last = binding.keys[#binding.keys]

			if input.KeyCode ~= last then
				continue
			end

			local satisfied = true

			for index = 1, #binding.keys - 1 do
				if not UserInputService:IsKeyDown(binding.keys[index]) then
					satisfied = false
					break
				end
			end

			if satisfied then
				local ok, err = pcall(binding.handler)

				if not ok then
					warn(`[Lume] key handler errored: {err}`)
				end
			end
		end
	end))

	return binder
end

--- Binds a key or chord. The returned binding disconnects itself.
function Keys.bind(
	self: Keys,
	keys: { Enum.KeyCode } | Enum.KeyCode,
	handler: () -> (),
	whileTyping: boolean?
): Types.KeyBinding
	local list: { Enum.KeyCode } = if typeof(keys) == "EnumItem" then { keys :: Enum.KeyCode } else keys :: { Enum.KeyCode }

	local binding: Binding = {
		keys = list,
		handler = handler,
		whileTyping = whileTyping == true,
		live = true,
	}

	table.insert(self.bindings, binding)

	return {
		keys = list,
		handler = handler,
		disconnect = function()
			binding.live = false

			local index = table.find(self.bindings, binding)

			if index then
				table.remove(self.bindings, index)
			end
		end,
	}
end

--- Drops every binding.
function Keys.clear(self: Keys)
	table.clear(self.bindings)
end

return Keys
