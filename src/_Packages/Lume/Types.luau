--!strict

--- Every public type in Lume, in one place. Implementations annotate against
--- these records, so a class's runtime fields are declared here rather than
--- smuggled in behind an `any` cast.
---
--- The shape is deliberately two-layered: `*Fields` records hold state,
--- `*Api<T>` records hold the chained methods and are parameterised by the
--- concrete type so `Button:setName()` returns a `Button`, not a `Node`.
--- @section Core

--// reactive
export type Unsubscribe = () -> ()

--- A mutable reactive cell. Read with `get`, write with `set` or `update`.
export type Value<T> = {
	kind: "value",

	get: (self: Value<T>) -> T,
	set: (self: Value<T>, value: T) -> (),
	update: (self: Value<T>, transform: (T) -> T) -> (),
	subscribe: (self: Value<T>, listener: (T) -> ()) -> Unsubscribe,
	destroy: (self: Value<T>) -> (),
}

--- A derived cell. Recomputes when anything it read during evaluation changes.
export type Computed<T> = {
	kind: "computed",

	get: (self: Computed<T>) -> T,
	subscribe: (self: Computed<T>, listener: (T) -> ()) -> Unsubscribe,
	destroy: (self: Computed<T>) -> (),
}

export type Source<T> = Value<T> | Computed<T>

--- Anything a setter accepts: a plain value, or a source that feeds it.
export type Bindable<T> = T | Source<T>

--// lifecycle
export type Cleanup = (() -> ()) | Instance | RBXScriptConnection | { destroy: (any) -> () }

--- Owns everything created under it. Destroying a scope unwinds instances,
--- connections, subscriptions and child scopes in reverse order.
export type Scope = {
	add: (self: Scope, item: Cleanup) -> Cleanup,
	child: (self: Scope) -> Scope,
	alive: (self: Scope) -> boolean,
	destroy: (self: Scope) -> (),
}

export type Signal = {
	connect: (self: Signal, handler: (...any) -> ()) -> Unsubscribe,
	once: (self: Signal, handler: (...any) -> ()) -> Unsubscribe,
	fire: (self: Signal, ...any) -> (),
	count: (self: Signal) -> number,
	destroy: (self: Signal) -> (),
}

--// construction
export type Descriptor = {
	class: string,
	ref: string?,

	props: { [string]: any }?,
	events: { [string]: (...any) -> () }?,
	children: { Descriptor | Instance }?,
}

export type Refs = { [string]: Instance }

--// theme
--- A motion intent. `duration` + `easing` picks the tween path, `stiffness` +
--- `damping` picks the spring path. A spec with both prefers the spring.
export type MotionSpec = {
	duration: number?,
	easing: string?,
	stiffness: number?,
	damping: number?,
}

export type ShadowTokens = {
	image: string,
	slice: Rect,
	color: Color3,
	transparency: number,
	spread: number,
	offset: Vector2,
}

export type Theme = {
	name: string,

	color: { [string]: Color3 },
	rich: { [string]: string },
	transparency: { [string]: number },

	font: { [string]: Enum.Font },
	text: { [string]: number },

	space: { [string]: number },
	radius: { [string]: number },
	stroke: { [string]: number },
	size: { [string]: number },

	shadow: ShadowTokens,
	motion: { [string]: MotionSpec },

	extend: (self: Theme, overrides: { [string]: any }) -> Theme,
	spec: (self: Theme, named: MotionSpec | string | nil) -> MotionSpec,
}

--// motion
export type Animation = {
	completed: Signal,

	active: (self: Animation) -> boolean,
	cancel: (self: Animation) -> (),
	finish: (self: Animation) -> (),
}

--// layout
export type Edge = "top" | "bottom" | "left" | "right"

export type Anchor =
	"top"
	| "bottom"
	| "left"
	| "right"
	| "center"
	| "topLeft"
	| "topRight"
	| "bottomLeft"
	| "bottomRight"

export type Axis = "vertical" | "horizontal"

--- Cached text measurement. Every element sizes itself through this rather
--- than calling TextService directly, so a theme change flushes one cache.
export type Measurer = {
	text: (self: Measurer, text: string, size: number, font: Enum.Font, width: number?) -> Vector2,
	width: (self: Measurer, text: string, size: number, font: Enum.Font) -> number,
	lineHeight: (self: Measurer, size: number, font: Enum.Font) -> number,
	spaceWidth: (self: Measurer, size: number, font: Enum.Font) -> number,
	flush: (self: Measurer) -> (),
}

