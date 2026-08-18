--!strict

--- `announce <message>` — a system message to everybody in the server.
--- @section Commands

return function(Astrix: any)
	local TextChatService = game:GetService("TextChatService")

	Astrix.Define("Announce")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Sends a message to everyone")
		:Aliases({ "Say", "Broadcast" })
		:Parsed({
			{ Name = "Message", Type = "String", Required = true },
		})
		:Cooldown(3)
		:Tasks({
			Server = function(context)
				local message = context.Parsed.Message

				local channels = TextChatService:FindFirstChild("TextChannels")
				local general = channels and channels:FindFirstChild("RBXGeneral")

				if general and general:IsA("TextChannel") then
					general:DisplaySystemMessage(message)
				end

				return Astrix.Resolve.Ok(`announced: {message}`, message)
			end,
		})
		:Register()
end
