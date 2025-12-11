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
local WQT_Profiles = addon.WQT_Profiles;

local _; -- local trash 

local _playerFaction = GetPlayerFactionGroup();
local _playerName = UnitName("player");

WQT_PanelID = EnumUtil.MakeEnum("Quests", "Settings");

local function slashcmd(msg)
	if (msg == "debug") then
		addon.debug = not addon.debug;
		WQT_ListContainer:UpdateQuestList();
		print("WQT: debug", addon.debug and "enabled" or "disabled");
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
	WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
	return MenuResponse.Refresh;
end

local function GenericFilterFlagChecked(data)
	local flagKey = data[2];

	if (WQT_Utils:IsFilterDisabledByOfficial(flagKey)) then
		return false;
	end

	local options = data[1];
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
	WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
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
			WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
		end
		local cb = factionsSubmenu:CreateCheckbox(OTHER, OtherFactionsChecked, OtherFactionsOnSelect);

		-- No faction
		local function NoFactionChecked()
			return factionFilters.misc.none;
		end
		local function NoFactionOnSelect()
			factionFilters.misc.none = not factionFilters.misc.none;
			WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
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
		WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
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
		WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");

		-- If we turn it off, remove the auto set as well
		if not value then
			WQT_WorldQuestFrame.autoEmisarryId = nil;
		end
	end
	local emissaryCB = rootDescription:CreateCheckbox(_L["TYPE_EMISSARY"], DDEmissaryChecked, DDEmissaryOnSelect);
	AddBasicTooltipFunctionsToDropdownItem(emissaryCB, _L["TYPE_EMISSARY"], _L["TYPE_EMISSARY_TT"]);
end

-----------------------------------------
-- WQT_SortingDataContainer
-----------------------------------------

WQT_SortingDataContainer = {};

function WQT_SortingDataContainer:Init()
	self.sortFunctions = {};
	self.sortOptions = {};
end

function WQT_SortingDataContainer:AddSortFunction(functionID, func)
	if (self.sortFunctions[functionID]) then
		error("Trying to add sort function to a ID that already exists: " .. functionID);
	end

	self.sortFunctions[functionID] = func;
end

function WQT_SortingDataContainer:AddSortOption(sortID, label, functionIDs)
	if (type(functionIDs) ~= "table") then
		error("functionIDs must be a table of function IDs");
	end
	if (self:GetSortOptionByID(sortID)) then
		error("Trying to add sort function to an ID that already exists: " .. sortID);
	end

	for k, functionID in ipairs(functionIDs) do
		if (not self.sortFunctions[functionID]) then
			error("List contains function tag that does not have a matching function registered: " .. functionID);
		end
	end

	local data = {
		sortID = sortID;
		label = label;
		functionIDs = functionIDs;
	};

	tinsert(self.sortOptions, data);
end

function WQT_SortingDataContainer:EnumerateOptions()
	return ipairs(self.sortOptions);
end

function WQT_SortingDataContainer:GetSortOptionByID(sortID)
	for k, data in self:EnumerateOptions() do
		if (data.sortID == sortID) then
			return data;
		end
	end

	return nil;
end

function WQT_SortingDataContainer:GetSortLabel(sortID)
	local sortData = self:GetSortOptionByID(sortID);
	return sortData and sortData.label or "Invalid Label";
end

function WQT_SortingDataContainer:SortQuests(sortID, questInfoA, questInfoB)
	local sortData = self:GetSortOptionByID(sortID);
	if (not sortData) then
		WQT:DebugPrint("SortQuests - SortID not found:", sortID);
		return false;
	end

	for k, functionID in ipairs(sortData.functionIDs) do
		local sortFunction = self.sortFunctions[functionID];
		
		if (sortFunction) then
			local result = sortFunction(questInfoA, questInfoB);
			if (result ~= nil) then
				return result;
			end
		else
			WQT:DebugPrint("SortQuests - functionID not found:", functionID);
		end
	end

	return nil;
end

-----------------------------------------
-- Filtering stuff
-----------------------------------------

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

