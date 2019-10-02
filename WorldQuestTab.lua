--
-- Info structure
--
-- isCriteria				[boolean] is part of currently selected amissary
-- passedFilter				[boolean] passed current filters
-- questId					[number] questId
-- rarity					[number] quest rarity; normal, rare, epic
-- isValid					[boolean, nullable] true if the quest is valid. Quest can be invalid if they are awaiting data or are an actual invalid quest (Don't ask).
-- time						[table] time related values
--		seconds					[number] seconds remaining
-- mapInfo					[table] zone related values
--		mapX					[number] x pin position
--		mapY					[number] y pin position
-- reward					[table] reward related values
--		type					[number] reward type, see WQT_REWARDTYPE below
--		texture					[number/string] texture of the reward. can be string for things like gold or unknown reward
--		amount					[amount] amount of items, gold, rep, or item level
--		id						[number, nullable] itemId for reward. null if not an item
--		quality					[number] item quality; common, rare, epic, etc
--		canUpgrade				[boolean, nullable] true if item has a chance to upgrade (e.g. ilvl 285+)

--
-- For other data use following functions
--
-- local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questId);
-- local zoneInfo = WQT_Utils:GetCachedMapInfo(zoneId); 	| zoneInfo = {[mapID] = number, [name] = string, [parenMapID] = number, [mapType] = Enum.UIMapType};
-- local mapInfo = WQT_Utils:GetMapInfoForQuest(questId); 	| Quick function that gets the zoneId from the questId first
-- local factionInfo = WQT_Utils:GetFactionDataInternal(factionId); 	| factionInfo = {[name] = string, [texture] = string/number, [playerFaction] = string, [expansion] = number}
-- local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, displayTimeLeft = GetQuestTagInfo(questId);
-- local texture, sizeX, sizeY = WQT_Utils:GetCachedTypeIconData(worldQuestType, tradeskillLineIndex);
-- local timeLeftSeconds, timeString, color, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated);

--
-- Callbacks (WQT_WorldQuestFrame:RegisterCallback(event, func))
--
-- "InitFilter" 		(self, level) After InitFilter finishes
-- "DisplayQuestList" 	(skipPins) After all buttons in the list have been updated
-- "FilterQuestList"	() After the list has been filtered
-- "QuestsLoaded"		() After the dataprovider updated its quest data
-- "WaitingRoomUpdated"	() After data in the dataprovider's waitingroom got updated
-- "SortChanged"		(category) After sort category was changed to a different one
-- "ListButtonUpdate"	(button) After a button was updated and shown
-- "AnchorChanged"		(anchor) After the anchor of the quest list has changed

local addonName, addon = ...

local WQT = addon.WQT;
local ADD = LibStub("AddonDropDown-1.0");

local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;

local _; -- local trash 
local _emptyTable = {};

local _playerFaction = GetPlayerFactionGroup();
local _playerName = UnitName("player");

local utilitiesStatus = select(5, GetAddOnInfo("WorldQuestTabUtilities"))
local _utilitiesInstalled = not utilitiesStatus or utilitiesStatus ~= "MISSING";

local _WFMLoaded = IsAddOnLoaded("WorldFlightMap");

local WQT_DEFAULTS = {
	global = {	
		versionCheck = "";
		sortBy = 1;
		updateSeen = false;
		fullScreenButtonPos = {["x"] = -1, ["y"] = -1};

		["general"] = {
			defaultTab = false;
			saveFilters = true;
			emissaryOnly = false;
			useLFGButtons = false;
			autoEmisarry = true;
			questCounter = true;
			bountyCounter = true;
			
			loadUtilities = true;
			
			useTomTom = true;
			TomTomAutoArrow = true;
			TomTomArrowOnClick = false;
		};
		
		["list"] = {
			typeIcon = true;
			factionIcon = true;
			zone = true;
			amountColors = true;
			alwaysAllQuests = false;
			fullTime = false;
		};

		["pin"] = {
			typeIcon = true;
			rewardTypeIcon = false;
			filterPoI = true;
			bigPoI = false;
			disablePoI = false;
			reward = true;
			timeLabel = false;
			ringType = _V["RINGTYPE_TIME"];
		};

		["filters"] = {
				[1] = {["name"] = FACTION
				, ["flags"] = {[OTHER] = true, [_L["NO_FACTION"]] = true}}
				,[2] = {["name"] = TYPE
						, ["flags"] = {["Default"] = true, ["Elite"] = true, ["PvP"] = true, ["Petbattle"] = true, ["Dungeon"] = true, ["Raid"] = true, ["Profession"] = true, ["Invasion"] = true, ["Assault"] = true, ["Daily"] = true}}
				,[3] = {["name"] = REWARD
						, ["flags"] = {["Item"] = true, ["Armor"] = true, ["Gold"] = true, ["Currency"] = true, ["Artifact"] = true, ["Relic"] = true, ["None"] = true, ["Experience"] = true, ["Honor"] = true, ["Reputation"] = true}}
			}
	}
}

for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	if v.expansion >= LE_EXPANSION_LEGION then
		WQT_DEFAULTS.global.filters[1].flags[k] = true;
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

local function AddTomTomArrowByQuestId(questId)
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

local function RemoveTomTomArrowbyQuestId(questId)
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

local function GetQuestLogInfo(hiddenList)
	local numEntries = GetNumQuestLogEntries();
	local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept();
	local questCount = 0;
	wipe(hiddenList);
	for questLogIndex = 1, numEntries do
		local _, _, _, isHeader, _, _, frequency, questID, _, _, _, _, isTask, isBounty, _, isHidden, _ = GetQuestLogTitle(questLogIndex);
		local tagID = GetQuestTagInfo(questID)
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

function WQT:GetFlightMapPin(questId)
	if not WQT.FlightmapPins then return nil end;
	
	return WQT.FlightmapPins.activePins[questId];
end

 WQT_MapDP = nil;

