--
-- Info structure
--
-- factionId				[number, nullable] factionId, null if no faction
-- expansionLevel		[number] expansion it belongs to
-- tradeskill				[number] tradeskillId
-- isCriteria				[boolean] is part of currently selected amissary
-- passedFilter			[boolean] passed current filters
-- type						[number] type of quest
-- questId					[number] questId
-- rarity					[number] quest rarity; normal, rare, epic
-- numObjetives		[number] number of objectives
-- title						[string] quest title
-- faction					[string] faction name
-- isElite					[boolean] is elite quest
-- isValid					[boolean, nullable] true if the quest is valid. Quest can be invalid if they are awaiting data or are an actual invalid quest (Don't ask).
-- time						[table] time related values
--		short					[string] short time string (6H)
-- 	full						[string] long time string (6 Hours)
--		minutes				[number] minutes remaining
--		color						[color] color of time string
-- mapInfo				[table] zone related values
--		mapType				[number] map type, see official Enum.UIMapType
--		mapID					[number] mapID, uses capital 'ID' because Blizzard
-- 	name					[string] zone name
--		mapX					[number] x pin position
--		mapY					[number] y pin position
--		parentMapID			[number] parentmapID, uses capital 'ID' because Blizzard
-- reward					[table] reward related values
--		type						[number] reward type, see WQT_REWARDTYPE below
--		texture					[number/string] texture of the reward. can be string for things like gold or unknown reward
--		amount					[amount] amount of items, gold, rep, or item level
--		id							[number, nullable] itemId for reward. null if not an item
--		quality					[number] item quality; common, rare, epic, etc
--		canUpgrade			[boolean, nullable] true if item has a chance to upgrade (e.g. ilvl 285+)

local addonName, addon = ...
local deprecated = {}

local WQT = addon.WQT;
local ADD = LibStub("AddonDropDown-1.0");

local _L = addon.L
local _V = addon.variables;
local _debug = addon.debug
local _playerFaction = GetPlayerFactionGroup();

local _TomTomLoaded = IsAddOnLoaded("TomTom");
local _CIMILoaded = IsAddOnLoaded("CanIMogIt");
local _WFMLoaded = IsAddOnLoaded("WorldFlightMap");

local time = time;
	
local WQT_DEFAULTS = {
	global = {	
		version = "";
		sortBy = 1;
		defaultTab = false;
		showTypeIcon = true;
		showFactionIcon = true;
		saveFilters = true;
		filterPoI = true;
		bigPoI = false;
		disablePoI = false;
		showPinReward = true;
		showPinRing = true;
		showPinTime = false;
		funQuests = true;
		emissaryOnly = false;
		preciseFilter = true;
		rewardAmountColors = true;
		alwaysAllQuests = false;
		useLFGButtons = false;
		autoEmisarry = true;
		questCounter = true;
		bountyCounter = true;
		ringType = _V["RINGTYPE_TIME"];
		useTomTom = true;
		TomTomAutoArrow = true;
		
		filters = {
				[1] = {["name"] = FACTION
				, ["flags"] = {[OTHER] = false, [_L["NO_FACTION"]] = false}}
				,[2] = {["name"] = TYPE
						, ["flags"] = {["Default"] = false, ["Elite"] = false, ["PvP"] = false, ["Petbattle"] = false, ["Dungeon"] = false, ["Raid"] = false, ["Profession"] = false, ["Invasion"] = false, ["Assault"] = false}}--, ["Emissary"] = false}}
				,[3] = {["name"] = REWARD
						, ["flags"] = {["Item"] = false, ["Armor"] = false, ["Gold"] = false, ["Currency"] = false, ["Artifact"] = false, ["Relic"] = false, ["None"] = false, ["Experience"] = false, ["Honor"] = false, ["Reputation"] = false}}
			}
	}
}

for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	if v.expansion >= LE_EXPANSION_LEGION then
		WQT_DEFAULTS.global.filters[1].flags[k] = false;
	end
end
	
------------------------------------------------------------

local _filterOrders = {}
local _dataProvider = CreateFromMixins(WQT_DataProvider);

------------------------------------------------------------

local function QuestIsWatched(questID)
	for i=1, GetNumWorldQuestWatches() do 
		if (GetWorldQuestWatchInfo(i) == questID) then
			return true;
		end
	end
	return false;
end

local function GetQuestLogInfo(hiddenList)
	local numEntries, numQuests = GetNumQuestLogEntries();
	local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept();
	local questCount = 0;
	wipe(hiddenList);
	for questLogIndex = 1, numEntries do
		local _, _, _, isHeader, _, _, frequency, questID, _, _, _, _, isTask, isBounty, _, isHidden, _ = GetQuestLogTitle(questLogIndex);
		local tagID, tagName = GetQuestTagInfo(questID)
		if not (isHeader or isTask or isBounty or frequency > 2 or tagID == 102) or tagID == 256 or frequency == 2 then
			questCount = questCount + 1;

			-- hidden quest counting to the cap
			if (isHidden) then
				tinsert(hiddenList, questLogIndex);
			end
		end
	end
	
	local color = questCount >= maxQuests and RED_FONT_COLOR or (questCount >= maxQuests-2 and _V["WQT_ORANGE_FONT_COLOR"] or _V["WQT_WHITE_FONT_COLOR"]);
	
	if (questCount > maxQuests) then
		WQT:debugPrint("|cFFFF0000Questlog:", questCount, "/", maxQuests, "|r");
	end
	
	return questCount, maxQuests, color;
	
end

function WQT:GetObjectiveTrackerWQModule()
	if WQT.wqObjectiveTacker then
		return WQT.wqObjectiveTacker;
	end
	
	if ObjectiveTrackerFrame.MODULES then
		for k, v in ipairs(ObjectiveTrackerFrame.MODULES) do
			if (v.headerText and v.headerText == TRACKER_HEADER_WORLD_QUESTS) then
				WQT.wqObjectiveTacker = v;
				return v;
			end
		end
	end

	return nil;
end

local function GetMapWQProvider()
	if WQT.mapWQProvider then return WQT.mapWQProvider; end
	
	for k, v in pairs(WorldMapFrame.dataProviders) do 
		for k1, v2 in pairs(k) do
			if k1=="IsMatchingWorldMapFilters" then 
				WQT.mapWQProvider = k; 
				break;
			end 
		end 
	end
	
	if not WQT.hookedWQProvider then
	-- We hook it here because we can't hook it during addonloaded for some reason
	hooksecurefunc(WQT.mapWQProvider, "RefreshAllData", function(self) 
			-- If the pins updated and make sure the highlight is still on the correct pin
			local parentPin = WQT_PoISelectIndicator:GetParent();
			local questId = parentPin and parentPin.questID;
			if (WQT_PoISelectIndicator:IsShown() and questId and questId ~= WQT_PoISelectIndicator.questId) then
				local pin = WQT:GetMapPinForWorldQuest(WQT_PoISelectIndicator.questId);
				if pin then
					WQT_WorldQuestFrame:ShowHighlightOnPin(pin)
				end
			end
			
			-- Keep highlighted pin in foreground
			if (WQT_PoISelectIndicator.questId) then
				local provider = GetMapWQProvider();
				local pin = provider.activePins[WQT_PoISelectIndicator.questId];
				if (pin) then
					pin:SetFrameLevel(3000);
				end
			end
			
			if (WQT.settings.disablePoI) then return; end
			-- Hook a script to every pin's OnClick
			for qId, pin in pairs(WQT.mapWQProvider.activePins ) do
				if (not pin.WQTHooked) then
					pin.WQTHooked = true;
					hooksecurefunc(pin, "OnClick", function(self, button) 
						if (WQT.settings.disablePoI) then return; end
						
						if (button == "LeftButton") then
							WQT_WorldQuestFrame.recentlyUntrackedQuest = nil;
						elseif (button == "RightButton") then
							if (WQT_WorldQuestFrame.recentlyUntrackedQuest) then
								AddWorldQuestWatch(WQT_WorldQuestFrame.recentlyUntrackedQuest);
								WQT_WorldQuestFrame.recentlyUntrackedQuest = nil;
							end
							-- If the quest wasn't tracked before we clicked, untrack it again
							if (self.notTracked and QuestIsWatched(self.questID)) then
								RemoveWorldQuestWatch(self.questID);
							end
							
							-- Show the tracker dropdown
							if WQT_TrackDropDown:GetParent() ~= self then
								-- If the dropdown is linked to another button, we must move and close it first
								WQT_TrackDropDown:SetParent(self);
								ADD:HideDropDownMenu(1);
							end
							ADD:ToggleDropDownMenu(1, nil, WQT_TrackDropDown, self, -10, 0, nil, nil, 2);
						end
							
					end)
				end
			end

		end);
		WQT.hookedWQProvider = true;
	end
		
		
	return WQT.mapWQProvider;
end

function WQT:GetFirstContinent(a) 
	local i = C_Map.GetMapInfo(a) 
	if not i then return a; end
	local p = i.parentMapID;
	if not p or i.mapType <= Enum.UIMapType.Continent then 
		return a 
	end 
	return self:GetFirstContinent(p) 
end

function WQT:GetMapPinForWorldQuest(questID)
	local provider = GetMapWQProvider();
	if (provider == nil) then
		return nil
	end
	
	return provider.activePins[questID];
end

function WQT:GetMapPinForBonusObjective(questID)
	if not WorldMapFrame.pinPools["BonusObjectivePinTemplate"] then 
		return nil; 
	end
	
	for pin, v in pairs(WorldMapFrame.pinPools["BonusObjectivePinTemplate"].activeObjects) do 
		if (questID == pin.questID) then
			return pin;
		end
	end
	return nil;
end

local function GetFactionData(id)
	if (not id) then  
		-- No faction
		return _V["WQT_NO_FACTION_DATA"];
	end;
	local factionData = _V["WQT_FACTION_DATA"];

	if (not factionData[id]) then
		-- Add new faction in case it's not in our data yet
		factionData[id] = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = _V["WQT_FACTIONUNKNOWN"] }
		factionData[id].name = GetFactionInfoByID(id) or "Unknown Faction";
	end
	
	return factionData[id];
end

local function GetAbreviatedNumberChinese(number)
	if type(number) ~= "number" then return "NaN" end;
	if (number >= 10000 and number < 100000) then
		local rest = number - floor(number/10000)*10000
		if rest < 100 then
			return _L["NUMBERS_FIRST"]:format(floor(number / 10000));
		else
			return _L["NUMBERS_FIRST"]:format(floor(number / 1000)/10);
		end
	elseif (number >= 100000 and number < 100000000) then
		return _L["NUMBERS_FIRST"]:format(floor(number / 10000));
	elseif (number >= 100000000 and number < 1000000000) then
		local rest = number - floor(number/100000000)*100000000
		if rest < 100 then
			return _L["NUMBERS_SECOND"]:format(floor(number / 100000000));
		else
			return _L["NUMBERS_SECOND"]:format(floor(number / 10000000)/10);
		end
	elseif (number >= 1000000000) then
		return _L["NUMBERS_SECOND"]:format(floor(number / 100000000));
	end
	return number 
end

local function GetAbreviatedNumberRoman(number)
	if type(number) ~= "number" then return "NaN" end;
	if (number >= 1000 and number < 10000) then
		local rest = number - floor(number/1000)*1000
		if rest < 100 then
			return _L["NUMBERS_FIRST"]:format(floor(number / 1000));
		else
			return _L["NUMBERS_FIRST"]:format(floor(number / 100)/10);
		end
	elseif (number >= 10000 and number < 1000000) then
		return _L["NUMBERS_FIRST"]:format(floor(number / 1000));
	elseif (number >= 1000000 and number < 10000000) then
		local rest = number - floor(number/1000000)*1000000
		if rest < 100000 then
			return _L["NUMBERS_SECOND"]:format(floor(number / 1000000));
		else
			return _L["NUMBERS_SECOND"]:format(floor(number / 100000)/10);
		end
	elseif (number >= 10000000 and number < 1000000000) then
		return _L["NUMBERS_SECOND"]:format(floor(number / 1000000));
	elseif (number >= 1000000000 and number < 10000000000) then
		local rest = number - floor(number/1000000000)*1000000000
		if rest < 100000000 then
			return _L["NUMBERS_THIRD"]:format(floor(number / 1000000000));
		else
			return _L["NUMBERS_THIRD"]:format(floor(number / 100000000)/10);
		end
	elseif (number >= 10000000) then
		return _L["NUMBERS_THIRD"]:format(floor(number / 1000000000));
	end
	return number 
end

local function GetLocalizedAbreviatedNumber(number)
	if (_L["IS_AZIAN_CLIENT"]) then
		return GetAbreviatedNumberChinese(number);
	end
	return GetAbreviatedNumberRoman(number);
end

