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
	callingAvailable	= { ["hideObjectives"] = true; };
	callingActive		= TOOLTIP_QUEST_REWARDS_STYLE_CALLING_REWARD;
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

local enumRingType = {
	default	= 1;
	reward	= 2;
	time	= 3;
	rarity	= 4;
}
function _V:GetRingTypeEnum()
	return enumRingType;
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

local enumZoneIDs =
{
	Azeroth = 947;

	Kalimdor = 12;
	Silithus = 81;
	ThousandNeedles = 64;
	Uldum = 249;
	Tanaris = 71;
	UngoroCrater = 78;
	Feralas = 69;
	DustwallowMarsh = 70;
	SouthernBarrens = 199;
	Mulgore = 7;
	Desolace = 66;
	StonetalonMountain = 65;
	NorthernBarrens = 10;
	Durotar = 1;
	Ashenvale = 63;
	Darkshore = 62;
	Azshara = 76;
	Hyjal = 198;
	Felwood = 77;
	Moonglade = 80;
	Winterspring = 83;
	Teldrassil = 57;
	AzuremystIsle = 97;
	BloodmystIsle = 106;

	EasternKingdoms = 13;
	StranglethronVale = 224;
	StranglethronValeNorth = 50;
	StranglethronValeCape = 210;
	BlastedLands = 17;
	SwampOfSorrows = 51;
	DeadwindPass = 42;
	Duskwood = 47;
	Westfall = 52;
	ElwynnForest = 37;
	RedridgeMountains = 49;
	BurningSteppes = 36;
	SearingGorge = 32;
	Badlands = 15;
	DunMorogh = 27;
	LochModan = 48;
	TwilightHighlands = 241;
	Wetlands = 56;
	ArathiHighlands = 14;
	Hinterlands = 26;
	HillsbradFoothills = 25;
	RuinsOfGilneas = 217;
	SilverpineForest = 21;
	TirisfallGlades = 18;
	WesternPlaguelands = 22;
	EasternPlaguelands = 23;

	Pandaria = 424;
	PandariaFlightmap = 989;
	JadeForest = 371;
	KarasangWilds = 418;
	ValleyOfTheFourWinds = 376;
	DreadWastes = 422;
	ValleyOfEternalBlossom = 390;
	TownlongSteppes = 388;
	KunlaiSummit = 379;
	IsleOfGiants = 507;
	IsleOfThunder = 504;
	TimelessIsle = 554;

	Draenor = 572;
	DraenorFlightmap = 990;
	NagrandWoD = 550;
	FrostfireRidge = 525;
	Gorgrond = 543;
	Talador = 535;
	SpiresOfArak = 542;
	ShadowmoonValleyWoD = 539;
	TanaanJungle = 534;
	Ashran = 588;

	BrokenIsles = 619;
	BrokenIslesFlightmap = 993;
	Azsuna = 630;
	Suramar = 680;
	Stormheim = 634;
	Highmountain = 650;
	Valsharah = 641;
	EyeOfAzshara = 790;
	BrokenShore = 646;
	DalaranLegion = 627;
	Argus = 905;
	ArgusFlightmap = 994;
	Krokuun = 830;
	AntoranWastes = 885;
	Eredath = 882;

	Zandalar = 875;
	ZandalarFlightmap = 1011;
	Voldun = 864;
	Nazmir = 863;
	Zuldazar = 862;
	Dazaralor = 1165;
	Kultiras = 876;
	KultirasFlightmap = 1014;
	StormsongValley = 942;
	Drustvar = 896;
	TiragardeSound = 895;
	Boralus = 1161;
	TolDagor = 1169;
	Mechagon = 1462;
	Nazjatar = 1355;
	NazjatarFlightmap = 1504;
	UldumBfA = 1527;
	ValeOfEternalBlossomBfA = 1530;

	Shadowlands = 1550;
	ShadowlandsFlightmap = 1647;
	TheMaw = 1543;
	Maldraxxus = 1536;
	Revendreth = 1525;
	Oribos = 1670;
	Bastion = 1533;
	Ardenweald = 1565;
	ZerethMortis = 1970;

	DragonIsles = 1978;
	DragonIslesFlightmap = 2057;
	ZaralekCavern = 2133;
	WakingShores = 2022;
	OhnahranPlains = 2023;
	EmeraldDream = 2200;
	Amidrassil = 2239;
	AzureSpan = 2024;
	Thaldraszus = 2025;
	ForgbiddenReach = 2151;
	Valdrakken = 2112;

	KhazAlgar = 2274;
	KhazAlgarFlightmap = 2276;
	IsleOfDorn = 2248;
	Dornogal = 2339;
	SirenIsle = 2369;
	RingingDeeps = 2214;
	Hallowfall = 2215;
	AzjKahet = 2255;
	Undermine = 2346;
	Karesh = 2371;
	KareshFlightmap = 2398;
	Tazavesh = 2472;

	QuelThalas = 2537;
	QuelThalasFlightmap = 2481;
	IlseOfQuelDanas = 2424;
	EversongWoods = 2395;
	SilvermoonCity = 2393;
	ZulAman = 2437;
	Voidstorm = 2405;
	VoidstormFlightmap = 2479;
	Haradar = 2413;
	HaradarFlightmap = 2480;
}

