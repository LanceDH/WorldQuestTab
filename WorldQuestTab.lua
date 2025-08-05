-- Callbacks using EventRegistry
--
-- "WQT.DataProvider.QuestsLoaded"			() After InitFilter finishes
-- "WQT.DataProvider.ProgressUpdated"		(progress) Progress in gethering quests from zones (% from 0-1)
-- "WQT.DataProvider.FilteredListUpdated"	() Quest list have been filtered and sorted (get though fitleredQuestsList)
-- "WQT.CoreFrame.AnchorUpdated"			(anchor) Anchor for the core frame has been changed
-- "WQT.ScrollList.BackgroundUpdated"		() Updated the background of the quest list
-- "WQT.MapPinProvider.PinInitialized"		(pin) A pin has been set up 
-- "WQT.FiltersUpdated"						() A filter was changed. Used to update dataprovider
-- "WQT.SortUpdated"						() Sorting was changed. Used to update dataprovider
-- "WQT.RegisterdEventTriggered"			(event, ...) An event registered to our core frame triggered
-- "WQT.QuestContextSetup"					(rootDescription, questInfo) Right-click context menu is being set up. Before Cancel is added

local addonName, addon = ...

local WQT = addon.WQT;

local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

local _; -- local trash 

local _playerFaction = GetPlayerFactionGroup();
local _playerName = UnitName("player");

local utilitiesStatus = select(5, C_AddOns.GetAddOnInfo("WorldQuestTabUtilities"));

WQT_PanelID = EnumUtil.MakeEnum("Quests", "WhatsNew", "Settings");

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
		WQT_ListContainer:UpdateQuestList();
		print("WQT: debug", addon.debug and "enabled" or "disabled");
		return;
	elseif (msg:find("^dump")) then
		local addition = msg:sub(6)
		WQT_DebugFrame:DumpDebug(addition);
		return;
	end
end

local function AddBasicTooltipFunctionsToDropdownItem(item, title, body)
	item:SetOnEnter(function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
			GameTooltip_SetTitle(GameTooltip, title);
			GameTooltip_AddNormalLine(GameTooltip, body);
			GameTooltip:Show();
		end);
	
	item:SetOnLeave(function(button)
			GameTooltip:Hide();
		end);
end

local function FilterTypesGeneralOnClick(data)
	WQT:SetAllFilterTo(data.type, data.value, data.maskFunc);
	EventRegistry:TriggerEvent("WQT.FiltersUpdated");
	return MenuResponse.Refresh;
end

local function GenericFilterFlagChecked(data)
	local flagKey = data[2];

	if (WQT_Utils:IsFilterDisabledByOfficial(flagKey)) then
		return false;
	end

	local options = data[1];
	local flagKey = flagKey;
	return options[flagKey]
end

local function GenericFilterOnSelect(data)
	local options = data[1];
	local flagKey = data[2];
	local refreshPins = #data > 2 and data[3] or false;
	options[flagKey] = not options[flagKey];
	if (refreshPins) then
		WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
	end
	EventRegistry:TriggerEvent("WQT.FiltersUpdated");
end

local function ShowDisabledFilterTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip_SetTitle(GameTooltip, _L["MAP_FILTER_DISABLED"]);
	GameTooltip_AddNormalLine(GameTooltip, _L["MAP_FILTER_DISABLED_INFO"]);
	GameTooltip:Show();
end

