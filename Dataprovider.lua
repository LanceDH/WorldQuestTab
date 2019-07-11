local addonName, addon = ...

----------------------------
-- VARIABLES
----------------------------

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;

local _WFMLoaded = IsAddOnLoaded("WorldFlightMap");

----------------------------
-- LOCAL FUNCTIONS
----------------------------

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
		local line = _G["WQT_TooltipTooltipTextLeft"..i];
		if not line then break; end
		local lineText = line:GetText() or "";
		result = lineText:match(pattern);
		if result then break; end
	end
	
	-- Force hide compare tooltips as they's show up for people with alwaysCompareItems set to 1
	for k, tooltip in ipairs(WQT_Tooltip.shoppingTooltips) do
		tooltip:Hide();
	end
	
	return result;
end

local function SetQuestReward(questInfo)
	local reward = questInfo.reward;
	local _, texture, numItems, quality, rewardType, color, rewardId, canUpgrade = nil, nil, 0, 1, WQT_REWARDTYPE.missing, _V["WQT_COLOR_MISSING"], nil, nil;
	
	local haveData = HaveQuestRewardData(questInfo.questId);
	
	if haveData then
		if (GetNumQuestLogRewards(questInfo.questId) > 0) then
			local ilvl;
			_, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, questInfo.questId);
			if rewardId then
				local price, typeID, subTypeID = select(11, GetItemInfo(rewardId));
				if (typeID == 4 or typeID == 2) then -- Gear (4 = armor, 2 = weapon)
					canUpgrade =ScanTooltipRewardForPattern(questInfo.questId, "(%d+%+)$") and true;
					numItems = ilvl;
					rewardType = typeID == 4 and WQT_REWARDTYPE.equipment or  WQT_REWARDTYPE.weapon;
					color = typeID == 4 and _V["WQT_COLOR_ARMOR"] or _V["WQT_COLOR_WEAPON"];
				elseif (typeID == 3 and subTypeID == 11) then
					-- Find updagade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					numItems = tonumber(ScanTooltipRewardForPattern(questInfo.questId, "^%+(%d+)"));
					rewardType = WQT_REWARDTYPE.relic;	
					color = _V["WQT_COLOR_RELIC"];
				else	-- Normal items
					if (typeID == 0 and subTypeID == 8 and price == 0 and ilvl > 100) then -- Item converting into equipment
						rewardType = WQT_REWARDTYPE.equipment;
						color = _V["WQT_COLOR_ARMOR"];
						numItems = ilvl;
					else
						rewardType = WQT_REWARDTYPE.item;
						color = _V["WQT_COLOR_ITEM"];
					end
				end
			end
		elseif (GetQuestLogRewardSpell(1, questInfo.questId)) then
			texture, _, _, _, _, _, _, _, rewardId = GetQuestLogRewardSpell(1, questInfo.questId);
			rewardType = WQT_REWARDTYPE.spell;
			color = _V["WQT_COLOR_ITEM"];
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
			local currenyId;
			_, texture, numItems, currenyId = GetQuestLogRewardCurrencyInfo(GetNumQuestLogRewardCurrencies(questInfo.questId), questInfo.questId)
			-- Because azerite is currency but is treated as an item
			local azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();
			if currenyId ~= azuriteID then
				local name, _, apTex, _, _, _, _, apQuality = GetCurrencyInfo(currenyId);
				name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currenyId, numItems, name, texture, apQuality); 
				
				if	C_CurrencyInfo.GetFactionGrantedByCurrency(currenyId) then
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

	questInfo.reward.id = rewardId;
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

local function SetTime(questInfo)

end

local function ValidateQuest(questInfo)
	questInfo.isValid = not (not WorldMap_DoesWorldQuestInfoPassFilters(questInfo) and questInfo.time.minutes == 0 and questInfo.reward.type == WQT_REWARDTYPE.missing and not questInfo.factionId);
end

----------------------------
-- MIXIN
----------------------------
local QUEST_LOG_UPDATE_CD = 1;

WQT_DataProvider = {}

function WQT_DataProvider:OnLoad()
	self.pool = CreateObjectPool(QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.keyList = {};
	-- If we added a quest which we didn't have rewarddata for yet, it gets added to the waiting room
	self.waitingRoomRewards = {};
	self.waitingRoomQuest = {};
	self.lastUpdate = 0;
	
	self.cachedTypeData = {};
	
	self.callbacks = {
		["waitingRoom"] = {}
		,["questsLoaded"] = {}
	}
	
	UpdateWorldZones(); 
	
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
		local mapAreaID = WorldMapFrame.mapID;
		if (self.currentMapId ~= mapAreaID) then
			self.mapChanged = true;
			self.currentMapId = mapAreaID;
			self.currentMapInfo = C_Map.GetMapInfo(mapAreaID);
			self:UpdateData();
		end
	end)
end

