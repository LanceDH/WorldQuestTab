--
-- Info structure
--
-- questId					[number] questId
-- isAllyQuest				[boolean] is a quest for combat allies (Nazjatar)
-- isDaily					[boolean] is a daily type quest (Nazjatar & threat quests)
-- isCriteria				[boolean] is part of currently selected emissary
-- alwaysHide				[boolean] If the quest should be hidden no matter what
-- passedFilter				[boolean] passed current filters
-- isValid					[boolean] true if the quest is valid. Quest are invalid when they are missing quest data
-- time						[table] time related values
--		seconds					[number] seconds remaining when the data was gathered (To check the difference between no time and expired time)
-- mapInfo					[table] zone related values, for more accurate position use WQT_Utils:GetQuestMapLocation
--		mapX					[number] x pin position
--		mapY					[number] y pin position
-- Reward					[table]
--		typeBits				[bitfield] a combination of flags for all the types of rewards the quest provides. I.e. AP + gold + rep = 2^3 + 2^6 + 2^9 = 584 (1001001000‬)
-- rewardList				[table] List of rewards sorted by priority and filter settings
--		iterative list of rewardInfo tables
--
-- questInfo Functions
-- 
-- GetRewardType()			Type of the top reward
-- GetRewardId()			Id of the top reward
-- GetRewardAmount()		Amount of the top reward
-- GetRewardTexture()		Texture of the top reward
-- GetRewardQuality()		Quality of the top reward
-- GetRewardColor()			Color of the top reward
-- GetRewardCanUpgrade()	If the top reward has a chance of upgrading
-- TryDressUpReward()		Try all of the rewards to be shown in the dressing room
-- IsExpired()				Whether the quest time is expired or not
-- GetReward(index)			Get a specific reward from the list. nil if index is not available
-- IterateRewards()			Return ipairs of the rewards

-- RewardInfo structure
--
--	type					[number] type of reward. See WQT_REWARDTYPE in Data.lua
--	texture					[number/string] texture of the reward. can be string for things like gold or unknown reward
--	amount					[amount] amount of items, gold, rep, or item level
--	id						[number] itemId for reward. 0 if not applicable (i.e. gold)
--	quality					[number] item quality; common, rare, epic, etc
--	canUpgrade				[boolean, nullable] true if item has a chance to upgrade (e.g. ilvl 285+)
--	color					[Color] color based on the type of reward

--
-- For other data use following functions
--
-- local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questId);
-- local mapInfo = WQT_Utils:GetCachedMapInfo(zoneId); 	| mapInfo = {[mapID] = number, [name] = string, [parenMapID] = number, [mapType] = Enum.UIMapType};
-- local mapInfo = WQT_Utils:GetMapInfoForQuest(questId); 	| Quick function that gets the zoneId from the questId first
-- local factionInfo = WQT_Utils:GetFactionDataInternal(factionId); 	| factionInfo = {[name] = string, [texture] = string/number, [playerFaction] = string, [expansion] = number}
-- local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, displayTimeLeft = GetQuestTagInfo(questId);
-- local texture, sizeX, sizeY = WQT_Utils:GetCachedTypeIconData(worldQuestType, tradeskillLineIndex);
-- local timeLeftSeconds, timeString, color, timeStringShort, category = WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated);
-- local x, y = WQT_Utils:GetQuestMapLocation(questId, mapId); | More up to date position than mapInfo

--
-- Callbacks (WQT_WorldQuestFrame:RegisterCallback(event, func))
--
-- "InitFilter" 			(self, level) After InitFilter finishes
-- "DisplayQuestList" 		(skipPins) After all buttons in the list have been updated
-- "FilterQuestList"		() After the list has been filtered
-- "UpdateQuestList"		() After the list has been both filtered and updated
-- "QuestsLoaded"			() After the dataprovider updated its quest data
-- "WaitingRoomUpdated"		() After data in the dataprovider's waitingroom got updated
-- "SortChanged"			(category) After sort category was changed to a different one
-- "ListButtonUpdate"		(button) After a button was updated and shown
-- "AnchorChanged"			(anchor) After the anchor of the quest list has changed
-- "MapPinInitialized"		(pin) After a map pin has been fully setup to be shown
-- "WorldQuestCompleted"	(questId, questInfo) When a world quest is completed. questInfo gets cleared shortly after this callback is triggered

local addonName, addon = ...

local WQT = addon.WQT;
local ADD = LibStub("AddonDropDown-1.0");

local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

local _; -- local trash 
local _emptyTable = {};

local _playerFaction = GetPlayerFactionGroup();
local _playerName = UnitName("player");

local utilitiesStatus = select(5, GetAddOnInfo("WorldQuestTabUtilities"));
local _utilitiesInstalled = not utilitiesStatus or utilitiesStatus ~= "MISSING";

local _WFMLoaded = IsAddOnLoaded("WorldFlightMap");

-- Custom number abbreviation to fit inside reward icons in the list.
local function GetLocalizedAbbreviatedNumber(number)
	if type(number) ~= "number" then return "NaN" end;

	local intervals = _L["IS_AZIAN_CLIENT"] and _V["NUMBER_ABBREVIATIONS_ASIAN"] or _V["NUMBER_ABBREVIATIONS"];
	
	for i = 1, #intervals do
		local interval = intervals[i];
		local value = interval.value;
		local valueDivTen = value / 10;
		if (number >= value) then
			if (interval.decimal) then
				local rest = number - floor(number/value)*value;
				if (rest < valueDivTen) then
					return interval.format:format(floor(number/value));
				else
					return interval.format:format(floor(number/valueDivTen)/10);
				end
			end
			return interval.format:format(floor(number/valueDivTen));
		end
	end
	
	return number;
end

local function slashcmd(msg)
	if (msg == "debug") then
		addon.debug = not addon.debug;
		WQT_QuestScrollFrame:UpdateQuestList();
		print("WQT: debug", addon.debug and "enabled" or "disabled");
		return;
	elseif (msg:find("^dump")) then
		local addition = msg:sub(6)
		WQT_DebugFrame:DumpDebug(addition);
		return;
	end
	
	print(_L["OPTIONS_INFO"]);
end

