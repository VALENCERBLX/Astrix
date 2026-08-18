--!strict

--- `announce <message>` — a notice on every player's screen.
---
--- Shown to **everyone**, not just people who could have run it. That is what
--- separates an announcement from a command result: the audience is the whole
--- server, and almost none of them will have the rank to produce one.
---
--- It also goes to the chat channel, so it survives in scrollback after the
--- toast has faded.
--- @section Commands

return function(Astrix: any)
	local TextChatService = game:GetService("TextChatService")

	Astrix.Define("Announce")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Shows a notice to everyone in the server")
		:Aliases({ "Say", "Broadcast", "A" })
		:Parsed({
			{ Name = "Message", Type = "String", Required = true },
		})
		:Flags({
			{ Name = "Duration", Extended = "IsValue", Type = "Number", Default = 6 },
			{ Name = "Tone", Extended = "IsValue", Type = "String", Default = "Announce" },
			{ Name = "Quiet", Extended = "IsBool", Description = "skip the chat copy" },
		})
		:Cooldown(3)
		:Tasks({
			Server = function(context)
				local message = context.Parsed.Message

				if message == "" then
					return Astrix.Resolve.Fail("nothing to announce")
				end

				--// the toast: everybody, no rank check
				Astrix.Notify(message, context.Flags.Tone, context.Flags.Duration)

				--// and a chat copy, so it is still there once the toast has
				--// gone. Wrapped because a place can remove the default channel
				if not context.Flags.Quiet then
					pcall(function()
						local channels = TextChatService:FindFirstChild("TextChannels")
						local general = channels and channels:FindFirstChild("RBXGeneral")

						if general and general:IsA("TextChannel") then
							general:DisplaySystemMessage(`[Announce] {message}`)
						end
					end)
				end

				return Astrix.Resolve.Ok(`announced to {#game:GetService("Players"):GetPlayers()}`, message)
			end,
		})
		:Register()
end