--- The result of one layout pass over a panel's children.
export type Solution = {
	content: Vector2,
	total: Vector2,
	clamped: Vector2,
	overflow: boolean,
}

--// input
export type DragHandle = {
	moved: Signal,
	started: Signal,
	ended: Signal,

	dragging: (self: DragHandle) -> boolean,
	setEnabled: (self: DragHandle, enabled: boolean) -> (),
	setPosition: (self: DragHandle, position: UDim2) -> (),
	destroy: (self: DragHandle) -> (),
}

export type KeyBinding = {
	keys: { Enum.KeyCode },
	handler: () -> (),
	disconnect: () -> (),
}

--// app
--- The one piece of shared state: host gui, theme, layers, measurement cache,
--- focus ring and key binder. One app per experience is the normal case.
export type App = {
	gui: LayerCollector,
	theme: Theme,
	scope: Scope,
	measure: Measurer,

	layers: { [string]: Frame },
	panels: { Panel },

	--- The focus ring (`Input/Focus`) and key binder (`Input/Keys`). Typed
	--- loosely here so the input modules can own their own concrete types
	--- without this file having to require them.
	focus: any,
	keys: any,

	resized: Signal,
	themed: Signal,

	viewport: (self: App) -> Vector2,
	surface: (self: App, layer: string) -> Frame,
	restyle: (self: App, overrides: { [string]: any }) -> Theme,

	panel: (self: App, preset: Preset?) -> Panel,
	stack: (self: App, anchor: Anchor?) -> Stack,

	bind: (self: App, keys: { Enum.KeyCode } | Enum.KeyCode, handler: () -> ()) -> KeyBinding,
	blur: (self: App) -> (),

	destroy: (self: App) -> (),
}

--// node: the shared base of Panel and Element
export type NodeFields = {
	app: App,
	scope: Scope,
	instance: GuiObject,

	refs: Refs,
	bindings: { [string]: Unsubscribe },
	events: { [string]: Signal },

	owner: Panel?,
	dead: boolean,
}

export type NodeApi<T> = {
	setName: (self: T, name: string) -> T,
	setVisible: (self: T, visible: Bindable<boolean>) -> T,
	setSize: (self: T, size: Bindable<UDim2>) -> T,
	setPosition: (self: T, position: Bindable<UDim2>) -> T,
	setAnchorPoint: (self: T, anchor: Bindable<Vector2>) -> T,
	setZIndex: (self: T, index: Bindable<number>) -> T,
	setLayoutOrder: (self: T, order: Bindable<number>) -> T,
	setProps: (self: T, props: { [string]: any }) -> T,

	on: (self: T, event: string, handler: (...any) -> ()) -> T,
	once: (self: T, event: string, handler: (...any) -> ()) -> T,
	emit: (self: T, event: string, ...any) -> T,

	animate: (self: T, props: { [string]: any }, spec: (MotionSpec | string)?) -> Animation,
	get: (self: T) -> GuiObject,
	alive: (self: T) -> boolean,
	destroy: (self: T) -> (),
}

--// element
export type ElementFields = {
	kind: string,

	desired: Vector2,
	margin: number,
	fill: boolean,
	grow: boolean,
	enabled: boolean,
	measured: boolean,
}

export type ElementApi<T> = {
	--- Desired size given the space the panel can offer. Panels call this;
	--- you rarely do.
	measure: (self: T, available: Vector2) -> Vector2,

	--- Applies the size the panel decided on. Called by the panel immediately
	--- after solving, once the final inner width is known — which is the only
	--- point at which a `fill` element can be sized correctly.
	commit: (self: T, inner: Vector2, vertical: boolean, share: number) -> (),

	--- Mark the element's size stale and schedule a panel layout pass.
	invalidate: (self: T) -> T,

	--- Re-measure. Bubbles to whatever contains this element, so any element
	--- can host children without special-casing.
	refresh: (self: T) -> T,

	setFill: (self: T, fill: boolean) -> T,
	setGrow: (self: T, grow: boolean) -> T,
	setMargin: (self: T, margin: number) -> T,
	setOrder: (self: T, order: number) -> T,
	setEnabled: (self: T, enabled: Bindable<boolean>) -> T,
	setTooltip: (self: T, text: Bindable<string>) -> T,

	--- The panel hosting this element, if it is mounted in one.
	host: (self: T) -> Panel?,
}

