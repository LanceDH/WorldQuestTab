local addonName, addon = ...

addon.WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");
local WQT = addon.WQT;

addon.debug = false;
addon.debugPrint = false;

addon.WQT_Utils = {};
WQT_Utils = addon.WQT_Utils;

addon.variables = {};
local _V = addon.variables;

addon.WQT_Profiles =  {};

local _L = addon.loca;
local _playerFaction = UnitFactionGroup("Player");

------------------------
-- PUBLIC
------------------------
WQT_REWARDTYPE = FlagsUtil.MakeFlags(
	"weapon",		--1
	"equipment",	--2
	"conduit",		--4
	"relic",		--8
	"anima",		--16
	"artifact",		--32
	"spell",		--64
	"item",			--128
	"currency",		--256
	"gold",			--512
	"honor",		--1024
	"reputation",	--2048
	"xp",			--4096
	"missing"		--8192
);
WQT_REWARDTYPE.none = 0;
-- Combos
WQT_REWARDTYPE.gear = bit.bor(WQT_REWARDTYPE.weapon, WQT_REWARDTYPE.equipment);

WQT_CallbackRegistry = CreateFromMixins(CallbackRegistryMixin);
WQT_CallbackRegistry:SetUndefinedEventsAllowed(true);
WQT_CallbackRegistry:OnLoad();

------------------------
-- SHARED
------------------------

local enumListAnchorType = {
	flight	= 1;
	world	= 2;
	full	= 3;
	taxi	= 4;
}
function _V:GetListAnchorTypeEnum()
	return enumListAnchorType;
end

local tooltipStyles = {
	default				= TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST;
	callingAvailable	= { ["hideObjectives"] = true, prefixBlankLineCount = 1, postHeaderBlankLineCount = 0, headerText = QUEST_REWARDS, headerColor = NORMAL_FONT_COLOR,};
	callingActive		= { ["hideType"] = true, prefixBlankLineCount = 1, postHeaderBlankLineCount = 0, headerText = QUEST_REWARDS, headerColor = NORMAL_FONT_COLOR,};
}
function _V:GetTooltipStyle(name)
	return tooltipStyles[name];
end

local defaultColors = {
	rewardNone		= CreateColor(0.45, 0.45, .45);
	rewardWeapon	= CreateColor(1, 0.45, 1);
	rewardArmor		= CreateColor(0.95, 0.65, 1);
	rewardArtifact	= CreateColor(0, 0.75, 0);
	rewardCurrency	= CreateColor(0.6, 0.4, 0.1);
	rewardGold		= CreateColor(0.95, 0.8, 0);
	rewardHonor		= CreateColor(0.8, 0.26, 0);
	rewardItem		= CreateColor(0.85, 0.85, 0.85);
	rewardRelic		= CreateColor(0.3, 0.7, 1);
	rewardMissing	= CreateColor(0.7, 0.1, 0.1);

	fontWhite		= CreateColor(0.9, 0.9, 0.9);
	fontOrange		= CreateColor(1, 0.5, 0);
	fontGreen		= CreateColor(0, 0.8, 0);
	fontBlue		= CreateColor(0.2, 0.60, 1);
	fontPurple		= CreateColor(0.84, 0.38, 0.94);
}

function _V:GetDefaultColor(name)
	return defaultColors[name];
end

local enumFilterType = {
	faction = 1;
	type    = 2;
	reward  = 3;
}
function _V:GetFilterTypeEnum()
	return enumFilterType;
end

local enumPinCenterType = {
	blizzard	= 1;
	reward		= 2;
	faction		= 3;
}
function _V:GetPinCenterTypeEnum()
	return enumPinCenterType;
end

local enumPinColorType = {
	default			= 1;
	reward			= 2;
	time			= 3;
	rarity			= 4;
	rewardQuality	= 5;
}
function _V:GetPinColorType()
	return enumPinColorType;
end

local enumPinContinent = {
	none	= 1;
	tracked	= 2;
	all		= 3;
}
function _V:GetPinContinentEnum()
	return enumPinContinent;
end

local enumPinZone = {
	none	= 1;
	tracked	= 2;
	all		= 3;
}
function _V:GetPinZoneEnum()
	return enumPinZone;
end

local enumPinLabel = {
	none	= 1;
	time	= 2;
	amount	= 3;
}
function _V:GetPinLabelEnum()
	return enumPinLabel;
end

local enumZoneQuests = {
	zone		= 1;
	neighbor	= 2;
	expansion	= 3;
}
function _V:GetZoneQuestsEnum()
	return enumZoneQuests;
end

-- Not where they should be. Count them as invalid. Thanks Blizzard
local buggedQuestIDs =  {
	[66004] = 2022	-- Galgresh
	,[66356] = 2023	-- Irontree
	,[69849] = 2022	-- Enraged Steamburst Elemental
	,[69850] = 2025	-- Woolfang
	,[69858] = 2024	-- Blightfur
	,[69861] = 2024	-- Trilvarus Loreweaver
	,[69865] = 2023	-- Scaleseeker Mezeri
	,[69882] = 2025	-- Lord Epochbrgi
	,[69951] = 2022	-- Bouldron
	,[69953] = 2022	-- Karantun
	,[69954] = 2022	-- Infernum
	,[69956] = 2022	-- Grizzlerock
	,[69960] = 2022	-- Gravlion
	,[69961] = 2022	-- Frozion
	,[69964] = 2025	-- Craggravated Elemental
	,[69969] = 2022	-- Voraazka
	,[69970] = 2022	-- Kain Firebrand
	,[69972] = 2022	-- Zurgaz Corebreaker
	,[69973] = 2022	-- Rouen Icewind
	,[69975] = 1978	-- Neela Firebane
	,[72128] = 2022	-- Enkine the Voracious
	,[74441] = 2023	-- Eaglemaster Niraak
}
function _V:GetBuggedQuestMapID(questID)
	return buggedQuestIDs[questID];
