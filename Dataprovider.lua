local _, addon = ...

----------------------------
-- VARIABLES
----------------------------

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;

local _WFMLoaded = IsAddOnLoaded("WorldFlightMap");
local _azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();

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

local function QuestCreationFunc()
	local questInfo = {["time"] = {}, ["reward"] = {}, ["mapInfo"] = {}};
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
	for _, tooltip in ipairs(WQT_Tooltip.shoppingTooltips) do
		tooltip:Hide();
	end
	
	return result;
end

local function GetMostImpressiveCurrency(questInfo)
	local numCurrencies = GetNumQuestLogRewardCurrencies(questInfo.questId);
	local bestType = WQT_REWARDTYPE.missing;
	local best, bestAmount, highestQuality, bestTex;
	for i=1, numCurrencies do
		local _, _, amount, currencyId = GetQuestLogRewardCurrencyInfo(i, questInfo.questId);
		if (currencyId) then
			local name, _, texture, _, _, _, _, quality = GetCurrencyInfo(currencyId);
			local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyId) ~= nil;
			name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyId, amount, name, texture, quality); 
			local currType = currencyId == _azuriteID and WQT_REWARDTYPE.artifact or  (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
			if (currType < bestType or highestQuality < quality) then
				highestQuality = quality;
				bestAmount = amount;
				bestTex = texture;
				bestType = currType;
				best = currencyId;
			end
		end
	end
	return best, bestType, highestQuality, bestAmount, bestTex;
end

local function AddQuestReward(questInfo, rewardType, amount, texture, quality, color, id, canUpgrade)
	if (not questInfo.reward.type) then
		amount = amount or 1;
		questInfo.reward.id = id;
		questInfo.reward.type = rewardType;
		questInfo.reward.amount = amount;
		questInfo.reward.texture = texture;
		questInfo.reward.quality = quality;
		questInfo.reward.color = color;
		questInfo.reward.canUpgrade = canUpgrade;
	end
	questInfo.reward.typeBits = bit.bor(questInfo.reward.typeBits, rewardType);
end

local function SetQuestRewards(questInfo)
	local haveData = HaveQuestRewardData(questInfo.questId);
	questInfo.reward.typeBits = 0;
	
	
	if haveData then
		local currencyId, currencyType, currencyQuality, currencyAmount, currencyTexture = GetMostImpressiveCurrency(questInfo);
		if (GetNumQuestLogRewards(questInfo.questId) > 0) then
			local _, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, questInfo.questId);
			if rewardId then
				local price, typeID, subTypeID = select(11, GetItemInfo(rewardId));
				if (typeID == 4 or typeID == 2) then -- Gear (4 = armor, 2 = weapon)
					local canUpgrade = ScanTooltipRewardForPattern(questInfo.questId, "(%d+%+)$") and true or false;
					local rewardType = typeID == 4 and WQT_REWARDTYPE.equipment or  WQT_REWARDTYPE.weapon;
					local color = typeID == 4 and _V["WQT_COLOR_ARMOR"] or _V["WQT_COLOR_WEAPON"];
					AddQuestReward(questInfo, rewardType, ilvl, texture, quality, color, rewardId, canUpgrade);
				elseif (typeID == 3 and subTypeID == 11) then
					-- Find updagade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					local numItems = tonumber(ScanTooltipRewardForPattern(questInfo.questId, "^%+(%d+)"));
					AddQuestReward(questInfo, WQT_REWARDTYPE.relic, numItems, texture, quality, _V["WQT_COLOR_RELIC"], rewardId);
				else	-- Normal items
					if (typeID == 0 and subTypeID == 8 and price == 0 and ilvl > 100) then -- Item converting into equipment
						AddQuestReward(questInfo, WQT_REWARDTYPE.equipment, ilvl, texture, quality, _V["WQT_COLOR_ARMOR"], rewardId);
					else
						AddQuestReward(questInfo, WQT_REWARDTYPE.item, numItems, texture, quality, _V["WQT_COLOR_ITEM"], rewardId);
					end
				end
			end
		end
		if (GetQuestLogRewardSpell(1, questInfo.questId)) then
			local texture, _, _, _, _, _, _, _, rewardId = GetQuestLogRewardSpell(1, questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.spell, 1, texture, 1, _V["WQT_COLOR_ITEM"], rewardId);
		end
		if GetQuestLogRewardHonor(questInfo.questId) > 0 then
			local numItems = GetQuestLogRewardHonor(questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.honor, numItems, 1455894, 1, _V["WQT_COLOR_HONOR"]);
		end
		if (currencyId and (currencyType < WQT_REWARDTYPE.gold or currencyQuality > 1)) then
			local color = currencyType == WQT_REWARDTYPE.artifact and _V["WQT_COLOR_ARTIFACT"] or  _V["WQT_COLOR_CURRENCY"];
			AddQuestReward(questInfo, currencyType, currencyAmount, currencyTexture, currencyQuality, color, currencyId);
		end
		if GetQuestLogRewardMoney(questInfo.questId) > 0 then
			local numItems = floor(abs(GetQuestLogRewardMoney(questInfo.questId) / 10000))
			AddQuestReward(questInfo, WQT_REWARDTYPE.gold, numItems, 133784, 1, _V["WQT_COLOR_GOLD"]);
		end
		if (currencyId) then
			local color = currencyType == WQT_REWARDTYPE.artifact and _V["WQT_COLOR_ARTIFACT"] or  _V["WQT_COLOR_CURRENCY"];
			AddQuestReward(questInfo, currencyType, currencyAmount, currencyTexture, currencyQuality, color, currencyId);
			
			local numCurrencies = GetNumQuestLogRewardCurrencies(questInfo.questId);
			for i=1, numCurrencies do
				local _, _, _, currencyId = GetQuestLogRewardCurrencyInfo(i, questInfo.questId);
				if (currencyId) then
					local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyId) ~= nil;
					local currType = currencyId == _azuriteID and WQT_REWARDTYPE.artifact or  (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
					questInfo.reward.typeBits = bit.bor(questInfo.reward.typeBits, currType);
				end
			end
		end
		if haveData and GetQuestLogRewardXP(questInfo.questId) > 0 then
			local numItems = GetQuestLogRewardXP(questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.xp, numItems, 894556, 1, _V["WQT_COLOR_ITEM"]);
		end
		if (questInfo.reward.type == 0) then
			AddQuestReward(questInfo, WQT_REWARDTYPE.none, 1, "", 1, _V["WQT_COLOR_ITEM"]);
		end
	else
		AddQuestReward(questInfo, WQT_REWARDTYPE.missing, 0, 134400, 1, _V["WQT_COLOR_MISSING"]);
	end

	return haveData;
end

local function ValidateQuest(questInfo)
	local _, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local seconds = WQT_Utils:GetQuestTimeString(questInfo);
	questInfo.isValid = not questInfo.alwaysHide and not (not WorldMap_DoesWorldQuestInfoPassFilters(questInfo) and seconds == 0 and questInfo.reward.type == WQT_REWARDTYPE.missing and not factionId);
end

----------------------------
-- SHARED
----------------------------

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
		factionData[id] = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = 134400 } -- Questionmark icon
		factionData[id].name = GetFactionInfoByID(id) or "Unknown Faction";
		WQT:debugPrint("Added new faction", id,factionData[id].name);
	end
	
	return factionData[id];
