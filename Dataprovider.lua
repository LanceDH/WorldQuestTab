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
	
	local expLevel = GetAccountExpansionLevel();
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
	local questInfo = {
		["time"] = {},
		["reward"] = { 
			["type"] = WQT_REWARDTYPE.missing;
			["typeBits"] = WQT_REWARDTYPE.missing;
			["id"] = 0;
			["amount"] = 0;
			["texture"] = 134400;
			["quality"] = 1;
			["color"] = _V["WQT_COLOR_MISSING"];
		}, 
		["mapInfo"] = {}
	};
	return questInfo;
end

local function WipeQuestInfoRecursive(questInfo)
	-- Clean out everthing that isn't a color
	for k, v in pairs(questInfo) do
		local objType = type(v);
		if objType == "table" and not v.GetRGB then
			WipeQuestInfoRecursive(v)
		else
			if (objType == "boolean" or objType == "number") then
				questInfo[k] = nil;
			elseif (objType == "string") then
				questInfo[k] = "";
			end
		end
	end
end

local function QuestResetFunc(pool, questInfo)
	WipeQuestInfoRecursive(questInfo);
	-- Reset defaults
	questInfo.reward.type = WQT_REWARDTYPE.missing;
	questInfo.reward.typeBits = WQT_REWARDTYPE.missing;
	questInfo.reward.amount = 0;
	questInfo.reward.texture = 134400;
	questInfo.reward.quality = 1;
	questInfo.reward.color = _V["WQT_COLOR_MISSING"];
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
	
	-- Force hide compare tooltips as they'd show up for people with alwaysCompareItems set to 1
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
			local currType = currencyId == _azuriteID and WQT_REWARDTYPE.artifact or (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
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
	local reward = questInfo.reward;
	-- First reward added will be our displayed reward
	if (questInfo.reward.type == WQT_REWARDTYPE.none) then
		amount = amount or amount;
		reward.id = id;
		reward.type = rewardType or reward.type;
		reward.amount = amount or reward.amount;
		reward.texture = texture or reward.texture;
		reward.quality = quality or reward.quality;
		reward.color = color or reward.color;
		reward.canUpgrade = canUpgrade;
	end
	reward.typeBits = bit.bor(reward.typeBits, rewardType);
end

local function SetQuestRewards(questInfo)
	local haveData = HaveQuestRewardData(questInfo.questId);
	
	if haveData then
		-- Setup default for no reward
		questInfo.reward.typeBits = 0;
		questInfo.reward.type = WQT_REWARDTYPE.none;
		questInfo.reward.amount = 0;
		questInfo.reward.texture = "Interface/Garrison/GarrisonMissionUIInfoBoxBackgroundTile";
		questInfo.reward.quality = 1;
		questInfo.reward.color = _V["WQT_COLOR_NONE"];

		local currencyId, currencyType, currencyQuality, currencyAmount, currencyTexture = GetMostImpressiveCurrency(questInfo);
		-- Items
		if (GetNumQuestLogRewards(questInfo.questId) > 0) then
			local _, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, questInfo.questId);
			if rewardId then
				local price, typeID, subTypeID = select(11, GetItemInfo(rewardId));
				if (typeID == 4 or typeID == 2) then -- Gear (4 = armor, 2 = weapon)
					local canUpgrade = ScanTooltipRewardForPattern(questInfo.questId, "(%d+%+)$") and true or false;
					local rewardType = typeID == 4 and WQT_REWARDTYPE.equipment or WQT_REWARDTYPE.weapon;
					local color = typeID == 4 and _V["WQT_COLOR_ARMOR"] or _V["WQT_COLOR_WEAPON"];
					AddQuestReward(questInfo, rewardType, ilvl, texture, quality, color, rewardId, canUpgrade);
				elseif (typeID == 3 and subTypeID == 11) then
					-- Find upgrade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					local numItems = tonumber(ScanTooltipRewardForPattern(questInfo.questId, "^%+(%d+)"));
					AddQuestReward(questInfo, WQT_REWARDTYPE.relic, numItems, texture, quality, _V["WQT_COLOR_RELIC"], rewardId);
				else	
					-- Normal items
					if (typeID == 0 and subTypeID == 8 and price == 0 and ilvl > 100) then 
						-- Item converting into equipment
						AddQuestReward(questInfo, WQT_REWARDTYPE.equipment, ilvl, texture, quality, _V["WQT_COLOR_ARMOR"], rewardId);
					else
						AddQuestReward(questInfo, WQT_REWARDTYPE.item, numItems, texture, quality, _V["WQT_COLOR_ITEM"], rewardId);
					end
				end
			end
		end
		-- Spells
		if (GetQuestLogRewardSpell(1, questInfo.questId)) then
			local texture, _, _, _, _, _, _, _, rewardId = GetQuestLogRewardSpell(1, questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.spell, 1, texture, 1, _V["WQT_COLOR_ITEM"], rewardId);
		end
		-- Honor
		if GetQuestLogRewardHonor(questInfo.questId) > 0 then
			local numItems = GetQuestLogRewardHonor(questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.honor, numItems, 1455894, 1, _V["WQT_COLOR_HONOR"]);
		end
		-- Important currency (i.e. Azerite and prismatic manapearls)
		if (currencyId and (currencyType < WQT_REWARDTYPE.gold or currencyQuality > 1)) then
			local color = currencyType == WQT_REWARDTYPE.artifact and _V["WQT_COLOR_ARTIFACT"] or  _V["WQT_COLOR_CURRENCY"];
			AddQuestReward(questInfo, currencyType, currencyAmount, currencyTexture, currencyQuality, color, currencyId);
		end
		-- Gold
		if GetQuestLogRewardMoney(questInfo.questId) > 0 then
			local numItems = floor(abs(GetQuestLogRewardMoney(questInfo.questId) / 10000))
			AddQuestReward(questInfo, WQT_REWARDTYPE.gold, numItems, 133784, 1, _V["WQT_COLOR_GOLD"]);
		end
		-- Additional or important currencies (i.e. War resources)
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
		-- Player experience 
		if haveData and GetQuestLogRewardXP(questInfo.questId) > 0 then
			local numItems = GetQuestLogRewardXP(questInfo.questId);
			AddQuestReward(questInfo, WQT_REWARDTYPE.xp, numItems, 894556, 1, _V["WQT_COLOR_ITEM"]);
		end
	end

	return haveData;
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
			self:LoadQuestsInZone(self.currentMapId);
		end
	end)
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		self:LoadQuestsInZone(self.currentMapId);
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
		WQT:debugPrint("Tried to trigger invalid callback event:", event);
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
end

