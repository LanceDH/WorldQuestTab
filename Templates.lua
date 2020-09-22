local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-1.0");
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

--------------------------------
-- WQT_MiniIconMixin
--------------------------------

WQT_MiniIconMixin = {};

function WQT_MiniIconMixin:Reset()
	self:Hide();
	
	self.Icon:Show();
	self.Icon:SetTexture(nil);
	self.Icon:SetScale(1);
	self.Icon:SetTexCoord(0, 1, 0, 1);
	self.Icon:SetVertexColor(1, 1, 1);
	
	self.BG:Show();
	self.BG:SetTexture("Interface/GLUES/Models/UI_MainMenu_Legion/UI_Legion_Shadow");
	self.BG:SetScale(1);
	self.BG:SetVertexColor(1, 1, 1);
	self.BG:SetAlpha(0.75);
end

function WQT_MiniIconMixin:SetIconColor(color)
	self.Icon:SetVertexColor(color:GetRGB());
end

function WQT_MiniIconMixin:SetIconCoords(left, right, top, bottom)
	self.Icon:SetTexCoord(left, right, top, bottom);
end

function WQT_MiniIconMixin:SetIconScale(scale)
	self.Icon:SetScale(scale);
end

function WQT_MiniIconMixin:SetBackgroundShown(value)
	self.BG:SetShown(value);
end

function WQT_MiniIconMixin:SetupIcon(texture, left, right, top, bottom)
	self:Reset();
	
	if (not texture) then return; end
	
	if (left) then
		self.Icon:SetTexture(texture);
		self.Icon:SetTexCoord(left, right, top, bottom);
	else
		self.Icon:SetAtlas(texture);
	end
end

function WQT_MiniIconMixin:SetupRewardIcon(rewardType)
	self:Reset();
	
	if(not rewardType) then return; end
	
	local rewardTypeAtlas = _V["REWARD_TYPE_ATLAS"][rewardType];
	if (rewardTypeAtlas) then
		if (rewardTypeAtlas.l) then
			self.Icon:SetTexture(rewardTypeAtlas.texture);
			self.Icon:SetTexCoord(rewardTypeAtlas.l, rewardTypeAtlas.r, rewardTypeAtlas.t, rewardTypeAtlas.b);
		else
			self.Icon:SetAtlas(rewardTypeAtlas.texture);
		end
		self.Icon:SetScale(rewardTypeAtlas.scale);
		if (rewardTypeAtlas.color) then
			self.Icon:SetVertexColor(rewardTypeAtlas.color:GetRGB());
		end
		self:Show();
	end
end

--------------------------------
-- WQT_ScrollFrameMixin
--------------------------------

WQT_ScrollFrameMixin = {};

function WQT_ScrollFrameMixin:OnLoad()
	self.offset = 0;
	self.scrollStep = 30;
	self.max = 0;
	self.ScrollBar:SetMinMaxValues(0, 0);
	self.ScrollBar:SetValue(0);
	self.ScrollChild:SetPoint("RIGHT", self)
end

function WQT_ScrollFrameMixin:OnShow()
	self:SetChildHeight(self.ScrollChild:GetHeight());
end

function WQT_ScrollFrameMixin:UpdateChildFramePosition()
	if (self.ScrollChild) then
		self.ScrollChild:SetPoint("TOPLEFT", self, 0, self.offset);
	end
end

function WQT_ScrollFrameMixin:ScrollValueChanged(value)
	self.offset = max(0, min(value, self.max));
	self:UpdateChildFramePosition();
end

function WQT_ScrollFrameMixin:OnMouseWheel(delta)
	self.offset = self.offset - delta * self.scrollStep;
	self.offset = max(0, min(self.offset, self.max));
	self:UpdateChildFramePosition();
	self.ScrollBar:SetValue(self.offset);
end

function WQT_ScrollFrameMixin:SetChildHeight(height)
	self.ScrollChild:SetHeight(height);
	self.max = max(0, height - self:GetHeight());
	self.offset = min(self.offset, self.max);
	self.ScrollBar:SetMinMaxValues(0, self.max);
end

----------------------------
-- Containers
----------------------------

WQT_ContainerButtonMixin = {};

function WQT_ContainerButtonMixin:OnClick()
	self:SetSelected(not self.isSelected);
end

