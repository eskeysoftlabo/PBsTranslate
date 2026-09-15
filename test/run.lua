-- Tests for PB's Translate.
--
--   lua test/run.lua     (from the add-on folder; any Lua 5.1+)
--
-- Two parts. The first loads the add-on through its manifest against the stub client in
-- harness.lua and drives the chat pipeline: what gets translated, what is left alone, and
-- that the translation lands under the message it belongs to. The second is a list of chat
-- lines and the Japanese the engine currently makes of them -- a change to the grammar or
-- the dictionary that alters any of them shows up here, and is either a fix (update the
-- line) or a regression.

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
ADDON_DIR = HERE .. "/.."

local failures = 0
local function check(label, got, want)
	local ok = got == want
	if not ok then failures = failures + 1 end
	if not ok or os.getenv("VERBOSE") then
		print(string.format("%s %-44s got=%s want=%s", ok and "PASS" or "FAIL", label, tostring(got), tostring(want)))
	end
end

local function CollectStringKeys(path)
	local collected = {}
	local realCreate, realVersion = ZO_CreateStringId, SafeAddVersion
	ZO_CreateStringId = function(id) collected[id] = true end
	SafeAddVersion = function() end
	dofile(path)
	ZO_CreateStringId, SafeAddVersion = realCreate, realVersion
	return collected
end

dofile(HERE .. "/harness.lua")

local addon = PBS_TRANSLATE
local T = PBsTranslate

-- Defaults and one-time migration from the previous 60% default.
check("partial translations enabled by default", addon.sv.minKnownPercent, 0)
do
	local saved = addon.sv
	for _, threshold in ipairs({ 0, 60, 80 }) do
		addon.sv = { minKnownPercent = threshold }
		addon:MigrateKnownThreshold()
		check("migrate threshold " .. threshold, addon.sv.minKnownPercent, threshold == 60 and 0 or threshold)
		addon.sv.minKnownPercent = 60
		addon:MigrateKnownThreshold()
		check("later threshold choice survives reload", addon.sv.minKnownPercent, 60)
	end
	addon.sv = saved
	local ja = addon:TranslateLine("roe unflag")
	check("partial translation retains unknown word", ja ~= nil and ja:find("unflag", 1, true) ~= nil, true)
	addon.sv.minKnownPercent = 60
	local rejected, reason = addon:TranslateLine("roe unflag")
	check("explicit threshold still filters", rejected, nil)
	check("explicit threshold reason", reason, "50% known")
	addon.sv.minKnownPercent = 0
end

