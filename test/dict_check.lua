-- Dictionary lint for PB's TranslateTest.
--
--   lua test/dict_check.lua          (from the add-on folder)
--
-- A dictionary line is typed by hand, and the grammar trusts it: a verb marked ichidan that is
-- really godan conjugates into nonsense (帰ます), an i-adjective without its い loses its
-- ending, and a key with a stray character is never matched. None of that fails a sentence
-- test unless that exact word happens to be in one. This walks every entry instead:
--
--   errors    (exit 1)  class and ending disagree, empty or invalid Japanese, a predicate
--                       that cannot be built, a key that can never match
--   warnings  (listed)  shapes that are usually wrong but have real exceptions
--                       (godan verbs ending in e-row + る such as 帰る, 走る, 入る)

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
dofile(HERE .. "/engine.lua")
local T = LoadEngine()

local errors, warnings = {}, {}
local function Err(where, text) errors[#errors + 1] = where .. ": " .. text end
local function Warn(where, text) warnings[#warnings + 1] = where .. ": " .. text end

local U_ROW = { ["う"] = true, ["く"] = true, ["ぐ"] = true, ["す"] = true, ["つ"] = true, ["ぬ"] = true, ["ぶ"] = true, ["む"] = true, ["る"] = true }
local E_I_ROW = {}
for kana in ("いきぎしじちぢにひびぴみりえけげせぜてでねへべぺめれ"):gmatch("[\227-\239][\128-\191][\128-\191]") do
	E_I_ROW[kana] = true
end

local function Last(text, n)
	-- the n-th kana from the end (kana are three bytes)
	n = n or 1
	if #text < 3 * n then
		return ""
	end
	return text:sub(#text - 3 * n + 1, #text - 3 * (n - 1))
end

local MODES = { false, "progressive", "want", "can", "request", "imperative", "lets", "must", "should",
	"need", "try", "intend", "maybe", "likes", "passive" }

local function CheckPredicates(where, entry)
	for _, mode in ipairs(MODES) do
		for _, past in ipairs({ false, true }) do
			for _, negative in ipairs({ false, true }) do
				for _, plain in ipairs({ false, true }) do
					local form = { mode = mode or nil, past = past, negative = negative, plain = plain }
					local ok, result = pcall(T.Predicate, entry, form)
					if not ok then
						Err(where, "Predicate failed (" .. tostring(mode) .. "): " .. tostring(result))
						return
					end
					if type(result) ~= "string" or result == "" or not T.IsValidUTF8(result) then
						Err(where, "Predicate gave bad text for " .. tostring(mode))
						return
					end
					if result:find("るます", 1, true) or result:find("るませ", 1, true) or result:find("るたい", 1, true) then
						Err(where, "conjugation left the dictionary る in: " .. result)
						return
					end
				end
			end
		end
	end
end

local KEY_PATTERN = "^[a-z0-9][a-z0-9 '%+/%-]*$"

local function CheckEntry(dictionary, key, entry)
	local where = string.format("%s %s [%s]", dictionary, key, entry.pos)
	local ja = entry.ja
	if type(ja) ~= "string" or ja == "" then
		Err(where, "empty Japanese")
		return
	end
	if not T.IsValidUTF8(ja) then
		Err(where, "Japanese is not valid UTF-8")
		return
	end
	if not key:match(KEY_PATTERN) then
		Warn(where, "unusual key characters")
	end
	if key ~= T.Lower(key) then
		Err(where, "key is not lower case and can never match")
	end

	if entry.pos == "v" then
		local class = entry.class
		if class == "1" then
			if Last(ja) ~= "る" then
				Err(where, "ichidan verb must end in る: " .. ja)
			elseif Last(ja, 2) ~= "" and not E_I_ROW[Last(ja, 2)] and Last(ja, 2):byte() == 0xE3 then
				Err(where, "ichidan verb needs an e/i-row kana before る: " .. ja)
			end
		elseif class == "5" then
			if not U_ROW[Last(ja)] then
				Err(where, "godan verb must end in a u-row kana: " .. ja)
			elseif Last(ja) == "る" and E_I_ROW[Last(ja, 2)] then
				Warn(where, "godan verb in e/i-row + る (right for 帰る, 走る; wrong for 食べる): " .. ja)
			end
		elseif class == "s" then
			if ja:sub(-6) ~= "する" then
				Err(where, "suru verb must end in する: " .. ja)
			end
		elseif class == "k" then
			if ja:sub(-6) ~= "くる" and ja:sub(-6) ~= "来る" then
				Err(where, "kuru verb must end in くる or 来る: " .. ja)
			end
		elseif class == "i" then
			if Last(ja) ~= "い" then
				Err(where, "i-class verb must end in い: " .. ja)
			end
		elseif class == "na" or class == "rel" then
			if Last(ja) == "だ" or ja:sub(-6) == "です" then
				Err(where, "na-class verb must not end in だ/です: " .. ja)
			end
		else
			Err(where, "unknown verb class " .. tostring(class))
		end
		CheckPredicates(where, entry)
	elseif entry.pos == "a" then
		if entry.class == "i" and Last(ja) ~= "い" then
			Err(where, "i-adjective must end in い: " .. ja)
		elseif entry.class == "na" and (Last(ja) == "だ" or ja:sub(-6) == "です") then
			Err(where, "na-adjective must not end in だ/です: " .. ja)
		end
		local ok, result = pcall(T.Copula, ja, entry.class, { negative = true, past = true })
		if not ok or type(result) ~= "string" or not T.IsValidUTF8(result) then
			Err(where, "adjective predicate failed")
		end
	end
end

local counted = 0
for _, pair in ipairs({ { "general", T.lexicon }, { "cyrodiil", T.cyrodiilLexicon } }) do
	local name, dictionary = pair[1], pair[2]
	for key, entry in pairs(dictionary) do
		counted = counted + 1
		CheckEntry(name, key, entry)
		for _, alternative in pairs(entry.alts or {}) do
			CheckEntry(name, key, alternative)
		end
	end
end

table.sort(errors)
table.sort(warnings)
if os.getenv("VERBOSE") then
	for _, line in ipairs(warnings) do
		print("WARN  " .. line)
	end
end
for _, line in ipairs(errors) do
	print("ERROR " .. line)
end
print(string.format("%d entries, %d errors, %d warnings", counted, #errors, #warnings))
os.exit(#errors == 0 and 0 or 1)