function WQT_ContainerButtonMixin:SetSelected(isSelected)
	self.isSelected = isSelected;	
	if (self.container) then
		if (self.isSelected) then
			self.container:Show();
			self.Selected:SetAlpha(0.5);
			WQT_WorldQuestFrame:SelectTab(WQT_TabWorld);
		else
			self.container:Hide();
			self.Selected:SetAlpha(0);
			WQT_WorldQuestFrame:SelectTab(WQT_TabNormal);
		end
	end
end

function WQT_ContainerButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(TRACKER_HEADER_WORLD_QUESTS, 1, 1, 1, true);
	GameTooltip:Show();
end

function WQT_ContainerButtonMixin:OnLeave()
	GameTooltip:Hide();
end

----------------------------
-- Utilities
----------------------------

local FORMAT_VERSION_MINOR = "%s|cFF888888.%s|r"
local FORMAT_H1 = "%s<h1 align='center'>%s</h1>";
local FORMAT_H2 = "%s<h2>%s:</h2>";
local FORMAT_p = "%s<p>%s</p>";
local FORMAT_WHITESPACE = "%s<h3>&#160;</h3>"

local function AddNotes(updateMessage, title, notes)
	if (not notes) then return updateMessage; end
	if (title) then
		updateMessage = FORMAT_H2:format(updateMessage, title);
	end
	for k, note in ipairs(notes) do
		updateMessage = FORMAT_p:format(updateMessage, note);
		updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	end
	updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	return updateMessage;
end


local cachedTypeData = {};
local cachedZoneInfo = {};

function WQT_Utils:GetSetting(...)
	local settings =  WQT.settings;
	local index = 1;
	local param = select(index, ...);
	
	while (param ~= nil) do
		if(settings[param] == nil) then 
			return nil 
		end;
		settings = settings[param];
		index = index + 1;
		param = select(index, ...);
	end
	
	if (type(settings) == "table") then
		return nil 
	end;
	
	return settings;
end

function WQT_Utils:GetLocal(key)
	return _L[key or ""];
end

function WQT_Utils:GetVariable(key)
	local val = _V[key or ""];
	
	if (not val) then return; end
	
	if (type(val) == "table") then
		return CopyTable(val);
	end
	
	return val;
end

function WQT_Utils:GetCachedMapInfo(zoneId)
	zoneId = zoneId or 0;
	local zoneInfo = cachedZoneInfo[zoneId];
	if (not zoneInfo) then
		zoneInfo = C_Map.GetMapInfo(zoneId);
		if (zoneInfo and zoneInfo.name) then
			cachedZoneInfo[zoneId] = zoneInfo;
		end
	end
	
	return zoneInfo;
end

function WQT_Utils:GetFactionDataInternal(id)
	if (not id) then  
		-- No faction
		return _V["WQT_NO_FACTION_DATA"];
	end;
	local factionData = _V["WQT_FACTION_DATA"];

	if (not factionData[id]) then
		-- Add new faction in case it's not in our data yet
		factionData[id] = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = 134400, ["unknown"] = true } -- Questionmark icon
		factionData[id].name = GetFactionInfoByID(id) or "Unknown Faction";
		WQT:debugPrint("Added new faction", id,factionData[id].name);
	end
	
	return factionData[id];
end

function WQT_Utils:GetCachedTypeIconData(questInfo)
	
	if (questInfo.isDaily)	then
		return "QuestDaily", 17, 17, true;
	elseif (questInfo.isQuestStart) then
		return "QuestNormal", 17, 17, true;
	elseif (C_QuestLog.IsThreatQuest(questInfo.questId)) then
		 return "worldquest-icon-nzoth", 14, 14, true;
	end
	
	local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questId);
	-- If there is no tag info, it's a bonus objective
	if (not tagInfo) then
		return "QuestBonusObjective", 21, 21, true;
	end
	
	local isNew = false;
	local originalType = tagInfo.worldQuestType;
	tagInfo.worldQuestType = tagInfo.worldQuestType or _V["WQT_TYPE_BONUSOBJECTIVE"];

	if (not cachedTypeData[tagInfo.worldQuestType]) then 
		cachedTypeData[tagInfo.worldQuestType] = {};
		isNew = true;
	end
	if (tagInfo.tradeskillLineID and not cachedTypeData[tagInfo.worldQuestType][tagInfo.tradeskillLineID]) then 
		cachedTypeData[tagInfo.worldQuestType][tagInfo.tradeskillLineID] = {};
		isNew = true;
	end
	
	if (isNew) then
		local atlasTexture, sizeX, sizeY  = QuestUtil.GetWorldQuestAtlasInfo(originalType, false, tagInfo.tradeskillLineID);
		if (tagInfo.tradeskillLineID) then
			cachedTypeData[tagInfo.worldQuestType][tagInfo.tradeskillLineID] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		else
			cachedTypeData[tagInfo.worldQuestType] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		end
	end
	
	if (tagInfo.tradeskillLineID) then
		local data = cachedTypeData[tagInfo.worldQuestType][tagInfo.tradeskillLineID];
		return data.texture, data.x, data.y;
	end
	
	local data = cachedTypeData[tagInfo.worldQuestType];
	return data.texture, data.x, data.y;