function WQT:Sort_OnClick(self, sortID)
	if (sortID and WQT.settings.general.sortBy ~= sortID) then
		WQT.settings.general.sortBy = sortID;
		WQT_CallbackRegistry:TriggerEvent("WQT.SortUpdated", sortID);
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
	WQT_Profiles:InitSettings();
	
	WQT.combatLockWarned = false;

	local settingsVersion = WQT_Utils:GetSettingsVersion();
	local currentVersion = WQT_Utils:GetAddonVersion();
	if (settingsVersion < currentVersion) then
		WQT.db.global.updateSeen = false;
		WQT.db.global.versionCheck  = currentVersion;
	end

	-- Button on full screen map
	WQT.mapButtonsLib = LibStub("Krowi_WorldMapButtons-1.4");
	self.mapButton = WQT.mapButtonsLib:Add("WQT_WorldMapButtonTemplate", "BUTTON");

	-- Map tab and content frame
	self.tabLib = LibStub("LibWorldMapTabs");
	self.tabLib:AddCustomTab(WQT_QuestMapTab);
	self.contentFrame = self.tabLib:CreateContentFrameForTab(WQT_QuestMapTab);

	-- Sorting
	self.sortDataContainer = CreateAndInitFromMixin(WQT_SortingDataContainer);
	
	local SortFunctionTags = {
		rewardType = "rewardType",
		rewardQuality = "rewardQuality",
		canUpgrade = "canUpgrade",
		seconds = "seconds",
		rewardAmount = "rewardAmount",
		rewardId = "rewardId",
		faction = "faction",
		questType = "questType",
		questRarity = "questRarity",
		title = "title",
		elite = "elite",
		criteria = "criteria",
		zone = "zone",
		numRewards = "numRewards",
	}

	-- Sorting functions
	do -- rewardType
		local func = function(a, b)
			local aType, aSubType = a:GetRewardType();
			local bType, bSubType = b:GetRewardType();
			if (aType and bType and aType ~= bType) then
				if (aType == WQT_REWARDTYPE.none or bType == WQT_REWARDTYPE.none) then
					return aType > bType;
				end
				return aType < bType;
			elseif (aType == bType and aSubType and bSubType) then
				return aSubType < bSubType;
			end
		end;
		self.sortDataContainer:AddSortFunction(SortFunctionTags.rewardType, func);
	end
	do -- rewardQuality
		local func = function(a, b)
			local aQuality = a:GetRewardQuality();
			local bQuality = b:GetRewardQuality();
			if (not aQuality or not bQuality) then
				return aQuality and not bQuality;
			end

			if (aQuality and bQuality and aQuality ~= bQuality) then
				return aQuality > bQuality;
			end
		end;
		self.sortDataContainer:AddSortFunction(SortFunctionTags.rewardQuality, func);
	end
	do -- canUpgrade
		local func = function(a, b)
			local aCanUpgrade = a:GetRewardCanUpgrade();
			local bCanUpgrade = b:GetRewardCanUpgrade();
			if (aCanUpgrade and bCanUpgrade and aCanUpgrade ~= bCanUpgrade) then
				return aCanUpgrade and not bCanUpgrade;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.canUpgrade, func);
	end
	do -- seconds
		local func = function(a, b)
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end

			if (a.time.seconds ~= b.time.seconds) then
				return a.time.seconds < b.time.seconds;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.seconds, func);
	end
	do -- rewardAmount
		local func = function(a, b)
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end

			local amountA = a:GetRewardAmount(C_QuestLog.QuestCanHaveWarModeBonus(a.questID));
			local amountB = b:GetRewardAmount(C_QuestLog.QuestCanHaveWarModeBonus(b.questID));

			if (amountA ~= amountB) then
				return amountA > amountB;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.rewardAmount, func);
	end
	do -- rewardId
		local func = function(a, b)
			local aId = a:GetRewardId();
			local bId = b:GetRewardId();
			if (aId and bId and aId ~= bId) then
				return aId < bId;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.rewardId, func);
	end
	do -- faction
		local func = function(a, b)
			if (a.factionID ~= b.factionID) then
				if (not a.factionID or not b.factionID) then
					return b.factionID == nil;
				end

				local factionA = WQT_Utils:GetFactionDataInternal(a.factionID);
				local factionB = WQT_Utils:GetFactionDataInternal(b.factionID);
				return factionA.name < factionB.name;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.faction, func);
	end
	do -- questType
		local func = function(a, b)
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end

			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			if (tagInfoA and tagInfoB and tagInfoA.worldQuestType and tagInfoB.worldQuestType and tagInfoA.worldQuestType ~= tagInfoB.worldQuestType) then
				return tagInfoA.worldQuestType > tagInfoB.worldQuestType;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.questType, func);
	end
	do -- questRarity
		local func = function(a, b)
			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			if (tagInfoA and tagInfoB and tagInfoA.quality and tagInfoB.quality and tagInfoA.quality ~= tagInfoB.quality) then
				return tagInfoA.quality > tagInfoB.quality;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.questRarity, func);
	end
	do -- title
		local func = function(a, b)
			if (a.title ~= b.title) then
				return a.title < b.title;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.title, func);
	end
	do -- elite
		local func = function(a, b)
			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			local aIsElite = tagInfoA and tagInfoA.isElite;
			local bIsElite = tagInfoB and tagInfoB.isElite;
			if (aIsElite ~= bIsElite) then
				return aIsElite and not bIsElite;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.elite, func);
	end
	do -- criteria
		local func = function(a, b)
			local aIsCriteria = a:IsCriteria(WQT.settings.general.bountySelectedOnly);
			local bIsCriteria = b:IsCriteria(WQT.settings.general.bountySelectedOnly);
			if (aIsCriteria ~= bIsCriteria) then return aIsCriteria and not bIsCriteria; end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.criteria, func);
	end
	do -- zone
		local func = function(a, b)
			local mapInfoA = WQT_Utils:GetCachedMapInfo(a.mapID);
			local mapInfoB = WQT_Utils:GetCachedMapInfo(b.mapID);
			if (not mapInfoA or not mapInfoB) then
				return mapInfoA;
			end

			if (mapInfoA and mapInfoA.name and mapInfoB and mapInfoB.name and mapInfoA.mapID ~= mapInfoB.mapID) then
				if (mapInfoA.mapID == WorldMapFrame.mapID or mapInfoB.mapID == WorldMapFrame.mapID) then
					return mapInfoA.mapID == WorldMapFrame.mapID;
				end
				return mapInfoA.name < mapInfoB.name;
			elseif (mapInfoA.mapID == mapInfoB.mapID) then
				if (a.isBonusQuest ~= b.isBonusQuest) then
					return b.isBonusQuest;
				end
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.zone, func);
	end
	do -- numRewards
		local func = function(a, b)
			local aNumRewards = #a.rewardList;
			local bNumRewards = #b.rewardList;
			if (aNumRewards ~= bNumRewards) then
				return aNumRewards > bNumRewards;
			end
		end
		self.sortDataContainer:AddSortFunction(SortFunctionTags.numRewards, func);
	end

	-- Sorting options
	do -- reward
		local functionTags = {
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].reward, REWARD, functionTags);
	end
	do -- time
		local functionTags = {
			SortFunctionTags.seconds,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].time, _L["TIME"], functionTags);
	end
	do -- faction
		local functionTags = {
			SortFunctionTags.faction,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].faction, FACTION, functionTags);
	end
	do -- zone
		local functionTags = {
			SortFunctionTags.zone,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].zone, ZONE, functionTags);
	end
	do -- type
		local functionTags = {
			SortFunctionTags.criteria,
			SortFunctionTags.questType,
			SortFunctionTags.questRarity,
			SortFunctionTags.elite,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].type, TYPE, functionTags);
	end
	do -- name
		local functionTags = {
			SortFunctionTags.title,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].name, NAME, functionTags);
	end
	do -- quality
		local functionTags = {
			SortFunctionTags.rewardQuality,
			SortFunctionTags.rewardType,
			SortFunctionTags.rewardAmount,
			SortFunctionTags.numRewards,
			SortFunctionTags.canUpgrade,
			SortFunctionTags.rewardId,
			SortFunctionTags.seconds,
			SortFunctionTags.title,
		}
		self.sortDataContainer:AddSortOption(_V["SORT_IDS"].quality, QUALITY, functionTags);
	end