local zoneData = {};
local zonesPerExpansion = {
	[0] = {};
};

local function AddZoneData(zoneID, name)
	local data = {
		name = name;
		expansion = 0;
		children = {};
		mapInfo = C_Map.GetMapInfo(zoneID);
	};
	zoneData[zoneID] = data;
	zonesPerExpansion[0][zoneID] = true;
	return data;
end

local function AddChildToZone(zoneID, childZoneID, coordX, coordY, isSubZone)
	local data = zoneData[zoneID];
	if (not data) then return; end;

	local childData = {
		x = coordX;
		y = coordY;
		isSubZone = isSubZone;
	}

	data.children[childZoneID] = childData;
end

local function MarkZoneForExampansion(expansion, zoneID, includeChildren)
	local data = zoneData[zoneID];
	if (not data) then return; end;

	if (not zonesPerExpansion[expansion]) then
		zonesPerExpansion[expansion] = {};
	end

	if (zonesPerExpansion[expansion][zoneID]) then return; end

	zonesPerExpansion[data.expansion][zoneID] = nil;
	data.expansion = expansion;

	zonesPerExpansion[expansion][zoneID] = true;

	if (includeChildren) then
		for childID in pairs(data.children) do
			MarkZoneForExampansion(expansion, childID, true);
		end
	end
end

local function MarkZoneAsFlightmap(zoneID)
	local data = zoneData[zoneID];
	if (not data) then return; end;
	data.isFlightMap = true;
end

for k, v in pairs(enumZoneIDs) do
	AddZoneData(v, k);
end

local includeChildren = true;
local isSubZone = true;

