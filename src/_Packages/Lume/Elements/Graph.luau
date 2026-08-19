--!strict

--- A live series with thresholds: frame times, ping, memory.
---
--- The idea is borrowed from **Lori** (KYRORBLX/Lori), a debug overlay whose
--- graphs auto-scale, carry a unit, and colour themselves against a warning and
--- a failure line. That last part is what makes a debug graph worth looking at:
--- a number is only interesting relative to the number you would accept, so the
--- graph says which samples were unacceptable rather than leaving you to read
--- an axis.
---
--- Bars rather than a line, which is what separates it from `sparkline`. A
--- sparkline is a shape you read at a glance; a graph is samples you read
--- individually, and a bar can be coloured on its own where a line segment
--- belongs to two samples at once.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Graph = {}
Graph.__index = Graph

export type Fields = Types.NodeFields & Types.ElementFields & {
	samples: { number },
	bars: { Frame },
	window: number,

	minimum: number?,
	maximum: number?,
	warn: number?,
	fail: number?,
	optimum: string,

	unit: string,
	labelText: string,
	plotHeight: number,
	showValue: boolean,
	formatter: ((number) -> string)?,
}

--- Creates a graph. Prefer `panel:graph(label)`.
function Graph.new(app: Types.App): Types.Graph
	local theme = app.theme
	local scope = app.scope:child()

	local plotHeight = 44

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, plotHeight),
			Name = "Graph",
		},
		children = {
			Create.list(Enum.FillDirection.Vertical, theme.space.xs),
			{
				class = "Frame",
				ref = "header",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, theme.size.row),
					LayoutOrder = 1,
					Visible = false,
					Name = "Header",
				},
				children = {
					{
						class = "TextLabel",
						ref = "label",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.new(0.5, 0, 1, 0),

							Font = theme.font.body,
							TextSize = theme.text.sm,
							TextColor3 = theme.color.textMuted,
							TextTransparency = theme.transparency.muted,
							TextXAlignment = Enum.TextXAlignment.Left,

							Name = "Label",
							Text = "",
						},
					},
					{
						class = "TextLabel",
						ref = "readout",
						props = {
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0.5, 0, 1, 0),

							Font = theme.font.mono,
							TextSize = theme.text.xs,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Right,

							Name = "Readout",
							Text = "",
						},
					},
				},
			},
			{
				class = "Frame",
				ref = "plot",
				props = {
					BackgroundColor3 = theme.color.surfaceSunken,
					BackgroundTransparency = 0.6,
					BorderSizePixel = 0,
					ClipsDescendants = true,

					Size = UDim2.new(1, 0, 0, plotHeight),
					LayoutOrder = 2,
					Name = "Plot",
				},
				children = {
					Create.corner(theme.radius.sm),
					{
						class = "Frame",
						ref = "warnLine",
						props = {
							BackgroundColor3 = theme.color.warn,
							BackgroundTransparency = 0.6,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0, 0.5),
							Size = UDim2.new(1, 0, 0, 1),
							Visible = false,
							ZIndex = 2,
							Name = "Warn",
						},
					},
					{
						class = "Frame",
						ref = "failLine",
						props = {
							BackgroundColor3 = theme.color.danger,
							BackgroundTransparency = 0.5,
							BorderSizePixel = 0,

							AnchorPoint = Vector2.new(0, 0.5),
							Size = UDim2.new(1, 0, 0, 1),
							Visible = false,
							ZIndex = 2,
							Name = "Fail",
						},
					},
					{
						class = "Frame",
						ref = "bars",
						props = {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Name = "Bars",
						},
					},
				},
			},
		},
	})

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root :: GuiObject,
		refs = refs,
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "graph",
		desired = Vector2.new(0, plotHeight),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		samples = {},
		bars = {},
		window = 60,

		minimum = nil,
		maximum = nil,
		warn = nil,
		fail = nil,
		optimum = "low",

		unit = "",
		labelText = "",
		plotHeight = plotHeight,
		showValue = true,
		formatter = nil,
	}

	return setmetatable(fields, Graph) :: any