export type Element = NodeFields & ElementFields & NodeApi<Element> & ElementApi<Element>

--// panel
export type Preset = "window" | "bar" | "popover" | "tooltip" | "modal" | "toast" | "card" | "sheet" | "plain"

export type PanelFields = {
	preset: Preset,
	anchor: Anchor,
	axis: Axis,
	layer: string,

	content: ScrollingFrame,
	children: { Element },
	panels: { Panel },

	titleHeight: number,
	hasTitle: boolean,
	scrollable: boolean,
	dismissable: boolean,
	dirty: boolean,
	mounted: boolean,

	backdrop: Frame?,
	attachTarget: GuiObject?,
	attachSide: Edge,
	attachGap: number,

	gap: number,
	padX: number,
	padY: number,

	minWidth: number,
	maxWidth: number,
	minHeight: number,
	maxHeight: number,
	fixedWidth: number?,
	fixedHeight: number?,

	inset: number,
	radius: number,
	pill: boolean,

	opened: boolean,
	solving: boolean,
	seq: number,

	target: Vector2,
	settled: UDim2,

	stack: Stack?,
	drag: DragHandle?,
	shadow: ImageLabel?,
	--- What `setShadow` was last told. The shadow tracker reads it, so a
	--- shadow turned off stays off across layout passes.
	shadowOn: boolean,
}

export type PanelApi<T> = {
	--// shell
	setPreset: (self: T, preset: Preset) -> T,
	setTitle: (self: T, title: Bindable<string>) -> T,
	setSubtitle: (self: T, subtitle: Bindable<string>) -> T,
	setIcon: (self: T, image: Bindable<string>) -> T,
	setAnchor: (self: T, anchor: Anchor, offset: Vector2?) -> T,
	setLayer: (self: T, layer: string) -> T,
	setRadius: (self: T, radius: number | "pill") -> T,
	--- Makes the whole panel clickable, for a collapsed bar that expands when
	--- you click it. The target sits above the content, so it is turned off
	--- automatically while the panel is expanded.
	setActivatable: (self: T, enabled: boolean) -> T,
	onActivated: (self: T, handler: () -> ()) -> T,
	setColor: (self: T, color: Bindable<Color3>) -> T,
	setTransparency: (self: T, transparency: Bindable<number>) -> T,
	setBorder: (self: T, enabled: boolean) -> T,
	setShadow: (self: T, enabled: boolean) -> T,
	setClip: (self: T, enabled: boolean) -> T,

	--// layout
	setAxis: (self: T, axis: Axis) -> T,
	setGap: (self: T, gap: number) -> T,
	setPadding: (self: T, x: number, y: number?) -> T,
	setWidth: (self: T, width: number | "auto") -> T,
	setHeight: (self: T, height: number | "auto") -> T,
	setMinSize: (self: T, width: number, height: number) -> T,
	setMaxSize: (self: T, width: number, height: number) -> T,
	setInset: (self: T, inset: number) -> T,
	setScroll: (self: T, enabled: boolean) -> T,

	--// behaviour
	--- `options` forwards to `Input/Drag` — `smooth` for a springy follow with
	--- a little overshoot on release, `axis` to lock one direction, `bounds`
	--- to allow leaving the viewport.
	setDraggable: (self: T, enabled: boolean, options: { [string]: any }?) -> T,
	setDismissable: (self: T, enabled: boolean) -> T,
	setCloseButton: (self: T, enabled: boolean) -> T,
	attachTo: (self: T, target: GuiObject | Element | Panel, side: Edge?, gap: number?) -> T,

	--// children
	add: (self: T, child: Element | Panel) -> T,
	remove: (self: T, child: Element | Panel) -> T,
	clear: (self: T) -> T,

	--// child factories
	label: (self: T, text: Bindable<string>?) -> Label,
	icon: (self: T, image: Bindable<string>?) -> Icon,
	button: (self: T, text: Bindable<string>?) -> Button,
	field: (self: T, placeholder: Bindable<string>?) -> Field,
	toggle: (self: T, label: Bindable<string>?) -> Toggle,
	slider: (self: T, label: Bindable<string>?) -> Slider,
	select: (self: T, label: Bindable<string>?) -> Select,
	list: (self: T) -> List,
	divider: (self: T) -> Divider,
	spacer: (self: T, size: number?) -> Spacer,
	group: (self: T, axis: Axis?) -> Group,
	progress: (self: T) -> Progress,
	tabs: (self: T) -> Tabs,
	chips: (self: T) -> Chips,
	suggest: (self: T) -> Suggest,
	menu: (self: T) -> Menu,
	menuBar: (self: T, menus: { MenuGroup }?) -> MenuBar,
	colorPicker: (self: T, label: Bindable<string>?) -> ColorPicker,
	stepper: (self: T, label: Bindable<string>?) -> Stepper,
	accordion: (self: T) -> Accordion,
	badge: (self: T, text: Bindable<string>?) -> Badge,
	scroll: (self: T) -> Scroll,
	keybind: (self: T, label: Bindable<string>?) -> Keybind,
	panel: (self: T, preset: Preset?) -> Panel,

	--// lifecycle
	open: (self: T) -> T,
	close: (self: T) -> T,
	toggleOpen: (self: T) -> T,
	isOpen: (self: T) -> boolean,

	--- Recompute this panel's size from its children. Coalesced to one pass
	--- per frame; call it freely.
	refresh: (self: T) -> T,
	--- Recompute immediately, skipping the deferred coalescing.
	refreshNow: (self: T) -> T,

	mount: (self: T, parent: Instance | Panel) -> T,
	center: (self: T) -> T,
	moveTo: (self: T, position: UDim2) -> T,
	front: (self: T) -> T,
	--- A brief lift of the surface and a slower settle back — for marking
	--- which panel just took focus.
	flash: (self: T, amount: number?, rise: (MotionSpec | string)?, fall: (MotionSpec | string)?) -> T,
}

