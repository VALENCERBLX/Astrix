--- Refreshes the vendored copies under `src/_Packages`.
---
--- Astrix ships self-contained, which means every dependency is a *copy*.
--- Editing the upstream package does nothing until this is run — a stale
--- vendored copy is the failure mode this script exists to prevent.
---
--- Run with `lune run scripts/vendor`.

local fs = require("@lune/fs")
local process = require("@lune/process")

local SOURCES = {
	{ Name = "Lume", From = "../Lume/src" },
	{ Name = "Switch", From = "../BOLD/src/_Packages/Switch" },
	{ Name = "Substance", From = "../BOLD/src/_Packages/Substance" },
}

local function count(dir: string): number
	local total = 0

	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`

		if fs.isDir(full) then
			total += count(full)
		else
			total += 1
		end
	end

	return total
end

for _, source in SOURCES do
	local target = `src/_Packages/{source.Name}`

	if not fs.isDir(source.From) then
		print(`skip {source.Name}: {source.From} is not there`)
		continue
	end

	if fs.isDir(target) then
		fs.removeDir(target)
	end

	fs.copy(source.From, target)

	print(`vendored {source.Name} ({count(target)} files)`)
end

print("\nremember to rebuild the installer: lune run scripts/build-installer")