end

local enumTimeRemaining = {
	none		= 0;
	expired		= 1;
	critical	= 2; -- <15m
	short		= 3; -- 1h
	medium		= 4; -- 24h
	long		= 5; -- 3d
	veryLong	= 6; -- >3d
}
function _V:GetTimeRemainingEnum()
	return enumTimeRemaining;
end

local abriviationNumbers = {
	{["value"] = 10000000000, ["format"] = _L:Get("NUMBERS_THIRD")};
	{["value"] = 1000000000, ["format"] = _L:Get("NUMBERS_THIRD"), ["decimal"] = true};
	{["value"] = 10000000, ["format"] = _L:Get("NUMBERS_SECOND")};
	{["value"] = 1000000, ["format"] = _L:Get("NUMBERS_SECOND"), ["decimal"] = true};
	{["value"] = 10000, ["format"] = _L:Get("NUMBERS_FIRST")};
	{["value"] = 1000, ["format"] = _L:Get("NUMBERS_FIRST"), ["decimal"] = true};
}

local locale = GetLocale();
if (locale == "koKR" or locale == "zhCN" or locale == "zhTW") then
	abriviationNumbers = {
		{["value"] = 1000000000, ["format"] = _L:Get("NUMBERS_THIRD")};
		{["value"] = 100000000, ["format"] = _L:Get("NUMBERS_SECOND"), ["decimal"] = true};
		{["value"] = 100000, ["format"] = _L:Get("NUMBERS_FIRST")};
		{["value"] = 10000, ["format"] = _L:Get("NUMBERS_FIRST"), ["decimal"] = true};
	}
end
function _V:GetAbriviationNumbers()
	return abriviationNumbers;
end

local factionFallbackData = { ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 131071, ["name"]=_L:Get("NO_FACTION") } -- No faction
local factionData = {
	[67] = 		{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 2203914, ["playerFaction"] = "Horde" }; -- Horde
	[469] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 2203912, ["playerFaction"] = "Alliance" }; -- Alliance
	[609] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 1396983 }; -- Cenarion Circle - Call of the Scarab
	[910] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 236232 }; -- Brood of Nozdormu - Call of the Scarab
	[1106] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 236690 }; -- Argent Crusade

	[1445] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 133283 }; -- Draenor Frostwolf Orcs
	[1515] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1002596 }; -- Dreanor Arakkoa Outcasts
	[1731] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1048727 }; -- Dreanor Council of Exarchs
	[1681] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1042727 }; -- Dreanor Vol'jin's Spear
	[1682] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1042294 }; -- Dreanor Wrynn's Vanguard
	-- Legion
	[1090] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394955 }; -- Kirin Tor
	[1828] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394954 }; -- Highmountain Tribes
	[1859] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394956 }; -- Nightfallen
	[1883] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394953 }; -- Dreamweavers
	[1894] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394958 }; -- Wardens
	[1900] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394952 }; -- Court of Farnodis

	[1948] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394957 }; -- Valarjar
	[2045] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708498 }; -- Legionfall
	[2165] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708497 }; -- Army of the Light
	[2170] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708496 }; -- Argussian Reach
	-- BFA
	[2103] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065579, ["playerFaction"] = "Horde" }; -- Zandalari Empire
	[2156] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065575, ["playerFaction"] = "Horde" }; -- Talanji's Expedition
	[2157] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065571, ["playerFaction"] = "Horde" }; -- The Honorbound
	[2158] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032599, ["playerFaction"] = "Horde" }; -- Voldunai
	[2159] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065569, ["playerFaction"] = "Alliance" }; -- 7th Legion
	[2160] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065573, ["playerFaction"] = "Alliance" }; -- Proudmoore Admirality
	[2161] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032594, ["playerFaction"] = "Alliance" }; -- Order of Embers
	[2162] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032596, ["playerFaction"] = "Alliance" }; -- Storm's Wake
	[2163] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032598 }; -- Tortollan Seekers
	[2164] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032592 }; -- Champions of Azeroth
	[2391] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2909316 }; -- Rustbolt
	[2373] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2821782, ["playerFaction"] = "Horde" }; -- Unshackled
	[2400] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2909045, ["playerFaction"] = "Alliance" }; -- Waveblade Ankoan
	[2417] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 3196264 }; -- Uldum Accord
	[2415] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 3196265 }; -- Rajani
	-- Shadowlands
	[2407] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3257748 }; -- The Ascended
	[2410] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3641396 }; -- The Undying Army
	[2413] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3257751 }; -- Court of Harvesters
	[2465] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3641394 }; -- The Wild Hunt
	[2432] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3729461 }; -- Ve'nari
	[2470] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4083292 }; -- Korthia
	[2472] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4067928 }; -- Korthia Codex
	[2478] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4226232 }; -- Zereth Mortis
	-- LE_EXPANSION_DRAGONFLIGHT
	[2523] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4528811 }; -- Dark Talons
	[2507] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687628 }; -- Dragonscale Expedition
	[2574] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 5244643 }; -- Dream Wardens
	[2511] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687629 }; -- Iskaara Tuskarr
	[2564] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 5140835 }; -- Loamm Niffen
	[2503] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687627 }; -- Maruuk Centaur
	[2510] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687630 }; -- Valdrakken Accord
	[2524] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4528812 }; -- Obsidian Warders
	[2517] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4640487 }; -- Wrathion
	[2518] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4640488 }; -- Sabellian
	-- LE_EXPANSION_WAR_WITHIN
	[2570] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 5891368 }; -- Hallowfall Arathi
	[2594] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6029027 }; -- The Assembly of the Deeps
	[2590] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6029029 }; -- Council of Dornogal
	[2600] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 5891370 }; -- The Severed Threads
	[2653] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6351805 }; -- The Cartels of Undermine
	[2673] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439627 }; -- Bilgewater
	[2669] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439629 }; -- Darkfuse
	[2675] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439628 }; -- Blackwater
	[2677] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439630 }; -- Steamwheedle
	[2671] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439631 }; -- Venture Co.
	[2658] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6937966 }; -- K'aresh Trust
	-- LE_EXPANSION_MIDNIGHT
	[2696] =	{ ["expansion"] = LE_EXPANSION_MIDNIGHT, ["texture"] = 7505698 }; -- Amani Tribe
	[2699] =	{ ["expansion"] = LE_EXPANSION_MIDNIGHT, ["texture"] = 7505702 }; -- The Singularity
	[2704] =	{ ["expansion"] = LE_EXPANSION_MIDNIGHT, ["texture"] = 7505704 }; -- Hara'ti
	[2710] =	{ ["expansion"] = LE_EXPANSION_MIDNIGHT, ["texture"] = 7505700 }; -- Silvermoon Court
}

