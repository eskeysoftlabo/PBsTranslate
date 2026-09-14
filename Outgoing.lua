-- PB's TranslateTest -- /en: Japanese in, English into the chat entry box (prototype)
--
--   /en チャルマン砦の正門が攻撃されている   ->   the chat box opens holding "chal fd lit"
--
-- An add-on cannot send chat. SendChatMessage is *private* (ESOUIDocumentation.txt), so the
-- one call that sends is out of reach, and the player presses send. What an add-on can do is
-- open the entry box with text already in it: SharedChatSystem:StartTextEntry(text, ...)
-- hands the text to TextEntry:Open, which puts it in the edit control.
--
-- The opening itself follows PB's ChatAssistant, which does it on PS5 today:
--
--   * dontShowHUDWindow = true. ZO_GamepadChatSystem:StartTextEntry calls the private
--     SetSetting unless that flag is set, so the flag is the only way in -- and the window
--     work the flag skips is done here instead.
--   * after a wait. /en is itself typed into the chat box, and the slash command runs while
--     that box is closing. Reopening in the same frame gives the console no lost-and-regained
--     focus to raise its input screen for.
--
-- WHAT THIS PROTOTYPE IS FOR
--
-- Two things nobody has measured, and every /en prints a line that answers them:
--
--   1. Does the English survive into the console's input screen, or does the platform open
--      the screen empty?                                 -> "text=" and what the player sees
--   2. Does sending still work from a box an add-on opened with text in it, or does the game
--      refuse a private call on the way out?             -> "[en] sent" when the message echoes
--
-- Everything is under pcall and nothing here wraps or hooks client code.

local addon = PBS_TRANSLATE_TEST
local T = PBsTranslate
if not addon or not T or not T.TranslateJaToEn then
	return
end

local DEFAULT_DELAY_MS = 300
local REPORT_AFTER_MS = 1500
local OPEN_RETRIES = 10
local RETRY_MS = 100

local outgoing = {
	pending = nil,     -- the English we put in the box, until it echoes back as sent
	lastReport = nil,
}
addon.outgoing = outgoing

local function Say(text)
	if addon.Say then
		addon.Say(text)
	elseif CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	end
end

local PREFIX = "|cFF69B4[en]|r "

local function Report(format, ...)
	local ok, text = pcall(string.format, format, ...)
	Say(PREFIX .. (ok and text or format))
end

local function DelayMs()
	local sv = addon.sv
	local value = sv and tonumber(sv.outgoingDelayMs)
	return value and value >= 0 and value or DEFAULT_DELAY_MS
end

local function GetChat()
	if type(ZO_GetChatSystem) ~= "function" then
		return nil
	end
	return ZO_GetChatSystem()
end

local function EditControlOf(chat)
	local textEntry = chat and chat.textEntry
	return textEntry and type(textEntry.GetEditControl) == "function" and textEntry:GetEditControl() or nil
end

local function ReadEntry(chat)
	local edit = EditControlOf(chat)
	local open = chat and type(chat.IsTextEntryOpen) == "function" and chat:IsTextEntryOpen() or false
	local text = edit and type(edit.GetText) == "function" and edit:GetText() or nil
	local screen = type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen() or nil
	return open, text, screen
end

