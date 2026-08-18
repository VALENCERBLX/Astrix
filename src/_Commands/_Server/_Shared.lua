--!strict

--- Helpers the server commands share.
---
--- Character lookups are the fiddly part of every one of these: a player may be
--- dead, loading, or between respawns, and reaching straight for
--- `Character.Humanoid` is how admin commands throw instead of reporting.
--- @section Commands

local Shared = {}

--- The player's humanoid, or nil with a reason.
function Shared.Humanoid(player: Player): (Humanoid?, string?)
	local character = player.Character

	if not character then
		return nil, `{player.Name} has no character`
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil, `{player.Name} has no humanoid`
	end

	return humanoid, nil
end

--- The player's root part, or nil with a reason.
function Shared.Root(player: Player): (BasePart?, string?)
	local character = player.Character

	if not character then
		return nil, `{player.Name} has no character`
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if not root or not root:IsA("BasePart") then
		return nil, `{player.Name} has no root part`
	end

	return root, nil
end

return Shared
