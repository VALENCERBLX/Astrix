--!strict

--- `echo <value>` — prints what it is given and returns it.
---
--- Its real use is in a pipeline: `echo` returns its argument, so it is how you
--- look at `::Kout` or feed a literal into the next stage.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Echo")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Prints a value and passes it along")
		:Aliases({ "Print" })
		:Parsed({
			{ Name = "Value", Type = "String", Required = false, Default = "" },
		})
		:Tasks({
			Local = function(context)
				local value = context.Parsed.Value

				return Astrix.Resolve.Ok(tostring(value), value)
			end,
		})
		:Register()
end
