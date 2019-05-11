local addonName, addon = ...

----------------------------
-- VARIABLES
----------------------------

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;
local _debug = addon.debug;

----------------------------
-- LOCAL FUNCTIONS
----------------------------

function WQT:debugPrint(...)
	if _debug then print(...) end
end

local function UpdateWorldZones(newLevel)
	if (newLevel and newLevel ~= 110 and newLevel ~=120) then return; end
	 
	newLevel = newLevel or UnitLevel("player");
	
	local expLevel = GetExpansionLevel();
	local worldTable = _V["WQT_ZONE_MAPCOORDS"][947]
	wipe(worldTable);
	
	-- world map continents depending on expansion level
	worldTable[113] = {["x"] = 0.49, ["y"] = 0.13} -- Northrend
	worldTable[424] = {["x"] = 0.46, ["y"] = 0.92} -- Pandaria
	
	if (expLevel >= LE_EXPANSION_BATTLE_FOR_AZEROTH and newLevel >= 120) then
		worldTable[875] = {["x"] = 0.54, ["y"] = 0.61} -- Zandalar
		worldTable[876] = {["x"] = 0.72, ["y"] = 0.49} -- Kul Tiras
		worldTable[12] = {["x"] = 0.19, ["y"] = 0.5} -- Kalimdor
		worldTable[13] = {["x"] = 0.88, ["y"] = 0.56} -- Eastern Kingdom
	elseif (expLevel >= LE_EXPANSION_LEGION and newLevel >= 110) then
		worldTable[619] = {["x"] = 0.6, ["y"] = 0.41} -- Broken Isles
	end
end

local function QuestCreationFunc(pool)
	local questInfo = {["time"] = {}, ["reward"] = {}};
	return questInfo;
end

local function QuestResetFunc(pool, questInfo)
	-- Clean out everthing that isn't a color
	for k, v in pairs(questInfo) do
		local objType = type(v);
		if objType == "table" and not v.GetRGB then
			QuestResetFunc(pool, v)
		else
			if (objType == "boolean") then
				questInfo[k] = nil;
			elseif (objType == "string") then
				questInfo[k] = "";
			elseif (objType == "number") then
				questInfo[k] = nil;
			end
		end
	end
end

local function ScanTooltipRewardForPattern(questID, pattern)
	local result;
	
	GameTooltip_AddQuestRewardsToTooltip(WQT_Tooltip, questID);
	for i=2, 6 do
		local lineText = _G["WQT_TooltipTooltipTextLeft"..i]:GetText() or "";
		result = lineText:match(pattern);
		if result then break; end
	end
	
	-- Force hide compare tooltips as they's show up for people with alwaysCompareItems set to 1
	for k, tooltip in ipairs(WQT_Tooltip.shoppingTooltips) do
		tooltip:Hide();
	end
	
	return result;
end