do -- Old content
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Silithus,			0.42, 0.82);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.ThousandNeedles,	0.50, 0.72);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Uldum,				0.47, 0.91);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.UldumBfA,			0.47, 0.91);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Tanaris,			0.55, 0.84);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.UngoroCrater,		0.50, 0.81);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Feralas,			0.43, 0.70);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.DustwallowMarsh,	0.55, 0.67);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.SouthernBarrens,	0.51, 0.67);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Mulgore,			0.47, 0.60);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Desolace,			0.41, 0.57);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.StonetalonMountain,	0.43, 0.46);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.NorthernBarrens,	0.52, 0.50);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Durotar,			0.58, 0.50);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Ashenvale,			0.49, 0.41);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Darkshore,			0.46, 0.23);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Azshara,			0.59, 0.37);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Hyjal,				0.54, 0.32);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Felwood,			0.49, 0.25);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Moonglade,			0.53, 0.19);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Winterspring,		0.58, 0.23);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.Teldrassil,			0.42, 0.10);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.AzuremystIsle,		0.33, 0.27);
	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.BloodmystIsle,		0.30, 0.18);

	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.BlastedLands,		0.54, 0.89);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.SwampOfSorrows,		0.54, 0.78);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.DeadwindPass,		0.49, 0.79);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.Duskwood,			0.45, 0.80);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.Westfall,			0.40, 0.79);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.ElwynnForest,		0.47, 0.75);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.RedridgeMountains,	0.51, 0.75);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.BurningSteppes,		0.49, 0.70);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.SearingGorge,		0.47, 0.65);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.Badlands,			0.52, 0.65);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.DunMorogh,			0.44, 0.61);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.LochModan,			0.52, 0.60);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.TwilightHighlands,	0.56, 0.55);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.Wetlands,			0.50, 0.53);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.ArathiHighlands,	0.51, 0.46);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.Hinterlands,		0.57, 0.40);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.HillsbradFoothills,	0.46, 0.40);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.RuinsOfGilneas,		0.40, 0.48);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.SilverpineForest,	0.41, 0.39);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.WesternPlaguelands,	0.49, 0.31);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.EasternPlaguelands,	0.54, 0.32);

	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.StranglethronVale,	0.47, 0.87,	isSubZone);
	AddChildToZone(enumZoneIDs.EasternKingdoms,	enumZoneIDs.QuelThalas,			0.58, 0.21,	isSubZone);

	AddChildToZone(enumZoneIDs.StranglethronVale,	enumZoneIDs.StranglethronValeNorth,	0.67, 0.40,	isSubZone);
	AddChildToZone(enumZoneIDs.StranglethronVale,	enumZoneIDs.StranglethronValeCape,	0.42, 0.62,	isSubZone);

	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.Kalimdor,			0.18, 0.54);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.EasternKingdoms,	0.89, 0.55);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.Pandaria,			0.48, 0.80);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.BrokenIsles,		0.58, 0.40);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.Zandalar,			0.54, 0.62);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.Kultiras,			0.71, 0.50);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.DragonIsles,		0.76, 0.22);
	AddChildToZone(enumZoneIDs.Azeroth,	enumZoneIDs.KhazAlgar,			0.29, 0.82);

	-- General case we just want to avoid scanning
	MarkZoneForExampansion(-1, enumZoneIDs.Azeroth);
end

do -- Pandaria
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.TimelessIsle,			0.90, 0.68);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.JadeForest,				0.67, 0.52);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.KarasangWilds,			0.53, 0.75);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.ValleyOfTheFourWinds,	0.51, 0.65);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.DreadWastes,			0.35, 0.62);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.ValleyOfEternalBlossom,	0.50, 0.52);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.KunlaiSummit,			0.45, 0.35);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.IsleOfGiants,			0.48, 0.05);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.TownlongSteppes,		0.32, 0.45);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.IsleOfThunder,			0.20, 0.11);

	MarkZoneForExampansion(LE_EXPANSION_MISTS_OF_PANDARIA, enumZoneIDs.Pandaria, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_MISTS_OF_PANDARIA, enumZoneIDs.PandariaFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.PandariaFlightmap);
end

do -- Warlord of Draenor
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.NagrandWoD,				0.24, 0.49);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.FrostfireRidge,			0.34, 0.29);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.Gorgrond,				0.49, 0.21);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.Talador,				0.43, 0.56);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.SpiresOfArak,			0.46, 0.73);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.ShadowmoonValleyWoD,	0.58, 0.67);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.TanaanJungle,			0.58, 0.47);
	AddChildToZone(enumZoneIDs.Draenor,	enumZoneIDs.Ashran,					0.73, 0.43);

	MarkZoneForExampansion(LE_EXPANSION_WARLORDS_OF_DRAENOR, enumZoneIDs.Draenor, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_WARLORDS_OF_DRAENOR, enumZoneIDs.DraenorFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.DraenorFlightmap);
end

do -- Legion
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Azsuna,			0.33, 0.58);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Suramar,		0.46, 0.45);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Stormheim,		0.60, 0.33);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Highmountain,	0.46, 0.23);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Valsharah,		0.34, 0.33);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.EyeOfAzshara,	0.46, 0.84);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.BrokenShore,	0.54, 0.68);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.DalaranLegion,	0.45, 0.64);
	AddChildToZone(enumZoneIDs.BrokenIsles,	enumZoneIDs.Argus,			0.88, 0.14);

	AddChildToZone(enumZoneIDs.Argus,	enumZoneIDs.Krokuun,		0.61, 0.68);
	AddChildToZone(enumZoneIDs.Argus,	enumZoneIDs.AntoranWastes,	0.31, 0.51);
	AddChildToZone(enumZoneIDs.Argus,	enumZoneIDs.Eredath,		0.62, 0.26);

	MarkZoneForExampansion(LE_EXPANSION_LEGION, enumZoneIDs.BrokenIsles, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_LEGION, enumZoneIDs.BrokenIslesFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_LEGION, enumZoneIDs.Argus, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_LEGION, enumZoneIDs.ArgusFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.BrokenIslesFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.ArgusFlightmap);