export type Panel = NodeFields & PanelFields & NodeApi<Panel> & ElementApi<Panel> & PanelApi<Panel>

--// stack: panels laid out in sequence from a shared anchor
export type Stack = {
	app: App,
	anchor: Anchor,
	axis: Axis,
	gap: number,
	members: { Panel },

	add: (self: Stack, panel: Panel) -> Stack,
	remove: (self: Stack, panel: Panel) -> Stack,
	setGap: (self: Stack, gap: number) -> Stack,
	setOrigin: (self: Stack, position: UDim2) -> Stack,
	reflow: (self: Stack, spec: (MotionSpec | string)?) -> Stack,
	destroy: (self: Stack) -> (),
}

--// elements
export type Label = NodeFields & ElementFields & NodeApi<Label> & ElementApi<Label> & {
	setText: (self: Label, text: Bindable<string>) -> Label,
	setColor: (self: Label, color: Bindable<Color3>) -> Label,
	setTextSize: (self: Label, size: number) -> Label,
	setFont: (self: Label, font: Enum.Font) -> Label,
	setAlign: (self: Label, horizontal: Enum.TextXAlignment, vertical: Enum.TextYAlignment?) -> Label,
	setWrapped: (self: Label, wrapped: boolean) -> Label,
	setRich: (self: Label, rich: boolean) -> Label,
	setMuted: (self: Label, muted: boolean) -> Label,
	setMaxLines: (self: Label, lines: number) -> Label,
	text: (self: Label) -> string,
}

export type Icon = NodeFields & ElementFields & NodeApi<Icon> & ElementApi<Icon> & {
	setImage: (self: Icon, image: Bindable<string>) -> Icon,
	setColor: (self: Icon, color: Bindable<Color3>) -> Icon,
	setIconSize: (self: Icon, size: number) -> Icon,
	setScaleType: (self: Icon, scale: Enum.ScaleType) -> Icon,
	setRectOffset: (self: Icon, offset: Vector2, size: Vector2) -> Icon,
	setSpin: (self: Icon, spinning: boolean) -> Icon,
}

export type Button = NodeFields & ElementFields & NodeApi<Button> & ElementApi<Button> & {
	setText: (self: Button, text: Bindable<string>) -> Button,
	setIcon: (self: Button, image: Bindable<string>) -> Button,
	setVariant: (self: Button, variant: "solid" | "soft" | "ghost" | "outline" | "danger") -> Button,
	setColor: (self: Button, color: Bindable<Color3>) -> Button,
	setRadius: (self: Button, radius: number | "pill") -> Button,
	setLoading: (self: Button, loading: Bindable<boolean>) -> Button,
	setFixedWidth: (self: Button, width: number) -> Button,

	onClicked: (self: Button, handler: () -> ()) -> Button,
	onPressed: (self: Button, handler: () -> ()) -> Button,
	onReleased: (self: Button, handler: () -> ()) -> Button,
	onHovered: (self: Button, handler: (boolean) -> ()) -> Button,

	click: (self: Button) -> Button,
}

