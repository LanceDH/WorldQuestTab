local name = "ZygorGuidesViewer";
local addonName, addon = ...
local WQT = addon.WQT;
local _V = addon.variables;

local function ScheduledQuest(questID)
	local mapID = C_TaskQuest.GetQuestZoneID(questID);
	ZGV.WorldQuests:SuggestWorldQuestGuide(nil, questID ,true, mapID);
end

local function OnQuestClickHandled(source, handleType, frame, questInfo, button)
	local questHandleEnum = _V:GetQuestHandleTypeEnum();
	if (handleType ~= questHandleEnum.watched) then return; end

	-- Seems this is how you solve shift clicking not marking the actual quest location
	ZGV:ScheduleTimer(ScheduledQuest, 0, questInfo.questID);
end

local shouldHighlight = true;
local highlightedQuestID = nil;
local poiDisabled = true;

local function OnHighlightShow(source, row)
	if (poiDisabled) then return; end

	ZGV.WorldQuests.Highlight:Hide();

	local questID = row and row.questID;
	if (not questID or questID == highlightedQuestID) then return; end
	
	if (highlightedQuestID) then
		WQT_CallbackRegistry:TriggerEvent("WQT.QuestListButtonMouseEnter", highlightedQuestID, not shouldHighlight);
	end
	
	WQT_CallbackRegistry:TriggerEvent("WQT.QuestListButtonMouseEnter", row.questID, shouldHighlight);
	highlightedQuestID = row.questID;
end

local function OnHighlightHide(source)
	if (poiDisabled) then return; end

	if (highlightedQuestID) then
		WQT_CallbackRegistry:TriggerEvent("WQT.QuestListButtonMouseEnter", highlightedQuestID, not shouldHighlight);
		highlightedQuestID = nil;
	end
end

local function OnSettinChanged(source, category, tag)
	if (tag == "PIN_DISABLE_CHANGES") then
		OnHighlightHide();
		poiDisabled = WQT_Utils:GetSetting("pin", "disablePoI");
	end
end


local ZygorExternal = CreateFromMixins(WQT_ExternalMixin);

function ZygorExternal:GetName()
	return name;
end

function ZygorExternal:Init()
	poiDisabled = WQT_Utils:GetSetting("pin", "disablePoI");

	WQT_CallbackRegistry:RegisterCallback("WQT.QuestClickHandled", OnQuestClickHandled, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged", OnSettinChanged,self);

	hooksecurefunc(ZGV.WorldQuests, "HighlightShow", OnHighlightShow);
	hooksecurefunc(ZGV.WorldQuests, "HighlightHide", OnHighlightHide);
end

WQT:AddExternal(ZygorExternal);