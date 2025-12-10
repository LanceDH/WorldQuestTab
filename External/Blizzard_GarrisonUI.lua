-------------------------------------------------------------------------------------------------------------------
-- This hooks into the tooltip display when hovering over callings in the garrison page
-- If a calling is available or active, it will instead show the default WQT tooltip, providing more information.
-------------------------------------------------------------------------------------------------------------------

local name = "Blizzard_GarrisonUI";
local addonName, addon = ...
local WQT = addon.WQT;

local _hookedCallingsUpdate = false;
local _hookedDisplays = {};

local TOOLTIP_STYLE_NO_OBJECTIVE = {["hideObjectives"] = true;}
local TOOLTIP_STYLE_NO_TYPE = {["hideType"] = true;}

local function ShowCustomTooltip(display)
	if (WQT_Utils:GetSetting("pin", "disablePoI")) then
		return;
	end

	-- Look for quest info in the callings board
	local questInfo, calling = WQT_CallingsBoard:GetQuestData(display.questID);
	-- If we got the info, replace the tooltip
	if (questInfo and calling) then
		GameTooltip:Hide();
		if (calling:IsActive()) then
			WQT_Utils:ShowQuestTooltip(display, questInfo, TOOLTIP_STYLE_NO_TYPE);
		else
			WQT_Utils:ShowQuestTooltip(display, questInfo, TOOLTIP_STYLE_NO_OBJECTIVE);
		end
	end
end

local function HookDisplays()
	for display in GarrisonLandingPage.CovenantCallings.pool:EnumerateActive() do
		if (not _hookedDisplays[display]) then
			-- I could hook into 'UpdateTooltip' but don't want to redo the 'X days until new calling' tooltip
			hooksecurefunc(display, "UpdateTooltipQuestActive", function() ShowCustomTooltip(display); end)
			hooksecurefunc(display, "UpdateTooltipQuestOffer", function() ShowCustomTooltip(display); end)
			
			_hookedDisplays[display] = true;
		end
	end
end

local function HookCallingsUpdate()
	if (_hookedCallingsUpdate or not GarrisonLandingPage.CovenantCallings) then
		return;
	end
	
	hooksecurefunc(GarrisonLandingPage.CovenantCallings, "OnCovenantCallingsUpdated", HookDisplays);
	_hookedCallingsUpdate = false;
end

local ExampleExternal = CreateFromMixins(WQT_ExternalMixin);

function ExampleExternal:GetName()
	return name;
end

function ExampleExternal:Init()
	hooksecurefunc(GarrisonLandingPage, "SetupCovenantCallings", HookCallingsUpdate);
end

WQT:AddExternal(ExampleExternal);