local function GetMapWQProvider()
	if WQT.mapWQProvider then return WQT.mapWQProvider; end
	
	for k in pairs(WorldMapFrame.dataProviders) do 
		for k1 in pairs(k) do
			if k1=="IsMatchingWorldMapFilters" then 
				WQT.mapWQProvider = k; 
				WQT_MapDP = k;
				break;
			end 
		end 
	end

	if not WQT.hookedWQProvider then
	-- We hook it here because we can't hook it during addonloaded for some reason
	hooksecurefunc(WQT.mapWQProvider, "RefreshAllData", function() 
			if (WQT.settings.pin.disablePoI) then return; end
			-- Hook a script to every pin's OnClick
			for _, pin in pairs(WQT.mapWQProvider.activePins ) do
				if (not pin.WQTHooked) then
					pin.WQTHooked = true;
					hooksecurefunc(pin, "OnClick", function(self, button) 
						if (WQT.settings.pin.disablePoI) then return; end
						
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
			-- Bonus Objective pins
			if (WorldMapFrame.pinPools.BonusObjectivePinTemplate) then
				for pin in pairs(WorldMapFrame.pinPools.BonusObjectivePinTemplate.activeObjects) do
					if (not pin.WQTHooked) then
						pin.WQTHooked = true;
						hooksecurefunc(pin, "OnClick", function(self, button) 
							if (button == "RightButton") then
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
			end

		end);
		WQT.hookedWQProvider = true;
	end
		
	return WQT.mapWQProvider;
end

function WQT:GetFirstContinent(mapId) 
	local info = WQT_Utils:GetCachedMapInfo(mapId);
	if not info then return mapId; end
	local parent = info.parentMapID;
	if not parent or info.mapType <= Enum.UIMapType.Continent then 
		return mapId, info.mapType
	end 
	return self:GetFirstContinent(parent) 
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

local function slashcmd(msg)
	if (msg == "debug") then
		addon.debug = not addon.debug;
		WQT_QuestScrollFrame:UpdateQuestList();
		print("WQT: debug", addon.debug and "enabled" or "disabled");
		return;
	end
	
	print(_L["OPTIONS_INFO"]);
end

local function IsRelevantFilter(filterID, key)
	-- Check any filter outside of factions if disabled by worldmap filter
	if (filterID > 1) then return not WQT:FilterIsWorldMapDisabled(key) end
	-- Faction filters that are a string get a pass
	if (not key or type(key) == "string") then return true; end
	-- Factions with an ID of which the player faction is matching or neutral pass
	local data = WQT_Utils:GetFactionDataInternal(key);
	
	if (data and not data.playerFaction or data.playerFaction == _playerFaction) then return true; end
	
	return false;
end

local function InitFilter(self, level)

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
				WQT.settings.general.emissaryOnly = value;
				WQT_QuestScrollFrame:UpdateQuestList();
				if (WQT.settings.pin.filterPoI) then
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
				
				-- If we turn it off, remove the auto set as well
				if not value then
					WQT_WorldQuestFrame.autoEmisarryId = nil;
				end
			end
		info.checked = function() return WQT.settings.general.emissaryOnly end;
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
		
		info.hasArrow = false;
		local newText = WQT.settings.updateSeen and "" or "|TInterface\\FriendsFrame\\InformationIcon:14|t ";
		
		info.text = newText .. _L["WHATS_NEW"];
		info.tooltipTitle = _L["WHATS_NEW"];
		info.tooltipText =  _L["WHATS_NEW_TT"];
		
		info.func = function()
						local scrollFrame = WQTU_VersionFrame;
						local blockerText = scrollFrame.Text;
						
						blockerText:SetText(_V["LATEST_UPDATE"]);
						blockerText:SetHeight(blockerText:GetContentHeight());
						scrollFrame.limit = max(0, blockerText:GetHeight() - scrollFrame:GetHeight());
						scrollFrame.scrollBar:SetMinMaxValues(0, scrollFrame.limit)
						scrollFrame.scrollBar:SetValue(0);
						
						WQT.settings.updateSeen = true;
						
						WQT_WorldQuestFrame:ShowOverlayFrame(scrollFrame, 10, -18, -3, 3);
						
					end
		ADD:AddButton(info, level)
		
	elseif level == 2 then
		info.keepShownOnClick = true;
		info.hasArrow = false;
		info.isNotRadio = true;
		if ADD.MENU_VALUE then
			if ADD.MENU_VALUE == 1 then
			
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:UpdateQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:UpdateQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[ADD.MENU_VALUE].flags;
				local order = _filterOrders[ADD.MENU_VALUE] 
				local currExp = LE_EXPANSION_BATTLE_FOR_AZEROTH;
				for k, flagKey in pairs(order) do
					local factionInfo = type(flagKey) == "number" and WQT_Utils:GetFactionDataInternal(flagKey) or nil;
					-- factions that aren't a faction (other and no faction), are of current expansion, and are neutral of player faction
					if (not factionInfo or (factionInfo.expansion == currExp and (not factionInfo.playerFaction or factionInfo.playerFaction == _playerFaction))) then
						info.text = type(flagKey) == "number" and GetFactionInfoByID(flagKey) or flagKey;
						info.func = function(_, _, _, value)
											options[flagKey] = value;
											if (value) then
												WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
											end
											WQT_QuestScrollFrame:UpdateQuestList();
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
								WQT_QuestScrollFrame:UpdateQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(ADD.MENU_VALUE, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:UpdateQuestList();
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
										WQT_QuestScrollFrame:UpdateQuestList();
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
						WQT.settings.general.defaultTab = value;

					end
				info.checked = function() return WQT.settings.general.defaultTab end;
				ADD:AddButton(info, level);			

				info.text = _L["SAVE_SETTINGS"];
				info.tooltipTitle = _L["SAVE_SETTINGS"];
				info.tooltipText = _L["SAVE_SETTINGS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.general.saveFilters = value;
					end
				info.checked = function() return WQT.settings.general.saveFilters end;
				ADD:AddButton(info, level);	
				
				info.disabled = false;
				
				
				
				info.text = _L["LFG_BUTTONS"];
				info.tooltipTitle = _L["LFG_BUTTONS"];
				info.tooltipText = _L["LFG_BUTTONS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.general.useLFGButtons = value;
					end
				info.checked = function() return WQT.settings.general.useLFGButtons end;
				ADD:AddButton(info, level);		
				
				info.text = _L["AUTO_EMISARRY"];
				info.tooltipTitle = _L["AUTO_EMISARRY"];
				info.tooltipText = _L["AUTO_EMISARRY_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.general.autoEmisarry = value;
					end
				info.checked = function() return WQT.settings.general.autoEmisarry end;
				ADD:AddButton(info, level);		
				
				info.text = _L["QUEST_COUNTER"];
				info.tooltipTitle = _L["QUEST_COUNTER"];
				info.tooltipText = _L["QUEST_COUNTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.general.questCounter = value;
						WQT_QuestLogFiller:SetShown(value);
					end
				info.checked = function() return WQT.settings.general.questCounter end;
				ADD:AddButton(info, level);		
				
				info.text = _L["EMISSARY_COUNTER"];
				info.tooltipTitle = _L["EMISSARY_COUNTER"];
				info.tooltipText = _L["EMISSARY_COUNTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.general.bountyCounter = value;
						WQT_WorldQuestFrame:UpdateBountyCounters();
						WQT_WorldQuestFrame:RepositionBountyTabs();
					end
				info.checked = function() return WQT.settings.general.bountyCounter end;
				ADD:AddButton(info, level);	
				
				
				-- List Settings
				info.tooltipTitle = nil;
				info.tooltipText = nil;
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = _L["LIST_SETTINGS"];
				info.value = 302;
				info.func = nil;
				ADD:AddButton(info, level)
				
				-- Map Pin Settings
				info.text = _L["PIN_SETTINGS"];
				info.value = 303;
				ADD:AddButton(info, level)
				
				-- TomTom compatibility
				if TomTom then
					info.tooltipTitle = nil;
					info.tooltipText = nil;
					info.hasArrow = true;
					info.notCheckable = true;
					info.text = "TomTom";
					info.value = 304;
					info.func = nil;
					ADD:AddButton(info, level)
				end
				
				
				if (_utilitiesInstalled) then
					-- Utilities
					ADD:AddSeparator(level);
					
					local utilitiesEnabled = GetAddOnEnableState(_playerName, "WorldQuestTabUtilities");
					info.hasArrow = false;
					info.notCheckable = false;
					info.value = nil;
					info.disabled = utilitiesEnabled == 0;
					info.text = _L["LOAD_UTILITIES"];
					info.tooltipTitle = _L["LOAD_UTILITIES"];
					info.tooltipText = utilitiesEnabled == 0 and _L["LOAD_UTILITIES_TT_DISABLED"] or _L["LOAD_UTILITIES_TT"];
					info.func = function(_, _, _, value)
							WQT.settings.general.loadUtilities = value;
							if (value and not IsAddOnLoaded("WorldQuestTabUtilities")) then
								LoadAddOn("WorldQuestTabUtilities");
								WQT_QuestScrollFrame:UpdateQuestList();
								ADD:CloseDropDownMenus();
							end
						end
					info.checked = function() return WQT.settings.general.loadUtilities end;
					ADD:AddButton(info, level);	
				end
			end
		end
	elseif level == 3 then
		info.isNotRadio = true;
		info.notCheckable = false;
		if ADD.MENU_VALUE == 301 then -- Legion factions
			local options = WQT.settings.filters[1].flags;
			local order = _filterOrders[1] 
			local currExp = LE_EXPANSION_LEGION;
			for k, flagKey in pairs(order) do
				local data = type(flagKey) == "number" and WQT_Utils:GetFactionDataInternal(flagKey) or nil;
				if (data and data.expansion == currExp ) then
					info.text = type(flagKey) == "number" and data.name or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
										end
										WQT_QuestScrollFrame:UpdateQuestList();
									end
					info.checked = function() return options[flagKey] end;
					ADD:AddButton(info, level);			
				end
			end
		elseif ADD.MENU_VALUE == 302 then -- List settings
			info.tooltipWhileDisabled = true;
			info.tooltipOnButton = true;
			info.keepShownOnClick = true;	
			
			info.text = _L["SHOW_TYPE"];
			info.tooltipTitle = _L["SHOW_TYPE"];
			info.tooltipText = _L["SHOW_TYPE_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.typeIcon = value;
					WQT_QuestScrollFrame:DisplayQuestList(true);
				end
			info.checked = function() return WQT.settings.list.typeIcon end;
			ADD:AddButton(info, level);		
			
			info.text = _L["SHOW_FACTION"];
			info.tooltipTitle = _L["SHOW_FACTION"];
			info.tooltipText = _L["SHOW_FACTION_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.factionIcon = value;
					WQT_QuestScrollFrame:DisplayQuestList(true);
				end
			info.checked = function() return WQT.settings.list.factionIcon end;
			ADD:AddButton(info, level);		
			
			info.text = _L["SHOW_ZONE"];
			info.tooltipTitle = _L["SHOW_ZONE"];
			info.tooltipText = _L["SHOW_ZONE_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.showZone = value;
					WQT_QuestScrollFrame:DisplayQuestList(true);
				end
			info.checked = function() return WQT.settings.list.showZone end;
			ADD:AddButton(info, level);		

			info.text = _L["AMOUNT_COLORS"];
			info.tooltipTitle = _L["AMOUNT_COLORS"];
			info.tooltipText = _L["AMOUNT_COLORS_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.amountColors = value;
					WQT_QuestScrollFrame:DisplayQuestList(true);
				end
			info.checked = function() return WQT.settings.list.amountColors end;
			ADD:AddButton(info, level);		
			
			info.text = _L["LIST_FULL_TIME"];
			info.tooltipTitle = _L["LIST_FULL_TIME"];
			info.tooltipText = _L["LIST_FULL_TIME_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.fullTime = value;
					WQT_QuestScrollFrame:DisplayQuestList(true);
				end
			info.checked = function() return WQT.settings.list.fullTime end;
			ADD:AddButton(info, level);	
			
			info.keepShownOnClick = true;	
			info.text = _L["ALWAYS_ALL"];
			info.tooltipTitle = _L["ALWAYS_ALL"];
			info.tooltipText = _L["ALWAYS_ALL_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.list.alwaysAllQuests = value;
					local mapAreaID = WorldMapFrame.mapID;
					_dataProvider:LoadQuestsInZone(mapAreaID);
					ADD:Refresh(self);
					WQT_QuestScrollFrame:UpdateQuestList();
				end
			info.checked = function() return WQT.settings.list.alwaysAllQuests end;
			ADD:AddButton(info, level);		
			
		elseif ADD.MENU_VALUE == 303 then -- Map pins settings
			info.tooltipWhileDisabled = true;
			info.tooltipOnButton = true;
			info.keepShownOnClick = true;	
			info.text = _L["PIN_DISABLE"];
			info.tooltipTitle = _L["PIN_DISABLE"];
			info.tooltipText = _L["PIN_DISABLE_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.disablePoI = value;
					if (value) then
						-- Reset alpha on official pins
						local WQProvider = GetMapWQProvider();
						for _, PoI in pairs(WQProvider.activePins) do
							PoI.BountyRing:SetAlpha(1);
							PoI.TimeLowFrame:SetAlpha(1);
							PoI.TrackedCheck:SetAlpha(1);
							PoI.Texture:SetAlpha(1);
						end
						-- Bonus objectives and dailies
						if(WorldMapFrame.pinPools.BonusObjectivePinTemplate) then
							for mapPin in pairs(WorldMapFrame.pinPools.BonusObjectivePinTemplate.activeObjects) do
								mapPin.Texture:SetAlpha(1);
							end
						end
						
						WQT_WorldQuestFrame.pinHandler:ReleaseAllPools();
					end
					ADD:Refresh(self, 1, 3);
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(true)
				end
			info.checked = function() return WQT.settings.pin.disablePoI end;
			ADD:AddButton(info, level);
			
			info.disabled = function() return WQT.settings.pin.disablePoI end;
			
			info.text = _L["FILTER_PINS"];
			info.tooltipTitle = _L["FILTER_PINS"];
			info.tooltipText = _L["FILTER_PINS_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.filterPoI = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			info.checked = function() return WQT.settings.pin.filterPoI end;
			ADD:AddButton(info, level);
			
			info.text = _L["PIN_REWARDS"];
			info.tooltipTitle = _L["PIN_REWARDS"];
			info.tooltipText = _L["PIN_REWARDS_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.reward = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					ADD:Refresh(self, 1, 3);
				end
			info.checked = function() return WQT.settings.pin.reward end;
			ADD:AddButton(info, level);
			
			info.disabled = function() return WQT.settings.pin.disablePoI or not WQT.settings.pin.reward end;
			
			info.text = _L["PIN_TYPE"];
			info.tooltipTitle = _L["PIN_TYPE"];
			info.tooltipText = _L["PIN_TYPE_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.typeIcon = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			info.checked = function() return WQT.settings.pin.typeIcon end;
			ADD:AddButton(info, level);
			
			info.disabled = function() return WQT.settings.pin.disablePoI end;
			
			info.text = _L["PIN_REWARD_TYPE"];
			info.tooltipTitle = _L["PIN_REWARD_TYPE"];
			info.tooltipText = _L["PIN_REWARD_TYPE_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.rewardTypeIcon = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			info.checked = function() return WQT.settings.pin.rewardTypeIcon end;
			ADD:AddButton(info, level);
			
			info.text = _L["PIN_BIGGER"];
			info.tooltipTitle = _L["PIN_BIGGER"];
			info.tooltipText = _L["PIN_BIGGER_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.bigPoI = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			info.checked = function() return WQT.settings.pin.bigPoI end;
			ADD:AddButton(info, level);
			
			info.text = _L["PIN_TIME"];
			info.tooltipTitle = _L["PIN_TIME"];
			info.tooltipText = _L["PIN_TIME_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.pin.timeLabel  = value;
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			info.checked = function() return WQT.settings.pin.timeLabel  end;
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
			info.disabled = function() return WQT.settings.pin.disablePoI end;
			
			info.text = _L["PIN_RING_NONE"];
			info.tooltipTitle = _L["PIN_RING_NONE"];
			info.tooltipText = _L["PIN_RIMG_NONE_TT"];
			info.func = function()
					WQT.settings.pin.ringType = _V["RINGTYPE_NONE"];
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
					ADD:Refresh(self, 1, 3);
				end
			info.checked = function() return  WQT.settings.pin.ringType == _V["RINGTYPE_NONE"]; end;
			ADD:AddButton(info, level);
			
			info.text = _L["PIN_RING_COLOR"];
			info.tooltipTitle = _L["PIN_RING_COLOR"];
			info.tooltipText = _L["PIN_RING_COLOR_TT"];
			info.func = function()
					WQT.settings.pin.ringType = _V["RINGTYPE_REWARD"];
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
					ADD:Refresh(self, 1, 3);
				end
			info.checked = function() return WQT.settings.pin.ringType == _V["RINGTYPE_REWARD"]; end;
			ADD:AddButton(info, level);
			
			info.text = _L["PIN_RING_TIME"];
			info.tooltipTitle = _L["PIN_RING_TIME"];
			info.tooltipText = _L["PIN_RIMG_TIME_TT"];
			info.func = function()
					WQT.settings.pin.ringType = _V["RINGTYPE_TIME"];
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
					ADD:Refresh(self, 1, 3);
				end
			info.checked = function() return  WQT.settings.pin.ringType == _V["RINGTYPE_TIME"]; end;
			ADD:AddButton(info, level);
			
			info.disabled = nil;

		elseif ADD.MENU_VALUE == 304 then -- TomTom
			info.text = _L["USE_TOMTOM"];
			info.tooltipTitle = _L["USE_TOMTOM"];
			info.tooltipText = _L["USE_TOMTOM_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.general.useTomTom = value;
					WQT_QuestScrollFrame:UpdateQuestList();
					
					if value then
						ADD:EnableButton(3, 2);
					else 
						ADD:DisableButton(3, 2);
					end
				end
			info.checked = function() return WQT.settings.general.useTomTom end;
			ADD:AddButton(info, level);	
			
			info.disabled = not WQT.settings.general.useTomTom;
			info.text = _L["TOMTOM_AUTO_ARROW"];
			info.tooltipTitle = _L["TOMTOM_AUTO_ARROW"];
			info.tooltipText = _L["TOMTOM_AUTO_ARROW_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.general.TomTomAutoArrow = value;
					WQT_QuestScrollFrame:UpdateQuestList();
				end
			info.checked = function() return WQT.settings.general.TomTomAutoArrow end;
			ADD:AddButton(info, level);	
			
			info.disabled = not WQT.settings.general.useTomTom;
			info.text = _L["TOMTOM_CLICK_ARROW"];
			info.tooltipTitle = _L["TOMTOM_CLICK_ARROW"];
			info.tooltipText = _L["TOMTOM_CLICK_ARROW_TT"];
			info.func = function(_, _, _, value)
					WQT.settings.general.TomTomArrowOnClick = value;
					
					if (not value and WQT_WorldQuestFrame.softTomTomArrow and not IsWorldQuestHardWatched(WQT_WorldQuestFrame.softTomTomArrow)) then
						RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
					end

					WQT_QuestScrollFrame:UpdateQuestList();
				end
			info.checked = function() return WQT.settings.general.TomTomArrowOnClick end;
			ADD:AddButton(info, level);	
		end
	end
	
	WQT_WorldQuestFrame:TriggerEvent("InitFilter", self, level);
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

local function SortQuestList(a, b, sortID)
	if (not a.isValid or not b.isValid) then
		if (a.isValid == b.isValid) then return a.questId < b.questId; end;
		return a.isValid and not b.isValid;
	end
	
	if (not a.passedFilter or not b.passedFilter) then
		if (a.passedFilter == b.passedFilter) then return a.questId < b.questId; end;
		return a.passedFilter and not b.passedFilter;
	end

	local order = _V["SORT_OPTION_ORDER"][sortID];
	if (not order) then
		order = _emptyTable;
		WQT:debugPrint("No sort order for", sortID);
		return a.questId < b.questId;
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
	return a.questId < b.questId;
end

local function GetNewSettingData(old, default)
	return old == nil and default or old;
end

local function ConvertOldSettings(version)
	if (not version) then
		WQT.settings.filters[3].flags.Resources = nil;
		WQT.settings.versionCheck = "1";
	end
	-- BfA
	if (version < "8.0.1") then
		-- In 8.0.01 factions use ids rather than name
		local repFlags = WQT.settings.filters[1].flags;
		for name in pairs(repFlags) do
			if (type(name) == "string" and name ~=OTHER and name ~= _L["NO_FACTION"]) then
				repFlags[name] = nil;
			end
		end
	end
	-- Pin rework, turn off pin time by default
	if (version < "8.2.01")  then
		WQT.settings.showPinTime = false;
	end
	-- Reworked save structure
	if (version < "8.2.02")  then
		WQT.settings.general.defaultTab =		GetNewSettingData(WQT.settings.defaultTab, false);
		WQT.settings.general.saveFilters = 		GetNewSettingData(WQT.settings.saveFilters, true);
		WQT.settings.general.emissaryOnly = 		GetNewSettingData(WQT.settings.emissaryOnly, false);
		WQT.settings.general.useLFGButtons = 	GetNewSettingData(WQT.settings.useLFGButtons, false);
		WQT.settings.general.autoEmisarry = 		GetNewSettingData(WQT.settings.autoEmisarry, true);
		WQT.settings.general.questCounter = 		GetNewSettingData(WQT.settings.questCounter, true);
		WQT.settings.general.bountyCounter = 	GetNewSettingData(WQT.settings.bountyCounter, true);
		WQT.settings.general.useTomTom = 		GetNewSettingData(WQT.settings.useTomTom, true);
		WQT.settings.general.TomTomAutoArrow = 	GetNewSettingData(WQT.settings.TomTomAutoArrow, true);
		
		WQT.settings.list.typeIcon = 			GetNewSettingData(WQT.settings.showTypeIcon, true);
		WQT.settings.list.factionIcon = 			GetNewSettingData(WQT.settings.showFactionIcon, true);
		WQT.settings.list.zone = 				GetNewSettingData(WQT.settings.listShowZone, true);
		WQT.settings.list.amountColors = 		GetNewSettingData(WQT.settings.rewardAmountColors, true);
		WQT.settings.list.alwaysAllQuests =		GetNewSettingData(WQT.settings.alwaysAllQuests, false);
		WQT.settings.list.fullTime = 			GetNewSettingData(WQT.settings.listFullTime, false);

		WQT.settings.pin.typeIcon =				GetNewSettingData(WQT.settings.pinType, true);
		WQT.settings.pin.rewardTypeIcon =		GetNewSettingData(WQT.settings.pinRewardType, false);
		WQT.settings.pin.filterPoI =				GetNewSettingData(WQT.settings.filterPoI, true);
		WQT.settings.pin.bigPoI =				GetNewSettingData(WQT.settings.bigPoI, false);
		WQT.settings.pin.disablePoI =			GetNewSettingData(WQT.settings.disablePoI, false);
		WQT.settings.pin.reward =				GetNewSettingData(WQT.settings.showPinReward, true);
		WQT.settings.pin.timeLabel =				GetNewSettingData(WQT.settings.showPinTime, false);
		WQT.settings.pin.ringType =				GetNewSettingData(WQT.settings.ringType, _V["RINGTYPE_TIME"]);
		
		-- Clean up old data
		local version = WQT.settings.versionCheck;
		local sortBy = WQT.settings.sortBy;
		local updateSeen = WQT.settings.updateSeen;
		
		for k, v in pairs(WQT.settings) do
			if (type(v) ~= "table") then
				WQT.settings[k] = nil;
			end
		end
		
		WQT.settings.versionCheck = version;
		WQT.settings.sortBy = sortBy;
		WQT.settings.updateSeen = updateSeen;
		
		-- New filters
		for flagId in pairs(WQT.settings.filters) do
			WQT:SetAllFilterTo(flagId, true);
		end
	end
	-- Hightlight 'what's new'
	if (version < GetAddOnMetadata(addonName, "version")) then
		WQT.settings.updateSeen = false;
	end
end

function WQT:UpdateFilterIndicator() 
	if (InCombatLockdown()) then return; end
	if (C_CVar.GetCVarBool("showTamers") and C_CVar.GetCVarBool("worldQuestFilterArtifactPower") and C_CVar.GetCVarBool("worldQuestFilterResources") and C_CVar.GetCVarBool("worldQuestFilterGold") and C_CVar.GetCVarBool("worldQuestFilterEquipment")) then
		WQT_WorldQuestFrame.FilterButton.Indicator:Hide();
	else
		WQT_WorldQuestFrame.FilterButton.Indicator:Show();
	end
end

function WQT:SetAllFilterTo(id, value)
	local filter = WQT.settings.filters[id];
	if (not filter) then return end;
	local flags = filter.flags;
	for k, v in pairs(flags) do
		flags[k] = value;
	end
end

function WQT:FilterIsWorldMapDisabled(filter)
	if (filter == "Petbattle" and not C_CVar.GetCVarBool("showTamers")) or (filter == "Artifact" and not C_CVar.GetCVarBool("worldQuestFilterArtifactPower")) or (filter == "Currency" and not C_CVar.GetCVarBool("worldQuestFilterResources"))
		or (filter == "Gold" and not C_CVar.GetCVarBool("worldQuestFilterGold")) or (filter == "Armor" and not C_CVar.GetCVarBool("worldQuestFilterEquipment")) then
		
		return true;
	end

	return false;
end

function WQT:InitSort(self, level)

	local selectedValue = ADD:GetSelectedValue(self);
	local info = ADD:CreateInfo();
	local buttonsAdded = 0;
	info.func = function(self, category) WQT:Sort_OnClick(self, category) end
	
	for k, option in pairs(_V["WQT_SORT_OPTIONS"]) do
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
		WQT_WorldQuestFrame:TriggerEvent("SortChanged", category);
	end
end

function WQT:InitTrackDropDown(self, level)

	if not self:GetParent() or not self:GetParent().info then return; end
	local questInfo = self:GetParent().info;
	local questId = questInfo.questId;
	local mapInfo = WQT_Utils:GetMapInfoForQuest(questInfo.questId);
	local info = ADD:CreateInfo();
	local _, _, worldQuestType = GetQuestTagInfo(questId);
	info.notCheckable = true;	
	
	-- Title
	local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
	info.text = title;
	info.isTitle = true;
	ADD:AddButton(info, level);
	
	info.isTitle = false;
	
	-- TomTom functionality
	if (TomTom and WQT.settings.general.useTomTom) then
	
		if (TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			-- All required functions are found
			if ( not TomTom:WaypointExists(mapInfo.mapID, questInfo.mapInfo.mapX, questInfo.mapInfo.mapY, title)) then
				info.text = _L["TRACKDD_TOMTOM"];
				info.func = function()
					AddTomTomArrowByQuestId(questId);
				end
			else
				info.text = _L["TRACKDD_TOMTOM_REMOVE"];
				info.func = function()
					RemoveTomTomArrowbyQuestId(questId);
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
	
	-- Don't allow tracking for quests that don't support it in the ObjectiveTrackerFrame
	if (worldQuestType) then
		-- Tracking
		if (QuestIsWatched(questId)) then
			info.text = UNTRACK_QUEST;
			info.func = function()
						RemoveWorldQuestWatch(questId);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_QuestScrollFrame:DisplayQuestList();
						end
					end
		else
			info.text = TRACK_QUEST;
			info.func = function()
						AddWorldQuestWatch(questId, true);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_QuestScrollFrame:DisplayQuestList();
						end
					end
		end	
		ADD:AddButton(info, level)
	end
	
	-- LFG if possible
	if (WQT_WorldQuestFrame:ShouldAllowLFG(questInfo)) then
		info.text = OBJECTIVES_FIND_GROUP;
		info.func = function()
			WQT_WorldQuestFrame:SearchGroup(questInfo);
		end
		ADD:AddButton(info, level);
	end
	
	info.text = CANCEL;
	info.func = nil;
	ADD:AddButton(info, level)
end

function WQT:IsWorldMapFiltering()
	for k, cVar in pairs(_V["WQT_CVAR_LIST"]) do
		if not C_CVar.GetCVarBool(cVar) then
			return true;
		end
	end
	return false;
end

function WQT:IsFiltering()
	if WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId then return true; end
	for k, category in pairs(WQT.settings.filters)do
		for k2, flag in pairs(category.flags) do
			if not flag and IsRelevantFilter(k, k2) then 
				return true;
			end
		end
	end
	return false;
end

function WQT:IsUsingFilterNr(id)
	if not WQT.settings.filters[id] then return false end
	local flags = WQT.settings.filters[id].flags;
	for k, flag in pairs(flags) do
		if (not flag) then return true; end
	end
	return false;
end

function WQT:PassesMapFilter(questInfo)
	if (WQT.settings.list.alwaysAllQuests) then return true; end
	local mapID = WorldMapFrame.mapID;
	if (FlightMapFrame and FlightMapFrame:IsShown()) then
		mapID = GetTaxiMapID();
	else
		if (_dataProvider.currentMapInfo and _dataProvider.currentMapInfo.mapType == Enum.UIMapType.World) then return true; end
	end
	local questZone = C_TaskQuest.GetQuestZoneID(questInfo.questId)
	if (mapID == questZone) then return true; end
	
	if (_V["WQT_ZONE_MAPCOORDS"][mapID] and _V["WQT_ZONE_MAPCOORDS"][mapID][questZone]) then return true; end
end

function WQT:PassesAllFilters(questInfo)
	--if not self:PassesMapFilter(questInfo) then return false; end
	
	if WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId then 
		return WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	end
	
	if WQT:IsUsingFilterNr(1) and not WQT:PassesFactionFilter(questInfo) then return false; end
	if WQT:IsUsingFilterNr(2) and not WQT:PassesFlagId(2, questInfo) then return false; end
	if WQT:IsUsingFilterNr(3) and not WQT:PassesFlagId(3, questInfo) then return false; end
	
	return  true;
end

function WQT:PassesFactionFilter(questInfo)
	-- Factions (1)
	local flags = WQT.settings.filters[1].flags
	-- no faction
	local _, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	if not factionId then return flags[_L["NO_FACTION"]]; end
	
	if flags[factionId] ~= nil then 
		-- specific faction
		return flags[factionId];
	else
		-- other faction
		return flags[OTHER];
	end

	return false;
end

function WQT:PassesFlagId(flagId ,questInfo)
	local flags = WQT.settings.filters[flagId].flags
	if not flags then return false; end
	local _, _, worldQuestType = GetQuestTagInfo(questInfo.questId);
	
	for flag, filterEnabled in pairs(flags) do
		if (filterEnabled) then
			local func = _V["FILTER_FUNCTIONS"][flagId] and _V["FILTER_FUNCTIONS"][flagId][flag] ;
			if(func and func(questInfo, worldQuestType)) then 
				return true;
			end
		end
	end
	return false;
end

function WQT:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("BWQDB", WQT_DEFAULTS, true);
	self.settings = self.db.global;
	
	ConvertOldSettings(WQT.settings.versionCheck)
	WQT.settings.versionCheck  = GetAddOnMetadata(addonName, "version");
end

function WQT:OnEnable()
	WQT_TabNormal.Highlight:Show();
	WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	if (WQT.settings.general.loadUtilities and GetAddOnEnableState(_playerName, "WorldQuestTabUtilities") > 0 and not IsAddOnLoaded("WorldQuestTabUtilities")) then
		LoadAddOn("WorldQuestTabUtilities");
	end
	
	if (WQT.settings.fullScreenButtonPos.x >= 0) then
		WQT_WorldMapContainerButton:SetStartPosition("BOTTOMLEFT", WQT.settings.fullScreenButtonPos.x, WQT.settings.fullScreenButtonPos.y);
	end
	
	if (not self.settings.general.saveFilters) then
		for k in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, false);
		end
	end

	if self.settings.general.saveFilters and _V["WQT_SORT_OPTIONS"][self.settings.sortBy] then
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
	WQT_WorldQuestFrame:SelectTab((UnitLevel("player") >= 110 and self.settings.general.defaultTab) and WQT_TabWorld or WQT_TabNormal);
	WQT_WorldQuestFrame.tabBeforeAnchor = WQT_WorldQuestFrame.selectedTab;
	
	-- Show quest log counter
	WQT_QuestLogFiller:SetShown(self.settings.general.questCounter);
	
	-- Add LFG buttons to objective tracker
	if self.settings.general.useLFGButtons then
		WQT_WorldQuestFrame.LFGButtonPool = CreateFramePool("BUTTON", nil, "WQT_LFGEyeButtonTemplate");
	
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
	
	-- Load externals
	for k, func in ipairs(addon.externals) do
		local name, success = func();
		WQT:debugPrint("WQT external", name, success and "Success" or "Failed");
	end
end

------------------------------------------
-- 			LISTBUTTON MIXIN			--
------------------------------------------
--
-- OnClick(button)
-- SetEnabledMixin(value)	Custom version of 'disable' for the sake of combat
-- OnUpdate()
-- OnLeave()
-- OnEnter()
-- UpdateQuestType(questInfo)
-- Update(questInfo, shouldShowZone)
-- ShowWorldmapHighlight(questId)
-- FactionOnEnter(frame)

WQT_ListButtonMixin = {}

function WQT_ListButtonMixin:OnClick(button)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if not self.questId or self.questId== -1 then return end
	local _, _, worldQuestType = GetQuestTagInfo(self.questId);

	if IsModifiedClick("QUESTWATCHTOGGLE") then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (worldQuestType ~= _V["WQT_TYPE_BONUSOBJECTIVE"]) then
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
		if (worldQuestType ~= _V["WQT_TYPE_BONUSOBJECTIVE"]) then
			local hardWatched = IsWorldQuestHardWatched(self.questId);
			AddWorldQuestWatch(self.questId);
			-- if it was hard watched, keep it that way
			if hardWatched then
				AddWorldQuestWatch(self.questId, true);
			end
		end
		if (WorldMapFrame:IsShown()) then
			WorldMapFrame:SetMapID(self.zoneId);
		end
		
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

function WQT_ListButtonMixin:SetEnabledMixin(value)
	value = value==nil and true or value;
	self:SetEnabled(value);
	self:EnableMouse(value);
	self.Faction:EnableMouse(value);
end

function WQT_ListButtonMixin:OnUpdate()
	if (not self.info or not self:IsShown() or self.info.seconds == 0) then return; end
	local _, timeString, color, _ = WQT_Utils:GetQuestTimeString(self.info, WQT.settings.list.fullTime);
	self.Time:SetTextColor(color.r, color.g, color.b, 1);
	self.Time:SetText(timeString);
end

function WQT_ListButtonMixin:OnLeave()
	self.Highlight:Hide();
	GameTooltip:Hide();
	GameTooltip.ItemTooltip:Hide();

	WQT_WorldQuestFrame.pinHandler:HideHighlightOnPinForQuestId(self.info.questId);
	
	if (FlightMapFrame and FlightMapFrame:IsShown() and self.flightPin) then
		local keepVisible = FlightMapFrame.ScrollContainer.targetScale  > 0.5;
		keepVisible = keepVisible or GetSuperTrackedQuestID() == self.questId or IsWorldQuestWatched(self.questId);
		self.flightPin:SetAlpha(keepVisible and 1 or 0);
		self.flightPin = nil;
	else
		WQT_WorldQuestFrame:HideWorldmapHighlight();
	end
	
end

function WQT_ListButtonMixin:OnEnter()
	self.Highlight:Show();
	
	local questInfo = self.info;

	WQT_WorldQuestFrame.pinHandler:ShowHighlightOnPinForQuestId(questInfo.questId);
	
	WQT_QuestScrollFrame:ShowQuestTooltip(self, questInfo);
	
	if (not FlightMapFrame or not FlightMapFrame:IsShown() or _WFMLoaded) then
		WQT_WorldQuestFrame:ShowWorldmapHighlight(questInfo.questId);
	end
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)
	local frame = self.Type;
	local isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	local _, _, questType, rarity, isElite = GetQuestTagInfo(questInfo.questId);

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
	local atlasTexture, sizeX, sizeY, hideBG = WQT_Utils:GetCachedTypeIconData(questInfo);

	frame.Texture:SetAtlas(atlasTexture);
	frame.Texture:SetSize(sizeX, sizeY);
	frame.Bg:SetAlpha(hideBG and 0 or 1);
	
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
	if (self.info ~= questInfo) then
		self.Reward.Amount:Hide();
		self.TrackedBorder:Hide();
		self.Highlight:Hide();
		self:Hide();
	end

	self:Show();
	self.info = questInfo;
	self.zoneId = C_TaskQuest.GetQuestZoneID(questInfo.questId);
	self.questId = questInfo.questId;
	
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	if (not questInfo.isValid) then
		title = "|cFFFF0000(Invalid) " .. title;
	elseif (not questInfo.passedFilter) then
		title = "|cFF999999(Filtered) " .. title;
	end
	
	self.Title:SetText(title);

	local extraSpace = WQT.settings.list.factionIcon and 0 or 14;
	extraSpace = extraSpace + (WQT.settings.list.typeIcon and 0 or 14);
	local timeWidth = extraSpace + (WQT.settings.list.fullTime and 70 or 60);
	local zoneWidth = extraSpace + (WQT.settings.list.fullTime and 80 or 90);
	if (not shouldShowZone) then
		timeWidth = timeWidth + zoneWidth;
		zoneWidth = 0.1;
	end
	self.Time:SetWidth(timeWidth)
	self.Extra:SetWidth(zoneWidth)
	
	local zoneName = "";
	if (shouldShowZone) then
		local mapInfo = WQT_Utils:GetMapInfoForQuest(questInfo.questId);
		zoneName = mapInfo.name;
	end
	
	self.Extra:SetText(zoneName);
	
	if (self:IsMouseOver() or self.Faction:IsMouseOver() or (WQT_QuestScrollFrame.PoIHoverId and WQT_QuestScrollFrame.PoIHoverId > 0 and WQT_QuestScrollFrame.PoIHoverId == questInfo.questId)) then
		self.Highlight:Show();
	else
		self.Highlight:Hide();
	end
			
	self.Title:ClearAllPoints()
	self.Title:SetPoint("RIGHT", self.Reward, "LEFT", -5, 0);
	
	if (WQT.settings.list.factionIcon) then
		self.Title:SetPoint("BOTTOMLEFT", self.Faction, "RIGHT", 5, 1);
	elseif (WQT.settings.list.typeIcon) then
		self.Title:SetPoint("BOTTOMLEFT", self.Type, "RIGHT", 5, 1);
	else
		self.Title:SetPoint("BOTTOMLEFT", self, "LEFT", 10, 0);
	end
	
	if (WQT.settings.list.factionIcon) then
		self.Faction:Show();
		local factionData = WQT_Utils:GetFactionDataInternal(factionId);

		self.Faction.Icon:SetTexture(factionData.texture);
		self.Faction:SetWidth(self.Faction:GetHeight());
	else
		self.Faction:Hide();
		self.Faction:SetWidth(0.1);
	end
	
	if (WQT.settings.list.typeIcon) then
		self:UpdateQuestType(questInfo)
	else
		self.Type:Hide()
		self.Type:SetWidth(0.1);
	end
	
	-- display reward
	self.Reward:Show();
	self.Reward.Icon:Show();
	
	if (questInfo.reward.typeBits == WQT_REWARDTYPE.missing) then
		self.Reward.IconBorder:SetVertexColor(.75, 0, 0);
		self.Reward:SetAlpha(1);
		self.Reward.Icon:SetColorTexture(0, 0, 0, 0.5);
		self.Reward.Amount:Hide();
	elseif (questInfo.reward.typeBits == WQT_REWARDTYPE.none) then
		self.Reward:SetAlpha(0);
	else
		local r, g, b = GetItemQualityColor(questInfo.reward.quality);
		self.Reward.IconBorder:SetVertexColor(r, g, b);
		self.Reward:SetAlpha(1);
		if questInfo.reward.texture == "" then
			self.Reward:SetAlpha(0);
		end
		self.Reward.Icon:SetTexture(questInfo.reward.texture);
	
		if (questInfo.reward.amount and questInfo.reward.amount > 1)  then
			if (questInfo.reward.type == WQT_REWARDTYPE.relic) then
				self.Reward.Amount:SetText("+" .. questInfo.reward.amount);
			elseif (questInfo.reward.type == WQT_REWARDTYPE.equipment) then
				if (questInfo.reward.canUpgrade) then
					self.Reward.Amount:SetText(questInfo.reward.amount.."+");
				else 
					self.Reward.Amount:SetText(questInfo.reward.amount);
				end
			else
				local rewardAmount = questInfo.reward.amount;
				if (C_PvP.IsWarModeDesired() and _V["WARMODE_BONUS_REWARD_TYPES"][questInfo.reward.type] and C_QuestLog.QuestHasWarModeBonus(questInfo.questId) ) then
					rewardAmount = rewardAmount + floor(rewardAmount * C_PvP.GetWarModeRewardBonus() / 100);
				end
				self.Reward.Amount:SetText(GetLocalizedAbreviatedNumber(rewardAmount));
			end
			
			r, g, b = 1, 1, 1;
			if ( WQT.settings.list.amountColors) then
				if (questInfo.reward.type == WQT_REWARDTYPE.artifact) then
					r, g, b = GetItemQualityColor(2);
				elseif (questInfo.reward.type == WQT_REWARDTYPE.equipment or questInfo.reward.type == WQT_REWARDTYPE.weapon) then
					if (questInfo.reward.canUpgrade) then
						self.Reward.Amount:SetText(questInfo.reward.amount.."+");
					end
					r, g, b = questInfo.reward.color:GetRGB();
				end
			end
	
			self.Reward.Amount:SetVertexColor(r, g, b);
			self.Reward.Amount:Show();
		else
			self.Reward.Amount:Hide();
		end
	end
	
	if (GetSuperTrackedQuestID() == questInfo.questId or IsWorldQuestWatched(questInfo.questId)) then
		self.TrackedBorder:Show();
		self.TrackedBorder:SetAlpha(IsWorldQuestHardWatched(questInfo.questId) and 0.6 or 1);
	else
		self.TrackedBorder:Hide();
	end

	WQT_WorldQuestFrame:TriggerEvent("ListButtonUpdate", self)
end

function WQT_ListButtonMixin:FactionOnEnter(frame)
	self.Highlight:Show();
	local _, factionId = C_TaskQuest.GetQuestInfoByQuestID(self.info.questId);
	if (factionId) then
		local factionInfo = WQT_Utils:GetFactionDataInternal(factionId)
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT", -5, -10);
		GameTooltip:SetText(factionInfo.name, nil, nil, nil, nil, true);
	end
end

------------------------------------------
-- 			PInHANDLER MIXIN			--
------------------------------------------
-- 
-- OnLoad()
-- KeepHightlightedOnTop()
-- ReleaseAllPools()
-- UpdateFlightMapPins()
-- UpdateMapPoI()
-- ShowHighlightOnPinForQuestId(questId)
-- HideHighlightOnPinForQuestId(questId)
-- 

WQT_PinHandlerMixin = {};

local function OnPinRelease(pool, pin)
	pin.questID = nil;
	pin:Hide();
	pin:ClearAllPoints();
end

function WQT_PinHandlerMixin:OnLoad()
	self.pinPool = CreateFramePool("COOLDOWN", nil, "WQT_PinTemplate", OnPinRelease);
	self.pinPoolFlightMap = CreateFramePool("COOLDOWN", nil, "WQT_PinTemplate", OnPinRelease);
	self.pinHighlightPool = CreateFramePool("FRAME", nil, "WQT_PoISelectTemplate");
	self.questHighlights = {};
end

function WQT_PinHandlerMixin:KeepHightlightedOnTop()
	for highlight in self.pinHighlightPool:EnumerateActive() do
		if (highlight.pin.owningMap == WorldMapFrame) then
			 highlight.pin:SetFrameLevel(3000);
		end
	end
end

function WQT_PinHandlerMixin:ReleaseAllPools()
	self.pinPool:ReleaseAll();
	self.pinPoolFlightMap:ReleaseAll();
end

function WQT_PinHandlerMixin:UpdateFlightMapPins()
	if (not FlightMapFrame:IsShown() or WQT.settings.pin.disablePoI or not WQT.FlightmapPins) then return; end
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
	
	if (WQT.settings.pin.disablePoI) then return; end
	local WQProvider = GetMapWQProvider();

	local questInfo;
	for qID, PoI in pairs(WQProvider.activePins) do
		questInfo = _dataProvider:GetQuestById(qID);
		if (questInfo and questInfo.isValid) then
			local pin = self.pinPool:Acquire();
			pin.info = questInfo;
			pin.questID = qID;
			pin:Update(PoI, questInfo);
			PoI:SetShown(true);
			if (WQT.settings.pin.filterPoI) then
				PoI:SetShown(questInfo.passedFilter);
			end
		end
	end
	if(WorldMapFrame.pinPools.BonusObjectivePinTemplate) then
		for mapPin in pairs(WorldMapFrame.pinPools.BonusObjectivePinTemplate.activeObjects) do
			questInfo = _dataProvider:GetQuestById(mapPin.questID );
			if (questInfo and questInfo.isValid) then
				local pin = self.pinPool:Acquire();
				pin.info = questInfo;
				pin.questID = qID;
				pin:Update(mapPin, questInfo, nil, true);
				mapPin:SetShown(true);
				if (WQT.settings.pin.filterPoI) then
					mapPin:SetShown(questInfo.passedFilter);
				end
			end
		end
	end
end

function  WQT_PinHandlerMixin:ShowHighlightOnPinForQuestId(questId)
	local pin = WQT:GetMapPinForWorldQuest(questId);
	local scale = 1;
	
	if (FlightMapFrame and FlightMapFrame:IsShown() and not _WFMLoaded) then
		pin =  WQT:GetFlightMapPin(questId)
		if(pin) then
			pin:SetAlpha(1);
			pin:Show();
		end
	end
	
	if not pin then
		pin = WQT:GetMapPinForBonusObjective(questId);
		
		local questInfo = _dataProvider:GetQuestById(questId);
		if (questInfo and questInfo.isDaily) then
			scale = 0.45;
		else
			scale = 0.5;
		end
	end
	 
	if (pin) then
		local existingHighlight = self.questHighlights[questId];
		if (existingHighlight) then
			-- If it's the same pin, keep everything as is
			if (existingHighlight.pin == pin) then 
				return;
			end
			-- Otherwise, hide the old one
			self:HideHighlightOnPinForQuestId(questId);
		end

		local highlight;
		for obj in self.pinHighlightPool:EnumerateActive() do
			if (obj.pin == pin) then 
				highlight = obj;
				break;
			end
		end

		highlight = highlight or self.pinHighlightPool:Acquire();
		
		selector = selector or WQT_PoISelectIndicator;
		highlight:SetParent(pin);
		highlight:ClearAllPoints();
		highlight:SetPoint("CENTER", pin, 0, -1);
		highlight:SetFrameLevel(pin:GetFrameLevel()+1);
		highlight.pinLevel = pin:GetFrameLevel();
		highlight.pin = pin;
		highlight:Show();
		local size = WQT.settings.pin.bigPoI and 55 or 45;
		highlight:SetSize(size, size);
		highlight:SetScale(scale);
		if (pin.owningMap == FlightMapFrame) then
			pin:SetFrameLevel(3000);
		end
		
		self.questHighlights[questId] = highlight;
	end
end

function  WQT_PinHandlerMixin:HideHighlightOnPinForQuestId(questId)

	local highlight = self.questHighlights[questId]; 
	
	if (not highlight) then 
		return;
	end
	
	local pin = highlight.pin;

	-- We have to check on name because in WorldFlightMap WorldMapFrame == FlightMapFrame
	if (FlightMapFrame and pin.owningMap and pin.owningMap:GetName() == "FlightMapFrame") then
		local keepVisible = FlightMapFrame.ScrollContainer.targetScale  > 0.5;
		keepVisible = keepVisible or GetSuperTrackedQuestID() == questId or IsWorldQuestWatched(questId);
		pin:SetAlpha(keepVisible and 1 or 0);
	end

	if (highlight.pin) then
		highlight.pin:SetFrameLevel(highlight.pinLevel);
		highlight.pin = nil;
	end
	self.pinHighlightPool:Release(highlight);
	
	self.questHighlights[questId] = nil;
end

------------------------------------------
-- 				Pin MIXIN				--
------------------------------------------
--
-- OnUpdate()
-- Update(PoI, questInfo, flightPinNr)

WQT_PinMixin = {};

function WQT_PinMixin:OnUpdate()
	if (not self.info or (self.info and self.info.time.seconds <= 0)) then return end;

	local start, total, timeLeft, seconds, color, timeStringShort = WQT_Utils:GetPinTime(self.info);
	if (WQT.settings.pin.ringType ==  _V["RINGTYPE_TIME"] and seconds > 0) then
		local r, g, b = color:GetRGB();
		self.Pointer:SetRotation((timeLeft)/(total)*6.2831);
		self:SetCooldownUNIX(time()-start,  start + timeLeft);
		self.Pointer:SetAlpha(1);
		self.Pointer:SetVertexColor(r*1.1, g*1.1, b*1.1);
		self.Ring:SetVertexColor(r*0.25, g*0.25, b*0.25);
		self:SetSwipeColor(r*.8, g*.8, b*.8);
	end
	
	if(WQT.settings.pin.timeLabel ) then
		self.Time:SetText(timeStringShort)
		self.Time:SetVertexColor(color.r, color.g, color.b) 
	end
end

function WQT_PinMixin:Update(PoI, questInfo, flightPinNr, isBonus)
	self:SetParent(PoI);
	self:SetFrameLevel(PoI:GetFrameLevel()+2);
	self:SetAllPoints();
	
	local scale = 1;
	local margin = WQT.settings.pin.bigPoI and 10 or 5;
	local iconDistance =  WQT.settings.pin.bigPoI and 34 or 30;
	local seconds, _, color, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo);
	local _, _, worldQuestType = GetQuestTagInfo(questInfo.questId);
	
	if(isBonus) then
		if (questInfo.isDaily) then
			-- Daily quests
			margin = WQT.settings.pin.bigPoI and 0 or -5;
			scale = 0.45;
		else
			-- Actual bonus objectives
			margin = WQT.settings.pin.bigPoI and 6 or 1;
			scale = 0.55;
		end
	end
	
	self:SetPoint("TOPLEFT", -margin, margin);
	self:SetPoint("BOTTOMRIGHT", margin, -margin);
	self:SetScale(scale);
	self:Show();
	
	PoI.Texture:SetAlpha(0);
	
	if not flightPinNr then
		PoI.info = questInfo;
	end
	
	if (PoI.BountyRing) then
		PoI.BountyRing:SetAlpha(0);
		PoI.TimeLowFrame:SetAlpha(0);
		PoI.TrackedCheck:SetAlpha(0);
	end

	self.TrackedCheck:SetAlpha(IsWorldQuestWatched(questInfo.questId) and 1 or 0);
	
	-- Ring stuff
	local ringType = WQT.settings.pin.ringType;
	local hideRing = ringType ==  _V["RINGTYPE_NONE"] and not WQT.settings.pin.reward;
	local now = hideRing and 0 or time();
	local r, g, b = _V["WQT_COLOR_CURRENCY"]:GetRGB();
	self.Ring:SetAlpha(hideRing and 0 or 1);
	self:SetCooldownUNIX(now, now);
	self.Pointer:SetAlpha(0);
	
	if (ringType ==  _V["RINGTYPE_TIME"]) then
		r, g, b = color:GetRGB();
		if (seconds > 0) then
			local start, total, timeLeft = WQT_Utils:GetPinTime(questInfo);
		
			self:SetCooldownUNIX(now-start,  start + timeLeft);
			self.Pointer:SetAlpha(1);
			self.Pointer:SetVertexColor(r*1.1, g*1.1, b*1.1);
			self.Pointer:SetRotation((timeLeft)/(total)*6.2831);
		end
	elseif (ringType ==  _V["RINGTYPE_REWARD"]) then
		r, g, b = questInfo.reward.color:GetRGB();
	end
	
	self.Ring:SetVertexColor(r*0.25, g*0.25, b*0.25);
	self:SetSwipeColor(r*.8, g*.8, b*.8);
	local showTypeIcon = WQT.settings.pin.reward and WQT.settings.pin.typeIcon and (isBonus or (worldQuestType > 0 and worldQuestType ~= LE_QUEST_TAG_TYPE_NORMAL));
	local showRewardIcon = WQT.settings.pin.rewardTypeIcon;
	
	-- Quest Type Icon
	local typeAtlas =  showTypeIcon and WQT_Utils:GetCachedTypeIconData(questInfo);
	self.TypeIcon:SetAlpha(typeAtlas and 1 or 0);
	self.TypeBG:SetAlpha(typeAtlas and 1 or 0);
	if (typeAtlas) then
		local typeSize = WQT.settings.pin.bigPoI and 32 or 26;
		local angle = 270 + (showRewardIcon and 30 or 0)
		local posX = iconDistance * cos(angle);
		local posY = iconDistance * sin(angle);
		self.TypeBG:SetSize(typeSize+11, typeSize+11);
		typeSize = typeSize * (worldQuestType == LE_QUEST_TAG_TYPE_PVP and 0.8 or 1)
		self.TypeIcon:SetSize(typeSize, typeSize);
		self.TypeIcon:SetAtlas(typeAtlas);
		self.TypeIcon:SetPoint("CENTER", posX, posY);
	end
	
	-- Reward Type Icon
	local rewardTypeAtlas =  showRewardIcon and _V["REWARD_TYPE_ATLAS"][questInfo.reward.type];
	self.RewardIcon:SetAlpha(rewardTypeAtlas and 1 or 0);
	self.RewardBG:SetAlpha(rewardTypeAtlas and 1 or 0);
	if (rewardTypeAtlas) then
		local typeSize = WQT.settings.pin.bigPoI and 32 or 26;
		local angle = 270 - (showTypeIcon and 30 or 0)
		local posX = iconDistance * cos(angle);
		local posY = iconDistance * sin(angle);
		self.RewardBG:SetSize(typeSize+11, typeSize+11);
		typeSize = typeSize * rewardTypeAtlas.scale;
		self.RewardIcon:SetSize(typeSize, typeSize);
		if (rewardTypeAtlas.r) then
			self.RewardIcon:SetTexture(rewardTypeAtlas.texture);
			self.RewardIcon:SetTexCoord(rewardTypeAtlas.l, rewardTypeAtlas.r, rewardTypeAtlas.t, rewardTypeAtlas.b);
		else
			self.RewardIcon:SetAtlas(rewardTypeAtlas.texture);
			self.RewardIcon:SetTexCoord(0, 1, 0, 1);
		end
		if (rewardTypeAtlas.color) then
			self.RewardIcon:SetVertexColor(rewardTypeAtlas.color:GetRGB());
		else
			self.RewardIcon:SetVertexColor(1, 1, 1);
		end
		
		self.RewardIcon:SetPoint("CENTER", posX, posY);
	end

	-- Icon stuff
	local showIcon = WQT.settings.pin.reward and (questInfo.reward.type == WQT_REWARDTYPE.missing or questInfo.reward.texture ~= "")
	self.Icon:SetAlpha(showIcon and 1 or 0);
	self.Icon:SetTexture(questInfo.reward.texture or "Interface/PETBATTLES/BattleBar-AbilityBadge-Neutral");

	-- Time
	local timeDistance = (showTypeIcon or showRewardIcon) and 0 or 5; 
	self.Time:SetAlpha((WQT.settings.pin.timeLabel  and timeStringShort ~= "")and 1 or 0);
	self.TimeBg:SetAlpha((WQT.settings.pin.timeLabel  and timeStringShort ~= "") and 0.65 or 0);
	if(WQT.settings.pin.timeLabel ) then
		self.Time:SetFontObject(flightPinNr and "WQT_NumberFontOutlineBig" or "WQT_NumberFontOutline");
		self.Time:SetScale(flightPinNr and 1 or 2.5);
		self.Time:SetHeight(flightPinNr and 32 or 16);
		self.Time:SetPoint("TOP", self.Time:GetParent(), "BOTTOM", 2, timeDistance);
		self.Time:SetText(timeStringShort)
		self.Time:SetVertexColor(color.r, color.g, color.b) 
	end
	
end

------------------------------------------
-- 			SCROLLLIST MIXIN			--
------------------------------------------
--
-- OnLoad()
-- SetButtonsEnabled(value)
-- ApplySort()
-- UpdateFilterDisplay()
-- UpdateQuestList()
-- DisplayQuestList(skipPins)
-- ScrollFrameSetEnabled(enabled)

WQT_ScrollListMixin = {};

function WQT_ScrollListMixin:OnLoad()
	self.questList = {};
	self.questListDisplay = {};
	self.scrollBar.trackBG:Hide();
	self.scrollBar.doNotHide = true;
	self.update = function() self:DisplayQuestList(true) end;
	HybridScrollFrame_CreateButtons(self, "WQT_QuestTemplate", 1, 0);
end

function WQT_ScrollListMixin:ShowQuestTooltip(button, questInfo)
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
	local color = WORLD_QUEST_QUALITY_COLORS[rarity or 1];
	
	GameTooltip:SetText(title, color.r, color.g, color.b, 1, true);
	
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
	local seconds, timeString = WQT_Utils:GetQuestTimeString(questInfo, true, true)
	if (seconds > 0) then
		color = seconds <= SECONDS_PER_HOUR  and color or NORMAL_FONT_COLOR;
		GameTooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(timeString), color.r, color.g, color.b);
	end

	local numObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questId);
	for objectiveIndex = 1, numObjectives do
		local objectiveText, _, finished = GetQuestObjectiveInfo(questInfo.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			GameTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
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
		if((questInfo.reward.type == WQT_REWARDTYPE.equipment) and GameTooltip.ItemTooltip:IsShown()) then
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

function WQT_ScrollListMixin:SetButtonsEnabled(value)
	value = value==nil and true or value;
	local buttons = self.buttons;
	if not buttons then return end;
	
	for k, button in ipairs(buttons) do
		button:SetEnabledMixin(value);
		button:EnableMouse(value);
		button:EnableMouseWheel(value);
	end
end

function WQT_ScrollListMixin:ApplySort()
	local list = self.questListDisplay;
	local sortOption = ADD:GetSelectedValue(WQT_WorldQuestFrame.sortButton);
	table.sort(list, function (a, b) return SortQuestList(a, b, sortOption); end);
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
	-- If we are filtering, 'show' things
	WQT_WorldQuestFrame.FilterBar:SetHeight(20);
	-- Emissary has priority
	if (WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then
		local text = _L["TYPE_EMISSARY"]
		if WQT_WorldQuestFrame.autoEmisarryId then
			text = GARRISON_TEMPORARY_CATEGORY_FORMAT:format(text);
		end
		
		filterList = text;	
	else
		for kO, option in pairs(WQT.settings.filters) do
			local active = 0;
			local total = 0;
			
			for _, flag in pairs(option.flags) do
				if (flag) then active = active + 1; end
				total = total + 1;
			end

			if (active < total) then
				filterList = filterList == "" and option.name or string.format("%s, %s", filterList, option.name);
			end
		end
	end
	
	local numHidden = 0;
	local totalValid = 0;
	for k, questInfo in ipairs(self.questList) do
		if (questInfo.isValid and questInfo.reward.type ~= WQT_REWARDTYPE.missing) then
			if (questInfo.passedFilter) then
				numHidden = numHidden + 1;
			end	
			totalValid = totalValid + 1;
		end
	end
	
	local filterFormat = "(%d/%d) "..FILTERS..": %s"
	WQT_WorldQuestFrame.FilterBar.Text:SetText(filterFormat:format(numHidden, totalValid, filterList)); 
end

function WQT_ScrollListMixin:FilterQuestList()
	wipe(self.questListDisplay);
	local WQTFiltering = WQT:IsFiltering();
	local BlizFiltering = WQT:IsWorldMapFiltering();
	for k, questInfo in ipairs(self.questList) do
		questInfo.passedFilter = false;
		if (questInfo.isValid and not questInfo.alwaysHide and questInfo.reward.type ~= WQT_REWARDTYPE.missing) then
			local pass = BlizFiltering and WorldMap_DoesWorldQuestInfoPassFilters(questInfo) or not BlizFiltering;
			if (pass and WQTFiltering) then
				pass = WQT:PassesAllFilters(questInfo);
			end
			
			questInfo.passedFilter = pass;
			if (questInfo.passedFilter) then
				table.insert(self.questListDisplay, questInfo);
			elseif (addon.debug) then
				table.insert(self.questListDisplay, questInfo);
			end
		elseif (addon.debug) then
				table.insert(self.questListDisplay, questInfo);
		end
	end
	
	WQT_WorldQuestFrame:TriggerEvent("FilterQuestList");
end

function WQT_ScrollListMixin:UpdateQuestList()
	local flightShown = (FlightMapFrame and FlightMapFrame:IsShown() or TaxiRouteMap:IsShown() );
	local worldShown = WorldMapFrame:IsShown();
	
	if (not (flightShown or worldShown) or InCombatLockdown()) then return end	
	
	self.questList = _dataProvider:GetIterativeList();
	self:FilterQuestList();
	self:ApplySort();
	self:DisplayQuestList();
end

function WQT_ScrollListMixin:DisplayQuestList(skipPins)
	local mapId = WorldMapFrame.mapID;
	if (((FlightMapFrame and FlightMapFrame:IsShown()) or TaxiRouteMap:IsShown()) and not _WFMLoaded) then 
		local taxiId = GetTaxiMapID()
		mapId = (taxiId and taxiId > 0) and taxiId or mapId;
	end
	local mapInfo = WQT_Utils:GetCachedMapInfo(mapId or 0);
	if not mapInfo or InCombatLockdown() or WQT_WorldQuestFrame:GetAlpha() < 1 or not WQT_WorldQuestFrame.selectedTab or WQT_WorldQuestFrame.selectedTab:GetID() ~= 2 then 
		if (not skipPins and mapInfo and mapInfo.mapType ~= Enum.UIMapType.Continent) then	
			WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
		end
		return 
	end
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	if buttons == nil then return; end

	local shouldShowZone = WQT.settings.list.showZone and (WQT.settings.list.alwaysAllQuests or (mapInfo and (mapInfo.mapType == Enum.UIMapType.Continent or mapInfo.mapType == Enum.UIMapType.World))); 

	self:UpdateFilterDisplay();
	local list = self.questListDisplay;
	self:GetParent():HideCombatOverlay();
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
	
	if (IsAddOnLoaded("Aurora") or (WorldMapFrame:IsShown() and WorldMapFrame.isMaximized)) then
		WQT_WorldQuestFrame.Background:SetAlpha(0);
	else
		WQT_WorldQuestFrame.Background:SetAlpha(1);
		if (#list == 0) then
			WQT_WorldQuestFrame.Background:SetAtlas("NoQuestsBackground", true);
		else
			WQT_WorldQuestFrame.Background:SetAtlas("QuestLogBackground", true);
		end
	end
	
	WQT_WorldQuestFrame:TriggerEvent("DisplayQuestList", skipPins);
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

------------------------------------------
-- 			QUESTCOUNTER MIXIN			--
------------------------------------------
--
-- OnLoad()
-- InfoOnEnter(frame)
-- UpdateText()

WQT_QuestCounterMixin = {}

function WQT_QuestCounterMixin:OnLoad()
	self:SetFrameLevel(self:GetParent():GetFrameLevel() +5);
	self.hiddenList = {};
end

function WQT_QuestCounterMixin:InfoOnEnter(frame)
	-- If it's hidden, don't show tooltip
	if (frame.isHidden) then return end;
	
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	GameTooltip:SetText(_L["QUEST_COUNTER_TITLE"], nil, nil, nil, nil, true);
	GameTooltip:AddLine(_L["QUEST_COUNTER_INFO"]:format(#self.hiddenList), 1, 1, 1, true);
	
	-- Add culprits
	for k, i in ipairs(self.hiddenList) do
		local name, _, _, _, _, _, _, id = GetQuestLogTitle(i); 
		local _, tagName = GetQuestTagInfo(id)
		GameTooltip:AddDoubleLine(string.format("%s (%s)", name, id), tagName, 1, 1, 1, 1, 1, 1, true);
	end
	
	GameTooltip:Show();
end

function WQT_QuestCounterMixin:UpdateText()
	local numQuests, maxQuests, color = GetQuestLogInfo(self.hiddenList);
	self.QuestCount:SetText(GENERIC_FRACTION_STRING_WITH_SPACING:format(numQuests, maxQuests));
	self.QuestCount:SetTextColor(color.r, color.g, color.b);

	-- Show or hide the icon
	local showIcon = #self.hiddenList > 0;
	self.HiddenInfo:SetAlpha(showIcon and 1 or 0);
	self.HiddenInfo.isHidden = not showIcon;
end

------------------------------------------
-- 		FULLSCREENCONTAINER MIXIN		--
------------------------------------------
-- 
-- OnLoad()
-- OnDragStart()	
-- OnDragStop()
-- OnUpdate()
-- SetStartPosition(anchor, x, y)
-- ConstrainPosition()
--

WQT_FullScreenConstrainMixin = {}

function WQT_FullScreenConstrainMixin:OnLoad(anchor, x, y)
	self.margins = {["left"] = 0, ["right"] = 0, ["top"] = 0, ["bottom"] = 0};
	self.FirstPlacement = true;
	self.left = 0;
	self.bottom = 0;
	self:SetStartPosition(anchor, x, y);
	self.dragMouseOffset = {["x"] = 0, ["y"] = 0};
end

function WQT_FullScreenConstrainMixin:OnDragStart()	
	if(InCombatLockdown()) then return; end
	
	self:StartMoving();
	local scale = self:GetEffectiveScale();
	local fx = self:GetLeft();
	local  fy = self:GetBottom();
	local x, y = GetCursorPosition();
	x = x / scale;
	y = y / scale;
	
	self.dragMouseOffset.x = x - fx;
	self.dragMouseOffset.y = y - fy;
	self.isBeingDragged = true;
end

function WQT_FullScreenConstrainMixin:OnDragStop()
	if(self.isBeingDragged) then
		self.isBeingDragged = false;
		self:StopMovingOrSizing()
		self:ConstrainPosition();
		
		if (self == WQT_WorldMapContainerButton) then
			WQT.settings.fullScreenButtonPos.x = self.left;
			WQT.settings.fullScreenButtonPos.y = self.bottom;
		end
	end
end

function WQT_FullScreenConstrainMixin:OnUpdate()
	if (self.isBeingDragged) then
		self:ConstrainPosition();
	end
end

function WQT_FullScreenConstrainMixin:SetStartPosition(anchor, x, y)
	self.anchor = anchor or "BOTTOMLEFT";
	self.startX = x or 0;
	self.startY = y or 0;
end

function WQT_FullScreenConstrainMixin:ConstrainPosition(force)
	local WorldMapButton = WorldMapFrame.ScrollContainer;
	
	if (self.FirstPlacement) then
		self:ClearAllPoints();
		self:SetPoint(self.anchor, WorldMapButton, self.startX, self.startY);
		self.FirstPlacement = nil;
	end

	local l1, b1, w1, h1 = self:GetRect();
	local l2, b2, w2, h2 = WorldMapFrame.ScrollContainer:GetRect();
	
	-- If we're being dragged, we should make calculations based on the mouse position instead
	if (self.isBeingDragged) then
		local scale = self:GetEffectiveScale();
		l1, b1 =  GetCursorPosition();
		l1 = l1 / scale;
		b1 = b1 / scale;
		l1 = l1 - self.dragMouseOffset.x;
		b1 = b1 - self.dragMouseOffset.y;
	end
	
	local left = (l1-l2);
	local bottom = (b1-b2);
	local right = (l2+w2) - (l1+w1) - self.margins.right;
	local top = (b2+h2) - (b1+h1) - self.margins.top;

	left = max(self.margins.left, left);
	bottom = max(self.margins.bottom, bottom);
	left = right < 0 and (w2-w1 - self.margins.right) or left;
	bottom = top < 0 and (h2-h1 - self.margins.top) or bottom;

	self:ClearAllPoints();
	self:SetPoint("BOTTOMLEFT", WorldMapButton, left, bottom);
	self.left = left;
	self.bottom = bottom;
end

------------------------------------------
-- 				CORE MIXIN				--
------------------------------------------
-- 
-- ShowWorldmapHighlight(questId)
-- HideWorldmapHighlight()
-- TriggerEvent(event, ...)
-- RegisterCallback(event, func)
-- OnLoad()
-- UpdateBountyCounters()
-- RepositionBountyTabs()
-- AddBountyCountersToTab(tab)
-- :ShowHighlightOnMapFilters()
-- FilterClearButtonOnClick()
-- SearchGroup(questInfo)
-- ShouldAllowLFG(questInfo)
-- SetCvarValue(flagKey, value)
-- ShowCombatOverlay(message, manualClose)
-- HideCombatOverlay(force)
-- SetCombatEnabled(value)
-- SelectTab(tab)		1. Default questlog  2. WQT  3. Quest details
-- ChangeAnchorLocation(anchor)		Show list on a different container using _V["LIST_ANCHOR_TYPE"] variable
-- :<event> -> ADDON_LOADED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, QUEST_TURNED_IN, PVP_TIMER_UPDATE, WORLD_QUEST_COMPLETED_BY_SPELL, QUEST_LOG_UPDATE, QUEST_WATCH_LIST_CHANGED

WQT_CoreMixin = {}

function WQT_CoreMixin:ShowWorldmapHighlight(questId)
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local areaId = WorldMapFrame.mapID;
	local coords = _V["WQT_ZONE_MAPCOORDS"][areaId] and _V["WQT_ZONE_MAPCOORDS"][areaId][zoneId];
	local mapInfo = WQT_Utils:GetCachedMapInfo(zoneId);
	--Highlihght continents on world view
	if (not coords and areaId == 947 and mapInfo and mapInfo.parentMapID) then
		coords = _V["WQT_ZONE_MAPCOORDS"][947][mapInfo.parentMapID];
		mapInfo = WQT_Utils:GetCachedMapInfo(mapInfo.parentMapID);
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
			WQT_MapZoneHightlight.Texture:SetPoint("CENTER", scrollChildX, scrollChildY);
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

function WQT_CoreMixin:HideWorldmapHighlight()
	WQT_MapZoneHightlight:Hide();
	if (self.resetLabel) then
		WorldMapFrame.ScrollContainer:GetMap():TriggerEvent("ClearAreaLabel", MAP_AREA_LABEL_TYPE.POI);
		self.resetLabel = false;
	end
end

function WQT_CoreMixin:TriggerEvent(event, ...)
	if (not self.callbacks[event]) then return end;
	
	for k, func in ipairs(self.callbacks[event]) do
		func(...);
	end
end

function WQT_CoreMixin:RegisterCallback(event, func)
	if (not self.callbacks[event]) then
		self.callbacks[event] = {};
	end
	tinsert(self.callbacks[event], func);
end

function WQT_CoreMixin:OnLoad()
	
	self.callbacks = {};
	self.WQT_Utils = WQT_Utils;
	self.variables = addon.variables;
	self.pinHandler = CreateFromMixins(WQT_PinHandlerMixin);
	self.pinHandler:OnLoad();
	self.bountyCounterPool = CreateFramePool("FRAME", self, "WQT_BountyCounterTemplate");
	
	self:SetFrameLevel(self:GetParent():GetFrameLevel()+4);
	self.Blocker:SetFrameLevel(self:GetFrameLevel()+4);
	
	self.filterDropDown = ADD:CreateMenuTemplate("WQT_WorldQuestFrameFilterDropDown", self);
	self.filterDropDown.noResize = true;
	ADD:Initialize(self.filterDropDown, function(dd, level) InitFilter(dd, level) end, "MENU");
	self.FilterButton.Indicator.tooltipTitle = _L["MAP_FILTER_DISABLED_TITLE"];
	self.FilterButton.Indicator.tooltipSub = _L["MAP_FILTER_DISABLED_INFO"];
	
	self.sortButton = ADD:CreateMenuTemplate("WQT_WorldQuestFrameSortButton", self, nil, "BUTTON");
	self.sortButton:SetSize(110, 22);
	self.sortButton:SetPoint("RIGHT", "WQT_WorldQuestFrameFilterButton", "LEFT", -2, -1);
	self.sortButton:EnableMouse(false);
	self.sortButton:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); end);

	ADD:Initialize(self.sortButton, function(self, level) WQT:InitSort(self, level) end);

	local frame = ADD:CreateMenuTemplate("WQT_TrackDropDown", self);
	frame:EnableMouse(true);
	ADD:Initialize(frame, function(self, level) WQT:InitTrackDropDown(self, level) end, "MENU");
	
	
	self.dataProvider = _dataProvider;
	self.dataProvider:OnLoad()
	
	self.dataProvider:HookWaitingRoomUpdate(function() 
			if (InCombatLockdown()) then return end;
			WQT_QuestScrollFrame:ApplySort();
			WQT_QuestScrollFrame:FilterQuestList();
			if WQT_WorldQuestFrame:GetAlpha() > 0 then 
				WQT_QuestScrollFrame:UpdateQuestList();
			else
				WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(); 
			end
			WQT_WorldQuestFrame:TriggerEvent("WaitingRoomUpdated")
		end)
		
	self.dataProvider:HookQuestsLoaded(function() 
			if (InCombatLockdown()) then return end;
			self.ScrollFrame:UpdateQuestList(); 
			self.pinHandler:UpdateMapPoI(); 
			-- Update the quest number counter
			WQT_QuestLogFiller:UpdateText();
			WQT_WorldQuestFrame:TriggerEvent("QuestsLoaded", questList)
		end)

	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("QUEST_TURNED_IN");
	self:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL"); -- Class hall items
	self:RegisterEvent("PVP_TIMER_UPDATE"); -- Warmode toggle because WAR_MODE_STATUS_UPDATE does fuck if I know what
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("TAXIMAP_OPENED");
	self:RegisterEvent("QUEST_LOG_UPDATE"); -- Dataprovider only
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

	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd
	
	self.trackedQuests = {};
	self.recentlyUntrackedQuest = nil;
	
	-- Show quest tab when leaving quest details
	hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
			self:SelectTab(WQT_TabNormal);
		end)
		
	for k, v in pairs(WorldMapFrame.dataProviders) do 
		if k.pin and k.pin.HighlightTexture  then
			hooksecurefunc(k.pin.HighlightTexture, "Show", function() 
				if (MouseIsOver(WQT_WorldMapContainer)) then
					k.pin.HighlightTexture:Hide();
				end
			end);
			break;
		end
	end
	
	WorldMapFrame:HookScript("OnShow", function() 
			local mapAreaID = WorldMapFrame.mapID;
			_dataProvider:LoadQuestsInZone(mapAreaID);
			self.ScrollFrame:UpdateQuestList();
			self:SelectTab(self.selectedTab); 

			-- If emissaryOnly was automaticaly set, and there's none in the current list, turn it off again.
			if WQT_WorldQuestFrame.autoEmisarryId and not WQT_WorldQuestFrame.dataProvider:ListContainsEmissary() then
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT_QuestScrollFrame:UpdateQuestList();
			end
		end)

	WorldMapFrame:HookScript("OnHide", function() 
			self:HideOverlayFrame()
			wipe(WQT_QuestScrollFrame.questListDisplay);
			_dataProvider:ClearData();
		end)

	QuestScrollFrame:SetScript("OnShow", function() 
			if(self.selectedTab and self.selectedTab:GetID() == 2) then
				self:SelectTab(WQT_TabWorld); 
			else
				self:SelectTab(WQT_TabNormal); 
			end
		end)
		
	-- Re-anchor list when maxi/minimizing world map
	hooksecurefunc(WorldMapFrame, "HandleUserActionToggleSelf", function()
			if not WorldMapFrame:IsShown() then return end
			local anchor = WorldMapFramePortrait:IsShown() and _V["LIST_ANCHOR_TYPE"].world or _V["LIST_ANCHOR_TYPE"].full;
			WQT_WorldQuestFrame:ChangeAnchorLocation(anchor);
		end)

	hooksecurefunc(WorldMapFrame, "HandleUserActionToggleQuestLog", function()
			if not WorldMapFrame:IsShown() then return end
			local anchor = _V["LIST_ANCHOR_TYPE"].world;
			WQT_WorldQuestFrame:ChangeAnchorLocation(anchor);
		end)
	
	hooksecurefunc(WorldMapFrame, "HandleUserActionMinimizeSelf", function()
			WQT_WorldQuestFrame:ChangeAnchorLocation(_V["LIST_ANCHOR_TYPE"].world);
		end)
		
	hooksecurefunc(WorldMapFrame, "HandleUserActionMaximizeSelf", function()
			WQT_WorldQuestFrame:ChangeAnchorLocation(_V["LIST_ANCHOR_TYPE"].full);
		end)
		
	-- Update filters when stuff happens to the world map filters
	local worldMapFilter;
	
	for k, frame in ipairs(WorldMapFrame.overlayFrames) do
		for name in pairs(frame) do
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
		if (not WQT.settings.general.autoEmisarry or tab.isEmpty or WQT.settings.general.emissaryOnly) then return; end
		WQT_WorldQuestFrame.autoEmisarryId = bountyBoard.bounties[tab.bountyIndex];
		WQT_QuestScrollFrame:UpdateQuestList();
	end)
	
	hooksecurefunc(bountyBoard, "RefreshSelectedBounty", function() 
		if (WQT.settings.general.bountyCounter) then
			self:UpdateBountyCounters();
		end
	end)
	
	-- Slight offset the tabs to make room for the counters
	hooksecurefunc(bountyBoard, "AnchorBountyTab", function(self, tab) 
		if (not WQT.settings.general.bountyCounter) then return end
		local point, relativeTo, relativePoint, x, y = tab:GetPoint(1);
		tab:SetPoint(point, relativeTo, relativePoint, x, y + 2);
	end)
	
	-- Show hightlight in list when hovering over PoI
	hooksecurefunc("TaskPOI_OnEnter", function(self)
			if (WQT.settings.pin.disablePoI) then return; end
			if (self.questID ~= WQT_QuestScrollFrame.PoIHoverId) then
				WQT_QuestScrollFrame.PoIHoverId = self.questID;
				WQT_QuestScrollFrame:UpdateQuestList(true);
			end
			self.notTracked = not QuestIsWatched(self.questID);
			
			-- Improve official tooltips overlap
			local level = GameTooltip:GetFrameLevel();
			ShoppingTooltip1:SetFrameLevel(level + 1);
			ShoppingTooltip2:SetFrameLevel(level + 1);
		end)
		
	hooksecurefunc("TaskPOI_OnLeave", function(self)
			if (WQT.settings.pin.disablePoI) then return; end
			WQT_QuestScrollFrame.PoIHoverId = -1;
			WQT_QuestScrollFrame:UpdateQuestList(true);
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
		
	-- Add quest info to daily quests
	hooksecurefunc("TaskPOI_OnEnter", function(self) 
			local questInfo = _dataProvider:GetQuestById(self.questID);
			if(questInfo and (questInfo.isDaily)) then
				WorldMap_AddQuestTimeToTooltip(self.questID);
				for objectiveIndex = 1, self.numObjectives do
					local objectiveText, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(self.questID, objectiveIndex, false);
					if(self.shouldShowObjectivesAsStatusBar) then 
						local percent = math.floor((numFulfilled/numRequired) * 100);
						GameTooltip_ShowProgressBar(GameTooltip, 0, numRequired, numFulfilled, PERCENTAGE_STRING:format(percent));
					elseif ( objectiveText and #objectiveText > 0 ) then
						local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
						GameTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
					end
				end
			
				GameTooltip_AddQuestRewardsToTooltip(GameTooltip, self.questID);
				GameTooltip:Show();
			end
		end);

	-- Shift questlog around to make room for the tabs
	local a,b,c,d =QuestMapFrame:GetPoint(1);
	QuestMapFrame:SetPoint(a,b,c,d,-65);
	QuestScrollFrame:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -2);
	QuestScrollFrame.Background:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -2);
	QuestMapFrame.DetailsFrame:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -26, -2)
	QuestMapFrame.VerticalSeparator:SetHeight(463);
end

function WQT_CoreMixin:UpdateBountyCounters()
	self.bountyCounterPool:ReleaseAll();
	if (not WQT.settings.general.bountyCounter) then return end
	
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
	local size = WQT.settings.pin.bigPoI and 50 or 40;
	WQT_PoISelectIndicator:SetSize(size, size);
	WQT_PoISelectIndicator:SetScale(0.40);
end


function WQT_CoreMixin:FilterClearButtonOnClick()
	ADD:CloseDropDownMenus();
	if WQT_WorldQuestFrame.autoEmisarryId then
		WQT_WorldQuestFrame.autoEmisarryId = nil;
	elseif WQT.settings.general.emissaryOnly then
		WQT.settings.general.emissaryOnly = false;
	else
		for k, v in pairs(WQT.settings.filters) do
			WQT:SetAllFilterTo(k, true);
		end
	end
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:SearchGroup(questInfo)
	local id, title;
	if (type(questInfo) == "number") then
		id = questInfo;
	else
		id = questInfo.questId;
	end
	title = C_TaskQuest.GetQuestInfoByQuestID(id);
	
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
	local questId = questInfo;
	if type(questInfo) == "table" then
		if (questInfo.isDaily) then 
			return false; 
		end
		questId = questInfo.questId;
	end
	local questType = select(3, GetQuestTagInfo(questId));
	return questType and not (questType == LE_QUEST_TAG_TYPE_PET_BATTLE or questType == LE_QUEST_TAG_TYPE_DUNGEON or questType == LE_QUEST_TAG_TYPE_PROFESSION or questType == LE_QUEST_TAG_TYPE_RAID);
end

function WQT_CoreMixin:ADDON_LOADED(loaded)
	WQT:UpdateFilterIndicator();
	if (loaded == "Blizzard_FlightMap") then
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
		WQT.FlightMapList = {};
		hooksecurefunc(WQT.FlightmapPins, "RefreshAllData", function() self.pinHandler:UpdateFlightMapPins() end);
		hooksecurefunc(WQT.FlightmapPins, "OnHide", function() 
				for id in pairs(WQT.FlightMapList) do
					WQT.FlightMapList[id].id = -1;
					WQT.FlightMapList[id] = nil;
				end 
			end)
		
		WQT_FlightMapContainer:SetParent(FlightMapFrame);
		WQT_FlightMapContainer:SetAlpha(0);
		WQT_FlightMapContainer:SetPoint("BOTTOMLEFT", FlightMapFrame, "BOTTOMRIGHT", -6, 0);
		WQT_FlightMapContainerButton:SetParent(FlightMapFrame);
		WQT_FlightMapContainerButton:SetAlpha(1);
		WQT_FlightMapContainerButton:SetPoint("BOTTOMRIGHT", FlightMapFrame, "BOTTOMRIGHT", -8, 8);
		WQT_FlightMapContainerButton:SetFrameLevel(FlightMapFrame:GetFrameLevel()+2);
		
		self:UnregisterEvent("ADDON_LOADED");
	elseif (loaded == "TomTom") then
		TomTom = TomTom;
	elseif (loaded == "WorldFlightMap") then
		_WFMLoaded = true;
	elseif (loaded == "WorldQuestTabUtilities") then
		WQT.settings.general.loadUtilities = true;
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	self.ScrollFrame:ScrollFrameSetEnabled(false)
	WQT_WorldMapContainer:EnableMouse(false);
	self:ShowCombatOverlay();
	ADD:HideDropDownMenu(1);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	if self:GetAlpha() == 1 then
		self.ScrollFrame:ScrollFrameSetEnabled(true)
	end
	self.ScrollFrame:UpdateQuestList();
	self:SelectTab(self.selectedTab);
	WQT:UpdateFilterIndicator();
	
	WQT_WorldQuestFrame:ChangeAnchorLocation(WQT_WorldQuestFrame.anchor);
	WQT_WorldMapContainer:EnableMouse(true);
end

function WQT_CoreMixin:QUEST_TURNED_IN(questId)
	-- Clear possible highlight
	WQT_WorldQuestFrame.pinHandler:HideHighlightOnPinForQuestId(questId);

	-- Remove TomTom arrow if tracked
	if (TomTom and WQT.settings.general.useTomTom and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
		RemoveTomTomArrowbyQuestId(questId);
	end
end

function WQT_CoreMixin:PVP_TIMER_UPDATE()
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:WORLD_QUEST_COMPLETED_BY_SPELL()
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:QUEST_LOG_UPDATE()
	-- Dataprovider handles this one
end

function WQT_CoreMixin:QUEST_WATCH_LIST_CHANGED(...)
	local questId, added = ...;

	self.ScrollFrame:DisplayQuestList();
	
	local autoArrow = WQT.settings.general.TomTomAutoArrow;
	local clickArrow = WQT.settings.general.TomTomArrowOnClick;

	if (questId and added and TomTom and WQT.settings.general.useTomTom and (clickArrow or autoArrow) and QuestUtils_IsQuestWorldQuest(questId)) then
		
		if (added) then
			if (clickArrow or IsWorldQuestHardWatched(questId)) then
				AddTomTomArrowByQuestId(questId);
				--If click arrow is active, we want to clear the previous click arrow
				if (clickArrow and self.softTomTomArrow and not IsWorldQuestHardWatched(self.softTomTomArrow)) then
					RemoveTomTomArrowbyQuestId(self.softTomTomArrow);
				end
				
				if (clickArrow and not IsWorldQuestHardWatched(questId)) then
					self.softTomTomArrow = questId;
				end
			end
			
		else
			RemoveTomTomArrowbyQuestId(questId)
		end
	end
end

function WQT_CoreMixin:TAXIMAP_OPENED(system)
	local anchor = _V["LIST_ANCHOR_TYPE"].taxi;
	if (system == 2) then
		-- It's the new flight map
		anchor = _V["LIST_ANCHOR_TYPE"].flight;
		self.pinHandler:UpdateFlightMapPins() ;
	end
	
	WQT_WorldQuestFrame:ChangeAnchorLocation(anchor);
	_dataProvider:LoadQuestsInZone(GetTaxiMapID());
end

function WQT_CoreMixin:SetCvarValue(flagKey, value)
	value = (value == nil) and true or value;

	if _V["WQT_CVAR_LIST"][flagKey] then
		SetCVar(_V["WQT_CVAR_LIST"][flagKey], value);
		self.ScrollFrame:UpdateQuestList();
		WQT:UpdateFilterIndicator();
		return true;
	end
	return false;
end

function WQT_CoreMixin:ShowOverlayFrame(frame, offsetLeft, offsetRight, offsetTop, offsetBottom)
	if (not frame or InCombatLockdown()) then return end
	offsetLeft = offsetLeft or 0;
	offsetRight = offsetRight or 0;
	offsetTop = offsetTop or 0;
	offsetBottom = offsetBottom or 0;

	local blocker = self.Blocker;
	if (blocker.CurrentOverlayFrame) then
		self:HideOverlayFrame();
	end
	blocker.CurrentOverlayFrame = frame;
	
	blocker:Show();
	blocker.CombatBG:SetAlpha(0);
	blocker.CombatText:SetAlpha(0);
	blocker.UpdatesBG:SetAlpha(1);
	blocker.CloseButton:SetAlpha(1);
	blocker.CloseButton:SetEnabled(true);
	self:SetCombatEnabled(false);
	
	frame:SetParent(blocker);
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", blocker, offsetLeft, offsetTop);
	frame:SetPoint("BOTTOMRIGHT", blocker, offsetRight, offsetBottom);
	frame:SetFrameLevel(blocker:GetFrameLevel()+1)
	frame:SetFrameStrata(blocker:GetFrameStrata())
	frame:Show();
	
	WQT_QuestScrollFrame.DetailFrame:SetAlpha(0);
	
	self.manualCloseOverlay = true;
	ADD:HideDropDownMenu(1);
	
	-- Hide quest and filter to prevent bleeding through when walking around
	WQT_QuestScrollFrame:SetAlpha(0);
	self.FilterBar:SetAlpha(0);
end

function WQT_CoreMixin:HideOverlayFrame()
	local blocker = self.Blocker;
	if (not blocker.CurrentOverlayFrame or InCombatLockdown()) then return end
	self:SetCombatEnabled(true);
	blocker:Hide();
	blocker.CurrentOverlayFrame:Hide();
	WQT_QuestScrollFrame.DetailFrame:SetAlpha(1);
	
	blocker.CurrentOverlayFrame = nil;
	
	-- Show everything again
	WQT_QuestScrollFrame:SetAlpha(1);
	self.FilterBar:SetAlpha(1);
end

function WQT_CoreMixin:ShowCombatOverlay()
	local blocker = self.Blocker;
	
	self:HideOverlayFrame()
	
	self.manualCloseOverlay = manualClose;
	
	self:SetCombatEnabled(false);
	self.Blocker:Show();

	-- Update Background
	blocker.CombatBG:SetAlpha(1);
	blocker.UpdatesBG:SetAlpha(0);
	blocker.CombatText:SetAlpha(1);
	blocker.CombatText:SetText(_L["COMBATLOCK"])
	blocker.CloseButton:SetEnabled(false);
	blocker.CloseButton:SetAlpha(0);
	ADD:HideDropDownMenu(1);
end

function WQT_CoreMixin:HideCombatOverlay(force)
	if (self.manualCloseOverlay and not force) then return end;
	self:SetCombatEnabled(true);
	self.Blocker:Hide();
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

	WQT_QuestLogFiller.HiddenInfo:EnableMouse(false);
	WQT_TabWorld:EnableMouse(true);
	WQT_TabNormal:EnableMouse(true);

	if (not QuestScrollFrame.Contents:IsShown() and not QuestMapFrame.DetailsFrame:IsShown()) or id == 1 then
		-- Default questlog
		WQT_QuestLogFiller.HiddenInfo:EnableMouse(true);
		self:SetAlpha(0);
		WQT_TabNormal.Hider:SetAlpha(0);
		WQT_QuestLogFiller:SetAlpha(1);
		WQT_TabNormal.Highlight:Show();
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		QuestScrollFrame:Show();
		
		if not InCombatLockdown() then
			self:HideOverlayFrame(true)
			self:SetCombatEnabled(false);
		end
	elseif id == 2 then
		-- WQT
		WQT_TabWorld.Hider:SetAlpha(0);
		WQT_TabWorld.Highlight:Show();
		self:SetAlpha(1);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		QuestScrollFrame:Hide();
		self.ScrollFrame:UpdateQuestList();
		
		if (not InCombatLockdown() and not self.Blocker:IsShown()) then
			self:SetFrameLevel(self:GetParent():GetFrameLevel()+3);
			self:SetCombatEnabled(true);
		end
	elseif id == 3 then
		-- Quest details
		self:SetAlpha(0);
		WQT_TabNormal:SetAlpha(0);
		WQT_TabWorld:SetAlpha(0);
		QuestScrollFrame:Hide();
		QuestMapFrame.DetailsFrame:Show();
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

function WQT_CoreMixin:ChangeAnchorLocation(anchor)
	-- Store the original tab for when we come back to the world anchor
	if (self.anchor == _V["LIST_ANCHOR_TYPE"].world) then
		self.tabBeforeAnchor = self.selectedTab;
	end
	
	self.anchor = anchor;

	-- Prevent showing up when the map is minimized during combat
	if (anchor ~= _V["LIST_ANCHOR_TYPE"].full) then
		WQT_WorldMapContainer:SetAlpha(0);
	end
	
	if (InCombatLockdown() or not anchor) then return end
	
	if (anchor == _V["LIST_ANCHOR_TYPE"].flight) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetPoint("BOTTOMLEFT", WQT_FlightMapContainer, "BOTTOMLEFT", 3, 5);
		WQT_WorldQuestFrame:SetParent(WQT_FlightMapContainer);
		if (WQT_FlightMapContainer:GetAlpha() == 0) then
			WQT_WorldQuestFrame:SelectTab(WQT_TabNormal);
		else
			WQT_WorldQuestFrame:SelectTab(WQT_TabWorld);
		end
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].taxi) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetPoint("BOTTOMLEFT", WQT_OldTaxiMapContainer, "BOTTOMLEFT", 3, 5);
		WQT_WorldQuestFrame:SetParent(WQT_OldTaxiMapContainer);
		if (WQT_OldTaxiMapContainer:GetAlpha() == 0) then
			WQT_WorldQuestFrame:SelectTab(WQT_TabNormal);
		else
			WQT_WorldQuestFrame:SelectTab(WQT_TabWorld);
		end
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].world) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetPoint("TOPLEFT", QuestMapFrame, "TOPLEFT", -2, 3);
		WQT_WorldQuestFrame:SetParent(QuestMapFrame);
		WQT_WorldQuestFrame:SelectTab(self.tabBeforeAnchor);
		WQT_WorldMapContainer:EnableMouse(false);
		WQT_WorldMapContainer.DragFrame:EnableMouse(false);
		WQT_WorldMapContainer:SetAlpha(0);
		WQT_WorldMapContainerButton:EnableMouse(false);
		WQT_WorldMapContainerButton:SetAlpha(0);
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].full) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldMapContainer:ConstrainPosition();
		WQT_WorldMapContainerButton:ConstrainPosition();
		WQT_WorldQuestFrame:SetParent(WQT_WorldMapContainer);
		WQT_WorldQuestFrame:SetPoint("BOTTOMLEFT", WQT_WorldMapContainer, "BOTTOMLEFT", 3, 5);
		WQT_WorldQuestFrame:SetFrameLevel(WQT_WorldMapContainer:GetFrameLevel()+2);
		WQT_WorldMapContainerButton:EnableMouse(true);
		WQT_WorldMapContainerButton:SetAlpha(1);
		if (WQT_WorldMapContainerButton.isSelected) then
			WQT_WorldQuestFrame:SelectTab(WQT_TabWorld);
			WQT_WorldMapContainer:EnableMouse(true);
			WQT_WorldMapContainer.DragFrame:EnableMouse(true);
			WQT_WorldMapContainer:SetAlpha(1);
		else
			WQT_WorldQuestFrame:SelectTab(WQT_TabNormal);
			WQT_WorldMapContainer:EnableMouse(false);
			WQT_WorldMapContainer.DragFrame:EnableMouse(false);
			WQT_WorldMapContainer:SetAlpha(0);
		end
	end
	
	WQT_WorldQuestFrame:TriggerEvent("AnchorChanged", self, anchor);
end


