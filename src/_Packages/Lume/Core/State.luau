--!strict

--- Reactivity. Two cells — `value` (mutable) and `computed` (derived) — plus
--- `observe`, which is what every setter in the library funnels through.
---
--- Computeds track their dependencies automatically: whatever they read during
--- evaluation becomes a dependency, and they resubscribe on every recompute so
--- branching (`if flag:get() then a:get() else b:get() end`) stays correct.
---
--- Equality is `==`. Setting a table to itself is a no-op, so mutate through
--- `update` and return a fresh table when you want subscribers to hear about it.
--- @section State

local Types = require(script.Parent.Parent.Types)

type Unsubscribe = Types.Unsubscribe

--// locals
--// dependency capture: each frame is the dep set of one in-flight computed
local capturing: { { [any]: boolean } } = {}

--// batching: while depth > 0 notifications queue instead of firing
local depth = 0
local queued: { any } = {}
local queuedSet: { [any]: boolean } = {}

local State = {}

local Value = {}
Value.__index = Value

local Computed = {}
Computed.__index = Computed

export type ValueFields<T> = {
	kind: "value",
	current: T,
	listeners: { (T) -> () },
	dead: boolean,
}

export type ComputedFields<T> = {
	kind: "computed",
	current: T,
	compute: () -> T,
	listeners: { (T) -> () },
	links: { Unsubscribe },
	dead: boolean,
}

local function track(cell: any)
	local frame = capturing[#capturing]

	if frame then
		frame[cell] = true
	end
end

local function publish(cell: any)
	local snapshot = table.clone(cell.listeners)

	for _, listener in snapshot do
		local ok, err = pcall(listener, cell.current)

		if not ok then
			warn(`[Lume] state listener errored: {err}`)
		end
	end
end

local function notify(cell: any)
	if depth > 0 then
		if not queuedSet[cell] then
			queuedSet[cell] = true
			table.insert(queued, cell)
		end

		return
	end

	publish(cell)
end

local function subscribe(cell: any, listener: (any) -> ()): Unsubscribe
	table.insert(cell.listeners, listener)

	local live = true

	return function()
		if not live then
			return
		end

		live = false

		local index = table.find(cell.listeners, listener)

		if index then
			table.remove(cell.listeners, index)
		end
	end
end

--// value
--- Creates a mutable cell.
function State.value<T>(initial: T): Types.Value<T>
	local self: ValueFields<T> = {
		kind = "value",
		current = initial,
		listeners = {},
		dead = false,
	}

	return setmetatable(self, Value) :: any
end

function Value.get<T>(self: ValueFields<T> & Types.Value<T>): T
	track(self)

	return self.current
end

function Value.set<T>(self: ValueFields<T> & Types.Value<T>, next: T)
	if self.dead or self.current == next then
		return
	end

	self.current = next

	notify(self)
end

function Value.update<T>(self: ValueFields<T> & Types.Value<T>, transform: (T) -> T)
	Value.set(self, transform(self.current))
end

function Value.subscribe<T>(self: ValueFields<T> & Types.Value<T>, listener: (T) -> ()): Unsubscribe
	return subscribe(self, listener)
end

function Value.destroy<T>(self: ValueFields<T> & Types.Value<T>)
	self.dead = true

	table.clear(self.listeners)
end

--// computed
local function evaluate<T>(self: ComputedFields<T> & Types.Computed<T>, initial: boolean)
	for _, unlink in self.links do
		unlink()
	end

	table.clear(self.links)

	local frame: { [any]: boolean } = {}

	table.insert(capturing, frame)

	local ok, result = pcall(self.compute)

	table.remove(capturing)

	if not ok then
		warn(`[Lume] computed errored: {result}`)
		return
	end

	for dependency in frame do
		table.insert(
			self.links,
			subscribe(dependency, function()
				evaluate(self, false)
			end)
		)
	end

	local changed = self.current ~= result

	self.current = result :: any

	if changed and not initial then
		notify(self)
	end
end

--- Creates a derived cell from a function of other cells.
function State.computed<T>(compute: () -> T): Types.Computed<T>
	local self: ComputedFields<T> = {
		kind = "computed",
		current = nil :: any,
		compute = compute,
		listeners = {},
		links = {},
		dead = false,
	}

	local public = setmetatable(self, Computed) :: any

	evaluate(public, true)

	return public
end

function Computed.get<T>(self: ComputedFields<T> & Types.Computed<T>): T
	track(self)

	return self.current
end

function Computed.subscribe<T>(self: ComputedFields<T> & Types.Computed<T>, listener: (T) -> ()): Unsubscribe
	return subscribe(self, listener)
end

function Computed.destroy<T>(self: ComputedFields<T> & Types.Computed<T>)
	self.dead = true

	for _, unlink in self.links do
		unlink()
	end

	table.clear(self.links)
	table.clear(self.listeners)
end

--// public api
--- Whether a value is a reactive source rather than a plain value.
function State.is(candidate: any): boolean
	if type(candidate) ~= "table" then
		return false
	end

	local kind = rawget(candidate, "kind")

	return kind == "value" or kind == "computed"
end

--- Reads through a source, or returns a plain value unchanged.
function State.unwrap<T>(candidate: Types.Bindable<T>): T
	if State.is(candidate) then
		return (candidate :: any):get()
	end

	return candidate :: T
end

--- Calls `listener` with the current value now and on every change. Returns an
--- unsubscribe function; for a plain value it fires once and unsubscribing is
--- a no-op. This is the single seam every bindable setter goes through.
function State.observe<T>(candidate: Types.Bindable<T>, listener: (T) -> ()): Unsubscribe
	if not State.is(candidate) then
		listener(candidate :: T)

		return function() end
	end

	local source = candidate :: any

	listener(source:get())

	return source:subscribe(listener)
end

--- Groups writes so subscribers see one notification per changed cell at the
--- end, instead of one per `set`.
function State.batch(body: () -> ())
	depth += 1

	local ok, err = pcall(body)

	depth -= 1

	if depth == 0 then
		local flushing = table.clone(queued)

		table.clear(queued)
		table.clear(queuedSet)

		for _, cell in flushing do
			publish(cell)
		end
	end

	if not ok then
		error(err, 0)
	end
end

--- Sugar for a computed that formats one source into a string.
function State.format<T>(source: Types.Bindable<T>, template: string): Types.Computed<string>
	return State.computed(function()
		return string.format(template, State.unwrap(source) :: any)
	end)
end

--- Sugar for a computed that picks between two values on a boolean source.
function State.pick<T>(condition: Types.Bindable<boolean>, whenTrue: T, whenFalse: T): Types.Computed<T>
	return State.computed(function()
		return if State.unwrap(condition) then whenTrue else whenFalse
	end)
end

return State
