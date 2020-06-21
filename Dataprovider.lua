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
	worldTable[12] = {["x"] = 0.19, ["y"] = 0.5} -- Kalimdor
	worldTable[13] = {["x"] = 0.88, ["y"] = 0.56} -- Eastern Kingdom
	
	if (expLevel >= LE_EXPANSION_BATTLE_FOR_AZEROTH and newLevel >= 110) then
		worldTable[875] = {["x"] = 0.54, ["y"] = 0.61} -- Zandalar
		worldTable[876] = {["x"] = 0.72, ["y"] = 0.49} -- Kul Tiras
	elseif (expLevel >= LE_EXPANSION_LEGION and newLevel >= 98) then
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
	
	QuestUtils_AddQuestRewardsToTooltip(WQT_Tooltip, questID, TOOLTIP_QUEST_REWARDS_STYLE_DEFAULT);
	for i=2, 6 do
		local line = _G["WQT_TooltipTooltipTextLeft"..i];
		if (not line) then break; end
		local lineText = line:GetText() or "";
		result = lineText:match(pattern);
		if (result) then break; end
	end
	
	-- Force hide compare tooltips as they'd show up for people with alwaysCompareItems set to 1
	for _, tooltip in ipairs(WQT_Tooltip.shoppingTooltips) do
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
-- Init(questId, isDaily, isCombatAllyQuest, alwaysHide, posX, posY)
-- OnCreate() | Setup for QuestCreationFunc
-- SetMapPos(posX, posY)
-- Reset()
-- LoadRewards() | Will add and parse rewards
-- AddReward(rewardType, amount, texture, quality, color, id, canUpgrade)
-- ParseRewards()
-- TryDressUpReward()
-- IterateRewards()
-- GetReward(index)
-- IsExpired()
-- GetRewardType() | Top reward in the list
-- GetRewardId() | Top reward in the list
-- GetRewardAmount() | Top reward in the list
-- GetRewardTexture() | Top reward in the list
-- GetRewardQuality() | Top reward in the list
-- GetRewardColor() | Top reward in the list
-- GetRewardCanUpgrade() | Top reward in the list

local QuestInfoMixin = {};

local function QuestCreationFunc()
	local questInfo = CreateFromMixins(QuestInfoMixin);
	questInfo:OnCreate();
	return questInfo;
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
	
	self.isValid = HaveQuestData(self.questId);
	self.time.seconds = WQT_Utils:GetQuestTimeString(self); -- To check if expired or never had a time limit
	self.passedFilter = true;
	self.isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questId);
	self.hasRewardData = self:LoadRewards();
	
	return self.hasRewardData;
end

function QuestInfoMixin:OnCreate()
	self.time = {};
	self.reward = { 
			["typeBits"] = WQT_REWARDTYPE.missing;
		};
	self.rewardList = {};
	self.mapInfo = {};
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
end

function QuestInfoMixin:LoadRewards()
	local haveData = HaveQuestRewardData(self.questId);
	if (haveData) then
		self.reward.typeBits = WQT_REWARDTYPE.none;
		-- Items
		if (GetNumQuestLogRewards(self.questId) > 0) then
			local _, texture, numItems, quality, _, rewardId, ilvl = GetQuestLogRewardInfo(1, self.questId);

			if (rewardId) then
				local price, typeID, subTypeID = select(11, GetItemInfo(rewardId));
				if (typeID == 4 or typeID == 2) then -- Gear (4 = armor, 2 = weapon)
					local canUpgrade = ScanTooltipRewardForPattern(self.questId, "(%d+%+)$") and true or false;
					local rewardType = typeID == 4 and WQT_REWARDTYPE.equipment or WQT_REWARDTYPE.weapon;
					local color = typeID == 4 and _V["WQT_COLOR_ARMOR"] or _V["WQT_COLOR_WEAPON"];
					self:AddReward(rewardType, ilvl, texture, quality, color, rewardId, canUpgrade);
				elseif (typeID == 3 and subTypeID == 11) then
					-- Find upgrade amount as C_ArtifactUI.GetItemLevelIncreaseProvidedByRelic doesn't scale
					local numItems = tonumber(ScanTooltipRewardForPattern(self.questId, "^%+(%d+)"));
					self:AddReward(WQT_REWARDTYPE.relic, numItems, texture, quality, _V["WQT_COLOR_RELIC"], rewardId);
				else	
					-- Normal items
					if (texture == 894556) then
						-- Bonus player xp item is counted as actual xp
						self:AddReward(WQT_REWARDTYPE.xp, ilvl, texture, quality, _V["WQT_COLOR_ARMOR"], rewardId);
					elseif (typeID == 0 and subTypeID == 8 and price == 0 and ilvl > 100) then 
						-- Item converting into equipment
						self:AddReward(WQT_REWARDTYPE.equipment, ilvl, texture, quality, _V["WQT_COLOR_ARMOR"], rewardId);
					else 
						self:AddReward(WQT_REWARDTYPE.item, numItems, texture, quality, _V["WQT_COLOR_ITEM"], rewardId);
					end
				end
			end
		end
		-- Spells
		if (GetQuestLogRewardSpell(1, self.questId)) then
			local texture, _, _, _, _, _, _, _, rewardId = GetQuestLogRewardSpell(1, self.questId);
			self:AddReward(WQT_REWARDTYPE.spell, 1, texture, 1, _V["WQT_COLOR_ITEM"], rewardId);
		end
		-- Honor
		if GetQuestLogRewardHonor(self.questId) > 0 then
			local numItems = GetQuestLogRewardHonor(self.questId);
			self:AddReward(WQT_REWARDTYPE.honor, numItems, 1455894, 1, _V["WQT_COLOR_HONOR"]);
		end
		-- Gold
		if GetQuestLogRewardMoney(self.questId) > 0 then
			local numItems = floor(abs(GetQuestLogRewardMoney(self.questId) / 10000))
			self:AddReward(WQT_REWARDTYPE.gold, numItems, 133784, 1, _V["WQT_COLOR_GOLD"]);
		end
		-- Currency
		local numCurrencies = GetNumQuestLogRewardCurrencies(self.questId);
		for i=1, numCurrencies do
			local _, _, amount, currencyId = GetQuestLogRewardCurrencyInfo(i, self.questId);
			if (currencyId) then
				local name, _, texture, _, _, _, _, quality = GetCurrencyInfo(currencyId);
				local isRep = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyId) ~= nil;
				name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyId, amount, name, texture, quality); 
				local currType = currencyId == _azuriteID and WQT_REWARDTYPE.artifact or (isRep and WQT_REWARDTYPE.reputation or WQT_REWARDTYPE.currency);
				local color = currType == WQT_REWARDTYPE.artifact and _V["WQT_COLOR_ARTIFACT"] or  _V["WQT_COLOR_CURRENCY"]
				self:AddReward(currType, amount, texture, quality, color, currencyId);
			end
		end
		-- Player experience 
		if (GetQuestLogRewardXP(self.questId) > 0) then
			local numItems = GetQuestLogRewardXP(self.questId);
			self:AddReward(WQT_REWARDTYPE.xp, numItems, 894556, 1, _V["WQT_COLOR_ITEM"]);
		end
		
		self:ParseRewards();
	end

	return haveData;