local function AddFilterSubmenu(rootDescription, filterType)
	rootDescription:CreateButton(CHECK_ALL, FilterTypesGeneralOnClick, { ["type"] = filterType, ["value"] = true});
	rootDescription:CreateButton(UNCHECK_ALL, FilterTypesGeneralOnClick, { ["type"] = filterType, ["value"] = false});

	local options = WQT.settings.filters[filterType].flags;
	local order = WQT.filterOrders[filterType]
	local haveLabels = (_V["WQT_TYPEFLAG_LABELS"][filterType] ~= nil);
	local oldContentFlags = {};
	
	for k, flagKey in pairs(order) do
		if (not WQT_Utils:FilterIsOldContent(filterType, flagKey)) then
			local text = haveLabels and _V["WQT_TYPEFLAG_LABELS"][filterType][flagKey] or flagKey;
			local checkbox = rootDescription:CreateCheckbox(text, GenericFilterFlagChecked, GenericFilterOnSelect, { options, flagKey });

			if (WQT_Utils:IsFilterDisabledByOfficial(flagKey)) then
				checkbox:SetEnabled(false);
				checkbox:SetOnEnter(ShowDisabledFilterTooltip);
				checkbox:SetOnLeave(function() GameTooltip:Hide(); end);
			end
			
		else
			tinsert(oldContentFlags, flagKey);
		end
	end

	if (#oldContentFlags > 0) then
		local otherSubmenu = rootDescription:CreateButton(OTHER);
		for k, flagKey in pairs(oldContentFlags) do
			local text = haveLabels and _V["WQT_TYPEFLAG_LABELS"][filterType][flagKey] or flagKey;
			otherSubmenu:CreateCheckbox(text, GenericFilterFlagChecked, GenericFilterOnSelect, { options, flagKey });
		end
	end
end

local function AddExpansionFactionsToMenu(rootDescription, expansionLevel)
	local filterType = _V["FILTER_TYPES"].faction;
	local options = WQT.settings.filters[filterType].flags;
	local order = WQT.filterOrders[filterType];
 
	local function maskFunc(flagKey) 
		if (type(flagKey) == "number") then
			local factionInfo = WQT_Utils:GetFactionDataInternal(flagKey);
			return factionInfo and factionInfo.expansion == expansionLevel;
		else
			return expansionLevel == LE_EXPANSION_LEVEL_CURRENT;
		end
	end

	rootDescription:CreateButton(CHECK_ALL, FilterTypesGeneralOnClick, {["type"] = filterType, ["value"] = true, ["maskFunc"] = maskFunc});
	rootDescription:CreateButton(UNCHECK_ALL, FilterTypesGeneralOnClick, {["type"] = filterType, ["value"] = false, ["maskFunc"] = maskFunc});

	for k, flagKey in pairs(order) do
		local factionInfo = type(flagKey) == "number" and WQT_Utils:GetFactionDataInternal(flagKey) or nil;
		if (factionInfo and factionInfo.expansion == expansionLevel and (not factionInfo.playerFaction or factionInfo.playerFaction == _playerFaction)) then
			local name = type(flagKey) == "number" and factionInfo.name or flagKey;
			rootDescription:CreateCheckbox(name, GenericFilterFlagChecked, GenericFilterOnSelect, { options, flagKey, true });
		end
	end
end

local function FilterDropdownSetup(dropdown, rootDescription)
	rootDescription:SetTag("WQT_FILTERS_DROPDOWN");

	-- Facation submenu
	local factionsSubmenu = rootDescription:CreateButton(FACTION);
	do
		AddExpansionFactionsToMenu(factionsSubmenu, LE_EXPANSION_LEVEL_CURRENT);

		local factionFilters = WQT.settings.filters[_V["FILTER_TYPES"].faction];
		-- Other factions
		local function OtherFactionsChecked()
			return factionFilters.misc.other;
		end
		local function OtherFactionsOnSelect()
			factionFilters.misc.other = not factionFilters.misc.other;
			EventRegistry:TriggerEvent("WQT.FiltersUpdated");
		end
		local cb = factionsSubmenu:CreateCheckbox(OTHER, OtherFactionsChecked, OtherFactionsOnSelect);

		-- No faction
		local function NoFactionChecked()
			return factionFilters.misc.none;
		end
		local function NoFactionOnSelect()
			factionFilters.misc.none = not factionFilters.misc.none;
			EventRegistry:TriggerEvent("WQT.FiltersUpdated");
		end
		factionsSubmenu:CreateCheckbox(_L["NO_FACTION"], NoFactionChecked, NoFactionOnSelect);

		-- Dragonflight
		local dragonflightSubmenu = factionsSubmenu:CreateButton(EXPANSION_NAME9);
		
		AddExpansionFactionsToMenu(dragonflightSubmenu, LE_EXPANSION_DRAGONFLIGHT);
		
		-- Shadowlands
		local shadowlandsSubmenu = factionsSubmenu:CreateButton(EXPANSION_NAME8);
		AddExpansionFactionsToMenu(shadowlandsSubmenu, LE_EXPANSION_SHADOWLANDS);

		-- BfA
		local bfaSubmenu = factionsSubmenu:CreateButton(EXPANSION_NAME7);
		AddExpansionFactionsToMenu(bfaSubmenu, LE_EXPANSION_BATTLE_FOR_AZEROTH);

		-- Legion
		local legionSubmenu = factionsSubmenu:CreateButton(EXPANSION_NAME6);
		AddExpansionFactionsToMenu(legionSubmenu, LE_EXPANSION_LEGION);
	end
	-- end Facation submenu

	-- Type submenu
	local typeSubmenu = rootDescription:CreateButton(TYPE);
	AddFilterSubmenu(typeSubmenu, _V["FILTER_TYPES"].type);
	
	-- Rewards submenu
	local rewardsSubmenu = rootDescription:CreateButton(REWARD);
	AddFilterSubmenu(rewardsSubmenu, _V["FILTER_TYPES"].reward);

	-- Uninterested
	local function DDUninterededChecked()
		return WQT.settings.general.showDisliked;
	end

	local function DDUninterededOnSelect()
		WQT.settings.general.showDisliked = not WQT.settings.general.showDisliked;
		EventRegistry:TriggerEvent("WQT.FiltersUpdated");
	end
	local uninterestedCB = rootDescription:CreateCheckbox(_L["UNINTERESTED"], DDUninterededChecked, DDUninterededOnSelect);
	AddBasicTooltipFunctionsToDropdownItem(uninterestedCB, _L["UNINTERESTED"], _L["UNINTERESTED_TT"]);

	-- Emisarry only filter
	local function DDEmissaryChecked()
		return WQT.settings.general.emissaryOnly;
	end

	local function DDEmissaryOnSelect()
		local value = not WQT.settings.general.emissaryOnly;
		WQT_WorldQuestFrame.autoEmisarryId = nil;
		WQT.settings.general.emissaryOnly = value;
		EventRegistry:TriggerEvent("WQT.FiltersUpdated");

		-- If we turn it off, remove the auto set as well
		if not value then
			WQT_WorldQuestFrame.autoEmisarryId = nil;
		end
	end
	local emissaryCB = rootDescription:CreateCheckbox(_L["TYPE_EMISSARY"], DDEmissaryChecked, DDEmissaryOnSelect);
	AddBasicTooltipFunctionsToDropdownItem(emissaryCB, _L["TYPE_EMISSARY"], _L["TYPE_EMISSARY_TT"]);
end

local function SettingsDropdownSetup(dropdown, rootDescription)
	rootDescription:SetTag("WQT_SETTINGS_DROPDOWN");
	-- Settings
	rootDescription:CreateButton(SETTINGS, function()
				WQT_WorldQuestFrame:ChangePanel(WQT_PanelID.Settings);
			end);
	
	-- What's new
	local newLabel = WQT.db.global.updateSeen and "" or "|TInterface\\FriendsFrame\\InformationIcon:14|t ";
	newLabel = newLabel .. _L["WHATS_NEW"];
	rootDescription:CreateButton(newLabel, function()
				WQT_WorldQuestFrame:ChangePanel(WQT_PanelID.WhatsNew);
			end);
end

local function IsSortSelected(sortID)
	return WQT.settings.general.sortBy == sortID;
end

local function SortOnSelect(sortID)
	WQT:Sort_OnClick(nil, sortID);
end

local function SortDropdownSetup(dropdown, rootDescription)
	rootDescription:SetTag("WQT_SETTINGS_DROPDOWN");

	for sortID, sortName in pairs(_V["WQT_SORT_OPTIONS"]) do
		rootDescription:CreateRadio(sortName, IsSortSelected, SortOnSelect, sortID);
	end

end

local function InitQuestButton(button, data)
	button:Update(data.questInfo, data.showZone);
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
						local infoA = C_Reputation.GetFactionDataByID(tonumber(a));
						local infoB = C_Reputation.GetFactionDataByID(tonumber(b));
						local nameA = infoA and infoA.name;
						local nameB = infoB and infoB.name;
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

local function GetNewSettingData(old, default)
	return old == nil and default or old;
end

local function ConvertOldSettings(version)
	if (not version or version == "") then
		WQT.db.global.versionCheck = "1";
		-- It's a new user, their settings are perfect
		-- Unless I change my mind again
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

	if (version < "8.3.04")  then
		-- Changes for profiles
		if (WQT.db.global.sortBy) then
			WQT.db.global.general.sortBy = WQT.db.global.sortBy;
			WQT.db.global.sortBy = nil;
		end
		if (WQT.db.global.fullScreenContainerPos) then
			WQT.db.global.general.fullScreenContainerPos = WQT.db.global.fullScreenContainerPos;
			WQT.db.global.fullScreenContainerPos = nil;
		end
		
		-- Forgot to clear this in 8.3.01
		WQT.db.global.pin.bigPoI = nil;
		WQT.db.global.pin.reward = nil; 
	end
	
	if (version < "9.0.02") then
		-- More specific options for map pins
		WQT.db.global.pin.continentVisible = WQT.db.global.pin.continentPins and _V["ENUM_PIN_CONTINENT"].all or _V["ENUM_PIN_CONTINENT"].none;
		WQT.db.global.pin.continentPins = nil;
	end

	if (version < "11.1.01") then
		-- Reworked full map button
		WQT.db.global.fullScreenButtonPos = nil;
		-- Cba to deal with this anymore
		WQT.db.global.general.useLFGButtons = nil;
		-- None of that
		WQT.db.global.general.filterPasses = nil;
	end
end

-- Display an indicator on the filter if some official map filters might hide quest
function WQT:UpdateFilterIndicator() 
	if (C_CVar.GetCVarBool("showTamers") and C_CVar.GetCVarBool("worldQuestFilterArtifactPower") and C_CVar.GetCVarBool("worldQuestFilterResources") and C_CVar.GetCVarBool("worldQuestFilterGold") and C_CVar.GetCVarBool("worldQuestFilterEquipment")) then
		--WQT_WorldQuestFrame.FilterButton.Indicator:Hide();
	else
		--WQT_WorldQuestFrame.FilterButton.Indicator:Show();
	end
end

function WQT:SetAllFilterTo(id, value, maskFunc)
	local filter = WQT.settings.filters[id];
	if (not filter) then return end;
	
	local misc = filter.misc;
	if (misc) then
		for k, v in pairs(misc) do
			if(not maskFunc or maskFunc(k)) then
				misc[k] = value;
			end
		end
	end
	
	local flags = filter.flags;
	for k, v in pairs(flags) do
		if(not maskFunc or maskFunc(k)) then
			flags[k] = value;
		end
	end
end

-- Wheter the quest is being filtered because of official map filter settings
function WQT:FilterIsWorldMapDisabled(filter)
	if (filter == "Petbattle" and not C_CVar.GetCVarBool("showTamers"))
		or (filter == "Artifact" and not C_CVar.GetCVarBool("worldQuestFilterArtifactPower"))
		or (filter == "Currency" and not C_CVar.GetCVarBool("worldQuestFilterResources"))
		or (filter == "Gold" and not C_CVar.GetCVarBool("worldQuestFilterGold"))
		or (filter == "Armor" and not C_CVar.GetCVarBool("worldQuestFilterEquipment")) then
		return true;
	end

	return false;
end

function WQT:Sort_OnClick(self, category)
	if ( category and WQT.settings.general.sortBy ~= category ) then
		WQT.settings.general.sortBy = category;
		EventRegistry:TriggerEvent("WQT.SortUpdated");
	end
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
	for flagKey, flag in pairs(flags) do
		if (WQT.settings.general.preciseFilters and flag) then
			return true;
		elseif (not WQT.settings.general.preciseFilters and not flag) then
			return true;
		end

		if (WQT_Utils:IsFilterDisabledByOfficial(flagKey)) then
			return true;
		end
	end
	return false;
end

function WQT:IsFiltering()
	if (WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then return true; end
	if (not WQT.settings.general.showDisliked) then return true; end
	
	for k, category in pairs(WQT.settings.filters)do
		if (self:IsUsingFilterNr(k)) then return true; end
	end
	return false;
end

function WQT:PassesAllFilters(questInfo)
	if (WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then 
		return questInfo:IsCriteria(WQT.settings.general.bountySelectedOnly or WQT_WorldQuestFrame.autoEmisarryId);
	end
	local filterTypes = _V["FILTER_TYPES"];

	if (not WQT.settings.general.showDisliked and questInfo:IsDisliked()) then
		return false;
	end

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
	local factionInfo = WQT_Utils:GetFactionDataInternal(questInfo.factionID);

	-- Specific filters (matches all)
	if (checkPrecise) then
		if (factionNone and questInfo.factionID) then
			return false;
		end
		if (factionOther and (not questInfo.factionID or not factionInfo.unknown)) then
			return false;
		end 
		for flagKey, value in pairs(flags) do
			if (value and type(flagKey) == "number" and flagKey ~= questInfo.factionID) then
				return false;
			end
		end
		return true;
	end
	
	-- General filters (matchs at least one)
	if (not questInfo.factionID) then return factionNone; end
	
	if (not factionInfo.unknown) then 
		-- specific faction
		return flags[questInfo.factionID];
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
	local tagInfo = questInfo:GetTagInfo();
	
	local passesPrecise = true;
	
	for flag, filterEnabled in pairs(flags) do
		local func = _V["FILTER_FUNCTIONS"][flagId] and _V["FILTER_FUNCTIONS"][flagId][flag];
		if (func) then
			local passed = func(questInfo, tagInfo)
			if (passed) then
				if (WQT_Utils:IsFilterDisabledByOfficial(flag)) then
					return false;
				end
			end

			if (filterEnabled) then
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
	
	WQT.combatLockWarned = false;

	-- Hightlight 'what's new'
	local currentVersion = C_AddOns.GetAddOnMetadata(addonName, "version")
	if (WQT.db.global.versionCheck < currentVersion) then
		WQT.db.global.updateSeen = false;
		WQT.db.global.versionCheck  = currentVersion;
	end

	-- Button on full screen map
	WQT.mapButtonsLib = LibStub("Krowi_WorldMapButtons-1.4");
	self.mapButton = WQT.mapButtonsLib:Add("WQT_WorldMapButtonTemplate", "BUTTON");

	-- Map tab and content frame
	local tabLib = LibStub("WorldMapTabsLib-1.0");
	tabLib:AddCustomTab(WQT_QuestMapTab);
	self.contentFrame = tabLib:CreateContentFrameForTab(WQT_QuestMapTab);

	
end

function WQT:OnEnable()
	-- load WorldQuestTabUtilities
	if (WQT.settings.general.loadUtilities and C_AddOns.GetAddOnEnableState(_playerName, "WorldQuestTabUtilities") > 0 and not C_AddOns.IsAddOnLoaded("WorldQuestTabUtilities")) then
		--C_AddOns.LoadAddOn("WorldQuestTabUtilities");
	end
	
	-- Place fullscreen button in saved location
	WQT_WorldMapContainer:LinkSettings(WQT.settings.general.fullScreenContainerPos);
	
	-- Apply saved filters
	if (not self.settings.general.saveFilters) then
		for k in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, true);
		end
	end

	-- Sort filters
	self.filterOrders = {};
	for k, v in pairs(WQT.settings.filters) do
		self.filterOrders[k] = GetSortedFilterOrder(k);
	end
	
	-- Show default tab depending on setting
	if (self.settings.general.defaultTab) then
		QuestMapFrame:SetDisplayMode(WQT_QuestMapTab.displayMode);
	end
	WQT_WorldQuestFrame.tabBeforeAnchor = WQT_WorldQuestFrame.selectedTab;
	
	-- Quest list scroll
	local view = CreateScrollBoxListLinearView();
	view:SetElementInitializer("WQT_QuestTemplate", function(button, elementData)
		InitQuestButton(button, elementData);
	end);
	ScrollUtil.InitScrollBoxListWithScrollBar(WQT_ListContainer.QuestScrollBox, WQT_ListContainer.ScrollBar, view);

	-- What's New Frame
	WQT_WhatsNewFrame.TitleText:SetText(_L["WHATS_NEW"]);

	ScrollUtil.InitScrollBoxWithScrollBar(WQT_WhatsNewFrame.ScrollBox, WQT_WhatsNewFrame.ScrollBar, CreateScrollBoxLinearView());

	local whatsNewContent = WQT_WhatsNewFrame.ScrollBox.ScrollContent;
	whatsNewContent.Text:SetText(_V["LATEST_UPDATE"]);
	whatsNewContent.Text:SetHeight(whatsNewContent.Text:GetContentHeight());
	whatsNewContent:SetHeight(whatsNewContent.Text:GetContentHeight());
	WQT_WhatsNewFrame.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately);

	
	-- Load settings
	WQT_SettingsFrame:Init(_V["SETTING_CATEGORIES"], _V["SETTING_LIST"]);
	
	WQT_Utils:LoadColors();
	
	-- Load externals
	self.loadableExternals = {};
	for k, external in ipairs(addon.externals) do
		if (external:IsLoaded()) then
			external:Init(WQT_Utils);
			WQT_WorldQuestFrame:RegisterEventsForExternal(external);
			WQT:debugPrint("External", external:GetName(), "loaded on first try.");
		elseif (external:IsLoadable()) then
			self.loadableExternals[external:GetName()] = external;
			WQT:debugPrint("External", external:GetName(), "waiting for load.");
		else
			WQT:debugPrint("External", external:GetName(), "not installed.");
		end
	end

	wipe(_V["SETTING_LIST"]);
	
	-- Dropdowns
	-- We need to do this after settings are available now

	-- Sorting
	WQT_ListContainer.SortDropdown:SetWidth(150);
	WQT_ListContainer.SortDropdown:SetupMenu(SortDropdownSetup);

	-- Filter
	WQT_ListContainer.FilterDropdown:SetWidth(90);
	WQT_ListContainer.FilterDropdown.Text:SetPoint("TOP", 0, 1);
	WQT_ListContainer.FilterDropdown:SetupMenu(FilterDropdownSetup);

	-- Settings
	WQT_ListContainer.SettingsDropdown:SetupMenu(SettingsDropdownSetup);

	


	self.isEnabled = true;
end

-----------------------------------------
--
--------

WQT_QuestLogSettingsButtonMixin = CreateFromMixins(QuestLogSettingsButtonMixin)

function WQT_QuestLogSettingsButtonMixin:OnMouseDown()
	if(not self.disabled) then
		QuestLogSettingsButtonMixin.OnMouseDown(self);
	end
end

function WQT_QuestLogSettingsButtonMixin:OnMouseUp()
	if(not self.disabled) then
		QuestLogSettingsButtonMixin.OnMouseUp(self);
	end
end

function WQT_QuestLogSettingsButtonMixin:OnEnable()
	self.disabled = false;
	self.Icon:SetAlpha(1);
end

function WQT_QuestLogSettingsButtonMixin:OnDisable()
	self.disabled = true;
	self.Icon:SetAlpha(0.45);
end

------------------------------------------
-- World Map Tab Mixin
------------------------------------------

WQT_TabButtonMixin = CreateFromMixins(QuestLogTabButtonMixin);

function WQT_TabButtonMixin:OnMouseUp(button, upInside)
	QuestLogTabButtonMixin.OnMouseUp(self, button, upInside);

	if (button == "LeftButton" and upInside) then
		WQT_WorldQuestFrame:ChangePanel(WQT_PanelID.Quests);
	end
end

function WQT_TabButtonMixin:SetChecked(checked)
	QuestLogTabButtonMixin.SetChecked(self, checked);

	if (checked) then
		WQT_QuestMapTab.Icon:SetSize(24, 24);
		WQT_QuestMapTab.Icon:SetAlpha(1);
	else
		WQT_QuestMapTab.Icon:SetAlpha(0.5);
		WQT_QuestMapTab.Icon:SetSize(24,24);
	end
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
	self:SetDesaturated(false);
	for k, reward in ipairs(self.rewardFrames) do
		reward:Hide();
	end
	
	self.numDisplayed = 0;
	self:SetWidth(0.1);
end

function WQT_RewardDisplayMixin:SetDesaturated(desaturate)
	self.desaturate = desaturate;
end

function WQT_RewardDisplayMixin:AddRewardByInfo(rewardInfo, warmodeBonus)
	-- A bit easier when updating buttons
	self:AddReward(rewardInfo.type, rewardInfo.texture, rewardInfo.quality, rewardInfo.amount, rewardInfo.textColor, rewardInfo.canUpgrade, warmodeBonus);
end

function WQT_RewardDisplayMixin:UpdateVisuals()
	for i = 1, self.numDisplayed do
		local rewardFrame = self.rewardFrames[i];

		rewardFrame:Show();
		rewardFrame.Icon:SetTexture(rewardFrame.texture);
		rewardFrame.Icon:SetDesaturated(self.desaturate);

		
		if (rewardFrame.quality > 1) then
			rewardFrame.QualityColor:Show()

			local r, g, b = C_Item.GetItemQualityColor(rewardFrame.quality);
			if (self.desaturate) then
				rewardFrame.QualityColor:SetVertexColor(1, 1, 1);
			else
				rewardFrame.QualityColor:SetVertexColor(r, g, b);
			end
		else
			rewardFrame.QualityColor:Hide()
		end

		if (rewardFrame.isMinor) then
			rewardFrame.Amount:Hide();
			rewardFrame.AmountBG:Hide();
		else
			local amount = rewardFrame.amount;
			if (amount > 1) then
				rewardFrame.Amount:Show();
				rewardFrame.AmountBG:Show();

				if (rewardFrame.rewardType == WQT_REWARDTYPE.gold) then
					amount = floor(amount / 10000);
				end

				local amountDisplay = GetLocalizedAbbreviatedNumber(amount);

				if (rewardFrame.rewardType == WQT_REWARDTYPE.relic) then
					amountDisplay = "+" .. amountDisplay;
				elseif (rewardFrame.canUpgrade) then
					amountDisplay = amountDisplay .. "+";
				end

				rewardFrame.Amount:SetText(amountDisplay);

				-- Color reward amount for certain types
				local r, g, b = 1, 1, 1
				if (not self.desaturate and WQT.settings.list.amountColors) then
					r, g, b = rewardFrame.typeColor:GetRGB();
				end

				rewardFrame.Amount:SetVertexColor(r, g, b);
			else
				rewardFrame.Amount:Hide();
				rewardFrame.AmountBG:Hide();
			end
		end
	end
end

function WQT_RewardDisplayMixin:AddReward(rewardType, texture, quality, amount, typeColor, canUpgrade, warmodeBonus)
	-- Limit the amount of rewards shown
	if (self.numDisplayed >= WQT.settings.list.rewardNumDisplay) then return; end
	
	self.numDisplayed = self.numDisplayed + 1;
	local num = self.numDisplayed;

	amount = amount or 1;
	-- Calculate warmode bonus
	if (warmodeBonus) then
		amount = WQT_Utils:CalculateWarmodeAmount(rewardType, amount);
	end
	
	local rewardFrame = self.rewardFrames[num];
	rewardFrame.rewardType = rewardType;
	rewardFrame.texture = texture;
	rewardFrame.quality = quality;
	rewardFrame.amount = amount;
	local _, textColor = WQT_Utils:GetRewardTypeColorIDs(rewardType);
	rewardFrame.typeColor = textColor;
	rewardFrame.canUpgrade = canUpgrade;
	
	self:UpdateVisuals();

	local minWidth = 0.01;

	if (self.Reward1:IsShown()) then
		minWidth = self.Reward1:GetWidth();
		if (self.Reward3:IsShown()) then
			minWidth = minWidth + self.Reward2:GetWidth();
			if (self.Reward4:IsShown()) then
				minWidth = minWidth + self.Reward4:GetWidth();
			end
		end
	end

	self:SetWidth(minWidth);
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
	self.UpdateTooltip = function() self:ShowTooltip() end;
	self.timer = 0;
end

function WQT_ListButtonMixin:OnClick(button)
	WQT_Utils:HandleQuestClick(self, self.questInfo, button);
end

-- Custom enable/disable
function WQT_ListButtonMixin:SetEnabledMixin(value)
	value = value==nil and true or value;
	self:SetEnabled(value);
	self:EnableMouse(value);
	self.Faction:EnableMouse(value);
end

function WQT_ListButtonMixin:OnUpdate(elapsed)
	self.timer = self.timer + elapsed;
	
	if (self.timer >= 1) then 
		self:UpdateTime();
		self.timer = 0;
	end;
end

function WQT_ListButtonMixin:UpdateTime()
	if ( not self.questInfo or not self:IsShown() or self.questInfo.seconds == 0) then
		return false;
	end

	local seconds, timeString, color, _, _, category = WQT_Utils:GetQuestTimeString(self.questInfo, WQT.settings.list.fullTime);

	if(seconds == 0) then
		self.Time:SetText("");
		return false;
	end

	if (self.questInfo:IsDisliked() or (not WQT.settings.list.colorTime and category ~= _V["TIME_REMAINING_CATEGORY"].critical)) then
		color = _V["WQT_WHITE_FONT_COLOR"];
	end
	self.Time:SetTextColor(color.r, color.g, color.b, 1);
	self.Time:SetText(timeString);
	return true;
end

function WQT_ListButtonMixin:OnLeave()
	self.Highlight:Hide();
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questID, false);
	WQT_WorldQuestFrame:HideWorldmapHighlight();
	GameTooltip:Hide();
	GameTooltip.ItemTooltip:Hide();
	
	local isDisliked = self.questInfo:IsDisliked();
	self:SetAlpha(isDisliked and 0.75 or 1);

	self.Title:SetFontObject(GameFontNormal);
	
	WQT:HideDebugTooltip()