end

function WQT:OnEnable()
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
		self.tabLib:SetDisplayMode(WQT_QuestMapTab.displayMode);
	end
	WQT_WorldQuestFrame.tabBeforeAnchor = WQT_WorldQuestFrame.selectedTab;
	self.tabLib = nil;

	-- Load settings
	WQT_SettingsFrame:Init();
	
	WQT_Utils:LoadColors();

	if (self.externals) then
		for k, external in ipairs(self.externals) do
			local name = external:GetName();
			WQT:DebugPrint("Setting up external load:", name);
			EventUtil.ContinueOnAddOnLoaded(name, function()
				WQT:DebugPrint("Initializing external:", name);
				external:Init(WQT_Utils);
				WQT_WorldQuestFrame:RegisterEventsForExternal(external);
			end);
		end
	end

	self.externals = nil;

	if (self.callbacksWhenReady) then
		for k, data in ipairs(self.callbacksWhenReady) do
			data.callback(data.owner);
		end
		self.callbacksWhenReady = nil;
	end

	self.isReady = true;
end

function WQT:CallbackWhenReady(callback, owner)
	if (self.isReady) then
		callback();
		return;
	end

	if (not self.callbacksWhenReady) then
		self.callbacksWhenReady = {};
	end

	local data = {
		callback = callback;
		owner = owner;
	}
	table.insert(self.callbacksWhenReady, data);