local function slashcmd(msg, editbox)
	if msg == "options" then
		print(_L["OPTIONS_INFO"]);
	else
		if _debug then
		--This is to get the zone coords for highlights so I don't have to retype it every time
		
		-- local x, y = GetCursorPosition();
		
		-- local WorldMapButton = WorldMapFrame.ScrollContainer.Child;
		-- x = x / WorldMapButton:GetEffectiveScale();
		-- y = y / WorldMapButton:GetEffectiveScale();
	
		-- local centerX, centerY = WorldMapButton:GetCenter();
		-- local width = WorldMapButton:GetWidth();
		-- local height = WorldMapButton:GetHeight();
		-- local adjustedY = (centerY + (height/2) - y ) / height;
		-- local adjustedX = (x - (centerX - (width/2))) / width;
		-- print(WorldMapFrame.mapID)
		-- print("{\[\"x\"\] = " .. floor(adjustedX*100)/100 .. ", \[\"y\"\] = " .. floor(adjustedY*100)/100 .. "} ")
		
		local debugfr = WQT.debug;
		debugfr.mem = GetAddOnMemoryUsage(addonName);
		local frames = {WQT_WorldQuestFrame, WQT_QuestScrollFrame, WQT_WorldQuestFrame.pinHandler, WQT_WorldQuestFrame.dataProvider, WQT};
		for key, frame in pairs(frames) do
			for k, v in pairs(frame) do
				if type(v) == "function" then
					local name = frame.GetName and  frame:GetName() .. ":" or ""
					debugfr.callCounters[name .. k] = {};
					hooksecurefunc(frame, k, function(self) 
							local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
							tinsert(debugfr.callCounters[name .. k], time().."|"..mem);
						end)
				end
			end
		end
	
		debugfr.callCounters["OnMapChanged"] = {};
		hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
			tinsert(debugfr.callCounters["OnMapChanged"], time().."|"..mem);
		end)
			
		debugfr.callCounters["QuestMapFrame_ShowQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ShowQuestDetails"], time().."|"..mem);
			end)
		
		debugfr.callCounters["QuestMapFrame_ReturnFromQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ReturnFromQuestDetails"], time().."|"..mem);
			end)
			
			debugfr.callCounters["ToggleDropDownMenu"] = {};
		hooksecurefunc("ToggleDropDownMenu", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["ToggleDropDownMenu"], time().."|"..mem);
			end);
			
			debugfr.callCounters["QuestMapFrame_ShowQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(self)
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ShowQuestDetails"], time().."|"..mem);
			end)
			
			debugfr.callCounters["LFGListSearchPanel_UpdateResults"] = {};
		hooksecurefunc("LFGListSearchPanel_UpdateResults", function(self)
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["LFGListSearchPanel_UpdateResults"], time().."|"..mem);
			end)
		end
	end
end

local function IsRelevantFilter(filterID, key)
	-- Check any filter outside of factions if disabled by worldmap filter
	if (filterID > 1) then return not WQT:FilterIsWorldMapDisabled(key) end
	-- Faction filters that are a string get a pass
	if (not key or type(key) == "string") then return true; end
	-- Factions with an ID of which the player faction is matching or neutral pass
	local data = GetFactionData(key);
	
	if (data and not data.faction or data.faction == _playerFaction) then return true; end
	
	return false;
end

local function GetSortedFilterOrder(filterId)
	local filter = WQT.settings.filters[filterId];
	local tbl = {};
	for k, v in pairs(filter.flags) do
		table.insert(tbl, k);
	end
	table.sort(tbl, function(a, b) 
				if(a == NONE or b == NONE)then
					return a == NONE and b == NONE;
				end
				if(a == _L["NO_FACTION"] or b == _L["NO_FACTION"])then
					return a ~= _L["NO_FACTION"] and b == _L["NO_FACTION"];
				end
				if(a == OTHER or b == OTHER)then
					return a ~= OTHER and b == OTHER;
				end
				if(type(a) == "number" and type(b) == "number")then
					local nameA = GetFactionInfoByID(tonumber(a));
					local nameB = GetFactionInfoByID(tonumber(b));
					if nameA and nameB then
						return nameA < nameB;
					end
					return a and not b;
				end
				if (_V["WQT_TYPEFLAG_LABELS"][filterId]) then
					return (_V["WQT_TYPEFLAG_LABELS"][filterId][a] or "") < (_V["WQT_TYPEFLAG_LABELS"][filterId][b] or "");
				else
					return a < b;
				end
			end)
	return tbl;
end

