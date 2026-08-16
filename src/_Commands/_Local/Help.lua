--!strict

--- `help [command]` — every command you can run, or one in detail.
---
--- The list is filtered by rank, so it never advertises something the caller
--- would immediately be refused.

return function(Astrix: any)
	Astrix.Define("Help")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Lists commands, or explains one")
		:Aliases({ "Commands", "Cmds", "?" })
		:Parsed({
			{ Name = "Command", Type = "String", Required = false, Description = "a command to explain" },
		})
		:Tasks({
			Local = function(context)
				local registry = Astrix.Registry
				local elements = context.Output.Elements
				local wanted = context.Parsed.Command

				if wanted then
					local definition = registry:Resolve(wanted)

					if not definition then
						return Astrix.Resolve.CommandNotFound(wanted)
					end

					local rows = {}

					for _, argument in definition.Parsed do
						table.insert(rows, {
							argument.Name,
							argument.Type,
							if argument.Required then "required" else "optional",
							argument.Description or "",
						})
					end

					context.Output.Reply(elements.Text(`{definition.Name} — {definition.Description or "no description"}`))

					if #rows > 0 then
						context.Output.Reply(elements.Table({ "Argument", "Type", "Need", "Description" }, rows))
					end

					return Astrix.Resolve.Ok()
				end

				local rank = Astrix.GetRank(context.Executor)
				local rows = {}

				for _, definition in registry:List() do
					if definition.Rank <= rank then
						table.insert(rows, {
							definition.Name,
							tostring(definition.Rank),
							definition.Description or "",
						})
					end
				end

				context.Output.Reply(elements.Table({ "Command", "Rank", "Description" }, rows))

				return Astrix.Resolve.Ok(nil, #rows)
			end,
		})
		:Register()
end