function WQT_DataProvider:SetQuestData(questInfo)
	local questId = questInfo.questId;
	
	questInfo.isValid = HaveQuestData(questInfo.questId);
	questInfo.time.seconds = WQT_Utils:GetQuestTimeString(questInfo);
	questInfo.passedFilter = true;
	questInfo.isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questId);
end

function WQT_DataProvider:UpdateWaitingRoom()
	local questInfo;
	local updatedData = false;

	for i = #self.waitingRoomRewards, 1, -1 do
		questInfo = self.waitingRoomRewards[i];
		if ( questInfo.questId and HaveQuestRewardData(questInfo.questId)) then
			SetQuestRewards(questInfo);
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
		-- If we don't have an expansion linked to the zone, use the player's expansion level isntead
		local zoneExpansion = _V["WQT_ZONE_EXPANSIONS"][zoneId] or GetAccountExpansionLevel();
		local zones = _V["ZONES_BY_EXPANSION"][zoneExpansion];
		if (zones) then
			for key, zoneID in ipairs(zones) do	
				local zoneInfo = WQT_Utils:GetCachedMapInfo(zoneId);
				self:AddQuestsInZone(zoneID, zoneInfo.parentMapID);
			end
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
	local missingData = false;

	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	if (questsById) then
		for k, info in ipairs(questsById) do
			if (info.mapID == zoneID) then
				local hasData = self:AddQuest(info);
				if (not hasData) then 
					missingData = true;
				end;
			end
		end
	end

	return missingData;
end

function WQT_DataProvider:AddQuest(qInfo)
	-- Setting to filter daily world quests
	if (not WQT.settings.list.includeDaily and qInfo.isDaily) then
		return true;
	end

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

	questInfo.alwaysHide = not MapUtil.ShouldShowTask(qInfo.mapID, qInfo)
	questInfo.isDaily = qInfo.isDaily;
	questInfo.isAllyQuest = qInfo.isCombatAllyQuest;
	questInfo.questId = qInfo.questId;
	questInfo.mapInfo.mapX = qInfo.x;
	questInfo.mapInfo.mapY = qInfo.y;

	self:SetQuestData(questInfo);
	
	local haveRewardData = SetQuestRewards(questInfo);

	if (not haveRewardData) then
		C_TaskQuest.RequestPreloadRewardData(qInfo.questId);
		tinsert(self.waitingRoomRewards, questInfo);
		return false;
	end;

	return true;
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