function WQT_DataProvider:UpdateData()
	local now = GetTime();
	local elapsed = now - self.lastUpdate;
	if  (self.mapChanged or elapsed > QUEST_LOG_UPDATE_CD) then
		self.lastUpdate = now;
		self.mapChanged = false;
		self:LoadQuestsInZone(self.currentMapId);
		if (self.dataTicker) then
			self.dataTicker:Cancel();
			self.dataTicker = nil;
		end
	else
		self:UpdateWaitingRoom();
		if (not self.dataTicker) then
			self.dataTicker =  C_Timer.NewTicker(QUEST_LOG_UPDATE_CD - elapsed+0.05, function() self:UpdateData() end, 1);
		end
	end
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		self:UpdateData();
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

function WQT_DataProvider:GetQuestTimeString(questInfo, fullString, unabreviated)
	local timeLeftMinutes = 0
        local timeLeftSeconds = 0
	local timeString = "";
	local timeStringShort = "";
	local color = _V["WQT_COLOR_CURRENCY"];
	
	if (not questInfo or not questInfo.questId) then return timeLeftSeconds, timeString, color ,timeStringShort, timeLeftMinutes end
	timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInfo.questId) or 0;
	timeLeftSeconds = C_TaskQuest.GetQuestTimeLeftSeconds(questInfo.questId) or 0;

	-- Time ran out, waiting for an update
	if (questInfo.time.seconds and questInfo.time.seconds > 0 and timeLeftSeconds < 1) then 
		timeString = RAID_INSTANCE_EXPIRES_EXPIRED;
		return timeLeftSeconds, timeString, color,timeStringShort , timeLeftMinutes 
	end
	
	if ( timeLeftSeconds  and timeLeftSeconds > 0) then
		local displayTime = timeLeftSeconds
		if (displayTime < 3600 and displayTime >= 60) then
			displayTime = displayTime + 60;
		end
	
		if ( timeLeftSeconds <= WORLD_QUESTS_TIME_CRITICAL_MINUTES * 60 ) then
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(displayTime, displayTime > 60 and true or false, unabreviated);
		elseif displayTime < 3600  then
			timeString = SecondsToTime(displayTime, true);
			color = _V["WQT_ORANGE_FONT_COLOR"];
		elseif displayTime < 24 * 3600  then
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_HOURS:format(displayTime / 3600);
			end
			color = _V["WQT_GREEN_FONT_COLOR"]
		else
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_DAYS:format(displayTime / (24*3600));
			end
			local isWeek = questInfo.isElite and questInfo.rarity == LE_WORLD_QUEST_QUALITY_EPIC
			color = isWeek and _V["WQT_PURPLE_FONT_COLOR"] or _V["WQT_BLUE_FONT_COLOR"];
		end
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	if t and str then
		timeStringShort = t..str;
	end
	
	return timeLeftSeconds, timeString, color, timeStringShort ,timeLeftMinutes;
end

function WQT_DataProvider:SetQuestData(questInfo)
	local questId = questInfo.questId;
	local zoneId = questInfo.mapInfo.mapID;
	
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questId);
	worldQuestType = worldQuestType or _V["WQT_TYPE_BONUSOBJECTIVE"];
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questId);
	
	local faction = factionId and GetFactionInfoByID(factionId) or _L["NO_FACTION"];
	
	local expLevel = _V["WQT_ZONE_EXPANSIONS"][zoneId] or 0;

	questInfo.title = title;
	
	questInfo.faction = faction;
	questInfo.factionId = factionId;
	questInfo.type = worldQuestType or -1;
	questInfo.rarity = rarity;
	questInfo.isElite = isElite;
	
	questInfo.expantionLevel = expLevel;
	questInfo.tradeskill = tradeskillLineIndex;
	
	local seconds, timeString, color, timeStringShort, minutes = self:GetQuestTimeString(questInfo);
	
	questInfo.time.seconds = seconds;
	questInfo.time.minutes = minutes; -- deprecated
	questInfo.time.full = timeString; -- deprecated
	questInfo.time.short = timeStringShort; -- deprecated
	questInfo.time.color = color; -- deprecated
	questInfo.time.timeStamp = GetTime(); -- deprecated

	questInfo.passedFilter = true;
	questInfo.isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questId);
end

function WQT_DataProvider:UpdateWaitingRoom()
	local questInfo;
	local updatedData = false;
	local fixed = {};
	WQT:debugTableWipe("fixedData"); -- debug
	WQT:debugTableWipe("fixedReward"); -- debug
	
	for i = #self.waitingRoomQuest, 1, -1 do
		local questInfo = self.waitingRoomQuest[i];
		if (questInfo.questId and HaveQuestData(questInfo.questId)) then
			WQT:debugTableInsert("fixedData", questInfo, questInfo.questId) -- debug
			tinsert(fixed, questInfo.questId);
			self:SetQuestData(questInfo);
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
	
	wipe(fixed);
	for i = #self.waitingRoomRewards, 1, -1 do
		questInfo = self.waitingRoomRewards[i];
		if ( questInfo.questId and HaveQuestRewardData(questInfo.questId)) then
			WQT:debugTableInsert("fixedReward", questInfo, questInfo.questId) -- debug
			SetQuestReward(questInfo);
			SetSubReward(questInfo);
			ValidateQuest(questInfo);
			table.remove(self.waitingRoomRewards, i);
			updatedData = true;
		end
	end

	WQT:debugAnnounceTable("fixedData"); -- debug
	WQT:debugAnnounceTable("fixedReward"); -- debug
	
	if (updatedData) then
		for k, func in ipairs(self.callbacks.waitingRoom) do
			func();
		end
	end
