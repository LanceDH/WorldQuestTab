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

local function UpdateAzerothZones(newLevel)
	newLevel = newLevel or UnitLevel("player");
	
	local expLevel = GetAccountExpansionLevel();
	local worldTable = _V["WQT_ZONE_MAPCOORDS"][947]
	wipe(worldTable);
	
	-- world map continents depending on expansion level
	worldTable[113] = {["x"] = 0.49, ["y"] = 0.13} -- Northrend
	worldTable[424] = {["x"] = 0.46, ["y"] = 0.92} -- Pandaria
	worldTable[12] = {["x"] = 0.19, ["y"] = 0.5} -- Kalimdor
	worldTable[13] = {["x"] = 0.88, ["y"] = 0.56} -- Eastern Kingdom
	
	-- Always take the highest expansion
	if (expLevel >= LE_EXPANSION_BATTLE_FOR_AZEROTH and newLevel >= 50) then
		worldTable[875] = {["x"] = 0.54, ["y"] = 0.61} -- Zandalar
		worldTable[876] = {["x"] = 0.72, ["y"] = 0.49} -- Kul Tiras
	elseif (expLevel >= LE_EXPANSION_LEGION and newLevel >= 50) then
		worldTable[619] = {["x"] = 0.6, ["y"] = 0.41} -- Broken Isles
	end
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

local function RewardSortFunc(a, b)
	local aPassed = WQT_Utils:RewardTypePassesFilter(a.type);
	local bPassed = WQT_Utils:RewardTypePassesFilter(b.type);
	
	-- Rewards that pass the filters get priority
	if (aPassed ~= bPassed) then
		return aPassed and not bPassed;
	end
	
	if (a.type == b.type) then
		if (a.quality == b.quality) then
			if (a.id and b.id and a.id ~= b.id) then
				return a.id > b.id;
			end
			if (a.amount == b.amount) then
				return a.id < b.id;
			end
			return a.amount > b.amount;
		end
		return a.quality  > b.quality;
	end
	return a.type < b.type;
end

local function ScanTooltipRewardForPattern(questID, pattern)
	local result;
	
	WQT_Utils:AddQuestRewardsToTooltip(WQT_ScrapeTooltip, questID, TOOLTIP_QUEST_REWARDS_STYLE_DEFAULT);

	for i=2, 6 do
		local line = _G["WQT_ScrapeTooltipTooltipTextLeft"..i];
		if (not line) then break; end
		local lineText = line:GetText() or "";
		result = lineText:match(pattern);
		if (result) then break; end
	end
	
	-- Force hide compare tooltips as they'd show up for people with alwaysCompareItems set to 1
	for _, tooltip in ipairs(WQT_ScrapeTooltip.shoppingTooltips) do
		tooltip:Hide();
	end

	return result;
end

local function ZonesByExpansionSort(a, b)
	local expA = _V["WQT_ZONE_EXPANSIONS"][a];
	local expB = _V["WQT_ZONE_EXPANSIONS"][b];
	if (not expA or not expB or expA == expB) then
		return b > a;
	end
	return expB > expA;
end

----------------------------
-- QuestInfoMixin
----------------------------

local QuestInfoMixin = {};

function WQT_Utils:QuestCreationFunc()
	local questInfo = CreateFromMixins(QuestInfoMixin);
	local hasRewardData = questInfo:OnCreate();
	return questInfo, hasRewardData;
end

local function QuestResetFunc(pool, questInfo)
	questInfo:Reset();
end

function QuestInfoMixin:Init(questId, isDaily, isCombatAllyQuest, alwaysHide, posX, posY)
	self.questId = questId;
	self.isDaily = isDaily;
	self.isAllyQuest = isCombatAllyQuest;
	self.alwaysHide = alwaysHide;
	self:SetMapPos(posX, posY);
	self.tagInfo = C_QuestLog.GetQuestTagInfo(questId);
	
	self.isValid = HaveQuestData(self.questId);
	self.time.seconds = WQT_Utils:GetQuestTimeString(self); -- To check if expired or never had a time limit
	self.passedFilter = true;

	self:LoadRewards();
	
	return self.hasRewardData;
