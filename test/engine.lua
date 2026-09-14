-- Loads the translation engine and its dictionary in manifest order, outside the game.
-- The engine touches no client API, so no stubs are needed for it.
--
--   lua test/engine.lua "text to translate" ...   (from the add-on folder)

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
local DIR = HERE .. "/.."

ENGINE_FILES = {
	"Text.lua",
	"Conjugate.lua",
	"Lexicon.lua",
	"Tokenizer.lua",
	"Grammar.lua",
	"dict/Core.lua",
	"dict/Nouns.lua",
	"dict/Adjectives.lua",
	"dict/Verbs.lua",
	"dict/Expressions.lua",
	"dict/ESO.lua",
	"dict/Cyrodiil.lua",
	"dict/Irregular.lua",
}

function LoadEngine()
	for _, file in ipairs(ENGINE_FILES) do
		local f = io.open(DIR .. "/" .. file)
		if f then
			f:close()
			dofile(DIR .. "/" .. file)
		end
	end
	return PBsTranslate
end

if arg and arg[0] and arg[0]:match("engine%.lua$") then
	local T = LoadEngine()
	T.SetCyrodiilPriority(os.getenv("CYRODIIL") == "1")
	for _, text in ipairs(arg) do
		local ja, stats = T.Translate(text)
		print(string.format("%-40s -> %s  (%d/%d)", text, ja, stats.known, stats.unknown))
	end
end
