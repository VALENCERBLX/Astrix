--!strict

--- The base every Panel and Element shares: a root instance, a scope, a bag of
--- refs, a bag of property bindings, and a bag of event signals.
---
--- It is installed as a mixin rather than inherited through a metatable chain.
--- Copying the methods onto each class costs one loop at load and saves a
--- pointer chase on every call, and it keeps each class's method table honest
--- about what it actually answers to.
---
--- Every setter here returns the receiver, which is what makes the whole
--- library chainable.
--- @section Core

local Types = require(script.Parent.Parent.Types)
local Motion = require(script.Parent.Parent.Motion)
local Signal = require(script.Parent.Parent.Core.Signal)
local State = require(script.Parent.State)

type NodeFields = Types.NodeFields
type Bindable<T> = Types.Bindable<T>

local Node = {}

--// public api
--- Fills in the shared fields on a freshly constructed node.
function Node.init(self: NodeFields, app: Types.App, instance: GuiObject, scope: Types.Scope)
	self.app = app
	self.instance = instance
	self.scope = scope

	self.refs = {}
	self.bindings = {}
	self.events = {}

	self.owner = nil
	self.dead = false
end

--- Binds a property key to a plain value or a reactive source, replacing any
--- previous binding on that key. `apply` receives the resolved value.
---
--- Rebinding is the normal case — `setText` called twice should not leave the
--- first subscription running — so the old one is disposed first.
function Node.bind<T>(self: NodeFields, key: string, value: Bindable<T>, apply: (T) -> ())
	local existing = self.bindings[key]

	if existing then
		existing()

		self.bindings[key] = nil
	end

	if self.dead then
		return
	end

	self.bindings[key] = State.observe(value, apply)
end

--- Drops a binding without setting a new one.
function Node.unbind(self: NodeFields, key: string)
	local existing = self.bindings[key]

	if existing then
		existing()

		self.bindings[key] = nil
	end
end

--- Gets or creates the signal for a named event.
function Node.signal(self: NodeFields, event: string): Types.Signal
	local existing = self.events[event]

	if existing then
		return existing
	end

	local created = Signal.new()

	self.events[event] = created

	self.scope:add(created)

	return created
end

--- The shared teardown: fire `destroyed`, drop every binding, stop every
--- animation, unwind the scope. Classes with their own `destroy` (a panel has
--- children to take with it) call this at the end rather than repeating it.
function Node.teardown(self: NodeFields)
	if self.dead then
		return
	end

	self.dead = true

	local signal = self.events.destroyed

	if signal then
		signal:fire()
	end

	for _, unbind in self.bindings do
		unbind()
	end

	table.clear(self.bindings)

	Motion.stop(self.instance)

	self.scope:destroy()

	table.clear(self.refs)
	table.clear(self.events)
end

--- Installs the shared chained methods onto a class table. Methods the class
--- already defines are left alone, so a class can override any of them.
function Node.install(class: { [string]: any })
	--// identity and visibility
	if not class.setName then
		function class.setName<T>(self: T & NodeFields, name: string): T
			self.instance.Name = name

			return self
		end
	end

	if not class.setVisible then
		function class.setVisible<T>(self: T & NodeFields, visible: Bindable<boolean>): T
			Node.bind(self, "Visible", visible, function(next: boolean)
				self.instance.Visible = next

				local owner = self.owner

				if owner then
					owner:refresh()
				end
			end)

			return self
		end
	end

	--// geometry
	if not class.setSize then
		function class.setSize<T>(self: T & NodeFields, size: Bindable<UDim2>): T
			Node.bind(self, "Size", size, function(next: UDim2)
				self.instance.Size = next
			end)

			return self
		end
	end

	if not class.setPosition then
		function class.setPosition<T>(self: T & NodeFields, position: Bindable<UDim2>): T
			Node.bind(self, "Position", position, function(next: UDim2)
				self.instance.Position = next
			end)

			return self
		end
	end

	if not class.setAnchorPoint then
		function class.setAnchorPoint<T>(self: T & NodeFields, anchor: Bindable<Vector2>): T
			Node.bind(self, "AnchorPoint", anchor, function(next: Vector2)
				self.instance.AnchorPoint = next
			end)

			return self
		end
	end

	if not class.setZIndex then
		function class.setZIndex<T>(self: T & NodeFields, index: Bindable<number>): T
			Node.bind(self, "ZIndex", index, function(next: number)
				self.instance.ZIndex = next
			end)

			return self
		end
	end

	if not class.setLayoutOrder then
		function class.setLayoutOrder<T>(self: T & NodeFields, order: Bindable<number>): T
			Node.bind(self, "LayoutOrder", order, function(next: number)
				self.instance.LayoutOrder = next
			end)

			return self
		end
	end

	--- Escape hatch: assign raw Roblox properties on the root instance.
	if not class.setProps then
		function class.setProps<T>(self: T & NodeFields, props: { [string]: any }): T
			for key, value in props do
				Node.bind(self, `raw:{key}`, value, function(next: any)
					local ok, err = pcall(function()
						(self.instance :: any)[key] = next
					end)

					if not ok then
						warn(`[Lume] could not set {self.instance.ClassName}.{key}: {err}`)
					end
				end)
			end

			return self
		end
	end

	--// events
	if not class.on then
		function class.on<T>(self: T & NodeFields, event: string, handler: (...any) -> ()): T
			self.scope:add(Node.signal(self, event):connect(handler))

			return self
		end
	end

	if not class.once then
		function class.once<T>(self: T & NodeFields, event: string, handler: (...any) -> ()): T
			self.scope:add(Node.signal(self, event):once(handler))

			return self
		end
	end

	if not class.emit then
		function class.emit<T>(self: T & NodeFields, event: string, ...: any): T
			local signal = self.events[event]

			if signal then
				signal:fire(...)
			end

			return self
		end
	end

	--// motion
	if not class.animate then
		function class.animate(
			self: NodeFields,
			props: { [string]: any },
			spec: (Types.MotionSpec | string)?
		): Types.Animation
			return Motion.animate(self.instance, props, self.app.theme:spec(spec))
		end
	end

	--// access and teardown
	if not class.get then
		function class.get(self: NodeFields): GuiObject
			return self.instance
		end
	end

	if not class.alive then
		function class.alive(self: NodeFields): boolean
			return not self.dead
		end
	end

	if not class.destroy then
		function class.destroy(self: NodeFields)
			Node.teardown(self)
		end
	end
end

return Node
