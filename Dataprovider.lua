﻿local _, addon = ...

----------------------------
-- VARIABLES
----------------------------

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;

local _WFMLoaded = C_AddOns.IsAddOnLoaded("WorldFlightMap");
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
	if (expLevel >= LE_EXPANSION_WAR_WITHIN and newLevel >= 70) then
		worldTable[2274] = {["x"] = 0.28, ["y"] = 0.84} -- Khaz Algar
	elseif (newLevel >= 10) then
		worldTable[1978] = {["x"] = 0.77, ["y"] = 0.22} -- Dragon Isles
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
	
	if (a.quality == b.quality) then
		if (a.quality == b.quality) then
			if (a.id and b.id and a.id ~= b.id) then
				return a.id > b.id;
			end
			if (a.amount == b.amount) then
				return a.id < b.id;
			end
			return a.amount > b.amount;
		end
		return a.type  < b.type;
	end
	return a.quality > b.quality;
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

function WQT_Utils:QuestCreationFunc(questId)
	local questInfo = CreateFromMixins(QuestInfoMixin);
	questInfo:OnCreate();
	return questInfo;
end

local function QuestResetFunc(pool, questInfo)
	questInfo:Reset();
end

function QuestInfoMixin:Init(questId, qInfo, alwaysHide, posX, posY)
	self.questId = questId;
	self.questID = questId;
	self.isDaily = qInfo.isDaily;
	self.isAllyQuest = qInfo.isCombatAllyQuest;
	self.alwaysHide = alwaysHide;
	self:SetMapPos(posX, posY);
	self.tagInfo = C_QuestLog.GetQuestTagInfo(questId);
	self.isBonusQuest = self.tagInfo == nil;
	self.isBanned = _V["BUGGED_POI"][questId] ==  qInfo.mapID;
	self.time.seconds = WQT_Utils:GetQuestTimeString(self); -- To check if expired or never had a time limit
	self.passedFilter = true;
	self:UpdateValidity();
	
	-- quest type
	self.typeBits = WQT_QUESTTYPE.normal;
	if (self.isDaily) then self.typeBits = bit.bor(self.typeBits, WQT_QUESTTYPE.daily); end
	if (C_QuestLog.IsThreatQuest(self.questId)) then self.typeBits = bit.bor(self.typeBits, WQT_QUESTTYPE.threat); end
	if (C_QuestLog.IsQuestCalling(self.questId)) then self.typeBits = bit.bor(self.typeBits, WQT_QUESTTYPE.calling); end
	if (self.isCombatAllyQuest) then self.typeBits = bit.bor(self.typeBits, WQT_QUESTTYPE.combatAlly); end

	-- rewards
	self:LoadRewards();
	
	return self.hasRewardData;
end

