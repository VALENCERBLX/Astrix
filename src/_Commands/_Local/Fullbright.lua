--!strict

--- `fullbright [on]` — flattens local lighting so nothing is in shadow.
---
--- Client-only: it changes what you see, not what anybody else does.
--- @section Commands

return function(Astrix: any)
	local Lighting = game:GetService("Lighting")

	local saved: { [string]: any }? = nil

	Astrix.Define("Fullbright")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Removes local shadows and ambient darkness")
		:Aliases({ "FB" })
		:Parsed({
			{ Name = "On", Type = "Boolean", Required = false },
		})
		:Tasks({
			Local = function(context)
				local wanted = context.Parsed.On

				if wanted == nil then
					wanted = saved == nil
				end

				if wanted then
					--// remembered so it can be put back exactly, rather than
					--// reset to whatever the defaults happen to be
					saved = saved
						or {
							Ambient = Lighting.Ambient,
							OutdoorAmbient = Lighting.OutdoorAmbient,
							Brightness = Lighting.Brightness,
							GlobalShadows = Lighting.GlobalShadows,
							FogEnd = Lighting.FogEnd,
						}

					Lighting.Ambient = Color3.fromRGB(178, 178, 178)
					Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
					Lighting.Brightness = 2
					Lighting.GlobalShadows = false
					Lighting.FogEnd = 1e6

					return Astrix.Resolve.Ok("fullbright on", true)
				end

				for key, value in saved or {} do
					(Lighting :: any)[key] = value
				end

				saved = nil

				return Astrix.Resolve.Ok("fullbright off", false)
			end,
		})
		:Register()
end
