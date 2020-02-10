local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-1.0");
local WQT_Utils = addon.WQT_Utils;


local URL_CURSEFORGE = "https://www.curseforge.com/wow/addons/worldquesttab/issues"
local URL_WOWI = "https://www.wowinterface.com/downloads/info25042-WorldQuestTab.html"

-- regionID, locale, textLocale, playerFaction, map, coords, addonVersion
local FORMAT_PLAYER = "%d;%s;%s;%s;%d;%s;%s\n";
local FORMAT_QUEST_HEADER = "Quests;%d;%d\nQuestId;Counted;Frequency;IsTask;IsBounty;IsHidden\n"
local FORMAT_QUEST = "%s%d;%s;%d;%s;%s;%s\n"
local FORMAT_WORLDQUEST_HEADER = "World Quests;%d\nQuestId;MapId;PassedFilter;IsValid;AlwaysHide;IsDaily;IsAllyQuest;Seconds;RewardBits\n";
local FORMAT_WORLDQUEST = "%s%d;%d;%s;%s;%s;%s;%s;%d;%d\n"
-- output, name
local FORMAT_ADDON = "%s%s\n"
-- ouput, indentation, key, value
local FORMAT_TABLE_VALUE = "%s%s%s = %s\n";

local function bts(bool)
	return bool and "Y" or "N";
end

local function GetQuestDump()
	local counted, limit = WQT_Utils:GetQuestLogInfo(hiddenList)
	local output = FORMAT_QUEST_HEADER:format(counted, limit);
	
	local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling;
	local numEntries = GetNumQuestLogEntries();
	for index = 1, numEntries do
		title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(index);
		local counted = WQT_Utils:QuestCountsToCap(index);
		if (not isHeader) then
			output = FORMAT_QUEST:format(output, questID, bts(counted), frequency, bts(isTask), bts(isBounty), bts(isHidden));
		end
	end
	
	return output;
end

local function GetWorldQuestDump()
	local mapID = WorldMapFrame:GetMapID() or  0;
	local output = FORMAT_WORLDQUEST_HEADER:format(mapID);
	
	local list = WQT_WorldQuestFrame.dataProvider:GetIterativeList();
	for k, questInfo in ipairs(list) do
		local title = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
		local mapInfo = WQT_Utils:GetMapInfoForQuest(questInfo.questId)
		output = FORMAT_WORLDQUEST:format(output, questInfo.questId, mapInfo.mapID, bts(questInfo.passedFilter), bts(questInfo.isValid), bts(questInfo.alwaysHide), bts(questInfo.isDaily), bts(questInfo.isAllyQuest), questInfo.time.seconds, questInfo.reward.typeBits);
	end
	
	return output;
end

local function GetPlayerDump()
	local version = GetAddOnMetadata(addonName, "version");
	local map = C_Map.GetBestMapForUnit("player");
	local coords = nil;
	if (map) then
		local pos = C_Map.GetPlayerMapPosition(map, "player");
		coords = string.format("%.2f,%.2f", pos.x, pos.y);
	end
	local output = FORMAT_PLAYER:format(GetCurrentRegion(), GetLocale(), C_CVar.GetCVar("textLocale"), UnitFactionGroup("player"), map, coords, version);
	return output;
end

local function LoopTableValues(output, t, level)
	local indented = string.rep("    ", level);
	for k, v in pairs(t) do
		if (type(v) ~= "table") then
			output = FORMAT_TABLE_VALUE:format(output, indented, k, tostring(v));
		end
	end
	for k, v in pairs(t) do
		if (type(v) == "table") then
			output = output .. indented .. k .."\n"
			output = LoopTableValues(output, v, level+1);
		end
	end
	return output;
end

local function GetSettingsDump()
	local output = "Settings\n";
	
	output = LoopTableValues(output, WQT.settings, 0);
	
	return output;
end

local function GetAddonDump()
	local output = "Addons\n";
	
	for i = 1, GetNumAddOns() do
		if (IsAddOnLoaded(i)) then
			output = FORMAT_ADDON:format(output, GetAddOnInfo(i));
		end
	end
	
	return output;
end

local function GetOutputTypeFromString(s)
	if (s == "s") then
		return _V["DEBUG_OUTPUT_TYPE"].setting;
	elseif (s == "q") then
		return _V["DEBUG_OUTPUT_TYPE"].quest;
	elseif (s == "wq") then
		return _V["DEBUG_OUTPUT_TYPE"].worldQuest;
	elseif (s == "a") then
		return _V["DEBUG_OUTPUT_TYPE"].addon;
	end
	return _V["DEBUG_OUTPUT_TYPE"].invalid;
end


WQT_DebugFrameMixin = {};

function WQT_DebugFrameMixin:OnLoad()
	self.CurseURL:SetText(URL_CURSEFORGE);
	self.WoWIURL:SetText(URL_WOWI);
end

function WQT_DebugFrameMixin:DumpDebug(input)
	
	local outputType = input;
	if (type(outputType) == "string") then
		outputType = GetOutputTypeFromString(input);
	end
	
	if (outputType == _V["DEBUG_OUTPUT_TYPE"].invalid) then
		print("Usage: /wqt dump <type> where <type> is:");
		print("s: Settings");
		print("q: Normal quests");
		print("wq: World Quests (current map)");
		print("a: Enabled Add-ons");
		return;
	end

	local text = GetPlayerDump();
	
	if (outputType == _V["DEBUG_OUTPUT_TYPE"].quest) then
		text = text .. GetQuestDump();
	elseif (outputType == _V["DEBUG_OUTPUT_TYPE"].worldQuest) then
		text = text .. GetWorldQuestDump();
	elseif (outputType == _V["DEBUG_OUTPUT_TYPE"].setting) then
		text = text .. GetSettingsDump();
	elseif (outputType == _V["DEBUG_OUTPUT_TYPE"].addon) then
		text = text .. GetAddonDump();
	end

	self.DumpFrame.EditBox:SetText(text);
	OpenWorldMap();
	WQT_WorldQuestFrame:SelectTab(WQT_TabWorld); 
	WQT_WorldQuestFrame:ShowOverlayFrame(self);
end
