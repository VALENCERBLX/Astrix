--!strict

--- Shared module types for Astrix.
---
--- Not to be confused with `_Types/`, which holds pluggable per-argument
--- providers (validation, casting, completion for a `Player` or a `Vector3`).
--- Similar-looking name, completely different concept.

--// content and output ---------------------------------------------------------
export type ContentElement =
	{ Kind: "Text", Value: string, Color: Color3? }
	| { Kind: "Table", Headers: { string }, Rows: { { string } } }
	| { Kind: "ProgressBar", Progress: number, Label: string? }
	| { Kind: "Ascii", Art: string }
	| { Kind: "Image", AssetId: string, Size: Vector2? }
	| { Kind: "Divider" }

export type HistoryKind = "Input" | "Output" | "Ok" | "Fail" | "Warn"

export type HistoryEntry = {
	Kind: HistoryKind,
	Text: string,
	Content: ContentElement?,
}

--// arguments and flags ---------------------------------------------------------
export type ArgumentType = "String" | "Number" | "Boolean" | "Player" | "Vector3" | "Enum"

export type Argument = {
	Name: string,
	Type: ArgumentType,
	Required: boolean,
	Default: any?,
	Description: string?,

	--- Only meaningful for `Type = "Enum"`. Without it there is nothing to
	--- validate against, which is why the Enum provider used to never run.
	EnumValues: { string }?,
}

export type FlagKind = "IsValue" | "IsBool"

export type Flag = {
	Name: string,
	Aliases: { string }?,
	Extended: FlagKind,
	Type: ArgumentType?,
	Default: any?,
	Description: string?,
}

--// execution -------------------------------------------------------------------
export type ResolveKind =
	"Ok"
	| "Fail"
	| "Warn"
	| "CommandNotFound"
	| "RankDenied"
	| "OnCooldown"
	| "ParseFailed"
	| "AbsoluteOverwrite"

export type CommandResolve = {
	Resolved: boolean,
	Kind: ResolveKind,
	Output: string?,
	Result: any?,
	Content: ContentElement?,
}

export type OutputChannel = {
	Reply: (Message: string | ContentElement) -> (),
	Error: (Message: string) -> (),
	Success: (Message: string) -> (),
	Elements: any,
}

export type ExecutionContext = {
	Executor: Player,
	Parsed: { [string]: any },
	Flags: { [string]: any },
	RawInput: string,
	Windows: any,
	Output: OutputChannel,
}

--// commands --------------------------------------------------------------------
export type CommandType = "Local" | "Server" | "Service"

export type CommandTask = (Context: ExecutionContext, PriorResult: any?) -> CommandResolve?

export type CommandTasks = {
	Server: CommandTask?,
	Local: CommandTask?,
}

export type CommandDefinition = {
	Name: string,
	Aliases: { string }?,
	Type: CommandType,
	Description: string?,
	Rank: number,
	Parsed: { Argument },
	Flags: { Flag }?,
	LocalFirst: boolean?,
	Cooldown: number?,
	Tasks: CommandTasks,
}

--- What actually crosses the network: a definition with its Tasks stripped.
export type ReplicatedDefinition = {
	Name: string,
	Aliases: { string }?,
	Type: CommandType,
	Description: string?,
	Rank: number,
	Parsed: { Argument },
	Flags: { Flag }?,
	LocalFirst: boolean?,
	Cooldown: number?,
}

--// the Kyn abstract syntax tree -------------------------------------------------
export type WordNode =
	{ Kind: "String", Value: string }
	| { Kind: "Number", Value: number }
	| { Kind: "Boolean", Value: boolean }
	| { Kind: "StackRef", Depth: number }
	| { Kind: "Ref", Path: { string }, Call: { WordNode }? }
	| { Kind: "Bareword", Value: string }

export type FlagNode = {
	Name: string,
	Value: WordNode?,
}

export type PipelineStage =
	{ Kind: "Command", Head: string, Args: { WordNode }, Flags: { FlagNode } }
	| { Kind: "RefCall", Ref: WordNode }
	| { Kind: "FunctionDecl", Name: string, Body: WordNode }

--- `Op` is the chain operator that FOLLOWS this segment, which is the form the
--- evaluator wants: it asks "did the segment before me resolve, and what
--- operator joined us?".
export type ChainSegment = {
	Pipeline: { PipelineStage },
	Op: string?,
}

export type LineAST = {
	Segments: { ChainSegment },
	Error: string?,
}

--// runtime ---------------------------------------------------------------------
export type RuntimeStats = {
	CommandsRun: number,
	LastActiveAt: number,
}

export type RuntimeSettings = {
	Theme: string,
	Keybind: Enum.KeyCode?,
}

export type InterfaceState = {
	History: { HistoryEntry },
	ZOrder: { string },
	Focus: string?,
}

export type RuntimeEntry = {
	Session: any,
	Stats: RuntimeStats,
	Settings: RuntimeSettings,
	Interface: { State: InterfaceState },
}

export type AstrixProfile = {
	Settings: { Theme: string, Keybind: number? },
	Stats: RuntimeStats,
}

--// argument type providers ------------------------------------------------------
export type ArgumentTypeProvider<T> = {
	Name: string,
	Validate: (Raw: string, Argument: Argument?) -> boolean,
	Resolve: (Raw: string, Argument: Argument?) -> T?,
	Suggest: (Prefix: string, Argument: Argument?) -> { string },
}

--// windows ----------------------------------------------------------------------
export type WindowConfig = {
	Id: string,
	Title: string?,
	Docked: boolean?,
	Position: UDim2?,
	Width: number?,
	Theme: any?,
}

--// options --------------------------------------------------------------------
export type AstrixOptions = {
	Interface: {
		Theme: string?,
		Keybind: Enum.KeyCode?,
		InterfaceRank: number?,
	}?,
	Rank: {
		Resolver: ((Entity: any) -> number?)?,
	}?,
}

return {}
