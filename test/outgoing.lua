-- Tests for the /en prototype (JaToEn.lua, Outgoing.lua).
--
--   lua test/outgoing.lua     (from the add-on folder; any Lua 5.1+)
--
-- The chat system is a stub that records what StartTextEntry was asked to do, and zo_callLater
-- is a queue the test drains by hand. None of this can say which call crashed the PS5 client
-- in 0.4.12 -- that is what /en try 1..5 are for -- only that /en itself leaves the chat box
-- alone and that each try step makes exactly the calls it announces, in order.

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
ADDON_DIR = HERE .. "/.."

local failures = 0
local function check(label, got, want)
	local ok = got == want
	if not ok then failures = failures + 1 end
	if not ok or os.getenv("VERBOSE") then
		print(string.format("%s %-48s got=%s want=%s", ok and "PASS" or "FAIL", label, tostring(got), tostring(want)))
	end
end

-- ---- timers ---------------------------------------------------------------------------
local timers = {}
function zo_callLater(fn, ms) timers[#timers + 1] = fn end
local function RunTimers()
	local guard = 0
	while #timers > 0 and guard < 100 do
		guard = guard + 1
		table.remove(timers, 1)()
	end
end

-- ---- chat system stub -----------------------------------------------------------------
local edit = { text = "" }
function edit:GetText() return self.text end
function edit:SetText(text) self.text = text end
function edit:TakeFocus() self.focused = true end

local chat = {
	open = false, calls = {}, decline = false, fail = false,
	textEntry = {}, primaryContainer = { FadeIn = function() end },
}
function chat.textEntry:GetEditControl() return edit end
function chat:IsTextEntryOpen() return self.open end
function chat:SetHUDEnabled() end
function chat:StartTextEntry(text, channel, target, dontShowHUDWindow)
	self.calls[#self.calls + 1] = { text = text, dontShow = dontShowHUDWindow }
	if self.fail then error("Attempt to access a private function 'SetSetting' from insecure code") end
	if self.decline then return end
	self.open = true
	if text and text ~= "" then edit.text = text end
end
function ZO_GetChatSystem() return chat end
ScreenUp = true
function IsVirtualKeyboardOnScreen() return ScreenUp end

dofile(HERE .. "/harness.lua")

local T = PBsTranslate
local function Lines() return table.concat(ChatWindow, "\n") end
local function Reset()
	ClearChat()
	timers = {}
	chat.open, chat.calls, chat.decline, chat.fail = false, {}, false, false
	edit.text = ""
end

-- ---- translation ----------------------------------------------------------------------
local CASES = {
	{ "チャルマン砦の正門が攻撃されている", "chal fd lit" },
	{ "ブラックブート砦に集合", "stack at bb" },
	{ "正門に破城槌が必要です", "need rams at fd" },
	{ "クラウンに集合してください", "stack on crown" },
	{ "正門から大集団が来ています", "zerg inc from fd" },
	{ "ローベック砦を防衛してください", "def roe" },
	{ "裏門に攻城兵器を置いてください", "drop siege at bd" },
	{ "チャルマンに向かってる", "omw to chal" },
	{ "アレッシア砦にポートして", "port to alessia" },
	{ "内門が破られました", "inner down" },
	{ "ありがとう、了解", "ty, roger" },
	{ "ここに集合", "stack here" },
	{ "英語は話せません", "I don't speak English" },
	{ "vMAに行こう", "go vMA" },
}
for _, case in ipairs(CASES) do
	local english, unknown = T.TranslateJaToEn(case[1])
	check(case[1], english, case[2])
	check(case[1] .. " fully understood", #unknown, 0)
end
do
	local english, unknown = T.TranslateJaToEn("ケーキを食べたい")
	check("unknown sentence gives nothing", english, "")
	check("unknown words reported", table.concat(unknown, "/"), "ケーキ/食べたい")
end

-- ---- /en opens the box with the English -----------------------------------------------
check("/en registered", type(SLASH_COMMANDS["/en"]), "function")

Reset()
SLASH_COMMANDS["/en"]("チャルマン砦の正門が攻撃されている")
check("/en prints the English", Lines():find("chal fd lit", 1, true) ~= nil, true)
check("/en waits before opening", #chat.calls, 0)
check("/en schedules one open", #timers, 1)
RunTimers()
check("/en opens once", #chat.calls, 1)
check("/en opens with the English", chat.calls[1] and chat.calls[1].text, "chal fd lit")
check("/en passes dontShowHUDWindow", chat.calls[1] and chat.calls[1].dontShow, true)
check("/en box holds the English", edit.text, "chal fd lit")
check("/en schedules nothing after opening", #timers, 0)

Reset()
SLASH_COMMANDS["/en"]("ケーキを食べたい")
RunTimers()
check("untranslatable opens with 翻訳不可", chat.calls[1] and chat.calls[1].text, "翻訳不可")
check("untranslatable words listed", Lines():find("ケーキ / 食べたい", 1, true) ~= nil, true)

Reset()
SLASH_COMMANDS["/en"]("ありがとう、ケーキ")
RunTimers()
check("partly translated opens with the English part", chat.calls[1] and chat.calls[1].text, "ty")
check("partly translated lists the rest", Lines():find("未対応の語: ケーキ", 1, true) ~= nil, true)

-- A box still open after the wait is left alone, not polled or reopened.
Reset()
chat.open = true
SLASH_COMMANDS["/en"]("ありがとう")
RunTimers()
check("still-open box not reopened", #chat.calls, 0)
check("still-open box reported", Lines():find("入力欄を開けませんでした: the chat box is still open", 1, true) ~= nil, true)
check("still-open box not polled", #timers, 0)

Reset()
chat.fail = true
local okFail = pcall(function()
	SLASH_COMMANDS["/en"]("ありがとう")
	RunTimers()
end)
check("/en open error contained", okFail, true)
check("/en open error reported", Lines():find("入力欄を開けませんでした: ", 1, true) ~= nil, true)

-- ---- /en try N: one more call per step --------------------------------------------------
local function Try(step)
	Reset()
	SLASH_COMMANDS["/en"]("try " .. step)
	check("try " .. step .. " waits before opening", #chat.calls, 0)
	RunTimers()
end

Try(1)
check("try 1 opens once", #chat.calls, 1)
check("try 1 opens empty", chat.calls[1] and chat.calls[1].text, nil)
check("try 1 passes dontShowHUDWindow", chat.calls[1] and chat.calls[1].dontShow, true)
check("try 1 announces before opening", Lines():find("opening the chat box empty now", 1, true) ~= nil, true)
check("try 1 reads nothing back", Lines():find("text=", 1, true) == nil and Lines():find("screen=", 1, true) == nil, true)

Try(2)
check("try 2 reads the screen state", Lines():find("try 2: screen=true", 1, true) ~= nil, true)
check("try 2 opens empty", chat.calls[1] and chat.calls[1].text, nil)

Try(3)
check("try 3 reads the text", Lines():find("try 3: text=[]", 1, true) ~= nil, true)

Try(4)
check("try 4 sets the text afterwards", edit.text, "hello")
check("try 4 opened empty first", chat.calls[1] and chat.calls[1].text, nil)

Try(5)
check("try 5 opens with hello", chat.calls[1] and chat.calls[1].text, "hello")

Try(6)
check("try 6 opens with hello", chat.calls[1] and chat.calls[1].text, "hello")
check("try 6 uses 300 ms", Lines():find("try 6: starting in 300 ms", 1, true) ~= nil, true)
check("try 6 reads nothing back", Lines():find("text", 1, true) == nil, true)

Try(7)
check("try 7 uses 2000 ms", Lines():find("try 7: starting in 2000 ms", 1, true) ~= nil, true)
check("try 7 reads text at once", Lines():find("try 7: text at once=[hello]", 1, true) ~= nil, true)
check("try 7 reads screen and text later", Lines():find("try 7: screen=true text=[hello]", 1, true) ~= nil, true)

Try(8)
check("try 8 uses 300 ms", Lines():find("try 8: starting in 300 ms", 1, true) ~= nil, true)
check("try 8 reads like 0.4.12", Lines():find("try 8: screen=true text=[hello]", 1, true) ~= nil, true)

-- A box that is still open is not reopened on top of itself.
Reset()
chat.open = true
SLASH_COMMANDS["/en"]("try 1")
RunTimers()
check("busy box declined", Lines():find("open declined: the chat box is still open", 1, true) ~= nil, true)
check("busy box not reopened", #chat.calls, 0)

-- Declined and failing opens are reported, never thrown, and stop the step.
Reset()
chat.decline = true
SLASH_COMMANDS["/en"]("try 3")
RunTimers()
check("declined open reported", Lines():find("open declined: StartTextEntry declined", 1, true) ~= nil, true)
check("declined open skips the read", Lines():find("try 3: text=", 1, true) == nil, true)

Reset()
chat.fail = true
local ok = pcall(function()
	SLASH_COMMANDS["/en"]("try 5")
	RunTimers()
end)
check("open error contained", ok, true)
check("open error reported", Lines():find("try 5: open error", 1, true) ~= nil, true)

Reset()
SLASH_COMMANDS["/en"]("try 9")
RunTimers()
check("unknown step does nothing", #chat.calls, 0)

-- ---- /en probe ------------------------------------------------------------------------
Reset()
SLASH_COMMANDS["/en"]("probe")
check("probe reports the locale", Lines():find("locale: E3 letter=", 1, true) ~= nil, true)
check("probe reports the sample", Lines():find("untranslatable sample: english=empty pieces=2 valid=true", 1, true) ~= nil, true)
check("probe opens nothing", #chat.calls, 0)

-- ---- a console-like locale --------------------------------------------------------------
-- In a Latin-1 ctype locale 0xE3 is a letter, which is what broke untranslatable Japanese on
-- PS5 in 0.4.16. Everything below must hold there too. Skipped where the locale is missing.
-- (LuaJIT's patterns ignore the locale, so there the section is skipped too.)
if os and os.setlocale and os.setlocale("en_US.ISO8859-1", "ctype") and string.char(0xE3):find("%a") then
	for _, text in ipairs({ "ケーキを食べたい", "今日はだめだ", "ぅぁ、だ", "チャルマン砦の正門が攻撃されている", "ありがとう、ケーキ" }) do
		local english, unknown = T.TranslateJaToEn(text)
		local valid = T.IsValidUTF8(english)
		for _, piece in ipairs(unknown) do valid = valid and T.IsValidUTF8(piece) end
		check("Latin-1: valid UTF-8 for " .. text, valid, true)
	end
	check("Latin-1: untranslatable stays empty", (T.TranslateJaToEn("ケーキを食べたい")), "")
	check("Latin-1: callout still translates", (T.TranslateJaToEn("チャルマン砦の正門が攻撃されている")), "chal fd lit")

	Reset()
	SLASH_COMMANDS["/en"]("ケーキを食べたい")
	RunTimers()
	check("Latin-1: untranslatable opens with 翻訳不可", chat.calls[1] and chat.calls[1].text, "翻訳不可")
	check("Latin-1: every chat line is valid UTF-8", T.IsValidUTF8(Lines()), true)

	Reset()
	Speak(CHAT_CATEGORY_SAY, "@Someone", "今日はだめだ、ケーキを食べたい")
	check("Latin-1: Japanese chat never produces invalid lines", T.IsValidUTF8(Lines()), true)
	Speak(CHAT_CATEGORY_SAY, "@Someone", "thank you")
	check("Latin-1: English chat still translated", Lines():find("ありがとう", 1, true) ~= nil, true)
	os.setlocale("C", "ctype")
end

-- Sanitizer
check("sanitize drops a cut character", (T.SanitizeUTF8("a" .. string.char(0xE3, 0x81) .. "b")), "ab")
check("sanitize keeps valid text", (T.SanitizeUTF8("翻訳不可")), "翻訳不可")
check("valid UTF-8 detects a stray continuation byte", T.IsValidUTF8(string.char(0xA0)), false)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
