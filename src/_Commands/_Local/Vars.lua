--!strict

--- `vars` — what the Kyn session is currently holding.
---
--- Variables from `@Set`, functions from `@Function`, and the `::Kout` stack,
--- which is otherwise invisible.
--- @section Commands

return function(Astrix: any)
	Astrix.Define("Vars")
		:Type("Local")
		:Rank(Astrix.Enums.Rank.Player.Min)
		:Describe("Lists Kyn variables, functions and the result stack")
		:Aliases({ "Session" })
		:Tasks({
			Local = function(context)
				local session = Astrix.Session()
				local elements = context.Output.Elements

				if not session then
					return Astrix.Resolve.Fail("no session")
				end

				local rows = {}

				for _, name in session:VariableNames() do
					rows[#rows + 1] = { "variable", name, tostring(session.Variables[name]) }
				end

				for _, name in session:FunctionNames() do
					rows[#rows + 1] = { "function", name, "" }
				end

				for index = 1, math.min(#session.Stack, 5) do
					rows[#rows + 1] = { "::Kout", `({index - 1})`, tostring(session.Stack[index]) }
				end

				if #rows == 0 then
					return Astrix.Resolve.Ok("the session is empty", 0)
				end

				context.Output.Reply(elements.Table({ "Kind", "Name", "Value" }, rows))

				return Astrix.Resolve.Ok(nil, #rows)
			end,
		})
		:Register()
end