end

function WQT_Utils:GetCachedTypeIconData(questInfo)
	local _, _, questType, _, _, tradeskillLineIndex = GetQuestTagInfo(questInfo.questId);
	if (questInfo.isDaily)	then
		return "QuestDaily", 17, 17, true;
	elseif (questInfo.isQuestStart) then
		return "QuestNormal", 17, 17, true;
	elseif (not questType) then
		return "QuestBonusObjective", 21, 21, true;
	end
	
	
	local isNew = false;
	local originalType = questType;
	questType = questType or _V["WQT_TYPE_BONUSOBJECTIVE"];
	
	if (not cachedTypeData[questType]) then 
		cachedTypeData[questType] = {};
		isNew = true;
	end
	if (tradeskillLineIndex and not cachedTypeData[questType][tradeskillLineIndex]) then 
		cachedTypeData[questType][tradeskillLineIndex] = {};
		isNew = true;
	end
	
	if (isNew) then
		local atlasTexture, sizeX, sizeY  = QuestUtil.GetWorldQuestAtlasInfo(originalType, false, tradeskillLineIndex);
		if (tradeskillLineIndex) then
			cachedTypeData[questType][tradeskillLineIndex] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		else
			cachedTypeData[questType] = {["texture"] = atlasTexture, ["x"] = sizeX, ["y"] = sizeY};
		end
	end
	
	if (tradeskillLineIndex) then
		local data = cachedTypeData[questType][tradeskillLineIndex];
		return data.texture, data.x, data.y;
	end
	
	local data = cachedTypeData[questType];
	return data.texture, data.x, data.y;
