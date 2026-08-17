-- Astrix docs: build with `lune run scripts/Docket`
return {
	Title = "Astrix",
	Lead = "An in-game command console for Roblox, driven by Kyn — a bash-inspired shell language.",
	Theme = "tokyonight",
	Version = "0.1.0",
	License = "MIT",
	Sections = {
		"Overview",
		"Kyn",
		"Commands",
		"Console",
		"Themes",
		"Core",
		"Elements",
		"Patterns",
		"Support",
	},
	Repo = "https://github.com/VALENCERBLX/Astrix",

	-- vendored third-party code lives in src/ but is not Astrix's API
	Ignore = { "_Packages/" },
}
