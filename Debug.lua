local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;


------------------------
-- DEBUGGING
------------------------
function WQT:debugPrint(...)
	if (addon.debugPrint) then 
		print("WQT", ...);
	end
end

local function AddIndentedDoubleLine(tooltip, a, b, level, color)
	local indented = string.rep("    ", level) .. a;
	if (type(b) == "table" and b.GetRGBA) then
		b = floor(b.r*100)/100 .. "/" ..  floor(b.g*100)/100 .. "/" ..  floor(b.b*100)/100;
	elseif (type(b) == "table" and b.GetXY) then
		b = "{" ..floor(b.x*100)/100 .. " | " .. floor(b.y*100)/100 .. "}";
	elseif (type(b) == "boolean") then
		b = b and "true" or "false";
	elseif  (type(a) == "string" and a:find("Bits") and type(b) == "number" and b > 0) then
		local bits = b;
		local o = "";
		local index = 0;
		while (bits > 0) do
			local rest = bits% 2
			if (rest > 0) then
				o = o .. (o == "" and "" or ", ") .. index;
			end
			bits = (bits - rest) / 2
			index = index + 1;
		end
		b = string.format("%s (%s)", b, o);
	elseif (b == nil) then
		b = "nil";
	end
	tooltip:AddDoubleLine(indented, b, color.r, color.g, color.b, color.r, color.g, color.b);
end

local function KeySortFunc(a, b)
	return a < b;
end

function WQT:AddDebugToTooltip(tooltip, questInfo, level)
	if (not addon.debug) then return end;
	level = level or 0;
	local color = LIGHTBLUE_FONT_COLOR;
	if(level == 0) then
		AddIndentedDoubleLine(tooltip, "questInfo data:", "", 0, color);
	end

	-- First all non table values;
	local sortedKeys = {}
	for key, value in pairs(questInfo) do
		if ((type(value) ~= "table" or value.GetRGBA) and type(value) ~= "function") then
			tinsert(sortedKeys, key);
		end
	end
	table.sort(sortedKeys, KeySortFunc);
	for _, key in ipairs(sortedKeys) do
		AddIndentedDoubleLine(tooltip, key, questInfo[key], level+1, color);
	end
	wipe(sortedKeys);

	-- Actual tables
	for key, value in pairs(questInfo) do
		if (type(value) == "table" and not value.GetRGBA and key ~= "debug") then
			tinsert(sortedKeys, key);
		end
	end

	table.sort(sortedKeys, KeySortFunc);
	for _, key in ipairs(sortedKeys) do
		AddIndentedDoubleLine(tooltip, key, "", level+1, color);
		self:AddDebugToTooltip(tooltip, questInfo[key], level + 1)
	end

	if(level == 0 and questInfo.questID) then
		color = GRAY_FONT_COLOR;
		
		AddIndentedDoubleLine(tooltip, "Through functions:", "", 0, color);
		
		local classifictaion = C_QuestInfoSystem.GetQuestClassification(questInfo.questID)
		AddIndentedDoubleLine(tooltip, "classifictaion", classifictaion, 1, color);
		local difficultyLevel = C_QuestLog.GetQuestDifficultyLevel(questInfo.questID);
		AddIndentedDoubleLine(tooltip, "difficultyLevel", difficultyLevel, 1, color);
		local expLevel = GetQuestExpansion(questInfo.questID);
		AddIndentedDoubleLine(tooltip, "expansion", expLevel, 1, color);
		-- Time
		local seconds, timeString, timeColor, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo, true, true);
		AddIndentedDoubleLine(tooltip, "time", "", 1, color);
		AddIndentedDoubleLine(tooltip, "seconds", seconds, 2, color);
		AddIndentedDoubleLine(tooltip, "timeString", timeString, 2, color);
		AddIndentedDoubleLine(tooltip, "color", timeColor, 2, color);
		AddIndentedDoubleLine(tooltip, "timeStringShort", timeStringShort, 2, color);
		AddIndentedDoubleLine(tooltip, "isExpired", questInfo:IsExpired(), 2, color);
		-- Faction
		local factionInfo = WQT_Utils:GetFactionDataInternal(questInfo.factionID);
		AddIndentedDoubleLine(tooltip, "faction", "", 1, color);
		AddIndentedDoubleLine(tooltip, "name", factionInfo.name, 2, color);
		AddIndentedDoubleLine(tooltip, "playerFaction", factionInfo.playerFaction, 2, color);
		AddIndentedDoubleLine(tooltip, "texture", factionInfo.texture, 2, color);
		AddIndentedDoubleLine(tooltip, "expansion", factionInfo.expansion, 2, color);
		-- MapInfo
		local mapInfo = WQT_Utils:GetCachedMapInfo(questInfo.mapID);
		AddIndentedDoubleLine(tooltip, "mapInfo", "", 1, color);
		if (mapInfo) then
			AddIndentedDoubleLine(tooltip, "name", mapInfo.name, 2, color);
			AddIndentedDoubleLine(tooltip, "mapID", mapInfo.mapID, 2, color);
			AddIndentedDoubleLine(tooltip, "parentMapID", mapInfo.parentMapID, 2, color);
			AddIndentedDoubleLine(tooltip, "mapType", mapInfo.mapType, 2, color);
		else
			AddIndentedDoubleLine(tooltip, "Map info missing", "", 2, color);
		end
	end
