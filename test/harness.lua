-- Stub of just enough ESO client to run PB's Translate outside the game.
--
-- CHAT_ROUTER is modelled on esoui/ingame/chatsystem/chathandlers.lua: a callback object whose
-- AddSystemMessage fires "FormattedChatMessage" with no raw text, and a channel message that
-- fires it with the raw text in fifth position. The chat window is a listener registered
-- before any add-on loads, as the client's own is.
local DIR = ADDON_DIR

-- ---- string table -------------------------------------------------------------------
local stringValues = {}
local nextId = 1
function ZO_CreateStringId(id, value) if not _G[id] then _G[id] = nextId; nextId = nextId + 1 end; stringValues[_G[id]] = value end
function SafeAddVersion() end
function GetString(id) return stringValues[id] or ("<missing " .. tostring(id) .. ">") end

-- ---- chat categories ----------------------------------------------------------------
CHAT_CATEGORY_SAY = 1
CHAT_CATEGORY_YELL = 2
CHAT_CATEGORY_ZONE = 3
CHAT_CATEGORY_ZONE_ENGLISH = 30
CHAT_CATEGORY_ZONE_JAPANESE = 31
CHAT_CATEGORY_WHISPER_INCOMING = 4
CHAT_CATEGORY_WHISPER_OUTGOING = 5
CHAT_CATEGORY_PARTY = 6
CHAT_CATEGORY_GUILD_1 = 10
CHAT_CATEGORY_SYSTEM = 20
CHAT_CATEGORY_MONSTER_SAY = 40

-- ---- events -------------------------------------------------------------------------
EVENT_ADD_ON_LOADED = "EVENT_ADD_ON_LOADED"
EVENT_PLAYER_ACTIVATED = "EVENT_PLAYER_ACTIVATED"
EVENT_CHAT_MESSAGE_CHANNEL = 100

local handlers = {}
EVENT_MANAGER = {
	RegisterForEvent = function(_, name, event, fn) handlers[event] = handlers[event] or {}; handlers[event][name] = fn end,
	UnregisterForEvent = function(_, name, event) if handlers[event] then handlers[event][name] = nil end end,
}
UpdateHandlers = {}
function EVENT_MANAGER:RegisterForUpdate(name, interval, fn) UpdateHandlers[name] = fn end
function EVENT_MANAGER:UnregisterForUpdate(name) UpdateHandlers[name] = nil end
function TickUpdates()
	local pending = {}
	for name, fn in pairs(UpdateHandlers) do pending[name] = fn end
	for name, fn in pairs(pending) do if UpdateHandlers[name] == fn then fn() end end
end
function Fire(event, ...) for _, fn in pairs(handlers[event] or {}) do fn(event, ...) end end

-- ---- chat ---------------------------------------------------------------------------
ChatWindow = {}   -- every line that reached the chat window, in order

CHAT_ROUTER = { callbacks = {} }
function CHAT_ROUTER:RegisterCallback(name, fn)
	self.callbacks[name] = self.callbacks[name] or {}
	table.insert(self.callbacks[name], fn)
end
function CHAT_ROUTER:FireCallbacks(name, ...)
	for _, fn in ipairs(self.callbacks[name] or {}) do fn(...) end
end
function CHAT_ROUTER:AddSystemMessage(text)
	self:FireCallbacks("FormattedChatMessage", text, CHAT_CATEGORY_SYSTEM, nil, nil, nil)
end

-- The client's chat window, registered first.
CHAT_ROUTER:RegisterCallback("FormattedChatMessage", function(message)
	ChatWindow[#ChatWindow + 1] = message
end)

-- Channel formatter pipeline: the real router formats before broadcasting to chat UIs.
CHAT_ROUTER.formatters = {}
function CHAT_ROUTER:GetRegisteredMessageFormatters() return self.formatters end
function CHAT_ROUTER:RegisterMessageFormatter(event, formatter) self.formatters[event] = formatter end
function ZO_ChatSystem_GetEventCategoryMappings()
	local categories = {}
	for i = 1, 40 do categories[i] = i end
	return { [EVENT_CHAT_MESSAGE_CHANNEL] = categories }, {}
end
CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, function(category, fromName, text, _, sender)
	return "[" .. tostring(fromName) .. "] " .. text, nil, sender, text
end)

-- What arrives when a player speaks.
function Speak(category, fromDisplayName, text)
	local formatted, target, sender, raw, narration, color = CHAT_ROUTER.formatters[EVENT_CHAT_MESSAGE_CHANNEL](
		category, fromDisplayName, text, false, fromDisplayName)
	if formatted then
		CHAT_ROUTER:FireCallbacks("FormattedChatMessage", formatted, category, target, sender, raw, narration, color)
	end
end

function ClearChat() ChatWindow = {} end
function d(text) ChatWindow[#ChatWindow + 1] = "[d] " .. tostring(text) end

SLASH_COMMANDS = {}

-- ---- the player ---------------------------------------------------------------------
InCyrodiil = false
function IsInCyrodiil() return InCyrodiil end
InImperialCity = false
function IsInImperialCity() return InImperialCity end

function GetDisplayName() return "@PinkBanther" end
function GetFrameTimeSeconds() return 0 end
function GetGroupSize() return 0 end

-- ---- add-on manager -----------------------------------------------------------------
function GetAddOnManager()
	return {
		GetNumAddOns = function() return 1 end,
		GetAddOnInfo = function(_, i) return "PBsTranslate", ManifestTitle end,
	}
end

-- ---- saved variables ----------------------------------------------------------------
SavedStore = {}
local function DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = DeepCopy(v) end
	return out
end
ZO_SavedVars = {
	NewAccountWide = function(_, name, version, namespace, defaults)
		SavedStore[name] = SavedStore[name] or {}
		local store = SavedStore[name]
		for k, v in pairs(defaults or {}) do if store[k] == nil then store[k] = DeepCopy(v) end end
		return store
	end,
}

-- ---- LibHarvensAddonSettings --------------------------------------------------------
PanelRows = {}
LibHarvensAddonSettings = {
	ST_COLOR = "color", ST_LABEL = "label", ST_SECTION = "section", ST_CHECKBOX = "checkbox", ST_SLIDER = "slider",
	ST_EDIT = "edit", ST_DROPDOWN = "dropdown", ST_BUTTON = "button",
	AddAddon = function(_, title)
		local panel = { title = title }
		function panel:AddSetting(row) PanelRows[#PanelRows + 1] = row end
		function panel:UpdateControls() end
		return panel
	end,
}

-- ---- load the add-on from its manifest ----------------------------------------------
-- English strings only; run.lua checks separately that jp.lua has the same keys.
ManifestFiles = {}
for line in io.lines(DIR .. "/PBsTranslate.addon") do
	local title = line:match("^## Title: (.*)$")
	if title then
		ManifestTitle = title
	end
	if not line:match("^##") and line:match("%S") then
		local file = line:gsub("%s+$", "")
		ManifestFiles[#ManifestFiles + 1] = file
		if not file:find("$(language)", 1, true) then
			dofile(DIR .. "/" .. file)
		end
	end
end

Fire(EVENT_ADD_ON_LOADED, "PBsTranslate")
