--!strict

--- Resolves a player by name or display name, case-insensitively, preferring an
--- exact match over a prefix one.
---
--- Kyn's own `@Players.Rin` is the *reference* form and resolves in the session.
--- This provider is the **casting** form: it turns a bare word that landed in a
--- `Player`-typed argument slot into a real Player.

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Types)

local function find(raw: string): Player?
	local query = string.lower(tostring(raw))

	if query == "" then
		return nil
	end

	local prefix: Player? = nil

	for _, player in Players:GetPlayers() do
		local name = string.lower(player.Name)
		local display = string.lower(player.DisplayName)

		if name == query or display == query then
			return player
		end

		if not prefix and (string.sub(name, 1, #query) == query or string.sub(display, 1, #query) == query) then
			prefix = player
		end
	end

	return prefix
end

local Player: Types.ArgumentTypeProvider<Player> = {
	Name = "Player",

	Validate = function(raw: string): boolean
		return find(raw) ~= nil
	end,

	Resolve = function(raw: string): Player?
		return find(raw)
	end,

	Suggest = function(prefix: string): { string }
		local query = string.lower(tostring(prefix))
		local out = {}

		for _, player in Players:GetPlayers() do
			if string.sub(string.lower(player.Name), 1, #query) == query then
				table.insert(out, player.Name)
			end
		end

		table.sort(out)

		return out
	end,
}

return Player
