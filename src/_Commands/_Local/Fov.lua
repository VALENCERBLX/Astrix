--!strict

--- `fov [amount]` — the camera's field of view.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Fov")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Sets the camera field of view")
		:Aliases({ "Zoom" })
		:Parsed({
			{ Name = "Amount", Type = "Number", Required = false, Default = 70 },
		})
		:Tasks({
			Local = function(context)
				local camera = workspace.CurrentCamera

				if not camera then
					return Astrix.Resolve.Fail("no camera")
				end

				camera.FieldOfView = math.clamp(context.Parsed.Amount, 1, 120)

				return Astrix.Resolve.Ok(`fov {camera.FieldOfView}`, camera.FieldOfView)
			end,
		})
		:Register()
end
