local name = "ZygorGuidesViewer";
local addonName, addon = ...
local _V = addon.variables;
local _L = addon.loca;

local function ScheduledQuest(questID)
	local mapID = C_TaskQuest.GetQuestZoneID(questID);
	ZGV.WorldQuests:SuggestWorldQuestGuide(nil, questID ,true, mapID);
end

local function OnQuestWatchChanged(source, questInfo)
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

local function OnSettinChanged(source, category, tag, value)
	if (tag == "PIN_DISABLE_CHANGES") then
		OnHighlightHide();
		poiDisabled = value;
	end
end


local _defaultSettings = {
		enabled = true;
	};

local ZygorExternal = CreateAndInitFromMixin(WQT_ExternalMixin, name, _defaultSettings);

function ZygorExternal:OnLoad()
	-- Add options to settings menu
	self:GenerateBasicSettings("Zygore Guides");

	poiDisabled = WQT_Utils:GetSetting("pin", "disablePoI");

	WQT_CallbackRegistry:RegisterCallback("WQT.QuestWatchChanged", self:CreateEnabledCheckCall(OnQuestWatchChanged), self);
	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged", self:CreateEnabledCheckCall(OnSettinChanged),self);

	hooksecurefunc(ZGV.WorldQuests, "HighlightShow", self:CreateEnabledCheckCall(OnHighlightShow));
	hooksecurefunc(ZGV.WorldQuests, "HighlightHide", self:CreateEnabledCheckCall(OnHighlightHide));
end
