--!strict

--- Empty space. A fixed amount, or flexible so it eats whatever the panel has
--- left over — which is how you push one element to the far end of a row.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Element = require(script.Parent.Element)

local Spacer = {}
Spacer.__index = Spacer

export type Fields = Types.NodeFields & Types.ElementFields & {
	amount: number,
}

--- Creates a spacer. Prefer `panel:spacer(size)`.
function Spacer.new(app: Types.App): Types.Spacer
	local scope = app.scope:child()

	local root = Create.node(scope, {
		class = "Frame",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, app.theme.space.sm),
			Name = "Spacer",
		},
	}) :: Frame

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root,
		refs = { root = root },
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "spacer",
		desired = Vector2.new(0, app.theme.space.sm),
		margin = 0,
		fill = false,
		grow = false,
		enabled = true,
		measured = false,

		amount = app.theme.space.sm,
	}

	return setmetatable(fields, Spacer) :: any
end

function Spacer.setAmount(self: Fields & Types.Spacer, amount: number): Types.Spacer
	self.amount = amount

	return self:invalidate()
end

--- A flexible spacer measures as nothing and grows into everything left over.
function Spacer.setFlexible(self: Fields & Types.Spacer, flexible: boolean): Types.Spacer
	self.grow = flexible ~= false

	return self:invalidate()
end

function Spacer.measure(self: Fields & Types.Spacer, _available: Vector2): Vector2
	local size = if self.grow then 0 else self.amount

	self.desired = Vector2.new(size, size)
	self.measured = true

	return self.desired
end

Element.install(Spacer)

return Spacer