end

do
	local function IsSortSelected(sortID)
		return WQT.settings.general.sortBy == sortID;
	end

	local function SortOnSelect(sortID)
		WQT:Sort_OnClick(nil, sortID);
	end

	function WQT:SortDropdownSetup(rootDescription)
		rootDescription:SetTag("WQT_SETTINGS_DROPDOWN");

		for k, data in WQT.sortDataContainer:EnumerateOptions() do
			rootDescription:CreateRadio(data.label, IsSortSelected, SortOnSelect, data.sortID);
		end
	end
end


function WQT:AddExternal(external)
	if (not self.externals) then
		self.externals = {};
	end

	tinsert(self.externals, external);
end

-----------------------------------------
--
--------

WQT_QuestLogSettingsButtonMixin = {};

function WQT_QuestLogSettingsButtonMixin:OnMouseDown()
	if(not self.disabled) then
		self.Icon:AdjustPointsOffset(1, -1);
	end
end

function WQT_QuestLogSettingsButtonMixin:OnMouseUp()
	if(not self.disabled) then
		self.Icon:AdjustPointsOffset(-1, 1);
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

WQT_TabButtonMixin = CreateFromMixins(SidePanelTabButtonMixin);

function WQT_TabButtonMixin:OnMouseUp(button, upInside)
	SidePanelTabButtonMixin.OnMouseUp(self, button, upInside);

	if (button == "LeftButton" and upInside) then
		WQT_WorldQuestFrame:ChangePanel(WQT_PanelID.Quests);
	end
end

function WQT_TabButtonMixin:SetChecked(checked)
	SidePanelTabButtonMixin.SetChecked(self, checked);

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

WQT_RewardDisplayMixin = {};