end

do -- Battle of Azertoh
	AddChildToZone(enumZoneIDs.Zandalar,	enumZoneIDs.Voldun,		0.39, 0.32);
	AddChildToZone(enumZoneIDs.Zandalar,	enumZoneIDs.Nazmir,		0.57, 0.28);
	AddChildToZone(enumZoneIDs.Zandalar,	enumZoneIDs.Zuldazar,	0.55, 0.61);
	AddChildToZone(enumZoneIDs.Zandalar,	enumZoneIDs.Nazjatar,	0.86, 0.14);

	AddChildToZone(enumZoneIDs.Zuldazar,	enumZoneIDs.Dazaralor,	0.00, 0.00, isSubZone);

	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.StormsongValley,	0.55, 0.25);
	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.Drustvar,			0.36, 0.67);
	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.TiragardeSound,		0.56, 0.54);
	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.TolDagor,			0.78, 0.61);
	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.Mechagon,			0.17, 0.28);
	AddChildToZone(enumZoneIDs.Kultiras,	enumZoneIDs.Nazjatar,			0.86, 0.14);

	AddChildToZone(enumZoneIDs.TiragardeSound,	enumZoneIDs.Boralus,	0.56, 0.54, isSubZone);

	AddChildToZone(enumZoneIDs.Nazjatar,	enumZoneIDs.Zandalar,	0.11, 0.49);
	AddChildToZone(enumZoneIDs.Nazjatar,	enumZoneIDs.Kultiras,	0.77, 0.75);

	AddChildToZone(enumZoneIDs.Kalimdor,	enumZoneIDs.UldumBfA,					0.49, 0.90);
	AddChildToZone(enumZoneIDs.Pandaria,	enumZoneIDs.ValeOfEternalBlossomBfA,	0.50, 0.52);

	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.Zandalar, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.ZandalarFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.Kultiras, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.KultirasFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.Nazjatar, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.NazjatarFlightmap, includeChildren);

	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.UldumBfA);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.ValeOfEternalBlossomBfA);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.ArathiHighlands);
	MarkZoneForExampansion(LE_EXPANSION_BATTLE_FOR_AZEROTH, enumZoneIDs.Darkshore);

	MarkZoneAsFlightmap(enumZoneIDs.ZandalarFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.KultirasFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.NazjatarFlightmap);
end


do -- Shadowlands
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.TheMaw,			0.23, 0.13);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.Maldraxxus,		0.62, 0.21);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.Revendreth,		0.24, 0.54);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.Oribos,			0.47, 0.51);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.Bastion,		0.71, 0.57);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.Ardenweald,		0.48, 0.80);
	AddChildToZone(enumZoneIDs.Shadowlands,	enumZoneIDs.ZerethMortis,	0.85, 0.81);

	MarkZoneForExampansion(LE_EXPANSION_SHADOWLANDS, enumZoneIDs.Shadowlands, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_SHADOWLANDS, enumZoneIDs.ShadowlandsFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.ShadowlandsFlightmap);
end

