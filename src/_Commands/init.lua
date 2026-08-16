--!strict

--- Built-in command manifest, grouped by execution type.
---
--- Each entry is a function taking the Astrix module, so a command file never
--- has to require the library it is being registered into.

local groups = {
	require(script._Local),
	require(script._Server),
	require(script._Service),
}

local Commands = {}

function Commands.Register(Astrix: any)
	for _, group in groups do
		for _, define in group do
			define(Astrix)
		end
	end
end

return Commands