-- Add localized faction names
for k, v in pairs(factionData) do
	local info = C_Reputation.GetFactionDataByID(k);
	if(info) then
		v.name = info.name;
	end
end

function _V:GetFactionData(factionID)
	if (not factionID) then
		-- No faction
		return factionFallbackData;
	end;

	if (not factionData[factionID]) then
		-- Add new faction in case it's not in our data yet
		local data = C_Reputation.GetFactionDataByID(factionID);
		factionData[factionID] = { ["expansion"] = 0,["faction"] = nil ,["texture"] = 1103069, ["unknown"] = true, ["name"] = data and data.name or "Unknown Faction" };
		WQT:DebugPrint("Added new faction", factionData[factionID].name);
	end

	return factionData[factionID];
end

do
	local FilterDataMixin = {};

	function FilterDataMixin:Init()
		self.filtersTypes = {};
		self.filterOrder = {};
	end

	function FilterDataMixin:RegisterFilterType(filterType, label)
		if (not filterType or not label or self.filtersTypes[filterType]) then return; end

		self.filtersTypes[filterType] = {
			label = label;
			filters = {};
			sortedIDs = {};
		};

		tinsert(self.filterOrder, filterType);
	end

	function FilterDataMixin:RegisterFilter(filterType, id, label, func, tag, manualSortOrder)
		if (not filterType or not id) then return; end
	
		local filter = self:GetFilterType(filterType);

		if (not filter or not filter.filters) then return; end
		local filterList = filter.filters;

		if (filterList[id]) then return; end

		manualSortOrder = manualSortOrder or 0;

		filterList[id] = {
			id = id;
			label = label;
			func = func;
			tag = tag;
			manualSortOrder = manualSortOrder;
		};

		tinsert(filter.sortedIDs, id);
	end

	function FilterDataMixin:SortFilterType(filterType)
		local list = self:GetFiltersOfType(filterType);
		local sortedIDs = self:GetSortedFilterIDs(filterType);
		if (list and sortedIDs) then
			table.sort(sortedIDs, function(a, b)
				local orderA = list[a].manualSortOrder or 0;
				local orderB = list[b].manualSortOrder or 0;
				if (orderA ~= orderB) then
					return orderA < orderB;
				end

				-- Compare localized labels
				local labelA = list[a].label;
				local labelB = list[b].label;
				if (labelA ~= labelB) then
					if (not labelA or not labelB) then
						return labelA ~= nil;
					end
					return labelA < labelB;
				end
				-- Failsafe
				return tostring(a) < tostring(b);
			end)
		end
	end

	function FilterDataMixin:GetFilterType(filterType)
		return self.filtersTypes[filterType];
	end

	function FilterDataMixin:GetSortedFilterIDs(filterType)
		local type = self:GetFilterType(filterType);
		return type and type.sortedIDs;
	end

	function FilterDataMixin:GetFiltersOfType(filterType)
		local type = self:GetFilterType(filterType);
		return type and type.filters;
	end

	function FilterDataMixin:GetFilterTypeLabel(filterType)
		local type = self:GetFilterType(filterType);
		return type and type.label;
	end

	function FilterDataMixin:GetFilter(filterType, id)
		local list = self:GetFiltersOfType(filterType);
		return list and list[id];
	end

	function FilterDataMixin:GetFilterFunction(filterType, id)
		local filter = self:GetFilter(filterType, id);
		return filter and filter.func;
	end

	local FILTER_TAG_OLD_CONTENT = "OLD_CONTENT";

	function FilterDataMixin:FilterIsOldContent(filterType, id)
		local filter = self:GetFilter(filterType, id);
		return filter and filter.tag == FILTER_TAG_OLD_CONTENT;
	end

	function FilterDataMixin:EnumerateFilterTypes()
		return ipairs(self.filterOrder);
	end

	local filterData = CreateAndInitFromMixin(FilterDataMixin);

	do
		local type = enumFilterType.faction;
		filterData:RegisterFilterType(type, FACTION);
		do
			local id = "Other";
			local label = OTHER;
			filterData:RegisterFilter(type, id, label, nil, FILTER_TAG_OLD_CONTENT, 98);
		end
		do
			local id = "None";
			local label = _L:Get("NO_FACTION");
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.PvP; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT, 99);
		end
		-- Entry for every faction we care about
		for id, data in pairs(factionData) do
			filterData:RegisterFilter(type, id, data.name, nil, data.expansion);
		end
	end

	do
		local type = enumFilterType.type;
		filterData:RegisterFilterType(type, TYPE);
		do
			local id = "PvP";
			local label = PVP;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.PvP; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Petbattle";
			local label = PET_BATTLE_PVP_QUEUE;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.PetBattle; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Dungeon";
			local label = TRACKER_HEADER_DUNGEON;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Dungeon; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Raid";
			local label = RAID;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Raid; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Profession";
			local label = BATTLE_PET_SOURCE_4;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Profession; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Elite";
			local label = ELITE;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.isElite and tagInfo.worldQuestType ~= Enum.QuestTagType.Dungeon; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Default";
			local label = DEFAULT;
			local func = function(questInfo, tagInfo) return tagInfo and not tagInfo.isElite and tagInfo.worldQuestType == Enum.QuestTagType.Normal; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Bonus";
			local label = SCENARIO_BONUS_LABEL;
			local func = function(questInfo, tagInfo) return not tagInfo; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Dragonrider";
			local label = DRAGONRIDING_RACES_MAP_TOGGLE;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.DragonRiderRacing; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Prey";
			local label = _L:Get("TYPE_PREY");
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Prey; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		-- old content
		do
			local id = "Invasion";
			local label = _L:Get("TYPE_INVASION");
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Invasion; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
		do
			local id = "Assault";
			local label = SPLASH_BATTLEFORAZEROTH_8_1_FEATURE2_TITLE;
			local func = function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.FactionAssault; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
	end

	do
		local type = enumFilterType.reward;
		filterData:RegisterFilterType(type, REWARD);
		do
			local id = "Armor";
			local label = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.equipment + WQT_REWARDTYPE.weapon) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Item";
			local label = ITEMS;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.spell + WQT_REWARDTYPE.item) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Honor";
			local label = HONOR;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.honor) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Gold";
			local label = WORLD_QUEST_REWARD_FILTERS_GOLD;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.gold) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Currency";
			local label = CURRENCY;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.currency) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Experience";
			local label = POWER_TYPE_EXPERIENCE;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.xp) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "Reputation";
			local label = REPUTATION;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.reputation) > 0; end;
			filterData:RegisterFilter(type, id, label, func);
		end
		do
			local id = "None";
			local label = NONE;
			local func = function(questInfo, tagInfo) return questInfo.reward.typeBits == WQT_REWARDTYPE.none; end;
			local manualSortOrder = 99;
			filterData:RegisterFilter(type, id, label, func, nil, manualSortOrder);
		end
		-- old content
		do
			local id = "Relic";
			local label = RELICSLOT;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.relic) > 0; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
		do
			local id = "Anima";
			local label = WORLD_QUEST_REWARD_FILTERS_ANIMA;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.anima) > 0; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
		do
			local id = "Conduits";
			local label = _L:Get("REWARD_CONDUITS");
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.conduit) > 0; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
		do
			local id = "Artifact";
			local label = ITEM_QUALITY6_DESC;
			local func = function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.artifact) > 0; end;
			filterData:RegisterFilter(type, id, label, func, FILTER_TAG_OLD_CONTENT);
		end
	end

	-- Alphabetical sort all filters
	for k, filterType in filterData:EnumerateFilterTypes() do
		filterData:SortFilterType(filterType);
	end


	function _V:GetFiltersOfType(filterType)
		return filterData:GetFiltersOfType(filterType);
	end

	function _V:GetFilter(filterType, id)
		return filterData:GetFilter(filterType, id);
	end

	function _V:GetFilterFunction(filterType, id)
		return filterData:GetFilterFunction(filterType, id);
	end

	function _V:FilterIsOldContent(filterType, id)
		return filterData:FilterIsOldContent(filterType, id);
	end
	
	function _V:GetSortedFilterIDs(filterType)
		return filterData:GetSortedFilterIDs(filterType);
	end
	
	function _V:GetFilterTypeLabel(filterType)
		return filterData:GetFilterTypeLabel(filterType);
	end

	function _V:EnumerateFilterTypes()
		return filterData:EnumerateFilterTypes();
	end