function QuestInfoMixin:UpdateValidity()
	self.isValid = not self.isBanned and HaveQuestData(self.questId);
	return self.isValid;
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
	self.typeBits = WQT_QUESTTYPE.normal;
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
				local price, typeID, subTypeID = select(11, C_Item.GetItemInfo(rewardId));
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
		if (C_QuestInfoSystem.HasQuestRewardSpells(self.questId)) then
			local spellIds = C_QuestInfoSystem.GetQuestRewardSpells(self.questId);

			for k, spelldId in ipairs(spellIds) do
				local spellInfo = C_Spell.GetSpellInfo(spelldId)

				self:AddReward(WQT_REWARDTYPE.spell, 1, spellInfo.texture, 1, WQT_Utils:GetColor(_V["COLOR_IDS"].rewardItem), spellIds);
			end
			
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
		local currencies = C_QuestLog.GetQuestRewardCurrencies(self.questId);
		for k, currency in ipairs(currencies) do
			local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currency.currencyID) ~= nil;
			local currType = currency.currencyID == _azuriteID and WQT_REWARDTYPE.artifact or (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
			local color = currType == WQT_REWARDTYPE.artifact and WQT_Utils:GetColor(_V["COLOR_IDS"].rewardArtiface) or  WQT_Utils:GetColor(_V["COLOR_IDS"].rewardCurrency);
			self:AddReward(currType, currency.totalRewardAmount, currency.texture, currency.quality, color, currency.currencyID);
		end
		-- XP
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
			local _, link = C_Item.GetItemInfo(rewardInfo.id);
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

function QuestInfoMixin:GetTagInfo()
	return self.tagInfo;
end

function QuestInfoMixin:IsDisliked()
	return WQT_Utils:QuestIsDisliked(self.questId);
end

function QuestInfoMixin:DataIsValid()
	return self.questId ~= nil;
end

function QuestInfoMixin:IsSpecialType()
	return self.typeBits ~= WQT_QUESTTYPE.normal;
end

function QuestInfoMixin:IsQuestOfType(questType)
	return bit.band(self.typeBits, questType) > 0;
end

----------------------------
-- MIXIN
----------------------------

WQT_DataProvider = {};

function WQT_DataProvider:Init()
	self.frame = CreateFrame("FRAME");
	self.frame:SetScript("OnUpdate", function(frame, ...) self:OnUpdate(...); end);
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...); end);
	self.frame:SetScript("OnLoad", function(frame, ...) self:OnEvent(...); end);
	self.frame:RegisterEvent("QUEST_LOG_UPDATE");
	self.frame:RegisterEvent("PLAYER_LEVEL_UP");
	
	self.pool = CreateObjectPool(WQT_Utils.QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.ignoreNextLogUpdate = false;
	
	self.zoneLoading = {
		startTimestamp = 0,
		remainingZones = {},
		numRemaining = 0,
		numTotal = 0,
		questsFound = {},
		questsActive = {},
	};

	UpdateAzerothZones(); 
	
	self.updateCD = 0;
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		local mapID = WorldMapFrame.mapID;
		self:LoadQuestsInZone(mapID);

	elseif (event == "PLAYER_LEVEL_UP") then
		local level = ...;
		UpdateAzerothZones(level); 
	end
end

local MAX_PROCESSING_TIME = 0.005;
function WQT_DataProvider:OnUpdate(elapsed)
	if(self.zoneLoading.numRemaining > 0) then
		
		local processedCount = 0;
		local updateStart = GetTimePreciseSec();
		local timeSpent = 0;

		-- Get quests from all the zones in our list
		-- Only spend a max amount of time on it each frame to prevent extreme stutters when we have a lot of zones
		for zoneID in pairs(self.zoneLoading.remainingZones) do
			self.zoneLoading.remainingZones[zoneID] = nil;
			self.zoneLoading.numRemaining = self.zoneLoading.numRemaining - 1;
			processedCount = processedCount + 1;

			local taskPOIs = C_TaskQuest.GetQuestsOnMap(zoneID);
			local numPoIs = taskPOIs and #taskPOIs or 0;
			if (numPoIs > 0) then
				for k, apiInfo in ipairs(taskPOIs) do
					self.zoneLoading.questsFound[apiInfo.questID] = apiInfo;
				end
			end

			timeSpent = GetTimePreciseSec() - updateStart;
			if (timeSpent >= MAX_PROCESSING_TIME) then
				break;
			end
		end

		-- Current progress
		local progress = (self.zoneLoading.numTotal - self.zoneLoading.numRemaining) / self.zoneLoading.numTotal;
		--WQT:debugPrint(string.format("Buffered: %3s (%s) in %.5fs ", processedCount, self.zoneLoading.numRemaining, timeSpent));

		if (self.zoneLoading.numRemaining == 0) then
			-- We're done getting quests from all the zones. Turn them into quest info for the add-on
			-- Remove quests we no longer need, and add new ones.

			local questForRemove = {};
			local questsToAdd = {};
			-- Mark all for removal
			for addonInfo in self.pool:EnumerateActive() do
				questForRemove[addonInfo.questID] = addonInfo;
			end

			local acceptedCount = 0;
			local updated = 0;
			-- Go through quests, mark for add if we don't currently have it, otherwise unmark for removal
			for questID, apiInfo in pairs(self.zoneLoading.questsFound) do
				acceptedCount = acceptedCount + 1;
				if (not questForRemove[questID]) then
					questsToAdd[questID] = apiInfo;
				else
					local addonInfo = questForRemove[questID];
					questForRemove[questID] = nil;
					local updateSuccess = false;
					-- Quest log update might have been for missing data
					if (not addonInfo.hasRewardData) then
						updateSuccess = updateSuccess or addonInfo:LoadRewards(true);
					end
					if (not addonInfo.isValid) then
						updateSuccess = updateSuccess or addonInfo:UpdateValidity();
					end
					if (updateSuccess) then
						updated = updated + 1;
					end
				end
			end

			local removed = 0;
			-- Remove everything still marked for removal
			for questID, addonInfo in pairs(questForRemove) do
				removed = removed + 1;
				self.pool:Release(addonInfo);
			end

			local added = 0;
			-- Add all new ones
			for questID, apiInfo in pairs(questsToAdd) do
				added = added + 1;
				local questInfo = self.pool:Acquire();
				local alwaysHide = not MapUtil.ShouldShowTask(apiInfo.mapID, apiInfo);
				local posX, posY = WQT_Utils:GetQuestMapLocation(apiInfo.questID, apiInfo.mapID);
				questInfo:Init(apiInfo.questID, apiInfo, alwaysHide, posX, posY);
			end

			-- local timeSinceStart = GetTimePreciseSec() - self.zoneLoading.startTimestamp;

			-- for info in self.pool:EnumerateActive() do
			-- 	--print("Active", info.questID);
			-- end

			WQT:debugPrint(string.format("Done: %s quests (-%s +%s ~%s)", acceptedCount, removed, added, updated));

			self.zoneLoading.startTimestamp = 0;
			progress = 0;
			EventRegistry:TriggerEvent("WQT.DataProvider.QuestsLoaded");
		end

		EventRegistry:TriggerEvent("WQT.DataProvider.ProgressUpdated", progress);
	end
end

function WQT_DataProvider:ClearData()
	wipe(self.iterativeList);
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

function WQT_DataProvider:AddZoneToRemainingUnique(zoneID)
	if(self.zoneLoading.remainingZones[zoneID]) then return; end

	self.zoneLoading.remainingZones[zoneID] = true;
	self.zoneLoading.numRemaining = self.zoneLoading.numRemaining + 1;
	self.zoneLoading.numTotal = self.zoneLoading.numTotal + 1;
end

function WQT_DataProvider:AddZoneToBuffer(zoneID)
	self:AddZoneToRemainingUnique(zoneID);
	
	-- Check for subzones and add those as well
	local subZones = _V["ZONE_SUBZONES"][zoneID];
	if (subZones) then
		for k, subID in ipairs(subZones) do
			self:AddZoneToRemainingUnique(zoneID);
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneID)

	if (not zoneID) then return end
	self:ClearData();
	zoneID = zoneID or self.latestZoneId or C_Map.GetBestMapForUnit("player");
	
	if (not zoneID) then return end;

	if (not WorldMapFrame:IsShown()) then
		print("No update while invisible");
		return;
	end

	if(self.zoneLoading.startTimestamp > 0) then print("Interrupt") end

	
	self.zoneLoading.startTimestamp = GetTimePreciseSec();
	self.zoneLoading.numRemaining = 0;
	self.zoneLoading.numTotal = 0;
	wipe(self.zoneLoading.remainingZones);
	wipe(self.zoneLoading.questsFound);

	
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
end

function WQT_DataProvider:GetIterativeList()
	wipe(self.iterativeList);
	
	for questInfo in self.pool:EnumerateActive() do
		table.insert(self.iterativeList, questInfo);
	end
	
	return self.iterativeList;
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

function WQT_DataProvider:ReloadQuestRewards()
	for questInfo, v in self.pool:EnumerateActive() do
		questInfo:LoadRewards(true);
	end
	--self:TriggerCallback("QuestsLoaded");
end
