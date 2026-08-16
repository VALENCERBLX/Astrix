--!strict

--- A minimal signal. Connecting returns an unsubscribe function rather than a
--- connection object, so handlers drop straight into a scope:
--- `scope:add(panel.opened:connect(fn))`.
---
--- Firing iterates a snapshot, so connecting or disconnecting from inside a
--- handler never skips or double-fires the dispatch in flight.
--- @section Core

local Types = require(script.Parent.Parent.Types)

export type Handler = (...any) -> ()

export type Fields = {
	handlers: { Handler },
	firing: boolean,
}

local Signal = {}
Signal.__index = Signal

--- Creates an empty signal.
function Signal.new(): Types.Signal
	local self: Fields = {
		handlers = {},
		firing = false,
	}

	return setmetatable(self, Signal) :: any
end

--- Connects a handler. The returned function disconnects it.
function Signal.connect(self: Fields & Types.Signal, handler: Handler): Types.Unsubscribe
	table.insert(self.handlers, handler)

	local live = true

	return function()
		if not live then
			return
		end

		live = false

		local index = table.find(self.handlers, handler)

		if index then
			table.remove(self.handlers, index)
		end
	end
end

--- Connects a handler for exactly one fire.
function Signal.once(self: Fields & Types.Signal, handler: Handler): Types.Unsubscribe
	local disconnect: Types.Unsubscribe

	disconnect = Signal.connect(self, function(...)
		disconnect()
		handler(...)
	end)

	return disconnect
end

--- Fires every currently connected handler.
function Signal.fire(self: Fields & Types.Signal, ...: any)
	local snapshot = table.clone(self.handlers)

	self.firing = true

	for _, handler in snapshot do
		local ok, err = pcall(handler, ...)

		if not ok then
			warn(`[Lume] signal handler errored: {err}`)
		end
	end

	self.firing = false
end

--- How many handlers are connected.
function Signal.count(self: Fields & Types.Signal): number
	return #self.handlers
end

--- Drops every handler.
function Signal.destroy(self: Fields & Types.Signal)
	table.clear(self.handlers)
end

return Signal
