--!strict

--- Server commands: the client sends resolved values, the server does the work
--- and returns a resolve.
--- @section Commands

return {
	require(script.Kill),
	require(script.Heal),
	require(script.Respawn),
	require(script.God),
	require(script.Speed),
	require(script.Jump),
	require(script.Bring),
	require(script.Goto),
	require(script.Kick),
	require(script.Announce),
	require(script.Time),
	require(script.Gravity),
	require(script.Rank),
}
