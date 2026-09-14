-- PB's TranslateTest -- byte-safe text helpers
--
-- Lua's character classes (%a %w %s %u) and string.lower/upper ask the C library, and the C
-- library answers by the process's locale. On a desk that is the "C" locale and only ASCII
-- counts as a letter or a space. A game client need not run in "C": in a Latin-1 locale,
-- 0xE3 is a letter (a-tilde), 0xA0 and 0x85 are spaces, and lower() rewrites 0xC0-0xDE.
--
-- Those are UTF-8 bytes of Japanese text. こ is E3 81 93, だ is E3 81 A0. A pattern that thinks
-- E3 is a letter or A0 a space cuts a character in half, and lower() can change one of its
-- bytes -- either way the result is no longer UTF-8, and invalid UTF-8 handed to the chat
-- window or the entry box is the likely way /en crashed the PS5 client on untranslatable
-- Japanese (0.4.16): translatable input is consumed whole by dictionary matches and never
-- reaches a character class; untranslatable input always does.
--
-- So the add-on names its classes explicitly (ASCII only) and checks UTF-8 before any text it
-- built reaches the client. /en probe reports what the console's locale actually does.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

T.SPACE = "[ \t\r\n]"

function T.Trim(text)
	return (tostring(text or ""):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

-- ASCII-only lower case; every other byte is left exactly as it was.
function T.Lower(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

-- Is the whole string well-formed UTF-8?
function T.IsValidUTF8(text)
	if type(text) ~= "string" then
		return false
	end
	local i, length = 1, #text
	while i <= length do
		local byte = text:byte(i)
		local size
		if byte < 0x80 then
			size = 1
		elseif byte >= 0xC2 and byte <= 0xDF then
			size = 2
		elseif byte >= 0xE0 and byte <= 0xEF then
			size = 3
		elseif byte >= 0xF0 and byte <= 0xF4 then
			size = 4
		else
			return false
		end
		if i + size - 1 > length then
			return false
		end
		for k = i + 1, i + size - 1 do
			local continuation = text:byte(k)
			if continuation < 0x80 or continuation > 0xBF then
				return false
			end
		end
		i = i + size
	end
	return true
end

-- Drop every byte that is not part of a well-formed character. Returns the text and whether
-- anything was dropped.
function T.SanitizeUTF8(text)
	if T.IsValidUTF8(text) then
		return text, false
	end
	local out, i, length = {}, 1, #tostring(text or "")
	text = tostring(text or "")
	while i <= length do
		local byte = text:byte(i)
		local size = (byte < 0x80 and 1) or (byte >= 0xC2 and byte <= 0xDF and 2)
			or (byte >= 0xE0 and byte <= 0xEF and 3) or (byte >= 0xF0 and byte <= 0xF4 and 4) or 0
		local ok = size > 0 and i + size - 1 <= length
		if ok then
			for k = i + 1, i + size - 1 do
				local continuation = text:byte(k)
				if continuation < 0x80 or continuation > 0xBF then
					ok = false
					break
				end
			end
		end
		if ok then
			out[#out + 1] = text:sub(i, i + size - 1)
			i = i + size
		else
			i = i + 1
		end
	end
	return table.concat(out), true
end

-- What this Lua's locale does to UTF-8 bytes. Everything returned is ASCII.
function T.ProbeLocale()
	local function Matches(byte, class)
		return string.char(byte):find(class) ~= nil
	end
	local lowered = string.lower(string.char(0xC3))
	return {
		alphaE3 = Matches(0xE3, "%a"),
		alnumE3 = Matches(0xE3, "%w"),
		spaceA0 = Matches(0xA0, "%s"),
		space85 = Matches(0x85, "%s"),
		upperC3 = Matches(0xC3, "%u"),
		lowerChangesC3 = lowered ~= string.char(0xC3),
	}
end
