--!strict

--- Local commands: everything runs on the client that typed it.
--- @section Commands

return {
	require(script.Help),
	require(script.Clear),
	require(script.Echo),
	require(script.Vars),
	require(script.Version),
	require(script.Fov),
	require(script.Fullbright),
	require(script.Ping),
	require(script.Teleport),
	require(script.Theme),
	require(script.Window),
}