end

function QuestInfoMixin:OnCreate()
	self.time = {};
	self.reward = { 
			["typeBits"] = WQT_REWARDTYPE.missing;
		};
	self.rewardList = {};
	self.mapInfo = {};
	self.hasRewardData = false;
end

function QuestInfoMixin:SetMapPos(posX, posY)
	self.mapInfo.mapX = posX;
	self.mapInfo.mapY = posY;
end

function QuestInfoMixin:Reset()
	wipe(self.rewardList);
	
	WipeQuestInfoRecursive(self);
	-- Reset defaults
	self.reward.typeBits = WQT_REWARDTYPE.missing;
	self.hasRewardData = false;
	self.isValid = false;
	self.tagInfo = nil;
end

function QuestInfoMixin:LoadRewards(force)
	-- If we already have our data, don't try again;
	if (not force and self.hasRewardData) then return; end

	wipe(self.rewardList);
	local haveData = HaveQuestRewardData(self.questId);
	if (haveData) then
		self.reward.typeBits = WQT_REWARDTYPE.none;
		-- Items
		if (GetNumQuestLogRewards(self.questId) > 0) then
			local _, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, self.questId);

			if (rewardId) then
				local price, typeID, subTypeID = select(11, GetItemInfo(rewardId));
				if (C_Soulbinds.IsItemConduitByItemInfo(rewardId)) then
					-- Conduits
					-- Lovely yikes on getting the type
					local conduitType = ScanTooltipRewardForPattern(self.questId, "(.+)") or "";
					local subType = _V["CONDUIT_SUBTYPE"].endurance;
					if(conduitType == CONDUIT_TYPE_FINESSE) then
						subType = _V["CONDUIT_SUBTYPE"].finesse;
					elseif(conduitType == CONDUIT_TYPE_POTENCY) then
						subType = _V["CONDUIT_SUBTYPE"].potency;
					end
					self:AddReward(WQT_REWARDTYPE.conduit, ilvl, texture, quality, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardRelic), rewardId, false, subType);
				elseif (typeID == 4 or typeID == 2) then 
					-- Gear (4 = armor, 2 = weapon)
					local canUpgrade = ScanTooltipRewardForPattern(self.questId, "(%d+%+)$") and true or false;
					local rewardType = typeID == 4 and WQT_REWARDTYPE.equipment or WQT_REWARDTYPE.weapon;
					local color = typeID == 4 and WQT_Utils:GetColor(_V["COLOR_IDS"].rewardArmor) or WQT_Utils:GetColor(_V["COLOR_IDS"].rewardWeapon);
					self:AddReward(rewardType, ilvl, texture, quality, color, rewardId, canUpgrade);
				elseif (typeID == 3 and subTypeID == 11) then
					-- Relics
					-- Find upgrade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					local numItems = tonumber(ScanTooltipRewardForPattern(self.questId, "^%+(%d+)"));
					self:AddReward(WQT_REWARDTYPE.relic, numItems, texture, quality,WQT_Utils:GetColor(_V["COLOR_IDS"].rewardRelic), rewardId);
				elseif(C_Item.IsAnimaItemByID(rewardId)) then
					-- Anima
					local value = ScanTooltipRewardForPattern(self.questId, " (%d+) ") or 1;
					value = tonumber(value);

					if (WQT.settings.general.sl_genericAnimaIcons) then
						texture = 3528288;
						if (value >= 250) then
							texture = 3528287;
						end
					end
					self:AddReward(WQT_REWARDTYPE.anima, numItems * value, texture, quality, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardAnima), rewardId);
				else	
					-- Normal items
					if (texture == 894556) then
						-- Bonus player xp item is counted as actual xp
						self:AddReward(WQT_REWARDTYPE.xp, ilvl, texture, quality, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardItem), rewardId);
					elseif (typeID == 0 and subTypeID == 8 and price == 0 and ilvl > 100) then 
						-- Item converting into equipment
						self:AddReward(WQT_REWARDTYPE.equipment, ilvl, texture, quality, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardArmor), rewardId);
					else 
						self:AddReward(WQT_REWARDTYPE.item, numItems, texture, quality, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardItem), rewardId);
					end
				end
			end
		end
		-- Spells
		if (GetQuestLogRewardSpell(1, self.questId)) then
			local texture, _, _, _, _, _, _, _, rewardId = GetQuestLogRewardSpell(1, self.questId);
			self:AddReward(WQT_REWARDTYPE.spell, 1, texture, 1, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardItem), rewardId);
		end
		-- Honor
		if (GetQuestLogRewardHonor(self.questId) > 0) then
			local numItems = GetQuestLogRewardHonor(self.questId);
			self:AddReward(WQT_REWARDTYPE.honor, numItems, 1455894, 1, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardHonor));
		end
		-- Gold
		if (GetQuestLogRewardMoney(self.questId) > 0) then
			local numItems = floor(abs(GetQuestLogRewardMoney(self.questId)))
			self:AddReward(WQT_REWARDTYPE.gold, numItems, 133784, 1, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardGold));
		end
		-- Currency
		local numCurrencies = GetNumQuestLogRewardCurrencies(self.questId);
		for i=1, numCurrencies do
			local _, _, amount, currencyId = GetQuestLogRewardCurrencyInfo(i, self.questId);
			if (currencyId) then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId);
				local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyId) ~= nil;
				local name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyId, amount, currencyInfo.name, currencyInfo.iconFileID, currencyInfo.quality); 
				local currType = currencyId == _azuriteID and WQT_REWARDTYPE.artifact or (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
				local color = currType == WQT_REWARDTYPE.artifact and WQT_Utils:GetColor(_V["COLOR_IDS"].rewardArtiface) or  WQT_Utils:GetColor(_V["COLOR_IDS"].rewardCurrency);
				self:AddReward(currType, amount, texture, quality, color, currencyId);
			end
		end
		-- Player experience 
		if (GetQuestLogRewardXP(self.questId) > 0) then
			local numItems = GetQuestLogRewardXP(self.questId);
			self:AddReward(WQT_REWARDTYPE.xp, numItems, 894556, 1, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardXp));
		end
		
		self:ParseRewards();
	end

	self.hasRewardData = haveData;
