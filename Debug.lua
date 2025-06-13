local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;


------------------------
-- DEBUGGING
------------------------

local _debugTable;
if (addon.debug and LDHDebug) then
	LDHDebug:Monitor(addonName);
end

function WQT:debugPrint(...)
	if (addon.debug) then 
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

function WQT:AddDebugToTooltip(tooltip, questInfo, level)
	if (not addon.debug) then return end;
	level = level or 0;
	local color = LIGHTBLUE_FONT_COLOR;
	if(level == 0) then
		AddIndentedDoubleLine(tooltip, "questInfo data:", "", 0, color);
	end
	
	-- First all non table values;
	for key, value in pairs(questInfo) do
		if ((type(value) ~= "table" or value.GetRGBA) and type(value) ~= "function") then
			AddIndentedDoubleLine(tooltip, key, value, level+1, color);
		end
	end
	-- Actual tables
	for key, value in pairs(questInfo) do
		if (type(value) == "table" and not value.GetRGBA and key ~= "debug") then
			AddIndentedDoubleLine(tooltip, key, "", level+1, color);
			self:AddDebugToTooltip(tooltip, value, level + 1)
		end
	end
	
	if(level == 0 and questInfo.questId) then
		color = GRAY_FONT_COLOR;
		
		AddIndentedDoubleLine(tooltip, "Through functions:", "", 0, color);
		local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
		AddIndentedDoubleLine(tooltip, "title", title, 1, color);
		
		local classifictaion = C_QuestInfoSystem.GetQuestClassification(questInfo.questId)
		AddIndentedDoubleLine(tooltip, "classifictaion", classifictaion, 1, color);
		-- Time
		local seconds, timeString, timeColor, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo, true, true);
		AddIndentedDoubleLine(tooltip, "time", "", 1, color);
		AddIndentedDoubleLine(tooltip, "seconds", seconds, 2, color);
		AddIndentedDoubleLine(tooltip, "timeString", timeString, 2, color);
		AddIndentedDoubleLine(tooltip, "color", timeColor, 2, color);
		AddIndentedDoubleLine(tooltip, "timeStringShort", timeStringShort, 2, color);
		AddIndentedDoubleLine(tooltip, "isExpired", questInfo:IsExpired(), 2, color);
		-- Faction
		local factionInfo = WQT_Utils:GetFactionDataInternal(factionId);
		AddIndentedDoubleLine(tooltip, "faction", "", 1, color);
		AddIndentedDoubleLine(tooltip, "factionId", factionId, 2, color);
		AddIndentedDoubleLine(tooltip, "name", factionInfo.name, 2, color);
		AddIndentedDoubleLine(tooltip, "playerFaction", factionInfo.playerFaction, 2, color);
		AddIndentedDoubleLine(tooltip, "texture", factionInfo.texture, 2, color);
		AddIndentedDoubleLine(tooltip, "expansion", factionInfo.expansion, 2, color);
		-- MapInfo
		local mapInfo = WQT_Utils:GetMapInfoForQuest(questInfo.questId);
		if (questInfo.mapinfo) then
			AddIndentedDoubleLine(tooltip, "mapInfo", "", 1, color);
			AddIndentedDoubleLine(tooltip, "name", mapInfo.name, 2, color);
			AddIndentedDoubleLine(tooltip, "mapID", mapInfo.mapID, 2, color);
			AddIndentedDoubleLine(tooltip, "parentMapID", mapInfo.parentMapID, 2, color);
			AddIndentedDoubleLine(tooltip, "mapType", mapInfo.mapType, 2, color);
			local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(mapInfo.mapID, CreateVector2D(questInfo.mapInfo.mapX, questInfo.mapInfo.mapY))
			AddIndentedDoubleLine(tooltip, "continentID", continentID, 2, color);
			AddIndentedDoubleLine(tooltip, "worldPosition.x", worldPosition.x, 2, color);
			AddIndentedDoubleLine(tooltip, "worldPosition.y", worldPosition.x, 2, color);
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
	local removedQuests = {};
	local counted, limit = WQT_Utils:GetQuestLogInfo(removedQuests);
	local output = FORMAT_QUEST_HEADER:format(counted, limit);
	
	local numEntries = C_QuestLog.GetNumQuestLogEntries();
	for index = 1, numEntries do
		local info = C_QuestLog.GetInfo(index);
		local counted = WQT_Utils:QuestCountsToCap(index);
		if (not info.isHeader) then
			output = FORMAT_QUEST:format(output, info.questID, bts(counted), info.frequency, bts(info.isTask), bts(info.isBounty), bts(info.isHidden));
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