end

function QuestInfoMixin:AddReward(rewardType, amount, texture, quality, color, id, canUpgrade)
	local index = #self.rewardList + 1;

	-- Create reward
	local rewardInfo = self.rewardList[index] or {};
	rewardInfo.id = id or 0;
	rewardInfo.type = rewardType
	rewardInfo.amount = amount
	rewardInfo.texture = texture
	rewardInfo.quality = quality
	rewardInfo.color = color
	rewardInfo.canUpgrade = canUpgrade;
	
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

-- Getters for the most important reward
function QuestInfoMixin:GetRewardType()
	local reward = self.rewardList[1];
	return reward and reward.type or WQT_REWARDTYPE.missing;
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
	local reward = self.rewardList[1];
	return reward and reward.texture or 134400;
end

function QuestInfoMixin:GetRewardQuality()
	local reward = self.rewardList[1];
	return reward and reward.quality or 1;
end

function QuestInfoMixin:GetRewardColor()
	local reward = self.rewardList[1];
	return reward and reward.color or _V["WQT_COLOR_MISSING"];
end

function QuestInfoMixin:GetRewardCanUpgrade()
	local reward = self.rewardList[1];
	return reward and reward.canUpgrade;
end

----------------------------
-- MIXIN
----------------------------
-- Callbacks:
-- "BufferUpdated"	(progress): % of buffered quests has changed. progress = 0-1
-- "QuestsLoaded"	(): Buffer emptied
-- "WaitingRoom"	(): Quest in the waiting room had data updated

WQT_DataProvider = CreateFromMixins(WQT_CallbackMixin);

function WQT_DataProvider:OnLoad()
	self.pool = CreateObjectPool(QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.keyList = {};
	-- If we added a quest which we didn't have rewarddata for yet, it gets added to the waiting room
	self.waitingRoomRewards = {};
	
	self.bufferedZones = {};
	self.bufferTimer = C_Timer.NewTicker(0, function() self:Tick() end);
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			self:LoadQuestsInZone(WorldMapFrame.mapID);
		end);
	
	UpdateWorldZones(); 
end

function WQT_DataProvider:OnEvent(event, ...)
	if (event == "QUEST_LOG_UPDATE") then
		self:LoadQuestsInZone(WorldMapFrame.mapID);
	elseif (event == "PLAYER_LEVEL_UP") then
		local level = ...;
		UpdateWorldZones(level); 
	end
end

function WQT_DataProvider:Tick()
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
			questInfo:LoadRewards();
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
		for zoneId  in pairs(continentZones) do
			tinsert(self.bufferedZones, zoneId);
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
	if (WQT.settings.list.alwaysAllQuests ) then
		local expLevel = _V["WQT_ZONE_EXPANSIONS"][zoneId];
		if (not expLevel or expLevel == 0) then
			expLevel = GetAccountExpansionLevel();
		end
		
		-- Gather quests for all zones either matching current zone's expansion, or matching no expansion (i.e. Stranglethorn fishing quest)
		local count = 0;
		for zoneId, expId in pairs(_V["WQT_ZONE_EXPANSIONS"])do
			if (expId == 0 or expId == expLevel) then
				tinsert(self.bufferedZones, zoneId);
			end
			count = count + 1;
		end
	else
		local continentZones = _V["WQT_ZONE_MAPCOORDS"][zoneId];
		if (currentMapInfo.mapType == Enum.UIMapType.World) then
			self:AddWorldMapQuests(continentZones);
		elseif (continentZones) then -- Zone with multiple subzones
			self:AddContinentMapQuests(continentZones);
		else
			tinsert(self.bufferedZones, zoneId);
		end
	end
	
	-- Sort current expansion to front, they are more likely to have quests
	table.sort(self.bufferedZones, ZonesByExpansionSort);
	self:UpdateBufferProgress();
	self:TriggerCallback("QuestsLoaded");
end

function WQT_DataProvider:AddQuestsInZone(zoneID, continentId)
	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	if (questsById) then
		for k, info in ipairs(questsById) do
			if (info.mapID == zoneID) then
				self:AddQuest(info);
			end
		end
		return #questsById > 0;
	end

	return false;
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

