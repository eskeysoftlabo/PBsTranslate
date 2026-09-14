-- PB's TranslateTest -- the dictionary
--
-- An add-on cannot reach a server, so every word it can translate ships inside it. The word
-- lists live in dict/*.lua as plain "english=japanese" lines, one block per part of speech,
-- because that is the form that is easy to read, extend and diff. They are turned into
-- entries once, while the files load.
--
--   D("n", [[
--   sword=剣
--   world boss=ワールドボス          -- several words are fine; the longest match wins
--   ]])
--
--   D("v", [[
--   go=行く/5/に                     -- japanese / verb class / object particle
--   ]])
--
-- Parts of speech the grammar understands:
--
--   n    noun                  pn   pronoun             v    verb
--   a    adjective (/i, /na)   adv  adverb              x    fixed expression
--   prep preposition (/particle placement, see Grammar.lua)
--   det  determiner            conj conjunction         wh   question word
--
-- An x entry is translated as a whole and stands on its own: "thank you", "lfg", "gg".
--
-- A word not in the lists is looked up again with its inflection taken off -- plural -s,
-- past -ed, -ing, comparative -er -- and the inflection is handed to the grammar. Irregular
-- forms (went, children, better) come from the table in dict/Irregular.lua.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

T.lexicon = T.lexicon or {}
T.cyrodiilLexicon = T.cyrodiilLexicon or {}
T.cyrodiilPriority = T.cyrodiilPriority or false
T.irregular = T.irregular or {}
T.maxPhraseWords = T.maxPhraseWords or 1
T.entryCount = T.entryCount or 0

local lexicon = T.lexicon

local function Trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- One "english=japanese/field/field" line into an entry. Returns key, entry or nil.
local function ParseLine(pos, line)
	line = Trim((line:gsub("%-%-.*$", "")))
	if line == "" then
		return nil
	end
	local english, rest = line:match("^(.-)%s*=%s*(.+)$")
	if not english or english == "" then
		return nil
	end
	local fields = {}
	for field in (rest .. "/"):gmatch("(.-)/") do
		fields[#fields + 1] = Trim(field)
	end
	local entry = { pos = pos, ja = fields[1] }
	if pos == "v" then
		entry.class = fields[2] ~= "" and fields[2] or "5"
		entry.particle = fields[3] ~= "" and fields[3] or nil
	elseif pos == "a" then
		entry.class = fields[2] == "na" and "na" or "i"
		-- A "na" entry that is really a verb form or a noun with の (乾いた, できる, 魔法の)
		-- neither takes な in front of a noun nor です after it; see T.Copula.
		local last = entry.ja:sub(-3)
		if entry.class == "na" and (last == "た" or last == "る" or last == "の" or last == "な") then
			entry.class = "rel"
		end
	elseif pos == "prep" then
		entry.place = fields[2] ~= "" and fields[2] or "after"
	elseif (pos == "n" or pos == "adv") and fields[2] == "place" then
		entry.place = true
	elseif pos == "n" and fields[2] == "time" then
		entry.time = true
	elseif pos == "n" and fields[2] == "unit" then
		-- a unit stays after its number: 80パーセント, not パーセント×80
		entry.unit = true
	end
	-- join=の: the particle put between this noun and a noun right before it
	-- ("drake fd" -> ドレイクロー砦の正門, "bleaks ua" -> 侵入者の基地に奇襲)
	if pos == "n" then
		for index = 2, #fields do
			local join = fields[index]:match("^join=(.+)$")
			if join then
				entry.join = join
			elseif fields[index]:match("^then=") then
				-- the particle put after this noun when another noun follows ("ad zerg" -> ドミニオンの大集団)
				entry["then"] = fields[index]:match("^then=(.+)$")
			elseif fields[index] == "end" then
				-- ends its noun phrase: "ball group inc bd" -- bd is where, not whose
				entry.ends = true
			end
		end
	end
	return english:lower():gsub("%s+", " "), entry
end

-- A word defined under two parts of speech keeps both: the later one is the default and the
-- earlier ones hang off it in alts, for the grammar to pick when the context says so ("I need
-- help" is the noun, "help me" is the verb).
local function Add(key, entry, dictionary)
	local existing = dictionary[key] or lexicon[key]
	if not lexicon[key] and not T.cyrodiilLexicon[key] then
		T.entryCount = T.entryCount + 1
	end
	if existing then
		-- Never mutate a shared entry: normal meanings must survive PvP overrides.
		local alts = {}
		for pos, alternative in pairs(existing.alts or {}) do
			if pos ~= entry.pos then alts[pos] = alternative end
		end
		if existing.pos ~= entry.pos then
			local alternative = {}
			for k, v in pairs(existing) do
				if k ~= "alts" then alternative[k] = v end
			end
			alts[existing.pos] = alternative
		end
		if next(alts) then entry.alts = alts end
	end
	dictionary[key] = entry
	local words = 1
	for _ in key:gmatch(" ") do
		words = words + 1
	end
	if words > T.maxPhraseWords then
		T.maxPhraseWords = words
	end
end

-- Later definitions of the same word replace earlier ones, so a file loaded later in the
-- manifest (the ESO terms) can override a general meaning ("tank" is not a water tank).
local function DefineInto(dictionary, pos, block)
	for line in (block .. "\n"):gmatch("(.-)\r?\n") do
		local key, entry = ParseLine(pos, line)
		if key and entry.ja and entry.ja ~= "" then
			Add(key, entry, dictionary)
		end
	end
end

function T.Define(pos, block)
	DefineInto(lexicon, pos, block)
end

function T.DefineCyrodiil(pos, block)
	DefineInto(T.cyrodiilLexicon, pos, block)
end

function T.SetCyrodiilPriority(enabled)
	T.cyrodiilPriority = enabled == true
end

-- english = "base inflection", e.g. went = "go past".
function T.DefineIrregular(block)
	for line in (block .. "\n"):gmatch("(.-)\r?\n") do
		line = Trim((line:gsub("%-%-.*$", "")))
		local form, base, inflection = line:match("^(%S+)%s*=%s*(%S+)%s+(%S+)$")
		if form then
			T.irregular[form:lower()] = { base = base:lower(), inflection = inflection }
		end
	end
end

-- The player's own words, from saved variables. Kept apart from the shipped table so that
-- removing one gives the shipped meaning back.
T.userLexicon = T.userLexicon or {}

function T.SetUserEntries(entries)
	T.userLexicon = {}
	for english, value in pairs(entries or {}) do
		if type(english) == "string" and type(value) == "string" then
			local pos, rest = value:match("^(%a+):(.+)$")
			if not pos then
				pos, rest = "x", value
			end
			local key, entry = ParseLine(pos, english .. "=" .. rest)
			if key then
				T.userLexicon[key] = entry
				local words = select(2, key:gsub(" ", " ")) + 1
				if words > T.maxPhraseWords then
					T.maxPhraseWords = words
				end
			end
		end
	end
end

local function Exact(key)
	if T.userLexicon[key] then return T.userLexicon[key] end
	if T.cyrodiilPriority then
		return T.cyrodiilLexicon[key] or lexicon[key]
	end
	return lexicon[key] or T.cyrodiilLexicon[key]
end

T.Exact = Exact

-- The entry as the given part of speech, or nil.
function T.As(entry, pos)
	if not entry then
		return nil
	end
	if entry.pos == pos then
		return entry
	end
	return entry.alts and entry.alts[pos] or nil
end

-- Which parts of speech each suffix may come off. "sings" is a verb, "swords" a noun; "ed"
-- never makes a noun.
local SUFFIX_RULES = {
	{ "ies", { "y" }, { n = "plural", v = "third" } },
	{ "ves", { "f", "fe" }, { n = "plural" } },
	{ "es", { "", "e" }, { n = "plural", v = "third" } },
	{ "s", { "" }, { n = "plural", v = "third", x = "plural" } },
	{ "ied", { "y" }, { v = "past" } },
	{ "ed", { "", "e", "double" }, { v = "past" } },
	{ "ying", { "ie" }, { v = "ing" } },
	{ "ing", { "", "e", "double" }, { v = "ing" } },
	{ "iest", { "y" }, { a = "superlative" } },
	{ "est", { "", "e", "double" }, { a = "superlative" } },
	{ "ier", { "y" }, { a = "comparative" } },
	{ "er", { "", "e", "double" }, { a = "comparative" } },
	{ "ily", { "y" }, { a = "adverb" } },
	{ "ly", { "", "le" }, { a = "adverb" } },
}

local function Candidates(word, suffix, endings)
	local stem = word:sub(1, #word - #suffix)
	if #stem < 2 then
		return {}
	end
	local out = {}
	for _, ending in ipairs(endings) do
		if ending == "double" then
			local last = stem:sub(-1)
			if #stem >= 3 and stem:sub(-2, -2) == last then
				out[#out + 1] = stem:sub(1, -2)
			end
		else
			out[#out + 1] = stem .. ending
		end
	end
	return out
end

-- Look a single lower-case word up. Returns entry, inflection (or nil), base word.
-- skipExact looks past an exact entry to the inflected reading ("understood" the expression
-- -> "understand" past).
function T.Lookup(word, skipExact)
	local entry = not skipExact and Exact(word)
	if entry then
		return entry, nil, word
	end

	local irregular = T.irregular[word]
	if irregular then
		entry = Exact(irregular.base)
		if entry then
			return entry, irregular.inflection, irregular.base
		end
	end

	for _, rule in ipairs(SUFFIX_RULES) do
		local suffix, endings, allowed = rule[1], rule[2], rule[3]
		if #word > #suffix and word:sub(-#suffix) == suffix then
			for _, base in ipairs(Candidates(word, suffix, endings)) do
				local found = Exact(base)
				if found and allowed[found.pos] then
					return found, allowed[found.pos], base
				end
				if found and found.alts then
					for pos, inflection in pairs(allowed) do
						if found.alts[pos] then
							return found.alts[pos], inflection, base
						end
					end
				end
			end
		end
	end

	return nil
end