end

function QuestInfoMixin:AddReward(rewardType, amount, texture, quality, color, id, canUpgrade, subType)
	local index = #self.rewardList + 1;

	-- Create reward
	local rewardInfo = self.rewardList[index] or {};
	rewardInfo.id = id or 0;
	rewardInfo.type = rewardType;
	rewardInfo.amount = amount;
	rewardInfo.texture = texture;
	rewardInfo.quality = quality;
	rewardInfo.color, rewardInfo.textColor = WQT_Utils:GetRewardTypeColorIDs(rewardType);
	rewardInfo.canUpgrade = canUpgrade;
	rewardInfo.subType = subType;
	
	self.rewardList[index] = rewardInfo;
	
	-- Raise type flag
	self.reward.typeBits = bit.bor(self.reward.typeBits, rewardType);
end

function QuestInfoMixin:ParseRewards()
	table.sort(self.rewardList, RewardSortFunc);
end

function QuestInfoMixin:TryDressUpReward()
	for k, rewardInfo in self:IterateRewards() do
		if (bit.band(rewardInfo.type, WQT_REWARDTYPE.gear) > 0) then
			local _, link = GetItemInfo(rewardInfo.id);
			DressUpItemLink(link)
		end
	end
end

function QuestInfoMixin:IterateRewards()
	return ipairs(self.rewardList);
end