-- Open the box with the text in it. Returns opened, reason.
local function OpenWithText(text)
	local chat = GetChat()
	if not chat or type(chat.StartTextEntry) ~= "function" then
		return false, "no chat system"
	end
	if type(chat.SetHUDEnabled) == "function" then
		chat:SetHUDEnabled(true)
	end

	chat:StartTextEntry(text, nil, nil, true)
	if type(chat.IsTextEntryOpen) ~= "function" or not chat:IsTextEntryOpen() then
		return false, "StartTextEntry declined"
	end

	-- The window work dontShowHUDWindow skipped (see PB's ChatAssistant, OpenChatEntry).
	if chat.isMinimized and type(chat.Maximize) == "function" then
		chat:Maximize()
	elseif chat.primaryContainer and type(chat.primaryContainer.FadeIn) == "function" then
		chat.primaryContainer:FadeIn()
	end
	chat.shouldMinimizeAfterEntry = false

	-- Open() only sets the text when the box was closed; set it again in case it was not.
	local edit = EditControlOf(chat)
	if edit then
		if type(edit.GetText) == "function" and edit:GetText() ~= text and type(edit.SetText) == "function" then
			edit:SetText(text)
		end
		if type(edit.TakeFocus) == "function" then
			edit:TakeFocus()
		end
	end
	return true
end

local function Later(fn, ms)
	if type(zo_callLater) == "function" then
		zo_callLater(fn, ms)
	else
		fn()
	end
end

-- Wait for the box the command was typed into to finish closing, then open ours.
local function OpenWhenFree(text, attempt)
	attempt = attempt or 1
	local chat = GetChat()
	local busy = chat and type(chat.IsTextEntryOpen) == "function" and chat:IsTextEntryOpen()
	if busy and attempt < OPEN_RETRIES then
		Later(function()
			OpenWhenFree(text, attempt + 1)
		end, RETRY_MS)
		return
	end

	local ok, opened, reason = pcall(OpenWithText, text)
	if not ok then
		Report("open FAILED with an error: %s", tostring(opened))
		return
	end
	if not opened then
		Report("open declined: %s (busy=%s after %d tries)", tostring(reason), tostring(busy), attempt)
		return
	end
	outgoing.pending = text

	local open, current, screen = ReadEntry(chat)
	local firstText = current == text and "ok" or ("MISMATCH [" .. tostring(current) .. "]")
	local firstScreen = tostring(screen)
	Later(function()
		local laterOpen, laterText, laterScreen = ReadEntry(GetChat())
		outgoing.lastReport = {
			open = open, text = firstText, screen = firstScreen,
			laterOpen = laterOpen, laterText = laterText == text and "ok" or tostring(laterText), laterScreen = laterScreen,
		}
		Report("opened=%s text=%s screen=%s | %dms later: open=%s text=%s screen=%s",
			tostring(open), firstText, firstScreen, REPORT_AFTER_MS,
			tostring(laterOpen), outgoing.lastReport.laterText, tostring(laterScreen))
	end, REPORT_AFTER_MS)
end

-- ---------------------------------------------------------------------------------------
-- The command
-- ---------------------------------------------------------------------------------------

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function addon:OutgoingCommand(argumentString)
	local argument = Trim(argumentString)

	if argument == "" or argument == "help" then
		Report("/en <日本語> -- 英訳して入力欄に入れます（送信は自分で）")
		Report("/en test -- 英語の固定文 \"hello\" で入力欄を開きます（翻訳を使わない確認用）")
		Report("/en delay <ms> -- 入力欄を開くまでの待ち時間（今: %d ms）", DelayMs())
		return
	end

	local delay = argument:match("^delay%s+(%d+)$")
	if delay then
		if self.sv then
			self.sv.outgoingDelayMs = tonumber(delay)
		end
		Report("delay %d ms", DelayMs())
		return
	end

	local english
	if argument == "test" then
		english = "hello"
	else
		local ok, result, unknown = pcall(T.TranslateJaToEn, argument)
		if not ok then
			Report("translation error: %s", tostring(result))
			return
		end
		if #unknown > 0 then
			Report("未対応の語: %s", table.concat(unknown, " / "))
		end
		if result == "" then
			Report("英訳できませんでした。入力欄は開きません。")
			return
		end
		english = result
	end

	-- Shown in chat as well, so the English is not lost if the box opens empty.
	Report("%s", english)
	Later(function()
		OpenWhenFree(english)
	end, DelayMs())
end

-- ---------------------------------------------------------------------------------------
-- Did it go out?
--
-- A sent message echoes back through the chat router with its raw text, like every other
-- message. When the raw text is what we put in the box and the sender is the player, the
-- send worked -- the answer to question 2 above.
-- ---------------------------------------------------------------------------------------

local function OnFormattedChatMessage(_, _, _, fromDisplayName, rawMessageText)
	local pending = outgoing.pending
	if not pending or type(rawMessageText) ~= "string" then
		return
	end
	local mine = type(GetDisplayName) == "function" and GetDisplayName() or nil
	local fromMe = fromDisplayName == nil or fromDisplayName == mine
		or (type(fromDisplayName) == "string" and mine and fromDisplayName:gsub("^@", "") == mine:gsub("^@", ""))
	if fromMe and rawMessageText == pending then
		outgoing.pending = nil
		outgoing.sent = (outgoing.sent or 0) + 1
		Report("sent: %s", pending)
	end
end

local function Install()
	if SLASH_COMMANDS then
		SLASH_COMMANDS["/en"] = function(argumentString)
			local ok, err = pcall(addon.OutgoingCommand, addon, argumentString)
			if not ok then
				Report("command error: %s", tostring(err))
			end
		end
	end
	if CHAT_ROUTER and type(CHAT_ROUTER.RegisterCallback) == "function" then
		CHAT_ROUTER:RegisterCallback("FormattedChatMessage", function(...)
			pcall(OnFormattedChatMessage, ...)
		end)
	end
end

local ok, err = pcall(Install)
if not ok then
	addon.outgoingInstallError = tostring(err)
end
