-- Astrix docs: build with `lune run scripts/Docket`
return {
	Title = "Astrix",
	Lead = "An in-game command console for Roblox, driven by Kyn — a bash-inspired shell language.",
	Theme = "tokyonight",
	Version = "0.1.0",
	License = "MIT",
	Sections = {
		"Guides",
		"Overview",
		"Kyn",
		"Commands",
		"Console",
		"Themes",
		"Arguments",
		"Patterns",
		"Runtime",
	},

	Pages = {
		{ file = "pages/GettingStarted.md", section = "Guides" },
		{ file = "pages/Kyn.md", section = "Guides" },
		{ file = "pages/Commands.md", section = "Guides" },
		{ file = "pages/Configuration.md", section = "Guides" },
		{ file = "pages/Windows.md", section = "Guides" },
	},
	Repo = "https://github.com/VALENCERBLX/Astrix",

	-- vendored third-party code lives in src/ but is not Astrix's API
	Ignore = { "_Packages/" },
}
