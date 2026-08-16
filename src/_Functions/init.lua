--!strict

--- The native function manifest.
---
--- Each entry is `{ Name, Run }`. `Astrix.Native(name, fn)` adds more at
--- runtime; anything here is registered at startup and is reserved from then on.

local manifest = {
	require(script.Random),
}

local Functions = {}

--- Registers every native onto a session config's `Natives` table.
function Functions.Install(natives: { [string]: (...any) -> any })
	for _, entry in manifest do
		natives[entry.Name] = entry.Run
	end

	return natives
end

function Functions.Names(): { string }
	local names = {}

	for _, entry in manifest do
		table.insert(names, entry.Name)
	end

	return names
end

return Functions