function WQT_DebugFrameMixin:DoDebugThing()
	print("Debug");

	-- local timeStart = GetTimePreciseSec();
	-- for contID in pairs(_V["WQT_ZONE_MAPCOORDS"][947]) do
	-- 	-- Every ID is a continent, get every zone on every continent
	-- 	local continentZones = _V["WQT_ZONE_MAPCOORDS"][contID];
	-- 	for zoneID  in pairs(continentZones) do
	-- 		local quests = C_TaskQuest.GetQuestsOnMap(zoneID);
	-- 		print(zoneID, quests and #quests or "nil");
	-- 	end
	-- end

	-- print(GetTimePreciseSec() - timeStart);`

	-- WQT_Test.done = 1;
	local dataprovider = WQT_WorldQuestFrame.dataProvider;

	local list = {}
	for k, v in ipairs(C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Zone, true)) do
		list[v.mapID] = true;
		
	end
	for k, v in ipairs(C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Orphan, true)) do
		list[v.mapID] = true;
	end

	local count = 0;
	for zoneID in pairs(list) do
		dataprovider:AddZoneToBuffer(zoneID);
		count = count + 1;
	end

	print("Sent", count);
	--for k, v in ipairs(C_Map.GetMapChildrenInfo(WorldMapFrame.mapID)) do print(string.format("  %s: %s (%s)",v.mapType, v.name, v.mapID)) end


	-- local mapID = WorldMapFrame.mapID;
	-- print(mapID);
	-- local childInfo = C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone, true);

	-- for k, v in ipairs(childInfo) do
	-- 	print(string.format("  %s: %s (%s)",v.mapType, v.name, v.mapID))
	-- end

	if true then return end


	for k, v in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Orphan, true)) do
		tinsert(childInfo, v);
	end
	-- for k, v in ipairs(C_Map.GetMapChildrenInfo(WorldMapFrame.mapID)) do print(string.format("  %s: %s (%s)",v.mapType, v.name, v.mapID)) end
	local yes = {};
	local no = {};
	local questInfo = {};
	for k, v in pairs(childInfo) do
		local x,x2=C_Map.GetMapRectOnMap(v.mapID, mapID);
		local accept = false;
		--if(v.mapType == Enum.UIMapType.Zone or v.mapType == Enum.UIMapType.Orphan) then
			accept = true;
		--end

		tinsert(accept and yes or no, v);
	end

	print("Yes");
	for _, v in pairs(yes) do
		local quests = C_TaskQuest.GetQuestsOnMap(v.mapID);
		if (quests and #quests > 0) then
			for _, quest in ipairs(quests) do
				if (not questInfo[quest.questID]) then
					C_TaskQuest.GetQuestZoneID(quest.questID)
					local info = { ["questID"] = quest.questID, ["mapID"] = v.mapID };

					questInfo[quest.questID] = info;
				end
					
			end
			
		end
		print(string.format("  %s: %s (%s) -> %s",v.mapType, v.name, v.mapID, quests and #quests or "nil"));
	end

	-- print("No");
	-- for k, v in pairs(no) do
	-- 	print(string.format("  %s: %s (%s)",v.mapType, v.name, v.mapID));
	-- end

	print("quests");
	local questCount = 0;
	for k, v in pairs(questInfo) do
		questCount = questCount + 1;
		print(v.questID, v.mapID);
	end

	print(#childInfo, questCount);
end
