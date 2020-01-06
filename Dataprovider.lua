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
	elseif (C_QuestLog.IsThreatQuest(questInfo.questId)) then
		 return "worldquest-icon-nzoth", 14, 14, true;
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
	local category = _V["TIME_REMAINING_CATEGORY"].none;
	
	if (not questInfo or not questInfo.questId) then return timeLeftSeconds, timeString, color ,timeStringShort, timeLeftMinutes, category end
	
	-- Time ran out, waiting for an update
	if (self:QuestIsExpired(questInfo)) then
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
			local _, _, _, rarity, isElite = GetQuestTagInfo(questInfo.questId);
			local isWeek = isElite and rarity == LE_WORLD_QUEST_QUALITY_EPIC
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
			local _, _, _, rarity, isElite = GetQuestTagInfo(questInfo.questId);
			if (timeLeft > maxTime or (isElite and rarity == LE_WORLD_QUEST_QUALITY_EPIC)) then
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

function WQT_Utils:QuestIsExpired(questInfo)
	local timeLeftSeconds =  C_TaskQuest.GetQuestTimeLeftSeconds(questInfo.questId) or 0;
	return questInfo.time.seconds and questInfo.time.seconds > 0 and timeLeftSeconds < 1;
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
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");

	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if (not questInfo.questId or not HaveQuestData(questInfo.questId)) then
		GameTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		GameTooltip.recalculatePadding = true;
		-- Add debug lines
		WQT:AddDebugToTooltip(GameTooltip, questInfo);
		GameTooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local _, _, _, rarity = GetQuestTagInfo(questInfo.questId);
	local qualityColor = WORLD_QUEST_QUALITY_COLORS[rarity or 1];
	
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
	
	WQT:AddDebugToTooltip(GameTooltip, questInfo);

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
	mapWQProvider:RemoveAllData();

	WorldMapFrame:RefreshAllDataProviders();
	
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