function WQT_RewardDisplayMixin:GetRewardFrame(index)
	if(index <= 0 or index > #self.rewardFrames) then return nil; end

	return self.rewardFrames[index];
end

function WQT_RewardDisplayMixin:UpdateRewards(questInfo, warmodeBonus)
	local layoutChanged = false;
	local isDisliked = questInfo:IsDisliked();
	local maxRewardsToShow = min(WQT.settings.list.rewardNumDisplay, #self.rewardFrames);
	local numDisplayed = 0;

	for i = 1, #self.rewardFrames, 1 do
		local rewardFrame = self:GetRewardFrame(i);
		if (rewardFrame) then
			local show = false;
			if (i <= maxRewardsToShow) then
				local rewardInfo = questInfo:GetReward(i);
				if (rewardInfo) then
					show = true;
					rewardFrame.Icon:SetTexture(rewardInfo.texture);
					rewardFrame.Icon:SetDesaturated(isDisliked);

					if (rewardInfo.quality > 1) then
						rewardFrame.QualityColor:Show()

						local r, g, b = 1, 1, 1;
						if (not isDisliked) then
							r, g, b = C_Item.GetItemQualityColor(rewardInfo.quality);
						end
						rewardFrame.QualityColor:SetVertexColor(r, g, b);
					else
						rewardFrame.QualityColor:Hide()
					end

					local displayAmount, rawAmount = WQT_Utils:GetDisplayRewardAmount(rewardInfo, warmodeBonus)
					local showAmount = not rewardFrame.hideAmount and rawAmount > 1;
					rewardFrame.Amount:SetShown(showAmount);
					rewardFrame.AmountBG:SetShown(showAmount);

					if (showAmount) then
						rewardFrame.Amount:Show();
						rewardFrame.AmountBG:Show();

						rewardFrame.Amount:SetText(displayAmount);

						-- Color reward amount for certain types
						local amountColor = _V["WQT_WHITE_FONT_COLOR"];
						if (not isDisliked and WQT.settings.list.amountColors) then
							amountColor = select(2, WQT_Utils:GetRewardTypeColorIDs(rewardInfo.type));
						end
						
						rewardFrame.Amount:SetVertexColor(amountColor:GetRGB());
					end

					numDisplayed = numDisplayed + 1;
				end
			end
			if (show ~= rewardFrame:IsShown()) then
				layoutChanged = true;
			end
			rewardFrame:SetShown(show);
		end
	end

	return layoutChanged;
end

------------------------------------------
-- 			LISTBUTTON MIXIN			--
------------------------------------------

WQT_ListButtonMixin = {}

function WQT_ListButtonMixin:ClearTimer()
	if (self.timer) then
		self.timer:Cancel();
		self.timer = nil;
	end
end

function WQT_ListButtonMixin:GetTitleFontString()
	return self.CenterContent.Title;
end

function WQT_ListButtonMixin:GetTimeFontString()
	return self.CenterContent.BottomRow.Time;
end

function WQT_ListButtonMixin:GetBottomRow()
	return self.CenterContent.BottomRow;
end

function WQT_ListButtonMixin:GetZoneFontString()
	return self:GetBottomRow().Extra;
end

function WQT_ListButtonMixin:GetZoneSeparator()
	return self:GetBottomRow().ZoneSeparator;
end

function WQT_ListButtonMixin:GetWarbandIcon()
	return self.RightContent.WarbandIcon;
end

function WQT_ListButtonMixin:GetFactionFrame()
	return self.RightContent.Faction;
end

function WQT_ListButtonMixin:GetRewardsFrame()
	return self.RightContent.Rewards;
end

function WQT_ListButtonMixin:OnLoad()
	self.TrackedBorder:SetFrameLevel(self:GetFrameLevel() + 2);
	self.Highlight:SetFrameLevel(self:GetFrameLevel() + 2);
	self:EnableKeyboard(false);
	self.UpdateTooltip = function() self:ShowTooltip() end;
end

function WQT_ListButtonMixin:OnClick(button)
	WQT_Utils:HandleQuestClick(self, self.questInfo, button);
end

-- Custom enable/disable
function WQT_ListButtonMixin:SetEnabledMixin(value)
	value = value==nil and true or value;
	self:SetEnabled(value);
	self:EnableMouse(value);
	local factionFrame = self:GetFactionFrame();
	factionFrame:EnableMouse(value);
end

function WQT_ListButtonMixin:UpdateTime(...)
	self:ClearTimer();
	if ( not self.questInfo or not self:IsShown() or self.questInfo.seconds == 0) then
		return false;
	end

	local timeFrame = self:GetTimeFontString();
	local seconds, timeString, color, _, _, category = WQT_Utils:GetQuestTimeString(self.questInfo, WQT.settings.list.fullTime);
	
	if(seconds == 0) then
		timeFrame:SetText("");
		timeFrame:Hide();
	else
		timeFrame:Show();

		if (self.questInfo:IsDisliked() or (not WQT.settings.list.colorTime and category ~= _V["TIME_REMAINING_CATEGORY"].critical)) then
			color = _V["WQT_WHITE_FONT_COLOR"];
		end
		timeFrame:SetTextColor(color.r, color.g, color.b, 1);
		timeFrame:SetText(timeString);
	end

	
	local zoneSeparator = self:GetZoneSeparator();
	zoneSeparator:SetShown(self:GetZoneFontString():IsShown() and timeFrame:IsShown());

	-- Updating time changes its size so we need to make sure everything on the bottom row shifts with it
	self:GetBottomRow():Layout();

	local showingSecondary = WQT_Utils:GetSetting("list", "fullTime");
	local timerInterval = WQT_Utils:TimeLeftToUpdateTime(seconds, showingSecondary);
	if (timerInterval > 0) then
		self.timer = C_Timer.NewTimer(timerInterval, function() self:UpdateTime() end);
	end

	return seconds;
end

function WQT_ListButtonMixin:OnLeave()
	self.Highlight:Hide();
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questID, false);
	WQT_WorldQuestFrame:HideWorldmapHighlight();
	GameTooltip:Hide();
	GameTooltip.ItemTooltip:Hide();
	
	local isDisliked = self.questInfo:IsDisliked();
	self:SetAlpha(isDisliked and 0.75 or 1);

	local difficultyColor = GetDifficultyColor(Enum.RelativeContentDifficulty.Fair);
	local titleFS = self:GetTitleFontString();
	titleFS:SetTextColor(difficultyColor.r, difficultyColor.g, difficultyColor.b);

	WQT:HideDebugTooltip()
end

function WQT_ListButtonMixin:OnEnter()
	if (not self.questInfo) then return; end
	self.Highlight:Show();
	WQT_WorldQuestFrame.pinDataProvider:SetQuestIDPinged(self.questInfo.questID, true);
	WQT_WorldQuestFrame:ShowWorldmapHighlight(self.questInfo);

	local difficultyColor = select(2, GetDifficultyColor(Enum.RelativeContentDifficulty.Fair));
	local titleFS = self:GetTitleFontString();
	titleFS:SetTextColor(difficultyColor.r, difficultyColor.g, difficultyColor.b);

	self:ShowTooltip();
end

function WQT_ListButtonMixin:ShowTooltip()
	local questInfo = self.questInfo;
	if (not questInfo) then return; end
	local style = _V["TOOLTIP_STYLES"].default;

	WQT_Utils:ShowQuestTooltip(self, questInfo, style, 4, -self:GetHeight());
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)
	local typeFrame = self.Type;
	local wasShown = typeFrame:IsShown();
	local shouldShow = WQT.settings.list.typeIcon;
	local needsLayout = wasShown ~= shouldShow;

	typeFrame:SetShown(shouldShow);
	if (shouldShow) then
		local isDisliked = questInfo:IsDisliked();
		typeFrame.Bg:SetDesaturated(isDisliked);
		typeFrame.Texture:SetDesaturated(isDisliked);
		typeFrame.Elite:SetDesaturated(isDisliked);

		local isCriteria = questInfo:IsCriteria(WQT.settings.general.bountySelectedOnly);
		local tagInfo = questInfo:GetTagInfo();
		local isElite = tagInfo and tagInfo.isElite;
		
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

	return needsLayout;