local function IsRelevantFilter(filterID, key)
	-- Check any filter outside of factions if disabled by worldmap filter
	if (filterID > _V["FILTER_TYPES"].faction) then return not WQT:FilterIsWorldMapDisabled(key) end
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
		
		-- Emisarry only filter
		info.text = _L["TYPE_EMISSARY"];
		info.tooltipTitle = _L["TYPE_EMISSARY"];
		info.tooltipText =  _L["TYPE_EMISSARY_TT"];
		info.func = function(_, _, _, value)
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT.settings.general.emissaryOnly = value;
				WQT_QuestScrollFrame:UpdateQuestList();

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
		
		-- Faction, reward, and type filters
		for k, v in pairs(WQT.settings.filters) do
			info.text = v.name;
			info.value = k;
			ADD:AddButton(info, level)
		end
		
		info.hasArrow = false;
		
		-- Settings button
		info.text = SETTINGS;
		info.func = function()
				WQT_WorldQuestFrame:ShowOverlayFrame(WQT_SettingsFrame);
			end
		
		ADD:AddButton(info, level)
		
		-- What's new
		local newText = WQT.settings.updateSeen and "" or "|TInterface\\FriendsFrame\\InformationIcon:14|t ";
		
		info.text = newText .. _L["WHATS_NEW"];
		info.tooltipTitle = _L["WHATS_NEW"];
		info.tooltipText =  _L["WHATS_NEW_TT"];
		
		info.func = function()
						local scrollFrame = WQT_VersionFrame;
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
		-- Filters
		info.keepShownOnClick = true;
		info.hasArrow = false;
		info.isNotRadio = true;
		if ADD.MENU_VALUE then
			-- Faction filters
			if ADD.MENU_VALUE == _V["FILTER_TYPES"].faction then
			
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(_V["FILTER_TYPES"].faction, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:UpdateQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(_V["FILTER_TYPES"].faction, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:UpdateQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local filter = WQT.settings.filters[_V["FILTER_TYPES"].faction];
				local options = filter.flags;
				local order = WQT.filterOrders[_V["FILTER_TYPES"].faction] 
				local currExp = _V["CURRENT_EXPANSION"]
				for k, flagKey in pairs(order) do
					local factionInfo = type(flagKey) == "number" and WQT_Utils:GetFactionDataInternal(flagKey) or nil;
					-- Only factions that are current expansion and match the player's faction
					if (factionInfo and factionInfo.expansion == currExp and (not factionInfo.playerFaction or factionInfo.playerFaction == _playerFaction)) then
						info.text = type(flagKey) == "number" and GetFactionInfoByID(flagKey) or flagKey;
						info.func = function(_, _, _, value)
											options[flagKey] = value;
											WQT_QuestScrollFrame:UpdateQuestList();
										end
						info.checked = function() return options[flagKey] end;
						ADD:AddButton(info, level);			
					end
				end
				
				-- Other
				info.text = OTHER;
				info.func = function(_, _, _, value)
						filter.misc.other = value;
						WQT_QuestScrollFrame:UpdateQuestList();
					end
				info.checked = function() return filter.misc.other end;
				ADD:AddButton(info, level);			
				
				-- No faction
				info.text = _L["NO_FACTION"];
				info.func = function(_, _, _, value)
						filter.misc.none = value;
						WQT_QuestScrollFrame:UpdateQuestList();
					end
				info.checked = function() return filter.misc.none end;
				ADD:AddButton(info, level);	
				
				-- Other expansions
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = EXPANSION_NAME6;
				info.value = 301;
				info.func = nil;
				ADD:AddButton(info, level)
				
			-- Type and reward filters
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
				local order = WQT.filterOrders[ADD.MENU_VALUE] 
				local haveLabels = (_V["WQT_TYPEFLAG_LABELS"][ADD.MENU_VALUE] ~= nil);
				for k, flagKey in pairs(order) do
					info.disabled = false;
					info.tooltipTitle = nil;
					info.text = haveLabels and _V["WQT_TYPEFLAG_LABELS"][ADD.MENU_VALUE][flagKey] or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
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
			end
		end
	elseif level == 3 then
		info.isNotRadio = true;
		info.notCheckable = false;
		if ADD.MENU_VALUE == 301 then -- Legion factions
			local options = WQT.settings.filters[1].flags;
			local order = WQT.filterOrders[1] 
			local currExp = LE_EXPANSION_LEGION;
			for k, flagKey in pairs(order) do
				local data = type(flagKey) == "number" and WQT_Utils:GetFactionDataInternal(flagKey) or nil;
				if (data and data.expansion == currExp ) then
					info.text = type(flagKey) == "number" and data.name or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
										end
										WQT_QuestScrollFrame:UpdateQuestList();
									end
					info.checked = function() return options[flagKey] end;
					ADD:AddButton(info, level);			
				end
			end
		end
	end
	
	WQT_WorldQuestFrame:TriggerCallback("InitFilter", self, level);
end

-- Sort filters alphabetically regardless of localization
local function GetSortedFilterOrder(filterId)
	local filter = WQT.settings.filters[filterId];
	local tbl = {};
	for k, v in pairs(filter.flags) do
		table.insert(tbl, k);
	end
	table.sort(tbl, function(a, b) 
				if (filterId == _V["FILTER_TYPES"].faction) then
					-- Compare 2 factions
					if(type(a) == "number" and type(b) == "number")then
						local nameA = GetFactionInfoByID(tonumber(a));
						local nameB = GetFactionInfoByID(tonumber(b));
						if nameA and nameB then
							return nameA < nameB;
						end
						return a and not b;
					end
				else
					-- Compare localized labels for tpye and 
					if (_V["WQT_TYPEFLAG_LABELS"][filterId]) then
						return (_V["WQT_TYPEFLAG_LABELS"][filterId][a] or "") < (_V["WQT_TYPEFLAG_LABELS"][filterId][b] or "");
					end
				end
				-- Failsafe
				return tostring(a) < tostring(b);
			end)
	return tbl;
end

local function SortQuestList(a, b, sortID)
	-- Invalid goes to the bottom
	if (not a.isValid or not b.isValid) then
		if (a.isValid == b.isValid) then return a.questId < b.questId; end;
		return a.isValid and not b.isValid;
	end
	
	-- Filtered out quests go to the back (for debug view mainly)
	if (not a.passedFilter or not b.passedFilter) then
		if (a.passedFilter == b.passedFilter) then return a.questId < b.questId; end;
		return a.passedFilter and not b.passedFilter;
	end

	-- Sort by a list of filters depending on the current filter choice
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
	if (not version or version == "") then
		WQT.db.global.versionCheck = "1";
		return;
	end
	-- BfA
	if (version < "8.0.1") then
		-- In 8.0.01 factions use ids rather than name
		local repFlags = WQT.db.global.filters[1].flags;
		for name in pairs(repFlags) do
			if (type(name) == "string" and name ~= "Other" and name ~= _L["NO_FACTION"]) then
				repFlags[name] = nil;
			end
		end
	end
	-- Pin rework, turn off pin time by default
	if (version < "8.2.01")  then
		WQT.db.global.showPinTime = false;
	end
	-- Reworked save structure
	if (version < "8.2.02")  then
		WQT.db.global.general.defaultTab =		GetNewSettingData(WQT.db.global.defaultTab, false);
		WQT.db.global.general.saveFilters = 		GetNewSettingData(WQT.db.global.saveFilters, true);
		WQT.db.global.general.emissaryOnly = 	GetNewSettingData(WQT.db.global.emissaryOnly, false);
		WQT.db.global.general.useLFGButtons = 	GetNewSettingData(WQT.db.global.useLFGButtons, false);
		WQT.db.global.general.autoEmisarry = 	GetNewSettingData(WQT.db.global.autoEmisarry, true);
		WQT.db.global.general.questCounter = 	GetNewSettingData(WQT.db.global.questCounter, true);
		WQT.db.global.general.bountyCounter = 	GetNewSettingData(WQT.db.global.bountyCounter, true);
		WQT.db.global.general.useTomTom = 		GetNewSettingData(WQT.db.global.useTomTom, true);
		WQT.db.global.general.TomTomAutoArrow = 	GetNewSettingData(WQT.db.global.TomTomAutoArrow, true);
		
		WQT.db.global.list.typeIcon = 			GetNewSettingData(WQT.db.global.showTypeIcon, true);
		WQT.db.global.list.factionIcon = 		GetNewSettingData(WQT.db.global.showFactionIcon, true);
		WQT.db.global.list.showZone = 			GetNewSettingData(WQT.db.global.listShowZone, true);
		WQT.db.global.list.amountColors = 		GetNewSettingData(WQT.db.global.rewardAmountColors, true);
		WQT.db.global.list.alwaysAllQuests =		GetNewSettingData(WQT.db.global.alwaysAllQuests, false);
		WQT.db.global.list.fullTime = 			GetNewSettingData(WQT.db.global.listFullTime, false);

		WQT.db.global.pin.typeIcon =				GetNewSettingData(WQT.db.global.pinType, true);
		WQT.db.global.pin.rewardTypeIcon =		GetNewSettingData(WQT.db.global.pinRewardType, false);
		WQT.db.global.pin.filterPoI =			GetNewSettingData(WQT.db.global.filterPoI, true);
		WQT.db.global.pin.bigPoI =				GetNewSettingData(WQT.db.global.bigPoI, false);
		WQT.db.global.pin.disablePoI =			GetNewSettingData(WQT.db.global.disablePoI, false);
		WQT.db.global.pin.reward =				GetNewSettingData(WQT.db.global.showPinReward, true);
		WQT.db.global.pin.timeLabel =			GetNewSettingData(WQT.db.global.showPinTime, false);
		WQT.db.global.pin.ringType =				GetNewSettingData(WQT.db.global.ringType, _V["RING_TYPES"].time);
		
		-- Clean up old data
		local version = WQT.db.global.versionCheck;
		local sortBy = WQT.db.global.sortBy;
		local updateSeen = WQT.db.global.updateSeen;
		
		if (WQT.settings) then
			for k, v in pairs(WQT.settings) do
				if (type(v) ~= "table") then
					WQT.settings[k] = nil;
				end
			end
		end
		
		WQT.db.global.versionCheck = version;
		WQT.db.global.sortBy = sortBy;
		WQT.db.global.updateSeen = updateSeen;
	end
	
	if (version < "8.3.01")  then
		WQT.db.global.pin.scale = WQT.db.global.pin.bigPoI and 1.15 or 1;
		WQT.db.global.pin.centerType = WQT.db.global.pin.reward and _V["PIN_CENTER_TYPES"].reward or _V["PIN_CENTER_TYPES"].blizzard;
	end
	
	if (version < "8.3.02")  then
		local factionFlags = WQT.db.global.filters[_V["FILTER_TYPES"].faction].flags;
		-- clear out string keys
		for k in pairs(factionFlags) do
			if (type(k) == "string") then
				factionFlags[k] = nil;
			end
		end
	end
	
	if (version < "8.3.03")  then
		-- Anchoring changed, reset to default position
		WQT.db.global.fullScreenButtonPos.anchor =  _V["WQT_DEFAULTS"].global.fullScreenButtonPos.anchor;
		WQT.db.global.fullScreenButtonPos.x = _V["WQT_DEFAULTS"].global.fullScreenButtonPos.x;
		WQT.db.global.fullScreenButtonPos.y = _V["WQT_DEFAULTS"].global.fullScreenButtonPos.y;
	end
	
	if (version < "8.3.04")  then
		-- Changes for profiles
		if (WQT.db.global.sortBy) then
			WQT.db.global.general.sortBy = WQT.db.global.sortBy;
			WQT.db.global.sortBy = nil;
		end
		if (WQT.db.global.fullScreenButtonPos) then
			WQT.db.global.general.fullScreenButtonPos = WQT.db.global.fullScreenButtonPos;
			WQT.db.global.fullScreenButtonPos = nil;
		end
		if (WQT.db.global.fullScreenContainerPos) then
			WQT.db.global.general.fullScreenContainerPos = WQT.db.global.fullScreenContainerPos;
			WQT.db.global.fullScreenContainerPos = nil;
		end
		
		-- Forgot to clear this in 8.3.01
		WQT.db.global.pin.bigPoI = nil;
		WQT.db.global.pin.reward = nil; 
	end
end

-- Display an indicator on the filter if some official map filters might hide quest
function WQT:UpdateFilterIndicator() 
	if (C_CVar.GetCVarBool("showTamers") and C_CVar.GetCVarBool("worldQuestFilterArtifactPower") and C_CVar.GetCVarBool("worldQuestFilterResources") and C_CVar.GetCVarBool("worldQuestFilterGold") and C_CVar.GetCVarBool("worldQuestFilterEquipment")) then
		WQT_WorldQuestFrame.FilterButton.Indicator:Hide();
	else
		WQT_WorldQuestFrame.FilterButton.Indicator:Show();
	end
end

function WQT:SetAllFilterTo(id, value)
	local filter = WQT.settings.filters[id];
	if (not filter) then return end;
	
	local misc = filter.misc;
	if (misc) then
		for k, v in pairs(misc) do
			misc[k] = value;
		end
	end
	
	local flags = filter.flags;
	for k, v in pairs(flags) do
		flags[k] = value;
	end
end

-- Wheter the quest is being filtered because of official map filter settings
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
		WQT.settings.general.sortBy = category;
		WQT_QuestScrollFrame:UpdateQuestList();
		WQT_WorldQuestFrame:TriggerCallback("SortChanged", category);
	end
end

function WQT:InitTrackDropDown(self, level)
	if not self:GetParent() or not self:GetParent().questInfo then return; end
	local questInfo = self:GetParent().questInfo;
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
					WQT_Utils:AddTomTomArrowByQuestId(questId);
				end
			else
				info.text = _L["TRACKDD_TOMTOM_REMOVE"];
				info.func = function()
					WQT_Utils:RemoveTomTomArrowbyQuestId(questId);
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
		if (IsWorldQuestWatched(questId)) then
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

function WQT:IsUsingFilterNr(id)
	if not WQT.settings.filters[id] then return false end
	
	local misSettings = WQT.settings.filters[id].misc;
	if (misSettings) then
		for k, flag in pairs(misSettings) do
			if (WQT.settings.general.preciseFilters and flag) then
				return true;
			elseif (not WQT.settings.general.preciseFilters and not flag) then
				return true;
			end
		end
	end
	
	local flags = WQT.settings.filters[id].flags;
	for k, flag in pairs(flags) do
		if (WQT.settings.general.preciseFilters and flag) then
			return true;
		elseif (not WQT.settings.general.preciseFilters and not flag) then
			return true;
		end
	end
	return false;
end

function WQT:IsFiltering()
	if WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId then return true; end
	
	for k, category in pairs(WQT.settings.filters)do
		if (self:IsUsingFilterNr(k)) then return true; end
	end
	return false;
end

function WQT:PassesAllFilters(questInfo)
	if (WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then 
		return WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	end
	local filterTypes = _V["FILTER_TYPES"];
	
	-- For precise filters, all filters have to pass
	if (WQT.settings.general.preciseFilters)  then
		if (not  WQT:IsFiltering()) then
			return true;
		end
		local passesAll = true;
		
		if WQT:IsUsingFilterNr(filterTypes.faction) then passesAll = passesAll and WQT:PassesFactionFilter(questInfo, true) end
		if WQT:IsUsingFilterNr(filterTypes.type) then passesAll = passesAll and WQT:PassesFlagId(filterTypes.type, questInfo, true) end
		if WQT:IsUsingFilterNr(filterTypes.reward) then passesAll = passesAll and WQT:PassesFlagId(filterTypes.reward, questInfo, true) end
		
		return passesAll;
	end

	if WQT:IsUsingFilterNr(filterTypes.faction) and not WQT:PassesFactionFilter(questInfo) then return false; end
	if WQT:IsUsingFilterNr(filterTypes.type) and not WQT:PassesFlagId(filterTypes.type, questInfo) then return false; end
	if WQT:IsUsingFilterNr(filterTypes.reward) and not WQT:PassesFlagId(filterTypes.reward, questInfo) then return false; end
	
	return  true;
end

function WQT:PassesFactionFilter(questInfo, checkPrecise)
	-- Factions (1)
	local filter = WQT.settings.filters[_V["FILTER_TYPES"].faction];
	local flags = filter.flags
	local factionNone = filter.misc.none;
	local factionOther = filter.misc.other;
	local _, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local factionInfo = WQT_Utils:GetFactionDataInternal(factionId);

	-- Specific filters (matches all)
	if (checkPrecise) then
		if (factionNone and factionId) then
			return false;
		end
		if (factionOther and (not factionId or not factionInfo.unknown)) then
			return false;
		end 
		for flagKey, value in pairs(flags) do
			if (value and type(flagKey) == "number" and flagKey ~= factionId) then
				return false;
			end
		end
		return true;
	end
	
	-- General filters (matchs at least one)
	if (not factionId) then return factionNone; end
	
	if (not factionInfo.unknown) then 
		-- specific faction
		return flags[factionId];
	else
		-- other faction
		return factionOther;
	end

	return false;
end

-- Generic quest and reward type filters
function WQT:PassesFlagId(flagId ,questInfo, checkPrecise)
	local flags = WQT.settings.filters[flagId].flags
	if not flags then return false; end
	local _, _, worldQuestType = GetQuestTagInfo(questInfo.questId);
	
	local passesPrecise = true;
	
	for flag, filterEnabled in pairs(flags) do
		if (filterEnabled) then
			local func = _V["FILTER_FUNCTIONS"][flagId] and _V["FILTER_FUNCTIONS"][flagId][flag] ;
			if(func) then 
				local passed = func(questInfo, worldQuestType)
				-- If we are checking precise, combine all results. Otherwise exit out if we pass at least one
				if (WQT.settings.general.preciseFilters) then
					passesPrecise = passesPrecise and passed;
				elseif (passed) then
					return true;
				end
			end
		end
	end
	if (checkPrecise) then
		return passesPrecise;
	end
	
	return false;
end

function WQT:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("BWQDB", _V["WQT_DEFAULTS"], true);
	ConvertOldSettings(WQT.db.global.versionCheck)
	WQT_Profiles:InitSettings();
	
	-- Hightlight 'what's new'
	local currentVersion = GetAddOnMetadata(addonName, "version")
	if (WQT.db.global.versionCheck < currentVersion) then
		WQT.db.global.updateSeen = false;
		WQT.db.global.versionCheck  = currentVersion;
	end
	
	_V:GeneratePatchNotes();
end

function WQT:OnEnable()
	WQT_TabNormal.Highlight:Show();
	WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	-- load WorldQuestTabUtilities
	if (WQT.settings.general.loadUtilities and GetAddOnEnableState(_playerName, "WorldQuestTabUtilities") > 0 and not IsAddOnLoaded("WorldQuestTabUtilities")) then
		LoadAddOn("WorldQuestTabUtilities");
	end
	
	-- Place fullscreen button in saved location
	WQT_WorldMapContainerButton:LinkSettings(WQT.settings.general.fullScreenButtonPos);
	WQT_WorldMapContainer:LinkSettings(WQT.settings.general.fullScreenContainerPos);
	
	-- Apply saved filters
	if (not self.settings.general.saveFilters) then
		for k in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, true);
		end
	end

	-- Update sort text
	if self.settings.general.saveFilters and _V["WQT_SORT_OPTIONS"][self.settings.general.sortBy] then
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, self.settings.general.sortBy);
		ADD:SetText(WQT_WorldQuestFrameSortButton, _V["WQT_SORT_OPTIONS"][self.settings.general.sortBy]);
	else
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, 1);
		ADD:SetText(WQT_WorldQuestFrameSortButton, _V["WQT_SORT_OPTIONS"][1]);
	end

	-- Sort filters
	self.filterOrders = {};
	for k, v in pairs(WQT.settings.filters) do
		self.filterOrders[k] = GetSortedFilterOrder(k);
	end
	
	-- Show default tab depending on setting
	WQT_WorldQuestFrame:SelectTab((UnitLevel("player") >= 110 and self.settings.general.defaultTab) and WQT_TabWorld or WQT_TabNormal);
	WQT_WorldQuestFrame.tabBeforeAnchor = WQT_WorldQuestFrame.selectedTab;
	
	-- Show quest log counter
	WQT_QuestLogFiller:UpdateVisibility();
	
	-- Add LFG buttons to objective tracker
	if self.settings.general.useLFGButtons then
		WQT_WorldQuestFrame.LFGButtonPool = CreateFramePool("BUTTON", nil, "WQT_LFGEyeButtonTemplate");
	
		hooksecurefunc("ObjectiveTracker_AddBlock", function(block)
				local questID = block.id;
				if (not questID) then return; end
				
				-- release button if it exists
				if (block.WQTButton) then
					WQT_WorldQuestFrame.LFGButtonPool:Release(block.WQTButton);
					block.WQTButton = nil;
				end
				
				if (not (block.groupFinderButton) and QuestUtils_IsQuestWorldQuest(questID)) then
					if (WQT_WorldQuestFrame:ShouldAllowLFG(questID)) then
						local button = WQT_WorldQuestFrame.LFGButtonPool:Acquire();
						button.questId = questID;
						button:SetParent(block);
						button:ClearAllPoints();
						local offsetX = (block.rightButton or block.itemButton) and -18 or 11; 
						button:SetPoint("TOPRIGHT", block, offsetX, 4);
						button:Show();
						block.WQTButton = button;
					end
				end
			end);
	end
	
	-- Load externals
	self.loadableExternals = {};
	for k, external in ipairs(addon.externals) do
		if (external:IsLoaded()) then
			external:Init();
			WQT:debugPrint("External", external:GetName(), "loaded on first try.");
		elseif (external:IsLoadable()) then
			self.loadableExternals[external:GetName()] = external;
			WQT:debugPrint("External", external:GetName(), "waiting for load.");
		else
			WQT:debugPrint("External", external:GetName(), "not installed.");
		end
	end
	
	-- Load settings
	WQT_SettingsFrame:Init(_V["SETTING_CATEGORIES"], _V["SETTING_LIST"]);
	WQT_SettingsFrame:SetCategoryExpanded("GENERAL", true);
