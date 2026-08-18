--!strict

--- `notify <player> <message>` — a notice to one person.
---
--- The single-target twin of `announce`. Useful for warning somebody before
--- kicking them, which is politer than the alternative.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Notify")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Shows a notice to one player")
		:Aliases({ "Tell", "PM" })
		:Parsed({
			{ Name = "Target", Type = "Player", Required = true },
			{ Name = "Message", Type = "String", Required = true },
		})
		:Flags({
			{ Name = "Duration", Extended = "IsValue", Type = "Number", Default = 6 },
			{ Name = "Tone", Extended = "IsValue", Type = "String", Default = "Info" },
		})
		:Tasks({
			Server = function(context)
				local target = context.Parsed.Target :: Player

				Astrix.Notify(context.Parsed.Message, context.Flags.Tone, context.Flags.Duration, target)

				return Astrix.Resolve.Ok(`notified {target.Name}`, target.Name)
			end,
		})
		:Register()
end