end

function WQT_ListButtonMixin:Update(questInfo, shouldShowZone)
	if (self.questInfo ~= questInfo) then
		self.TrackedBorder:Hide();
		self.Highlight:Hide();
		self:Hide();
	end
	
	local needsLayoutUpdate = false;
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

	local titleFS = self:GetTitleFontString();
	titleFS:SetText(title);
	
	local showingZone = false;
	local zoneName = "";
	if (shouldShowZone and WQT.settings.list.showZone) then
		local mapInfo = WQT_Utils:GetCachedMapInfo(questInfo.mapID)
		if (mapInfo) then
			showingZone = true;
			zoneName = mapInfo.name;
		end
	end
	
	local extraFrame = self:GetZoneFontString();
	extraFrame:SetShown(showingZone);
	extraFrame:SetText(zoneName);
	local zoneSeparator = self:GetZoneSeparator();
	zoneSeparator:SetShown(showingZone and self:GetTimeFontString():IsShown());
	
	local tagQuality = questInfo:GetTagInfoQuality();

	if(tagQuality > 0) then
		self.QualityBg:Show();
		self.QualityBg:SetVertexColor(WORLD_QUEST_QUALITY_COLORS[tagQuality].color:GetRGB());
	else
		self.QualityBg:Hide();
	end

	-- Warband icon
	do
		local showWarBand = questInfo.hasWarbandBonus and WQT_Utils:GetSetting("list", "warbandIcon");
		local warbandIcon = self:GetWarbandIcon();
		warbandIcon:SetDesaturated(isDisliked);
		if (showWarBand ~= warbandIcon:IsShown()) then
			warbandIcon:SetShown(showWarBand);
			needsLayoutUpdate = true;
		end
	end
	
	local factionFrame = self:GetFactionFrame();
	-- Highlight
	local showHighLight = self:IsMouseOver() or factionFrame:IsMouseOver() or (WQT_ListContainer.PoIHoverId and WQT_ListContainer.PoIHoverId == questInfo.questID)
	self.Highlight:SetShown(showHighLight);
			
	-- Faction icon
	do
		local shouldShow = WQT.settings.list.factionIcon;
		if (shouldShow ~= factionFrame:IsShown()) then
			needsLayoutUpdate = true;
		end
		factionFrame:SetShown(shouldShow);
		if (shouldShow) then
			local factionData = WQT_Utils:GetFactionDataInternal(questInfo.factionID);
			factionFrame.Icon:SetTexture(factionData.texture);
			factionFrame.Icon:SetDesaturated(isDisliked);
		end
	end
	
	-- Type icon
	if (self:UpdateQuestType(questInfo)) then
		needsLayoutUpdate = true;
	end

	-- Rewards
	do
		local canWarmode = C_QuestLog.QuestCanHaveWarModeBonus(self.questID);
		local rewardsFrame = self:GetRewardsFrame();
		if(rewardsFrame:UpdateRewards(questInfo, canWarmode)) then
			needsLayoutUpdate = true;
		end
	end

	-- Show border if quest is tracked
	local isTracked = QuestUtils_IsQuestWatched(questInfo.questID);
	if (isTracked) then
		local isSuperTracked = questInfo.questID == C_SuperTrack.GetSuperTrackedQuestID();
		self.TrackedBorder:Show();
		self.TrackedBorder:SetAlpha(isSuperTracked and 0.9 or 0.5);
	else
		self.TrackedBorder:Hide();
	end
		
	self:UpdateTime();

	-- With a full quest list calling Layout on a all vs on none is a difference of about 9ms (~10ms vs ~1ms)
	-- So try and only call it when something changes that might require it (wardband icon, nr of rewards, etc)
	if (needsLayoutUpdate) then
		self:Layout();
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