export type Field = NodeFields & ElementFields & NodeApi<Field> & ElementApi<Field> & {
	setText: (self: Field, text: Bindable<string>) -> Field,
	setPlaceholder: (self: Field, placeholder: Bindable<string>) -> Field,
	setPrefix: (self: Field, prefix: Bindable<string>) -> Field,
	setIcon: (self: Field, image: Bindable<string>) -> Field,
	setHint: (self: Field, hint: Bindable<string>) -> Field,
	setFont: (self: Field, font: Enum.Font) -> Field,
	setTextSize: (self: Field, size: number) -> Field,
	--- A trailing glyph on the right edge — the console's submit arrow.
	setTrailingIcon: (self: Field, image: Bindable<string>) -> Field,
	--- Recolours the parts independently: `text`, `placeholder`, `prefix`,
	--- `hint`, `icon`. Omitted keys keep their current colour.
	setColors: (self: Field, colors: { [string]: Color3 }) -> Field,
	setRadius: (self: Field, radius: number | "pill") -> Field,
	setSurface: (self: Field, color: Color3, transparency: number) -> Field,
	setBorder: (self: Field, enabled: boolean) -> Field,
	setMultiline: (self: Field, multiline: boolean) -> Field,
	setMasked: (self: Field, masked: boolean) -> Field,
	setMaxLength: (self: Field, length: number) -> Field,
	setClearOnSubmit: (self: Field, clear: boolean) -> Field,
	setValidator: (self: Field, validator: (string) -> (boolean, string?)) -> Field,

	onChanged: (self: Field, handler: (string) -> ()) -> Field,
	onSubmitted: (self: Field, handler: (string) -> ()) -> Field,
	onFocused: (self: Field, handler: () -> ()) -> Field,
	onBlurred: (self: Field, handler: () -> ()) -> Field,

	focus: (self: Field) -> Field,
	blur: (self: Field) -> Field,
	value: (self: Field) -> string,
}

export type Toggle = NodeFields & ElementFields & NodeApi<Toggle> & ElementApi<Toggle> & {
	setLabel: (self: Toggle, label: Bindable<string>) -> Toggle,
	setDescription: (self: Toggle, description: Bindable<string>) -> Toggle,
	setValue: (self: Toggle, value: Bindable<boolean>) -> Toggle,
	setStyle: (self: Toggle, style: "switch" | "checkbox") -> Toggle,

	onChanged: (self: Toggle, handler: (boolean) -> ()) -> Toggle,

	flip: (self: Toggle) -> Toggle,
	value: (self: Toggle) -> boolean,
}

export type Slider = NodeFields & ElementFields & NodeApi<Slider> & ElementApi<Slider> & {
	setLabel: (self: Slider, label: Bindable<string>) -> Slider,
	setRange: (self: Slider, min: number, max: number) -> Slider,
	setStep: (self: Slider, step: number) -> Slider,
	setValue: (self: Slider, value: Bindable<number>) -> Slider,
	setFormat: (self: Slider, format: (number) -> string) -> Slider,
	setShowValue: (self: Slider, shown: boolean) -> Slider,

	onChanged: (self: Slider, handler: (number) -> ()) -> Slider,
	onCommitted: (self: Slider, handler: (number) -> ()) -> Slider,

	value: (self: Slider) -> number,
}

export type Accordion = NodeFields & ElementFields & NodeApi<Accordion> & ElementApi<Accordion> & {
	--- Adds a section and returns its body, which is a group.
	section: (self: Accordion, title: string, id: string?) -> Group,
	--- The body of a section already added.
	bodyOf: (self: Accordion, id: string) -> Group?,

	openSection: (self: Accordion, id: string) -> Accordion,
	closeSection: (self: Accordion, id: string) -> Accordion,
	toggleSection: (self: Accordion, id: string) -> Accordion,

	--- Only one section open at a time.
	setExclusive: (self: Accordion, exclusive: boolean?) -> Accordion,
	setGap: (self: Accordion, gap: number) -> Accordion,
	clear: (self: Accordion) -> Accordion,

	openIds: (self: Accordion) -> { string },

	onToggled: (self: Accordion, handler: (string, boolean) -> ()) -> Accordion,
}

