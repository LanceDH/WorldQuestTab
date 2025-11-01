local addonName, addon = ...

local _L = addon.L;

local function BackgroundUpdated()
	WQT_ListContainer.Background:SetAlpha(0);
	WQT_SettingsFrame.Background:SetAlpha(0);
end

local AuroraExternal = CreateFromMixins(WQT_ExternalMixin);

function AuroraExternal:GetName()
	return "Aurora";
end

function AuroraExternal:Init(utils)
	WQT_CallbackRegistry:RegisterCallback("WQT.ScrollList.BackgroundUpdated", BackgroundUpdated, self);

	WQT_FlightMapContainerBg:SetColorTexture(0,0,0,0.75);
end

WQT_WorldQuestFrame:LoadExternal(AuroraExternal);
