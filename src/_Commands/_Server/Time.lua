--!strict

--- `time [hour]` — the clock time of day, for everybody.
--- @section Commands

return function(Astrix: any)
	local Lighting = game:GetService("Lighting")

	Astrix.Define("Time")
		:Type("Server")
		:Rank(Astrix.Enums.Rank.Admin.Min)
		:Describe("Sets the time of day")
		:Parsed({
			{ Name = "Hour", Type = "Number", Required = false },
		})
		:Tasks({
			Server = function(context)
				local hour = context.Parsed.Hour

				if not hour then
					return Astrix.Resolve.Ok(Lighting.TimeOfDay, Lighting.ClockTime)
				end

				Lighting.ClockTime = math.clamp(hour, 0, 24) % 24

				return Astrix.Resolve.Ok(`time {Lighting.TimeOfDay}`, Lighting.ClockTime)
			end,
		})
		:Register()
end
