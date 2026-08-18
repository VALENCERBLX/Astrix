--!strict

--- `window <sub> [args]` — opens, closes and lists console windows.
---
--- Written with real sub-commands rather than an Enum argument, so each one
--- declares its own arguments and completes them: `window open <id>` offers
--- nothing for `id`, while `window close <id>` could offer the open ones.
---
--- Konsole had exactly two windows. Astrix takes as many as the cap allows,
--- which is three unless you raise it.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Window")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Opens, closes or lists console windows")
		:Aliases({ "Win", "W" })
		:Subs({
			Astrix.Sub("Open")
				:Describe("Opens a window")
				:Parsed({
					{ Name = "Id", Type = "String", Required = true, Description = "a name for it" },
				})
				:Tasks({
					Local = function(context)
						local id = context.Parsed.Id

						context.Windows.Open({ Id = id, Title = id, Docked = true })

						return Astrix.Resolve.Ok(`opened {id}`, id)
					end,
				}),

			Astrix.Sub("Close")
				:Describe("Closes a window")
				:Parsed({
					{ Name = "Id", Type = "String", Required = true },
				})
				:Tasks({
					Local = function(context)
						local id = context.Parsed.Id

						context.Windows.Close(id)

						return Astrix.Resolve.Ok(`closed {id}`, id)
					end,
				}),

			Astrix.Sub("Max")
				:Describe("Sets how many windows may exist at once")
				:Parsed({
					{ Name = "Count", Type = "Number", Required = true },
				})
				:Tasks({
					Local = function(context)
						Astrix.SetMaxWindows(context.Parsed.Count)

						return Astrix.Resolve.Ok(`window cap {context.Parsed.Count}`, context.Parsed.Count)
					end,
				}),

			Astrix.Sub("List")
				:Describe("Lists the open windows")
				:Tasks({
					Local = function(context)
						local elements = context.Output.Elements
						local focused = context.Windows.Focused()
						local rows = {}

						for index, name in context.Windows.List() do
							rows[#rows + 1] = { tostring(index), name, if name == focused then "focused" else "" }
						end

						context.Output.Reply(elements.Table({ "#", "Window", "" }, rows))

						return Astrix.Resolve.Ok(nil, #rows)
					end,
				}),
		})
		--// no sub given: list them, which is the useful default
		:Tasks({
			Local = function(context)
				local elements = context.Output.Elements
				local focused = context.Windows.Focused()
				local rows = {}

				for index, name in context.Windows.List() do
					rows[#rows + 1] = { tostring(index), name, if name == focused then "focused" else "" }
				end

				context.Output.Reply(elements.Table({ "#", "Window", "" }, rows))

				return Astrix.Resolve.Ok(nil, #rows)
			end,
		})
		:Register()
end