function QuestInfoMixin:GetReward(index)
	if (index < 1 or index > #self.rewardList) then
		return nil;
	end
	return self.rewardList[index];
end

function QuestInfoMixin:IsExpired()
	local timeLeftSeconds =  C_TaskQuest.GetQuestTimeLeftSeconds(self.questId) or 0;
	return self.time.seconds and self.time.seconds > 0 and timeLeftSeconds < 1;
end

function QuestInfoMixin:SetAsWaypoint()
	local mapInfo = WQT_Utils:GetMapInfoForQuest(self.questId);
	local x, y = WQT_Utils:GetQuestMapLocation(self.questId, mapInfo.mapID);
	local wayPoint = UiMapPoint.CreateFromCoordinates(mapInfo.mapID, x, y);
	C_Map.SetUserWaypoint(wayPoint);
end

-- Getters for the most important reward
function QuestInfoMixin:GetFirstNoneAzeriteType()
	if (self.reward.typeBits == WQT_REWARDTYPE.none) then
		return WQT_REWARDTYPE.none;
	end

	local hasAzerite = false;
	for i = 1, #self.rewardList do
		local reward = self.rewardList[i];
		if (reward.type ~= WQT_REWARDTYPE.artifact) then
			return reward.type, reward.subType;
		else
			hasAzerite = true;
		end
	end

	return hasAzerite and WQT_REWARDTYPE.artifact or WQT_REWARDTYPE.missing;
end

function QuestInfoMixin:GetRewardType()
	if (self.reward.typeBits == WQT_REWARDTYPE.none) then
		return WQT_REWARDTYPE.none;
	end
	local reward = self.rewardList[1];
	
	local rewardType = reward and reward.type or WQT_REWARDTYPE.missing;
	local rewardSubType = reward and reward.subType;
	return rewardType, rewardSubType;
end

function QuestInfoMixin:GetRewardId()
	local reward = self.rewardList[1];
	return reward and reward.id or 0;
end

function QuestInfoMixin:GetRewardAmount()
	local reward = self.rewardList[1];
	return reward and reward.amount or 0;
end

function QuestInfoMixin:GetRewardTexture()
	if (self.reward.typeBits == WQT_REWARDTYPE.none) then
		-- Dark empty texture
		return "Interface/Garrison/GarrisonMissionUIInfoBoxBackgroundTile";
	end

	local reward = self.rewardList[1];
	return reward and reward.texture or 134400;
end

function QuestInfoMixin:GetRewardQuality()
	local reward = self.rewardList[1];
	return reward and reward.quality or 1;
end

function QuestInfoMixin:GetRewardColor()
	if (self.reward.typeBits == WQT_REWARDTYPE.none) then
		return WQT_Utils:GetColor(_V["COLOR_IDS"].rewardNone);
	end
	local reward = self.rewardList[1];
	return reward and reward.color or WQT_Utils:GetColor(_V["COLOR_IDS"].rewardMissing);
end

function QuestInfoMixin:GetRewardCanUpgrade()
	local reward = self.rewardList[1];
	return reward and reward.canUpgrade;
end

function QuestInfoMixin:IsCriteria(forceSingle)
	local bountyBoard = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]];
	if (not bountyBoard) then return false; end
	
	-- Try only selected
	if (forceSingle) then
		return bountyBoard:IsWorldQuestCriteriaForSelectedBounty(self.questId);
	end
	
	-- Try any of them
	if (bountyBoard.bounties) then
		for k, bounty in ipairs(bountyBoard.bounties) do
			if (C_QuestLog.IsQuestCriteriaForBounty(self.questId, bounty.questID)) then
				return true;
			end
		end
	end
	
	return false;
end

function QuestInfoMixin:GetTitle()
	local title = C_TaskQuest.GetQuestInfoByQuestID(self.questId);
	return title;
end

function QuestInfoMixin:GetTagInfo()
	return self.tagInfo;
end

function QuestInfoMixin:IsDisliked()
	return WQT_Utils:QuestIsDisliked(self.questId);
end

----------------------------
-- MIXIN
----------------------------
-- Callbacks:
-- "BufferUpdated"	(progress): % of buffered quests has changed. progress = 0-1
-- "QuestsLoaded"	(): Buffer emptied
-- "WaitingRoom"	(): Quest in the waiting room had data updated