end

local rewardTypeAtlases = {
	[WQT_REWARDTYPE.weapon] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.211, ["r"] = 0.277, ["t"] = 0.246, ["b"] = 0.277}; -- Weapon
	[WQT_REWARDTYPE.equipment] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.847, ["r"] = 0.91, ["t"] = 0.459, ["b"] = 0.49}; -- Armor
	[WQT_REWARDTYPE.relic] = {["texture"] = "poi-scrapper", ["scale"] = 1}; -- Relic
	[WQT_REWARDTYPE.artifact] = {["texture"] = "AzeriteReady", ["scale"] = 1.3}; -- Azerite
	[WQT_REWARDTYPE.item] = {["texture"] = "Banker", ["scale"] = 1.1}; -- Item
	[WQT_REWARDTYPE.gold] = {["texture"] = "Auctioneer", ["scale"] = 1}; -- Gold
	[WQT_REWARDTYPE.currency] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.4921875, ["r"] = 0.55859375, ["t"] = 0.0390625, ["b"] = 0.068359375, ["color"] = CreateColor(0.7, 0.52, 0.43)}; -- Resources
	[WQT_REWARDTYPE.honor] = {["texture"] = _playerFaction == "Alliance" and "poi-alliance" or "poi-horde", ["scale"] = 1}; -- Honor
	[WQT_REWARDTYPE.reputation] = {["texture"] = "QuestRepeatableTurnin", ["scale"] = 1.2}; -- Rep
	[WQT_REWARDTYPE.xp] = {["texture"] = "poi-door-arrow-up", ["scale"] = .9}; -- xp
	[WQT_REWARDTYPE.spell] = {["texture"] = "Banker", ["scale"] = 1.1};  -- spell acts like item
	[WQT_REWARDTYPE.anima] = {["texture"] =  "AncientMana", ["scale"] = 1.5}; -- Anima
	[WQT_REWARDTYPE.conduit] = {
		[CONDUIT_TYPE_POTENCY] = {["texture"] =  "soulbinds_tree_conduit_icon_attack", ["scale"] = 1.15};
		[CONDUIT_TYPE_ENDURANCE] = {["texture"] =  "soulbinds_tree_conduit_icon_protect", ["scale"] = 1.15};
		[CONDUIT_TYPE_FINESSE] = {["texture"] =  "soulbinds_tree_conduit_icon_utility", ["scale"] = 1.15};
	}; -- conduits
}
function _V:GetRewardIconAtlas(rewardType, subType)
	local t = rewardTypeAtlases[rewardType];
	if (t and not t.texture) then
		t = t[subType];
	end
	return t;