export type Stepper = NodeFields & ElementFields & NodeApi<Stepper> & ElementApi<Stepper> & {
	setLabel: (self: Stepper, label: Bindable<string>) -> Stepper,
	setRange: (self: Stepper, min: number, max: number) -> Stepper,
	setStep: (self: Stepper, step: number) -> Stepper,
	setValue: (self: Stepper, value: Bindable<number>) -> Stepper,
	setFormat: (self: Stepper, format: (number) -> string) -> Stepper,
	--- Past the top comes back to the bottom.
	setWrap: (self: Stepper, wrap: boolean?) -> Stepper,

	--- Moves by whole steps. `bump(-1)` is one press of minus.
	bump: (self: Stepper, steps: number) -> Stepper,

	--- Fires on every step.
	onChanged: (self: Stepper, handler: (number) -> ()) -> Stepper,
	--- Fires when the interaction ends. A held repeat is one commit, not forty.
	onCommitted: (self: Stepper, handler: (number) -> ()) -> Stepper,

	value: (self: Stepper) -> number,
}

export type Option = { id: string, text: string, icon: string?, description: string? }

export type Select = NodeFields & ElementFields & NodeApi<Select> & ElementApi<Select> & {
	setLabel: (self: Select, label: Bindable<string>) -> Select,
	setOptions: (self: Select, options: Bindable<{ Option | string }>) -> Select,
	setValue: (self: Select, id: Bindable<string?>) -> Select,
	setPlaceholder: (self: Select, placeholder: Bindable<string>) -> Select,
	setSearchable: (self: Select, searchable: boolean) -> Select,
	setMulti: (self: Select, multi: boolean) -> Select,

	onChanged: (self: Select, handler: (string?, Option?) -> ()) -> Select,
	onOpened: (self: Select, handler: () -> ()) -> Select,
	onClosed: (self: Select, handler: () -> ()) -> Select,

	value: (self: Select) -> string?,
	values: (self: Select) -> { string },
}

export type ListItem = {
	id: string?,
	text: string?,
	icon: string?,
	description: string?,
	height: number?,
	data: any?,
}

export type List = NodeFields & ElementFields & NodeApi<List> & ElementApi<List> & {
	setItems: (self: List, items: Bindable<{ ListItem | string }>) -> List,
	setRowHeight: (self: List, height: number) -> List,
	setFont: (self: List, font: Enum.Font) -> List,
	setTextSize: (self: List, size: number) -> List,
	setVirtual: (self: List, virtual: boolean) -> List,
	setMaxRows: (self: List, rows: number) -> List,
	setSelectable: (self: List, selectable: boolean) -> List,
	setStacked: (self: List, stacked: boolean?) -> List,
	setSelected: (self: List, id: Bindable<string?>) -> List,
	setEmptyText: (self: List, text: Bindable<string>) -> List,
	setRenderer: (self: List, renderer: (ListItem, number) -> string) -> List,

	onSelected: (self: List, handler: (ListItem, number) -> ()) -> List,
	onActivated: (self: List, handler: (ListItem, number) -> ()) -> List,
	onScrolled: (self: List, handler: (number) -> ()) -> List,

	scrollTo: (self: List, index: number) -> List,
	scrollToBottom: (self: List) -> List,
	count: (self: List) -> number,
}

export type Divider = NodeFields & ElementFields & NodeApi<Divider> & ElementApi<Divider> & {
	setLabel: (self: Divider, label: Bindable<string>) -> Divider,
	setThickness: (self: Divider, thickness: number) -> Divider,
	setColor: (self: Divider, color: Bindable<Color3>) -> Divider,
}

export type Spacer = NodeFields & ElementFields & NodeApi<Spacer> & ElementApi<Spacer> & {
	setAmount: (self: Spacer, amount: number) -> Spacer,
	setFlexible: (self: Spacer, flexible: boolean) -> Spacer,
}