local function SortQuestList(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
	if (a.time.minutes == b.time.minutes or (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2)) then
		if a.expantionLevel ==  b.expantionLevel then
			if a.title ==  b.title then
				return a.questId < b.questId;
			end
			return a.title < b.title;
		end
		return a.expantionLevel > b.expantionLevel;
	end	
	return a.time.minutes < b.time.minutes;
end

local function SortQuestListByZone(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	if a.mapInfo.mapID == b.mapInfo.mapID then
		-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
		if (a.time.minutes == b.time.minutes or (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2)) then
			if a.title ==  b.title then
				return a.questId < b.questId;
			end
			return a.title < b.title;
		end	
		return a.time.minutes < b.time.minutes;
	end
	if WQT.settings.alwaysAllQuests then
		if a.mapInfo.mapID == WorldMapFrame.mapID or b.mapInfo.mapID == WorldMapFrame.mapID then
			return a.mapInfo.mapID == WorldMapFrame.mapID and b.mapInfo.mapID ~= WorldMapFrame.mapID;
		end
	end
	
	return (a.mapInfo.name or "zz") < (b.mapInfo.name or "zz");
end

local function SortQuestListByFaction(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	if a.expantionLevel ==  b.expantionLevel then
		if a.faction == b.faction then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.time.minutes == b.time.minutes or (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2)) then
				if a.title ==  b.title then
					return a.questId < b.questId;
				end
				return a.title < b.title;
			end	
			return a.time.minutes < b.time.minutes;
		end
		return a.faction > b.faction;
	end
	return a.expantionLevel > b.expantionLevel;
end

local function SortQuestListByType(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	local aIsCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(a.questId);
	local bIsCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(b.questId);
	if aIsCriteria == bIsCriteria then
		if a.type == b.type then
			if a.rarity == b.rarity then
				if (a.isElite and b.isElite) or (not a.isElite and not b.isElite) then
					-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
					if (a.time.minutes == b.time.minutes or (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2)) then
						if a.title ==  b.title then
							return a.questId < b.questId;
						end
						return a.title < b.title;
					end	
					return a.time.minutes < b.time.minutes;
				end
				return b.isElite;
			end
			return a.rarity < b.rarity;
		end
		return a.type < b.type;
	end
	return aIsCriteria and not bIsCriteria;
end

local function SortQuestListByName(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	if a.title ==  b.title then
		return a.questId < b.questId;
	end
	return a.title < b.title;
end

local function SortQuestListByReward(a, b) 
	if not a.isValid or not b.isValid then
		return a.isValid and not b.isValid;
	end
	if a.reward.type == b.reward.type then
		if not a.reward.quality or not b.reward.quality or a.reward.quality == b.reward.quality then
			if not a.reward.amount or not b.reward.amount or a.reward.amount == b.reward.amount then
				-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
				if (a.time.minutes == b.time.minutes or (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2)) then
					if a.title ==  b.title then
						return a.questId < b.questId;
					end
					return a.title < b.title;
				end	
				return a.time.minutes < b.time.minutes;
			end
			return a.reward.amount > b.reward.amount;
		end
		return a.reward.quality > b.reward.quality;
	elseif a.reward.type == 0 or b.reward.type == 0 then
		return a.reward.type > b.reward.type;
	end
	return a.reward.type < b.reward.type;
end

local function ConvertOldSettings()
	WQT.settings.filters[3].flags.Resources = nil;
	WQT.settings.versionCheck = "1";
end

local function ConvertToBfASettings()
	-- In 8.0.01 factions use ids rather than name
	local repFlags = WQT.settings.filters[1].flags;
	for name, value in pairs(repFlags) do
		if (type(name) == "string" and name ~=OTHER and name ~= _L["NO_FACTION"]) then
			repFlags[name] = nil;
		end
	end
end

local function AddDebugToTooltip(tooltip, questInfo)
	-- First all non table values;
	for key, value in pairs(questInfo) do
		if (not deprecated[key]) then
			if (type(value) ~= "table") then
				tooltip:AddDoubleLine(key, tostring(value));
			elseif (type(value) == "table" and value.GetRGBA) then
				tooltip:AddDoubleLine(key, value.r .. "/" .. value.g .. "/" .. value.b );
			end
		end
	end

	-- Actual tables
	for key, value in pairs(questInfo) do
		if (type(value) == "table" and not value.GetRGBA) then
			tooltip:AddDoubleLine(key, "");
			for key2, value2 in pairs(value) do
				if (type(value2) == "table" and value2.GetRGBA) then-- colors
					tooltip:AddDoubleLine("    " .. key2, value2.r .. "/" .. value2.g .. "/" .. value2.b );
				else
					tooltip:AddDoubleLine("    " .. key2, tostring(value2));
				end
			end
		end
	end
	
	-- Deprecated values
	for key, value in pairs(questInfo) do
		if (deprecated[key]) then
			if (type(value) ~= "table") then
				tooltip:AddDoubleLine(key, tostring(value) , 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
			elseif (type(value) == "table" and value.GetRGBA) then
				tooltip:AddDoubleLine(key, value.r .. "/" .. value.g .. "/" .. value.b , 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
			end
		end
	end

end

function WQT:UpdateFilterIndicator() 
	if (InCombatLockdown()) then return; end
	if (GetCVarBool("showTamers") and GetCVarBool("worldQuestFilterArtifactPower") and GetCVarBool("worldQuestFilterResources") and GetCVarBool("worldQuestFilterGold") and GetCVarBool("worldQuestFilterEquipment")) then
		WQT_WorldQuestFrame.FilterButton.Indicator:Hide();
	else
		WQT_WorldQuestFrame.FilterButton.Indicator:Show();
	end
end

function WQT:SetAllFilterTo(id, value)
	local options = WQT.settings.filters[id].flags;
	for k, v in pairs(options) do
		options[k] = value;
	end
end

function WQT:FilterIsWorldMapDisabled(filter)
	if (filter == "Petbattle" and not GetCVarBool("showTamers")) or (filter == "Artifact" and not GetCVarBool("worldQuestFilterArtifactPower")) or (filter == "Currency" and not GetCVarBool("worldQuestFilterResources"))
		or (filter == "Gold" and not GetCVarBool("worldQuestFilterGold")) or (filter == "Armor" and not GetCVarBool("worldQuestFilterEquipment")) then
		
		return true;
	end

	return false;
end

function WQT:InitFilter(self, level)

	local info = ADD:CreateInfo();
	info.keepShownOnClick = true;	
	info.tooltipWhileDisabled = true;
	info.tooltipOnButton = true;
	info.motionScriptsWhileDisabled = true;
	info.disabled = nil;
	
	if level == 1 then
		info.checked = 	nil;
		info.isNotRadio = true;
		info.func =  nil;
		info.hasArrow = false;
		info.notCheckable = false;
		
		info.text = _L["TYPE_EMISSARY"];
		info.tooltipTitle = _L["TYPE_EMISSARY"];
		info.tooltipText =  _L["TYPE_EMISSARY_TT"];
		info.func = function(_, _, _, value)
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT.settings.emissaryOnly = value;
				WQT_QuestScrollFrame:DisplayQuestList();
				if (WQT.settings.filterPoI) then
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
				
				-- If we turn it off, remove the auto set as well
				if not value then
					WQT_WorldQuestFrame.autoEmisarryId = nil;
				end
			end
		info.checked = function() return WQT.settings.emissaryOnly end;
		ADD:AddButton(info, level);		
		
		info.hasArrow = true;
		info.notCheckable = true;
		info.isNotRadio = nil;
		info.tooltipTitle = nil;
		info.tooltipText = nil;
		
		for k, v in pairs(WQT.settings.filters) do
			info.text = v.name;
			info.value = k;
			ADD:AddButton(info, level)
		end
		
		info.text = SETTINGS;
		info.value = 0;
		ADD:AddButton(info, level)
	elseif level == 2 then
		info.hasArrow = false;
		info.isNotRadio = true;
		if ADD.MENU_VALUE then
			if ADD.MENU_VALUE == 1 then
			
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[ADD.MENU_VALUE].flags;
				local order = _filterOrders[ADD.MENU_VALUE] 
				local haveLabels = (_V["WQT_TYPEFLAG_LABELS"][ADD.MENU_VALUE] ~= nil);
				local currExp = LE_EXPANSION_BATTLE_FOR_AZEROTH;
				for k, flagKey in pairs(order) do
					local factionInfo = type(flagKey) == "number" and GetFactionData(flagKey) or nil;
					-- factions that aren't a faction (other and no faction), are of current expansion, and are neutral of player faction
					if (not factionInfo or (factionInfo.expansion == currExp and (not factionInfo.faction or factionInfo.faction == _playerFaction))) then
						info.text = type(flagKey) == "number" and GetFactionInfoByID(flagKey) or flagKey;
						info.func = function(_, _, _, value)
											options[flagKey] = value;
											if (value) then
												WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
											end
											WQT_QuestScrollFrame:DisplayQuestList();
										end
						info.checked = function() return options[flagKey] end;
						ADD:AddButton(info, level);			
					end
				end
				
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = EXPANSION_NAME6;
				info.value = 301;
				info.func = nil;
				ADD:AddButton(info, level)
				
			
			elseif WQT.settings.filters[ADD.MENU_VALUE] then
				
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(ADD.MENU_VALUE, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(ADD.MENU_VALUE, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[ADD.MENU_VALUE].flags;
				local order = _filterOrders[ADD.MENU_VALUE] 
				local haveLabels = (_V["WQT_TYPEFLAG_LABELS"][ADD.MENU_VALUE] ~= nil);
				for k, flagKey in pairs(order) do
					info.disabled = false;
					info.tooltipTitle = nil;
					info.text = haveLabels and _V["WQT_TYPEFLAG_LABELS"][ADD.MENU_VALUE][flagKey] or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
										end
										WQT_QuestScrollFrame:DisplayQuestList();
									end
					info.checked = function() return options[flagKey] end;
					info.funcEnter = nil;
					info.funcLeave = nil;
					info.funcDisabled = nil
					
					if WQT:FilterIsWorldMapDisabled(flagKey) then
						info.disabled = true;
						info.tooltipTitle = _L["MAP_FILTER_DISABLED"];
						info.tooltipText = _L["MAP_FILTER_DISABLED_BUTTON_INFO"];
						info.funcEnter = function() WQT_WorldQuestFrame:ShowHighlightOnMapFilters(); end;
						info.funcLeave = function() WQT_PoISelectIndicator:Hide(); end;	
						info.funcDisabled = function(listButton, button)  
								if (button == "RightButton") then 
									if (WQT_WorldQuestFrame:SetCvarValue(flagKey, true)) then
										ADD:EnableButton(2, listButton:GetID());
										listButton.tooltipTitle = nil;
										listButton.tooltipText = nil;
										listButton.funcEnter = nil;
										listButton.funcLeave = nil;	
									end
								end
							end;	
					end
					
					ADD:AddButton(info, level);			
				end
				
			elseif ADD.MENU_VALUE == 0 then
				info.notCheckable = false;
				info.tooltipWhileDisabled = true;
				info.tooltipOnButton = true;
				info.keepShownOnClick = true;	
				
				info.text = _L["DEFAULT_TAB"];
				info.tooltipTitle = _L["DEFAULT_TAB"];
				info.tooltipText = _L["DEFAULT_TAB_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.defaultTab = value;

					end
				info.checked = function() return WQT.settings.defaultTab end;
				ADD:AddButton(info, level);			

				info.text = _L["SAVE_SETTINGS"];
				info.tooltipTitle = _L["SAVE_SETTINGS"];
				info.tooltipText = _L["SAVE_SETTINGS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.saveFilters = value;
					end
				info.checked = function() return WQT.settings.saveFilters end;
				ADD:AddButton(info, level);	
				
				info.text = _L["PRECISE_FILTER"];
				info.tooltipTitle = _L["PRECISE_FILTER"];
				info.tooltipText = _L["PRECISE_FILTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.preciseFilter = value;
						WQT_QuestScrollFrame:DisplayQuestList();
						if (WQT.settings.filterPoI) then
							WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
						end
					end
				info.checked = function() return WQT.settings.preciseFilter end;
				ADD:AddButton(info, level);	
				
				
				info.disabled = false;
				
				info.text = _L["SHOW_TYPE"];
				info.tooltipTitle = _L["SHOW_TYPE"];
				info.tooltipText = _L["SHOW_TYPE_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showTypeIcon = value;
						WQT_QuestScrollFrame:DisplayQuestList(true, true);
					end
				info.checked = function() return WQT.settings.showTypeIcon end;
				ADD:AddButton(info, level);		
				
				info.text = _L["SHOW_FACTION"];
				info.tooltipTitle = _L["SHOW_FACTION"];
				info.tooltipText = _L["SHOW_FACTION_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showFactionIcon = value;
						WQT_QuestScrollFrame:DisplayQuestList(true, true);
					end
				info.checked = function() return WQT.settings.showFactionIcon end;
				ADD:AddButton(info, level);		
				
				info.keepShownOnClick = true;	
				info.text = _L["ALWAYS_ALL"];
				info.tooltipTitle = _L["ALWAYS_ALL"];
				info.tooltipText = _L["ALWAYS_ALL_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.alwaysAllQuests = value;
						WQT_QuestScrollFrame:UpdateQuestList();
					end
				info.checked = function() return WQT.settings.alwaysAllQuests end;
				ADD:AddButton(info, level);		
				
				info.text = _L["LFG_BUTTONS"];
				info.tooltipTitle = _L["LFG_BUTTONS"];
				info.tooltipText = _L["LFG_BUTTONS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.useLFGButtons = value;
					end
				info.checked = function() return WQT.settings.useLFGButtons end;
				ADD:AddButton(info, level);		
				
				info.text = _L["AUTO_EMISARRY"];
				info.tooltipTitle = _L["AUTO_EMISARRY"];
				info.tooltipText = _L["AUTO_EMISARRY_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.autoEmisarry = value;
					end
				info.checked = function() return WQT.settings.autoEmisarry end;
				ADD:AddButton(info, level);		
				
				info.text = _L["QUEST_COUNTER"];
				info.tooltipTitle = _L["QUEST_COUNTER"];
				info.tooltipText = _L["QUEST_COUNTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.questCounter = value;
						WQT_QuestLogFiller:SetShown(value);
					end
				info.checked = function() return WQT.settings.questCounter end;
				ADD:AddButton(info, level);		
				
				info.text = _L["EMISSARY_COUNTER"];
				info.tooltipTitle = _L["EMISSARY_COUNTER"];
				info.tooltipText = _L["EMISSARY_COUNTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.bountyCounter = value;
						WQT_WorldQuestFrame:UpdateBountyCounters();
						WQT_WorldQuestFrame:RepositionBountyTabs();
					end
				info.checked = function() return WQT.settings.bountyCounter end;
				ADD:AddButton(info, level);	
				
				info.tooltipTitle = nil;
				info.tooltipText = nil;
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = _L["PIN_SETTINGS"];
				info.value = 302;
				info.func = nil;
				ADD:AddButton(info, level)
				
				-- TomTom compatibility
				if _TomTomLoaded then
					info.tooltipTitle = nil;
					info.tooltipText = nil;
					info.hasArrow = true;
					info.notCheckable = true;
					info.text = "TomTom";
					info.value = 303;
					info.func = nil;
					ADD:AddButton(info, level)
				end
			end
		end
	elseif level == 3 then
		info.isNotRadio = true;
		info.notCheckable = false;
		info.notCheckable = false;
		if ADD.MENU_VALUE == 301 then -- Legion factions
			local options = WQT.settings.filters[1].flags;
			local order = _filterOrders[1] 
			local haveLabels = (_V["WQT_TYPEFLAG_LABELS"][1] ~= nil);
			local currExp = LE_EXPANSION_LEGION;
			for k, flagKey in pairs(order) do
				local data = type(flagKey) == "number" and GetFactionData(flagKey) or nil;
				if (data and data.expansion == currExp ) then
					info.text = type(flagKey) == "number" and data.name or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
										end
										WQT_QuestScrollFrame:DisplayQuestList();
									end
					info.checked = function() return options[flagKey] end;
					ADD:AddButton(info, level);			
				end
			end
		elseif ADD.MENU_VALUE == 302 then -- Map Pins
			info.tooltipWhileDisabled = true;
			info.tooltipOnButton = true;
			info.keepShownOnClick = true;	
			info.text = _L["PIN_DISABLE"];
				info.tooltipTitle = _L["PIN_DISABLE"];
				info.tooltipText = _L["PIN_DISABLE_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.disablePoI = value;
						if (value) then
							-- Reset alpha on official pins
							local WQProvider = GetMapWQProvider();
							local WQProvider = GetMapWQProvider();
							for qID, PoI in pairs(WQProvider.activePins) do
								PoI.BountyRing:SetAlpha(1);
								PoI.TimeLowFrame:SetAlpha(1);
								PoI.TrackedCheck:SetAlpha(1);
							end
							WQT_WorldQuestFrame.pinHandler:ReleaseAllPools();
						end
						ADD:Refresh(self, 1, 3);
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(true)
					end
				info.checked = function() return WQT.settings.disablePoI end;
				ADD:AddButton(info, level);
				
				info.disabled = function() return WQT.settings.disablePoI end;
				
				info.text = _L["FILTER_PINS"];
				info.tooltipTitle = _L["FILTER_PINS"];
				info.tooltipText = _L["FILTER_PINS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.filterPoI = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.filterPoI end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_REWARDS"];
				info.tooltipTitle = _L["PIN_REWARDS"];
				info.tooltipText = _L["PIN_REWARDS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinReward = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.showPinReward end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_BIGGER"];
				info.tooltipTitle = _L["PIN_BIGGER"];
				info.tooltipText = _L["PIN_BIGGER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.bigPoI = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.bigPoI end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_TIME"];
				info.tooltipTitle = _L["PIN_TIME"];
				info.tooltipText = _L["PIN_TIME_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinTime = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.showPinTime end;
				ADD:AddButton(info, level);
				
				info.notClickable = true;
				info.notCheckable = true;
				
				info.text = _L["PIN_RING_TITLE"];
				info.tooltipTitle = nil;
				info.tooltipText = nil;
				ADD:AddButton(info, level);
				
				info.isNotRadio = false;
				info.notClickable = false;
				info.notCheckable = false;
				info.disabled = function() return WQT.settings.disablePoI end;
				
				info.text = _L["PIN_RING_NONE"];
				info.tooltipTitle = _L["PIN_RING_NONE"];
				info.tooltipText = _L["PIN_RIMG_NONE_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.ringType = _V["RINGTYPE_NONE"];
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
						ADD:Refresh(self, 1, 3);
					end
				info.checked = function() return  WQT.settings.ringType == _V["RINGTYPE_NONE"]; end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_RING_COLOR"];
				info.tooltipTitle = _L["PIN_RING_COLOR"];
				info.tooltipText = _L["PIN_RING_COLOR_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.ringType = _V["RINGTYPE_REWARD"];
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
						ADD:Refresh(self, 1, 3);
					end
				info.checked = function() return WQT.settings.ringType == _V["RINGTYPE_REWARD"]; end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_RING_TIME"];
				info.tooltipTitle = _L["PIN_RING_TIME"];
				info.tooltipText = _L["PIN_RIMG_TIME_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.ringType = _V["RINGTYPE_TIME"];
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
						ADD:Refresh(self, 1, 3);
					end
				info.checked = function() return  WQT.settings.ringType == _V["RINGTYPE_TIME"]; end;
				ADD:AddButton(info, level);
				
				info.disabled = nil;

		elseif ADD.MENU_VALUE == 303 then -- TomTom
			info.text = _L["USE_TOMTOM"];
			info.tooltipTitle = _L["USE_TOMTOM"];
			info.tooltipText = _L["USE_TOMTOM_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.useTomTom = value;
					WQT_QuestScrollFrame:UpdateQuestList();
					
					if value then
						ADD:EnableButton(3, 2);
					else 
						ADD:DisableButton(3, 2);
					end
				end
			info.checked = function() return WQT.settings.useTomTom end;
			ADD:AddButton(info, level);	
			
			info.disabled = not WQT.settings.useTomTom;
			info.text = _L["TOMTOM_AUTO_ARROW"];
			info.tooltipTitle = _L["TOMTOM_AUTO_ARROW"];
			info.tooltipText = _L["TOMTOM_AUTO_ARROW_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.TomTomAutoArrow = value;
					WQT_QuestScrollFrame:UpdateQuestList();
				end
			info.checked = function() return WQT.settings.TomTomAutoArrow end;
			ADD:AddButton(info, level);	
		end
	end

end

function WQT:InitSort(self, level)

	local selectedValue = ADD:GetSelectedValue(self);
	local info = ADD:CreateInfo();
	local buttonsAdded = 0;
	info.func = function(self, category) WQT:Sort_OnClick(self, category) end
	
	for k, option in ipairs(_V["WQT_SORT_OPTIONS"]) do
		info.text = option;
		info.arg1 = k;
		info.value = k;
		if k == selectedValue then
			info.checked = 1;
		else
			info.checked = nil;
		end
		ADD:AddButton(info, level);
		buttonsAdded = buttonsAdded + 1;
	end
	
	return buttonsAdded;
end

function WQT:Sort_OnClick(self, category)

	local dropdown = WQT_WorldQuestFrameSortButton;
	if ( category and dropdown.active ~= category ) then
		ADD:CloseDropDownMenus();
		dropdown.active = category
		ADD:SetSelectedValue(dropdown, category);
		ADD:SetText(dropdown, _V["WQT_SORT_OPTIONS"][category]);
		WQT.settings.sortBy = category;
		WQT_QuestScrollFrame:UpdateQuestList();
	end
end

function WQT:InitTrackDropDown(self, level)

	if not self:GetParent() or not self:GetParent().info then return; end
	local questId = self:GetParent().info.questId;
	local questInfo = self:GetParent().info;
	local info = ADD:CreateInfo();
	info.notCheckable = true;	
	
	-- TomTom functionality
	if (_TomTomLoaded and WQT.settings.useTomTom) then
	
		if (TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			-- All required functions are found
			if (not TomTom:WaypointExists(questInfo.mapInfo.mapID, questInfo.mapInfo.mapX, questInfo.mapInfo.mapY, questInfo.title)) then
				info.text = _L["TRACKDD_TOMTOM"];
				info.func = function()
					local uId = TomTom:AddWaypoint(questInfo.mapInfo.mapID, questInfo.mapInfo.mapX, questInfo.mapInfo.mapY, {["title"] = questInfo.title})
				end
			else
				info.text = _L["TRACKDD_TOMTOM_REMOVE"];
				info.func = function()
					local key = TomTom:GetKeyArgs(questInfo.mapInfo.mapID, questInfo.mapInfo.mapX, questInfo.mapInfo.mapY, questInfo.title);
					local wp = TomTom.waypoints[questInfo.mapInfo.mapID] and TomTom.waypoints[questInfo.mapInfo.mapID][key];
					TomTom:RemoveWaypoint(wp);
				end
			end
		else
			-- Something wrong with TomTom
			info.text = "TomTom Unavailable";
			info.func = function()
				print("Something is wrong with TomTom. Either it failed to load correctly, or an update changed its functionality.");
			end
		end
		
		ADD:AddButton(info, level);
	end
	
	-- Don't allow tracking and LFG for bonus objective, Blizzard UI can't handle it
	if (questInfo.type ~= _V["WQT_TYPE_BONUSOBJECTIVE"]) then
		-- Tracking
		if (QuestIsWatched(questId)) then
			info.text = UNTRACK_QUEST;
			info.func = function(_, _, _, value)
						RemoveWorldQuestWatch(questId);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_QuestScrollFrame:DisplayQuestList();
						end
					end
		else
			info.text = TRACK_QUEST;
			info.func = function(_, _, _, value)
						AddWorldQuestWatch(questId, true);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_QuestScrollFrame:DisplayQuestList();
						end
					end
		end	
		ADD:AddButton(info, level)
		
		
		-- LFG if possible
		if WQT_WorldQuestFrame:ShouldAllowLFG(questInfo) then
			info.text = OBJECTIVES_FIND_GROUP;
			info.func = function()
				WQT_WorldQuestFrame:SearchGroup(questInfo);
			end
			ADD:AddButton(info, level);
		end
	end
	
	info.text = CANCEL;
	info.func = nil;
	ADD:AddButton(info, level)
end

function WQT:IsWorldMapFiltering()
	for k, cVar in pairs(_V["WQT_CVAR_LIST"]) do
		if not GetCVarBool(cVar) then
			return true;
		end
	end
	return false;
end

function WQT:IsFiltering()
	if WQT.settings.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId then return true; end
	for k, category in pairs(WQT.settings.filters)do
		for k2, flag in pairs(category.flags) do
			if flag and IsRelevantFilter(k, k2) then 
				return true;
			end
		end
	end
	return false;
end

function WQT:isUsingFilterNr(id)
	if not WQT.settings.filters[id] then return false end
	local flags = WQT.settings.filters[id].flags;
	for k, flag in pairs(flags) do
		if flag then return true; end
	end
	return false;
end

function WQT:PassesMapFilter(questInfo)
	if (WQT_WorldQuestFrame.currentMapInfo and WQT_WorldQuestFrame.currentMapInfo.mapType == Enum.UIMapType.World) then return true; end

	if (WorldMapFrame.mapID == questInfo.mapInfo.mapID) then return true; end
	
	if (_V["WQT_ZONE_MAPCOORDS"][WorldMapFrame.mapID] and _V["WQT_ZONE_MAPCOORDS"][WorldMapFrame.mapID][questInfo.mapInfo.mapID]) then return true; end
end

function WQT:PassesAllFilters(questInfo)
	if questInfo.questId < 0 or not questInfo.isValid then return true; end
	
	if not self:PassesMapFilter(questInfo) then return false; end
	
	if not WorldMap_DoesWorldQuestInfoPassFilters(questInfo) then return false; end

	if WQT.settings.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId then 
		return WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	end
	
	local precise = WQT.settings.preciseFilter;
	local passed = true;
	
	if precise then
		if WQT:isUsingFilterNr(1) then 
			passed = WQT:PassesFactionFilter(questInfo) and true or false; 
		end
		if (WQT:isUsingFilterNr(2) and passed) then
			passed = WQT:PassesFlagId(2, questInfo) and true or false;
		end
		if (WQT:isUsingFilterNr(3) and passed) then
			passed = WQT:PassesFlagId(3, questInfo) and true or false;
		end
	else
		if WQT:isUsingFilterNr(1) and WQT:PassesFactionFilter(questInfo) then return true; end
		if WQT:isUsingFilterNr(2) and WQT:PassesFlagId(2, questInfo) then return true; end
		if WQT:isUsingFilterNr(3) and WQT:PassesFlagId(3, questInfo) then return true; end
	end
	
	return precise and passed or false;
end

function WQT:PassesFactionFilter(questInfo)
	-- Factions (1)
	local flags = WQT.settings.filters[1].flags
	-- no faction
	if not questInfo.factionId then return flags[_L["NO_FACTION"]]; end
	
	if flags[questInfo.factionId] ~= nil then 
		-- specific faction
		return flags[questInfo.factionId];
	else
		-- other faction
		return flags[OTHER];
	end

	return false;
end

function WQT:PassesFlagId(flagId ,questInfo)
	local flags = WQT.settings.filters[flagId].flags

	for k, func in ipairs(_V["WQT_FILTER_FUNCTIONS"][flagId]) do
		if(func(questInfo, flags)) then return true; end
	end
	return false;
end



function WQT:OnInitialize()

	self.db = LibStub("AceDB-3.0"):New("BWQDB", WQT_DEFAULTS, true);
	self.settings = self.db.global;
	
	if (not WQT.settings.versionCheck) then
		ConvertOldSettings()
	end
	if (WQT.settings.versionCheck < "8.0.1") then
		ConvertToBfASettings();
	end
	WQT.settings.versionCheck  = GetAddOnMetadata(addonName, "version");
	
end

function WQT:OnEnable()

	WQT_TabNormal.Highlight:Show();
	WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	if not self.settings.saveFilters then
		for k, filter in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, false);
		end
	end

	if self.settings.saveFilters and _V["WQT_SORT_OPTIONS"][self.settings.sortBy] then
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, self.settings.sortBy);
		ADD:SetText(WQT_WorldQuestFrameSortButton, _V["WQT_SORT_OPTIONS"][self.settings.sortBy]);
	else
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, 1);
		ADD:SetText(WQT_WorldQuestFrameSortButton, _V["WQT_SORT_OPTIONS"][1]);
	end

	for k, v in pairs(WQT.settings.filters) do
		_filterOrders[k] = GetSortedFilterOrder(k);
	end
	
	-- Show default tab depending on setting
	WQT_WorldQuestFrame:SelectTab((UnitLevel("player") >= 110 and self.settings.defaultTab) and WQT_TabWorld or WQT_TabNormal);
	
	-- Show quest log counter
	WQT_QuestLogFiller:SetShown(self.settings.questCounter);
	
	-- Add LFG buttons to objective tracker
	if self.settings.useLFGButtons then
		WQT_WorldQuestFrame.LFGButtonPool = CreateFramePool("BUTTON", Test_Frame, "WQT_LFGEyeButtonTemplate");
	
		hooksecurefunc("QuestObjectiveSetupBlockButton_FindGroup", function(block, questID) 
				-- release button if it exists
				if (block.WQTButton) then
					WQT_WorldQuestFrame.LFGButtonPool:Release(block.WQTButton);
					block.WQTButton = nil;
				end
				
				if not block.rightButton and QuestUtils_IsQuestWorldQuest(questID) then
					if WQT_WorldQuestFrame:ShouldAllowLFG(questID) then
						local button = WQT_WorldQuestFrame.LFGButtonPool:Acquire();
						button.questId = questID;
						button:SetParent(block);
						QuestObjectiveSetupBlockButton_AddRightButton(block, button, block.module.buttonOffsets.groupFinder);
						block.WQTButton = button;
					end
				end
			end);
	end
end

function WQT:ClearBountyIcons()

end

----------------------
-- LISTBUTTON MIXIN
----------------------

WQT_ListButtonMixin = {}

function WQT_ListButtonMixin:OnClick(button)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if not self.questId or self.questId== -1 then return end

	if IsModifiedClick("QUESTWATCHTOGGLE") then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (self.info.type ~= _V["WQT_TYPE_BONUSOBJECTIVE"]) then
			-- Only do tracking if we aren't adding the link tot he chat
			if (not ChatEdit_TryInsertQuestLinkForQuestID(self.questId)) then 
				if (QuestIsWatched(self.questId)) then
					local hardWatched = IsWorldQuestHardWatched(self.questId);
					RemoveWorldQuestWatch(self.questId);
					-- If it wasn't actually hard watched, do so now
					if not hardWatched then
						AddWorldQuestWatch(self.questId, true);
					end
				else
					AddWorldQuestWatch(self.questId, true);
				end
			end
		end
	elseif IsModifiedClick("DRESSUP") and self.info.reward.type == WQT_REWARDTYPE.equipment then
		local _, link = GetItemInfo(self.info.reward.id);
		DressUpItemLink(link)
		
	elseif button == "LeftButton" then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (self.info.type ~= _V["WQT_TYPE_BONUSOBJECTIVE"]) then
			local hardWatched = IsWorldQuestHardWatched(self.questId);
			AddWorldQuestWatch(self.questId);
			-- if it was hard watched, keep it that way
			if hardWatched then
				AddWorldQuestWatch(self.questId, true);
			end
		end
		WorldMapFrame:SetMapID(self.zoneId);
		
		if WQT_WorldQuestFrame:GetAlpha() > 0 then 
			WQT_QuestScrollFrame:DisplayQuestList();
		end
		
	elseif button == "RightButton" then

		if WQT_TrackDropDown:GetParent() ~= self then
			-- If the dropdown is linked to another button, we must move and close it first
			WQT_TrackDropDown:SetParent(self);
			ADD:HideDropDownMenu(1);
		end
		ADD:ToggleDropDownMenu(1, nil, WQT_TrackDropDown, "cursor", -10, -10, nil, nil, 2);
	end
	
	
end

function WQT_ListButtonMixin:SetEnabled(value)
	value = value==nil and true or value;
	
	if value then
		self:Enable();
	else
		self:Disable();
	end
	
	
	self:EnableMouse(value);
	self.Faction:EnableMouse(value);
end

function WQT_ListButtonMixin:OnLeave()
	HideUIPanel(self.Highlight);
	WQT_Tooltip:Hide();
	WQT_Tooltip.ItemTooltip:Hide();
	
	-- Small delay to prevent the animation from resetting every time the list updates
	WQT_PoISelectIndicator.delayTicker = C_Timer.NewTicker(0.05, function() 
			WQT_PoISelectIndicator:Hide(); 
			if (self.resetLabel) then
				WorldMapFrame.ScrollContainer:GetMap():TriggerEvent("ClearAreaLabel", MAP_AREA_LABEL_TYPE.POI);
				self.resetLabel = false;
			end
			-- Reset highlighted pin to original frame level
			if (WQT_PoISelectIndicator.pin) then
				WQT_PoISelectIndicator.pin:SetFrameLevel(WQT_PoISelectIndicator.pinLevel);
			end
			WQT_PoISelectIndicator.questId = nil;
		end, 1)
	
	WQT_MapZoneHightlight:Hide();
	
end

function WQT_ListButtonMixin:OnEnter()
	-- Cancel the timer if we are an a button before it ends so highlight doesn't get hidden
	if WQT_PoISelectIndicator.delayTicker then
		WQT_PoISelectIndicator.delayTicker:Cancel();
	end

	ShowUIPanel(self.Highlight);
	
	local questInfo = self.info;
	
	-- Put the ping on the relevant map pin
	local scale = 1;
	local pin = WQT:GetMapPinForWorldQuest(questInfo.questId);
	if not pin then
		 pin = WQT:GetMapPinForBonusObjective(questInfo.questId);
		 scale = 0.5;
	end
	if pin then
		-- the pin is different, hide the highlight to restart the animation
		if (pin ~= WQT_PoISelectIndicator.pin) then
			WQT_PoISelectIndicator:Hide();
		end
	
		WQT_WorldQuestFrame:ShowHighlightOnPin(pin, scale);
		WQT_PoISelectIndicator.questId = questInfo.questId;
	end
	
	WQT_QuestScrollFrame:ShowQuestTooltip(self, questInfo);
	
	-- If we are on a continent, we want to highlight the relevant zone
	self:ShowWorldmapHighlight(questInfo.mapInfo.mapID);
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)
	local frame = self.Type;
	local isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	local questType, rarity, isElite, tradeskillLineIndex = questInfo.type, questInfo.rarity, questInfo.isElite, questInfo.tradeskill;
	
	frame:Show();
	frame:SetWidth(frame:GetHeight());
	frame.Texture:Show();
	frame.Texture:Show();
	
	if isElite then
		frame.Elite:Show();
	else
		frame.Elite:Hide();
	end
	
	if not rarity or rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		frame.Bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		frame.Bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		frame.Bg:SetSize(28, 28);
	elseif rarity == LE_WORLD_QUEST_QUALITY_RARE then
		frame.Bg:SetAtlas("worldquest-questmarker-rare");
		frame.Bg:SetTexCoord(0, 1, 0, 1);
		frame.Bg:SetSize(18, 18);
	elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
		frame.Bg:SetAtlas("worldquest-questmarker-epic");
		frame.Bg:SetTexCoord(0, 1, 0, 1);
		frame.Bg:SetSize(18, 18);
	end

	-- Update Icon
	local atlasTexture, sizeX, sizeY = _dataProvider:GetCachedTypeIconData(questType, tradeskillLineIndex);

	frame.Texture:SetAtlas(atlasTexture);
	frame.Texture:SetSize(sizeX, sizeY);
	
	if ( isCriteria ) then
		if ( isElite ) then
			frame.CriteriaGlow:SetAtlas("worldquest-questmarker-dragon-glow", false);
			frame.CriteriaGlow:SetPoint("CENTER", 0, -1);
		else
			frame.CriteriaGlow:SetAtlas("worldquest-questmarker-glow", false);
			frame.CriteriaGlow:SetPoint("CENTER", 0, 0);
		end
		frame.CriteriaGlow:Show();
	else
		frame.CriteriaGlow:Hide();
	end
	
	-- Bonus objectives
	if (questType == _V["WQT_TYPE_BONUSOBJECTIVE"]) then
		frame.Texture:SetAtlas("QuestBonusObjective", true);
		frame.Texture:SetSize(22, 22);
	end
end

function WQT_ListButtonMixin:Update(questInfo, shouldShowZone)

	if self.info ~= questInfo then
		self.Reward.Amount:Hide();
		self.TrackedBorder:Hide();
		self.Highlight:Hide();
		self:Hide();
	end

	self:Show();
	self.Title:SetText(questInfo.title);
	self.Time:SetTextColor(questInfo.time.color.r, questInfo.time.color.g, questInfo.time.color.b, 1);
	self.Time:SetText(questInfo.time.full);
	self.Extra:SetText(shouldShowZone and questInfo.mapInfo.name or "");
	
	if (self:IsMouseOver() or self.Faction:IsMouseOver() or (WQT_QuestScrollFrame.PoIHoverId and WQT_QuestScrollFrame.PoIHoverId > 0 and WQT_QuestScrollFrame.PoIHoverId == questInfo.questId)) then
		self.Highlight:Show();
	else
		self.Highlight:Hide();
	end
			
	self.Title:ClearAllPoints()
	self.Title:SetPoint("RIGHT", self.Reward, "LEFT", -5, 0);
	
	self.info = questInfo;
	self.zoneId = questInfo.mapInfo.mapID;
	self.questId = questInfo.questId;
	self.numObjectives = questInfo.numObjectives;
	
	if WQT.settings.showFactionIcon then
		self.Title:SetPoint("BOTTOMLEFT", self.Faction, "RIGHT", 5, 1);
	elseif WQT.settings.showTypeIcon then
		self.Title:SetPoint("BOTTOMLEFT", self.Type, "RIGHT", 5, 1);
	else
		self.Title:SetPoint("BOTTOMLEFT", self, "LEFT", 10, 0);
	end
	
	if WQT.settings.showFactionIcon then
		self.Faction:Show();
		local factionData = GetFactionData(questInfo.factionId);
		
		self.Faction.Icon:SetTexture(factionData.icon);
		self.Faction:SetWidth(self.Faction:GetHeight());
	else
		self.Faction:Hide();
		self.Faction:SetWidth(0.1);
	end
	
	if WQT.settings.showTypeIcon then
		self:UpdateQuestType(questInfo)
	else
		self.Type:Hide()
		self.Type:SetWidth(0.1);
	end
	
	-- display reward
	self.Reward:Show();
	self.Reward.Icon:Show();

	if questInfo.reward.type == WQT_REWARDTYPE.missing then
		self.Reward.IconBorder:SetVertexColor(.75, 0, 0);
		self.Reward:SetAlpha(1);
		self.Reward.Icon:SetColorTexture(0, 0, 0, 0.5);
		self.Reward.Amount:Hide();
	else
		local r, g, b = GetItemQualityColor(questInfo.reward.quality);
		self.Reward.IconBorder:SetVertexColor(r, g, b);
		self.Reward:SetAlpha(1);
		if questInfo.reward.texture == "" then
			self.Reward:SetAlpha(0);
		end
		self.Reward.Icon:SetTexture(questInfo.reward.texture);
	
		if questInfo.reward.amount and questInfo.reward.amount > 1  then
			self.Reward.Amount:SetText(GetLocalizedAbreviatedNumber(questInfo.reward.amount));
			r, g, b = 1, 1, 1;
			if questInfo.reward.type == WQT_REWARDTYPE.relic then
				self.Reward.Amount:SetText("+" .. questInfo.reward.amount);
			elseif questInfo.reward.type == WQT_REWARDTYPE.artifact then
				r, g, b = GetItemQualityColor(2);
			elseif questInfo.reward.type == WQT_REWARDTYPE.equipment then
				if questInfo.reward.canUpgrade then
					self.Reward.Amount:SetText(questInfo.reward.amount.."+");
				end
				r, g, b = questInfo.reward.color:GetRGB();
			end
	
			self.Reward.Amount:SetVertexColor(r, g, b);
			self.Reward.Amount:Show();
		else
			self.Reward.Amount:Hide();
		end
	end
	
	if GetSuperTrackedQuestID() == questInfo.questId or IsWorldQuestWatched(questInfo.questId) then
		self.TrackedBorder:Show();
		self.TrackedBorder:SetAlpha(IsWorldQuestHardWatched(questInfo.questId) and 1 or 0.6);
	else
		self.TrackedBorder:Hide();
	end

end

function WQT_ListButtonMixin:ShowWorldmapHighlight(zoneId)
	local areaId = WorldMapFrame.mapID;
	local coords = _V["WQT_ZONE_MAPCOORDS"][areaId] and _V["WQT_ZONE_MAPCOORDS"][areaId][zoneId];
	local mapInfo = C_Map.GetMapInfo(zoneId);
	--Highlihght continents on world view
	if (not coords and areaId == 947 and mapInfo and mapInfo.parentMapID) then
		coords = _V["WQT_ZONE_MAPCOORDS"][947][mapInfo.parentMapID];
		mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
	end

	if not coords then return; end;

	WorldMapFrame.ScrollContainer:GetMap():TriggerEvent("SetAreaLabel", MAP_AREA_LABEL_TYPE.POI, mapInfo.name);

	-- Now we cheat by acting like we moved our mouse over the relevant zone
	WQT_MapZoneHightlight:SetParent(WorldMapFrame.ScrollContainer.Child);
	WQT_MapZoneHightlight:SetFrameLevel(5);
	local fileDataID, atlasID, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY = C_Map.GetMapHighlightInfoAtPosition(WorldMapFrame.mapID, coords.x, coords.y);
	if (fileDataID and fileDataID > 0) or (atlasID) then
		WQT_MapZoneHightlight.Texture:SetTexCoord(0, texPercentageX, 0, texPercentageY);
		local width = WorldMapFrame.ScrollContainer.Child:GetWidth();
		local height = WorldMapFrame.ScrollContainer.Child:GetHeight();
		WQT_MapZoneHightlight.Texture:ClearAllPoints();
		if (atlasID) then
			WQT_MapZoneHightlight.Texture:SetAtlas(atlasID, true, "TRILINEAR");
			scrollChildX = ((scrollChildX + 0.5*textureX) - 0.5) * width;
			scrollChildY = -((scrollChildY + 0.5*textureY) - 0.5) * height;
			WQT_MapZoneHightlight:SetPoint("CENTER", scrollChildX, scrollChildY);
			WQT_MapZoneHightlight:Show();
		else
			WQT_MapZoneHightlight.Texture:SetTexture(fileDataID, nil, nil, "LINEAR");
			textureX = textureX * width;
			textureY = textureY * height;
			scrollChildX = scrollChildX * width;
			scrollChildY = -scrollChildY * height;
			if textureX > 0 and textureY > 0 then
				WQT_MapZoneHightlight.Texture:SetWidth(textureX);
				WQT_MapZoneHightlight.Texture:SetHeight(textureY);
				WQT_MapZoneHightlight.Texture:SetPoint("TOPLEFT", WQT_MapZoneHightlight:GetParent(), "TOPLEFT", scrollChildX, scrollChildY);
				WQT_MapZoneHightlight:Show();
			end
		end
	end
	
	self.resetLabel = true;
end

WQT_PinHandlerMixin = {};

local function OnPinRelease(pool, pin)
	pin.questID = nil;
	pin:Hide();
	pin:ClearAllPoints();
end

function WQT_PinHandlerMixin:OnLoad()
	self.pinPool = CreateFramePool("COOLDOWN", WorldMapPOIFrame, "WQT_PinTemplate", OnPinRelease);
	self.pinPoolFlightMap = CreateFramePool("COOLDOWN", WorldMapPOIFrame, "WQT_PinTemplate", OnPinRelease);
end

function WQT_PinHandlerMixin:ReleaseAllPools()
	self.pinPool:ReleaseAll();
	self.pinPoolFlightMap:ReleaseAll();
end

function WQT_PinHandlerMixin:UpdateFlightMapPins()
	if not FlightMapFrame:IsShown() or WQT.settings.disablePoI then return; end
	WQT.FlightMapList = _dataProvider:GetKeyList()
	
	self.pinPoolFlightMap:ReleaseAll();
	local quest = nil;
	for qID, PoI in pairs(WQT.FlightmapPins.activePins) do
		quest =  _dataProvider:GetQuestById(qID);
		if (quest and quest.isValid) then
			local pin = self.pinPoolFlightMap:Acquire();
			pin:Update(PoI, quest, qID);
		end
	end
end

function WQT_PinHandlerMixin:UpdateMapPoI()
	self.pinPool:ReleaseAll();
	
	if (WQT.settings.disablePoI) then return; end
	local WQProvider = GetMapWQProvider();

	local quest;

	for qID, PoI in pairs(WQProvider.activePins) do
		quest = _dataProvider:GetQuestById(qID);
		if (quest and quest.isValid) then
			local pin = self.pinPool:Acquire();
			pin.questID = qID;
			pin:Update(PoI, quest);
			PoI:SetShown(true);
			if (WQT.settings.filterPoI) then
				PoI:SetShown(quest.passedFilter);
			end
		end
		
	end
end


WQT_PinMixin = {};

function WQT_PinMixin:Update(PoI, quest, flightPinNr)
	local bw = PoI:GetWidth();
	local bh = PoI:GetHeight();
	self:SetParent(PoI);
	self:SetAllPoints();
	local margin = WQT.settings.bigPoI and 8 or 4;
	
	self:SetPoint("TOPLEFT", -margin, margin);
	self:SetPoint("BOTTOMRIGHT", margin, -margin);
	self:Show();
	
	if not flightPinNr then
		PoI.info = quest;
	end
	
	PoI.BountyRing:SetAlpha(0);
	PoI.TimeLowFrame:SetAlpha(0);
	PoI.TrackedCheck:SetAlpha(0);

	self.TrackedCheck:SetAlpha(IsWorldQuestWatched(quest.questId) and 1 or 0);
	
	-- Ring stuff
	local ringType = WQT.settings.ringType;
	local now = time();
	local r, g, b = _V["WQT_COLOR_CURRENCY"]:GetRGB();
	self:SetCooldownUNIX(now, now);
	self.Pointer:SetAlpha(0);
	
	if (ringType ==  _V["RINGTYPE_TIME"]) then
		r, g, b = quest.time.color:GetRGB();
		local start = 0
		local timeLeft = quest.time.minutes;
		local offset =0
		if (timeLeft > 0) then
			if timeLeft > 1440 then
				offset = 5760*60;
				start = (5760-timeLeft)*60;
				timeLeft = timeLeft+1440/2
			elseif timeLeft > 60 then
				offset = 1440*60;
				start = (1440-timeLeft)*60;
				timeLeft = timeLeft +60/2
			elseif timeLeft > 15 then
				offset = 60*60;
				start = (60-timeLeft)*60;
				timeLeft = timeLeft+15/2
			else
				offset = 15*60;
				start = (15-timeLeft)*60;
			end
			timeLeft = timeLeft * 60;
			
			self:SetCooldownUNIX(now-start,  start + timeLeft);
			self.Pointer:SetAlpha(1);
			self.Pointer:SetVertexColor(r*1.1, g*1.1, b*1.1);
			self.Pointer:SetRotation((timeLeft)/(offset)*6.2831);
		end
	elseif (ringType ==  _V["RINGTYPE_REWARD"]) then
		r, g, b = quest.time.color:GetRGB();
	end
	
	self.Ring:SetVertexColor(r*0.35, g*0.35, b*0.35);
	self:SetSwipeColor(r*.8, g*.8, b*.8);

	-- Icon stuff
	local showIcon = WQT.settings.showPinReward and (quest.reward.type == WQT_REWARDTYPE.missing or quest.reward.texture ~= "")
	self.Icon:SetAlpha(showIcon and 1 or 0);
	if quest.reward.type == WQT_REWARDTYPE.missing or quest.reward.type == WQT_REWARDTYPE.none then
		SetPortraitToTexture(self.Icon, "Interface/DialogFrame/UI-DialogBox-Background-Dark");
	else
		SetPortraitToTexture(self.Icon, quest.reward.texture);
	end
	
	-- Time
	self.Time:SetAlpha((WQT.settings.showPinTime and quest.time.short ~= "")and 1 or 0);
	self.TimeBg:SetAlpha((WQT.settings.showPinTime and quest.time.short ~= "") and 0.65 or 0);
	self.Time:SetFontObject(flightPinNr and "WQT_NumberFontOutlineBig" or "WQT_NumberFontOutline");
	self.Time:SetScale(flightPinNr and 1 or 2.5);
	self.Time:SetHeight(flightPinNr and 32 or 16);
	if(WQT.settings.showPinTime) then
		self.Time:SetText(quest.time.short)
		self.Time:SetVertexColor(quest.time.color.r, quest.time.color.g, quest.time.color.b) 
	end
	
end


WQT_ScrollListMixin = {};

function WQT_ScrollListMixin:OnLoad()
	self.questList = {};
	self.questListDisplay = {};
	self.scrollBar.trackBG:Hide();
	
	self.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(self, "WQT_QuestTemplate", 1, 0);
	HybridScrollFrame_Update(self, 200, self:GetHeight());
		
	self.update = function() self:DisplayQuestList(true) end;
end

function WQT_ScrollListMixin:HookButtonUpdates(func)
	-- Hook a function to trigger after the Update function of every individual button in the list
	-- The usable arguments for the function are: func(button, questInfo, shouldShowZone)
	for k, button in ipairs(self.buttons) do
		hooksecurefunc(button, "Update", func);
	end
end

function WQT_ScrollListMixin:ShowQuestTooltip(button, questInfo)
	WQT_Tooltip:SetOwner(button, "ANCHOR_RIGHT");

	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if (not questInfo.questId or not HaveQuestData(questInfo.questId)) then
		WQT_Tooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		WQT_Tooltip.recalculatePadding = true;
			-- Add debug lines
	if _debug then
		AddDebugToTooltip(WQT_Tooltip, questInfo);
	end
		WQT_Tooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questInfo.questId);
	local color = WORLD_QUEST_QUALITY_COLORS[rarity or 1];
	
	WQT_Tooltip:SetText(title, color.r, color.g, color.b);
	
	if ( factionID ) then
		local factionName = GetFactionInfoByID(factionID);
		if ( factionName ) then
			if (capped) then
				WQT_Tooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
			else
				WQT_Tooltip:AddLine(factionName);
			end
		end
	end

	-- Add time
	if (questInfo.time.minutes > 0) then
		WQT_Tooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(questInfo.time.minutes*60, true, true)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end

	for objectiveIndex = 1, questInfo.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(questInfo.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			WQT_Tooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(questInfo.questId);
	if ( percent ) then
		GameTooltip_ShowProgressBar(WQT_Tooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
	end

	if (questInfo.reward.type == WQT_REWARDTYPE.missing) then
		WQT_Tooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	else
		GameTooltip_AddQuestRewardsToTooltip(WQT_Tooltip, questInfo.questId);
		
		-- reposition compare frame
		if((questInfo.reward.type == WQT_REWARDTYPE.equipment) and WQT_Tooltip.ItemTooltip:IsShown()) then
			if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
				-- Setup compare tootltips
				GameTooltip_ShowCompareItem(WQT_Tooltip.ItemTooltip.Tooltip);
				
				-- If there is room to the right, give priority to show compare tooltips to the right of the tooltip
				local totalWidth = 0;
				if ( WQT_CompareTooltip1:IsShown()  ) then
						totalWidth = totalWidth + WQT_CompareTooltip1:GetWidth();
				end
				if ( WQT_CompareTooltip2:IsShown()  ) then
						totalWidth = totalWidth + WQT_CompareTooltip2:GetWidth();
				end
				
				if WQT_Tooltip.ItemTooltip.Tooltip:GetRight() + totalWidth < GetScreenWidth() and WQT_CompareTooltip1:IsShown() then
					WQT_CompareTooltip1:ClearAllPoints();
					WQT_CompareTooltip1:SetPoint("TOPLEFT", WQT_Tooltip.ItemTooltip.Tooltip, "TOPRIGHT");
					
					WQT_CompareTooltip2:ClearAllPoints();
					WQT_CompareTooltip2:SetPoint("TOPLEFT", WQT_CompareTooltip1, "TOPRIGHT");
				end
				
				-- Set higher frame level in case things overlap
				local level = WQT_Tooltip:GetFrameLevel();
				WQT_CompareTooltip1:SetFrameLevel(level +2);
				WQT_CompareTooltip2:SetFrameLevel(level +1);
			end
		end
	end
	
	-- Add debug lines
	if _debug then
		AddDebugToTooltip(WQT_Tooltip, questInfo);
	end

	-- CanIMogIt functionality
	-- Partial copy of addToTooltip in tooltips.lua
	if (_CIMILoaded and questInfo.reward.id) then
		local _, itemLink = GetItemInfo(questInfo.reward.id);
		local tooltip = WQT_Tooltip.ItemTooltip.Tooltip;
		if (itemLink and CanIMogIt:IsReadyForCalculations(itemLink)) then
			local text;
			text = CanIMogIt:GetTooltipText(itemLink);
			if (text and text ~= "") then
				tooltip:AddDoubleLine(" ", text);
				tooltip:Show();
				tooltip.CIMI_tooltipWritten = true
			end
			
			if CanIMogItOptions["showSourceLocationTooltip"] then
				local sourceTypesText = CanIMogIt:GetSourceLocationText(itemLink);
				if (sourceTypesText and sourceTypesText ~= "") then
					tooltip:AddDoubleLine(" ", sourceTypesText);
					tooltip:Show();
					tooltip.CIMI_tooltipWritten = true
				end
			end
		end
	end

	WQT_Tooltip:Show();
	WQT_Tooltip.recalculatePadding = true;
end

function WQT_ScrollListMixin:SetButtonsEnabled(value)
	value = value==nil and true or value;
	local buttons = self.buttons;
	if not buttons then return end;
	
	for k, button in ipairs(buttons) do
		button:SetEnabled(value);
		button:EnableMouse(value);
		button:EnableMouseWheel(value);
	end
	
end

function WQT_ScrollListMixin:ApplySort()
	local list = self.questList;
	local sortOption = ADD:GetSelectedValue(WQT_WorldQuestFrame.sortButton);
	local sortFunction;
	if sortOption == 2 then -- faction
		sortFunction = SortQuestListByFaction;
	elseif sortOption == 3 then -- type
		sortFunction = SortQuestListByType;
	elseif sortOption == 4 then -- zone
		sortFunction = SortQuestListByZone;
	elseif sortOption == 5 then -- name
		sortFunction = SortQuestListByName;
	elseif sortOption == 6 then -- reward
		sortFunction = SortQuestListByReward;
	else -- time or anything else
		sortFunction = SortQuestList;
	end
	
	table.sort(list, sortFunction);
end

function WQT_ScrollListMixin:UpdateFilterDisplay()
	local isFiltering = WQT:IsFiltering();
	WQT_WorldQuestFrame.FilterBar.ClearButton:SetShown(isFiltering);
	-- If we're not filtering, we 'hide' everything
	if not isFiltering then
		WQT_WorldQuestFrame.FilterBar.Text:SetText(""); 
		WQT_WorldQuestFrame.FilterBar:SetHeight(0.1);
		return;
	end

	local filterList = "";
	local haveLabels = false;
	-- If we are filtering, 'show' things
	WQT_WorldQuestFrame.FilterBar:SetHeight(20);
	-- Emissary has priority
	if (WQT.settings.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then
		local text = _L["TYPE_EMISSARY"]
		if WQT_WorldQuestFrame.autoEmisarryId then
			text = GARRISON_TEMPORARY_CATEGORY_FORMAT:format(text);
		end
		
		filterList = text;	
	else
		for kO, option in pairs(WQT.settings.filters) do
			haveLabels = (_V["WQT_TYPEFLAG_LABELS"][kO] ~= nil);
			for kF, flag in pairs(option.flags) do
				if (flag and IsRelevantFilter(kO, kF)) then
					local label = haveLabels and _V["WQT_TYPEFLAG_LABELS"][kO][kF] or kF;
					label = type(kF) == "number" and GetFactionInfoByID(kF) or label;
					filterList = filterList == "" and label or string.format("%s, %s", filterList, label);
				end
			end
		end
	end

	WQT_WorldQuestFrame.FilterBar.Text:SetText(_L["FILTER"]:format(filterList)); 
end

function WQT_ScrollListMixin:UpdateQuestFilters()
	wipe(self.questListDisplay);
	
	local isfiltering = WQT:IsWorldMapFiltering() or WQT:IsFiltering();
	for k, questInfo in ipairs(self.questList) do
		if (questInfo.isValid) then
			questInfo.passedFilter = isfiltering and WQT:PassesAllFilters(questInfo) or not isfiltering;
			if questInfo.passedFilter then
				table.insert(self.questListDisplay, questInfo);
			end
		end
	end
end

function WQT_ScrollListMixin:UpdateQuestList()
	if (not WorldMapFrame:IsShown() or InCombatLockdown()) then return end	
	self.questList = _dataProvider:GetIterativeList();

	self:UpdateQuestFilters();

	self:ApplySort();
	if not InCombatLockdown() then
		self:DisplayQuestList();
	end
end

function WQT_ScrollListMixin:DisplayQuestList(skipPins, skipFilter)
	local mapInfo = C_Map.GetMapInfo(WorldMapFrame.mapID or 0);
	
	if not mapInfo or InCombatLockdown() or not WorldMapFrame:IsShown() or WQT_WorldQuestFrame:GetAlpha() < 1 or not WQT_WorldQuestFrame.selectedTab or WQT_WorldQuestFrame.selectedTab:GetID() ~= 2 then 
		if (not skipPins and mapInfo and mapInfo.mapType ~= Enum.UIMapType.Continent) then	
			WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
		end
		return 
	end
	
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	if buttons == nil then return; end

	local shouldShowZone = WQT.settings.alwaysAllQuests or (mapInfo and (mapInfo.mapType == Enum.UIMapType.Continent or mapInfo.mapType == Enum.UIMapType.World)); 

	if not skipFilter then
		self:UpdateQuestFilters();
		self:ApplySort();
		self:UpdateFilterDisplay();
	end
	local list = self.questListDisplay;
	local mapInfo = C_Map.GetMapInfo(WorldMapFrame.mapID);
	self:GetParent():HideOverlayMessage();
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;

		if ( displayIndex <= #list) then
			button:Update(list[displayIndex], shouldShowZone);
		else
			button.Reward.Amount:Hide();
			button.TrackedBorder:Hide();
			button.Highlight:Hide();
			button:Hide();
			button.info = nil;
		end
	end
	
	HybridScrollFrame_Update(self, #list * _V["WQT_LISTITTEM_HEIGHT"], self:GetHeight());

	if (not skipPins and mapInfo.mapType ~= Enum.UIMapType.Continent) then	
		WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
	end
	
	if (IsAddOnLoaded("Aurora")) then
		WQT_WorldQuestFrame.Background:SetAlpha(0);
	elseif (#list == 0) then
		WQT_WorldQuestFrame.Background:SetAtlas("NoQuestsBackground", true);
	else
		WQT_WorldQuestFrame.Background:SetAtlas("QuestLogBackground", true);
	end
end

function WQT_ScrollListMixin:ScrollFrameSetEnabled(enabled)
	self:EnableMouse(enabled)
	self:EnableMouse(enabled);
	self:EnableMouseWheel(enabled);
	local buttons = self.buttons;
	for k, button in ipairs(buttons) do
		button:EnableMouse(enabled);
	end
end


WQT_QuestCounterMixin = {}

function WQT_QuestCounterMixin:OnLoad()
	self:SetFrameLevel(self:GetParent():GetFrameLevel() +5);
	self.hiddenList = {};
end

function WQT_QuestCounterMixin:InfoOnEnter(frame)
	-- If it's hidden, don't show tooltip
	if frame.isHidden then return end;
	
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	GameTooltip:SetText(_L["QUEST_COUNTER_TITLE"], nil, nil, nil, nil, true);
	GameTooltip:AddLine(_L["QUEST_COUNTER_INFO"]:format(#self.hiddenList), 1, 1, 1, true);
	
	-- Add culprits
	for k, i in ipairs(self.hiddenList) do
		local n, _, _, header, _, _, _, id, _, _, _, _, _, _, _, hidden = GetQuestLogTitle(i); 
		local tagId, tagName = GetQuestTagInfo(id)
		GameTooltip:AddDoubleLine(string.format("%s (%s)", n, id), tagName, 1, 1, 1, 1, 1, 1, true);
	end
	
	GameTooltip:Show();
end

function WQT_QuestCounterMixin:UpdateText()
	local numQuests, maxQuests, color, logIsEmpty = GetQuestLogInfo(self.hiddenList);
	self.QuestCount:SetText(GENERIC_FRACTION_STRING_WITH_SPACING:format(numQuests, maxQuests));
	self.QuestCount:SetTextColor(color.r, color.g, color.b);

	-- Show or hide the icon
	local showIcon = #self.hiddenList > 0;
	self.HiddenInfo:SetAlpha(showIcon and 1 or 0);
	self.HiddenInfo.isHidden = not showIcon;
end



WQT_CoreMixin = {}

function WQT_CoreMixin:OnLoad()

	self.pinHandler = CreateFromMixins(WQT_PinHandlerMixin);
	self.pinHandler:OnLoad();
	self.bountyCounterPool = CreateFramePool("FRAME", self, "WQT_BountyCounterTemplate");

	self:SetFrameLevel(self:GetParent():GetFrameLevel()+4);
	self.Blocker:SetFrameLevel(self:GetFrameLevel()+4);
	
	self.filterDropDown = ADD:CreateMenuTemplate("WQT_WorldQuestFrameFilterDropDown", self);
	self.filterDropDown.noResize = true;
	ADD:Initialize(self.filterDropDown, function(self, level) WQT:InitFilter(self, level) end, "MENU");
	self.FilterButton.Indicator.tooltipTitle = _L["MAP_FILTER_DISABLED_TITLE"];
	self.FilterButton.Indicator.tooltipSub = _L["MAP_FILTER_DISABLED_INFO"];
	
	self.sortButton = ADD:CreateMenuTemplate("WQT_WorldQuestFrameSortButton", self, nil, "BUTTON");
	self.sortButton:SetSize(97, 22);
	self.sortButton:SetPoint("RIGHT", "WQT_WorldQuestFrameFilterButton", "LEFT", 12, -1);
	self.sortButton:EnableMouse(false);
	self.sortButton:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); end);

	ADD:Initialize(self.sortButton, function(self) WQT:InitSort(self, level) end);
	ADD:SetWidth(self.sortButton, 90);
	
	
	
	local frame = ADD:CreateMenuTemplate("WQT_TrackDropDown", self);
	frame:EnableMouse(true);
	ADD:Initialize(frame, function(self, level) WQT:InitTrackDropDown(self, level) end, "MENU");
	
	
	self.dataProvider = _dataProvider;
	self.dataProvider:OnLoad()
	
	self.dataProvider:HookWaitingRoomUpdate(function() 
			WQT:debugPrint("Waitingroom Update callback")
			WQT_QuestScrollFrame:ApplySort();
			WQT_QuestScrollFrame:UpdateQuestFilters();
			if WQT_WorldQuestFrame:GetAlpha() > 0 then 
				WQT_QuestScrollFrame:DisplayQuestList();
			else
				WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(); 
			end
		end)

	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("QUEST_TURNED_IN");
	self:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL"); -- Class hall items
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:SetScript("OnEvent", function(self, event, ...) 
			if	(self.dataProvider) then
				self.dataProvider:OnEvent(event, ...);
			end
			if (self[event]) then 
				self[event](self, ...) 
			else 
				WQT:debugPrint("WQT missing function for:",event); 
			end 

		end)

	-- Refresh the list every 60 seconds to update time remaining and check for new quests.
	-- I want this replaced with a function hook or event call. QUEST_LOG_UPDATE triggers too often
	self.ticker = C_Timer.NewTicker(_V["WQT_REFRESH_DEFAULT"], function() self.ScrollFrame:UpdateQuestList(); end)

	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd
	
	self.trackedQuests = {};
	self.recentlyUntrackedQuest = nil;
	
	-- Step 2: Check compare list after changes, if quest is left == quest that was untracked
	-- check QUEST_WATCH_LIST_CHANGED for step 1
	hooksecurefunc("ObjectiveTracker_Update", function(...)
				self.recentlyUntrackedQuest = nil;
				local wqModule = WQT:GetObjectiveTrackerWQModule()
				if wqModule then
					for k, v in pairs(wqModule.usedBlocks) do
						self.trackedQuests[k] = nil;
					end
					
					-- store the untracked quest. right clicking on map PoI will retrack the quest
					for k, v in pairs(self.trackedQuests) do
						self.recentlyUntrackedQuest = k;
					end
					wipe(self.trackedQuests);
					
					local questId = self.recentlyUntrackedQuest;
					-- If we have auto arrow handling turned on, remove it if it exists
					if (questId and _TomTomLoaded and WQT.settings.useTomTom and WQT.settings.TomTomAutoArrow) then
						local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
						local zoneId = C_TaskQuest.GetQuestZoneID(questId);
						if (title and zoneId) then
							local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
							if (x and y) then
								local key = TomTom:GetKeyArgs(zoneId, x, y, title);
								local wp = TomTom.waypoints[zoneId] and TomTom.waypoints[zoneId][key];
								if wp then
									TomTom:RemoveWaypoint(wp);
								end
								
							end
						end
					end
				end
		end)
	
	-- Show quest tab when leaving quest details
	hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
			self:SelectTab(WQT_TabNormal);
		end)
	
	WorldMapFrame:HookScript("OnShow", function() 
			local mapAreaID = WorldMapFrame.mapID;
			_dataProvider:LoadQuestsInZone(mapAreaID);
			self.ScrollFrame:UpdateQuestList();
			self:SelectTab(self.selectedTab); 
			
			-- If emissaryOnly was automaticaly set, and there's none in the current list, turn it off again.
			if WQT_WorldQuestFrame.autoEmisarryId and not WQT_WorldQuestFrame.dataProvider:ListContainsEmissary() then
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			
		end)
		
	WorldMapFrame:HookScript("OnHide", function() 
			_dataProvider:ClearData();
		end)

	QuestScrollFrame:SetScript("OnShow", function() 
			if(self.selectedTab and self.selectedTab:GetID() == 2) then
				self:SelectTab(WQT_TabWorld); 
			else
				self:SelectTab(WQT_TabNormal); 
			end
		end)
		
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
		local mapAreaID = WorldMapFrame.mapID;
	
		if (self.currentMapId ~= mapAreaID) then
			_dataProvider:LoadQuestsInZone(mapAreaID);
			self.currentMapId = mapAreaID;
			self.currentMapInfo = C_Map.GetMapInfo(mapAreaID);
			ADD:HideDropDownMenu(1);
			self.ScrollFrame:UpdateQuestList();
			self.pinHandler:UpdateMapPoI();
		end
	end)
	
	-- Update filters when stuff happens to the world map filters
	local worldMapFilter;
	
	for k, frame in ipairs(WorldMapFrame.overlayFrames) do
		for name, value in pairs(frame) do
			if (name == "OnSelection") then
				worldMapFilter = frame;
				break;
			end
		end
	end
	if (worldMapFilter) then
		hooksecurefunc(worldMapFilter, "OnSelection", function() 
				self.ScrollFrame:UpdateQuestList();
				WQT:UpdateFilterIndicator();
			end);
		self.worldMapFilter = worldMapFilter;
	end
	
	-- Close all our custom dropdowns when opening an Blizzard dropdown
	hooksecurefunc("ToggleDropDownMenu", function()
			ADD:CloseDropDownMenus();
		end);
	
	-- Fix for Blizzard issue with quest details not showing the first time a quest is clicked
	-- And (un)tracking quests on the details frame closes the frame
	local lastQuest = nil;
	QuestMapFrame.DetailsFrame.TrackButton:HookScript("OnClick", function(self) 
			QuestMapFrame_ShowQuestDetails(lastQuest);
		end)
	
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(questId)
			self:SelectTab(WQT_TabDetails);
			if QuestMapFrame.DetailsFrame.questID == nil then
				QuestMapFrame.DetailsFrame.questID = questId;
			end
			lastQuest = QuestMapFrame.DetailsFrame.questID;
		end)
	
	-- Auto emisarry when clicking on one of the buttons
	local bountyBoard = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]];
	self.bountyBoard = bountyBoard;
	
	hooksecurefunc(bountyBoard, "OnTabClick", function(self, tab) 
		if (not WQT.settings.autoEmisarry or tab.isEmpty or WQT.settings.emissaryOnly) then return; end
		WQT_WorldQuestFrame.autoEmisarryId = bountyBoard.bounties[tab.bountyIndex];
		WQT_QuestScrollFrame:DisplayQuestList();
	end)
	
	hooksecurefunc(bountyBoard, "RefreshSelectedBounty", function(s, tab) 
		if (WQT.settings.bountyCounter) then
			self:UpdateBountyCounters();
		end
	end)
	
	-- Slight offset the tabs to make room for the counters
	hooksecurefunc(bountyBoard, "AnchorBountyTab", function(self, tab) 
		if (not WQT.settings.bountyCounter) then return end
		local point, relativeTo, relativePoint, x, y = tab:GetPoint(1);
		tab:SetPoint(point, relativeTo, relativePoint, x, y + 2);
	end)
	
	-- Show hightlight in list when hovering over PoI
	hooksecurefunc("TaskPOI_OnEnter", function(self)
			if (WQT.settings.disablePoI) then return; end
			if (self.questID ~= WQT_QuestScrollFrame.PoIHoverId) then
				WQT_QuestScrollFrame.PoIHoverId = self.questID;
				WQT_QuestScrollFrame:DisplayQuestList(true);
			end
			self.notTracked = not QuestIsWatched(self.questID);
			
			-- Improve official tooltips overlap
			local level = GameTooltip:GetFrameLevel();
			ShoppingTooltip1:SetFrameLevel(level + 1);
			ShoppingTooltip2:SetFrameLevel(level + 1);
		end)
		
	hooksecurefunc("TaskPOI_OnLeave", function(self)
			if (WQT.settings.disablePoI) then return; end
			WQT_QuestScrollFrame.PoIHoverId = -1;
			WQT_QuestScrollFrame:DisplayQuestList(true);
			self.notTracked = nil;
		end)
		
	-- PVEFrame quest grouping
	LFGListFrame:HookScript("OnHide", function() 
			WQT_GroupSearch:Hide(); 
			WQT_GroupSearch.questId = nil;
			WQT_GroupSearch.title = nil;
		end)

	hooksecurefunc("LFGListSearchPanel_UpdateResults", function(self)
			if (self.searching and not InCombatLockdown()) then
				local searchString = LFGListFrame.SearchPanel.SearchBox:GetText();
				searchString = searchString:lower();
			
				if (WQT_GroupSearch.questId and WQT_GroupSearch.title and not (searchString:find(WQT_GroupSearch.questId) or WQT_GroupSearch.title:lower():find(searchString))) then
					WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_TYPO"]:format(WQT_GroupSearch.questId, WQT_GroupSearch.title));
					WQT_GroupSearch:Show();
				else
					WQT_GroupSearch:Hide();
				end
			end
		end);
		
	LFGListFrame.EntryCreation:HookScript("OnHide", function() 
			if (not InCombatLockdown()) then
				WQT_GroupSearch:Hide();
			end
		end);
		
	LFGListSearchPanelScrollFrame.StartGroupButton:HookScript("OnClick", function() 
			-- If we are creating a group because we couldn't find one, show the info on the create frame
			if InCombatLockdown() then return; end
			local searchString = LFGListFrame.SearchPanel.SearchBox:GetText();
			searchString = searchString:lower();
			if (WQT_GroupSearch.questId and WQT_GroupSearch.title and (searchString:find(WQT_GroupSearch.questId) or WQT_GroupSearch.title:lower():find(searchString))) then
				WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_CREATE"]:format(WQT_GroupSearch.questId, WQT_GroupSearch.title));
				WQT_GroupSearch:SetParent(LFGListFrame.EntryCreation.Name);
				WQT_GroupSearch:SetFrameLevel(LFGListFrame.EntryCreation.Name:GetFrameLevel()+5);
				WQT_GroupSearch:ClearAllPoints();
				WQT_GroupSearch:SetPoint("BOTTOMLEFT", LFGListFrame.EntryCreation.Name, "TOPLEFT", -2, 3);
				WQT_GroupSearch:SetPoint("BOTTOMRIGHT", LFGListFrame.EntryCreation.Name, "TOPRIGHT", -2, 3);
				WQT_GroupSearch.downArrow = true;
				WQT_GroupSearch.questId = nil;
				WQT_GroupSearch.title = nil;
				WQT_GroupSearch:Show();
			end
		end)
	local test = {15, 4};	

	-- Shift questlog around to make room for the tabs
	local a,b,c,d =QuestMapFrame:GetPoint(1);
	QuestMapFrame:SetPoint(a,b,c,d,-60);
	QuestScrollFrame:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -5);
	QuestScrollFrame.Background:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -5);
	QuestMapFrame.DetailsFrame:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -26, -8)
	QuestMapFrame.VerticalSeparator:SetHeight(470);
end

function WQT_CoreMixin:UpdateBountyCounters()
	self.bountyCounterPool:ReleaseAll();
	if (not WQT.settings.bountyCounter) then return end
	
	for tab, v in pairs(self.bountyBoard.bountyTabPool.activeObjects) do
		self:AddBountyCountersToTab(tab);
	end
end

function WQT_CoreMixin:RepositionBountyTabs()
	for tab, v in pairs(self.bountyBoard.bountyTabPool.activeObjects) do
		self.bountyBoard:AnchorBountyTab(tab);
	end
end


function WQT_CoreMixin:AddBountyCountersToTab(tab)
	local bountyData = self.bountyBoard.bounties[tab.bountyIndex];
	if bountyData then
		local questIndex = GetQuestLogIndexByID(bountyData.questID);
		if questIndex > 0 then
			local desc = GetQuestLogLeaderBoard(1, questIndex);
			
			local progress, goal = desc:match("([%d]+)%s*/%s*([%d]+)");
			progress = tonumber(progress);
			goal = tonumber(goal);
			
			if progress == goal then return end;
			
			local offsetAngle, startAngle = 32, 270;
			
			-- position of first counter
			startAngle = startAngle - offsetAngle * (goal -1) /2
			
			for i=1, goal do
				local counter = self.bountyCounterPool:Acquire();

				local x = cos(startAngle) * 16;
				local y = sin(startAngle) * 16;
				counter:SetPoint("CENTER", tab.Icon, "CENTER", x, y);
				counter:SetParent(tab);
				counter:Show();
				
				-- Light nr of completed
				if i <= progress then
					counter.icon:SetTexCoord(0, 0.5, 0, 0.5);
					counter.icon:SetVertexColor(1, 1, 1, 1);
					counter.icon:SetDesaturated(false);
				else
					counter.icon:SetTexCoord(0, 0.5, 0, 0.5);
					counter.icon:SetVertexColor(0.65, 0.65, 0.65, 1);
					counter.icon:SetDesaturated(true);
				end

				-- Offset next counter
				startAngle = startAngle + offsetAngle;
			end
		end
	end
	
end

function WQT_CoreMixin:ShowHighlightOnMapFilters()
	if (not self.worldMapFilter) then return; end
	WQT_PoISelectIndicator:SetParent(self.worldMapFilter);
	WQT_PoISelectIndicator:ClearAllPoints();
	WQT_PoISelectIndicator:SetPoint("CENTER", self.worldMapFilter, 0, 1);
	WQT_PoISelectIndicator:SetFrameLevel(self.worldMapFilter:GetFrameLevel()+1);
	WQT_PoISelectIndicator:Show();
	local size = WQT.settings.bigPoI and 50 or 40;
	WQT_PoISelectIndicator:SetSize(size, size);
	WQT_PoISelectIndicator:SetScale(0.40);
end

function WQT_CoreMixin:ShowHighlightOnPin(pin, scale)
	WQT_PoISelectIndicator:SetParent(pin);
	WQT_PoISelectIndicator:ClearAllPoints();
	WQT_PoISelectIndicator:SetPoint("CENTER", pin, 0, -1);
	WQT_PoISelectIndicator:SetFrameLevel(pin:GetFrameLevel()+1);
	WQT_PoISelectIndicator.pinLevel = pin:GetFrameLevel();
	WQT_PoISelectIndicator.pin = pin;
	pin:SetFrameLevel(3000);
	WQT_PoISelectIndicator:Show();
	local size = WQT.settings.bigPoI and 50 or 40;
	WQT_PoISelectIndicator:SetSize(size, size);
	WQT_PoISelectIndicator:SetScale(scale or 1);
end

function WQT_CoreMixin:FilterClearButtonOnClick()
	ADD:CloseDropDownMenus();
	if WQT_WorldQuestFrame.autoEmisarryId then
		WQT_WorldQuestFrame.autoEmisarryId = nil;
	elseif WQT.settings.emissaryOnly then
		WQT.settings.emissaryOnly = false;
	else
		for k, v in pairs(WQT.settings.filters) do
			WQT:SetAllFilterTo(k, false);
		end
	end
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:SearchGroup(questInfo)
	local id, title;
	if (type(questInfo) == "number") then
		id = questInfo;
		title = C_TaskQuest.GetQuestInfoByQuestID(id);
	else
		id = questInfo.questId;
		title = questInfo.title;
	end
	
	WQT_GroupSearch:Hide();
	LFGListUtil_FindQuestGroup(id);
	if (not C_LFGList.CanCreateQuestGroup(id)) then
		WQT_GroupSearch:SetParent(LFGListFrame.SearchPanel.SearchBox);
		WQT_GroupSearch:SetFrameLevel(LFGListFrame.SearchPanel.SearchBox:GetFrameLevel()+5);
		WQT_GroupSearch:ClearAllPoints();
		WQT_GroupSearch:SetPoint("TOPLEFT", LFGListFrame.SearchPanel.SearchBox, "BOTTOMLEFT", -2, -3);
		WQT_GroupSearch:SetPoint("RIGHT", LFGListFrame.SearchPanel, "RIGHT", -30, 0);
	
		WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_SEARCH"]:format(id, title));
		WQT_GroupSearch.downArrow = false;
		WQT_GroupSearch:Show();
		
		WQT_GroupSearch.questId = id;
		WQT_GroupSearch.title = title;
	end
end

function WQT_CoreMixin:ShouldAllowLFG(questInfo)
	local questType;
	if type(questInfo) == "number" then
		questType = select(3, GetQuestTagInfo(questInfo));
	else 
		questType = questInfo.type;
	end
	
	return not (questType == LE_QUEST_TAG_TYPE_PET_BATTLE or questType == LE_QUEST_TAG_TYPE_DUNGEON or questType == LE_QUEST_TAG_TYPE_PROFESSION or questType == LE_QUEST_TAG_TYPE_RAID);
end

function WQT_CoreMixin:ADDON_LOADED(loaded)
	WQT:UpdateFilterIndicator();
	if (loaded == "Blizzard_FlightMap") then
		for k, v in pairs(FlightMapFrame.dataProviders) do 
			if (type(k) == "table") then 
				for k2, v2 in pairs(k) do 
					if (k2 == "activePins") then 
						WQT.FlightmapPins = k;
						break;
					end 
				end 
			end 
		end
		WQT.FlightMapList = {};
		-- Load quest list once on show, the dataProvider will update the rewards if needed
		hooksecurefunc(WQT.FlightmapPins, "OnShow", function() 
				_dataProvider:LoadQuestsInZone(GetTaxiMapID());
				self.pinHandler:UpdateFlightMapPins() 
			end);
		hooksecurefunc(WQT.FlightmapPins, "RefreshAllData", function() self.pinHandler:UpdateFlightMapPins() end);
		hooksecurefunc(WQT.FlightmapPins, "OnHide", function() 
				for id in pairs(WQT.FlightMapList) do
					WQT.FlightMapList[id].id = -1;
					WQT.FlightMapList[id] = nil;
				end 
			end)

		-- find worldmap's world quest data provider
		self:UnregisterEvent("ADDON_LOADED");
	elseif (loaded == "TomTom") then
		_TomTomLoaded = true;
	elseif (loaded == "CanIMogIt") then
		_CIMILoaded = true;
	elseif (loaded == "WorldFlightMap") then
		_WFMLoaded = true;
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	self.ScrollFrame:ScrollFrameSetEnabled(false)
	self:ShowOverlayMessage(_L["COMBATLOCK"]);
	ADD:HideDropDownMenu(1);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	if self:GetAlpha() == 1 then
		self.ScrollFrame:ScrollFrameSetEnabled(true)
	end
	self.ScrollFrame:UpdateQuestList();
	self:SelectTab(self.selectedTab);
	WQT:UpdateFilterIndicator();
end

function WQT_CoreMixin:QUEST_TURNED_IN(questId)
	if (QuestUtils_IsQuestWorldQuest(questId) or WQT_WorldQuestFrame.autoEmisarryId == questId) then
		-- Remove TomTom arrow if tracked
		if (_TomTomLoaded and WQT.settings.useTomTom and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			local questInfo = WQT_WorldQuestFrame.dataProvider:GetQuestById(questId);
			if questInfo and questInfo.isValid then
				local mapId = questInfo.mapInfo.mapID;
				local key = TomTom:GetKeyArgs(mapId, questInfo.mapInfo.mapX, questInfo.mapInfo.mapY, questInfo.title);
				local wp = TomTom.waypoints[mapId] and TomTom.waypoints[mapId][key];
				if wp then
					TomTom:RemoveWaypoint(wp);
				end
			end
		end

		self.ScrollFrame:UpdateQuestList();
	end
end

function WQT_CoreMixin:WORLD_QUEST_COMPLETED_BY_SPELL(...)
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:QUEST_WATCH_LIST_CHANGED(...)
	local questId, added = ...;
	-- step 1: Get all the tracked quests before any changes happen
	-- check ObjectiveTracker_Update hook for step 2
	self.recentlyUntrackedQuest = nil;
	local wqModule = WQT:GetObjectiveTrackerWQModule();
	if wqModule then
		wipe(self.trackedQuests);
		for k, v in pairs(wqModule.usedBlocks) do
			self.trackedQuests[k] = true
		end
	end
		
	self.ScrollFrame:DisplayQuestList();

	if questId and added and _TomTomLoaded and WQT.settings.useTomTom and WQT.settings.TomTomAutoArrow and IsWorldQuestHardWatched(questId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local zoneId = C_TaskQuest.GetQuestZoneID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and zoneId and x and y) then
			local uId = TomTom:AddWaypoint(zoneId, x, y, {["title"] = title})
		end
	end
end

function WQT_CoreMixin:QUEST_LOG_UPDATE()
	--WQT_WorldQuestFrame.dataProvider:UpdateWaitingRoom();
	WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(); 
	--Do a delayed update because things can mess up if this add-on is set as OptionalDeps for another add-on
	C_Timer.NewTicker(0.1, function() WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(); end, 1); 
	
	-- Update the count number counter
	WQT_QuestLogFiller:UpdateText();
end

function WQT_CoreMixin:SetCvarValue(flagKey, value)
	value = (value == nil) and true or value;

	if _V["WQT_CVAR_LIST"][flagKey] then
		SetCVar(_V["WQT_CVAR_LIST"][flagKey], value);
		self.ScrollFrame:DisplayQuestList();
		WQT:UpdateFilterIndicator();
		return true;
	end
	return false;
end

function WQT_CoreMixin:ShowOverlayMessage(message)
	message = message or "";
	self:SetCombatEnabled(false);
	ShowUIPanel(self.Blocker);
	self.Blocker.Text:SetText(message);
end

function WQT_CoreMixin:HideOverlayMessage()
	self:SetCombatEnabled(true);
	HideUIPanel(self.Blocker);
end

function WQT_CoreMixin:SetCombatEnabled(value)
	value = value==nil and true or value;
	
	self:EnableMouse(value);
	self:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouse(value);
	WQT_QuestScrollFrame.scrollBar:EnableMouseWheel(value);
	WQT_QuestScrollFrame.scrollBar:EnableMouse(value);
	WQT_QuestScrollFrameScrollChild:EnableMouseWheel(value);
	WQT_QuestScrollFrameScrollChild:EnableMouse(value);
	WQT_WorldQuestFrameSortButtonButton:EnableMouse(value);
	self.FilterButton:EnableMouse(value);
	if value then
		self.FilterButton:Enable();
		self.sortButton:Enable();
	else
		self.FilterButton:Disable();
		self.sortButton:Disable();
	end

	self.ScrollFrame:SetButtonsEnabled(value);
	self.ScrollFrame:EnableMouseWheel(value);
end

function WQT_CoreMixin:SelectTab(tab)
	--if not tab then return end;
	-- There's a lot of shenanigans going on here with enabling/disabling the mouse due to
	-- Addon restructions of hiding/showing frames during combat
	local id = tab and tab:GetID() or 0;
	if self.selectedTab ~= tab then
		ADD:HideDropDownMenu(1);
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	end
	
	self.selectedTab = tab;
	
	WQT_TabNormal:SetAlpha(1);
	WQT_TabWorld:SetAlpha(1);
	WQT_TabNormal.Hider:SetAlpha(1);
	WQT_TabWorld.Hider:SetAlpha(1);
	WQT_QuestLogFiller:SetAlpha(0);
	
	-- because hiding stuff in combat doesn't work
	if not InCombatLockdown() then
		WQT_TabNormal:SetFrameLevel(WQT_TabNormal:GetParent():GetFrameLevel()+(tab == WQT_TabNormal and 8 or 1));
		WQT_TabWorld:SetFrameLevel(WQT_TabWorld:GetParent():GetFrameLevel()+(tab == WQT_TabWorld and 8 or 1));
	 
		self.FilterButton:SetFrameLevel(self:GetFrameLevel());
		self.sortButton:SetFrameLevel(self:GetFrameLevel());
		
		self.FilterButton:EnableMouse(true);
	end

	WQT_TabWorld:EnableMouse(true);
	WQT_TabNormal:EnableMouse(true);

	if (not QuestScrollFrame.Contents:IsShown() and not QuestMapFrame.DetailsFrame:IsShown()) or id == 1 then
		-- Default questlog
		self:SetAlpha(0);
		WQT_TabNormal.Hider:SetAlpha(0);
		WQT_QuestLogFiller:SetAlpha(1);
		WQT_TabNormal.Highlight:Show();
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		ShowUIPanel(QuestScrollFrame);
		
		if not InCombatLockdown() then
			self.Blocker:EnableMouse(false);
			HideUIPanel(self.Blocker)
			self:SetCombatEnabled(false);
		end
	elseif id == 2 then
		-- WQT
		WQT_TabWorld.Hider:SetAlpha(0);
		WQT_TabWorld.Highlight:Show();
		self:SetAlpha(1);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		HideUIPanel(QuestScrollFrame);
		self.ScrollFrame:DisplayQuestList();
		
		if not InCombatLockdown() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel()+3);
			self:SetCombatEnabled(true);
		end
	elseif id == 3 then
		-- Quest details
		self:SetAlpha(0);
		WQT_TabNormal:SetAlpha(0);
		WQT_TabWorld:SetAlpha(0);
		HideUIPanel(QuestScrollFrame);
		ShowUIPanel(QuestMapFrame.DetailsFrame);
		WQT_TabWorld:EnableMouse(false);
		WQT_TabNormal:EnableMouse(false);
		if not InCombatLockdown() then
			self.Blocker:EnableMouse(false);
			WQT_TabWorld:EnableMouse(false);
			WQT_TabNormal:EnableMouse(false);
			self.FilterButton:EnableMouse(false);
			self:SetCombatEnabled(false);
		end
	end
	WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
end


--------
-- Debug stuff to monitor mem usage
-- Remember to uncomment line template in xml
--------

if _debug then

	local l_debug = CreateFrame("frame", addonName .. "Debug", UIParent);
	WQT.debug = l_debug;

	l_debug.linePool = CreateFramePool("FRAME", l_debug, "WQT_DebugLine");

	local function ShowDebugHistory()
		local highest = 1000;
		for k, v in ipairs(l_debug.history) do
			if (v > highest) then
				highest = v;
			end
		end
		
		
		local mem = floor(l_debug.history[#l_debug.history]*100)/100;
		local scale = l_debug:GetScale();
		local yScale = 1000 / highest ;
		local current = 0;
		local following = 0;
		local line = nil;
		l_debug.linePool:ReleaseAll();
		
		for i=1, highest/1000 do
			local scaleLine = l_debug.linePool:Acquire();
			scaleLine:Show();
			scaleLine.Fill:SetStartPoint("BOTTOMLEFT", l_debug, 0, i*100*scale* yScale);
			scaleLine.Fill:SetEndPoint("BOTTOMLEFT", l_debug, 100*scale, i*100*scale* yScale);
			scaleLine.Fill:SetVertexColor(0.5, 0.5, 0.5, 0.5);
			scaleLine.Fill:Show();
		end
		
		for i=1, #l_debug.history, 1 do
			line = l_debug.linePool:Acquire();
			current = l_debug.history[i];
			following = i == # l_debug.history and  current or l_debug.history[i+1]; 
	
			line:Show();
			line.Fill:SetStartPoint("BOTTOMLEFT", l_debug, (i-1)*2*scale, current/10*scale * yScale);
			line.Fill:SetEndPoint("BOTTOMLEFT", l_debug, i*2*scale, following/10*scale * yScale);
			local fade = ((current-500)/ 500)*2;
			line.Fill:SetVertexColor(fade, 2-fade, 0, 1);
			line.Fill:Show();
		end
		l_debug.text:SetText(mem)
	end

	l_debug:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		  edgeFile = nil,
		  tileSize = 0, edgeSize = 16,
		  insets = { left = 0, right = 0, top = 0, bottom = 0 }
		  })
	l_debug:SetFrameLevel(5)
	l_debug:SetMovable(true)
	l_debug:SetPoint("Center", 250, 0)
	l_debug:RegisterForDrag("LeftButton")
	l_debug:EnableMouse(true);
	l_debug:SetScript("OnDragStart", l_debug.StartMoving)
	l_debug:SetScript("OnDragStop", l_debug.StopMovingOrSizing)
	l_debug:SetWidth(100)
	l_debug:SetHeight(100)
	l_debug:SetClampedToScreen(true)
	l_debug.text = l_debug:CreateFontString(nil, nil, "GameFontWhiteSmall")
	l_debug.text:SetPoint("BOTTOMLEFT", 2, 2)
	l_debug.text:SetText("0000")
	l_debug.text:SetJustifyH("left")
	l_debug.time = 0;
	l_debug.interval = 0.2;
	l_debug.history = {}
	l_debug.callCounters = {}

	l_debug:SetScript("OnUpdate", function(self,elapsed) 
			self.time = self.time + elapsed;
			if(self.time >= self.interval) then
				self.time = self.time - self.interval;
				UpdateAddOnMemoryUsage();
				table.insert(self.history, GetAddOnMemoryUsage(addonName));
				if(#self.history > 50) then
					table.remove(self.history, 1)
				end
				ShowDebugHistory()

				if(l_debug.showTT) then
					GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
					GameTooltip:SetText("Function calls", nil, nil, nil, nil, true);
					for k, v in pairs(l_debug.callCounters) do
						local t = time();
						local ts = 0;
						local mem = 0;
						local memtot = 0;
						local latest = 0;
						
						for i = #v, 1, -1 do
							ts, mem = v[i]:match("(%d+)|(%d+)");
							ts = tonumber(ts);
							
							mem = tonumber(mem);
							if ts then
								if (t - ts> 20) then
									table.remove(v, i);
								elseif (ts > latest) then
									latest = ts;
								end
								memtot = memtot + mem;
							end
						end
							
						if #v > 0 then
							local color = (t - latest <=1) and NORMAL_FONT_COLOR or DISABLED_FONT_COLOR;
							GameTooltip:AddDoubleLine(k, #v .. " (" .. floor(memtot/10)/10 .. ")", color.r, color.g, color.b, color.r, color.g, color.b);		
						end
					end
					GameTooltip:Show();
				end
			end
		end)

	l_debug:SetScript("OnEnter", function(self,elapsed) 
			l_debug.showTT = true;
			
		end)
		
	l_debug:SetScript("OnLeave", function(self,elapsed) 
			l_debug.showTT = false;
			GameTooltip:Hide();
		end)
	l_debug:Show()

end