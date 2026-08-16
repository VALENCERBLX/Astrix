--!strict

--- Lifecycle ownership. Everything Lume creates — instances, connections,
--- subscriptions, child scopes — is handed to a scope, and destroying that
--- scope unwinds all of it in reverse creation order.
---
--- Reverse order matters: a connection registered after the instance it fires
--- on must be dropped before that instance is destroyed, or the handler can
--- run against a parented-to-nil tree during teardown.
--- @section Core

local Types = require(script.Parent.Parent.Types)

type Cleanup = Types.Cleanup

export type Fields = {
	items: { Cleanup },
	kids: { Types.Scope },
	living: boolean,
}

local Scope = {}
Scope.__index = Scope

local function dispose(item: Cleanup)
	if type(item) == "function" then
		item()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif type(item) == "table" and type(item.destroy) == "function" then
		item.destroy(item)
	end
end

--- Creates an empty scope.
function Scope.new(): Types.Scope
	local self: Fields = {
		items = {},
		kids = {},
		living = true,
	}

	return setmetatable(self, Scope) :: any
end

--- Registers something for teardown. Returns the item, so it composes:
--- `local part = scope:add(Instance.new("Frame"))`.
function Scope.add(self: Fields & Types.Scope, item: Cleanup): Cleanup
	if not self.living then
		--// a scope that has already unwound owns nothing; dispose immediately
		--// rather than leaking the item into a dead list
		dispose(item)
		return item
	end

	table.insert(self.items, item)

	return item
end

--- Creates a nested scope destroyed with its parent. Every panel and element
--- takes one of these, which is why destroying a panel takes its whole subtree.
function Scope.child(self: Fields & Types.Scope): Types.Scope
	local kid = Scope.new()

	if not self.living then
		kid:destroy()
		return kid
	end

	table.insert(self.kids, kid)

	return kid
end

--- Whether this scope has not yet been destroyed.
function Scope.alive(self: Fields & Types.Scope): boolean
	return self.living
end

--- Unwinds children first, then own items in reverse order. Idempotent.
function Scope.destroy(self: Fields & Types.Scope)
	if not self.living then
		return
	end

	self.living = false

	for index = #self.kids, 1, -1 do
		self.kids[index]:destroy()
	end

	for index = #self.items, 1, -1 do
		local ok, err = pcall(dispose, self.items[index])

		if not ok then
			warn(`[Lume] cleanup failed: {err}`)
		end
	end

	table.clear(self.items)
	table.clear(self.kids)
end

return Scope