WQT_DataProvider = CreateFromMixins(WQT_CallbackMixin);

function WQT_DataProvider:Init()
	self.frame = CreateFrame("FRAME");
	self.frame:SetScript("OnUpdate", function(frame, ...) self:OnUpdate(...); end);
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...); end);
	self.frame:RegisterEvent("QUEST_LOG_UPDATE");
	self.frame:RegisterEvent("PLAYER_LEVEL_UP");

	self.pool = CreateObjectPool(WQT_Utils.QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.keyList = {};
	-- If we added a quest which we didn't have rewarddata for yet, it gets added to the waiting room
	self.waitingRoomRewards = {};
	
	self.bufferedZones = {};
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			-- If we change map, reset the CD, we want new quest info
			self:LoadQuestsInZone(WorldMapFrame.mapID);
		end);

	UpdateAzerothZones(); 
	
	self.updateCD = 0;
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		-- If the last update was too recent, it's probably just quest data becoming available
		if (self.updateCD > 0) then
			self:UpdateWaitingRoom();
		else
			self:LoadQuestsInZone(WorldMapFrame.mapID);
		end
			
	elseif (event == "PLAYER_LEVEL_UP") then
		local level = ...;
		UpdateAzerothZones(level); 
	end
end

function WQT_DataProvider:OnUpdate(elapsed)
	if (self.updateCD > 0) then
		self.updateCD = max(0, self.updateCD - elapsed);
	end

	if (#self.bufferedZones > 0) then
		-- Figure out how many zoned to check each frame
		local numQuests = #self.bufferedZones;
		local num = 10;
		num =  min (numQuests, num);
		local questsAdded = false;
		
		-- Load quests
		for i = numQuests, numQuests - num + 1, -1 do
			local zoneId = self.bufferedZones[i];
			local zoneInfo = WQT_Utils:GetCachedMapInfo(zoneId);
			local hadQuests = self:AddQuestsInZone(zoneId, zoneInfo.parentMapID);
			questsAdded = questsAdded or hadQuests;
			tremove(self.bufferedZones, i);
			self.numZonesProcessed = self.numZonesProcessed + 1;
		end
		
		self:UpdateBufferProgress();
		
		if (#self.bufferedZones == 0) then
			self.isUpdating = false;
			self:TriggerCallback("QuestsLoaded");
		end
	end
end

function WQT_DataProvider:ClearData()
	self.pool:ReleaseAll();
	wipe(self.iterativeList);
	wipe(self.keyList);
	wipe(self.waitingRoomRewards);
	wipe(self.bufferedZones);
	self.numZonesProcessed = 0;
end

function WQT_DataProvider:UpdateWaitingRoom()
	local questInfo;
	local updatedData = false;

	for i = #self.waitingRoomRewards, 1, -1 do
		questInfo = self.waitingRoomRewards[i];
		if ( questInfo.questId and HaveQuestRewardData(questInfo.questId)) then
			questInfo:LoadRewards(true);
			table.remove(self.waitingRoomRewards, i);
			updatedData = true;
		end
	end
	
	if (updatedData) then
		self:TriggerCallback("WaitingRoom");
	end
end

function WQT_DataProvider:AddContinentMapQuests(continentZones, continentId)
	if continentZones then
		for zoneID  in pairs(continentZones) do
			self:AddZoneToBuffer(zoneID);
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

function WQT_DataProvider:AddZoneToBuffer(zoneID)
	tinsert(self.bufferedZones, zoneID);
	
	-- Check for subzones and add those as well
	local subZones = _V["ZONE_SUBZONES"][zoneID];
	if (subZones) then
		for k, subID in ipairs(subZones) do
			tinsert(self.bufferedZones, subID);
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneID)
	self.isUpdating = true;
	self:ClearData();
	zoneID = zoneID or self.latestZoneId or C_Map.GetBestMapForUnit("player");
	
	if (not zoneID) then return end;
	
	self.updateCD = 0.5;
	self.latestZoneId = zoneID
	-- If the flight map is open, we want all quests no matter what
	if ((FlightMapFrame and FlightMapFrame:IsShown()) ) then 
		local taxiId = GetTaxiMapID()
		zoneID = (taxiId and taxiId > 0) and taxiId or zoneID;
		-- World Flight Map add-on overwrite
		if (_WFMLoaded) then
			zoneID = WorldMapFrame.mapID;
		end
	end
	
	local currentMapInfo = WQT_Utils:GetCachedMapInfo(zoneID);
	if not currentMapInfo then return end;
	if (WQT.settings.list.alwaysAllQuests ) then
		local expLevel = _V["WQT_ZONE_EXPANSIONS"][zoneID];
		if (not expLevel or expLevel == 0) then
			expLevel = GetAccountExpansionLevel();
		end
		
		-- Gather quests for all zones either matching current zone's expansion, or matching no expansion (i.e. Stranglethorn fishing quest)
		local count = 0;
		for zoneID, expId in pairs(_V["WQT_ZONE_EXPANSIONS"])do
			if (expId == 0 or expId == expLevel) then
				self:AddZoneToBuffer(zoneID);
			end
			count = count + 1;
		end
	else
		local continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneID];
		if (currentMapInfo.mapType == Enum.UIMapType.World) then
			self:AddWorldMapQuests(continentZones);
		elseif (continentZones) then -- Zone with multiple subzones
			self:AddContinentMapQuests(continentZones);
		else
			self:AddZoneToBuffer(zoneID);
		end
	end
	-- Sort current expansion to front, they are more likely to have quests
	table.sort(self.bufferedZones, ZonesByExpansionSort);
	self:UpdateBufferProgress();

	if (self.bufferedZones == 0) then
		self.isUpdating = false;
		
	end
	self:TriggerCallback("QuestsLoaded");
