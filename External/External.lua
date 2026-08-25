local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.loca;

-- Mixin to create an external add-on addition
WQT_ExternalMixin = {};

function WQT_ExternalMixin:GetName()
	return self.name;
end

function WQT_ExternalMixin:GetRequiredEvents()
	-- Override me
	return {};
end

function WQT_ExternalMixin:CreateEnabledCheckCall(func, settingName)
	settingName = settingName or "enabled";
	return function(...)
		if (self.activeSettings and not self.activeSettings[settingName]) then return; end
		func(...);
	end
end

function WQT_ExternalMixin:GenerateBasicSettings(label)
	local category = self:GenerateSettingsCategory(label);
	self:GenerateEnableSetting(category);
end

function WQT_ExternalMixin:GenerateSettingsCategory(label)
	label = label or self:GetName();
	return WQT_SettingsFrame.dataContainer:AddCategory(string.upper(self:GetName()), label, false);
end

function WQT_ExternalMixin:GenerateEnableSetting(category, settingName)
	settingName = settingName or "enabled";
	local settings = self.activeSettings;
	if (not settings or type(settings[settingName]) == "nil") then
		error(string.format("Couldn't generate enable setting using settingName: %s", settingName));
	end
	local tag = string.format("%s_ENABLE", string.upper(self:GetName()));
	local data = category:AddCheckbox(tag, _L:Get("ENABLE_EXTERNAL"), _L:Get("ENABLE_EXTERNAL_TT"));
	data:SetGetValueFunction(function() return settings[settingName]; end);
	data:SetValueChangedFunction(function(value) settings[settingName] = value; end);
	data:MarkAsSuggestReload();
	return data;
end

function WQT_ExternalMixin:Init(name, defaultSettings)
	self.name = name;
	self.activeSettings = nil;
	self.defaultSettings = defaultSettings;

	WQT:AddExternal(self);
end

function WQT_ExternalMixin:Load()
	if (self.defaultSettings) then
		self.activeSettings = WQT_Utils:RegisterExternalSettings(self.name, self.defaultSettings);
	end
	self:OnLoad();
end

function WQT_ExternalMixin:OnLoad()
	-- Override me
end