export type Group = NodeFields & ElementFields & NodeApi<Group> & ElementApi<Group> & {
	setAxis: (self: Group, axis: Axis) -> Group,
	setGap: (self: Group, gap: number) -> Group,
	setAlign: (self: Group, horizontal: Enum.HorizontalAlignment, vertical: Enum.VerticalAlignment?) -> Group,
	setWrap: (self: Group, wrap: boolean) -> Group,

	add: (self: Group, child: Element) -> Group,
	clear: (self: Group) -> Group,

	label: (self: Group, text: Bindable<string>?) -> Label,
	icon: (self: Group, image: Bindable<string>?) -> Icon,
	button: (self: Group, text: Bindable<string>?) -> Button,
	field: (self: Group, placeholder: Bindable<string>?) -> Field,
	toggle: (self: Group, label: Bindable<string>?) -> Toggle,
	slider: (self: Group, label: Bindable<string>?) -> Slider,
	stepper: (self: Group, label: Bindable<string>?) -> Stepper,
	select: (self: Group, label: Bindable<string>?) -> Select,
	colorPicker: (self: Group, label: Bindable<string>?) -> ColorPicker,
	keybind: (self: Group, label: Bindable<string>?) -> Keybind,
	list: (self: Group) -> List,
	divider: (self: Group) -> Divider,
	progress: (self: Group) -> Progress,
	tabs: (self: Group) -> Tabs,
	chips: (self: Group) -> Chips,
	accordion: (self: Group) -> Accordion,
	menuBar: (self: Group, menus: { MenuGroup }?) -> MenuBar,
	badge: (self: Group, text: Bindable<string>?) -> Badge,
	spacer: (self: Group, size: number?) -> Spacer,
	group: (self: Group, axis: Axis?) -> Group,
}

export type Progress = NodeFields & ElementFields & NodeApi<Progress> & ElementApi<Progress> & {
	setValue: (self: Progress, value: Bindable<number>) -> Progress,
	setLabel: (self: Progress, label: Bindable<string>) -> Progress,
	setColor: (self: Progress, color: Bindable<Color3>) -> Progress,
	setIndeterminate: (self: Progress, indeterminate: boolean) -> Progress,
	setThickness: (self: Progress, thickness: number) -> Progress,
	setShowValue: (self: Progress, shown: boolean) -> Progress,
}

export type Tab = { id: string, text: string, icon: string? }

export type Tabs = NodeFields & ElementFields & NodeApi<Tabs> & ElementApi<Tabs> & {
	setTabs: (self: Tabs, tabs: Bindable<{ Tab | string }>) -> Tabs,
	setValue: (self: Tabs, id: Bindable<string>) -> Tabs,
	setVariant: (self: Tabs, variant: "underline" | "pill" | "segmented") -> Tabs,

	onChanged: (self: Tabs, handler: (string) -> ()) -> Tabs,

	value: (self: Tabs) -> string?,
}

export type Chips = NodeFields & ElementFields & NodeApi<Chips> & ElementApi<Chips> & {
	setChips: (self: Chips, chips: Bindable<{ Option | string }>) -> Chips,
	setRemovable: (self: Chips, removable: boolean) -> Chips,
	setSelectable: (self: Chips, selectable: boolean) -> Chips,
	setSelected: (self: Chips, ids: Bindable<{ string }>) -> Chips,
	setWrap: (self: Chips, wrap: boolean) -> Chips,

	onRemoved: (self: Chips, handler: (string) -> ()) -> Chips,
	onSelected: (self: Chips, handler: ({ string }) -> ()) -> Chips,

	selected: (self: Chips) -> { string },
}

export type Suggest = NodeFields & ElementFields & NodeApi<Suggest> & ElementApi<Suggest> & {
	setSource: (self: Suggest, source: Bindable<{ Option | string }>) -> Suggest,
	setQuery: (self: Suggest, query: Bindable<string>) -> Suggest,
	setLimit: (self: Suggest, limit: number) -> Suggest,
	setMatcher: (self: Suggest, matcher: (string, string) -> (boolean, number)) -> Suggest,
	attach: (self: Suggest, field: Field) -> Suggest,
	--- Point at a field without taking over its filtering.
	setField: (self: Suggest, field: Field) -> Suggest,

	onAccepted: (self: Suggest, handler: (Option) -> ()) -> Suggest,
	onHighlighted: (self: Suggest, handler: (Option?) -> ()) -> Suggest,

	next: (self: Suggest) -> Suggest,
	previous: (self: Suggest) -> Suggest,
	accept: (self: Suggest) -> Suggest,
	highlighted: (self: Suggest) -> Option?,
}