end



local function CreatePinBoundry(xMin, xMax, yMin, yMax, clusterID)
	return {
		xMin = xMin;
		xMax = xMax;
		yMin = yMin;
		yMax = yMax;
		clusterID = clusterID;
	}
end

local PinCircleMixin = {};

function PinCircleMixin:Init(radius, startAngle, maxArc, offsetX, offsetY)
	self.radius = radius;
	self.startAngle = startAngle;
	self.maxArc = maxArc or 360;
	self.offsetX = offsetX or 0;
	self.offsetY = offsetY or 0;
end

local TWO_PI = PI * 2;
function PinCircleMixin:NudgeFunction(validPins, canvas)
	if (#validPins) == 0 then return; end

	local sourcePin = validPins[1];
	local pinSize = sourcePin:GetButton():GetSize();
	if (pinSize == 0) then return; end
	pinSize = pinSize * WQT_Utils:GetSetting("pin", "scale");

	local centerX, centerY = sourcePin:GetPosition();
	centerX = centerX + self.offsetX;
	centerY = centerY + self.offsetY;

	local pinSizeToWindow = pinSize / canvas:GetParent():GetHeight();
	local ratio = canvas:GetHeight() / canvas:GetWidth();

	local numPassedPins = #validPins;
	local distance = self.radius or 0.1;
	local maxArc = self.maxArc or 360;

	local available = rad(maxArc) * distance;
	local requested = numPassedPins * pinSizeToWindow;
	local spacePerPin = (min(available, requested) / (TWO_PI * distance)) / numPassedPins;
	local step = spacePerPin * 360;

	local angle = self.startAngle or 0;
	angle = angle - (spacePerPin * 180 * (numPassedPins - 1));

	for k, pin in ipairs(validPins) do
		local offsetX = cos(angle) * distance * ratio;
		local offsetY = sin(angle) * distance;
		local x = centerX + offsetX;
		local y = centerY + offsetY;
		pin:SetNudge(x, y);
		angle = angle + step;
	end
end

local function CreatePinCircle(radius, startAngle, maxArc, offsetX, offsetY)
	return CreateAndInitFromMixin(PinCircleMixin, radius, startAngle, maxArc, offsetX, offsetY);
end

local mapDatabase = {
	maps = {};
	expansions = {};
};

function mapDatabase:AddFlightMap(zoneID, expansionID)
	self:AddMap(zoneID, expansionID, true);
end

function mapDatabase:AddMap(zoneID, expansionID, isFlightmap)
	if (self.maps[zoneID]) then
		print("Already have zoneID", zoneID)
		return;
	end

	local mapInfo = C_Map.GetMapInfo(zoneID);
	if (not mapInfo) then return; end
	expansionID = expansionID or 0;

	local name = mapInfo.name;
	if (isFlightmap) then
		name = string.format("%s - flightmap", name);
	end

	local data = {
		name = mapInfo.name;
		expansion = expansionID;
		children = {};
		mapInfo = mapInfo;
	};

	self.maps[zoneID] = data;
	local epxansionTable = GetOrCreateTableEntry(self.expansions, expansionID);
	epxansionTable[zoneID] = true;

	local children = C_Map.GetMapChildrenInfo(zoneID);
	if (not children) then return; end
	for k, childInfo in ipairs(children) do
		if (childInfo.mapType <= Enum.UIMapType.Zone) then
			local isSubZone = mapInfo.mapType == Enum.UIMapType.Zone and childInfo.mapType == Enum.UIMapType.Zone;
			local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(childInfo.mapID, zoneID);
			local x = minX + (maxX - minX) * 0.5;
			local y = minY + (maxY - minY) * 0.5;
			if (x ~= 0) then
				local childData = self:AddMap(childInfo.mapID, expansionID);
				childData.origin = mapInfo.name;
				self:AddChildToMap(zoneID, childInfo.mapID, x, y, isSubZone);
			end
		end
	end

	return data;
end

function mapDatabase:AddChildToMap(zoneID, childZoneID, coordX, coordY, isSubZone, pinClusterData)
	local zoneData = self.maps[zoneID];
	if (not zoneData) then return; end;
	local childData = self.maps[childZoneID] or self:AddMap(childZoneID, zoneData.expansion);
	if (not childData) then return; end;

	local data = GetOrCreateTableEntry(zoneData.children, childZoneID);

	if(type(isSubZone) == nil) then
		isSubZone = data.isSubZone or false;
	end

	data.x = coordX or data.x or 0;
	data.y = coordY or data.y or 0;
	data.isSubZone = isSubZone;
	data.pinClusterData = pinClusterData or data.pinClusterData;
end

function mapDatabase:SetMapExpansion(zoneID, expansionID, excludeChildren)
	local zoneData = self.maps[zoneID] or self:AddMap(zoneID, expansionID);
	if (not zoneData) then return; end

	local currentExpansionTable = GetOrCreateTableEntry(self.expansions, zoneData.expansion);
	currentExpansionTable[zoneID] = nil;

	zoneData.expansion = expansionID;

	local newExpansionTable = GetOrCreateTableEntry(self.expansions, expansionID);
	newExpansionTable[zoneID] = true;
	
	if (not excludeChildren) then
		for childZoneID in pairs(zoneData.children) do
			self:SetMapExpansion(childZoneID, expansionID);
		end
	end
end

function mapDatabase:SetPinClusterData(zoneID, childZoneID, pinClusterData, xOverride, yOverride)
	local zoneData = self.maps[zoneID];
	local childData = zoneData and zoneData.children[childZoneID]
	if (not childData) then return; end;

	childData.pinClusterData = pinClusterData;
	childData.x = xOverride or childData.x;
	childData.y = yOverride or childData.y;
end

-- Temp mapID enum purely for readability
local enumZoneIDs =
{
	Azeroth = 947,

	Northrend = 113,
	NorthrendFlightmap = 1384,

	Pandaria = 424,
	PandariaFlightmap = 989,
	ValleyOfEternalBlossom = 390,

	Draenor = 572,
	DraenorFlightmap = 990,

	BrokenIsles = 619,
	BrokenIslesFlightmap = 993,
	DalaranLegion = 627,
	Argus = 905,
	ArgusFlightmap = 994,
	Krokuun = 830,
	AntoranWastes = 885,
	Eredath = 882,

	Zandalar = 875,
	ZandalarFlightmap = 1011,
	Kultiras = 876,
	KultirasFlightmap = 1014,
	Nazjatar = 1355,
	NazjatarFlightmap = 1504,
	UldumBfA = 1527,
	ValeOfEternalBlossomBfA = 1530,
	Kalimdor = 12,
	Darkshore = 62,
	ArathiHighlands = 14,

	Shadowlands = 1550,
	ShadowlandsFlightmap = 1647,
	Oribos = 1670,
	ZerethMortis = 1970,

	DragonIsles = 1978,
	DragonIslesFlightmap = 2057,
	ZaralekCavern = 2133,
	WakingShores = 2022,
	OhnahranPlains = 2023,
	EmeraldDream = 2200,
	Amidrassil = 2239,
	AzureSpan = 2024,
	Thaldraszus = 2025,
	ForgbiddenReach = 2151,

	KhazAlgar = 2274,
	KhazAlgarFlightmap = 2276,
	IsleOfDorn = 2248,
	SirenIsle = 2369,
	Undermine = 2346,
	Karesh = 2371,
	KareshFlightmap = 2398,

	QuelThalas = 2537,
	QuelThalasFlightmap = 2481,
	Haradar = 2413,
	VoidstormFlightmap = 2479,
	Voidstorm = 2405,
	HaradarFlightmap = 2480,
	EasternKingdoms = 13,
}

local isChildZone = true;
local excludeChildren = true;

-- Add Azeroth as no expansion to get all sub zones
mapDatabase:SetMapExpansion(enumZoneIDs.Azeroth, LE_EXPANSION_CLASSIC);
-- Then change just azeroth to no expansion to avoid it ever getting scanned
mapDatabase:SetMapExpansion(enumZoneIDs.Azeroth, -1, excludeChildren);

do  -- Wrath of the Lich King
	local expansion = LE_EXPANSION_WRATH_OF_THE_LICH_KING;
	mapDatabase:SetMapExpansion(enumZoneIDs.Northrend, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.NorthrendFlightmap, expansion);
end

do  -- Pandaria
	local expansion = LE_EXPANSION_MISTS_OF_PANDARIA;
	mapDatabase:SetMapExpansion(enumZoneIDs.Pandaria, expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.ValleyOfEternalBlossom, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.PandariaFlightmap, expansion);
end

do  -- Warlords of Draenor
	local expansion = LE_EXPANSION_WARLORDS_OF_DRAENOR;
	mapDatabase:SetMapExpansion(enumZoneIDs.Draenor, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.DraenorFlightmap, expansion);
end

do  -- Legion
	local expansion = LE_EXPANSION_LEGION;
	mapDatabase:SetMapExpansion(enumZoneIDs.BrokenIsles, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.BrokenIslesFlightmap,	expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.ArgusFlightmap,		expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.BrokenIsles,	enumZoneIDs.DalaranLegion,	0,		0);
	mapDatabase:AddChildToMap(enumZoneIDs.BrokenIsles,	enumZoneIDs.Krokuun,		nil,	nil,	not isChildZone, CreatePinBoundry(0.81, 0.95, 0.17, 0.36));
	mapDatabase:AddChildToMap(enumZoneIDs.BrokenIsles,	enumZoneIDs.AntoranWastes,	nil,	nil,	not isChildZone, CreatePinBoundry(0.70, 0.87, 0.13, 0.29));
	mapDatabase:AddChildToMap(enumZoneIDs.BrokenIsles,	enumZoneIDs.Eredath,		nil,	nil,	not isChildZone, CreatePinBoundry(0.83, 0.97, 0.07, 0.19));
	mapDatabase:AddChildToMap(enumZoneIDs.Argus,		enumZoneIDs.Krokuun,		0.61,	0.68,	not isChildZone, CreatePinBoundry(0.48, 0.73, 0.55, 0.83));
	mapDatabase:AddChildToMap(enumZoneIDs.Argus,		enumZoneIDs.AntoranWastes,	0.31,	0.51,	not isChildZone, CreatePinBoundry(0.19, 0.46, 0.40, 0.70));
	mapDatabase:AddChildToMap(enumZoneIDs.Argus,		enumZoneIDs.Eredath,		0.62,	0.26,	not isChildZone, CreatePinBoundry(0.50, 0.75, 0.17, 0.40));
end

do  -- Battle for Azeroth
	local expansion = LE_EXPANSION_BATTLE_FOR_AZEROTH;
	mapDatabase:SetMapExpansion(enumZoneIDs.Zandalar,					expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.Kultiras,					expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.Darkshore,					expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.ArathiHighlands,			expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.ValeOfEternalBlossomBfA,	expansion);
	mapDatabase:SetMapExpansion(enumZoneIDs.UldumBfA,					expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.ZandalarFlightmap, expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.KultirasFlightmap, expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.NazjatarFlightmap, expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.Pandaria, enumZoneIDs.ValeOfEternalBlossomBfA,	0.50, 0.52);
	mapDatabase:AddChildToMap(enumZoneIDs.Kalimdor, enumZoneIDs.UldumBfA,					0.49, 0.90);
	mapDatabase:AddChildToMap(enumZoneIDs.Zandalar, enumZoneIDs.Nazjatar,					0.87, 0.15, not isChildZone, CreatePinCircle(0.09, -90, 250));
	mapDatabase:AddChildToMap(enumZoneIDs.Kultiras, enumZoneIDs.Nazjatar,					0.87, 0.15, not isChildZone, CreatePinCircle(0.09, -90, 250));
	mapDatabase:AddChildToMap(enumZoneIDs.Nazjatar, enumZoneIDs.Zandalar,					0.11, 0.49);
	mapDatabase:AddChildToMap(enumZoneIDs.Nazjatar, enumZoneIDs.Kultiras,					0.77, 0.75);
end

do  -- Shadowlands
	local expansion = LE_EXPANSION_SHADOWLANDS;
	mapDatabase:SetMapExpansion(enumZoneIDs.Shadowlands, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.ShadowlandsFlightmap, expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.Shadowlands, enumZoneIDs.Oribos,			0.18, 0.18);
	mapDatabase:AddChildToMap(enumZoneIDs.Shadowlands, enumZoneIDs.ZerethMortis,	0.86, 0.80, not isChildZone, CreatePinCircle(0.09, -90, 270));
end

do  -- Dragonflight
	local expansion = LE_EXPANSION_DRAGONFLIGHT;
	mapDatabase:SetMapExpansion(enumZoneIDs.DragonIsles, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.DragonIslesFlightmap, expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.DragonIsles,		enumZoneIDs.ZaralekCavern,		0.89, 0.85, not isChildZone, CreatePinCircle(0.18, -110, 120));
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.WakingShores,		0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.OhnahranPlains,		0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.EmeraldDream,		0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.Amidrassil,			0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.AzureSpan,			0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.Thaldraszus,		0.88, 0.84);
	mapDatabase:AddChildToMap(enumZoneIDs.ZaralekCavern,	enumZoneIDs.ForgbiddenReach,	0.88, 0.84);
