-- Tests for the /en prototype (JaToEn.lua, Outgoing.lua).
--
--   lua test/outgoing.lua     (from the add-on folder; any Lua 5.1+)
--
-- The chat system is a stub that records what StartTextEntry was asked to do, and zo_callLater
-- is a queue the test drains by hand, so the wait before opening and the report after it run
-- in order without real time passing. None of this says whether the PS5 input screen keeps
-- the text -- that is what the prototype is for -- only that the add-on asks for the right
-- thing and reports what it sees.

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

-- ---- /en opens the box with the English ------------------------------------------------
check("/en registered", type(SLASH_COMMANDS["/en"]), "function")

Reset()
SLASH_COMMANDS["/en"]("チャルマン砦の正門が攻撃されている")
check("English echoed before opening", Lines():find("chal fd lit", 1, true) ~= nil, true)
check("nothing opened before the wait", #chat.calls, 0)
RunTimers()
check("StartTextEntry called once", #chat.calls, 1)
check("StartTextEntry got the English", chat.calls[1] and chat.calls[1].text, "chal fd lit")
check("dontShowHUDWindow passed", chat.calls[1] and chat.calls[1].dontShow, true)
check("edit box holds the English", edit.text, "chal fd lit")
check("focus taken", edit.focused, true)
check("report line printed", Lines():find("opened=true text=ok screen=true", 1, true) ~= nil, true)

-- The command's own box is still closing: wait for it, then open.
Reset()
chat.open = true
SLASH_COMMANDS["/en"]("ありがとう")
table.remove(timers, 1)()   -- the delay
check("waits while the box is busy", #chat.calls, 0)
chat.open = false
RunTimers()
check("opens once the box is free", chat.calls[1] and chat.calls[1].text, "ty")

-- Declined and failing opens are reported, never thrown.
Reset()
chat.decline = true
SLASH_COMMANDS["/en"]("ありがとう")
RunTimers()
check("declined open reported", Lines():find("open declined: StartTextEntry declined", 1, true) ~= nil, true)

Reset()
chat.fail = true
local ok = pcall(function()
	SLASH_COMMANDS["/en"]("ありがとう")
	RunTimers()
end)
check("private-function error contained", ok, true)
check("private-function error reported", Lines():find("open FAILED with an error", 1, true) ~= nil, true)

-- Nothing translatable: say so, do not open.
Reset()
SLASH_COMMANDS["/en"]("ケーキを食べたい")
RunTimers()
check("untranslatable does not open", #chat.calls, 0)
check("untranslatable explained", Lines():find("英訳できませんでした", 1, true) ~= nil, true)

-- /en test bypasses translation.
Reset()
SLASH_COMMANDS["/en"]("test")
RunTimers()
check("/en test opens with hello", chat.calls[1] and chat.calls[1].text, "hello")

-- The report notices a box that came up empty.
Reset()
chat.StartTextEntryOriginal = chat.StartTextEntry
function chat:StartTextEntry(text, channel, target, dontShow)
	self.calls[#self.calls + 1] = { text = text, dontShow = dontShow }
	self.open = true
	edit.text = ""
end
function edit:SetText() end
SLASH_COMMANDS["/en"]("ありがとう")
RunTimers()
check("empty box reported as a mismatch", Lines():find("text=MISMATCH", 1, true) ~= nil, true)
chat.StartTextEntry = chat.StartTextEntryOriginal
function edit:SetText(text) self.text = text end

-- The send echoes back: report it.
Reset()
SLASH_COMMANDS["/en"]("ありがとう")
RunTimers()
ClearChat()
Speak(CHAT_CATEGORY_SAY, "@PinkBanther", "ty")
check("send confirmed from the echo", Lines():find("[en]|r sent: ty", 1, true) ~= nil, true)
ClearChat()
Speak(CHAT_CATEGORY_SAY, "@PinkBanther", "ty")
check("confirmed only once", Lines():find("sent:", 1, true) == nil, true)

-- delay setting
SLASH_COMMANDS["/en"]("delay 800")
check("/en delay stored", PBS_TRANSLATE_TEST.sv.outgoingDelayMs, 800)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
