--!strict

--- Astrix's enumerations.
---
--- **The rank bands below are placeholders.** They were never confirmed in
--- design and are flagged as open item #2 in the specification. `Player 0-99`,
--- `Admin 100-199`, `Owner 200` is a guess that reads sensibly; confirm the
--- real numbers before shipping, because changing them later silently changes
--- who can run what.

local Enums = {}

Enums.Rank = {
	Player = { Min = 0, Max = 99 },
	Admin = { Min = 100, Max = 199 },
	Owner = { Min = 200, Max = 200 },
}

Enums.CommandType = {
	Local = "Local" :: "Local",
	Server = "Server" :: "Server",
	Service = "Service" :: "Service",
}

Enums.FlagKind = {
	IsValue = "IsValue" :: "IsValue",
	IsBool = "IsBool" :: "IsBool",
}

Enums.ArgumentType = {
	String = "String" :: "String",
	Number = "Number" :: "Number",
	Boolean = "Boolean" :: "Boolean",
	Player = "Player" :: "Player",
	Vector3 = "Vector3" :: "Vector3",
	Enum = "Enum" :: "Enum",
}

Enums.Resolve = {
	Ok = "Ok" :: "Ok",
	Fail = "Fail" :: "Fail",
	Warn = "Warn" :: "Warn",
	CommandNotFound = "CommandNotFound" :: "CommandNotFound",
	RankDenied = "RankDenied" :: "RankDenied",
	OnCooldown = "OnCooldown" :: "OnCooldown",
	ParseFailed = "ParseFailed" :: "ParseFailed",
	AbsoluteOverwrite = "AbsoluteOverwrite" :: "AbsoluteOverwrite",
}

Enums.HistoryKind = {
	Input = "Input" :: "Input",
	Output = "Output" :: "Output",
	Ok = "Ok" :: "Ok",
	Fail = "Fail" :: "Fail",
	Warn = "Warn" :: "Warn",
}

return table.freeze(Enums)