WQT_ScrollListMixin = {};

function WQT_ScrollListMixin:OnLoad()
	local paddingTop = 2;
	local paddingBottom = 4;
	local paddingLeft = 2;
	local paddingRight = paddingLeft;
	local view = CreateScrollBoxListLinearView(paddingTop, paddingBottom, paddingLeft, paddingRight);
	view:SetElementInitializer("WQT_QuestTemplate", function(button, elementData)
		button:Update(elementData.questInfo, elementData.showZone);
	end);
	view:SetElementResetter(function(button) button:ClearTimer(); end);
	ScrollUtil.InitScrollBoxListWithScrollBar(self.QuestScrollBox, self.ScrollBar, view);

	self.SortDropdown:SetDefaultText(UNKNOWN);
	self.FilterDropdown.Text:SetPoint("TOP", 0, 1);

	WQT:CallbackWhenReady(function()
			self.SortDropdown:SetupMenu(WQT.SortDropdownSetup);
			self.FilterDropdown:SetupMenu(FilterDropdownSetup);
		end);

	WQT_CallbackRegistry:RegisterCallback(
		"WQT.DataProvider.ProgressUpdated"
		,function(_, progress)
				CooldownFrame_SetDisplayAsPercentage(self.ProgressBar, progress);
				if (progress == 0 or progress == 1) then
					self.ProgressBar:Hide();
				end
			end
		, self);

	WQT_CallbackRegistry:RegisterCallback(
		"WQT.DataProvider.FilteredListUpdated"
		,function()
				self:UpdateQuestList();
			end
		, self);

	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID, tag)
			if (categoryID == "QUESTLIST" 
				or tag == "BOUNTY_SELECTED_ONLY"
				or tag == "PRECISE_FILTERS") then
				self:DisplayQuestList();
			end
		end,
		self);
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
	WQT_SettingsFrame.Background:SetAlpha(backgroundAlpha);
	if (#WQT_WorldQuestFrame.dataProvider.fitleredQuestsList == 0) then
		WQT_ListContainer.Background:SetAtlas("QuestLog-empty-quest-background", true);
	else
		WQT_ListContainer.Background:SetAtlas("QuestLog-main-background", true);
	end

	WQT_CallbackRegistry:TriggerEvent("WQT.ScrollList.BackgroundUpdated");
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

WQT_CoreMixin = {};

-- Mimics hovering over a zone or continent, based on the zone the map is in
function WQT_CoreMixin:ShowWorldmapHighlight(questInfo)
	local zoneId = questInfo.mapID;
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

	self.ExternalEvents = {};
	-- Events
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("PVP_TIMER_UPDATE"); -- Warmode toggle because WAR_MODE_STATUS_UPDATE doesn't seems to fire when toggling warmode
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:RegisterEvent("SUPER_TRACKING_CHANGED");
	self:RegisterEvent("TAXIMAP_OPENED");
	self:RegisterEvent("PLAYER_LOGOUT");

	self:SetScript("OnEvent", function(self, event, ...)
			if (self[event]) then 
				self[event](self, ...);
			elseif (not self.ExternalEvents[event]) then
				WQT:DebugPrint("WQT missing function for:",event);
			end 

			WQT_CallbackRegistry:TriggerEvent("WQT.RegisterdEventTriggered", event, ...);
		end)

	-- Slashcommands
	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd


	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID, tag)
			if (categoryID == "PROFILES") then
				self:ApplyAllSettings();
			elseif (tag == "BOUNTY_COUNTER") then
				self:UpdateBountyCounters();
				self:RepositionBountyTabs();
			elseif (tag == "BOUNTY_REWARD") then
				self:UpdateBountyCounters();
			end
		end,
		self);
	
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
end

