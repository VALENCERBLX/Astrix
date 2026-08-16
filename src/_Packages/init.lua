--!strict

--- Resolves Astrix's dependencies once, so every other file asks here instead
--- of hard-coding a path.
---
--- Lume can arrive three ways depending on how the consumer installed things —
--- vendored beside this file, in a Wally `Packages` folder next to Astrix, or
--- sitting in ReplicatedStorage. Looking in all three means swapping install
--- methods is not a code change, and a missing dependency fails with a sentence
--- rather than an `attempt to index nil`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = {}

local function search(name: string): Instance?
	--// vendored under src/_Packages
	local vendored = script:FindFirstChild(name)

	if vendored then
		return vendored
	end

	--// a Wally Packages folder beside Astrix
	local astrix = script.Parent

	if astrix then
		local sibling = astrix.Parent

		if sibling then
			local packages = sibling:FindFirstChild("Packages")

			if packages and packages:FindFirstChild(name) then
				return packages:FindFirstChild(name)
			end

			if sibling:FindFirstChild(name) then
				return sibling:FindFirstChild(name)
			end
		end
	end

	--// loose in ReplicatedStorage
	local loose = ReplicatedStorage:FindFirstChild(name)

	if loose then
		return loose
	end

	local packages = ReplicatedStorage:FindFirstChild("Packages")

	if packages then
		return packages:FindFirstChild(name)
	end

	return nil
end

local cache: { [string]: any } = {}

--- Requires a dependency by name. Errors with something readable when missing.
function Packages.Get(name: string): any
	if cache[name] ~= nil then
		return cache[name]
	end

	local found = search(name)

	if not found then
		error(
			`[Astrix] could not find dependency '{name}'. Vendor it under Astrix/_Packages/{name}, `
				.. `install it with Wally beside Astrix, or put it in ReplicatedStorage.`,
			0
		)
	end

	local module = require(found :: ModuleScript)

	cache[name] = module

	return module
end

--- Lume, the UI library Astrix renders through.
function Packages.Lume(): any
	return Packages.Get("Lume")
end

return Packages
