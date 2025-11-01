local _, addon = ...

----------------------------
-- VARIABLES
----------------------------

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;

local _azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();

----------------------------
-- LOCAL FUNCTIONS
----------------------------
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
		return a.quality > b.quality;
	end
	return a.type < b.type;
end

local function ScanTooltipRewardForPattern(questID, pattern)
	local result;

	QuestUtils_AddQuestRewardsToTooltip(WQT_ScrapeTooltip, questID, TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST);

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

local function SortQuestList(a, b, sortID)
	-- Invalid goes to the bottom
	if (not a.isValid or not b.isValid) then
		if (a.isValid == b.isValid) then 
			return a.questID < b.questID;
		end;
		return a.isValid and not b.isValid;
	end
	
	-- Filtered out quests go to the back (for debug view mainly)
	if (not a.passedFilter or not b.passedFilter) then
		if (a.passedFilter == b.passedFilter) then 
			return a.questID < b.questID; 
		end;
		return a.passedFilter and not b.passedFilter;
	end
	
	-- Disliked quests go to the back of the list
	local aDisliked = a:IsDisliked();
	local bDisliked = b:IsDisliked();
	if (aDisliked ~= bDisliked) then 
		return not aDisliked;
	end 

	-- Sort by a list of filters depending on the current filter choice
	local order = _V["SORT_OPTION_ORDER"][sortID];
	if (not order) then
		order = {};
		WQT:debugPrint("No sort order for", sortID);
		return a.questID < b.questID;
	end
	
	for k, criteria in ipairs(order) do
		if(_V["SORT_FUNCTIONS"][criteria]) then
			local result = _V["SORT_FUNCTIONS"][criteria](a, b);
			if (result ~= nil) then 
				return result 
			end;
		else
			WQT:debugPrint("Invalid sort criteria", criteria);
		end
	end
	
	-- Worst case fallback
	return a.questID < b.questID;
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

function QuestInfoMixin:Reset()
	wipe(self.rewardList);
	
	WipeQuestInfoRecursive(self);
	-- Reset defaults
	self.reward.typeBits = WQT_REWARDTYPE.missing;
	self.hasRewardData = false;
	self.isValid = false;
	self.tagInfo = nil;
end

function QuestInfoMixin:Init(questID, qInfo)
	self.questID = questID;
	self.mapID = qInfo and qInfo.mapID;
	self:UpdateTitleAndFaction();

	self.tagInfo = C_QuestLog.GetQuestTagInfo(questID);
	
	self.classification = C_QuestInfoSystem.GetQuestClassification(questID);
	self.isBonusQuest = self.classification == Enum.QuestClassification.BonusObjective;
	self.isBanned = qInfo and _V["BUGGED_POI"][questID] == qInfo.mapID;
	self.alwaysHide = self.isBonusQuest and not MapUtil.ShouldShowTask(qInfo.mapID, qInfo);
	
	self.passedFilter = true;
	self:UpdateValidity();
	self:UpdateTimeRemaining();
	self:UpdateHasWarbandBonus();

	-- rewards
	self:LoadRewards();
	
	return self.hasRewardData;
end

function QuestInfoMixin:UpdateTitleAndFaction()
	if (self.factionID == nil or self.title == nil) then
		local oldTitle = self.title;
		local oldFaction = self.factionID;
		local title, factionID = C_TaskQuest.GetQuestInfoByQuestID(self.questID);
		self.title = title;
		self.factionID = factionID;
		return self.factionID ~= oldFaction or self.title ~= oldTitle;
	end

	return false;
end

function QuestInfoMixin:UpdateHasWarbandBonus()
	self.hasWarbandBonus = C_QuestLog.QuestContainsFirstTimeRepBonusForPlayer(self.questID);
end

function QuestInfoMixin:UpdateValidity()
	local correctClassification = self.classification == Enum.QuestClassification.BonusObjective or self.classification == Enum.QuestClassification.WorldQuest;
	self.isValid = correctClassification and not self.isBanned and HaveQuestData(self.questID);
	return self.isValid;
end

