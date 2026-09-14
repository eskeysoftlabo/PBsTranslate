-- PBS_TRANSLATE_TEST is nil if Main.lua bailed out early (engine missing or already loaded).
if not PBS_TRANSLATE_TEST then
	return
end

local addon = PBS_TRANSLATE_TEST

-- Translation controls. Adding words needs typing, so that stays a chat command
-- (/pbtr add); the panel only says it exists.

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	local function Checkbox(key, label, tooltip)
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(label),
			tooltip = GetString(tooltip),
			default = self.DEFAULTS[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self.sv[key] = value
			end,
		})
	end

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_LABEL,
		label = GetString(SI_PBSTR_EXPLANATION),
	})

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = GetString(SI_PBSTR_ONLY),
		tooltip = GetString(SI_PBSTR_ONLY_TOOLTIP),
		default = self.DEFAULTS.translationOnly,
		getFunction = function() return self.sv.translationOnly end,
		setFunction = function(value) self:SetTranslationOnly(value) end,
	})

	Checkbox("enabled", SI_PBSTR_ENABLED, SI_PBSTR_ENABLED_TOOLTIP)
	Checkbox("translateOwn", SI_PBSTR_OWN, SI_PBSTR_OWN_TOOLTIP)
	Checkbox("translateOthers", SI_PBSTR_OTHERS, SI_PBSTR_OTHERS_TOOLTIP)
	Checkbox("translateZone", SI_PBSTR_ZONE, SI_PBSTR_ZONE_TOOLTIP)

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = GetString(SI_PBSTR_KNOWN),
		tooltip = GetString(SI_PBSTR_KNOWN_TOOLTIP),
		min = 0,
		max = 100,
		step = 5,
		format = "%d",
		unit = "%",
		default = self.DEFAULTS.minKnownPercent,
		getFunction = function()
			return self.sv.minKnownPercent
		end,
		setFunction = function(value)
			self.sv.minKnownPercent = value
		end,
	})

	if LibHarvensAddonSettings.ST_COLOR then
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_COLOR,
			label = GetString(SI_PBSTR_COLOR),
			tooltip = GetString(SI_PBSTR_COLOR_TOOLTIP),
			default = { self:GetTranslationRGB(self.DEFAULTS.color) },
			getFunction = function() return self:GetTranslationRGB() end,
			setFunction = function(r, g, b) self:SetTranslationRGB(r, g, b) end,
		})
	end

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
		label = GetString(SI_PBSTR_SECTION_WORDS),
	})

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_LABEL,
		label = string.format(GetString(SI_PBSTR_WORDS_NOTE), self.engine.entryCount or 0),
	})
end