end

function WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated)
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
		if (displayTime < SECONDS_PER_HOUR  and displayTime >= SECONDS_PER_MIN ) then
			displayTime = displayTime + SECONDS_PER_MIN ;
		end
	
		if ( timeLeftSeconds <= WORLD_QUESTS_TIME_CRITICAL_MINUTES * SECONDS_PER_MIN  ) then
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(displayTime, displayTime > SECONDS_PER_MIN  and true or false, unabreviated);
		elseif displayTime < SECONDS_PER_HOUR   then
			timeString = SecondsToTime(displayTime, true);
			color = _V["WQT_ORANGE_FONT_COLOR"];
		elseif displayTime < SECONDS_PER_DAY   then
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_HOURS:format(displayTime / SECONDS_PER_HOUR);
			end
			color = _V["WQT_GREEN_FONT_COLOR"]
		else
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_DAYS:format(displayTime / SECONDS_PER_DAY );
			end
			local _, _, _, rarity, isElite = GetQuestTagInfo(questInfo.questId);
			local isWeek = isElite and rarity == LE_WORLD_QUEST_QUALITY_EPIC
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

function WQT_Utils:GetPinTime(questInfo)
	local seconds, _, color, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo);
	local start = 0
	local timeLeft = seconds
	local total =0
	local maxTime, offset;
	if (timeLeft > 0) then
		if timeLeft >= 1440*60 then
			maxTime = 5760*60;
			offset = -720*60;
			local _, _, _, rarity, isElite = GetQuestTagInfo(questInfo.questId);
			if (timeLeft > maxTime or (isElite and rarity == LE_WORLD_QUEST_QUALITY_EPIC)) then
				maxTime = 1440 * 7*60;
				offset = 0;
			end
			
		elseif timeLeft >= 60*60 then
			maxTime = 1440*60;
			offset = 60*60;
		elseif timeLeft > 15*60 then
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
	return start, total, timeLeft, seconds, color, timeStringShort;
end

function WQT_Utils:GetMapInfoForQuest(questId)
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	return WQT_Utils:GetCachedMapInfo(zoneId);
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
			self.currentMapInfo = WQT_Utils:GetCachedMapInfo(mapAreaID);
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

function WQT_DataProvider:TriggerCallbacks(event, ...)
	if (not self.callbacks[event]) then 
		WQT:debugPrint("Tried to trigger incalid callback event:", event);
		return
	end;
	for k, func in ipairs(self.callbacks[event]) do
		func(event, ...);
	end
end

function WQT_DataProvider:ClearData()
	self.pool:ReleaseAll();
	wipe(self.iterativeList);
	wipe(self.keyList);
	wipe(self.waitingRoomRewards);
	wipe(self.waitingRoomQuest )
end

function WQT_DataProvider:SetQuestData(questInfo)
	local questId = questInfo.questId;
	
	questInfo.time.seconds = WQT_Utils:GetQuestTimeString(questInfo);
	questInfo.passedFilter = true;
	questInfo.isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questId);
end

function WQT_DataProvider:UpdateWaitingRoom()
	local questInfo;
	local updatedData = false;
	local fixed = {};
	
	for i = #self.waitingRoomQuest, 1, -1 do
		local questInfo = self.waitingRoomQuest[i];
		if (questInfo.questId and HaveQuestData(questInfo.questId)) then
			tinsert(fixed, questInfo.questId);
			self:SetQuestData(questInfo);
			if HaveQuestRewardData(questInfo.questId) then	
				SetQuestRewards(questInfo);
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
			SetQuestRewards(questInfo);
			ValidateQuest(questInfo);
			table.remove(self.waitingRoomRewards, i);
			updatedData = true;
		end
	end

	if (updatedData) then
		self:TriggerCallbacks("waitingRoom");
	end
end

