local name = "Aurora";
local addonName, addon = ...

local function BackgroundUpdated()
	WQT_ListContainer.Background:SetAlpha(0);
	WQT_SettingsFrame.Background:SetAlpha(0);
end

local AuroraExternal = CreateAndInitFromMixin(WQT_ExternalMixin, name);

function AuroraExternal:OnLoad()
	WQT_CallbackRegistry:RegisterCallback("WQT.ScrollList.BackgroundUpdated", BackgroundUpdated, self);

	WQT_FlightMapContainerBg:SetColorTexture(0,0,0,0.75);
end