local function GetQuestTimeString(questId)
	local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questId);
	local timeString = "";
	local timeStringShort = "";
	local color = _V["WQT_WHITE_FONT_COLOR"];
	if ( timeLeftMinutes ) then
		if ( timeLeftMinutes <= WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(timeLeftMinutes * 60);
		elseif timeLeftMinutes < 60  then
			timeString = SecondsToTime(timeLeftMinutes * 60);
			color = _V["WQT_ORANGE_FONT_COLOR"];
		elseif timeLeftMinutes < 24 * 60  then
			timeString = D_HOURS:format(timeLeftMinutes / 60);
			color = _V["WQT_GREEN_FONT_COLOR"]
		else
			timeString = D_DAYS:format(timeLeftMinutes  / 1440);
			color = _V["WQT_BLUE_FONT_COLOR"];
		end
	else 
		timeLeftMinutes = 0;
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	if t and str then
		timeStringShort = t..str;
	end
	
	return timeLeftMinutes, timeString, color, timeStringShort;
end

local function SetQuestReward(questInfo)
	local reward = questInfo.reward;
	local _, texture, numItems, quality, rewardType, color, rewardId, itemId, canUpgrade = nil, nil, 0, 1, WQT_REWARDTYPE.missing, _V["WQT_COLOR_MISSING"], nil, nil, nil;
	
	local haveData = HaveQuestRewardData(questInfo.questId);
	
	if haveData then
		if GetNumQuestLogRewards(questInfo.questId) > 0 then
			_, texture, numItems, quality, _, itemId = GetQuestLogRewardInfo(1, questInfo.questId);
			if itemId then
				local itemType = select(6, GetItemInfo(itemId));
				if (itemType == ARMOR or itemType == WEAPON) then -- Gear
					local result = ScanTooltipRewardForPattern(questInfo.questId, "(%d+%+?)$");
					if result then
						numItems = tonumber(result:match("(%d+)"));
						canUpgrade = result:match("(%+)") and true;
					end
					rewardType = WQT_REWARDTYPE.equipment;
					color = _V["WQT_COLOR_ARMOR"];
				elseif IsArtifactRelicItem(itemId) then
					-- Because getting a link of the itemID only shows the base item
					numItems = tonumber(ScanTooltipRewardForPattern(questInfo.questId, "^%+(%d+)"));
					rewardType = WQT_REWARDTYPE.relic;	
					color = _V["WQT_COLOR_RELIC"];
				else	-- Normal items
					rewardType = WQT_REWARDTYPE.item;
					color = _V["WQT_COLOR_ITEM"];
				end
			end
		elseif GetQuestLogRewardHonor(questInfo.questId) > 0 then
			numItems = GetQuestLogRewardHonor(questInfo.questId);
			texture = _V["WQT_HONOR"];
			color = _V["WQT_COLOR_HONOR"];
			rewardType = WQT_REWARDTYPE.honor;
		elseif GetQuestLogRewardMoney(questInfo.questId) > 0 then
			numItems = floor(abs(GetQuestLogRewardMoney(questInfo.questId) / 10000))
			texture = "Interface/ICONS/INV_Misc_Coin_01";
			rewardType = WQT_REWARDTYPE.gold;
			color = _V["WQT_COLOR_GOLD"];
		elseif GetNumQuestLogRewardCurrencies(questInfo.questId) > 0 then
			_, texture, numItems, rewardId = GetQuestLogRewardCurrencyInfo(GetNumQuestLogRewardCurrencies(questInfo.questId), questInfo.questId)
			-- Because azerite is currency but is treated as an item
			local azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();
			if rewardId ~= azuriteID then
				local name, _, apTex, _, _, _, _, apQuality = GetCurrencyInfo(rewardId);
				name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(rewardId, numItems, name, texture, apQuality); 
				
				if	C_CurrencyInfo.GetFactionGrantedByCurrency(rewardId) then
					rewardType = WQT_REWARDTYPE.reputation;
					quality = 0;
				else
					rewardType = WQT_REWARDTYPE.currency;
				end
				
				color = _V["WQT_COLOR_CURRENCY"];
			else
				-- We want azerite to act like AP
				local name, _, apTex, _, _, _, _, apQuality = GetCurrencyInfo(azuriteID);
				name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(azuriteID, numItems, name, texture, apQuality); 
				
				rewardType = WQT_REWARDTYPE.artifact;
				color = _V["WQT_COLOR_ARTIFACT"];
			end
		elseif haveData and GetQuestLogRewardXP(questInfo.questId) > 0 then
			numItems = GetQuestLogRewardXP(questInfo.questId);
			texture = _V["WQT_EXPERIENCE"];
			color = _V["WQT_COLOR_ITEM"];
			rewardType = WQT_REWARDTYPE.xp;
		elseif GetNumQuestLogRewards(questInfo.questId) == 0 then
			texture = "";
			color = _V["WQT_COLOR_ITEM"];
			rewardType = WQT_REWARDTYPE.none;
		end
	end

	questInfo.reward.id = itemId;
	questInfo.reward.quality = quality or 1;
	questInfo.reward.texture = texture or _V["WQT_QUESTIONMARK"];
	questInfo.reward.amount = numItems or 0;
	questInfo.reward.type = rewardType or 0;
	questInfo.reward.color = color;
	questInfo.reward.canUpgrade = canUpgrade;
	
	return haveData;
end

local function SetSubReward(questInfo) 
	local subType = nil;
	if questInfo.reward.type ~= WQT_REWARDTYPE.currency and questInfo.reward.type ~= WQT_REWARDTYPE.artifact and questInfo.reward.type ~= WQT_REWARDTYPE.reputation and GetNumQuestLogRewardCurrencies(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE.currency;
	elseif questInfo.reward.type ~= WQT_REWARDTYPE.honor and GetQuestLogRewardHonor(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE.honor;
	elseif questInfo.reward.type ~= WQT_REWARDTYPE.gold and GetQuestLogRewardMoney(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE.gold;
	end
	
	questInfo.reward.subType = subType;
end

local function SetQuestData(questInfo)
	local questId = questInfo.questId;
	local zoneId = questInfo.mapInfo.mapID;
	
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questId);
	
	worldQuestType = not QuestUtils_IsQuestWorldQuest(questId) and _V["WQT_TYPE_BONUSOBJECTIVE"] or worldQuestType;
	local minutes, timeString, color, timeStringShort = GetQuestTimeString(questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questId);
	
	local faction = factionId and GetFactionInfoByID(factionId) or _L["NO_FACTION"];
	
	local expLevel = _V["WQT_ZONE_EXPANSIONS"][zoneId] or 0;

	questInfo.time.minutes = minutes;
	questInfo.time.full = timeString;
	questInfo.time.short = timeStringShort;
	questInfo.time.color = color;
	
	questInfo.title = title;
	
	questInfo.faction = faction;
	questInfo.factionId = factionId;
	questInfo.type = worldQuestType or -1;
	questInfo.rarity = rarity;
	questInfo.isElite = isElite;
	
	questInfo.expantionLevel = expLevel;
	questInfo.tradeskill = tradeskillLineIndex;
	
	questInfo.passedFilter = true;
	questInfo.isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questId);
end

local function ValidateQuest(questInfo)
	questInfo.isValid = not (not WorldMap_DoesWorldQuestInfoPassFilters(questInfo) and questInfo.time.minutes == 0 and questInfo.reward.type == WQT_REWARDTYPE.missing and not questInfo.factionId);
end

----------------------------
-- MIXIN
----------------------------

WQT_DataProvider = {}

function WQT_DataProvider:OnLoad()
	self.pool = CreateObjectPool(QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.keyList = {};
	-- If we added a quest which we didn't have rewarddata for yet, it gets added to the waiting room
	self.waitingRoomRewards = {};
	self.waitingRoomQuest = {};
	
	self.cachedTypeData = {};
	
	self.callbacks = {
		["waitingRoom"] = {}
		,["questsLoaded"] = {}
	}
	
	UpdateWorldZones(); 
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		self:UpdateWaitingRoom();
	elseif (event == "PLAYER_LEVEL_UP") then
		local level = ...;
		UpdateWorldZones(level); 
	end
end

function WQT_DataProvider:HookWaitingRoomUpdate(func)
	tinsert(self.callbacks.waitingRoom, func);
end

function WQT_DataProvider:HookQuestsLoaded(func)
	tinsert(self.callbacks.questsLoaded, func);
end

function WQT_DataProvider:ClearData()
	self.pool:ReleaseAll();
	wipe(self.iterativeList);
	wipe(self.keyList);
	wipe(self.waitingRoomRewards);
	wipe(self.waitingRoomQuest )
end

function WQT_DataProvider:UpdateWaitingRoom()
	local questInfo;
	local updatedData = false;
	
	for i = #self.waitingRoomQuest, 1, -1 do
		local questInfo = self.waitingRoomQuest[i];
		if (questInfo.questId and HaveQuestData(questInfo.questId)) then
			WQT:debugPrint("Fixed", questInfo.questId);
			SetQuestData(questInfo);
			if HaveQuestRewardData(questInfo.questId) then	
				SetQuestReward(questInfo);
				SetSubReward(questInfo);
				ValidateQuest(questInfo);
			else
				WQT:debugPrint(questInfo.questId, "still missing reward");
				tinsert(self.waitingRoomRewards, questInfo);
			end
			table.remove(self.waitingRoomQuest, i);
			updatedData = true;
		end
	end
	
	for i = #self.waitingRoomRewards, 1, -1 do
		questInfo = self.waitingRoomRewards[i];
		if ( questInfo.questId and HaveQuestRewardData(questInfo.questId)) then
			WQT:debugPrint("Fixed", questInfo.questId, "reward");
			SetQuestReward(questInfo);
			SetSubReward(questInfo);
			ValidateQuest(questInfo);
			table.remove(self.waitingRoomRewards, i);
			updatedData = true;
		end
	end

	if (updatedData) then
		for k, func in ipairs(self.callbacks.waitingRoom) do
			func();
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneId)
	self:ClearData();
	
	if not (WorldMapFrame:IsShown() or (FlightMapFrame and FlightMapFrame:IsShown())) then return; end
	-- If the flight map is open, we want all quests no matter what
	if (FlightMapFrame and FlightMapFrame:IsShown()) then 
		local taxiId = GetTaxiMapID()
		zoneId = (taxiId and taxiId > 0) and taxiId or zoneId;
		-- World Flight Map  add-on overwrite
		if (_WFMLoaded) then
			zoneId = WorldMapFrame.mapID;
		end
	end
	
	local currentMapInfo = C_Map.GetMapInfo(zoneId);
	if not currentMapInfo then return end;
	
	local continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneId];
	local continentId = currentMapInfo.parentMapID;
	local missingRewardData = false;
	local questsById, quest;

	if (WQT.settings.alwaysAllQuests and currentMapInfo.mapType ~= Enum.UIMapType.World) then
	
		local highestMapId = WQT:GetFirstContinent(zoneId);
		continentZones = _V["WQT_ZONE_MAPCOORDS"][highestMapId];
		if continentZones then
			
			for ID, data in pairs(continentZones) do	
				self:AddQuestsInZone(ID, ID);
			end
		end

		local relatedMaps = _V["WQT_CONTINENT_GROUPS"][highestMapId];
		if relatedMaps then
			for k, mapId in pairs(relatedMaps) do	
				continentZones = _V["WQT_ZONE_MAPCOORDS"][mapId];
				if continentZones then
					for ID, data in pairs(continentZones) do	
						self:AddQuestsInZone(ID, ID);
					end
				end
			end
		end
		return;
	end

	if currentMapInfo.mapType == Enum.UIMapType.Continent  and continentZones then
		-- All zones in a continent
		for ID, data in pairs(continentZones) do	
			 self:AddQuestsInZone(ID, ID);
		end
	elseif (currentMapInfo.mapType == Enum.UIMapType.World) then
		for contID, contData in pairs(continentZones) do
			-- Every ID is a continent, get every zone on every continent
			continentZones = _V["WQT_ZONE_MAPCOORDS"][contID];
			for zoneID, zoneData  in pairs(continentZones) do
				self:AddQuestsInZone(zoneID, contID);
			end
		end
	else
		-- Simple zone map
		self:AddQuestsInZone(zoneId, continentId);
	end
	
	for k, func in ipairs(self.callbacks.questsLoaded) do
		func();
	end
end

function WQT_DataProvider:AddQuestsInZone(zoneID, continentId)
	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	if not questsById then return false; end
	local missingData = false;
	local quest;
	
	for k, info in ipairs(questsById) do
		if info.mapID == zoneID then
			quest = self:AddQuest(info, zoneID, continentId);
			if not quest then 
				missingData = true;
			end;
		end
	end
	
	return missingData;
end

function WQT_DataProvider:AddQuest(qInfo, zoneId, continentId)
	local duplicate = self:FindDuplicate(qInfo.questId);
	-- If there is a duplicate, we don't want to go through all the info again
	if (duplicate) then
		-- Check if the new zone is the 'official' zone, if so, use that one instead
		if (zoneId == C_TaskQuest.GetQuestZoneID(qInfo.questId) ) then
			local mapInfo = C_Map.GetMapInfo(zoneId);
			duplicate.mapInfo = mapInfo;
			duplicate.mapInfo.mapX = qInfo.x;
			duplicate.mapInfo.mapY = qInfo.y;
		end
		
		WQT:debugPrint("|cFFFFFF00Duplicate:", duplicate.title or duplicate.questId, "(", duplicate.mapInfo.name ,")|r");
		
		return duplicate;
	end
	
	local questInfo = self.pool:Acquire();
	
	questInfo.isValid = false;
	questInfo.questId = qInfo.questId;
	questInfo.mapInfo = C_Map.GetMapInfo(zoneId);
	questInfo.mapInfo.mapX = qInfo.x;
	questInfo.mapInfo.mapY = qInfo.y;
	questInfo.numObjectives = qInfo.numObjectives;
	
	if not HaveQuestData(qInfo.questId) then
		WQT:debugPrint("|cFF00FFFFMissing data:", questInfo.questId,"|r");
		tinsert(self.waitingRoomQuest, questInfo);
		return nil;
	end
	
	SetQuestData(questInfo);
	
	local haveRewardData = SetQuestReward(questInfo);
	if haveRewardData then
		-- If the quest as a second reward e.g. Mark of Honor + Honor points
		SetSubReward(questInfo);
	end
	
	-- Filter out invalid quests like "Tracking Quest" in nazmir
	ValidateQuest(questInfo);
	
	if not questInfo.isValid then
		WQT:debugPrint("|cFFFF0000Invalid:",questInfo.title,"(",questInfo.mapInfo.name,")|r");
	end
	
	if not haveRewardData then
		C_TaskQuest.RequestPreloadRewardData(qInfo.questId);
		tinsert(self.waitingRoomRewards, questInfo);
		return nil;
	end;

	return questInfo;
end

function WQT_DataProvider:FindDuplicate(questId)
	for questInfo, v in self.pool:EnumerateActive() do
		if (questInfo.questId == questId) then
			return questInfo;
		end
	end
	
	return nil;
end

function WQT_DataProvider:GetIterativeList()
	wipe(self.iterativeList);
	
	for questInfo, v in self.pool:EnumerateActive() do
		table.insert(self.iterativeList, questInfo);
	end
	
	return self.iterativeList;
end

function WQT_DataProvider:GetKeyList()
	for id, questInfo in pairs(self.keyList) do
		self.keyList[id] = nil;
	end
	
	for questInfo, v in self.pool:EnumerateActive() do
		self.keyList[questInfo.questId] = questInfo;
	end
	
	return self.keyList;
end

function WQT_DataProvider:GetQuestById(id)
	for questInfo, v in self.pool:EnumerateActive() do
		if questInfo.questId == id then return questInfo; end
	end
	return nil;
end

function WQT_DataProvider:ListContainsEmissary()
	for questInfo, v in self.pool:EnumerateActive() do
		if questInfo.isCriteria then return true; end
	end
	return false
end

function WQT_DataProvider:GetCachedTypeIconData(questType, tradeskillLineIndex)
	local isNew = false;
	if (not self.cachedTypeData[questType]) then 
		self.cachedTypeData[questType] = {};
		isNew = true;
	end
	if (tradeskillLineIndex and not self.cachedTypeData[questType][tradeskillLineIndex]) then 
		self.cachedTypeData[questType][tradeskillLineIndex] = {};
		isNew = true;
	end
	
	if (isNew) then
		local atlasTexture, sizeX, sizeY  = QuestUtil.GetWorldQuestAtlasInfo(questType, false, tradeskillLineIndex);
		if (tradeskillLineIndex) then
			self.cachedTypeData[questType][tradeskillLineIndex] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		else
			self.cachedTypeData[questType] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		end
	end
	
	if (tradeskillLineIndex) then
		return self.cachedTypeData[questType][tradeskillLineIndex].texture, self.cachedTypeData[questType][tradeskillLineIndex].x, self.cachedTypeData[questType][tradeskillLineIndex].y;
	end
	
	return self.cachedTypeData[questType].texture, self.cachedTypeData[questType].x, self.cachedTypeData[questType].y;
end