function WQT_DataProvider:AddContinentMapQuests(continentZones, continentId)
	if continentZones then
		for zoneID  in pairs(continentZones) do
			self:AddQuestsInZone(zoneID, continentId or zoneID);
		end
	end
end

function WQT_DataProvider:AddWorldMapQuests(worldContinents)
	if worldContinents then
		for contID in pairs(worldContinents) do
			-- Every ID is a continent, get every zone on every continent
			local continentZones = _V["WQT_ZONE_MAPCOORDS"][contID];
			self:AddContinentMapQuests(continentZones, contID)
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneId)
	self:ClearData();
	zoneId = zoneId or self.latestZoneId or C_Map.GetBestMapForUnit("player");
	if (not zoneId) then return end;
	self.latestZoneId = zoneId
	-- If the flight map is open, we want all quests no matter what
	if ((FlightMapFrame and FlightMapFrame:IsShown()) ) then 
		local taxiId = GetTaxiMapID()
		zoneId = (taxiId and taxiId > 0) and taxiId or zoneId;
		-- World Flight Map add-on overwrite
		if (_WFMLoaded) then
			zoneId = WorldMapFrame.mapID;
		end
	end
	
	local currentMapInfo = WQT_Utils:GetCachedMapInfo(zoneId);
	if not currentMapInfo then return end;
	if (WQT.settings.list.alwaysAllQuests and currentMapInfo.mapType ~= Enum.UIMapType.World) then
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
		if (currentMapInfo.mapType == Enum.UIMapType.Continent  and continentZones) then
			self:AddContinentMapQuests(continentZones);
		elseif (currentMapInfo.mapType == Enum.UIMapType.World) then
			self:AddWorldMapQuests(continentZones);
		else
			-- Simple zone map
			self:AddQuestsInZone(zoneId, currentMapInfo.parentMapID);
		end
	end
	
	self:TriggerCallbacks("questsLoaded");
end

function WQT_DataProvider:AddQuestsInZone(zoneID, continentId)
	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	if not questsById then return false; end
	local missingData = false;
	local quest;
	
	for k, info in ipairs(questsById) do
		if (info.mapID == zoneID) then
			quest = self:AddQuest(info, info.mapID);
			if (not quest) then 
				missingData = true;
			end;
		end
	end
	
	return missingData;
end

function WQT_DataProvider:AddQuest(qInfo, zoneId)
	local duplicate = self:FindDuplicate(qInfo.questId);
	-- If there is a duplicate, we don't want to go through all the info again
	if (duplicate) then
		-- Check if the new zone is the 'official' zone, if so, use that one instead
		if (qInfo.mapID == C_TaskQuest.GetQuestZoneID(qInfo.questId) ) then
			duplicate.mapInfo.mapX = qInfo.x;
			duplicate.mapInfo.mapY = qInfo.y;
		end
		
		return duplicate;
	end
	
	local questInfo = self.pool:Acquire();
	
	questInfo.isValid = false;
	questInfo.alwaysHide = not MapUtil.ShouldShowTask(qInfo.mapID, qInfo)-- or qInfo.isQuestStart;
	questInfo.isDaily = qInfo.isDaily;
	questInfo.isAllyQuest = qInfo.isCombatAllyQuest;
	questInfo.questId = qInfo.questId;
	questInfo.mapInfo.mapX = qInfo.x;
	questInfo.mapInfo.mapY = qInfo.y;
	
	if (not HaveQuestData(qInfo.questId)) then
		tinsert(self.waitingRoomQuest, questInfo);
	end
	
	self:SetQuestData(questInfo);
	
	local haveRewardData = SetQuestRewards(questInfo);

	-- Filter out invalid quests like "Tracking Quest" in nazmir
	ValidateQuest(questInfo);
	
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
	
	for questInfo in self.pool:EnumerateActive() do
		table.insert(self.iterativeList, questInfo);
	end
	
	return self.iterativeList;
end

function WQT_DataProvider:GetKeyList()
	for id in pairs(self.keyList) do
		self.keyList[id] = nil;
	end
	
	for questInfo, v in self.pool:EnumerateActive() do
		self.keyList[questInfo.questId] = questInfo;
	end
	
	return self.keyList;
end

function WQT_DataProvider:GetQuestById(id)
	for questInfo in self.pool:EnumerateActive() do
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