end

function WQT_ListButtonMixin:OnEnter()
	local questInfo = self.questInfo;
	if (not questInfo) then return; end
	self.Highlight:Show();
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questID, true);
	WQT_WorldQuestFrame:ShowWorldmapHighlight(questInfo.questID);

	self.Title:SetFontObject(GameFontHighlight);
	
	self:ShowTooltip();
end

function WQT_ListButtonMixin:ShowTooltip()
	local questInfo = self.questInfo;
	if (not questInfo) then return; end
	local style = _V["TOOLTIP_STYLES"].default;

	WQT_Utils:ShowQuestTooltip(self, questInfo, style);
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)

	local typeFrame = self.Type;
	local isCriteria = questInfo:IsCriteria(WQT.settings.general.bountySelectedOnly);
	local tagInfo = questInfo:GetTagInfo();
	local isElite = tagInfo and tagInfo.isElite;
	
	typeFrame:Show();
	typeFrame:SetWidth(typeFrame:GetHeight());
	typeFrame.Texture:Show();
	typeFrame.Elite:SetShown(isElite);
	
	-- Update Icon
	local atlasTexture, sizeX, sizeY = WQT_Utils:GetCachedTypeIconData(questInfo);
	typeFrame.Texture:SetAtlas(atlasTexture);
	typeFrame.Texture:SetSize(sizeX, sizeY);
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
end