end

--- The scale the plot is drawn against: the fixed range if one was set, the
--- window's own extremes otherwise. The thresholds are folded in, so a warning
--- line never sits off the top of a quiet graph.
function Graph.bounds(self: Fields): (number, number)
	local low = self.minimum
	local high = self.maximum

	if not low or not high then
		local seenLow = self.samples[1] or 0
		local seenHigh = self.samples[1] or 1

		for _, sample in self.samples do
			seenLow = math.min(seenLow, sample)
			seenHigh = math.max(seenHigh, sample)
		end

		low = low or math.min(seenLow, 0)
		high = high or seenHigh
	end

	for _, threshold in { self.warn, self.fail } do
		if threshold then
			high = math.max(high :: number, threshold)
			low = math.min(low :: number, threshold)
		end
	end

	if (high :: number) - (low :: number) <= 0 then
		high = (low :: number) + 1
	end

	return low :: number, high :: number
end

--- Which band a sample is in. `optimum` decides whether over or under the
--- threshold is the bad side, exactly as it does on a meter.
function Graph.grade(self: Fields, sample: number): string
	local fail = self.fail
	local warn = self.warn

	if self.optimum == "low" then
		if fail and sample >= fail then
			return "fail"
		end

		if warn and sample >= warn then
			return "warn"
		end

		return "ok"
	end

	if fail and sample <= fail then
		return "fail"
	end

	if warn and sample <= warn then
		return "warn"
	end

	return "ok"
end

function Graph.paint(self: Fields)
	local theme = self.app.theme
	local host = self.refs.bars :: Frame

	local count = #self.samples
	local low, high = Graph.bounds(self)
	local span = high - low

	--// one bar per sample, recycled: a graph pushed once a frame would
	--// otherwise build and destroy sixty instances a second
	while #self.bars < count do
		local bar = Create.node(self.scope, {
			class = "Frame",
			props = {
				BackgroundColor3 = theme.color.accent,
				BorderSizePixel = 0,

				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(0, 0),
				Name = `Bar{#self.bars + 1}`,
			},
		}) :: Frame

		bar.Parent = host

		table.insert(self.bars, bar)
	end

	for index = count + 1, #self.bars do
		self.bars[index].Visible = false
	end

	local slot = 1 / math.max(count, 1)

	for index = 1, count do
		local sample = self.samples[index]
		local bar = self.bars[index]
		local grade = Graph.grade(self, sample)

		bar.Visible = true
		bar.Position = UDim2.fromScale((index - 0.5) * slot, 1)
		bar.Size = UDim2.new(slot, -1, math.clamp((sample - low) / span, 0, 1), 0)
		bar.BackgroundColor3 = if grade == "fail"
			then theme.color.danger
			elseif grade == "warn" then theme.color.warn
			else theme.color.accent
		bar.BackgroundTransparency = if index == count then 0 else 0.25
	end

	local function place(line: Frame, threshold: number?)
		line.Visible = threshold ~= nil

		if threshold then
			line.Position = UDim2.fromScale(0, 1 - math.clamp((threshold - low) / span, 0, 1))
		end
	end

	place(self.refs.warnLine :: Frame, self.warn)
	place(self.refs.failLine :: Frame, self.fail)

	if self.showValue then
		local readout = self.refs.readout :: TextLabel
		local last = self.samples[count]

		if last then
			readout.Text = if self.formatter
				then self.formatter(last)
				else `{string.format(if last % 1 == 0 then "%d" else "%.1f", last)}{self.unit}`

			local grade = Graph.grade(self, last)

			readout.TextColor3 = if grade == "fail"
				then theme.color.danger
				elseif grade == "warn" then theme.color.warn
				else theme.color.text
		else
			readout.Text = ""
		end
	end
end

--- Adds a sample, dropping the oldest once the window is full.
function Graph.push(self: Fields & Types.Graph, sample: number): Types.Graph
	table.insert(self.samples, sample)

	while #self.samples > self.window do
		table.remove(self.samples, 1)
	end

	Graph.paint(self)

	return self
