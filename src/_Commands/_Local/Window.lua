--!strict

--- `window <action> [id]` — opens, closes and lists console windows.
---
--- Konsole had exactly two: the main console and a detached chat pill. Astrix
--- takes as many as the cap allows, which is three unless you raise it.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Window")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Opens, closes or lists console windows")
		:Aliases({ "Win", "W" })
		:Parsed({
			{
				Name = "Action",
				Type = "Enum",
				Required = false,
				Default = "List",
				Description = "list, open or close",
				EnumValues = { "List", "Open", "Close" },
			},
			{ Name = "Id", Type = "String", Required = false, Description = "which window" },
		})
		:Flags({
			{ Name = "Max", Extended = "IsValue", Type = "Number", Description = "set the window cap" },
		})
		:Tasks({
			Local = function(context)
				local elements = context.Output.Elements
				local windows = context.Windows

				if context.Flags.Max then
					Astrix.SetMaxWindows(context.Flags.Max)

					return Astrix.Resolve.Ok(`window cap set to {context.Flags.Max}`, context.Flags.Max)
				end

				local action = string.lower(context.Parsed.Action or "List")
				local id = context.Parsed.Id

				if action == "open" then
					if not id then
						return Astrix.Resolve.Fail("open needs an id")
					end

					windows.Open({ Id = id, Title = id, Docked = true })

					return Astrix.Resolve.Ok(`opened {id}`, id)
				end

				if action == "close" then
					if not id then
						return Astrix.Resolve.Fail("close needs an id")
					end

					windows.Close(id)

					return Astrix.Resolve.Ok(`closed {id}`, id)
				end

				local rows = {}

				for index, name in windows.List() do
					table.insert(rows, { tostring(index), name })
				end

				context.Output.Reply(elements.Table({ "#", "Window" }, rows))

				return Astrix.Resolve.Ok(nil, #rows)
			end,
		})
		:Register()
end