function WQT_ListButtonMixin:Update(questInfo, shouldShowZone)
	if (self.questInfo ~= questInfo) then
		self.TrackedBorder:Hide();
		self.Highlight:Hide();
		self:Hide();
	end
	
	self:Show();
	self.questInfo = questInfo;
	self.questID = questInfo.questID;
	local isDisliked = questInfo:IsDisliked();
	self:SetAlpha(isDisliked and 0.75 or 1);
	
	-- Title
	local title = questInfo.title or "Title Misisng";
	if (not questInfo.isValid) then
		title = "|cFFFF0000(Invalid) " .. title;
	elseif (not questInfo.passedFilter) then
		title = "|cFF999999(Filtered) " .. title;
	elseif (isDisliked) then
		title = "|cFF999999" .. title;
	end
	
	self.Title:SetText(title);
	
	local showedTime = self:UpdateTime();
	
	local zoneName = "";
	if (shouldShowZone and WQT.settings.list.showZone) then
		local mapInfo = WQT_Utils:GetCachedMapInfo(questInfo.mapID)
		if (mapInfo) then
			zoneName = mapInfo.name;
			if (showedTime) then
				zoneName = " - " .. zoneName;
			end
		end
	end
	
	self.Extra:SetText(zoneName);
	
	local tagQuality = questInfo:GetTagInfoQuality();

	if(tagQuality > 0) then
		self.QualityBg:Show();
		self.QualityBg:SetVertexColor(WORLD_QUEST_QUALITY_COLORS[tagQuality].color:GetRGB());
	else
		self.QualityBg:Hide();
	end
	
	-- Highlight
	local showHighLight = self:IsMouseOver() or self.Faction:IsMouseOver() or (WQT_ListContainer.PoIHoverId and WQT_ListContainer.PoIHoverId == questInfo.questID)
	self.Highlight:SetShown(showHighLight);
			
	-- Faction icon
	if (WQT.settings.list.factionIcon) then
		self.Faction:Show();
		local factionData = WQT_Utils:GetFactionDataInternal(questInfo.factionID);

		self.Faction.Icon:SetTexture(factionData.texture);
		self.Faction:SetWidth(self.Faction:GetHeight());
	else
		self.Faction:Hide();
		self.Faction:SetWidth(0.1);
	end
	self.Faction.Icon:SetDesaturated(isDisliked);
	
	-- Type icon
	if (WQT.settings.list.typeIcon) then
		self:UpdateQuestType(questInfo)
	else
		self.Type:Hide()
		self.Type:SetWidth(0.1);
	end
	self.Type.Bg:SetDesaturated(isDisliked);
	self.Type.Texture:SetDesaturated(isDisliked);
	self.Type.Elite:SetDesaturated(isDisliked);

	-- Rewards
	self.Rewards:Reset();
	self.Rewards:SetDesaturated(isDisliked);
	for k, rewardInfo in questInfo:IterateRewards() do
		self.Rewards:AddRewardByInfo(rewardInfo, C_QuestLog.QuestCanHaveWarModeBonus(self.questID));
	end

	-- Show border if quest is tracked
	local isHardWatched = WQT_Utils:QuestIsWatchedManual(questInfo.questID);
	if (isHardWatched) then
		self.TrackedBorder:Show();
	else
		self.TrackedBorder:Hide();
	end