end

function Graph.setSamples(self: Fields & Types.Graph, samples: Types.Bindable<{ number }>): Types.Graph
	Node.bind(self, "samples", samples, function(next: { number })
		self.samples = table.clone(next)

		while #self.samples > self.window do
			table.remove(self.samples, 1)
		end

		Graph.paint(self)
	end)

	return self
end

--- How many samples are kept. Sixty by default — a second of frames.
function Graph.setWindow(self: Fields & Types.Graph, window: number): Types.Graph
	self.window = math.max(2, math.round(window))

	while #self.samples > self.window do
		table.remove(self.samples, 1)
	end

	Graph.paint(self)

	return self
end

--- Fixes the vertical scale. Left unset, the graph scales to what it has.
function Graph.setRange(self: Fields & Types.Graph, minimum: number?, maximum: number?): Types.Graph
	self.minimum = minimum
	self.maximum = maximum

	Graph.paint(self)

	return self
end

--- The line a sample is unwelcome past, and the line it is a failure past.
function Graph.setThresholds(self: Fields & Types.Graph, warn: number?, fail: number?): Types.Graph
	self.warn = warn
	self.fail = fail

	Graph.paint(self)

	return self
end

--- `"low"` means low samples are healthy — frame time, ping. `"high"` means
--- high ones are — frames per second.
function Graph.setOptimum(self: Fields & Types.Graph, optimum: "high" | "low"): Types.Graph
	self.optimum = optimum

	Graph.paint(self)

	return self
end

--- Written straight after the number: `"ms"`, `"%"`, `" fps"`.
function Graph.setUnit(self: Fields & Types.Graph, unit: string): Types.Graph
	self.unit = unit

	Graph.paint(self)

	return self
end

function Graph.setLabel(self: Fields & Types.Graph, label: Types.Bindable<string>): Types.Graph
	Node.bind(self, "label", label, function(next: string)
		local text = self.refs.label :: TextLabel

		self.labelText = tostring(next)

		text.Text = self.labelText
		;(self.refs.header :: Frame).Visible = self.labelText ~= "" or self.showValue

		self:invalidate()
	end)

	return self
end

function Graph.setShowValue(self: Fields & Types.Graph, shown: boolean?): Types.Graph
	self.showValue = shown ~= false
	;(self.refs.readout :: TextLabel).Visible = self.showValue
	;(self.refs.header :: Frame).Visible = self.labelText ~= "" or self.showValue

	Graph.paint(self)

	return self:invalidate()
end

function Graph.setFormat(self: Fields & Types.Graph, format: (number) -> string): Types.Graph
	self.formatter = format

	Graph.paint(self)

	return self
end

function Graph.setPlotHeight(self: Fields & Types.Graph, height: number): Types.Graph
	self.plotHeight = math.max(16, height)
	;(self.refs.plot :: Frame).Size = UDim2.new(1, 0, 0, self.plotHeight)

	return self:invalidate()
end

--- The most recent sample.
function Graph.last(self: Fields & Types.Graph): number?
	return self.samples[#self.samples]
end

--- The mean of the window, which is the number worth quoting when the last
--- sample is noisy.
function Graph.average(self: Fields & Types.Graph): number
	local count = #self.samples

	if count == 0 then
		return 0
	end

	local total = 0

	for _, sample in self.samples do
		total += sample
	end

	return total / count
end

function Graph.clear(self: Fields & Types.Graph): Types.Graph
	table.clear(self.samples)

	Graph.paint(self)

	return self
end

function Graph.measure(self: Fields & Types.Graph, available: Vector2): Vector2
	local theme = self.app.theme
	local height = self.plotHeight

	if (self.refs.header :: Frame).Visible then
		height += theme.size.row + theme.space.xs
	end

	self.desired = Vector2.new(math.ceil(math.max(1, available.X - self.margin * 2)), math.ceil(height))
	self.measured = true

	return self.desired
end

Element.install(Graph)

return Graph
