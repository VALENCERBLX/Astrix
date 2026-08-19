--!strict

--- A tree you can fold: folders, a scene graph, anything nested.
---
--- The list of nodes is a shape; what gets drawn is that shape flattened to the
--- rows currently visible. Collapsing a branch removes its descendants from the
--- flattened list rather than hiding instances, so a folder with ten thousand
--- children costs nothing while it is closed.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Motion = require(script.Parent.Parent.Motion)
local Hover = require(script.Parent.Parent.Input.Hover)
local Text = require(script.Parent.Parent.Text)
local Element = require(script.Parent.Element)

local Tree = {}
Tree.__index = Tree

type Flat = { node: Types.TreeNode, depth: number, parent: string? }

export type Fields = Types.NodeFields & Types.ElementFields & {
	nodes: { Types.TreeNode },
	flat: { Flat },
	rows: { TextButton },
	expanded: { [string]: boolean },
	selected: string?,
	rowHeight: number,
	indent: number,
}

--// locals
local function identify(node: Types.TreeNode, index: number, parent: string?): string
	return node.id or `{parent or "root"}/{node.text or index}`
end

--- Creates a tree. Prefer `panel:tree()`.
function Tree.new(app: Types.App): Types.Tree
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			Name = "Tree",
		},
		children = { Create.list(Enum.FillDirection.Vertical, 0) },
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

		kind = "tree",
		desired = Vector2.new(0, 0),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		nodes = {},
		flat = {},
		rows = {},
		expanded = {},
		selected = nil,
		rowHeight = theme.size.row,
		indent = 14,
	}

	return setmetatable(fields, Tree) :: any
end

--- Walks the shape and writes down the rows that are currently visible.
function Tree.flatten(self: Fields)
	table.clear(self.flat)

	local function walk(nodes: { Types.TreeNode }, depth: number, parent: string?)
		for index, node in nodes do
			local id = identify(node, index, parent)

			table.insert(self.flat, { node = node, depth = depth, parent = parent })

			if node.children and #node.children > 0 and self.expanded[id] then
				walk(node.children, depth + 1, id)
			end
		end
	end

	walk(self.nodes, 0, nil)
end

function Tree.paint(self: Fields)
	local theme = self.app.theme

	for index, row in self.rows do
		local entry = self.flat[index]

		if not entry then
			continue
		end

		local id = identify(entry.node, index, entry.parent)
		local chosen = id == self.selected

		row.BackgroundTransparency = if chosen then 0.82 else 1
		row.TextColor3 = if chosen then theme.color.text else theme.color.textMuted
		row.TextTransparency = if chosen then 0 else theme.transparency.muted
	end
end

--- Rebuilds the visible rows.
function Tree.rebuild(self: Fields & Types.Tree)
	local theme = self.app.theme

	for _, row in self.rows do
		row:Destroy()
	end

	table.clear(self.rows)

	Tree.flatten(self)

	for index, entry in self.flat do
		local node = entry.node
		local id = identify(node, index, entry.parent)
		local branch = node.children ~= nil and #node.children > 0
		local indent = theme.space.xs + entry.depth * self.indent

		local row, refs = Create.tree(self.scope, {
			class = "TextButton",
			ref = "row",
			props = {
				BackgroundColor3 = theme.color.surfaceHover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,

				Size = UDim2.new(1, 0, 0, self.rowHeight),
				LayoutOrder = index,

				Font = theme.font.body,
				TextSize = theme.text.sm,
				TextColor3 = theme.color.textMuted,
				TextTransparency = theme.transparency.muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,

				Name = `Node_{id}`,
				Text = "",
			},
			children = {
				Create.corner(theme.radius.sm),
				{
					class = "TextButton",
					ref = "chevron",
					props = {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AutoButtonColor = false,

						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, indent, 0.5, 0),
						Size = UDim2.fromOffset(14, self.rowHeight),

						Font = theme.font.medium,
						TextSize = theme.text.xs,
						TextColor3 = theme.color.textGhost,
						TextTransparency = theme.transparency.ghost,
						Rotation = if self.expanded[id] then 90 else 0,

						Visible = branch,
						Name = "Chevron",
						Text = "▶",
					},
				},
				{
					class = "TextLabel",
					ref = "text",
					props = {
						BackgroundTransparency = 1,

						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, indent + 18, 0.5, 0),
						Size = UDim2.new(1, -(indent + 18 + theme.space.xs), 0, self.rowHeight),

						Font = theme.font.body,
						TextSize = theme.text.sm,
						TextColor3 = theme.color.text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						RichText = true,

						Name = "Text",
						Text = Text.escape(node.text or ""),
					},
				},
			},
		})

		row.Parent = self.instance

		table.insert(self.rows, row :: TextButton)

		local chevron = refs.chevron :: TextButton

		Hover.attach(self.scope, row :: TextButton, function(hovering)
			if not self.enabled or id == self.selected then
				return
			end

			(row :: TextButton).BackgroundTransparency = if hovering then 0.92 else 1
		end)

		self.scope:add(chevron.Activated:Connect(function()
			if not self.enabled or not branch then
				return
			end

			Tree.toggleNode(self, id)
		end))

		self.scope:add((row :: TextButton).Activated:Connect(function()
			if not self.enabled then
				return
			end

			self.selected = id

			Tree.paint(self)

			self:emit("selected", node, id)

			--// a branch row is a folder: clicking it opens it, which is what
			--// everyone expects and saves aiming at a 14px chevron
			if branch then
				Tree.toggleNode(self, id)
			end
		end))

		if branch then
			Motion.set(chevron, { Rotation = if self.expanded[id] then 90 else 0 })
		end
	end

	Tree.paint(self)
