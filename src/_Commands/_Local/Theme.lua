--!strict

--- `theme [name]` — switches the console's theme, or lists what is registered.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Theme")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Switches the console theme, or lists them")
		:Parsed({
			{
				Name = "Name",
				Type = "Enum",
				Required = false,
				Description = "a registered theme",
				--// filled in at registration from the registry, so completion
				--// offers exactly what is installed
				EnumValues = Astrix.Themes.List(),
			},
		})
		:Tasks({
			Local = function(context)
				local elements = context.Output.Elements
				local wanted = context.Parsed.Name

				if not wanted then
					local rows = {}

					for _, name in Astrix.Themes.List() do
						table.insert(rows, { name, if name == Astrix.CurrentTheme() then "active" else "" })
					end

					context.Output.Reply(elements.Table({ "Theme", "" }, rows))

					return Astrix.Resolve.Ok(nil, #rows)
				end

				local applied = Astrix.SetTheme(wanted)

				if not applied then
					return Astrix.Resolve.Fail(`no theme named "{wanted}"`)
				end

				return Astrix.Resolve.Ok(`theme set to {wanted}`, wanted)
			end,
		})
		:Register()
end