end

function WQT_ListButtonMixin:FactionOnEnter(frame)
	self.Highlight:Show();
	if (self.questInfo.factionID) then
		local factionInfo = WQT_Utils:GetFactionDataInternal(self.questInfo.factionID);
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT", -5, -10);
		GameTooltip:SetText(factionInfo.name, nil, nil, nil, nil, true);
	end
end

------------------------------------------
-- 			SCROLLLIST MIXIN			--
------------------------------------------
--
-- OnLoad()
-- ApplySort()
-- UpdateFilterDisplay()
-- UpdateQuestList()
-- DisplayQuestList(skipPins)
-- ScrollFrameSetEnabled(enabled)

WQT_ScrollListMixin = {};

function WQT_ScrollListMixin:OnLoad()
	EventRegistry:RegisterCallback(
		"WQT.DataProvider.ProgressUpdated"
		,function(_, progress)
				CooldownFrame_SetDisplayAsPercentage(self.ProgressBar, progress);
				if (progress == 0 or progress == 1) then
					self.ProgressBar:Hide();
				end
			end
		, self);
end

function WQT_ScrollListMixin:UpdateFilterDisplay()
	local isFiltering = WQT:IsFiltering();
	WQT_ListContainer.FilterBar.ClearButton:SetShown(isFiltering);
	-- If we're not filtering, we 'hide' everything
	if not isFiltering then
		WQT_ListContainer.FilterBar.Text:SetText(""); 
		WQT_ListContainer.FilterBar:SetHeight(0.1);
		return;
	end

	local filterList = "";
	-- If we are filtering, 'show' things
	WQT_ListContainer.FilterBar:SetHeight(20);
	-- Emissary has priority
	if (WQT.settings.general.emissaryOnly or WQT_WorldQuestFrame.autoEmisarryId) then
		local text = _L["TYPE_EMISSARY"]
		if WQT_WorldQuestFrame.autoEmisarryId then
			text = GARRISON_TEMPORARY_CATEGORY_FORMAT:format(text);
		end
		
		filterList = text;	
	else
		if (not WQT.settings.general.showDisliked) then
			filterList = _L["UNINTERESTED"];
		end
	
		for k, option in pairs(WQT.settings.filters) do
			local counts = WQT:IsUsingFilterNr(k);
			if (counts) then
				filterList = filterList == "" and option.name or string.format("%s, %s", filterList, option.name);
			end
		end
	end
	
	local numHidden = 0;
	local totalValid = 0;
	for k, questInfo in ipairs(WQT_WorldQuestFrame.dataProvider:GetIterativeList()) do
		if (questInfo.isValid and questInfo.hasRewardData) then
			if (questInfo.passedFilter) then
				numHidden = numHidden + 1;
			end	
			totalValid = totalValid + 1;
		end
	end
	
	local filterFormat = "(%d/%d) "..FILTERS..": %s"
	WQT_ListContainer.FilterBar.Text:SetText(filterFormat:format(numHidden, totalValid, filterList)); 
