--!strict

--- `ping` — your network round trip, in milliseconds.
---
--- Reads `Player:GetNetworkPing()` rather than timing a remote by hand. An
--- earlier version tried to measure the round trip itself, which does not
--- work through the dispatcher: the client task runs, the server task runs,
--- and only the server's resolve comes back — there is no second client step
--- to stop the clock in.
--- @section Commands

return function(Astrix: any)
	local Players = game:GetService("Players")

	Astrix.Define("Ping")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Shows your network round trip")
		:Tasks({
			Local = function()
				local player = Players.LocalPlayer

				if not player then
					return Astrix.Resolve.Fail("no local player")
				end

				local milliseconds = math.round(player:GetNetworkPing() * 2000)

				return Astrix.Resolve.Ok(`{milliseconds}ms`, milliseconds)
			end,
		})
		:Register()
end