export type MenuItem = {
	id: string?,
	text: string,
	icon: string?,
	shortcut: string?,
	divider: boolean?,
	danger: boolean?,
	disabled: boolean?,
	action: (() -> ())?,
}

export type Menu = NodeFields & ElementFields & NodeApi<Menu> & ElementApi<Menu> & {
	setItems: (self: Menu, items: { MenuItem | string }) -> Menu,
	openAt: (self: Menu, position: Vector2) -> Menu,
	openUnder: (self: Menu, target: GuiObject | Element, side: Edge?) -> Menu,
	surface: (self: Menu) -> Panel?,
	closeMenu: (self: Menu) -> Menu,

	onPicked: (self: Menu, handler: (MenuItem) -> ()) -> Menu,
}

--- One titled menu in a bar: a word on the strip, and what drops from it.
export type MenuGroup = {
	id: string?,
	text: string,
	icon: string?,
	disabled: boolean?,
	items: { MenuItem | string },
}

export type MenuBar = NodeFields & ElementFields & NodeApi<MenuBar> & ElementApi<MenuBar> & {
	setMenus: (self: MenuBar, menus: { MenuGroup }) -> MenuBar,
	openMenu: (self: MenuBar, id: string) -> MenuBar,
	closeMenu: (self: MenuBar) -> MenuBar,
	openId: (self: MenuBar) -> string?,

	onPicked: (self: MenuBar, handler: (MenuItem, string) -> ()) -> MenuBar,
	onOpened: (self: MenuBar, handler: (string) -> ()) -> MenuBar,
}

export type ColorPicker = NodeFields & ElementFields & NodeApi<ColorPicker> & ElementApi<ColorPicker> & {
	setValue: (self: ColorPicker, color: Bindable<Color3>) -> ColorPicker,
	setLabel: (self: ColorPicker, label: Bindable<string>) -> ColorPicker,
	setSquareHeight: (self: ColorPicker, height: number) -> ColorPicker,
	setHexField: (self: ColorPicker, shown: boolean?) -> ColorPicker,
	--- Sets the colour without firing anything, for loading a saved value.
	setSilent: (self: ColorPicker, color: Color3) -> ColorPicker,

	value: (self: ColorPicker) -> Color3,
	hex: (self: ColorPicker) -> string,

	--- Fires continuously while dragging.
	onChanged: (self: ColorPicker, handler: (Color3) -> ()) -> ColorPicker,
	--- Fires once, on release. Save here.
	onCommitted: (self: ColorPicker, handler: (Color3) -> ()) -> ColorPicker,
}

export type Badge = NodeFields & ElementFields & NodeApi<Badge> & ElementApi<Badge> & {
	setText: (self: Badge, text: Bindable<string>) -> Badge,
	setTone: (self: Badge, tone: "neutral" | "accent" | "success" | "warn" | "danger") -> Badge,
	setDot: (self: Badge, dot: boolean) -> Badge,
}

export type Scroll = NodeFields & ElementFields & NodeApi<Scroll> & ElementApi<Scroll> & {
	setAxis: (self: Scroll, axis: Axis) -> Scroll,
	setGap: (self: Scroll, gap: number) -> Scroll,
	setMaxHeight: (self: Scroll, height: number) -> Scroll,
	setFade: (self: Scroll, enabled: boolean) -> Scroll,
	setBarVisible: (self: Scroll, visible: boolean) -> Scroll,

	add: (self: Scroll, child: Element) -> Scroll,
	clear: (self: Scroll) -> Scroll,
	scrollToBottom: (self: Scroll) -> Scroll,

	label: (self: Scroll, text: Bindable<string>?) -> Label,
	group: (self: Scroll, axis: Axis?) -> Group,
	list: (self: Scroll) -> List,
}

export type Keybind = NodeFields & ElementFields & NodeApi<Keybind> & ElementApi<Keybind> & {
	setLabel: (self: Keybind, label: Bindable<string>) -> Keybind,
	setValue: (self: Keybind, key: Bindable<Enum.KeyCode?>) -> Keybind,

	onChanged: (self: Keybind, handler: (Enum.KeyCode?) -> ()) -> Keybind,

	value: (self: Keybind) -> Enum.KeyCode?,
}

return {}
