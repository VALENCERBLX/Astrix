--!strict

--- The element mixin: what every child of a panel answers to on top of the
--- shared node methods.
---
--- The contract is two calls. `measure(available)` reports the size the element
--- wants given the room on offer and must not mutate anything. `commit(inner,
--- vertical, share)` then applies the size the panel decided on — which is the
--- earliest moment a `fill` element can know how wide it is allowed to be.
---
--- Splitting them is what lets one pass handle both "size the panel to its
--- content" and "stretch the content across the panel".
---
--- **`fill` belongs to commit, never to measure.** An element that reported the
--- full available width as its *desired* width would drag every auto-sized
--- panel straight to its maximum, and a command bar that is always 900px wide
--- is not content-driven, it is just wide. Measure reports what the element
--- naturally wants; commit stretches it afterwards.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Node = require(script.Parent.Parent.Core.Node)
local State = require(script.Parent.Parent.Core.State)
local Hover = require(script.Parent.Parent.Input.Hover)

type ElementFields = Types.ElementFields
type NodeFields = Types.NodeFields
type Base = NodeFields & ElementFields

local Element = {}

--// public api
--- Fills in the shared element fields.
function Element.init(self: Base, kind: string, desired: Vector2)
	self.kind = kind
	self.desired = desired

	self.margin = 0
	self.fill = false
	self.grow = false
	self.enabled = true
	self.measured = false
end

--- Walks up to the nearest owning panel, if there is one.
function Element.owner(self: Base): Types.Panel?
	return self.owner
end

--- Installs the element methods onto a class table, then the node methods.
--- Anything the class already defines wins.
function Element.install(class: { [string]: any })
	--- Default measurement: whatever the element last computed for itself.
	--- Every real element overrides this.
	if not class.measure then
		function class.measure(self: Base, _available: Vector2): Vector2
			return self.desired
		end
	end

	--- Default commit: stretch across the cross axis when filling, otherwise
	--- take exactly the measured size. `share` is this element's cut of any
	--- leftover main-axis space.
	if not class.commit then
		function class.commit(self: Base, inner: Vector2, vertical: boolean, share: number)
			local width = self.desired.X
			local height = self.desired.Y

			if vertical then
				if self.fill then
					width = math.max(0, inner.X - self.margin * 2)
				end

				if self.grow then
					height += share
				end
			else
				if self.fill then
					height = math.max(0, inner.Y - self.margin * 2)
				end

				if self.grow then
					width += share
				end
			end

			self.instance.Size = UDim2.fromOffset(math.floor(width + 0.5), math.floor(height + 0.5))
		end
	end

	--- Marks the measurement stale and asks the owning panel for a new pass.
	--- Coalesced by the panel, so calling it from a text change handler on
	--- every keystroke costs one layout per frame.
	if not class.invalidate then
		function class.invalidate<T>(self: T & Base): T
			self.measured = false

			local owner = self.owner

			if owner then
				owner:refresh()
			end

			return self
		end
	end

	--- Re-measure. Panels, groups and scrolls override this with a real layout
	--- pass; for a leaf element it simply bubbles the request upward.
	---
	--- Every element answers it because any element can end up hosting
	--- children — a suggestion list owns a list, a select owns a popover — and
	--- `invalidate` calls `owner:refresh()` without asking what the owner is.
	if not class.refresh then
		function class.refresh<T>(self: T & Base): T
			return class.invalidate(self)
		end
	end

	--- Stretch across the panel's cross axis.
	if not class.setFill then
		function class.setFill<T>(self: T & Base, fill: boolean): T
			self.fill = fill ~= false

			return class.invalidate(self)
		end
	end

	--- Absorb leftover space along the panel's main axis.
	if not class.setGrow then
		function class.setGrow<T>(self: T & Base, grow: boolean): T
			self.grow = grow ~= false

			return class.invalidate(self)
		end
	end

	if not class.setMargin then
		function class.setMargin<T>(self: T & Base, margin: number): T
			self.margin = margin

			return class.invalidate(self)
		end
	end

	if not class.setOrder then
		function class.setOrder<T>(self: T & Base, order: number): T
			self.instance.LayoutOrder = order

			return self
		end
	end

	--- Greys the element out and stops it responding to input.
	if not class.setEnabled then
		function class.setEnabled<T>(self: T & Base, enabled: Types.Bindable<boolean>): T
			Node.bind(self, "enabled", enabled, function(next: boolean)
				self.enabled = next ~= false

				local theme = self.app.theme
				local target = if self.enabled then 0 else theme.transparency.disabled

				--// a CanvasGroup would be cleaner but costs a render target per
				--// element; fading the root's children keeps it to one property
				local root = self.instance

				if root:IsA("CanvasGroup") then
					root.GroupTransparency = target
				end

				if root:IsA("GuiButton") then
					root.Active = self.enabled
					root.Selectable = self.enabled
					root.AutoButtonColor = false
				end

				for _, child in root:GetDescendants() do
					if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
						child.TextTransparency = math.max(child.TextTransparency, target)
					elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
						child.ImageTransparency = math.max(child.ImageTransparency, target)
					end
				end
			end)

			return self
		end
	end

	--- Shows a tooltip panel while the pointer rests on this element.
	if not class.setTooltip then
		function class.setTooltip<T>(self: T & Base, text: Types.Bindable<string>): T
			local Panel = require(script.Parent.Parent.Panel)

			local tip: Types.Panel? = nil

			Hover.attach(self.scope, self.instance, function(hovering)
				if not hovering then
					if tip then
						tip:close()
					end

					return
				end

				if not tip then
					tip = Panel.new(self.app, "tooltip")

					local created = tip :: Types.Panel

					created:label(text):setMuted(false)
					created:attachTo(self.instance, "top", self.app.theme.space.xs)

					self.scope:add(created)
				end

				local created = tip :: Types.Panel

				created:attachTo(self.instance, "top", self.app.theme.space.xs)
				created:open()
			end)

			return self
		end
	end

	--- The panel hosting this element.
	if not class.host then
		function class.host(self: Base): Types.Panel?
			return self.owner
		end
	end

	Node.install(class)
end

--- Reads a bindable through to its current value. Re-exported so elements do
--- not each have to reach for State.
function Element.unwrap<T>(value: Types.Bindable<T>): T
	return State.unwrap(value)
end

return Element