end

do  -- War Within
	local expansion = LE_EXPANSION_WAR_WITHIN;
	mapDatabase:SetMapExpansion(enumZoneIDs.KhazAlgar, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.KhazAlgarFlightmap,	expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.KareshFlightmap,		expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.IsleOfDorn,	enumZoneIDs.SirenIsle,	0.18,	0.18,	not isChildZone, CreatePinCircle(0.07, -90));
	mapDatabase:AddChildToMap(enumZoneIDs.KhazAlgar,	enumZoneIDs.SirenIsle,	0.73,	0.23);
	mapDatabase:AddChildToMap(enumZoneIDs.KhazAlgar,	enumZoneIDs.Undermine,	0.82,	0.74,	not isChildZone, CreatePinCircle(0.09, -80, 250));
	mapDatabase:AddChildToMap(enumZoneIDs.KhazAlgar,	enumZoneIDs.Karesh,		0.178,	0.195,	not isChildZone, CreatePinCircle(0.09, -90, 300));
end

do  -- Midnight
	local expansion = LE_EXPANSION_MIDNIGHT;
	mapDatabase:SetMapExpansion(enumZoneIDs.QuelThalas, expansion);

	mapDatabase:AddFlightMap(enumZoneIDs.QuelThalasFlightmap,	expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.HaradarFlightmap,		expansion);
	mapDatabase:AddFlightMap(enumZoneIDs.VoidstormFlightmap,	expansion);

	mapDatabase:AddChildToMap(enumZoneIDs.EasternKingdoms,	enumZoneIDs.QuelThalas, 0.61, 0.18);
	mapDatabase:AddChildToMap(enumZoneIDs.QuelThalas,		enumZoneIDs.Voidstorm,	0.53, 0.24, not isChildZone, CreatePinCircle(0.54, 90, 30, 0, -0.40));
	mapDatabase:AddChildToMap(enumZoneIDs.QuelThalas,		enumZoneIDs.Haradar,	0.82, 0.17, not isChildZone, CreatePinCircle(0.54, 90, 30, 0, -0.41));