function WQT_CoreMixin:RegisterEventsForExternal(external)
	if (not external.GetRequiredEvents or not external.GetName) then return end;

	for k, event in pairs(external:GetRequiredEvents()) do
		if (self:RegisterEvent(event)) then
			self.ExternalEvents[event] = true;
			WQT:DebugPrint("Registered new event", event, "for external", external:GetName());
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
	
	WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
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
		self.pinDataProvider:HookPinHidingToMapFrame(FlightMapFrame);

		WQT_FlightMapContainer:SetParent(FlightMapFrame);
		WQT_FlightMapContainer:SetPoint("BOTTOMLEFT", FlightMapFrame, "BOTTOMRIGHT", -7, 0);
		WQT_FlightMapContainerButton:SetParent(FlightMapFrame);
		WQT_FlightMapContainerButton:SetAlpha(1);
		WQT_FlightMapContainerButton:SetPoint("BOTTOMRIGHT", FlightMapFrame, "BOTTOMRIGHT", -8, 8);
		WQT_FlightMapContainerButton:SetFrameLevel(FlightMapFrame:GetFrameLevel()+2);
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	WQT.combatLockWarned = false;
	WQT_ListContainer.SettingsButton:SetEnabled(false)
	self:ChangePanel(WQT_PanelID.Quests);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	WQT.combatLockWarned = false;
	WQT_ListContainer.SettingsButton:SetEnabled(true)
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

function WQT_CoreMixin:SUPER_TRACKING_CHANGED(...)
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
		WQT_WorldQuestFrame:SetPoint("BOTTOMRIGHT", WQT.contentFrame, -22, 0);
	elseif (anchor == _V["LIST_ANCHOR_TYPE"].full) then
		WQT_WorldQuestFrame:ClearAllPoints(); 
		WQT_WorldQuestFrame:SetParent(WQT_WorldMapContainer);
		WQT_WorldQuestFrame:SetPoint("TOPLEFT", WQT_WorldMapContainer, 14, -56);
		WQT_WorldQuestFrame:SetPoint("BOTTOMRIGHT", WQT_WorldMapContainer, -28, 12);
		WQT_WorldMapContainer:ConstrainPosition();
		showMapContainer = WQT.mapButton.isSelected;
	end

	WQT_WorldMapContainer:SetShown(showMapContainer);

	WQT_CallbackRegistry:TriggerEvent("WQT.CoreFrame.AnchorUpdated", anchor);
end