end

------------------------------------------
-- 			REWARDDISPLAY MIXIN			--
------------------------------------------
-- OnLoad()
-- Reset()
-- AddRewardByInfo(rewardInfo, warmodeBonus)
-- AddReward(rewardType, texture, quality, amount, typeColor, canUpgrade, warmodeBonus)

WQT_RewardDisplayMixin = {};

function WQT_RewardDisplayMixin:OnLoad()
	self.numDisplayed = 0;
end

function WQT_RewardDisplayMixin:Reset()
	for k, reward in ipairs(self.rewardFrames) do
		reward:Hide();
	end
	
	self.numDisplayed = 0;
	self:SetWidth(0.1);
end

function WQT_RewardDisplayMixin:AddRewardByInfo(rewardInfo, warmodeBonus)
	-- A bit easier when updating buttons
	self:AddReward(rewardInfo.type, rewardInfo.texture, rewardInfo.quality, rewardInfo.amount, rewardInfo.color, rewardInfo.canUpgrade, warmodeBonus);
end

function WQT_RewardDisplayMixin:AddReward(rewardType, texture, quality, amount, typeColor, canUpgrade, warmodeBonus)
	local displayTypeSetting = WQT.settings.list.rewardDisplay;

	-- Limit the amount of rewards shown
	if (self.numDisplayed >= WQT.settings.list.rewardNumDisplay) then return; end
	
	self.numDisplayed = self.numDisplayed + 1;
	local num = self.numDisplayed;
	
	amount = amount or 1;
	-- Calculate warmode bonus
	if (warmodeBonus  and C_PvP.IsWarModeDesired() and _V["WARMODE_BONUS_REWARD_TYPES"][rewardType]) then
		amount = amount + floor(amount * C_PvP.GetWarModeRewardBonus() / 100);
	end
	
	self:SetWidth(num * 29 - 1);
	local r, g, b = GetItemQualityColor(quality);
	local rewardFrame = self.rewardFrames[num];
	rewardFrame:Show();
	rewardFrame.Icon:SetTexture(texture);
	rewardFrame.IconBorder:SetVertexColor(r, g, b);
	
	rewardFrame.Amount:Hide();
	if (amount > 1) then
		rewardFrame.Amount:Show();
		
		local amountDisplay = GetLocalizedAbbreviatedNumber(amount);
		
		if (rewardType == WQT_REWARDTYPE.relic) then
			amountDisplay = "+"..amountDisplay;
		elseif (canUpgrade) then
			amountDisplay = amountDisplay.."+";
		end
		rewardFrame.Amount:SetText(amountDisplay);
		
		
		-- Color reward amount for certain types
		r, g, b = 1, 1, 1
		if ( WQT.settings.list.amountColors) then
			if (rewardType == WQT_REWARDTYPE.artifact) then
				r, g, b = GetItemQualityColor(2);
			elseif (rewardType == WQT_REWARDTYPE.equipment or rewardType == WQT_REWARDTYPE.weapon) then
				
				r, g, b = typeColor:GetRGB();
			end
		end
		
		rewardFrame.Amount:SetVertexColor(r, g, b);
		
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
-- FactionOnEnter(frame)

