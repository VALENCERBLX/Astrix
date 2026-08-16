--!strict

--- Instance construction. A descriptor is a plain table, so a component body
--- reads as the tree it builds, and every reactive prop or event registered
--- along the way is owned by the scope that built it.
--- @section Core

local Types = require(script.Parent.Parent.Types)
local State = require(script.Parent.State)

type Descriptor = Types.Descriptor
type Scope = Types.Scope
type Refs = Types.Refs

local Create = {}

--// locals
local function assign(instance: Instance, key: string, value: any)
	local ok, err = pcall(function()
		(instance :: any)[key] = value
	end)

	if not ok then
		warn(`[Lume] could not set {instance.ClassName}.{key}: {err}`)
	end
end

--- Applies a prop table to an instance, subscribing any reactive entries.
function Create.apply(scope: Scope, instance: Instance, props: { [string]: any }?)
	for key, value in props or {} do
		if State.is(value) then
			scope:add(State.observe(value, function(next)
				assign(instance, key, next)
			end))
		else
			assign(instance, key, value)
		end
	end
end

--- Connects an event table (`{ Activated = fn }`) to an instance.
function Create.connect(scope: Scope, instance: Instance, events: { [string]: (...any) -> () }?)
	for key, handler in events or {} do
		local event = (instance :: any)[key]

		if typeof(event) == "RBXScriptSignal" then
			scope:add(event:Connect(handler))
		else
			warn(`[Lume] {instance.ClassName} has no event {key}`)
		end
	end
end

--- Builds one descriptor and its children.
function Create.node(scope: Scope, descriptor: Descriptor, refs: Refs?): Instance
	local instance = Instance.new(descriptor.class)

	Create.apply(scope, instance, descriptor.props)
	Create.connect(scope, instance, descriptor.events)

	for _, child in descriptor.children or {} do
		if typeof(child) == "Instance" then
			child.Parent = instance
		else
			Create.node(scope, child :: Descriptor, refs).Parent = instance
		end
	end

	if descriptor.ref and refs then
		refs[descriptor.ref] = instance
	end

	scope:add(instance)

	return instance
end

--- Builds a descriptor and hands back the root plus every named ref in it.
function Create.tree(scope: Scope, descriptor: Descriptor): (Instance, Refs)
	local refs: Refs = {}
	local root = Create.node(scope, descriptor, refs)

	return root, refs
end

--- Binds one reactive source to one property of an existing instance.
function Create.bind(scope: Scope, instance: Instance, key: string, source: any): Instance
	scope:add(State.observe(source, function(next)
		assign(instance, key, next)
	end))

	return instance
end

--// descriptor helpers: the modifiers every surface reaches for
function Create.corner(radius: number | UDim): Descriptor
	local value = if typeof(radius) == "UDim" then radius else UDim.new(0, radius :: number)

	return { class = "UICorner", props = { CornerRadius = value } }
end

function Create.stroke(color: Color3, thickness: number, transparency: number?): Descriptor
	return {
		class = "UIStroke",
		props = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Transparency = transparency or 0,
			Thickness = thickness,
			Color = color,
		},
	}
end

function Create.padding(x: number, y: number?, right: number?, bottom: number?): Descriptor
	local vertical = y or x

	return {
		class = "UIPadding",
		props = {
			PaddingLeft = UDim.new(0, x),
			PaddingRight = UDim.new(0, right or x),
			PaddingTop = UDim.new(0, vertical),
			PaddingBottom = UDim.new(0, bottom or vertical),
		},
	}
end

function Create.list(direction: Enum.FillDirection, gap: number, extra: { [string]: any }?): Descriptor
	local props: { [string]: any } = {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		FillDirection = direction,
	}

	for key, value in extra or {} do
		props[key] = value
	end

	return { class = "UIListLayout", props = props }
end

function Create.grid(cell: Vector2, gap: number, extra: { [string]: any }?): Descriptor
	local props: { [string]: any } = {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellPadding = UDim2.fromOffset(gap, gap),
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
	}

	for key, value in extra or {} do
		props[key] = value
	end

	return { class = "UIGridLayout", props = props }
end

function Create.gradient(colors: ColorSequence, rotation: number?, transparency: NumberSequence?): Descriptor
	return {
		class = "UIGradient",
		props = {
			Color = colors,
			Rotation = rotation or 0,
			Transparency = transparency or NumberSequence.new(0),
		},
	}
end

function Create.constraint(min: Vector2?, max: Vector2?): Descriptor
	return {
		class = "UISizeConstraint",
		props = {
			MinSize = min or Vector2.zero,
			MaxSize = max or Vector2.new(math.huge, math.huge),
		},
	}
end

--- A transparent, borderless frame — the shape ninety percent of containers
--- want before anything else is said about them.
function Create.frame(name: string, extra: { [string]: any }?): Descriptor
	local props: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = name,
	}

	for key, value in extra or {} do
		props[key] = value
	end

	return { class = "Frame", props = props }
end

return Create
