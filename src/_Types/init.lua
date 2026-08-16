--!strict

--- The argument type providers, keyed by the `ArgumentType` they serve.
---
--- Not to be confused with `Types.lua`, which holds the module's own type
--- definitions. These are pluggable per-argument validators, casters and
--- completers; add your own by assigning into this table before `Start`.

return {
	String = require(script.String),
	Number = require(script.Number),
	Boolean = require(script.Boolean),
	Player = require(script.Player),
	Vector3 = require(script.Vector3),
	Enum = require(script.Enum),
}