WQT_ListButtonMixin = {}

function WQT_ListButtonMixin:OnLoad()
	self.TrackedBorder:SetFrameLevel(self:GetFrameLevel() + 2);
	self.Highlight:SetFrameLevel(self:GetFrameLevel() + 2);
	self:EnableKeyboard(false);
	self.UpdateTooltip = function() WQT_Utils:ShowQuestTooltip(self, self.questInfo) end;
end

function WQT_ListButtonMixin:OnClick(button)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if (not self.questId or self.questId== -1) then return end
	local isBonus = QuestUtils_IsQuestBonusObjective(self.questId);
	local reward = self.questInfo:GetReward(1);
	
	-- 'Hard' tracking quests with shift
	if (IsModifiedClick("QUESTWATCHTOGGLE")) then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (not isBonus) then
			-- Only do tracking if we aren't adding the link tot he chat
			if (not ChatEdit_TryInsertQuestLinkForQuestID(self.questId)) then 
				if (IsWorldQuestWatched(self.questId)) then
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
		
	-- Trying gear with Ctrl
	elseif (IsModifiedClick("DRESSUP")) then
		self.questInfo:TryDressUpReward();
	-- 'Soft' tracking and jumping map to relevant zone
	elseif (button == "LeftButton") then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (not isBonus) then
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
		
	-- Context menu
	elseif (button == "RightButton") then
		if WQT_TrackDropDown:GetParent() ~= self then
			-- If the dropdown is linked to another button, we must move and close it first
			WQT_TrackDropDown:SetParent(self);
			ADD:HideDropDownMenu(1);
		end
		ADD:ToggleDropDownMenu(1, nil, WQT_TrackDropDown, "cursor", -10, -10, nil, nil, 2);
	end
end

-- Custom enable/disable
function WQT_ListButtonMixin:SetEnabledMixin(value)
	value = value==nil and true or value;
	self:SetEnabled(value);
	self:EnableMouse(value);
	self.Faction:EnableMouse(value);
end

function WQT_ListButtonMixin:OnUpdate()
	if ( not self.questInfo or not self:IsShown() or self.questInfo.seconds == 0) then return; end
	local _, timeString, color, _, _, category = WQT_Utils:GetQuestTimeString(self.questInfo, WQT.settings.list.fullTime);
	if (not WQT.settings.list.colorTime and category ~= _V["TIME_REMAINING_CATEGORY"].critical) then
		color = _V["WQT_WHITE_FONT_COLOR"];
	end
	self.Time:SetTextColor(color.r, color.g, color.b, 1);
	self.Time:SetText(timeString);
end

function WQT_ListButtonMixin:OnLeave()
	self.Highlight:Hide();
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questId, false);
	WQT_WorldQuestFrame:HideWorldmapHighlight();
	GameTooltip:Hide();
	GameTooltip.ItemTooltip:Hide();
	
	WQT:HideDebugTooltip()
end

function WQT_ListButtonMixin:OnEnter()
	local questInfo = self.questInfo;
	self.Highlight:Show();
	
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questId, true);
	WQT_WorldQuestFrame:ShowWorldmapHighlight(questInfo.questId);
	WQT_Utils:ShowQuestTooltip(self, questInfo);
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)
	local typeFrame = self.Type;
	local isCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	local _, _, questType, rarity, isElite = GetQuestTagInfo(questInfo.questId);

	typeFrame:Show();
	typeFrame:SetWidth(typeFrame:GetHeight());
	typeFrame.Texture:Show();
	typeFrame.Elite:SetShown(isElite);
	
	if (not rarity or rarity == LE_WORLD_QUEST_QUALITY_COMMON) then
		typeFrame.Bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		typeFrame.Bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		typeFrame.Bg:SetSize(28, 28);
	elseif (rarity == LE_WORLD_QUEST_QUALITY_RARE) then
		typeFrame.Bg:SetAtlas("worldquest-questmarker-rare");
		typeFrame.Bg:SetTexCoord(0, 1, 0, 1);
		typeFrame.Bg:SetSize(18, 18);
	elseif (rarity == LE_WORLD_QUEST_QUALITY_EPIC) then
		typeFrame.Bg:SetAtlas("worldquest-questmarker-epic");
		typeFrame.Bg:SetTexCoord(0, 1, 0, 1);
		typeFrame.Bg:SetSize(18, 18);
	end

	-- Update Icon
	local atlasTexture, sizeX, sizeY, hideBG = WQT_Utils:GetCachedTypeIconData(questInfo);

	typeFrame.Texture:SetAtlas(atlasTexture);
	typeFrame.Texture:SetSize(sizeX, sizeY);
	typeFrame.Bg:SetAlpha(hideBG and 0 or 1);
	typeFrame.CriteriaGlow:SetShown(isCriteria);
	
	if (isCriteria) then
		if (isElite) then
			typeFrame.CriteriaGlow:SetAtlas("worldquest-questmarker-dragon-glow", false);
			typeFrame.CriteriaGlow:SetPoint("CENTER", 0, -1);
		else
			typeFrame.CriteriaGlow:SetAtlas("worldquest-questmarker-glow", false);
			typeFrame.CriteriaGlow:SetPoint("CENTER", 0, 0);
		end
	end
	
	-- Bonus objectives
	if (questType == _V["WQT_TYPE_BONUSOBJECTIVE"]) then
		typeFrame.Texture:SetAtlas("QuestBonusObjective", true);
		typeFrame.Texture:SetSize(22, 22);
	end
