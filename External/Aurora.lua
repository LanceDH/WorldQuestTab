local name = "Aurora";
if (not WQT_Utils:ExternalMightLoad(name)) then return; end

local addonName, addon = ...
local WQT = addon.WQT;

local function BackgroundUpdated()
	WQT_ListContainer.Background:SetAlpha(0);
	WQT_SettingsFrame.Background:SetAlpha(0);
end

local AuroraExternal = CreateFromMixins(WQT_ExternalMixin);

function AuroraExternal:GetName()
	return name;
end

function AuroraExternal:Init()
	WQT_CallbackRegistry:RegisterCallback("WQT.ScrollList.BackgroundUpdated", BackgroundUpdated, self);

	WQT_FlightMapContainerBg:SetColorTexture(0,0,0,0.75);
end

WQT:AddExternal(AuroraExternal);