end

function Tree.setNodes(self: Fields & Types.Tree, nodes: Types.Bindable<{ Types.TreeNode }>): Types.Tree
	Node.bind(self, "nodes", nodes, function(next: { Types.TreeNode })
		self.nodes = next

		Tree.rebuild(self)

		self:invalidate()
	end)

	return self
end

function Tree.expandNode(self: Fields & Types.Tree, id: string): Types.Tree
	if self.expanded[id] then
		return self
	end

	self.expanded[id] = true

	Tree.rebuild(self)

	self:emit("toggled", id, true)

	return self:invalidate()
end

function Tree.collapseNode(self: Fields & Types.Tree, id: string): Types.Tree
	if not self.expanded[id] then
		return self
	end

	self.expanded[id] = nil

	Tree.rebuild(self)

	self:emit("toggled", id, false)

	return self:invalidate()
end

function Tree.toggleNode(self: Fields & Types.Tree, id: string): Types.Tree
	if self.expanded[id] then
		return Tree.collapseNode(self, id)
	end

	return Tree.expandNode(self, id)
end

--- Opens everything. On a big tree this is a lot of rows, which is the point of
--- it being a separate call rather than a default.
function Tree.expandAll(self: Fields & Types.Tree): Types.Tree
	local function walk(nodes: { Types.TreeNode }, parent: string?)
		for index, node in nodes do
			local id = identify(node, index, parent)

			if node.children and #node.children > 0 then
				self.expanded[id] = true

				walk(node.children, id)
			end
		end
	end

	walk(self.nodes, nil)

	Tree.rebuild(self)

	return self:invalidate()
end

function Tree.collapseAll(self: Fields & Types.Tree): Types.Tree
	table.clear(self.expanded)

	Tree.rebuild(self)

	return self:invalidate()
end

function Tree.setSelected(self: Fields & Types.Tree, id: string?): Types.Tree
	self.selected = id

	Tree.paint(self)

	return self
end

function Tree.setIndent(self: Fields & Types.Tree, indent: number): Types.Tree
	self.indent = math.max(0, indent)

	Tree.rebuild(self)

	return self:invalidate()
end

function Tree.onSelected(self: Fields & Types.Tree, handler: (Types.TreeNode, string) -> ()): Types.Tree
	return self:on("selected", handler)
end

function Tree.onToggled(self: Fields & Types.Tree, handler: (string, boolean) -> ()): Types.Tree
	return self:on("toggled", handler)
end

function Tree.value(self: Fields & Types.Tree): string?
	return self.selected
end

--- How many rows are on screen — the flattened count, not the total.
function Tree.count(self: Fields & Types.Tree): number
	return #self.flat
end

function Tree.measure(self: Fields & Types.Tree, available: Vector2): Vector2
	self.desired = Vector2.new(
		math.ceil(math.max(1, available.X - self.margin * 2)),
		math.ceil(#self.flat * self.rowHeight)
	)
	self.measured = true

	return self.desired
end

Element.install(Tree)

return Tree