end

function WQT_ListButtonMixin:Update(questInfo, shouldShowZone)
	if (self.questInfo ~= questInfo) then
		self.TrackedBorder:Hide();
		self.Highlight:Hide();
		self:Hide();
	end

	self:Show();
	self.questInfo = questInfo;
	self.zoneId = C_TaskQuest.GetQuestZoneID(questInfo.questId);
	self.questId = questInfo.questId;

	-- Title
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	
	if (not questInfo.isValid) then
		title = "|cFFFF0000(Invalid) " .. title;
	elseif (not questInfo.passedFilter) then
		title = "|cFF999999(Filtered) " .. title;
	end
	
	self.Title:SetText(title);
	
	self.Title:ClearAllPoints()
	self.Title:SetPoint("RIGHT", self.Rewards, "LEFT", -5, 0);
	
	if (WQT.settings.list.factionIcon) then
		self.Title:SetPoint("BOTTOMLEFT", self.Faction, "RIGHT", 5, 1);
	elseif (WQT.settings.list.typeIcon) then
		self.Title:SetPoint("BOTTOMLEFT", self.Type, "RIGHT", 5, 1);
	else
		self.Title:SetPoint("BOTTOMLEFT", self, "LEFT", 10, 0);
	end

	-- Time and zone
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
		if (mapInfo) then
			zoneName = mapInfo.name;
		end
	end
	
	self.Extra:SetText(zoneName);
	
	-- Highlight
	local showHighLight = self:IsMouseOver() or self.Faction:IsMouseOver() or (WQT_QuestScrollFrame.PoIHoverId and WQT_QuestScrollFrame.PoIHoverId == questInfo.questId)
	self.Highlight:SetShown(showHighLight);
			
	-- Faction icon
	if (WQT.settings.list.factionIcon) then
		self.Faction:Show();
		local factionData = WQT_Utils:GetFactionDataInternal(factionId);

		self.Faction.Icon:SetTexture(factionData.texture);
		self.Faction:SetWidth(self.Faction:GetHeight());
	else
		self.Faction:Hide();
		self.Faction:SetWidth(0.1);
	end
	
	-- Type icon
	if (WQT.settings.list.typeIcon) then
		self:UpdateQuestType(questInfo)
	else
		self.Type:Hide()
		self.Type:SetWidth(0.1);
	end
	
	-- Rewards
	self.Rewards:Reset();
	for k, rewardInfo in questInfo:IterateRewards() do
		self.Rewards:AddRewardByInfo(rewardInfo, C_QuestLog.QuestCanHaveWarModeBonus(self.questId));
	end
	

	-- Show border if quest is tracked
	if (GetSuperTrackedQuestID() == questInfo.questId or IsWorldQuestWatched(questInfo.questId)) then
		self.TrackedBorder:Show();
		self.TrackedBorder:SetAlpha(IsWorldQuestHardWatched(questInfo.questId) and 0.6 or 1);
	else
		self.TrackedBorder:Hide();
	end

	WQT_WorldQuestFrame:TriggerCallback("ListButtonUpdate", self)
end

function WQT_ListButtonMixin:FactionOnEnter(frame)
	self.Highlight:Show();
	local _, factionId = C_TaskQuest.GetQuestInfoByQuestID(self.questInfo.questId);
	if (factionId) then
		local factionInfo = WQT_Utils:GetFactionDataInternal(factionId)
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT", -5, -10);
		GameTooltip:SetText(factionInfo.name, nil, nil, nil, nil, true);
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

function WQT_ScrollListMixin:ResetButtons()
	local buttons = self.buttons;
	if buttons == nil then return; end
	for i=1, #buttons do
		local button = buttons[i];
		button.TrackedBorder:Hide();
		button.Highlight:Hide();
		button:Hide();
		button.questInfo = nil;
	end
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
		for k, option in pairs(WQT.settings.filters) do
			local counts = WQT:IsUsingFilterNr(k);
			if (counts) then
				filterList = filterList == "" and option.name or string.format("%s, %s", filterList, option.name);
				break;
			end
		end
	end
	
	local numHidden = 0;
	local totalValid = 0;
	for k, questInfo in ipairs(self.questList) do
		if (questInfo.isValid and questInfo.hasRewardData) then
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
		if (questInfo.isValid and not questInfo.alwaysHide and questInfo.hasRewardData and not questInfo:IsExpired()) then
			local pass = BlizFiltering and WorldMap_DoesWorldQuestInfoPassFilters(questInfo) or not BlizFiltering;
			if (pass and WQTFiltering) then
				pass = WQT:PassesAllFilters(questInfo);
			end
			
			questInfo.passedFilter = pass;
			if (questInfo.passedFilter) then
				table.insert(self.questListDisplay, questInfo);
			end
		end
		-- In debug, still filter, but show everything.
		if (not questInfo.passedFilter and addon.debug) then
				table.insert(self.questListDisplay, questInfo);
		end
	end
	
	WQT_WorldQuestFrame:TriggerCallback("FilterQuestList");
end

function WQT_ScrollListMixin:UpdateQuestList()
	local flightShown = (FlightMapFrame and FlightMapFrame:IsShown() or TaxiRouteMap:IsShown() );
	local worldShown = WorldMapFrame:IsShown();
	
	if (not (flightShown or worldShown)) then return end	
	
	self.questList = WQT_WorldQuestFrame.dataProvider:GetIterativeList();
	-- Update reward priorities
	for k, questInfo in ipairs(self.questList) do
		questInfo:ParseRewards();
	end
	
	self:FilterQuestList();
	self:ApplySort();
	self:DisplayQuestList();
	WQT_WorldQuestFrame:TriggerCallback("UpdateQuestList");
end