end

function _V:GetZoneData(zoneID)
	return mapDatabase.maps[zoneID];
end

function _V:GetZonesOfExpansion(expansion)
	return mapDatabase.expansions[expansion];
end

function _V:GetMostRelevantMapCoordinates(zoneID, inZoneID)
	local childData = nil;
	local coordZoneID = zoneID;
	if (zoneID ~= inZoneID) then
		local data = _V:GetZoneData(inZoneID);
		if (data) then
			childData = data.children[zoneID];
			if (not childData) then
				local mapInfo = WQT_Utils:GetCachedMapInfo(zoneID);
				if (mapInfo and mapInfo.parentMapID and mapInfo.mapType > Enum.UIMapType.Cosmic) then
					childData, coordZoneID = self:GetMostRelevantMapCoordinates(mapInfo.parentMapID, inZoneID);
				end
			end
		end
	end
	return childData, coordZoneID;
end

local filterToOfficialCvar = {
	["Petbattle"]	= { "showTamersWQ" };
	["Dragonrider"]	= { "dragonRidingRacesFilterWQ" };
	["Profession"]	= { "primaryProfessionsFilter", "secondaryProfessionsFilter" };

	["Artifact"]	= { "worldQuestFilterArtifactPower" };
	["Gold"]		= { "worldQuestFilterGold" };
	["Armor"]		= { "worldQuestFilterEquipment" };
	["Reputation"]	= { "worldQuestFilterReputation" };
	["Anima"]		= { "worldQuestFilterAnima" };
	-- worldQuestFilterResources
	-- worldQuestFilterProfessionMaterials
}
function _V:IsRelevantOfficialCvar(cvar)
	for _, officalFilters in pairs(filterToOfficialCvar) do
		for _, officialFilter in ipairs(officalFilters) do
			if (officialFilter == cvar) then
				return true;
			end
		end
	end
	return false;