end

function WQT_ScrollListMixin:UpdateQuestList()
	local flightShown = (FlightMapFrame and FlightMapFrame:IsShown() or TaxiRouteMap:IsShown() );
	local worldShown = WorldMapFrame:IsShown();
	
	if (not (flightShown or worldShown)) then return end	
	self:DisplayQuestList();
end

function WQT_ScrollListMixin:DisplayQuestList()
	local shouldShowZone = WQT.settings.list.showZone; 

	self:UpdateFilterDisplay();

	-- New scroll frame
	local newDataProvider = CreateDataProvider();
	
	local list = WQT_WorldQuestFrame.dataProvider.fitleredQuestsList;
	self.numDisplayed = #list;
	for index, questInfo in ipairs(list) do
		newDataProvider:Insert({index = index, questInfo = questInfo, showZone = shouldShowZone});
	end
 
	WQT_ListContainer.QuestScrollBox:SetDataProvider(newDataProvider, ScrollBoxConstants.RetainScrollPosition);
	
	-- Update background
	self:UpdateBackground();
end

function WQT_ScrollListMixin:UpdateBackground()
	local backgroundAlpha = 1;
	if (WorldMapFrame:IsShown() and WQT_WorldMapContainer:IsShown()) then
		backgroundAlpha = 0.75;
	end
	WQT_ListContainer.Background:SetAlpha(backgroundAlpha);
	WQT_WhatsNewFrame.Background:SetAlpha(backgroundAlpha);
	WQT_SettingsFrame.Background:SetAlpha(backgroundAlpha);
	if (#WQT_WorldQuestFrame.dataProvider.fitleredQuestsList == 0) then
		WQT_ListContainer.Background:SetAtlas("QuestLog-empty-quest-background", true);
	else
		WQT_ListContainer.Background:SetAtlas("QuestLog-main-background", true);
	end

	EventRegistry:TriggerEvent("WQT.ScrollList.BackgroundUpdated");
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
-- SetCvarValue(flagKey, value)
-- ChangeAnchorLocation(anchor)		Show list on a different container using _V["LIST_ANCHOR_TYPE"] variable
-- :<event> -> ADDON_LOADED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, PVP_TIMER_UPDATE, WORLD_QUEST_COMPLETED_BY_SPELL, QUEST_LOG_UPDATE, QUEST_WATCH_LIST_CHANGED

WQT_CoreMixin = {};

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
	WQT_MapZoneHightlight:ClearAllPoints();
	WQT_MapZoneHightlight:SetPoint("Center", WorldMapFrame.ScrollContainer.Child, 0.5, 0.5);
	WQT_MapZoneHightlight:SetFrameLevel(2009);
	local fileDataID, atlasID, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY = C_Map.GetMapHighlightInfoAtPosition(areaId, coords.x, coords.y);
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
			WQT_MapZoneHightlight.Texture:SetTexture(fileDataID, nil, nil, "TRILINEAR");
			textureX = textureX * width;
			textureY = textureY * height;
			if textureX > 0 and textureY > 0 then
				scrollChildX = scrollChildX * width;
				scrollChildY = -scrollChildY * height;
				WQT_MapZoneHightlight.Texture:SetWidth(textureX);
				WQT_MapZoneHightlight.Texture:SetHeight(textureY);
				WQT_MapZoneHightlight.Texture:SetPoint("TOPLEFT", WQT_MapZoneHightlight:GetParent(), "TOPLEFT", scrollChildX, scrollChildY);
				WQT_MapZoneHightlight.Texture:SetPoint("CENTER");
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
	self.WQT_Utils = WQT_Utils;
	self.variables = addon.variables;
	WQT_Profiles:OnLoad();

	-- Quest Dataprovider
	self.dataProvider = CreateAndInitFromMixin(WQT_DataProvider);

	-- Pin Dataprovider
	self.pinDataProvider = CreateAndInitFromMixin(WQT_PinDataProvider);
	self.bountyCounterPool = CreateFramePool("FRAME", self, "WQT_BountyCounterTemplate");
	
	self:SetFrameLevel(self:GetParent():GetFrameLevel()+4);

	-- Hide the little detail at the top of the frame, it blocks our view. Thanks for making that a separate texture
	WQT_ListContainer.BorderFrame.TopDetail:Hide();

	EventRegistry:RegisterCallback(
		"WQT.DataProvider.FilteredListUpdated"
		,function()
				self.ScrollFrame:UpdateQuestList(); 
			end
		, self);

	self.ExternalEvents = {};
	-- Events
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PVP_TIMER_UPDATE"); -- Warmode toggle because WAR_MODE_STATUS_UPDATE doesn't seems to fire when toggling warmode
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("TAXIMAP_OPENED");
	self:RegisterEvent("PLAYER_LOGOUT");

	self:SetScript("OnEvent", function(self, event, ...)
			if (self[event]) then 
				self[event](self, ...);
			elseif (not self.ExternalEvents[event]) then
				WQT:debugPrint("WQT missing function for:",event);
			end 

			EventRegistry:TriggerEvent("WQT.RegisterdEventTriggered", event, ...);
		end)

	-- Slashcommands
	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd
	
	--
	-- Function hooks
	-- 

	-- Update when opening the map
	WorldMapFrame:HookScript("OnShow", function()
			-- If emissaryOnly was automaticaly set, turn it off again.
			if (WQT_WorldQuestFrame.autoEmisarryId) then
				WQT_WorldQuestFrame.autoEmisarryId = nil;
				WQT_ListContainer:UpdateQuestList();
			end
		end)

	-- Go back to quest list when closing map
	WorldMapFrame:HookScript("OnHide", function()
			WQT_WorldQuestFrame:ChangePanel(WQT_PanelID.Quests);
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

	-- Auto emisarry when clicking on one of the buttons
	local bountyBoard = WQT_Utils:GetOldBountyBoard();
	hooksecurefunc(bountyBoard, "OnTabClick", function(self, tab)
		if (not WQT.settings.general.autoEmisarry or tab.isEmpty or WQT.settings.general.emissaryOnly) then return; end
		WQT_WorldQuestFrame.autoEmisarryId = bountyBoard.bounties[tab.bountyIndex];
		WQT_ListContainer:UpdateQuestList();
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

	-- Auto emisarry when selecting a bounty
	local activityBoard = WQT_Utils:GetNewBountyBoard();
	hooksecurefunc(activityBoard, "SetNextMapForSelectedBounty", function()
		if (not WQT.settings.general.autoEmisarry or WQT.settings.general.emissaryOnly or not activityBoard.selectedBounty) then return; end
		WQT_WorldQuestFrame.autoEmisarryId = activityBoard.selectedBounty.factionID;
		WQT_ListContainer:UpdateQuestList();
	end)
	
	hooksecurefunc("TaskPOI_OnLeave", function(self)
			if (WQT.settings.pin.disablePoI) then return; end
			
			WQT_ListContainer.PoIHoverId = -1;
			WQT_ListContainer:UpdateQuestList(true);
			self.notTracked = nil;
		end)

	QuestMapFrame.QuestSessionManagement:HookScript("OnShow", function() 
			if(self:IsShown()) then
				QuestMapFrame.QuestSessionManagement:Hide();
			end
		end);
end

function WQT_CoreMixin:RegisterEventsForExternal(external)
	if (not external.GetRequiredEvents or not external.GetName) then return end;

	for k, event in pairs(external:GetRequiredEvents()) do
		if (self:RegisterEvent(event)) then
			self.ExternalEvents[event] = true;
			WQT:debugPrint("Registered new event", event, "for external", external:GetName());
		end
	end
end

function WQT_CoreMixin:ApplyAllSettings()
	self:UpdateBountyCounters();
	self:RepositionBountyTabs();
	self.pinDataProvider:RefreshAllData()
	WQT_ListContainer:UpdateQuestList();
	WQT:Sort_OnClick(nil, WQT.settings.general.sortBy);
	WQT_WorldMapContainer:LinkSettings(WQT.settings.general.fullScreenContainerPos);
end

function WQT_CoreMixin:UpdateBountyCounters()
	self.bountyCounterPool:ReleaseAll();
	if (not WQT.settings.general.bountyCounter) then return end
	
	if (not self.bountyInfo) then
		self.bountyInfo = {};
	end
	
	local bountyBoard = WQT_Utils:GetOldBountyBoard();
	for tab, v in bountyBoard.bountyTabPool:EnumerateActive() do
		self:AddBountyCountersToTab(tab);
	end
end

function WQT_CoreMixin:RepositionBountyTabs()
	local bountyBoard = WQT_Utils:GetOldBountyBoard();
	for tab, v in bountyBoard.bountyTabPool:EnumerateActive() do
		bountyBoard:AnchorBountyTab(tab);
	end
end

function WQT_CoreMixin:AddBountyCountersToTab(tab)
	local settingBountyReward = WQT_Utils:GetSetting("general", "bountyReward");

	if (not tab.WQT_Reward) then
		tab.WQT_Reward = CreateFrame("FRAME", nil, tab, "WQT_MiniIconTemplate");
		tab.WQT_Reward:SetPoint("CENTER", tab, "TOPRIGHT", -8, -7);
	end
	tab.WQT_Reward:Reset();
	
	local bountyBoard = WQT_Utils:GetOldBountyBoard();
	local bountyData = bountyBoard.bounties[tab.bountyIndex];
	
	if (bountyData) then
		local progress, goal = bountyBoard:CalculateBountySubObjectives(bountyData);
		
		if (progress == goal) then return end;
		
		-- RewardIcon
		if (settingBountyReward) then
			local bountyQuestInfo = self.bountyInfo[bountyData.questID];
			if (not bountyQuestInfo) then
				bountyQuestInfo = WQT_Utils:QuestCreationFunc();
				self.bountyInfo[bountyData.questID] = bountyQuestInfo;
				bountyQuestInfo:Init(bountyData.questID);
			end
			bountyQuestInfo:LoadRewards();
			tab.WQT_Reward:SetupRewardIcon(bountyQuestInfo:GetFirstNoneAzeriteType());
			tab.WQT_Reward:SetScale(1.38);
		end
		
		-- Counters
		local offsetAngle = 32;
		local startAngle = 270;
		
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
				counter.icon:SetVertexColor(0.75, 0.75, 0.75, 1);
				counter.icon:SetDesaturated(true);
			end

			-- Offset next counter
			startAngle = startAngle + offsetAngle;
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
	if WQT_WorldQuestFrame.autoEmisarryId then
		WQT_WorldQuestFrame.autoEmisarryId = nil;
	elseif WQT.settings.general.emissaryOnly then
		WQT.settings.general.emissaryOnly = false;
	else
		for k, v in pairs(WQT.settings.filters) do
			local default = not WQT.settings.general.preciseFilters;
			WQT:SetAllFilterTo(k, default);
		end

		for _, cvars in pairs(_V["WQT_FILTER_TO_OFFICIAL"]) do
			for _, cvar in ipairs(cvars) do
				C_CVar.SetCVar(cvar, 1);
			end
		end

		local filterButton = WQT_Utils:GetWoldMapFilterButton();
		if (filterButton) then
			filterButton:RefreshFilterCounter();
			filterButton:ValidateResetState();
		end
	end
	
	WQT.settings.general.showDisliked = true;
	
	EventRegistry:TriggerEvent("WQT.FiltersUpdated");
end

function WQT_CoreMixin:UnhookEvent(event, func)
	local list = self.eventHooks[event];
	if (list) then
		list[func] = nil;
	end
end

function WQT_CoreMixin:ADDON_LOADED(loaded)
	WQT:UpdateFilterIndicator();
	if (loaded == "Blizzard_FlightMap") then
		-- Add dataprovider to hide official pins
		FlightMapFrame:AddDataProvider(CreateFromMixins(WQT_OfficialPinSuppressorProviderMixin));

		WQT_FlightMapContainer:SetParent(FlightMapFrame);
		WQT_FlightMapContainer:SetPoint("BOTTOMLEFT", FlightMapFrame, "BOTTOMRIGHT", -7, 0);
		WQT_FlightMapContainerButton:SetParent(FlightMapFrame);
		WQT_FlightMapContainerButton:SetAlpha(1);
		WQT_FlightMapContainerButton:SetPoint("BOTTOMRIGHT", FlightMapFrame, "BOTTOMRIGHT", -8, 8);
		WQT_FlightMapContainerButton:SetFrameLevel(FlightMapFrame:GetFrameLevel()+2);
	elseif (loaded == "WorldQuestTabUtilities") then
		WQT.settings.general.loadUtilities = true;
	end
	
	-- Load waiting externals
	if (WQT.loadableExternals) then
		local external = WQT.loadableExternals[loaded];
		if (external) then
			external:Init(WQT_Utils);
			self:RegisterEventsForExternal(external);
			WQT:debugPrint("External", external:GetName(), "delayed load.");
			WQT.loadableExternals[loaded] = nil;
		end
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	WQT.combatLockWarned = false;
	WQT_ListContainer.SettingsDropdown:SetEnabled(false)
	self:ChangePanel(WQT_PanelID.Quests);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	WQT.combatLockWarned = false;
	WQT_ListContainer.SettingsDropdown:SetEnabled(true)
end

 -- Warmode toggle because WAR_MODE_STATUS_UPDATE doesn't seems to fire when toggling warmode
function WQT_CoreMixin:PVP_TIMER_UPDATE()
	self.ScrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:PLAYER_LOGOUT()
	WQT_Profiles:ClearDefaultsFromActive();
end

function WQT_CoreMixin:QUEST_WATCH_LIST_CHANGED(...)
	self.ScrollFrame:DisplayQuestList();
end

function WQT_CoreMixin:TAXIMAP_OPENED(system)
	local anchor = _V["LIST_ANCHOR_TYPE"].taxi;
	if (system == 2) then
		-- It's the new flight map
		anchor = _V["LIST_ANCHOR_TYPE"].flight;
	end
	
	WQT_WorldQuestFrame:ChangeAnchorLocation(anchor);
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

function WQT_CoreMixin:ChangePanel(panelID)
	if (panelID == WQT_PanelID.WhatsNew) then
		WQT.db.global.updateSeen = true;
	end

	for k, panel in ipairs(self.panels) do
		panel:SetShown(panel.panelID == panelID);
	end
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

	WQT_WorldMapContainer:Hide();
	local showMapContainer = false;
	WQT.mapButton:SetShown(anchor == _V["LIST_ANCHOR_TYPE"].full);
	-- Changing map to full screen doesn't call refresh on the buttons
	WQT.mapButtonsLib:SetPoints();

	if (anchor == _V["LIST_ANCHOR_TYPE"].flight) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetParent(WQT_FlightMapContainer);
		WQT_WorldQuestFrame:SetPoint("TOPLEFT", WQT_FlightMapContainer, 10, -56);
		WQT_WorldQuestFrame:SetPoint("BOTTOMRIGHT", WQT_FlightMapContainer, -28, 12);
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].taxi) then
		-- Exists in frame data but no longer used?
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].world) then
		WQT_WorldQuestFrame:ClearAllPoints();
		WQT_WorldQuestFrame:SetParent(WQT.contentFrame);
		WQT_WorldQuestFrame:SetPoint("TOPLEFT", WQT.contentFrame, 0, -29);
		WQT_WorldQuestFrame:SetPoint("BOTTOMRIGHT", WQT.contentFrame, -22, 9);
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].full) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetParent(WQT_WorldMapContainer);
		WQT_WorldQuestFrame:SetPoint("TOPLEFT", WQT_WorldMapContainer, 14, -56);
		WQT_WorldQuestFrame:SetPoint("BOTTOMRIGHT", WQT_WorldMapContainer, -28, 12);
		WQT_WorldMapContainer:ConstrainPosition();
		showMapContainer = WQT.mapButton.isSelected;
	end

	WQT_WorldMapContainer:SetShown(showMapContainer);

	EventRegistry:TriggerEvent("WQT.CoreFrame.AnchorUpdated", anchor);
end

function WQT_CoreMixin:LoadExternal(external)
	if (self.isEnabled and external:IsLoaded()) then
		external:Init(WQT_Utils);
	else
		tinsert(addon.externals, external);
	end
end


