--!strict

--- Shared module types for Astrix.
---
--- Not to be confused with `_Types/`, which holds pluggable per-argument
--- providers (validation, casting, completion for a `Player` or a `Vector3`).
--- Similar-looking name, completely different concept.
--- @section Overview

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

	--// only meaningful for `Type = "Enum"`. Without it there is nothing to
	--// validate against, which is why the Enum provider used to never run
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

	--// sub-commands, keyed by lowercase name and alias. A definition with
	--// these dispatches on its first positional word before binding anything
	Subs: { [string]: CommandDefinition }?,
	SubOrder: { string }?,
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
	Subs: { [string]: ReplicatedDefinition }?,
	SubOrder: { string }?,
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
	Anchor: Anchor?,
	Position: UDim2?,
	Width: number?,
	Theme: any?,
}

--// options --------------------------------------------------------------------
--- Everything `Astrix.Start` accepts. All of it optional; the defaults are the
--- console's own numbers.
export type AstrixOptions = {
	Interface: {
		--- A registered theme name. `Default` or `Tokyonight` ship.
		Theme: string?,
		--- The activation key. Pick one you do not need to type — it is watched
		--- while the console has focus so it can cycle windows.
		Keybind: Enum.KeyCode?,
		--- Below this rank the console will not open at all, whatever the
		--- individual command ranks say.
		InterfaceRank: number?,
		--- How long a run of activation presses counts as one cycle. Zero
		--- switches cycling off.
		CycleTimeout: number?,
		--- How many console windows may exist at once.
		MaxWindows: number?,
		--- The greyed text in an empty input.
		Placeholder: string?,
		--- The glyph before the caret.
		Prompt: string?,
		--- Where the console sits. `bottom` by default.
		Anchor: Anchor?,
		--- ScreenGui DisplayOrder, if something of yours has to sit above it.
		DisplayOrder: number?,
		--- Scrollback per window, in lines.
		HistoryLimit: number?,
		--- How many submitted lines the up-arrow remembers.
		RecallLimit: number?,
		--- Whether the console starts visible.
		StartOpen: boolean?,
	}?,

	Suggestions: {
		--- Turn completion off entirely.
		Enabled: boolean?,
		--- How many matches the dropdown shows.
		Limit: number?,
	}?,

	Toast: {
		--- Turn notices off entirely.
		Enabled: boolean?,
		--- Which corner they stack in.
		Anchor: Anchor?,
		--- Seconds before one fades, unless a caller overrides it.
		Duration: number?,
		--- How many are on screen before the oldest is pushed off.
		Max: number?,
		Gap: number?,
		Width: number?,
	}?,

	Kyn: {
		--- How many results `::Kout` remembers.
		StackLimit: number?,
		--- How deep `@Function` recursion may go before it fails.
		MaxDepth: number?,
	}?,

	Rank: {
		--- Answer from wherever you keep ranks. Return nil to fall through.
		Resolver: ((Entity: any) -> number?)?,
		--- What an unknown player gets.
		Default: number?,
		--- Whether the place creator is Owner automatically. On by default so a
		--- solo developer is not locked out of their own console.
		OwnerIsCreator: boolean?,
	}?,

	Commands: {
		--- Register the built-in command set. On by default.
		Builtins: boolean?,
	}?,
}

return {}