end

function _V:EnableAllOfficialCvars()
	for _, officalFilters in pairs(filterToOfficialCvar) do
		for _, cvar in ipairs(officalFilters) do
			C_CVar.SetCVar(cvar, 1);
		end
	end
end

function _V:IsFilterDisabledByCvar(filter)
	local cvars = filterToOfficialCvar[filter];
	if (cvars) then
		for k, cvar in ipairs(cvars) do
			if (not C_CVar.GetCVarBool(cvar)) then
				return true;
			end
		end
	end
	return false
end

local defaultSettings = {
	global = {
		versionCheck = 1;
		updateSeen = false;

		["colors"] = {
			["timeCritical"]		= RED_FONT_COLOR:GenerateHexColor();
			["timeShort"]			= defaultColors.fontOrange:GenerateHexColor();
			["timeMedium"]			= defaultColors.fontGreen:GenerateHexColor();
			["timeLong"]			= defaultColors.fontBlue:GenerateHexColor();
			["timeVeryLong"]		= defaultColors.fontPurple:GenerateHexColor();
			["timeNone"]			= defaultColors.rewardCurrency:GenerateHexColor();
			
			["rewardNone"]			= defaultColors.rewardNone:GenerateHexColor();
			["rewardWeapon"]		= defaultColors.rewardWeapon:GenerateHexColor();
			["rewardArmor"]			= defaultColors.rewardArmor:GenerateHexColor();
			["rewardConduit"]		= defaultColors.rewardRelic:GenerateHexColor();
			["rewardRelic"]			= defaultColors.rewardRelic:GenerateHexColor();
			["rewardAnima"]			= defaultColors.rewardArtifact:GenerateHexColor();
			["rewardArtifact"]		= defaultColors.rewardArtifact:GenerateHexColor();
			["rewardItem"]			= defaultColors.rewardItem:GenerateHexColor();
			["rewardXp"]			= defaultColors.rewardItem:GenerateHexColor();
			["rewardGold"]			= defaultColors.rewardGold:GenerateHexColor();
			["rewardCurrency"]		= defaultColors.rewardCurrency:GenerateHexColor();
			["rewardHonor"]			= defaultColors.rewardHonor:GenerateHexColor();
			["rewardReputation"]	= defaultColors.rewardCurrency:GenerateHexColor();
			["rewardMissing"]		= defaultColors.rewardMissing:GenerateHexColor();
			
			["rewardTextWeapon"]	= defaultColors.rewardWeapon:GenerateHexColor();
			["rewardTextArmor"]		= defaultColors.rewardArmor:GenerateHexColor();
			["rewardTextConduit"]	= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextRelic"]		= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextAnima"]		= GREEN_FONT_COLOR:GenerateHexColor();
			["rewardTextArtifact"]	= GREEN_FONT_COLOR:GenerateHexColor();
			["rewardTextItem"]		= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextXp"]		= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextGold"]		= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextCurrency"]	= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextHonor"]		= defaultColors.fontWhite:GenerateHexColor();
			["rewardTextReputation"] = defaultColors.fontWhite:GenerateHexColor();
		};
		
		["general"] = {
			sortBy = "reward";
			fullScreenContainerPos = {["anchor"] = "TOPLEFT", ["x"] = 0, ["y"] = -25};
		
			defaultTab = false;
			saveFilters = true;
			preciseFilters = false;
			emissaryOnly = false;
			autoEmisarry = true;
			bountyCounter = true;
			bountyReward = false;
			bountySelectedOnly = true;
			showDisliked = true;
			zoneQuests = enumZoneQuests.zone;
			
			sl_callingsBoard = true;
			sl_genericAnimaIcons = false;
			
			dislikedQuests = {};
			favoriteQuests = {};
			
			loadUtilities = true;
			
			useTomTom = true;
			TomTomAutoArrow = true;
			TomTomArrowOnClick = false;

			useCustomTooltip = true;
		};
		
		["list"] = {
			typeIcon = true;
			factionIcon = true;
			showZone = true;
			warbandIcon = false;
			amountColors = true;
			colorTime = true;
			fullTime = false;
			favoritesAtTop = true;
			rewardNumDisplay = 1;
		};

		["pin"] = {
			-- Mini icons
			typeIcon = true;
			favoriteIcon = true;
			numRewardIcons = 0;
			rarityIcon = false;
			timeIcon = false;
			warbandIcon = false;
			trackingIcon = true;

			continentVisible = enumPinContinent.none;
			zoneVisible = enumPinZone.all;

			disablePoI = false;
			filterPoI = true;
			fadeOnPing = true;
			eliteRing = false;
			trackingGlow = true;

			centerType = enumPinCenterType.reward;
			ringType = enumPinColorType.time;
			scale = 1;
			
			label = enumPinLabel.none;
			labelColorType = enumPinColorType.default;
			labelScale = 1;
		};

		["filters"] = {};
		
		["profiles"] = {};
	}
}

function _V:GetDefaultSettings()
	return defaultSettings;
end

function _V:GetDefaultSettingsCategory(category)
	return defaultSettings.global[category];
end

local filtersCategory = _V:GetDefaultSettingsCategory("filters");
if (filtersCategory) then
	for k, filterType in _V:EnumerateFilterTypes() do
		if (not filtersCategory[filterType]) then
			filtersCategory[filterType] = {
				["flags"] = {}, -- Table in table because legacy
			};
		end

		local flags = filtersCategory[filterType].flags;
		local filters = _V:GetFiltersOfType(filterType);
		for id in pairs(filters) do
			flags[id] = true;
		end
	end
end