function WQT_ScrollListMixin:DisplayQuestList()
	local mapId = WorldMapFrame.mapID;
	if (((FlightMapFrame and FlightMapFrame:IsShown()) or TaxiRouteMap:IsShown()) and not _WFMLoaded) then 
		local taxiId = GetTaxiMapID()
		mapId = (taxiId and taxiId > 0) and taxiId or mapId;
	end
	local mapInfo = WQT_Utils:GetCachedMapInfo(mapId or 0);	
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	if buttons == nil then return; end

	local shouldShowZone = WQT.settings.list.showZone and (WQT.settings.list.alwaysAllQuests or (mapInfo and (mapInfo.mapType == Enum.UIMapType.Continent or mapInfo.mapType == Enum.UIMapType.World))); 

	self:UpdateFilterDisplay();
	
	-- Update list buttons
	local list = self.questListDisplay;
	self.numDisplayed = #list;

	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;

		if ( displayIndex <= #list) then
			button:Update(list[displayIndex], shouldShowZone);
		else
			button.TrackedBorder:Hide();
			button.Highlight:Hide();
			button:Hide();
			button.questInfo = nil;
		end
	end
	HybridScrollFrame_Update(self, #list * _V["WQT_LISTITTEM_HEIGHT"], self:GetHeight());

	-- Update background
	self:UpdateBackground();
end

function WQT_ScrollListMixin:UpdateBackground()
	if (IsAddOnLoaded("Aurora") or (WorldMapFrame:IsShown() and WQT_WorldMapContainer:IsShown())) then
		WQT_WorldQuestFrame.Background:SetAlpha(0);
	else
		WQT_WorldQuestFrame.Background:SetAlpha(1);
		if (self.numDisplayed == 0 and not WQT_WorldQuestFrame.dataProvider:IsBuffereingQuests()) then
			WQT_WorldQuestFrame.Background:SetAtlas("NoQuestsBackground", true);
		else
			WQT_WorldQuestFrame.Background:SetAtlas("QuestLogBackground", true);
		end
	end
	
	WQT_WorldQuestFrame:TriggerCallback("DisplayQuestList");
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

-- Entering the hidden quests indicator
function WQT_QuestCounterMixin:InfoOnEnter(frame)
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
	local numQuests, maxQuests, color = WQT_Utils:GetQuestLogInfo(self.hiddenList);
	self.QuestCount:SetText(GENERIC_FRACTION_STRING_WITH_SPACING:format(numQuests, maxQuests));
	self.QuestCount:SetTextColor(color.r, color.g, color.b);

	-- Show or hide the icon
	local showIcon = #self.hiddenList > 0;
	self.HiddenInfo:SetShown(showIcon);
end

function WQT_QuestCounterMixin:UpdateVisibility()
	local shouldShow = WQT.settings.general.questCounter and QuestScrollFrame:IsShown();
	self:SetShown(shouldShow);
end

------------------------------------------
-- 		CONSTRAINED CHILD MIXIN		--
------------------------------------------
-- 
-- OnLoad()
-- OnDragStart()	
-- OnDragStop()
-- OnUpdate()
-- SetStartPosition(anchor, x, y)
-- ConstrainPosition()
--

WQT_ConstrainedChildMixin = {}

function WQT_ConstrainedChildMixin:OnLoad(anchor)
	self.margins = {["left"] = 0, ["right"] = 0, ["top"] = 0, ["bottom"] = 0};
	self.anchor = "BOTTOMLEFT";
	self.left = 0;
	self.bottom = 0;
	self.dragMouseOffset = {["x"] = 0, ["y"] = 0};
	self.firstSetup = true;
end

function WQT_ConstrainedChildMixin:OnDragStart()		
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

function WQT_ConstrainedChildMixin:OnDragStop()
	if(self.isBeingDragged) then
		self.isBeingDragged = false;
		self:StopMovingOrSizing()
		self:ConstrainPosition();
		
		if (self.settings) then
			self.settings.anchor = self.anchor;
			self.settings.x = self.left;
			self.settings.y = self.bottom;
		end
	end
end

function WQT_ConstrainedChildMixin:OnUpdate()
	--
	if (self.isBeingDragged) then
		self:ConstrainPosition();
	end
end

function WQT_ConstrainedChildMixin:LinkSettings(settings)
	self:ClearAllPoints();
	self:SetPoint(settings.anchor, self:GetParent(), settings.anchor, settings.x, settings.y);
	self.settings = settings;
end

-- Constrain the frame to stay inside the borders of the parent frame
function WQT_ConstrainedChildMixin:ConstrainPosition()
	
	local parent = self:GetParent();
	local l1, b1, w1, h1 = self:GetRect();
	local l2, b2, w2, h2 = parent:GetRect();

	-- If we're being dragged, we should make calculations based on the mouse position instead
	-- Start dragging at middle of frame -> Mouse goes outside bounds -> Doesn't move until mouse is back at the middle
	-- Oterwise the frame starts moving when the mouse is no longer near it.
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
	-- Check if any side passes a edge (including margins)
	local SetConstrainedPos = false;
	if (left < self.margins.left) then 
		left = self.margins.left;
		SetConstrainedPos = true;
	end
	if (bottom < self.margins.bottom) then 
		bottom = self.margins.bottom;
		SetConstrainedPos = true;
	end
	if (right < 0) then 
		left = (w2-w1 - self.margins.right);
		SetConstrainedPos = true;
	end
	if (top < 0) then 
		bottom = (h2-h1 - self.margins.top);
		SetConstrainedPos = true;
	end
	
	-- Find best fitting anchor
	local anchorH = "LEFT";
	local anchorV = "BOTTOM";
	if (left + w1/2 >= w2/2) then
		anchorH = "RIGHT";
		left = left - w2 + w1;
	end
	if (bottom + h1/2 >= h2/2) then
		anchorV = "TOP";
		bottom = bottom - h2 + h1;
	end
	
	local anchor = anchorV .. anchorH;
	
	self.anchor = anchor;
	self.left = left;
	self.bottom = bottom;

	-- If the frame had to be constrained, force the constrained position
	if (SetConstrainedPos) then
		self:ClearAllPoints();
		self:SetPoint(self.anchor, parent, self.anchor, left, bottom);
	end
end

------------------------------------------
-- 				CORE MIXIN				--
------------------------------------------
-- 
-- ShowWorldmapHighlight(questId)
-- HideWorldmapHighlight()
-- TriggerEvent(event, ...)
-- RegisterCallback(func)
-- OnLoad()
-- UpdateBountyCounters()
-- RepositionBountyTabs()
-- AddBountyCountersToTab(tab)
-- ShowHighlightOnMapFilters()
-- FilterClearButtonOnClick()
-- SearchGroup(questInfo)
-- ShouldAllowLFG(questInfo)
-- SetCvarValue(flagKey, value)
-- SetCustomEnabled(value)
-- SelectTab(tab)		1. Default questlog  2. WQT  3. Quest details
-- ChangeAnchorLocation(anchor)		Show list on a different container using _V["LIST_ANCHOR_TYPE"] variable
-- :<event> -> ADDON_LOADED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, QUEST_TURNED_IN, PVP_TIMER_UPDATE, WORLD_QUEST_COMPLETED_BY_SPELL, QUEST_LOG_UPDATE, QUEST_WATCH_LIST_CHANGED

WQT_CoreMixin = CreateFromMixins(WQT_CallbackMixin);

function WQT_CoreMixin:TryHideOfficialMapPin(pin)
	if (WQT.settings.pin.disablePoI) then return; end
	
	local questInfo = self.dataProvider:GetQuestById(pin.questID)
	if (questInfo and questInfo.isValid) then
		pin:Hide();
	end
end

function WQT_CoreMixin:HideOfficialMapPins()
	if (WQT.settings.pin.disablePoI) then return; end
	
	if (WorldMapFrame:IsShown()) then
		local mapWQProvider = WQT_Utils:GetMapWQProvider();
		for _, pin in pairs(mapWQProvider.activePins) do
			self:TryHideOfficialMapPin(pin);
		end
		
		WQT_Utils:ItterateAllBonusObjectivePins(function(pin) self:TryHideOfficialMapPin(pin); end);
	end
end

-- Mimics hovering over a zone or continent, based on the zone the map is in
function WQT_CoreMixin:ShowWorldmapHighlight(questId)
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local areaId = WorldMapFrame.mapID;
	local coords = _V["WQT_ZONE_MAPCOORDS"][areaId] and _V["WQT_ZONE_MAPCOORDS"][areaId][zoneId];
	local mapInfo = WQT_Utils:GetCachedMapInfo(zoneId);
	-- We can't use parentMapID for cases like Cape of Stranglethorn
	local continentID = WQT_Utils:GetContinentForMap(zoneId);
	-- Highlihght continents on world view
	-- 947 == Azeroth world map
	if (not coords and areaId == 947 and continentID) then
		coords = _V["WQT_ZONE_MAPCOORDS"][947][continentID];
		mapInfo = WQT_Utils:GetCachedMapInfo(continentID);
	end
	
	if (not coords or not mapInfo) then return; end;

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

function WQT_CoreMixin:OnLoad()
	self.callbacks = {};
	self.WQT_Utils = WQT_Utils;
	self.variables = addon.variables;

	-- Add utilities options to the settings if it's installed but not enabled
	if (_utilitiesInstalled) then
		for k, setting in ipairs(_V["SETTING_UTILITIES_LIST"]) do
			tinsert(_V["SETTING_LIST"], setting);
		end
	end

	-- Quest Dataprovider
	self.dataProvider = CreateFromMixins(WQT_DataProvider);
	self.dataProvider:OnLoad();
	
	-- Pin Dataprovider
	self.pinDataProvider = CreateFromMixins(WQT_PinDataProvider);
	self.pinDataProvider:Init();
	self.bountyCounterPool = CreateFramePool("FRAME", self, "WQT_BountyCounterTemplate");
	
	self:SetFrameLevel(self:GetParent():GetFrameLevel()+4);
	self.Blocker:SetFrameLevel(self:GetFrameLevel()+4);
	
	-- Fitler
	self.filterDropDown = ADD:CreateMenuTemplate("WQT_WorldQuestFrameFilterDropDown", self);
	self.filterDropDown.noResize = true;
	ADD:Initialize(self.filterDropDown, function(dd, level) InitFilter(dd, level) end, "MENU");
	self.FilterButton.Indicator.tooltipTitle = _L["MAP_FILTER_DISABLED_TITLE"];
	self.FilterButton.Indicator.tooltipSub = _L["MAP_FILTER_DISABLED_INFO"];
	
	-- Sort
	self.sortButton = ADD:CreateMenuTemplate("WQT_WorldQuestFrameSortButton", self, nil, "BUTTON");
	self.sortButton:SetSize(110, 22);
	self.sortButton:SetPoint("RIGHT", "WQT_WorldQuestFrameFilterButton", "LEFT", -2, -1);

	ADD:Initialize(self.sortButton, function(self, level) WQT:InitSort(self, level) end);

	-- Context menu
	local frame = ADD:CreateMenuTemplate("WQT_TrackDropDown", self);
	frame:EnableMouse(true);
	ADD:Initialize(frame, function(self, level) WQT:InitTrackDropDown(self, level) end, "MENU");

	self.dataProvider:RegisterCallback("WaitingRoom", function() 
			if (InCombatLockdown()) then return end;
			WQT_QuestScrollFrame:ApplySort();
			WQT_QuestScrollFrame:FilterQuestList();
			WQT_QuestScrollFrame:UpdateQuestList();
			WQT_WorldQuestFrame:TriggerCallback("WaitingRoomUpdated")
		end)
		
	self.dataProvider:RegisterCallback("QuestsLoaded", function() 
			self.ScrollFrame:UpdateQuestList(); 
			-- Update the quest number counter
			WQT_QuestLogFiller:UpdateText();
			WQT_WorldQuestFrame:TriggerCallback("QuestsLoaded")
		end)
	
	self.dataProvider:RegisterCallback("BufferUpdated", function(progress) 
			if (progress == 0) then
				self.ProgressBar:Hide();
			end
			CooldownFrame_SetDisplayAsPercentage(self.ProgressBar, progress);
			self.ProgressBar.Pointer:SetRotation(-progress*6.2831);
		end)

	-- Events
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("QUEST_TURNED_IN");
	self:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL"); -- Class hall items
	self:RegisterEvent("PVP_TIMER_UPDATE"); -- Warmode toggle because WAR_MODE_STATUS_UPDATE doesn't seems to fire when toggling warmode
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("TAXIMAP_OPENED");
	self:RegisterEvent("QUEST_LOG_UPDATE"); -- Dataprovider only
	self:RegisterEvent("PLAYER_LOGOUT");
	
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

	-- Slashcommands
	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd
	
	-- Show quest tab when leaving quest details
	hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
			self:SelectTab(WQT_TabNormal);
		end)

	--
	-- Function hooks
	-- 
	
	-- World map
	-- Update when opening the map
	WorldMapFrame:HookScript("OnShow", function() 
			local mapAreaID = WorldMapFrame.mapID;
			self.dataProvider:LoadQuestsInZone(mapAreaID);
			self.ScrollFrame:UpdateQuestList();
			self:SelectTab(self.selectedTab); 

			-- If emissaryOnly was automaticaly set, and there's none in the current list, turn it off again.
			if WQT_WorldQuestFrame.autoEmisarryId and not WQT_WorldQuestFrame.dataProvider:ListContainsEmissary() then
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT_QuestScrollFrame:UpdateQuestList();
			end
		end)

	-- Wipe data when hiding map
	WorldMapFrame:HookScript("OnHide", function() 
			self:HideOverlayFrame()
			wipe(WQT_QuestScrollFrame.questListDisplay);
			self.dataProvider:ClearData();
		end)

	-- Fix tabs when official quests are shown
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
		
	-- Opening quest details
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(questId)
			self:SelectTab(WQT_TabDetails);
			if QuestMapFrame.DetailsFrame.questID == nil then
				QuestMapFrame.DetailsFrame.questID = questId;
			end
			-- Anchor to small map in case details were opened through clicking a quest in the obejctive tracker
			WQT_WorldQuestFrame:ChangeAnchorLocation(_V["LIST_ANCHOR_TYPE"].world);
		end)	
	
	-- Update our filters when changes are made to the world map filters
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
	
	
	-- Show hightlight in list when hovering over official map pinDataProvider
	hooksecurefunc("TaskPOI_OnEnter", function(self)
			if (WQT.settings.pin.disablePoI) then return; end
			
			if (self.questID ~= WQT_QuestScrollFrame.PoIHoverId) then
				WQT_QuestScrollFrame.PoIHoverId = self.questID;
				WQT_QuestScrollFrame:UpdateQuestList(true);
			end
			self.notTracked = not IsWorldQuestWatched(self.questID);
			
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
		
	hooksecurefunc("LFGListUtil_FindQuestGroup", function(questID, isFromGreenEyeButton)
			if (isFromGreenEyeButton) then
				WQT_GroupSearch:Hide();
				WQT_GroupSearch.questId = nil;
				WQT_GroupSearch.title = nil;
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
				WQT_GroupSearch:Hide();
				WQT_GroupSearch:Show();
			end
		end)
		
	-- Add quest info to daily quests
	hooksecurefunc("TaskPOI_OnEnter", function(poi) 
			local questInfo = self.dataProvider:GetQuestById(poi.questID);
			if(questInfo and (questInfo.isDaily)) then
				WorldMap_AddQuestTimeToTooltip(poi.questID);
				for objectiveIndex = 1, poi.numObjectives do
					local objectiveText, _, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(poi.questID, objectiveIndex, false);
					if(poi.shouldShowObjectivesAsStatusBar) then 
						local percent = math.floor((numFulfilled/numRequired) * 100);
						GameTooltip_ShowProgressBar(GameTooltip, 0, numRequired, numFulfilled, PERCENTAGE_STRING:format(percent));
					elseif ( objectiveText and #objectiveText > 0 ) then
						local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
						GameTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
					end
				end
			
				GameTooltip_AddQuestRewardsToTooltip(GameTooltip, poi.questID);
				GameTooltip:Show();
			end
		end);

	-- Hook hiding of official pins if we replace them with our own
	local mapWQProvider = WQT_Utils:GetMapWQProvider();
	hooksecurefunc(mapWQProvider, "RefreshAllData", function() 
			self:HideOfficialMapPins();
		end);
		
	QuestMapFrame.QuestSessionManagement:HookScript("OnShow", function() 
			if(self:IsShown()) then
				QuestMapFrame.QuestSessionManagement:Hide();
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

function WQT_CoreMixin:ApplyAllSettings()
	self:UpdateBountyCounters();
	self:RepositionBountyTabs();
	self.pinDataProvider:RefreshAllData()
	WQT_Utils:RefreshOfficialDataProviders();
	WQT_QuestScrollFrame:UpdateQuestList();
	WQT:Sort_OnClick(nil, WQT.settings.general.sortBy);
	WQT_WorldMapContainerButton:LinkSettings(WQT.settings.general.fullScreenButtonPos);
	WQT_WorldMapContainer:LinkSettings(WQT.settings.general.fullScreenContainerPos);
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
			
			if (progress == goal) then return end;
			
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
			local default = not WQT.settings.general.preciseFilters;
			WQT:SetAllFilterTo(k, default);
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
	
	-- If we can't automatically make a group, show a message on what the player should type
	if (not C_LFGList.CanCreateQuestGroup(id)) then
		WQT_GroupSearch:SetParent(LFGListFrame.SearchPanel.SearchBox);
		WQT_GroupSearch:SetFrameLevel(LFGListFrame.SearchPanel.SearchBox:GetFrameLevel()+5);
		WQT_GroupSearch:ClearAllPoints();
		WQT_GroupSearch:SetPoint("TOPLEFT", LFGListFrame.SearchPanel.SearchBox, "BOTTOMLEFT", -2, -3);
		WQT_GroupSearch:SetPoint("RIGHT", LFGListFrame.SearchPanel, "RIGHT", -30, 0);
	
		WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_SEARCH"]:format(id, title));
		WQT_GroupSearch.downArrow = false;
		WQT_GroupSearch:Hide();
		WQT_GroupSearch:Show();
		
		WQT_GroupSearch.questId = id;
		WQT_GroupSearch.title = title;
	end
end

-- Only allow LFG for quests that would actually allow it
function WQT_CoreMixin:ShouldAllowLFG(questInfo)
	local questId = questInfo;
	if (type(questInfo) == "table") then
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
		-- Hook official pins to hide on show
		-- I'd rather not do it this way but the Flight map pins update so much I might as well
		local flightWQProvider = WQT_Utils:GetFlightWQProvider();
		hooksecurefunc(flightWQProvider, "AddWorldQuest", function(frame, info) 
				local pool = FlightMapFrame.pinPools[FlightMap_WorldQuestDataProviderMixin:GetPinTemplate()];
				if (not pool) then return; end
				for pin in pairs(pool.activeObjects) do
					if (not pin.WQTHooked) then
						pin.WQTHooked = true;
						pin:HookScript("OnShow", function() 
							self:TryHideOfficialMapPin(pin) 
						end);
					end
				end	
			end);
		
		WQT_FlightMapContainer:SetParent(FlightMapFrame);
		WQT_FlightMapContainer:SetPoint("BOTTOMLEFT", FlightMapFrame, "BOTTOMRIGHT", -6, 0);
		WQT_FlightMapContainerButton:SetParent(FlightMapFrame);
		WQT_FlightMapContainerButton:SetAlpha(1);
		WQT_FlightMapContainerButton:SetPoint("BOTTOMRIGHT", FlightMapFrame, "BOTTOMRIGHT", -8, 8);
		WQT_FlightMapContainerButton:SetFrameLevel(FlightMapFrame:GetFrameLevel()+2);
	elseif (loaded == "WorldFlightMap") then
		_WFMLoaded = true;
	elseif (loaded == "WorldQuestTabUtilities") then
		WQT.settings.general.loadUtilities = true;
	end
	
	-- Load waiting externals
	if (WQT.loadableExternals) then
		local external = WQT.loadableExternals[loaded];
		if (external) then
			external:Init();
			WQT:debugPrint("External", external:GetName(), "delayed load.");
			WQT.loadableExternals[loaded] = nil;
		end
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	-- Custom LFG buttons disabled during combat, because the LFG frame is protected
	for k, block in ipairs({ObjectiveTrackerBlocksFrame:GetChildren()}) do
		if (block.WQTButton) then
			block.WQTButton:SetEnabled(false);
		end
	end
	ADD:HideDropDownMenu(1);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	-- Custom LFG buttons disabled during combat, because the LFG frame is protected
	for k, block in ipairs({ObjectiveTrackerBlocksFrame:GetChildren()}) do
		if (block.WQTButton) then
			block.WQTButton:SetEnabled(true);
		end
	end
end

function WQT_CoreMixin:QUEST_TURNED_IN(questId)
	local questInfo = WQT_WorldQuestFrame.dataProvider:GetQuestById(questId);
	if (questInfo) then
		WQT_WorldQuestFrame:TriggerCallback("WorldQuestCompleted", questId, questInfo);
	end

	-- Remove TomTom arrow if tracked
	if (TomTom and WQT.settings.general.useTomTom and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
		WQT_Utils:RemoveTomTomArrowbyQuestId(questId);
	end
end

 -- Warmode toggle because WAR_MODE_STATUS_UPDATE doesn't seems to fire when toggling warmode
function WQT_CoreMixin:PVP_TIMER_UPDATE()
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:WORLD_QUEST_COMPLETED_BY_SPELL()
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:QUEST_LOG_UPDATE()
	-- Dataprovider handles this one
end

function WQT_CoreMixin:PLAYER_LOGOUT()
	WQT_Profiles:ClearDefaultsFromActive();
end

function WQT_CoreMixin:QUEST_WATCH_LIST_CHANGED(...)
	local questId, added = ...;

	self.ScrollFrame:DisplayQuestList();
	WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
	
	-- Update TomTom arrows when quests change. Might be new that needs tracking or completed that needs removing
	local autoArrow = WQT.settings.general.TomTomAutoArrow;
	local clickArrow = WQT.settings.general.TomTomArrowOnClick;
	if (questId and added and TomTom and WQT.settings.general.useTomTom and (clickArrow or autoArrow) and QuestUtils_IsQuestWorldQuest(questId)) then
		
		if (added) then
			if (clickArrow or IsWorldQuestHardWatched(questId)) then
				WQT_Utils:AddTomTomArrowByQuestId(questId);
				--If click arrow is active, we want to clear the previous click arrow
				if (clickArrow and self.softTomTomArrow and not IsWorldQuestHardWatched(self.softTomTomArrow)) then
					WQT_Utils:RemoveTomTomArrowbyQuestId(self.softTomTomArrow);
				end
				
				if (clickArrow and not IsWorldQuestHardWatched(questId)) then
					self.softTomTomArrow = questId;
				end
			end
			
		else
			WQT_Utils:RemoveTomTomArrowbyQuestId(questId)
		end
	end
end

function WQT_CoreMixin:TAXIMAP_OPENED(system)
	local anchor = _V["LIST_ANCHOR_TYPE"].taxi;
	if (system == 2) then
		-- It's the new flight map
		anchor = _V["LIST_ANCHOR_TYPE"].flight;
	end
	
	WQT_WorldQuestFrame:ChangeAnchorLocation(anchor);
	self.dataProvider:LoadQuestsInZone(GetTaxiMapID());
end

-- Reset official map filters
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

-- Show a frame over the world quest list
function WQT_CoreMixin:ShowOverlayFrame(frame, offsetLeft, offsetRight, offsetTop, offsetBottom)
	if (not frame) then return end
	offsetLeft = offsetLeft or 0;
	offsetRight = offsetRight or 0;
	offsetTop = offsetTop or 0;
	offsetBottom = offsetBottom or 0;

	local blocker = self.Blocker;
	-- Hide the previous frame if any
	if (blocker.CurrentOverlayFrame) then
		self:HideOverlayFrame();
	end
	blocker.CurrentOverlayFrame = frame;
	
	blocker:Show();
	self:SetCustomEnabled(false);
	
	frame:SetParent(blocker);
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", blocker, offsetLeft, offsetTop);
	frame:SetPoint("BOTTOMRIGHT", blocker, offsetRight, offsetBottom);
	frame:SetFrameLevel(blocker:GetFrameLevel()+1)
	frame:SetFrameStrata(blocker:GetFrameStrata())
	frame:Show();
	
	WQT_QuestScrollFrame.DetailFrame:Hide();
	
	self.manualCloseOverlay = true;
	ADD:HideDropDownMenu(1);
	
	-- Hide quest and filter to prevent bleeding through when walking around
	WQT_QuestScrollFrame:Hide();
	self.FilterBar:Hide();
end

function WQT_CoreMixin:HideOverlayFrame()
	local blocker = self.Blocker;
	if (not blocker.CurrentOverlayFrame) then return end
	self:SetCustomEnabled(true);
	blocker:Hide();
	blocker.CurrentOverlayFrame:Hide();
	WQT_QuestScrollFrame.DetailFrame:Show();
	
	blocker.CurrentOverlayFrame = nil;
	
	-- Show everything again
	WQT_QuestScrollFrame:Show();
	self.FilterBar:Show();
end

-- Enable/Disable all world quest list functionality
function WQT_CoreMixin:SetCustomEnabled(value)
	value = value==nil and true or value;
	
	self:EnableMouse(value);
	self:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouse(value);
	WQT_QuestScrollFrame.scrollBar:EnableMouseWheel(value);
	WQT_QuestScrollFrame.scrollBar:EnableMouse(value);
	WQT_QuestScrollFrameScrollChild:EnableMouseWheel(value);
	WQT_QuestScrollFrameScrollChild:EnableMouse(value);
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
	local id = tab and tab:GetID() or 0;
	if self.selectedTab ~= tab then
		ADD:HideDropDownMenu(1);
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	end
	self.selectedTab = tab;
	
	WQT_TabNormal:Show();
	WQT_TabWorld:Show();
	WQT_TabNormal:SetFrameLevel(2);
	WQT_TabWorld:SetFrameLevel(2);
	WQT_TabNormal.Hider:Show();
	WQT_TabWorld.Hider:Show();

	-- Hide/show when quest details are shown
	WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
	QuestMapFrame_UpdateQuestSessionState(QuestMapFrame);
	self:HideOverlayFrame();

	if (not QuestScrollFrame.Contents:IsShown() and not QuestMapFrame.DetailsFrame:IsShown()) or id == 1 then
		-- Default questlog
		self:Hide();
		WQT_TabNormal:SetFrameLevel(10);
		WQT_TabNormal.Hider:Hide();
		WQT_TabNormal.Highlight:Show();
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		QuestScrollFrame:Show();
	elseif id == 2 then
		-- WQT
		WQT_TabWorld:SetFrameLevel(10);
		WQT_TabWorld.Hider:Hide();
		WQT_TabWorld.Highlight:Show();
		self:Show();
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		QuestScrollFrame:Hide();
		-- Prevent the party sync block from showing through the quest list. 
		QuestMapFrame.QuestSessionManagement:Hide();
	elseif id == 3 then
		-- Quest details
		self:Hide();
		WQT_TabNormal:Hide();
		WQT_TabWorld:Hide()
		QuestScrollFrame:Hide();
		QuestMapFrame.DetailsFrame:Show();
	end
	
	WQT_QuestLogFiller:UpdateVisibility();
end

function WQT_CoreMixin:ChangeAnchorLocation(anchor)
	-- Store the original tab for when we come back to the world anchor
	if (self.anchor == _V["LIST_ANCHOR_TYPE"].world) then
		self.tabBeforeAnchor = self.selectedTab;
	end
	
	-- Prevent showing up when the map is minimized
	if (anchor ~= _V["LIST_ANCHOR_TYPE"].full) then
		WQT_WorldMapContainer:Hide();
	end
	
	if (not anchor) then return end
	
	self.anchor = anchor;
	
	local parent = QuestMapFrame;
	local point =  "BOTTOMLEFT";
	local xOffset = 3;
	local yOffset = 5;
	local tab = WQT_TabWorld;
	
	if (anchor == _V["LIST_ANCHOR_TYPE"].flight) then
		parent = WQT_FlightMapContainer;
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].taxi) then
		parent = WQT_OldTaxiMapContainer;
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].world) then
		point = "TOPLEFT";
		xOffset = -2;
		yOffset = 3;
		tab = self.tabBeforeAnchor;
		WQT_WorldMapContainer:Hide();
		WQT_WorldMapContainerButton:Hide();
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].full) then
		parent = WQT_WorldMapContainer;
		WQT_WorldMapContainer:ConstrainPosition();
		WQT_WorldMapContainerButton:ConstrainPosition();
		WQT_WorldQuestFrame:SetFrameLevel(WQT_WorldMapContainer:GetFrameLevel()+2);
		WQT_WorldMapContainerButton:Show();
		WQT_WorldMapContainer:SetShown(WQT_WorldMapContainerButton.isSelected);
	end

	WQT_WorldQuestFrame:ClearAllPoints(); 
	WQT_WorldQuestFrame:SetPoint(point, parent, point, xOffset, yOffset);
	WQT_WorldQuestFrame:SetParent(parent);
	WQT_WorldQuestFrame:SelectTab(tab);
	
	WQT_WorldQuestFrame:TriggerCallback("AnchorChanged", anchor);
end