function QuestInfoMixin:UpdateTimeRemaining()
	local oldTime = self.time.seconds;
	self.time.seconds = C_TaskQuest.GetQuestTimeLeftSeconds(self.questID) or 0;
	return self.time.seconds ~= oldTime;
end

function QuestInfoMixin:OnCreate()
	self.time = {};
	self.reward = { 
			["typeBits"] = WQT_REWARDTYPE.missing;
		};
	self.rewardList = {};
	self.hasRewardData = false;
end



function QuestInfoMixin:LoadRewards(force)
	-- If we already have our data, don't try again;
	if (not force and self.hasRewardData) then return; end
	
	wipe(self.rewardList);
	local haveData = HaveQuestRewardData(self.questID);
	if (haveData) then
		self.reward.typeBits = WQT_REWARDTYPE.none;
		-- Items
		if (GetNumQuestLogRewards(self.questID) > 0) then
			local _, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, self.questID);
			
			if (rewardId) then
				local price, typeID, subTypeID = select(11, C_Item.GetItemInfo(rewardId));
				if (C_Soulbinds.IsItemConduitByItemInfo(rewardId)) then
					-- Conduits
					-- Lovely yikes on getting the type
					local conduitType = ScanTooltipRewardForPattern(self.questID, "(.+)") or "";
					local subType = _V["CONDUIT_SUBTYPE"].endurance;
					if(conduitType == CONDUIT_TYPE_FINESSE) then
						subType = _V["CONDUIT_SUBTYPE"].finesse;
					elseif(conduitType == CONDUIT_TYPE_POTENCY) then
						subType = _V["CONDUIT_SUBTYPE"].potency;
					end
					self:AddReward(WQT_REWARDTYPE.conduit, ilvl, texture, quality, rewardId, false, subType);
				elseif (typeID == Enum.ItemClass.Armor or typeID == Enum.ItemClass.Weapon) then 
					local canUpgrade = ScanTooltipRewardForPattern(self.questID, "(%d+%+)$") and true or false;
					local rewardType = typeID == Enum.ItemClass.Armor and WQT_REWARDTYPE.equipment or WQT_REWARDTYPE.weapon;
					self:AddReward(rewardType, ilvl, texture, quality, rewardId, canUpgrade);
				elseif (typeID == Enum.ItemClass.Gem and subTypeID == Enum.ItemGemSubclass.Artifactrelic) then
					-- Find upgrade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					numItems = tonumber(ScanTooltipRewardForPattern(self.questID, "(%d+)%+$")) or 1;
					self:AddReward(WQT_REWARDTYPE.relic, numItems, texture, quality, rewardId, true);
				elseif(C_Item.IsAnimaItemByID(rewardId)) then
					-- Anima
					local value = ScanTooltipRewardForPattern(self.questID, " (%d+) ") or 1;
					value = tonumber(value);

					if (WQT.settings.general.sl_genericAnimaIcons) then
						texture = 3528288;
						if (value >= 250) then
							texture = 3528287;
						end
					end
					self:AddReward(WQT_REWARDTYPE.anima, numItems * value, texture, quality, rewardId);
				else
					-- Normal items
					if (texture == 894556) then
						-- Bonus player xp item is counted as actual xp
						self:AddReward(WQT_REWARDTYPE.xp, ilvl, texture, quality, rewardId);
					elseif (typeID == Enum.ItemClass.Consumable and subTypeID == Enum.ItemConsumableSubclass.Other and price == 0 and ilvl > 100) then 
						-- Item converting into equipment
						self:AddReward(WQT_REWARDTYPE.equipment, ilvl, texture, quality, rewardId);
					else 
						self:AddReward(WQT_REWARDTYPE.item, numItems, texture, quality, rewardId);
					end
				end
			end
		end
		-- Spells
		if (C_QuestInfoSystem.HasQuestRewardSpells(self.questID)) then
			local spellIds = C_QuestInfoSystem.GetQuestRewardSpells(self.questID);

			for k, spellId in ipairs(spellIds) do
				local spellInfo = C_Spell.GetSpellInfo(spellId)
				self:AddReward(WQT_REWARDTYPE.spell, 1, spellInfo.iconID, 1, spellId);
			end
		end
		-- Honor
		if (GetQuestLogRewardHonor(self.questID) > 0) then
			local numItems = GetQuestLogRewardHonor(self.questID);
			self:AddReward(WQT_REWARDTYPE.honor, numItems, 1455894, 1);
		end
		-- Gold
		if (GetQuestLogRewardMoney(self.questID) > 0) then
			local numItems = floor(abs(GetQuestLogRewardMoney(self.questID)))
			self:AddReward(WQT_REWARDTYPE.gold, numItems, 133784, 1);
		end
		-- Currency
		local currencies = C_QuestLog.GetQuestRewardCurrencies(self.questID);
		for k, currency in ipairs(currencies) do
			local container = C_CurrencyInfo.GetCurrencyContainerInfo(currency.currencyID, currency.totalRewardAmount);
			local texture = container and container.icon or currency.texture;
			local quality = container and container.quality or currency.quality;
			local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currency.currencyID) ~= nil;
			local currType = currency.currencyID == _azuriteID and WQT_REWARDTYPE.artifact or (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
			self:AddReward(currType, currency.totalRewardAmount, texture, quality, currency.currencyID);
		end
		-- XP
		if (GetQuestLogRewardXP(self.questID) > 0) then
			local numItems = GetQuestLogRewardXP(self.questID);
			self:AddReward(WQT_REWARDTYPE.xp, numItems, 894556, 1);
		end
		
		self:ParseRewards();
	end

	self.hasRewardData = haveData;
end

function QuestInfoMixin:AddReward(rewardType, amount, texture, quality, id, canUpgrade, subType)
	local index = #self.rewardList + 1;

	-- Create reward
	local rewardInfo = self.rewardList[index] or {};
	rewardInfo.id = id or 0;
	rewardInfo.type = rewardType;
	rewardInfo.amount = amount or 1;
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
	local timeLeftSeconds =  C_TaskQuest.GetQuestTimeLeftSeconds(self.questID) or 0;
	return self.time.seconds and self.time.seconds > 0 and timeLeftSeconds < 1;
end

function QuestInfoMixin:SetAsWaypoint()
	local x, y = WQT_Utils:GetQuestMapLocation(self.questID, self.mapID);
	local wayPoint = UiMapPoint.CreateFromCoordinates(self.mapID, x, y);
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
	local reward = #self.rewardList > 0 and self.rewardList[1];
	return reward and reward.id or 0;
end

function QuestInfoMixin:GetRewardAmount(warmode)
	local reward = self:GetReward(1);
	local amount = reward and reward.amount or 0;
	if (warmode and amount > 0) then
		amount = WQT_Utils:CalculateWarmodeAmount(reward);
	end

	return amount;
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
	if(#self.rewardList == 0) then return 0 end
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
	local bountyBoard = WQT_Utils:GetOldBountyBoard();
	local activityBoard = WQT_Utils:GetNewBountyBoard();
	if (not bountyBoard or not activityBoard) then return false; end
	
	-- Try only selected
	if (forceSingle) then
		if (bountyBoard:IsWorldQuestCriteriaForSelectedBounty(self.questID)) then
			return true;
		end
		if (activityBoard and activityBoard.selectedBounty) then
			return self.factionID == activityBoard.selectedBounty.factionID;
		end

		return false;
	end
	
	-- Try any of them
	if (bountyBoard.bounties) then
		for k, bounty in ipairs(bountyBoard.bounties) do
			if (C_QuestLog.IsQuestCriteriaForBounty(self.questID, bounty.questID)) then
				return true;
			end
		end
	end

	return false;
end

function QuestInfoMixin:GetTagInfo()
	return self.tagInfo;
end

function QuestInfoMixin:GetTagInfoQuality()
	return self.tagInfo and self.tagInfo.quality or 0;
end

function QuestInfoMixin:IsDisliked()
	return WQT_Utils:QuestIsDisliked(self.questID);
end

function QuestInfoMixin:DataIsValid()
	return self.questID ~= nil;
end

----------------------------
-- MIXIN
----------------------------

WQT_DataProvider = {};

function WQT_DataProvider:Init()
	self.frame = CreateFrame("FRAME");
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...); end);
	self.frame:SetScript("OnLoad", function(frame, ...) self:OnEvent(...); end);
	self.frame:RegisterEvent("QUEST_LOG_UPDATE");
	self.frame:RegisterEvent("QUEST_DATA_LOAD_RESULT");
	self.frame:RegisterEvent("TAXIMAP_OPENED");
	self.frame:RegisterEvent("CVAR_UPDATE");

	self.updateScriptSet = false;
	
	self.pool = CreateObjectPool(WQT_Utils.QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.ignoreNextLogUpdate = false;

	self.fitleredQuestsList = {};
	self.shouldUpdateFiltedList = false;
	
	self.zoneLoading = {
		needsUpdate = false,
		startTimestamp = 0,
		remainingZones = {},
		numRemaining = 0,
		numTotal = 0,
		questsFound = {},
		questsActive = {},
	};
	
	WQT_CallbackRegistry:RegisterCallback("WQT.FiltersUpdated", function() self:RequestFilterUpdate(); end, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.SortUpdated", function() self:RequestFilterUpdate(); end, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, _, tag)
			if (tag == "GENERAL_ZONE_QUESTS") then
				self:RequestDataUpdate();
			elseif (tag == "GENERAL_GENERIC_ANIMA") then
				self:ReloadQuestRewards();
			end
		end,
		self);

	-- Needed to trigger update in full screen map
	EventRegistry:RegisterCallback(
		"MapCanvas.MapSet"
		,function()
				self:RequestDataUpdate();
			end
		, self);
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		self:RequestDataUpdate();
	elseif (event == "QUEST_DATA_LOAD_RESULT") then
		self:RequestDataUpdate();
	elseif (event == "TAXIMAP_OPENED") then
		self:RequestDataUpdate();
	elseif (event =="CVAR_UPDATE") then
		local cvar = ...;
		for _, officalFilters in pairs(_V["WQT_FILTER_TO_OFFICIAL"]) do
			for _, officialFilter in ipairs(officalFilters) do
				if(cvar == officialFilter) then
					self:RequestFilterUpdate();
				end
			end
		end
	end
end

function WQT_DataProvider:RequestDataUpdate()
	self.zoneLoading.needsUpdate = true;
	self:SetUpdateScript();
end

function WQT_DataProvider:RequestFilterUpdate()
	self.shouldUpdateFiltedList = true;
	self:SetUpdateScript();
end

function WQT_DataProvider:SetUpdateScript()
	if (not self.updateScriptSet) then
		self.frame:SetScript("OnUpdate", function(...) self:OnUpdate(...); end);
		self.updateScriptSet = true;
	end
end

local MAX_PROCESSING_TIME = 0.005;
function WQT_DataProvider:OnUpdate(elapsed)
	if(self.zoneLoading.needsUpdate) then
		self.zoneLoading.needsUpdate = false;

		local mapIDToLoad = nil;
		if(WorldMapFrame:IsShown()) then
			mapIDToLoad = WorldMapFrame.mapID;
		elseif(FlightMapFrame and FlightMapFrame:IsShown()) then
			mapIDToLoad = FlightMapFrame.mapID;
		end

		if (mapIDToLoad) then
			self:LoadQuestsInZone(mapIDToLoad);
		end
	end

	if(self.zoneLoading.numRemaining > 0) then
		
		local processedCount = 0;
		local updateStart = GetTimePreciseSec();
		local timeSpent = 0;

		-- Get quests from all the zones in our list
		-- Only spend a max amount of time on it each frame to prevent extreme stutters when we have a lot of zones
		local matchQuestZone = WQT_Utils:GetSetting("general", "zoneQuests") == _V["ENUM_ZONE_QUESTS"].zone;
		for zoneID in pairs(self.zoneLoading.remainingZones) do
			self.zoneLoading.remainingZones[zoneID] = nil;
			self.zoneLoading.numRemaining = self.zoneLoading.numRemaining - 1;
			processedCount = processedCount + 1;

			local taskPOIs = C_TaskQuest.GetQuestsOnMap(zoneID);
			local numPoIs = taskPOIs and #taskPOIs or 0;
			if (numPoIs > 0) then
				for k, apiInfo in ipairs(taskPOIs) do
					if (not matchQuestZone or apiInfo.mapID == zoneID) then
						self.zoneLoading.questsFound[apiInfo.questID] = apiInfo;
					end
				end
			end

			timeSpent = GetTimePreciseSec() - updateStart;
			if (timeSpent >= MAX_PROCESSING_TIME) then
				break;
			end
		end

		-- Current progress
		local progress = (self.zoneLoading.numTotal - self.zoneLoading.numRemaining) / self.zoneLoading.numTotal;

		if (self.zoneLoading.numRemaining == 0) then
			-- We're done getting quests from all the zones. Turn them into quest info for the add-on
			-- Remove quests we no longer need, add new ones, and update existing in case we didn't have all data yet

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
				if (self.zoneLoading.expansion == 0 or self.zoneLoading.expansion == GetQuestExpansion(questID)) then
					acceptedCount = acceptedCount + 1;
					if (not questForRemove[questID]) then
						questsToAdd[questID] = apiInfo;
					else
						local addonInfo = questForRemove[questID];
						questForRemove[questID] = nil;
						local updateSuccess = false;
						-- Just always update these
						addonInfo:UpdateTimeRemaining();
						addonInfo:UpdateHasWarbandBonus();

						updateSuccess = addonInfo:UpdateTitleAndFaction() or updateSuccess;
						-- Quest log update might have been for missing data
						if (not addonInfo.hasRewardData) then
							updateSuccess = addonInfo:LoadRewards(true) or updateSuccess;
						end
						if (not addonInfo.isValid) then
							updateSuccess = addonInfo:UpdateValidity() or updateSuccess;
						end
						if (addonInfo.alwaysHide and MapUtil.ShouldShowTask(apiInfo.mapID, apiInfo)) then
							-- Have only encountered this once and not been able to replicate to test if this even works
							addonInfo.alwaysHide = false;
							WQT:debugPrint(string.format("Quest alwaysHide updated (%s)", questID));
							updateSuccess = addonInfo:UpdateValidity() or updateSuccess;
						end
						if (updateSuccess) then
							updated = updated + 1;
						end
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
				questInfo:Init(apiInfo.questID, apiInfo);
			end

			WQT:debugPrint(string.format("Done: %s quests (-%s +%s ~%s)", acceptedCount, removed, added, updated));

			self.zoneLoading.startTimestamp = 0;
			progress = 0;
			WQT_CallbackRegistry:TriggerEvent("WQT.DataProvider.QuestsLoaded");
			self.shouldUpdateFiltedList = true;
		end

		WQT_CallbackRegistry:TriggerEvent("WQT.DataProvider.ProgressUpdated", progress);
	end

	if (self.shouldUpdateFiltedList) then
		self.shouldUpdateFiltedList = false;
		self:FilterAndSortQuestList();
	end

	if (not self.zoneLoading.needsUpdate and self.zoneLoading.numRemaining == 0 and not self.shouldUpdateFiltedList) then
		self.frame:SetScript("OnUpdate", nil);
		self.updateScriptSet = false;
	end
end

function WQT_DataProvider:FilterAndSortQuestList()
	wipe(self.fitleredQuestsList);
	for k, questInfo in ipairs(self:GetIterativeList()) do
		questInfo.passedFilter = false;
		if (questInfo.isValid and not questInfo.alwaysHide and questInfo.hasRewardData and not questInfo:IsExpired()) then
			local passed = WQT:PassesAllFilters(questInfo);
			questInfo.passedFilter = passed;
		end
		
		-- In debug, still filter, but show everything.
		if (questInfo.passedFilter or addon.debug) then
				table.insert(self.fitleredQuestsList, questInfo);
		end

		-- Update reward orders in case the filtering for one of the changed
		questInfo:ParseRewards();
	end

	-- Apply sorting
	local list = self.fitleredQuestsList;
	local sortOption =  WQT.settings.general.sortBy;
	table.sort(list, function (a, b) return SortQuestList(a, b, sortOption); end);

	WQT_CallbackRegistry:TriggerEvent("WQT.DataProvider.FilteredListUpdated");
end

function WQT_DataProvider:ClearData()
	wipe(self.iterativeList);
end

function WQT_DataProvider:AddContinentMapQuests(mapID)
	self:AddZoneToBuffer(mapID);

	local continentZones = _V["WQT_ZONE_MAPCOORDS"][mapID];
	if (not continentZones) then return end

	for zoneID in pairs(continentZones) do
		self:AddZoneToBuffer(zoneID);
	end
end

function WQT_DataProvider:AddWorldMapQuests()
	local worldContinents = _V["WQT_ZONE_MAPCOORDS"][947];
	if (not worldContinents) then return end

	local expLevel = WQT_Utils:GetCharacterExpansionLevel();
	self.zoneLoading.expansion = expLevel;
	for contID, data in pairs(worldContinents) do
		if (data.expansion == expLevel or data.expansion <= LE_EXPANSION_MISTS_OF_PANDARIA) then
			local linkedZones = _V["WQT_CONTINENT_LINKS"][contID];
			if (linkedZones) then
				for _, linkedMapID in pairs(linkedZones) do
					self:AddContinentMapQuests(linkedMapID)
				end
			else
				self:AddContinentMapQuests(contID)
			end
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
			self:AddZoneToRemainingUnique(subID);
		end
	end
end

function WQT_DataProvider:LoadQuestsInZone(zoneID)
	if (not zoneID) then return end
	self:ClearData();
	zoneID = zoneID or self.latestZoneId or C_Map.GetBestMapForUnit("player");
	
	if (not zoneID) then return end;

	-- No update while invisible
	if (not WorldMapFrame:IsShown()
		and not (FlightMapFrame and FlightMapFrame:IsShown())) then
		return;
	end

	if(self.zoneLoading.startTimestamp > 0) then 
		WQT:debugPrint("Interrupt");
	end

	self.zoneLoading.startTimestamp = GetTimePreciseSec();
	self.zoneLoading.numRemaining = 0;
	self.zoneLoading.numTotal = 0;
	self.zoneLoading.expansion = 0;
	wipe(self.zoneLoading.remainingZones);
	wipe(self.zoneLoading.questsFound);

	self.latestZoneId = zoneID
	
	local currentMapInfo = WQT_Utils:GetCachedMapInfo(zoneID);
	if (not currentMapInfo) then return end;

	local zoneQuests = WQT_Utils:GetSetting("general", "zoneQuests");
	if (currentMapInfo.mapType == Enum.UIMapType.World) then
		self:AddWorldMapQuests();
		
	elseif (currentMapInfo.mapType == Enum.UIMapType.Continent or zoneQuests == _V["ENUM_ZONE_QUESTS"].expansion) then
		local continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneID];

		while (not continentZones and currentMapInfo.mapType > Enum.UIMapType.Continent and currentMapInfo.parentMapID and zoneID ~= currentMapInfo.parentMapID) do
			local parentMapInfo =  WQT_Utils:GetCachedMapInfo(currentMapInfo.parentMapID);
			if (not parentMapInfo) then
				break;
			end
			zoneID = currentMapInfo.parentMapID;
			currentMapInfo = parentMapInfo;
			continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneID];
		end

		self:AddContinentMapQuests(zoneID);
		local linkedZones = _V["WQT_CONTINENT_LINKS"][zoneID];
		if (linkedZones) then
			for _, continentID in ipairs(linkedZones) do
				self:AddContinentMapQuests(continentID);
			end
		end

	else
		if (zoneQuests == _V["ENUM_ZONE_QUESTS"].zone) then
			self:AddZoneToBuffer(zoneID);
		else
			self:AddContinentMapQuests(zoneID);
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
		if questInfo.questID == id then return questInfo; end
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
end