do -- Dragonflight
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.WakingShores,		0.48, 0.35);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.OhnahranPlains,		0.44, 0.56);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.EmeraldDream,		0.31, 0.57);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.Amidrassil,			0.24, 0.58);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.AzureSpan,			0.55, 0.74);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.Thaldraszus,		0.63, 0.51);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.ForgbiddenReach,	0.65, 0.10);
	AddChildToZone(enumZoneIDs.DragonIsles,	enumZoneIDs.ZaralekCavern,		0.88, 0.84);

	AddChildToZone(enumZoneIDs.Thaldraszus,	enumZoneIDs.Valdrakken,		0.00, 0.00,	isSubZone);

	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.WakingShores,		0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.OhnahranPlains,		0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.EmeraldDream,		0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.Amidrassil,			0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.AzureSpan,			0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.Thaldraszus,		0.88, 0.84);
	AddChildToZone(enumZoneIDs.ZaralekCavern,	enumZoneIDs.ForgbiddenReach,	0.88, 0.84);

	MarkZoneForExampansion(LE_EXPANSION_DRAGONFLIGHT, enumZoneIDs.DragonIsles, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_DRAGONFLIGHT, enumZoneIDs.DragonIslesFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_DRAGONFLIGHT, enumZoneIDs.ZaralekCavern, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.DragonIslesFlightmap);
end

do -- War Within
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.IsleOfDorn,		0.73, 0.23);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.RingingDeeps,	0.57, 0.58);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.Hallowfall,		0.35, 0.47);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.AzjKahet,		0.46, 0.75);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.Undermine,		0.82, 0.74);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.Karesh,			0.17, 0.20);
	AddChildToZone(enumZoneIDs.KhazAlgar,	enumZoneIDs.SirenIsle,		0.73, 0.23);

	AddChildToZone(enumZoneIDs.IsleOfDorn,	enumZoneIDs.SirenIsle,	0.18, 0.18);
	AddChildToZone(enumZoneIDs.IsleOfDorn,	enumZoneIDs.Dornogal,	0.00, 0.00, isSubZone);

	AddChildToZone(enumZoneIDs.Karesh,	enumZoneIDs.Tazavesh,	0.00, 0.00, isSubZone);

	MarkZoneForExampansion(LE_EXPANSION_WAR_WITHIN, enumZoneIDs.KhazAlgar, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_WAR_WITHIN, enumZoneIDs.KhazAlgarFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_WAR_WITHIN, enumZoneIDs.KareshFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.KhazAlgarFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.KareshFlightmap);
end

do -- Midnight
	AddChildToZone(enumZoneIDs.QuelThalas,	enumZoneIDs.IlseOfQuelDanas,	0.26, 0.14);
	AddChildToZone(enumZoneIDs.QuelThalas,	enumZoneIDs.EversongWoods,		0.27, 0.53);
	AddChildToZone(enumZoneIDs.QuelThalas,	enumZoneIDs.ZulAman,			0.44, 0.71);
	AddChildToZone(enumZoneIDs.QuelThalas,	enumZoneIDs.Voidstorm,			0.53, 0.23);
	AddChildToZone(enumZoneIDs.QuelThalas,	enumZoneIDs.Haradar,			0.82, 0.16);

	AddChildToZone(enumZoneIDs.EversongWoods,	enumZoneIDs.SilvermoonCity,		0.00, 0.00, isSubZone);

	MarkZoneForExampansion(LE_EXPANSION_MIDNIGHT, enumZoneIDs.QuelThalas, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_MIDNIGHT, enumZoneIDs.QuelThalasFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_MIDNIGHT, enumZoneIDs.VoidstormFlightmap, includeChildren);
	MarkZoneForExampansion(LE_EXPANSION_MIDNIGHT, enumZoneIDs.HaradarFlightmap, includeChildren);

	MarkZoneAsFlightmap(enumZoneIDs.QuelThalasFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.VoidstormFlightmap);
	MarkZoneAsFlightmap(enumZoneIDs.HaradarFlightmap);
end

function _V:GetMostRelevantMapCoordinates(zoneID, inZoneID)
	local childData = nil;
	local coordZoneID = zoneID;
	if (zoneID ~= inZoneID) then
		local data = zoneData[inZoneID];
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

function _V:GetZoneData(zoneID)
	return zoneData[zoneID];
end

function _V:GetZonesOfExpansion(expansion)
	return zonesPerExpansion[expansion];
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
			
			filterPoI = true;
			scale = 1;
			disablePoI = false;
			fadeOnPing = true;
			eliteRing = false;
			labelColors = true;
			trackingGlow = true;
			ringType = enumRingType.time;
			centerType = enumPinCenterType.reward;
			label = enumPinLabel.none;
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