end

function WQT_DataProvider:AddQuestsInZone(zoneID, continentId)
	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	local hadQuests;
	if (questsById) then
		for k, info in ipairs(questsById) do
			if (info.mapID == zoneID) then
				self:AddQuest(info);
			end
		end
		hadQuests = #questsById > 0;
	end
	
	return hadQuests;
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
			duplicate:SetMapPos(qInfo.x, qInfo.y);
		end
		
		return duplicate;
	end
	
	local questInfo = self.pool:Acquire();
	local alwaysHide = not MapUtil.ShouldShowTask(qInfo.mapID, qInfo);
	local posX, posY = WQT_Utils:GetQuestMapLocation(qInfo.questId, qInfo.mapID);
	local haveRewardData = questInfo:Init(qInfo.questId, qInfo.isDaily, qInfo.isCombatAllyQuest, alwaysHide, posX, posY);

	-- If we have no data for the quest, don't include them in the waiting room, they are probably messed up
	-- Worst case we do get their data at a later point, it will cause everything to refresh anyway
	if (not haveRewardData and HaveQuestData(qInfo.questId)) then
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
		if (questInfo:IsCriteria(WQT.settings.general.bountySelectedOnly)) then return true; end
	end
	return false
end

function WQT_DataProvider:HasNoQuests()
	if (self:IsBuffereingQuests()) then return false; end
	if (self.pool:GetNumActive() > 0) then return false; end
	return true;
end

function WQT_DataProvider:IsBuffereingQuests()
	return #self.bufferedZones > 0;
end 

function WQT_DataProvider:UpdateBufferProgress()
	local total = #self.bufferedZones + self.numZonesProcessed;
	local progress = 1-(#self.bufferedZones / total);
	
	self:TriggerCallback("BufferUpdated", progress);
end	

function WQT_DataProvider:ReloadQuestRewards()
	for questInfo, v in self.pool:EnumerateActive() do
		questInfo:LoadRewards(true);
	end
	self:TriggerCallback("QuestsLoaded");
end

function WQT_DataProvider:IsUpdating()
	return self.isUpdating or #self.bufferedZones > 0 or #self.waitingRoomRewards > 0;
end