end

function WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated)
	local timeLeftMinutes = 0
	local timeLeftSeconds = 0
	local timeString = "";
	local timeStringShort = "";
	local color = _V["WQT_COLOR_CURRENCY"];
	local category = _V["TIME_REMAINING_CATEGORY"].none;
	
	if (not questInfo or not questInfo.questId) then return timeLeftSeconds, timeString, color ,timeStringShort, timeLeftMinutes, category end
	
	-- Time ran out, waiting for an update
	if (questInfo:IsExpired()) then
		timeString = RAID_INSTANCE_EXPIRES_EXPIRED;
		timeStringShort = "Exp."
		color = GRAY_FONT_COLOR;
		return 0, timeString, color,timeStringShort , 0, _V["TIME_REMAINING_CATEGORY"].expired;
	end
	
	timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInfo.questId) or 0;
	timeLeftSeconds =  C_TaskQuest.GetQuestTimeLeftSeconds(questInfo.questId) or 0;
	if ( timeLeftSeconds  and timeLeftSeconds > 0) then
		local displayTime = timeLeftSeconds
		if (displayTime < SECONDS_PER_HOUR  and displayTime >= SECONDS_PER_MIN ) then
			displayTime = displayTime + SECONDS_PER_MIN ;
		end
	
		if ( timeLeftSeconds < WORLD_QUESTS_TIME_CRITICAL_MINUTES * SECONDS_PER_MIN  ) then
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(displayTime, displayTime > SECONDS_PER_MIN  and true or false, unabreviated);
			category = _V["TIME_REMAINING_CATEGORY"].critical;
		elseif displayTime < SECONDS_PER_HOUR   then
			timeString = SecondsToTime(displayTime, true);
			color = _V["WQT_ORANGE_FONT_COLOR"];
			category = _V["TIME_REMAINING_CATEGORY"].short
		elseif displayTime < SECONDS_PER_DAY   then
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_HOURS:format(displayTime / SECONDS_PER_HOUR);
			end
			color = _V["WQT_GREEN_FONT_COLOR"];
			category = _V["TIME_REMAINING_CATEGORY"].medium;
		else
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_DAYS:format(displayTime / SECONDS_PER_DAY );
			end
			local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questId);
			local isWeek = tagInfo and tagInfo.isElite and tagInfo.quality == Enum.WorldQuestQuality.Epic
			color = isWeek and _V["WQT_PURPLE_FONT_COLOR"] or _V["WQT_BLUE_FONT_COLOR"];
			category = isWeek and _V["TIME_REMAINING_CATEGORY"].veryLong or _V["TIME_REMAINING_CATEGORY"].long;
		end
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	if t and str then
		timeStringShort = t..str;
	end
	
	return timeLeftSeconds, timeString, color, timeStringShort ,timeLeftMinutes, category;
end

function WQT_Utils:GetPinTime(questInfo)
	local seconds, _, color, timeStringShort, _, category = WQT_Utils:GetQuestTimeString(questInfo);
	local start = 0;
	local timeLeft = seconds;
	local total = 0;
	local maxTime, offset;
	if (timeLeft > 0) then
		if timeLeft >= 1440*60 then
			maxTime = 5760*60;
			offset = -720*60;
			local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questId);
			if (timeLeft > maxTime or (tagInfo.isElite and tagInfo.quality == Enum.WorldQuestQuality.Epic)) then
				maxTime = 1440 * 7*60;
				offset = 0;
			end
			
		elseif timeLeft >= 60*59 then --Minute display doesn't start until 59min left
			maxTime = 1440*60;
			offset = 60*60;
		elseif timeLeft >= 15*60 then
			maxTime= 60*60;
			offset = -10*60;
		else
			maxTime = 15*60;
			offset = 0;
		end
		start = (maxTime - timeLeft);
		total = (maxTime + offset);
		timeLeft = (timeLeft + offset);
	end
	return start, total, timeLeft, seconds, color, timeStringShort, category;