end

function WQT:ShowDebugTooltipForQuest(questInfo, anchor)
	if (not addon.debug) then return end;
	WQT_DebugTooltip:SetOwner(anchor, "ANCHOR_LEFT");
	WQT_DebugTooltip:SetText("Debug Info");
	self:AddDebugToTooltip(WQT_DebugTooltip, questInfo)
	WQT_DebugTooltip:Show();
end

function WQT:HideDebugTooltip()
	WQT_DebugTooltip:Hide();
end

------------------------
-- OUTPUT DUMP
------------------------

local URL_CURSEFORGE = "https://www.curseforge.com/wow/addons/worldquesttab/issues"
local URL_WOWI = "https://www.wowinterface.com/downloads/info25042-WorldQuestTab.html"

-- regionID, locale, textLocale, playerFaction, map, coords, addonVersion
local FORMAT_PLAYER = "%d;%s;%s;%s;%d;%s;%s\n";
local FORMAT_QUEST_HEADER = "Quests;%d;%d\nQuestId;Counted;Frequency;IsTask;IsBounty;IsHidden\n"
local FORMAT_QUEST = "%s%d;%d;%s;%s;%s\n"
local FORMAT_WORLDQUEST_HEADER = "World Quests;%d\nQuestId;MapId;PassedFilter;IsValid;AlwaysHide;Seconds;RewardBits\n";
local FORMAT_WORLDQUEST = "%s%d;%d;%s;%s;%s;%d;%d\n"
-- output, name
local FORMAT_ADDON = "%s%s\n"
-- ouput, indentation, key, value
local FORMAT_TABLE_VALUE = "%s%s%s = %s\n";

local function bts(bool)
	return bool and "Y" or "N";
end

local function GetQuestDump()
	local removedQuests = {};
	local counted, limit = WQT_Utils:GetQuestLogInfo(removedQuests);
	local output = FORMAT_QUEST_HEADER:format(counted, limit);
	
	local numEntries = C_QuestLog.GetNumQuestLogEntries();
	for index = 1, numEntries do
		local info = C_QuestLog.GetInfo(index);
		if (not info.isHeader) then
			output = FORMAT_QUEST:format(output, info.questID, info.frequency, bts(info.isTask), bts(info.isBounty), bts(info.isHidden));
		end
	end
	
	return output;
end

local function GetWorldQuestDump()
	local mapID = WorldMapFrame:GetMapID() or  0;
	local output = FORMAT_WORLDQUEST_HEADER:format(mapID);
	
	local list = WQT_WorldQuestFrame.dataProvider:GetIterativeList();
	for k, questInfo in ipairs(list) do
		output = FORMAT_WORLDQUEST:format(output, questInfo.questID, questInfo.mapID, bts(questInfo.passedFilter), bts(questInfo.isValid), bts(questInfo.alwaysHide), questInfo.time.seconds, questInfo.reward.typeBits);
	end
	
	return output;
end

local function GetPlayerDump()
	local version = C_AddOns.GetAddOnMetadata(addonName, "version");
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
	
	for i = 1, C_AddOns.GetNumAddOns() do
		if (C_AddOns.IsAddOnLoaded(i)) then
			output = FORMAT_ADDON:format(output, C_AddOns.GetAddOnInfo(i));
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

function WQT_DebugFrameMixin:OnUpdate()

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
	
	self:Show();
end




WQT_DevMixin = {};

function WQT_DevMixin:OnLoad()
	self:RegisterEvent("TAXIMAP_OPENED");

	self:SetScript("OnEvent", function(self, event, ...)
			if (self[event]) then 
				self[event](self, ...);
			end
		end)

	EventRegistry:RegisterCallback("MapCanvas.MapSet",
		function(_, mapID)
			self.worldMapID:SetText(string.format("WorldMap: %s", WorldMapFrame.mapID or 0));
		end, 
		self);
end

function WQT_DevMixin:TAXIMAP_OPENED()
	self.flightMapID:SetText(string.format("FlightMap: %s", FlightMapFrame.mapID or 0));
end

function WQT_DevMixin:OnUpdate()
	if (not self:IsShown()) then return end;

	if (WorldMapFrame:IsShown()) then
		self.worldMapMousePos:SetText(string.format("WorldMapMouse: %.2f %.2f", WorldMapFrame:GetNormalizedCursorPosition()));
	end
end

function WQT_DevMixin:DoDebugThing()
	
end