-- ---- loading ------------------------------------------------------------------------
check("add-on loaded", type(addon), "table")
check("listener installed", addon.installed, true)
check("version read from manifest", addon.version ~= "", true)
check("slash /pbtr", type(SLASH_COMMANDS["/pbtr"]), "function")
check("slash /jp", type(SLASH_COMMANDS["/jp"]), "function")
check("dictionary loaded", (T.entryCount or 0) > 1000, true)
check("settings panel built", #PanelRows > 0, true)

do
	local en = CollectStringKeys(ADDON_DIR .. "/lang/strings.lua")
	local jp = CollectStringKeys(ADDON_DIR .. "/lang/jp.lua")
	for key in pairs(en) do check("jp.lua has " .. key, jp[key], true) end
	for key in pairs(jp) do check("strings.lua has " .. key, en[key], true) end
end

-- Every string the code asks for exists.
do
	local en = CollectStringKeys(ADDON_DIR .. "/lang/strings.lua")
	for _, file in ipairs({ "Main.lua", "Settings.lua" }) do
		local source = io.open(ADDON_DIR .. "/" .. file):read("*a")
		for id in source:gmatch("SI_PBSTR_[%u_]+") do
			check(file .. " uses defined " .. id, en[id], true)
		end
	end
end

-- ---- the chat pipeline --------------------------------------------------------------
local PREFIX = GetString(SI_PBSTR_LINE_PREFIX)

local function LastLine()
	return ChatWindow[#ChatWindow]
end

ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "can you help me?")
check("original line first", ChatWindow[1], "[@Someone] can you help me?")
check("translation under it", ChatWindow[2] and ChatWindow[2]:find(PREFIX, 1, true) ~= nil, true)
check("translation text", ChatWindow[2] and ChatWindow[2]:find("手伝ってもらえますか", 1, true) ~= nil, true)
check("exactly two lines", #ChatWindow, 2)

-- Model ESO's per-tab category filters, with the client listener preceding the add-on.
-- A translation belongs only to the tabs that display its source message.
do
	local clientListener = CHAT_ROUTER.callbacks.FormattedChatMessage[1]
	local tabs = {
		{ allowed = { [CHAT_CATEGORY_PARTY] = true }, lines = {} },
		{ allowed = { [CHAT_CATEGORY_SYSTEM] = true }, lines = {} },
		{ allowed = { [CHAT_CATEGORY_PARTY] = true, [CHAT_CATEGORY_SYSTEM] = true }, lines = {} },
	}
	CHAT_ROUTER.callbacks.FormattedChatMessage[1] = function(message, category)
		for _, tab in ipairs(tabs) do
			if tab.allowed[category] then
				tab.lines[#tab.lines + 1] = message
			end
		end
	end
	local before = addon.stats.translated
	Speak(CHAT_CATEGORY_PARTY, "@Someone", "thank you")
	check("party tab gets both lines", #tabs[1].lines, 2)
	check("party tab original first", tabs[1].lines[1], "[@Someone] thank you")
	check("party tab translation second", tabs[1].lines[2], addon:FormatTranslation("ありがとうございます"))
	check("system tab excludes party translation", #tabs[2].lines, 0)
	check("combined tab gets no duplicate", #tabs[3].lines, 2)
	check("translation callback does not recurse", addon.stats.translated - before, 1)
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("hidden zone does not leak into party tab", #tabs[1].lines, 2)
	check("hidden zone does not leak into system tab", #tabs[2].lines, 0)
	check("hidden zone does not leak into combined tab", #tabs[3].lines, 2)
	SLASH_COMMANDS["/jp"]("thank you")
	check("manual translation remains system output", #tabs[2].lines, 2)
	check("manual translation excluded from party tab", #tabs[1].lines, 2)
	CHAT_ROUTER.callbacks.FormattedChatMessage[1] = clientListener
end

ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "こんにちは")
check("Japanese left alone", #ChatWindow, 1)

ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "Ich habe keine Zeit heute")
check("German left alone", #ChatWindow, 1)

ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "vMA")
check("nothing to translate left alone", #ChatWindow, 1)

-- Translation admission must not depend on byte-range patterns in string.find.
-- Simulate a matcher that cannot find non-ASCII bytes with the old pattern.
do
	local originalFind = string.find
	string.find = function(text, pattern, ...)
		if pattern == "[\128-\255]" then return nil end
		return originalFind(text, pattern, ...)
	end
	local ok, err = pcall(function()
		for _, input in ipairs({ "thank you", "roe", "ad roe", "spam oils", "Roe needs more help", "defend roe" }) do
			ClearChat()
			Speak(CHAT_CATEGORY_ZONE, "@Someone", input)
			check("byte-safe automatic translation: " .. input, #ChatWindow, 2)
			check("byte-safe translation content: " .. input, ChatWindow[2], addon:FormatTranslation(T.Translate(input)))
		end
		local ja, reason = addon:TranslateLine("vMA")
		check("ASCII output still rejected", ja, nil)
		check("ASCII output rejection reason", reason, "nothing to translate")
	end)
	string.find = originalFind
	check("byte-safe admission test runs", ok, true)
	if not ok then print(tostring(err)) end
end

ClearChat()
CHAT_ROUTER:AddSystemMessage("thank you")
check("system message not translated", #ChatWindow, 1)

ClearChat()
Speak(CHAT_CATEGORY_MONSTER_SAY, "", "you will die here")
check("NPC speech not translated", #ChatWindow, 1)

ClearChat()
Speak(CHAT_CATEGORY_PARTY, "@PinkBanther", "thank you")
check("own message translated", #ChatWindow, 2)
addon.sv.translateOwn = false
ClearChat()
Speak(CHAT_CATEGORY_PARTY, "@PinkBanther", "thank you")
check("own message off", #ChatWindow, 1)
ClearChat()
Speak(CHAT_CATEGORY_WHISPER_OUTGOING, "@Friend", "thank you")
check("outgoing whisper counts as own", #ChatWindow, 1)
addon.sv.translateOwn = true

addon.sv.translateOthers = false
ClearChat()
Speak(CHAT_CATEGORY_PARTY, "@Someone", "thank you")
check("others off", #ChatWindow, 1)
addon.sv.translateOthers = true

addon.sv.translateZone = false
ClearChat()
Speak(CHAT_CATEGORY_ZONE_ENGLISH, "@Someone", "thank you")
check("zone off", #ChatWindow, 1)
ClearChat()
Speak(CHAT_CATEGORY_GUILD_1, "@Someone", "thank you")
check("guild still on with zone off", #ChatWindow, 2)
addon.sv.translateZone = true

addon.sv.enabled = false
ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "thank you")
check("master switch off", #ChatWindow, 1)
addon.sv.enabled = true

-- A fault inside the engine must not break the chat callback chain.
do
	local realTranslate = T.Translate
	T.Translate = function() error("boom") end
	ClearChat()
	local ok = pcall(Speak, CHAT_CATEGORY_SAY, "@Someone", "thank you")
	check("engine error contained", ok, true)
	check("engine error: original still shown", ChatWindow[1], "[@Someone] thank you")
	check("engine error counted", addon.stats.errors >= 1, true)
	T.Translate = realTranslate
end

-- Item links pass through untouched.
ClearChat()
Speak(CHAT_CATEGORY_SAY, "@Someone", "wts |H1:item:12345:0|h[Sword of Doom]|h pst")
check("link kept in translation", LastLine() and LastLine():find("|H1:item:12345:0|h[Sword of Doom]|h", 1, true) ~= nil, true)

-- Translation colors apply to the whole new line and are shared by both output paths.
do
	local previousColor = addon.sv.color
	SLASH_COMMANDS["/pbtr"]("color #ff8000")
	check("color command saves normalized RGB", addon.sv.color, "FF8000")
	check("color spans prefix and body", addon:FormatTranslation("ありがとう"), "|cFF8000" .. PREFIX .. " ありがとう|r")
	for _, invalid in ipairs({ "red", "FFFF", "GG0000", "FFFFFF00" }) do
		SLASH_COMMANDS["/pbtr"]("color " .. invalid)
		check("invalid color preserves preference: " .. invalid, addon.sv.color, "FF8000")
	end
	ClearChat()
	Speak(CHAT_CATEGORY_SAY, "@Someone", "thank you")
	check("automatic translation uses color", ChatWindow[2], "|cFF8000" .. PREFIX .. " ありがとうございます|r")
	ClearChat()
	SLASH_COMMANDS["/jp"]("thank you")
	check("manual translation uses color", ChatWindow[1], "|cFF8000" .. PREFIX .. " ありがとうございます|r")
	local colorRow
	for _, row in ipairs(PanelRows) do
		if row.type == LibHarvensAddonSettings.ST_COLOR then colorRow = row end
	end
	check("color picker exists", colorRow ~= nil, true)
	if colorRow then
		colorRow.setFunction(0, 1, 0, 1)
		check("picker saves RGB", addon.sv.color, "00FF00")
		local r, g, b, a = colorRow.getFunction()
		check("picker reads saved RGB", r == 0 and g == 1 and b == 0 and a == 1, true)
		colorRow.setFunction(colorRow.default[1], colorRow.default[2], colorRow.default[3], colorRow.default[4])
		check("picker default restores original", addon.sv.color, addon.DEFAULTS.color)
	end
	SLASH_COMMANDS["/pbtr"]("color default")
	check("color default restores original", addon.sv.color, addon.DEFAULTS.color)
	addon.sv.color = "invalid"
	check("bad saved color safely falls back", addon:GetTranslationColor(), addon.DEFAULTS.color)
	addon.sv.color = previousColor
end

-- ---- commands -----------------------------------------------------------------------
ClearChat()
SLASH_COMMANDS["/jp"]("I want to go to the bank")
check("/jp prints the translation", ChatWindow[1] and ChatWindow[1]:find("銀行に行きたいです", 1, true) ~= nil, true)

SLASH_COMMANDS["/pbtr"]("add molag bal = モラグ・バル様")
local ja = T.Translate("molag bal is here")
check("/pbtr add used by the engine", ja:find("モラグ・バル様", 1, true) ~= nil, true)
check("/pbtr add saved", addon.sv.userWords["molag bal"], "モラグ・バル様")
SLASH_COMMANDS["/pbtr"]("remove molag bal")
ja = T.Translate("molag bal is here")
check("/pbtr remove restores the built-in word", ja:find("モラグ・バル様", 1, true) == nil, true)

SLASH_COMMANDS["/pbtr"]("add raid night = n:レイドの夜")
ja = T.Translate("the raid night is fun")
check("/pbtr add with part of speech", ja, "レイドの夜は楽しいです")
SLASH_COMMANDS["/pbtr"]("remove raid night")

SLASH_COMMANDS["/pbtr"]("known 80")
check("/pbtr known", addon.sv.minKnownPercent, 80)
SLASH_COMMANDS["/pbtr"]("known 0")
SLASH_COMMANDS["/pbtr"]("zone off")
check("/pbtr zone off", addon.sv.translateZone, false)
SLASH_COMMANDS["/pbtr"]("zone on")
SLASH_COMMANDS["/pbtr"]("off")
check("/pbtr off", addon.sv.enabled, false)
SLASH_COMMANDS["/pbtr"]("on")
check("/pbtr on", addon.sv.enabled, true)

ClearChat()
local ok = pcall(SLASH_COMMANDS["/pbtr"], "")
check("/pbtr status runs", ok and #ChatWindow > 0, true)
ok = pcall(SLASH_COMMANDS["/pbtr"], "help")
check("/pbtr help runs", ok, true)

-- Replacement mode: formatter metadata, failures, hidden messages, and live toggling.
do
	local original = CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL]
	local calls = 0
	local color = {}
	CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(category, name, raw, _, sender)
		calls = calls + 1
		if raw == "hidden" then return nil end
		return "[channel][" .. name .. "] " .. raw, 77, sender, raw, name .. ": " .. raw, color
	end)
	SLASH_COMMANDS["/pbtr"]("only on")
	check("replacement mode enabled", addon.sv.translationOnly, true)
	ClearChat()
	local before, beforeCalls = addon.stats.translated, calls
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("replacement emits one line", #ChatWindow, 1)
	check("replacement keeps sender and channel", ChatWindow[1], "[channel][@Someone] " .. addon:FormatTranslation("ありがとうございます"))
	check("replacement counted once", addon.stats.translated - before, 1)
	check("original formatter called once", calls - beforeCalls, 1)
	local formatter = CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL]
	local line, target, sender, raw, narration, outputColor = formatter(CHAT_CATEGORY_PARTY, "thank you", "thank you", false, "@Someone")
	check("identical sender text stays intact", line, "[channel][thank you] " .. addon:FormatTranslation("ありがとうございます"))
	check("reply target preserved", target, 77)
	check("sender metadata preserved", sender, "@Someone")
	check("raw message preserved for other addons", raw, "thank you")
	check("narration translated", narration, "thank you: ありがとうございます")
	check("color metadata preserved", outputColor, color)
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "hidden")
	check("hidden messages remain hidden", #ChatWindow, 0)
	for _, text in ipairs({ "こんにちは", "qzxwv", "vMA" }) do
		ClearChat()
		Speak(CHAT_CATEGORY_ZONE, "@Someone", text)
		check("untranslated original kept: " .. text, ChatWindow[1], "[channel][@Someone] " .. text)
		check("untranslated original only once: " .. text, #ChatWindow, 1)
	end
	local translate = T.Translate
	T.Translate = function() error("replacement test error") end
	ClearChat()
	local errors = addon.stats.errors
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("engine error preserves original", ChatWindow[1], "[channel][@Someone] thank you")
	check("engine error produces one line", #ChatWindow, 1)
	check("engine error counted once", addon.stats.errors - errors, 1)
	T.Translate = translate
	addon.sv.translateZone = false
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("zone exclusion preserves original", ChatWindow[1], "[channel][@Someone] thank you")
	addon.sv.translateZone = true
	ClearChat()
	local link = "|H1:item:12345:0|h[Sword of Doom]|h"
	Speak(CHAT_CATEGORY_PARTY, "@Someone", "wts " .. link .. " pst")
	check("replacement keeps item link", ChatWindow[1]:find(link, 1, true) ~= nil, true)
	SLASH_COMMANDS["/pbtr"]("only off")
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("switch off restores two lines", #ChatWindow, 2)
	check("switch off restores original text", ChatWindow[1], "[channel][@Someone] thank you")
	-- Recover after a formatter replaces ours outright.
	CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, original)
	SLASH_COMMANDS["/pbtr"]("only on")
	check("replacement preference survives conflict", addon.sv.translationOnly, true)
	local stable = CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL]
	addon:SetTranslationOnly(true)
	check("repeat enable reuses active wrapper", CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL], stable)
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("reinstalled formatter emits one line", #ChatWindow, 1)
	check("reinstalled formatter translates", ChatWindow[1], "[@Someone] " .. addon:FormatTranslation("ありがとうございます"))
	-- A different addon wraps the old generation. Re-registering must translate only once.
	for i = 1, 3 do
		local previous = CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL]
		CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(...)
			local text, target, sender, raw, narration, color = previous(...)
			return text and ("[other]" .. text), target, sender, raw, narration, color
		end)
		addon:SetTranslationOnly(true)
		ClearChat()
		local count = addon.stats.translated
		Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
		check("nested wrapper one line " .. i, #ChatWindow, 1)
		check("nested wrapper one translation " .. i, addon.stats.translated - count, 1)
		check("nested wrapper retains other addon " .. i, ChatWindow[1], string.rep("[other]", i) .. "[@Someone] " .. addon:FormatTranslation("ありがとうございます"))
	end
	-- Temporarily unavailable at load; retain preference and recover on a bounded tick.
	CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL] = nil
	check("unavailable formatter reports failure", addon:SetTranslationOnly(true, true), false)
	check("unavailable formatter keeps preference", addon.sv.translationOnly, true)
	check("unavailable reason recorded", addon.diag.replacementError, "channel formatter not ready")
	CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL] = original
	TickUpdates()
	check("retry clears failure reason", addon.diag.replacementError, nil)
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("retry restores one translated line", ChatWindow[1], "[@Someone] " .. addon:FormatTranslation("ありがとうございます"))
	for i = 1, 5 do TickUpdates() end
	check("successful checks stop", next(UpdateHandlers), nil)
	-- Exceptions retain their details and checks stop even if registration never recovers.
	local register = CHAT_ROUTER.RegisterMessageFormatter
	CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL] = original
	CHAT_ROUTER.RegisterMessageFormatter = function() error("registration refused") end
	addon:SetTranslationOnly(true, true)
	check("registration exception recorded", addon.diag.replacementError:find("registration refused", 1, true) ~= nil, true)
	for i = 1, 5 do TickUpdates() end
	check("failed retries stop", next(UpdateHandlers), nil)
	check("failed retries keep preference", addon.sv.translationOnly, true)
	CHAT_ROUTER.RegisterMessageFormatter = register
	addon:SetTranslationOnly(true)
	addon:SetTranslationOnly(false)
	check("disable cancels checks", next(UpdateHandlers), nil)
	ClearChat()
	Speak(CHAT_CATEGORY_ZONE, "@Someone", "thank you")
	check("disable after recovery shows original and translation", #ChatWindow, 2)
	-- Restore the test fixture before the remaining engine snapshots.
	CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, original)
	addon.replacementFormatter = nil
	addon.formattedDecision = nil
end

-- ---- location-dependent dictionary priority -----------------------------------------
check("initial dictionary is normal", T.cyrodiilPriority, false)
local entryCount = T.entryCount
for _, inside in ipairs({ false, true, false, true, false }) do
	InCyrodiil = inside
	Fire(EVENT_PLAYER_ACTIVATED)
	local label = inside and "Cyrodiil" or "outside"
	check(label .. " warden", T.Translate("warden"), inside and "ウォーデン砦" or "ワーデン")
	check(label .. " dragon", T.Translate("dragon"), inside and "ドラゴンクロー砦" or "ドラゴン")
	check(label .. " mine pronoun", T.Translate("it is mine"), "それは私のものです")
	check(label .. " keep abbreviation fallback", T.Translate("bm fd"), "ブラッドメイン砦の正門")
	check(label .. " verb inflection", T.Translate("we pushed"), inside and "私たちは攻めました" or "私たちは押しました")
	check(label .. " dictionary count stable", T.entryCount, entryCount)
	ClearChat()
	Speak(CHAT_CATEGORY_PARTY, "@Someone", "warden")
	check(label .. " automatic translation", ChatWindow[2], addon:FormatTranslation(inside and "ウォーデン砦" or "ワーデン"))
	ClearChat()
	SLASH_COMMANDS["/jp"]("warden")
	check(label .. " manual translation", ChatWindow[1], addon:FormatTranslation(inside and "ウォーデン砦" or "ワーデン"))
	SLASH_COMMANDS["/pbtr"]("add warden = n:カスタム訳")
	check(label .. " user dictionary wins", T.Translate("warden"), "カスタム訳")
	SLASH_COMMANDS["/pbtr"]("remove warden")
	check(label .. " remove restores location meaning", T.Translate("warden"), inside and "ウォーデン砦" or "ワーデン")
end
local locationAPI = IsInCyrodiil
IsInCyrodiil = nil
Fire(EVENT_PLAYER_ACTIVATED)
check("missing location API uses normal dictionary", T.Translate("warden"), "ワーデン")
IsInCyrodiil = locationAPI

-- ---- diagnostics ----------------------------------------------------------------------
do
	-- A refused client function in the location check must not take the listener with it.
	local realCheck = IsInCyrodiil
	IsInCyrodiil = function() error("Attempt to access a private function 'IsInCyrodiil' from insecure code") end
	ClearChat()
	addon.bannerShown = false
	Fire(EVENT_PLAYER_ACTIVATED)
	IsInCyrodiil = realCheck
	check("banner printed once", ChatWindow[1] ~= nil and ChatWindow[1]:find("start-up step", 1, true) ~= nil, true)
	ClearChat()
	Speak(CHAT_CATEGORY_SAY, "@Someone", "thank you")
	check("still translating after a failed step", #ChatWindow, 2)
	ClearChat()
	SLASH_COMMANDS["/pbtr"]("probe")
	local probe = table.concat(ChatWindow, "\n")
	check("probe names the failed step", probe:find("load step FAILED: dictionary context", 1, true) ~= nil, true)
	check("probe shows callbacks", probe:find("callbacks=", 1, true) ~= nil, true)
	check("probe shows recent decision", probe:find("translated: thank you", 1, true) ~= nil, true)
	SLASH_COMMANDS["/pbtr"]("debug on")
	ClearChat()
	Speak(CHAT_CATEGORY_SAY, "@Someone", "Ich habe keine Zeit heute")
	check("debug line explains a skip", ChatWindow[2] ~= nil and ChatWindow[2]:find("[pbtr]", 1, true) ~= nil, true)
	SLASH_COMMANDS["/pbtr"]("debug off")

	-- Output that throws falls back to a system line instead of vanishing.
	local realFire = CHAT_ROUTER.FireCallbacks
	local depth = 0
	CHAT_ROUTER.FireCallbacks = function(router, name, message, category, target, from, raw)
		if raw == nil and category ~= CHAT_CATEGORY_SYSTEM then
			error("refused")
		end
		return realFire(router, name, message, category, target, from, raw)
	end
	ClearChat()
	Speak(CHAT_CATEGORY_SAY, "@Someone", "thank you")
	CHAT_ROUTER.FireCallbacks = realFire
	check("output fallback shows the translation", #ChatWindow, 2)
	check("output fallback counted", addon.diag.outputFallback, 1)
end

-- The Imperial City is its own zone (IsInCyrodiil is false there) but has the same chat.
InCyrodiil = false
InImperialCity = true
Fire(EVENT_PLAYER_ACTIVATED)
check("Imperial City uses the Cyrodiil dictionary", T.Translate("warden"), "ウォーデン砦")
InImperialCity = false
Fire(EVENT_PLAYER_ACTIVATED)
check("outside, winter is the season", T.Translate("winter is cold"), "冬は寒いです")
check("outside, fair is an adjective", T.Translate("that is fair"), "それは公平です")
InImperialCity = false

T.SetCyrodiilPriority(true)
for _, word in ipairs({ "ham", "Ham", "HAM" }) do
	check("Volendrung abbreviation " .. word, T.Translate(word), "ヴォレンドラング")
end

-- Existing snapshots were recorded with PvP meanings; exercise that context explicitly.
InCyrodiil = true
Fire(EVENT_PLAYER_ACTIVATED)

-- ---- translations -------------------------------------------------------------------
dofile(HERE .. "/cases.lua")

for _, case in ipairs(TRANSLATION_CASES) do
	local got = T.Translate(case[1])
	if os.getenv("PRINT") then
		print(string.format("\t{ %q, %q },", case[1], got))
	else
		check(case[1], got, case[2])
	end
end

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