end

function WQT_Utils:GetMapInfoForQuest(questId)
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	return WQT_Utils:GetCachedMapInfo(zoneId);
end

function WQT_Utils:ItterateAllBonusObjectivePins(func)
	if(WorldMapFrame.pinPools.BonusObjectivePinTemplate) then
		for mapPin in pairs(WorldMapFrame.pinPools.BonusObjectivePinTemplate.activeObjects) do
			func(mapPin)
		end
	end
	if(WorldMapFrame.pinPools.ThreatObjectivePinTemplate) then
		for mapPin in pairs(WorldMapFrame.pinPools.ThreatObjectivePinTemplate.activeObjects) do
			func(mapPin)
		end
	end
end

function WQT_Utils:ShowQuestTooltip(button, questInfo)
	WQT:ShowDebugTooltipForQuest(questInfo, button);
	
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");

	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if (not questInfo.questId or not HaveQuestData(questInfo.questId)) then
		GameTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		GameTooltip.recalculatePadding = true;
		GameTooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questId);
	local qualityColor = WORLD_QUEST_QUALITY_COLORS[tagInfo and tagInfo.quality or Enum.WorldQuestQuality.Common];
	
	GameTooltip:SetText(title, qualityColor.r, qualityColor.g, qualityColor.b, 1, true);
	
	if ( factionID ) then
		local factionName = GetFactionInfoByID(factionID);
		if ( factionName ) then
			if (capped) then
				GameTooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
			else
				GameTooltip:AddLine(factionName);
			end
		end
	end

	-- Add time
	local seconds, timeString, timeColor, _, _, category = WQT_Utils:GetQuestTimeString(questInfo, true, true)
	if (seconds > 0 or category == _V["TIME_REMAINING_CATEGORY"].expired) then
		timeColor = seconds <= SECONDS_PER_HOUR  and timeColor or NORMAL_FONT_COLOR;
		GameTooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(timeString), timeColor.r, timeColor.g, timeColor.b);
	end

	local numObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questId);
	for objectiveIndex = 1, numObjectives do
		local objectiveText, _, finished = GetQuestObjectiveInfo(questInfo.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local objectiveColor = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			GameTooltip:AddLine(QUEST_DASH .. objectiveText, objectiveColor.r, objectiveColor.g, objectiveColor.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(questInfo.questId);
	if ( percent ) then
		GameTooltip_ShowProgressBar(GameTooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
	end

	if (questInfo.reward.type == WQT_REWARDTYPE.missing) then
		GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	else
		GameTooltip_AddQuestRewardsToTooltip(GameTooltip, questInfo.questId);
		
		-- reposition compare frame
		if((questInfo.reward.type == WQT_REWARDTYPE.equipment or questInfo.reward.type == WQT_REWARDTYPE.weapon) and GameTooltip.ItemTooltip:IsShown()) then
			if IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems") then
				-- Setup compare tootltips
				GameTooltip_ShowCompareItem(GameTooltip.ItemTooltip.Tooltip);
				
				-- If there is room to the right, give priority to show compare tooltips to the right of the tooltip
				local totalWidth = 0;
				if ( ShoppingTooltip1:IsShown()  ) then
						totalWidth = totalWidth + ShoppingTooltip1:GetWidth();
				end
				if ( ShoppingTooltip2:IsShown()  ) then
						totalWidth = totalWidth + ShoppingTooltip2:GetWidth();
				end
				
				if GameTooltip.ItemTooltip.Tooltip:GetRight() + totalWidth < GetScreenWidth() and ShoppingTooltip1:IsShown() then
					ShoppingTooltip1:ClearAllPoints();
					ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip.ItemTooltip.Tooltip, "TOPRIGHT");
					
					ShoppingTooltip2:ClearAllPoints();
					ShoppingTooltip2:SetPoint("TOPLEFT", ShoppingTooltip1, "TOPRIGHT");
				end
				
				-- Set higher frame level in case things overlap
				local level = GameTooltip:GetFrameLevel();
				ShoppingTooltip1:SetFrameLevel(level +2);
				ShoppingTooltip2:SetFrameLevel(level +1);
			end
		end
	end

	GameTooltip:Show();
	GameTooltip.recalculatePadding = true;
end

-- Climb map parents until the first continent type map it can find.
function WQT_Utils:GetContinentForMap(mapId) 
	local info = WQT_Utils:GetCachedMapInfo(mapId);
	if not info then return mapId; end
	local parent = info.parentMapID;
	if not parent or info.mapType <= Enum.UIMapType.Continent then 
		return mapId, info.mapType
	end 
	return self:GetContinentForMap(parent) 
end

function WQT_Utils:GetMapWQProvider()
	if WQT.mapWQProvider then return WQT.mapWQProvider; end
	
	for k in pairs(WorldMapFrame.dataProviders) do 
		for k1 in pairs(k) do
			if k1=="IsMatchingWorldMapFilters" then 
				WQT.mapWQProvider = k; 
				break;
			end 
		end 
	end
	return WQT.mapWQProvider;
end

function WQT_Utils:GetFlightWQProvider()
	if (WQT.FlightmapPins) then return WQT.FlightmapPins; end
	if (not FlightMapFrame) then return nil; end
	
	for k in pairs(FlightMapFrame.dataProviders) do 
		if (type(k) == "table") then 
			for k2 in pairs(k) do 
				if (k2 == "activePins") then 
					WQT.FlightmapPins = k;
					break;
				end 
			end 
		end 
	end
	return WQT.FlightmapPins;
end

function WQT_Utils:RefreshOfficialDataProviders()
	-- Have to force remove the WQ data from the map because RefreshAllData doesn't do it
	local mapWQProvider = WQT_Utils:GetMapWQProvider();
	if (mapWQProvider) then
		mapWQProvider:RemoveAllData();
	end
	
	-- If there are no dataproviders, we haven't opened the map yet, so don't force a refresh on it
	if (#WorldMapFrame.dataProviders > 0) then 
		WorldMapFrame:RefreshAllDataProviders();
	end

	-- Flight map world quests
	local flightWQProvider = WQT_Utils:GetFlightWQProvider();
	if (flightWQProvider) then
		flightWQProvider:RemoveAllData();
		flightWQProvider:RefreshAllData();
	end
end

-- Compatibility with the TomTom add-on
function WQT_Utils:AddTomTomArrowByQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			TomTom:AddWaypoint(zoneId, x, y, {["title"] = title, ["crazy"] = true});
		end
	end
end

function WQT_Utils:RemoveTomTomArrowbyQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			local key = TomTom:GetKeyArgs(zoneId, x, y, title);
			local wp = TomTom.waypoints[zoneId] and TomTom.waypoints[zoneId][key];
			if (wp) then
				TomTom:RemoveWaypoint(wp);
			end
		end
	end
end

function WQT_Utils:QuestCountsToCap(questLogIndex)
	local questInfo = C_QuestLog.GetInfo(questLogIndex);
	
	if (questInfo.isHeader or questInfo.isTask or questInfo.isBounty) then
		return false, questInfo.isHidden;
	end
	
	local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);
	local counts = true;
	
	if (tagInfo and tagInfo.tagID and _V["QUESTS_NOT_COUNTING"][tagInfo.tagID]) then
		counts = false;
	end
	
	return counts, questInfo.isHidden;
end

-- Count quests counting to the quest log cap and collect hidden ones that can't be abandoned
function WQT_Utils:GetQuestLogInfo(hiddenList)
	local _, numEntries = C_QuestLog.GetNumQuestLogEntries();
	local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept();
	local questCount = 0;
	if (hiddenList) then
		wipe(hiddenList);
	end
	for questLogIndex = 1, numEntries do
		local counts, isHidden = WQT_Utils:QuestCountsToCap(questLogIndex);
		if (counts) then
			questCount = questCount + 1;
			
			-- hidden quest counting to the cap
			if (isHidden and hiddenList) then
				tinsert(hiddenList, questLogIndex);
			end
		end
	end
	
	local color = questCount >= maxQuests and RED_FONT_COLOR or (questCount >= maxQuests-2 and _V["WQT_ORANGE_FONT_COLOR"] or _V["WQT_WHITE_FONT_COLOR"]);
	
	return questCount, maxQuests, color;
end

function WQT_Utils:QuestIsWatchedManual(questId)
	return questId and C_QuestLog.GetQuestWatchType(questId) == Enum.QuestWatchType.Manual;
end

function WQT_Utils:QuestIsWatchedAutomatic(questId)
	return questId and C_QuestLog.GetQuestWatchType(questId) == Enum.QuestWatchType.Automatic;
end

function WQT_Utils:GetQuestMapLocation(questId, mapId)
	local isSameMap = true;
	if (mapId) then
		local mapInfo = WQT_Utils:GetMapInfoForQuest(questId);
		isSameMap = mapInfo.mapID == mapId;
	end
	-- Threat quest specific
	if (isSameMap and C_QuestLog.IsThreatQuest(questId)) then
		local completed, x, y = QuestPOIGetIconInfo(questId);
		if (x and y) then
			return x, y;
		end
	end
	-- General tasks
	local x, y = C_TaskQuest.GetQuestLocation(questId, mapId);
	if (x and y) then
		return x, y;
	end
	-- Could not get a position
	return 0, 0;
end

function WQT_Utils:RewardTypePassesFilter(rewardType) 
	local rewardFilters = WQT.settings.filters[_V["FILTER_TYPES"].reward].flags;
	if(rewardType == WQT_REWARDTYPE.equipment or rewardType == WQT_REWARDTYPE.weapon) then
		return rewardFilters.Armor;
	end
	if(rewardType == WQT_REWARDTYPE.spell or rewardType == WQT_REWARDTYPE.item) then
		return rewardFilters.Item;
	end
	if(rewardType == WQT_REWARDTYPE.gold) then
		return rewardFilters.Gold;
	end
	if(rewardType == WQT_REWARDTYPE.currency) then
		return rewardFilters.Currency;
	end
	if(rewardType == WQT_REWARDTYPE.artifact) then
		return rewardFilters.Artifact;
	end
	if(rewardType == WQT_REWARDTYPE.relic) then
		return rewardFilters.Relic;
	end
	if(rewardType == WQT_REWARDTYPE.xp) then
		return rewardFilters.Experience;
	end
	if(rewardType == WQT_REWARDTYPE.honor) then
		return rewardFilters.Honor ;
	end
	if(rewardType == WQT_REWARDTYPE.reputation) then
		return rewardFilters.Reputation;
	end

	return true;
end

function WQT_Utils:GetQuestRewardIcon(questID)
	local texture;
	-- Item
	texture = select(2, GetQuestLogRewardInfo(1, questID));
	if (texture) then return texture; end
	-- Spell
	texture = GetQuestLogRewardSpell(1, questID);
	if (texture) then return texture; end
	-- Honor
	if (GetQuestLogRewardHonor(questID) > 0) then return 1455894 end;
	-- Gold
	if (GetQuestLogRewardMoney(questID) > 0) then return 133784 end;
	-- Currency
	local _, _, amount, currencyId = GetQuestLogRewardCurrencyInfo(1, questID);
	if (currencyId) then
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId);
		texture = select(2, CurrencyContainerUtil.GetCurrencyContainerInfo(currencyId, amount, currencyInfo.name, currencyInfo.iconFileID, currencyInfo.quality));
		if (texture) then return texture; end
	end
end

function WQT_Utils:DeepWipeTable(t)
	for k, v in pairs(t) do
		if (type(v) == "table") then
			self:DeepWipeTable(v)
		end
	end
	wipe(t);
	t = nil;
end

function WQT_Utils:FormatPatchNotes(notes, title)
	local updateMessage = "<html><body><h3>&#160;</h3>";
	updateMessage = FORMAT_H1:format(updateMessage, title);
	updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	for i=1, #notes do
		local patch = notes[i];
		local version = patch.minor and FORMAT_VERSION_MINOR:format(patch.version, patch.minor) or patch.version;
		updateMessage = FORMAT_H1:format(updateMessage, version);
		updateMessage = AddNotes(updateMessage, nil, patch.intro);
		updateMessage = AddNotes(updateMessage, "New", patch.new);
		updateMessage = AddNotes(updateMessage, "Changes", patch.changes);
		updateMessage = AddNotes(updateMessage, "Fixes", patch.fixes);
	end
	return updateMessage .. "</body></html>";
end

function WQT_Utils:RegisterExternalSettings(key, defaults)
	--print(key, "adding default settings");
	return WQT_Profiles:RegisterExternalSettings(key, defaults);
end

function WQT_Utils:AddExternalSettingsOptions(settings)
	for k, setting in ipairs(settings) do
		tinsert(_V["SETTING_LIST"], setting);
	end
end

function WQT_Utils:AddExternalSettingsOptions(settings)
	for k, setting in ipairs(settings) do
		tinsert(_V["SETTING_LIST"], setting);
	end
end
