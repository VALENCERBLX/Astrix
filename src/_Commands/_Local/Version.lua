--!strict

--- `version` — what is installed.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Version")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Shows the Astrix version")
		:Aliases({ "About" })
		:Tasks({
			Local = function(context)
				local elements = context.Output.Elements

				context.Output.Reply(elements.Table({ "", "" }, {
					{ "Astrix", Astrix.Version },
					{ "Language", "Kyn" },
					{ "Theme", Astrix.CurrentTheme() },
					{ "Commands", tostring(#Astrix.Registry:List()) },
				}))

				return Astrix.Resolve.Ok(nil, Astrix.Version)
			end,
		})
		:Register()
end