end

function WQT_DataProvider:AddContinentMapQuests(continentZones, continentId)
	if continentZones then
		for zoneID, zoneData  in pairs(continentZones) do
			self:AddQuestsInZone(zoneID, continentId or zoneID);
		end
	end
end

function WQT_DataProvider:AddWorldMapQuests(worldContinents)
	if worldContinents then
		for contID, contData in pairs(worldContinents) do
			-- Every ID is a continent, get every zone on every continent
			local continentZones = _V["WQT_ZONE_MAPCOORDS"][contID];
			self:AddContinentMapQuests(continentZones, contID)
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneId)
	self:ClearData();
	zoneId = zoneId or self.latestZoneId
	if (not zoneId) then return end;
	self.latestZoneId = zoneId
	
	if not (WorldMapFrame:IsShown() or (FlightMapFrame and FlightMapFrame:IsShown())) then return; end
	-- If the flight map is open, we want all quests no matter what
	if (FlightMapFrame and FlightMapFrame:IsShown() and not _WFMLoaded) then 
		local taxiId = GetTaxiMapID()
		zoneId = (taxiId and taxiId > 0) and taxiId or zoneId;
		-- World Flight Map  add-on overwrite
		if (_WFMLoaded) then
			zoneId = WorldMapFrame.mapID;
		end
	end
	
	local currentMapInfo = C_Map.GetMapInfo(zoneId);
	if not currentMapInfo then return end;

	WQT:debugTableWipe("duplicate"); -- debug
	WQT:debugTableWipe("invalid"); -- debug
	WQT:debugTableWipe("missingData"); -- debug
	WQT:debugTableWipe("alwaysHide"); -- debug
	
	if (WQT.settings.alwaysAllQuests and currentMapInfo.mapType ~= Enum.UIMapType.World) then
		
		local highestMapId, mapType = WQT:GetFirstContinent(zoneId);
		local continentZones = _V["WQT_ZONE_MAPCOORDS"][highestMapId];
		if (mapType ~= Enum.UIMapType.World) then
			self:AddContinentMapQuests(continentZones);
			
			local relatedMaps = _V["WQT_CONTINENT_GROUPS"][highestMapId];
			if relatedMaps then
				for k, mapId in pairs(relatedMaps) do	
					self:AddContinentMapQuests(_V["WQT_ZONE_MAPCOORDS"][mapId]);
				end
			end
		else
			self:AddWorldMapQuests(continentZones);
		end
	else
		local continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneId];

		if currentMapInfo.mapType == Enum.UIMapType.Continent  and continentZones then
			self:AddContinentMapQuests(continentZones);
		elseif (currentMapInfo.mapType == Enum.UIMapType.World) then
			self:AddWorldMapQuests(continentZones);
		else
			-- Simple zone map
			self:AddQuestsInZone(zoneId, currentMapInfo.parentMapID);
		end
	end
	
	WQT:debugAnnounceTable("duplicate", "FFFF00"); -- debug
	WQT:debugAnnounceTable("invalid", "FF0000"); -- debug
	WQT:debugAnnounceTable("missingData", "00FFFF"); -- debug
	WQT:debugAnnounceTable("alwaysHide", "FF66FF"); -- debug
	
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
		
		WQT:debugTableInsert("duplicate", duplicate, duplicate.questId) -- debug
		
		return duplicate;
	end
	
	local questInfo = self.pool:Acquire();
	
	questInfo.isValid = false;
	questInfo.alwaysHide = not MapUtil.ShouldShowTask(zoneId, qInfo);
	questInfo.questId = qInfo.questId;
	questInfo.mapInfo = C_Map.GetMapInfo(zoneId);
	questInfo.mapInfo.mapX = qInfo.x;
	questInfo.mapInfo.mapY = qInfo.y;
	questInfo.numObjectives = qInfo.numObjectives;
	
	if not HaveQuestData(qInfo.questId) then
		WQT:debugTableInsert("missingData", questInfo, questInfo.questId) -- debug
		tinsert(self.waitingRoomQuest, questInfo);
		return nil;
	end
	
	self:SetQuestData(questInfo);
	
	local haveRewardData = SetQuestReward(questInfo);
	if haveRewardData then
		-- If the quest as a second reward e.g. Mark of Honor + Honor points
		SetSubReward(questInfo);
	end
	
	-- Filter out invalid quests like "Tracking Quest" in nazmir
	ValidateQuest(questInfo);
	
	if not questInfo.isValid then
		WQT:debugTableInsert("invalid", questInfo, questInfo.questId) -- debug
	end
	
	if questInfo.alwaysHide then
		WQT:debugTableInsert("alwaysHide", questInfo, questInfo.questId) -- debug
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
