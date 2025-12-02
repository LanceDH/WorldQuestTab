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

local _L = addon.L;
local _playerFaction = UnitFactionGroup("Player");


------------------------
-- PUBLIC
------------------------

WQT_WORLD_QUEST_TAB = "World Quest Tab";

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

_V["CONDUIT_SUBTYPE"] = {
	["endurance"] = 1,
	["finesse"] = 2,
	["potency"] = 3,
}

WQT_GROUP_INFO = _L["GROUP_SEARCH_INFO"];
WQT_CONTAINER_DRAG = _L["CONTAINER_DRAG"];
WQT_CONTAINER_DRAG_TT = _L["CONTAINER_DRAG_TT"];
WQT_FULLSCREEN_BUTTON_TT = _L["WQT_FULLSCREEN_BUTTON_TT"];


WQT_CallbackRegistry = CreateFromMixins(CallbackRegistryMixin);
WQT_CallbackRegistry:SetUndefinedEventsAllowed(true);
WQT_CallbackRegistry:OnLoad();

------------------------
-- SHARED
------------------------

_V["PATH_CUSTOM_ICONS"] = "Interface/Addons/WorldQuestTab/Images/CustomIcons";
_V["LIST_ANCHOR_TYPE"] = {["flight"] = 1, ["world"] = 2, ["full"] = 3, ["taxi"] = 4};

_V["TOOLTIP_STYLES"] = { 
	["default"] = TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST,
	["callingAvailable"] = { ["hideObjectives"] = true; },
	["callingActive"] = TOOLTIP_QUEST_REWARDS_STYLE_CALLING_REWARD,
}

_V["COLOR_IDS"] = {
}


_V["WQT_COLOR_NONE"] =  CreateColor(0.45, 0.45, .45) ;
_V["WQT_COLOR_ARMOR"] =  CreateColor(0.95, 0.65, 1) ;
_V["WQT_COLOR_WEAPON"] =  CreateColor(1, 0.45, 1) ;
_V["WQT_COLOR_ARTIFACT"] = CreateColor(0, 0.75, 0);
_V["WQT_COLOR_CURRENCY"] = CreateColor(0.6, 0.4, 0.1) ;
_V["WQT_COLOR_GOLD"] = CreateColor(0.95, 0.8, 0) ;
_V["WQT_COLOR_HONOR"] = CreateColor(0.8, 0.26, 0);
_V["WQT_COLOR_ITEM"] = CreateColor(0.85, 0.85, 0.85) ;
_V["WQT_COLOR_MISSING"] = CreateColor(0.7, 0.1, 0.1);
_V["WQT_COLOR_RELIC"] = CreateColor(0.3, 0.7, 1);
_V["WQT_WHITE_FONT_COLOR"] = CreateColor(0.9, 0.9, 0.9);
_V["WQT_ORANGE_FONT_COLOR"] = CreateColor(1, 0.5, 0);
_V["WQT_GREEN_FONT_COLOR"] = CreateColor(0, 0.8, 0);
_V["WQT_BLUE_FONT_COLOR"] = CreateColor(0.2, 0.60, 1);
_V["WQT_PURPLE_FONT_COLOR"] = CreateColor(0.84, 0.38, 0.94);

_V["FILTER_TYPES"] = {
	["faction"] = 1
	,["type"] = 2
	,["reward"] = 3
}

_V["PIN_CENTER_TYPES"] =	{
	["blizzard"] = 1
	,["reward"] = 2
	,["faction"] = 3
}

_V["RING_TYPES"] = {
	["default"] = 1
	,["reward"] = 2
	,["time"] = 3
	,["rarity"] = 4
}

_V["ENUM_PIN_CONTINENT"] = {
	["none"] = 1
	,["tracked"] = 2
	,["all"] = 3
}


_V["ENUM_PIN_ZONE"] = {
	["none"] = 1
	,["tracked"] = 2
	,["all"] = 3
}

_V["ENUM_PIN_LABEL"] = {
	["none"] = 1
	,["time"] = 2
	,["amount"] = 3
}

_V["ENUM_ZONE_QUESTS"] = {
	["zone"] = 1
	,["neighbor"] = 2
	,["expansion"] = 3
}

_V["SORT_IDS"] = {
	time = "time";
	faction = "faction";
	type = "type";
	zone = "zone";
	name = "name";
	reward = "reward";
	quality = "quality";
}

-- Not where they should be. Count them as invalid. Thanks Blizzard
_V["BUGGED_POI"] =  {
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

_V["TIME_REMAINING_CATEGORY"] = {
	["none"] = 0
	,["expired"] = 1
	,["critical"] = 2 -- <15m
	,["short"] = 3 -- 1h
	,["medium"] = 4 -- 24h
	,["long"] = 5 -- 3d
	,["veryLong"] = 6 -- >3d
}

_V["NUMBER_ABBREVIATIONS_ASIAN"] = {
		{["value"] = 1000000000, ["format"] = _L["NUMBERS_THIRD"]}
		,{["value"] = 100000000, ["format"] = _L["NUMBERS_SECOND"], ["decimal"] = true}
		,{["value"] = 100000, ["format"] = _L["NUMBERS_FIRST"]}
		,{["value"] = 10000, ["format"] = _L["NUMBERS_FIRST"], ["decimal"] = true}
	}

_V["NUMBER_ABBREVIATIONS"] = {
		{["value"] = 10000000000, ["format"] = _L["NUMBERS_THIRD"]}
		,{["value"] = 1000000000, ["format"] = _L["NUMBERS_THIRD"], ["decimal"] = true}
		,{["value"] = 10000000, ["format"] = _L["NUMBERS_SECOND"]}
		,{["value"] = 1000000, ["format"] = _L["NUMBERS_SECOND"], ["decimal"] = true}
		,{["value"] = 10000, ["format"] = _L["NUMBERS_FIRST"]}
		,{["value"] = 1000, ["format"] = _L["NUMBERS_FIRST"], ["decimal"] = true}
	}

_V["WQT_CVAR_LIST"] = {
		["Petbattle"] = "showTamers"
		,["Artifact"] = "worldQuestFilterArtifactPower"
		,["Armor"] = "worldQuestFilterEquipment"
		,["Gold"] = "worldQuestFilterGold"
		,["Currency"] = "worldQuestFilterResources"
	}
	
_V["WQT_TYPEFLAG_LABELS"] = {
		[2] = {
			["Default"] = DEFAULT,
			["Elite"] = ELITE,
			["PvP"] = PVP,
			["Petbattle"] = PET_BATTLE_PVP_QUEUE,
			["Dungeon"] = TRACKER_HEADER_DUNGEON,
			["Raid"] = RAID,
			["Profession"] = BATTLE_PET_SOURCE_4,
			["Invasion"] = _L["TYPE_INVASION"],
			["Assault"] = SPLASH_BATTLEFORAZEROTH_8_1_FEATURE2_TITLE,
			["Bonus"] = SCENARIO_BONUS_LABEL,
			["Dragonrider"] = DRAGONRIDING_RACES_MAP_TOGGLE
		}
		,[3] = {
			["Item"] = ITEMS,
			["Armor"] = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT,
			["Gold"] = WORLD_QUEST_REWARD_FILTERS_GOLD,
			["Currency"] = CURRENCY,
			["Artifact"] = ITEM_QUALITY6_DESC,
			["Anima"] = WORLD_QUEST_REWARD_FILTERS_ANIMA,
			["Conduits"] = _L["REWARD_CONDUITS"],
			["Relic"] = RELICSLOT,
			["None"] = NONE,
			["Experience"] = POWER_TYPE_EXPERIENCE,
			["Honor"] = HONOR,
			["Reputation"] = REPUTATION
		}
	};

_V["FILTER_TYPE_OLD_CONTENT"] = {
	[2] = {
		["Invasion"] = true;
		["Assault"] = true;
	};
	[3] = {
		["Artifact"] = true;
		["Relic"] = true;
		["Conduits"] = true;
		["Anima"] = true;
	}
}

_V["REWARD_TYPE_ATLAS"] = {
		[WQT_REWARDTYPE.weapon] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.211, ["r"] = 0.277, ["t"] = 0.246, ["b"] = 0.277} -- Weapon
		,[WQT_REWARDTYPE.equipment] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.847, ["r"] = 0.91, ["t"] = 0.459, ["b"] = 0.49} -- Armor
		,[WQT_REWARDTYPE.relic] = {["texture"] = "poi-scrapper", ["scale"] = 1} -- Relic
		,[WQT_REWARDTYPE.artifact] = {["texture"] = "AzeriteReady", ["scale"] = 1.3} -- Azerite
		,[WQT_REWARDTYPE.item] = {["texture"] = "Banker", ["scale"] = 1.1} -- Item
		,[WQT_REWARDTYPE.gold] = {["texture"] = "Auctioneer", ["scale"] = 1} -- Gold
		,[WQT_REWARDTYPE.currency] = {["texture"] =  "Interface/MINIMAP/POIIcons", ["scale"] = 1, ["l"] = 0.4921875, ["r"] = 0.55859375, ["t"] = 0.0390625, ["b"] = 0.068359375, ["color"] = CreateColor(0.7, 0.52, 0.43)} -- Resources
		,[WQT_REWARDTYPE.honor] = {["texture"] = _playerFaction == "Alliance" and "poi-alliance" or "poi-horde", ["scale"] = 1} -- Honor
		,[WQT_REWARDTYPE.reputation] = {["texture"] = "QuestRepeatableTurnin", ["scale"] = 1.2} -- Rep
		,[WQT_REWARDTYPE.xp] = {["texture"] = "poi-door-arrow-up", ["scale"] = .9} -- xp
		,[WQT_REWARDTYPE.spell] = {["texture"] = "Banker", ["scale"] = 1.1}  -- spell acts like item
		,[WQT_REWARDTYPE.anima] = {["texture"] =  "AncientMana", ["scale"] = 1.5} -- Anima
		,[WQT_REWARDTYPE.conduit] = {
			[_V["CONDUIT_SUBTYPE"].potency] = {["texture"] =  "soulbinds_tree_conduit_icon_attack", ["scale"] = 1.15};
			[_V["CONDUIT_SUBTYPE"].endurance] = {["texture"] =  "soulbinds_tree_conduit_icon_protect", ["scale"] = 1.15};
			[_V["CONDUIT_SUBTYPE"].finesse] = {["texture"] =  "soulbinds_tree_conduit_icon_utility", ["scale"] = 1.15};
		}-- Anima
	}	

_V["FILTER_FUNCTIONS"] = {
		[2] = { -- Types
			["PvP"] 			= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.PvP; end 
			,["Petbattle"] 		= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.PetBattle; end 
			,["Dungeon"] 		= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Dungeon; end 
			,["Raid"] 			= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Raid; end 
			,["Profession"]		= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Profession; end 
			,["Invasion"] 		= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.Invasion; end 
			,["Assault"]		= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.FactionAssault; end 
			,["Elite"]			= function(questInfo, tagInfo) return tagInfo and tagInfo.isElite and tagInfo.worldQuestType ~= Enum.QuestTagType.Dungeon; end
			,["Default"]		= function(questInfo, tagInfo) return tagInfo and not tagInfo.isElite and tagInfo.worldQuestType == Enum.QuestTagType.Normal; end 
			,["Bonus"]			= function(questInfo, tagInfo) return not tagInfo; end
			,["Dragonrider"]	= function(questInfo, tagInfo) return tagInfo and tagInfo.worldQuestType == Enum.QuestTagType.DragonRiderRacing; end 
			}
		,[3] = { -- Reward filters
			["Armor"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.equipment + WQT_REWARDTYPE.weapon) > 0; end
			,["Relic"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.relic) > 0; end
			,["Item"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.spell + WQT_REWARDTYPE.item) > 0; end
			,["Anima"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.anima) > 0; end
			,["Conduits"]	= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.conduit) > 0; end
			,["Artifact"]	= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.artifact) > 0; end
			,["Honor"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.honor) > 0; end
			,["Gold"]		= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.gold) > 0; end
			,["Currency"]	= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.currency) > 0; end
			,["Experience"]	= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.xp) > 0; end
			,["Reputation"]	= function(questInfo, tagInfo) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.reputation) > 0; end
			,["None"]		= function(questInfo, tagInfo) return questInfo.reward.typeBits == WQT_REWARDTYPE.none; end
			}
	};

local kareshMapCoords = {
	[2371]	= {["x"] = 0.00, ["y"] = 0.00}, -- K'aresh
	[2472]	= {["x"] = 0.67, ["y"] = 0.80}, -- Tazavesh
}
local isleOfDornMapCoords = {
	[2248]	= {["x"] = 0.00, ["y"] = 0.00}, -- Isle of Dorn
	[2369]	= {["x"] = 0.18, ["y"] = 0.18},  -- Siren Isle
}
local khazalgarMapCoords = {
	[2248]	= {["x"] = 0.73, ["y"] = 0.23}, -- Isle of Dorn
	[2214]	= {["x"] = 0.57, ["y"] = 0.58}, -- Ringing Deeps
	[2215]	= {["x"] = 0.35, ["y"] = 0.47}, -- Hallowfall
	[2255]	= {["x"] = 0.46, ["y"] = 0.75}, -- Azj-Kahet
	[2346]	= {["x"] = 0.82, ["y"] = 0.74}, -- Undermine
	[2371]	= {["x"] = 0.17, ["y"] = 0.20}, -- K'aresh
}
local zaralekMapCoords = {
	[2133]	= {["x"] = 0.00, ["y"] = 0.00}, -- Zaralek Cavern
	[2022]	= {["x"] = 0.88, ["y"] = 0.84}, -- Waking Shores
	[2023]	= {["x"] = 0.88, ["y"] = 0.84}, -- Ohn'ahran Plains
	[2200]	= {["x"] = 0.88, ["y"] = 0.84}, -- Emerald Dream
	[2239]	= {["x"] = 0.88, ["y"] = 0.84}, -- Amirdrassil
	[2024]	= {["x"] = 0.88, ["y"] = 0.84}, -- Azure Span
	[2025]	= {["x"] = 0.88, ["y"] = 0.84}, -- Thaldraszus
	[2151]	= {["x"] = 0.88, ["y"] = 0.84}, -- Forbidden Reach
	[2112]	= {["x"] = 0.88, ["y"] = 0.84}, -- Valdrakken
}
local dragonlandsMapCoords = {
	[2022]	= {["x"] = 0.48, ["y"] = 0.35}, -- Waking Shores
	[2023]	= {["x"] = 0.44, ["y"] = 0.56}, -- Ohn'ahran Plains
	[2200]	= {["x"] = 0.31, ["y"] = 0.57}, -- Emerald Dream
	[2239]	= {["x"] = 0.24, ["y"] = 0.58}, -- Amirdrassil
	[2024]	= {["x"] = 0.55, ["y"] = 0.74}, -- Azure Span
	[2025]	= {["x"] = 0.63, ["y"] = 0.51}, -- Thaldraszus
	[2151]	= {["x"] = 0.65, ["y"] = 0.10}, -- Forbidden Reach

	[2133]	= {["x"] = 0.88, ["y"] = 0.84}, -- Zaralek Cavern
}
local shadowlandsMapCoords = {
	[1543]	= {["x"] = 0.23, ["y"] = 0.13}, -- The Maw
	[1536]	= {["x"] = 0.62, ["y"] = 0.21}, -- Maldraxxus
	[1525]	= {["x"] = 0.24, ["y"] = 0.54}, -- Revendreth
	[1670]	= {["x"] = 0.47, ["y"] = 0.51}, -- Oribos
	[1533]	= {["x"] = 0.71, ["y"] = 0.57}, -- Bastion
	[1565]	= {["x"] = 0.48, ["y"] = 0.80}, -- Ardenweald
	[1970]	= {["x"] = 0.85, ["y"] = 0.81}, -- Zereth Mortis
}
local nazjatarMapCoords = {
	[1355]	= {["x"] = 0.00, ["y"] = 0.00}, -- Nazjatar

	[864]	= {["x"] = 0.11, ["y"] = 0.52}, -- Vol'dun
	[863]	= {["x"] = 0.11, ["y"] = 0.52}, -- Nazmir
	[862]	= {["x"] = 0.11, ["y"] = 0.52}, -- Zuldazar
	[1165]	= {["x"] = 0.11, ["y"] = 0.52}, -- Dazar'alor

	[942]	= {["x"] = 0.77, ["y"] = 0.77}, -- Stromsong Valley
	[896]	= {["x"] = 0.77, ["y"] = 0.77}, -- Drustvar
	[895]	= {["x"] = 0.77, ["y"] = 0.77}, -- Tiragarde Sound
	[1161]	= {["x"] = 0.77, ["y"] = 0.77}, -- Boralus
	[1169]	= {["x"] = 0.77, ["y"] = 0.77}, -- Tol Dagor
	[1462]	= {["x"] = 0.77, ["y"] = 0.77}, -- Mechagon
}
local zandalarMapCoords = {
	[864]	= {["x"] = 0.39, ["y"] = 0.32}, -- Vol'dun
	[863]	= {["x"] = 0.57, ["y"] = 0.28}, -- Nazmir
	[862]	= {["x"] = 0.55, ["y"] = 0.61}, -- Zuldazar
	[1165]	= {["x"] = 0.55, ["y"] = 0.61}, -- Dazar'alor

	[1355]	= {["x"] = 0.86, ["y"] = 0.14}, -- Nazjatar
}
local kultirasMapCoords = {
	[942]	= {["x"] = 0.55, ["y"] = 0.25}, -- Stromsong Valley
	[896]	= {["x"] = 0.36, ["y"] = 0.67}, -- Drustvar
	[895]	= {["x"] = 0.56, ["y"] = 0.54}, -- Tiragarde Sound
	[1161]	= {["x"] = 0.56, ["y"] = 0.54}, -- Boralus
	[1169]	= {["x"] = 0.78, ["y"] = 0.61}, -- Tol Dagor
	[1462]	= {["x"] = 0.17, ["y"] = 0.28}, -- Mechagon

	[1355]	= {["x"] = 0.86, ["y"] = 0.14}, -- Nazjatar
}
local argusMapCoords = {
	[830]	= {["x"] = 0.61, ["y"] = 0.68}, -- Krokuun
	[885]	= {["x"] = 0.31, ["y"] = 0.51}, -- Antoran Wastes
	[882]	= {["x"] = 0.62, ["y"] = 0.26}, -- Eredath
}
local legionMapCoords = {
	[630]	= {["x"] = 0.33, ["y"] = 0.58}, -- Azsuna
	[680]	= {["x"] = 0.46, ["y"] = 0.45}, -- Suramar
	[634]	= {["x"] = 0.60, ["y"] = 0.33}, -- Stormheim
	[650]	= {["x"] = 0.46, ["y"] = 0.23}, -- Highmountain
	[641]	= {["x"] = 0.34, ["y"] = 0.33}, -- Val'sharah
	[790]	= {["x"] = 0.46, ["y"] = 0.84}, -- Eye of Azshara
	[646]	= {["x"] = 0.54, ["y"] = 0.68}, -- Broken Shore
	[627]	= {["x"] = 0.45, ["y"] = 0.64}, -- Dalaran
	[830]	= {["x"] = 0.86, ["y"] = 0.15}, -- Krokuun
	[885]	= {["x"] = 0.86, ["y"] = 0.15}, -- Antoran Wastes
	[882]	= {["x"] = 0.86, ["y"] = 0.15}, -- Eredath
}
local draenorMapCoords = {
	[550]	= {["x"] = 0.24, ["y"] = 0.49}, -- Nagrand
	[525]	= {["x"] = 0.34, ["y"] = 0.29}, -- Frostridge
	[543]	= {["x"] = 0.49, ["y"] = 0.21}, -- Gorgrond
	[535]	= {["x"] = 0.43, ["y"] = 0.56}, -- Talador
	[542]	= {["x"] = 0.46, ["y"] = 0.73}, -- Spired of Arak
	[539]	= {["x"] = 0.58, ["y"] = 0.67}, -- Shadowmoon
	[534]	= {["x"] = 0.58, ["y"] = 0.47}, -- Tanaan Jungle
	[588]	= {["x"] = 0.73, ["y"] = 0.43}, -- Ashran
}
local pandariaMapCoords = {
	[554]	= {["x"] = 0.90, ["y"] = 0.68}, -- Timeless Isles
	[371]	= {["x"] = 0.67, ["y"] = 0.52}, -- Jade Forest
	[418]	= {["x"] = 0.53, ["y"] = 0.75}, -- Karasang
	[376]	= {["x"] = 0.51, ["y"] = 0.65}, -- Four Winds
	[422]	= {["x"] = 0.35, ["y"] = 0.62}, -- Dread Waste
	[390]	= {["x"] = 0.50, ["y"] = 0.52}, -- Eternal Blossom
	[379]	= {["x"] = 0.45, ["y"] = 0.35}, -- Kun-lai Summit
	[507]	= {["x"] = 0.48, ["y"] = 0.05}, -- Isle of Giants
	[388]	= {["x"] = 0.32, ["y"] = 0.45}, -- Townlong Steppes
	[504]	= {["x"] = 0.20, ["y"] = 0.11}, -- Isle of Thunder
	[1530]	= {["x"] = 0.51, ["y"] = 0.53}, -- Vale Of Eternal Blossom BfA
}
local northrendMapCoords = {
	[114]	= {["x"] = 0.22, ["y"] = 0.59}, -- Borean Tundra
	[119]	= {["x"] = 0.25, ["y"] = 0.41}, -- Sholazar Basin
	[118]	= {["x"] = 0.41, ["y"] = 0.26}, -- Icecrown
	[127]	= {["x"] = 0.47, ["y"] = 0.55}, -- Crystalsong
	[120]	= {["x"] = 0.61, ["y"] = 0.21}, -- Stormpeaks
	[121]	= {["x"] = 0.77, ["y"] = 0.32}, -- Zul'Drak
	[116]	= {["x"] = 0.71, ["y"] = 0.53}, -- Grizzly Hillsbrad
	[113]	= {["x"] = 0.78, ["y"] = 0.74}, -- Howling Fjord
}
local outlandMapCoords = {
	[104]	= {["x"] = 0.74, ["y"] = 0.80}, -- Shadowmoon Valley
	[108]	= {["x"] = 0.45, ["y"] = 0.77}, -- Terrokar
	[107]	= {["x"] = 0.30, ["y"] = 0.65}, -- Nagrand
	[100]	= {["x"] = 0.52, ["y"] = 0.51}, -- Hellfire
	[102]	= {["x"] = 0.33, ["y"] = 0.47}, -- Zangarmarsh
	[105]	= {["x"] = 0.36, ["y"] = 0.23}, -- Blade's Edge
	[109]	= {["x"] = 0.57, ["y"] = 0.20}, -- Netherstorm
}
local stranglethornMapCoords = {
	[210]	= {["x"] = 0.42, ["y"] = 0.62}, -- Cape
	[50]	= {["x"] = 0.67, ["y"] = 0.40} -- North
}
local kalimdorMapCoords = {
	[81] 	= {["x"] = 0.42, ["y"] = 0.82}, -- Silithus
	[64]	= {["x"] = 0.50, ["y"] = 0.72}, -- Thousand Needles
	[249]	= {["x"] = 0.47, ["y"] = 0.91}, -- Uldum
	[1527]	= {["x"] = 0.47, ["y"] = 0.91}, -- Uldum BfA
	[71]	= {["x"] = 0.55, ["y"] = 0.84}, -- Tanaris
	[78]	= {["x"] = 0.50, ["y"] = 0.81}, -- Ungoro
	[69]	= {["x"] = 0.43, ["y"] = 0.70}, -- Feralas
	[70]	= {["x"] = 0.55, ["y"] = 0.67}, -- Dustwallow
	[199]	= {["x"] = 0.51, ["y"] = 0.67}, -- S Barrens
	[7]		= {["x"] = 0.47, ["y"] = 0.60}, -- Mulgore
	[66]	= {["x"] = 0.41, ["y"] = 0.57}, -- Desolace
	[65]	= {["x"] = 0.43, ["y"] = 0.46}, -- Stonetalon
	[10]	= {["x"] = 0.52, ["y"] = 0.50}, -- N Barrens
	[1]		= {["x"] = 0.58, ["y"] = 0.50}, -- Durotar
	[63]	= {["x"] = 0.49, ["y"] = 0.41}, -- Ashenvale
	[62]	= {["x"] = 0.46, ["y"] = 0.23}, -- Dakshore
	[76]	= {["x"] = 0.59, ["y"] = 0.37}, -- Azshara
	[198]	= {["x"] = 0.54, ["y"] = 0.32}, -- Hyjal
	[77]	= {["x"] = 0.49, ["y"] = 0.25}, -- Felwood
	[80]	= {["x"] = 0.53, ["y"] = 0.19}, -- Moonglade
	[83]	= {["x"] = 0.58, ["y"] = 0.23}, -- Winterspring
	[57]	= {["x"] = 0.42, ["y"] = 0.10}, -- Teldrassil
	[97]	= {["x"] = 0.33, ["y"] = 0.27}, -- Azuremyst
	[106]	= {["x"] = 0.30, ["y"] = 0.18}, -- Bloodmyst
}
local easternKingdomsMapCoords = {
	[210]	= {["x"] = 0.47, ["y"] = 0.87}, -- Cape of STV
	[50]	= {["x"] = 0.47, ["y"] = 0.87}, -- N STV
	[17]	= {["x"] = 0.54, ["y"] = 0.89}, -- Blasted Lands
	[51]	= {["x"] = 0.54, ["y"] = 0.78}, -- Swamp of Sorrow
	[42]	= {["x"] = 0.49, ["y"] = 0.79}, -- Deadwind
	[47]	= {["x"] = 0.45, ["y"] = 0.80}, -- Duskwood
	[52]	= {["x"] = 0.40, ["y"] = 0.79}, -- Westfall
	[37]	= {["x"] = 0.47, ["y"] = 0.75}, -- Elwynn
	[49]	= {["x"] = 0.51, ["y"] = 0.75}, -- Redridge
	[36]	= {["x"] = 0.49, ["y"] = 0.70}, -- Burning Steppes
	[32]	= {["x"] = 0.47, ["y"] = 0.65}, -- Searing Gorge
	[15]	= {["x"] = 0.52, ["y"] = 0.65}, -- Badlands
	[27]	= {["x"] = 0.44, ["y"] = 0.61}, -- Dun Morogh
	[48]	= {["x"] = 0.52, ["y"] = 0.60}, -- Loch Modan
	[241]	= {["x"] = 0.56, ["y"] = 0.55}, -- Twilight Highlands
	[56]	= {["x"] = 0.50, ["y"] = 0.53}, -- Wetlands
	[14]	= {["x"] = 0.51, ["y"] = 0.46}, -- Arathi Highlands
	[26]	= {["x"] = 0.57, ["y"] = 0.40}, -- Hinterlands
	[25]	= {["x"] = 0.46, ["y"] = 0.40}, -- Hillsbrad
	[217]	= {["x"] = 0.40, ["y"] = 0.48}, -- Ruins of Gilneas
	[21]	= {["x"] = 0.41, ["y"] = 0.39}, -- Silverpine
	[18]	= {["x"] = 0.39, ["y"] = 0.32}, -- Tirisfall
	[22]	= {["x"] = 0.49, ["y"] = 0.31}, -- W Plaugelands
	[23]	= {["x"] = 0.54, ["y"] = 0.32}, -- E Plaguelands
	[95]	= {["x"] = 0.56, ["y"] = 0.23}, -- Ghostlands
	[94]	= {["x"] = 0.54, ["y"] = 0.18}, -- Eversong
	[122]	= {["x"] = 0.55, ["y"] = 0.05}, -- Quel'Danas
}
local azerothMapCoords = {
	[12]	= {["x"] = 0.17, ["y"] = 0.55, ["expansion"] = 0}; -- Kalimdor
	[13]	= {["x"] = 0.89, ["y"] = 0.55, ["expansion"] = 0}; -- Eastern Kingdoms
	[113]	= {["x"] = 0.50, ["y"] = 0.13, ["expansion"] = LE_EXPANSION_WRATH_OF_THE_LICH_KING}; -- Northrend
	[424]	= {["x"] = 0.50, ["y"] = 0.81, ["expansion"] = LE_EXPANSION_MISTS_OF_PANDARIA}; -- Pandaria
	[619]	= {["x"] = 0.58, ["y"] = 0.40, ["expansion"] = LE_EXPANSION_LEGION}; -- Broken Isles
	[875]	= {["x"] = 0.55, ["y"] = 0.63, ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH}; -- Zandalar
	[876]	= {["x"] = 0.71, ["y"] = 0.49, ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH}; -- Kul Tiras
	[1978]	= {["x"] = 0.76, ["y"] = 0.22, ["expansion"] = LE_EXPANSION_DRAGONFLIGHT}; -- Dragon Isle
	[2274]	= {["x"] = 0.28, ["y"] = 0.83, ["expansion"] = LE_EXPANSION_WAR_WITHIN}; -- Khaz Algar
}

_V["WQT_ZONE_MAPCOORDS"] = {
		[947]	= azerothMapCoords; -- All of Azeroth.
		[13]	= easternKingdomsMapCoords;
		[1208]	= easternKingdomsMapCoords; -- Flightmap
		[12] 	= kalimdorMapCoords;
		[1209] 	= kalimdorMapCoords; -- Flightmap
		[224]	= stranglethornMapCoords; -- Stranglethorn Vale

		[572]	= draenorMapCoords;
		[990]	= draenorMapCoords; -- Flightmap

		[424]	= pandariaMapCoords;
		[989]	= pandariaMapCoords; -- Flightmap

		[113]	= northrendMapCoords;
		[1384]	= northrendMapCoords; -- Flightmap

		[101]	= outlandMapCoords;
		[1467]	= outlandMapCoords; -- Flightmap

		[619] 	= legionMapCoords;
		[993] 	= legionMapCoords; -- Flightmap	
		[905] 	= argusMapCoords;
		[994] 	= argusMapCoords; -- Flightmap

		[875]	= zandalarMapCoords;
		[1011]	= zandalarMapCoords; -- Flightmap
		[876]	= kultirasMapCoords;
		[1014]	= kultirasMapCoords; -- Flightmap
		[1355]	= nazjatarMapCoords;
		[1504]	= nazjatarMapCoords; -- Flightmap

		[1550]	= shadowlandsMapCoords;
		[1647]	= shadowlandsMapCoords; -- Flightmap

		[1978]	= dragonlandsMapCoords;
		[2057]	= dragonlandsMapCoords; -- Flightmap

		[2133]	= zaralekMapCoords;
		[2274]	= khazalgarMapCoords;
		[2276]	= khazalgarMapCoords; -- Flightmap
		[2248]	= isleOfDornMapCoords;
		[2371]	= kareshMapCoords;
		[2398]	= kareshMapCoords; -- Flightmap
	}

-- Expansions that span multiple continents (maps containing multiple zones)
local linkedContinents = {
	{2274, 2276, 2248, 2371}, -- War Within
	{1978, 2057, 2133}, -- DragonFlight
	{875, 1011, 876, 1014, 1355, 1504}, -- BfA
	{619, 993, 905}, -- Legion
}

_V["WQT_CONTINENT_LINKS"] = {};
for _, group in ipairs(linkedContinents) do
	for _, mapID in ipairs(group) do
		_V["WQT_CONTINENT_LINKS"][mapID] = group;
	end
end
wipe(linkedContinents);

_V["ZONE_SUBZONES"] = {
	[1565] = {1701, 1702, 1703}; -- Ardenweald covenant
	[1533] = {1707, 1708}; -- Bastion Covenant
	[1525] = {1699, 1700}; -- Revendreth Covenant
	[1536] = {1698}; -- Maldraxxus Covenant

	[224] = {50, 210}; -- Stranglethorn
	[2371] = {2472}; -- K'aresh -> Tazavesh
}

_V["WQT_NO_FACTION_DATA"] = { ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 131071, ["name"]=_L["NO_FACTION"] } -- No faction
_V["WQT_FACTION_DATA"] = {
	[67] = 		{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 2203914 } -- Horde
	,[469] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 2203912 } -- Alliance
	,[609] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 1396983 } -- Cenarion Circle - Call of the Scarab
	,[910] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 236232 } -- Brood of Nozdormu - Call of the Scarab
	,[1106] = 	{ ["expansion"] = LE_EXPANSION_CLASSIC, ["texture"] = 236690 } -- Argent Crusade

	,[1445] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 133283 } -- Draenor Frostwolf Orcs
	,[1515] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1002596 } -- Dreanor Arakkoa Outcasts
	,[1731] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1048727 } -- Dreanor Council of Exarchs
	,[1681] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1042727 } -- Dreanor Vol'jin's Spear
	,[1682] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR, ["texture"] = 1042294 } -- Dreanor Wrynn's Vanguard
	-- Legion
	,[1090] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394955 } -- Kirin Tor
	,[1828] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394954 } -- Highmountain Tribes
	,[1859] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394956 } -- Nightfallen
	,[1883] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394953 } -- Dreamweavers
	,[1894] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394958 } -- Wardens
	,[1900] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394952 } -- Court of Farnodis

	,[1948] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1394957 } -- Valarjar
	,[2045] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708498 } -- Legionfall
	,[2165] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708497 } -- Army of the Light
	,[2170] = 	{ ["expansion"] = LE_EXPANSION_LEGION, ["texture"] = 1708496 } -- Argussian Reach
	-- BFA
	,[2103] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065579 ,["playerFaction"] = "Horde" } -- Zandalari Empire
	,[2156] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065575, ["playerFaction"] = "Horde" } -- Talanji's Expedition
	,[2157] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065571, ["playerFaction"] = "Horde" } -- The Honorbound
	,[2158] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032599, ["playerFaction"] = "Horde" } -- Voldunai
	,[2159] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065569, ["playerFaction"] = "Alliance" } -- 7th Legion
	,[2160] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2065573, ["playerFaction"] = "Alliance" } -- Proudmoore Admirality
	,[2161] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032594, ["playerFaction"] = "Alliance" } -- Order of Embers
	,[2162] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032596, ["playerFaction"] = "Alliance" } -- Storm's Wake
	,[2163] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032598 } -- Tortollan Seekers
	,[2164] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2032592 } -- Champions of Azeroth
	,[2391] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2909316 } -- Rustbolt
	,[2373] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2821782, ["playerFaction"] = "Horde" } -- Unshackled
	,[2400] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 2909045, ["playerFaction"] = "Alliance" } -- Waveblade Ankoan
	,[2417] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 3196264 } -- Uldum Accord
	,[2415] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH, ["texture"] = 3196265 } -- Rajani
	-- Shadowlands
	,[2407] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3257748 } -- The Ascended
	,[2410] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3641396 } -- The Undying Army
	,[2413] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3257751 } -- Court of Harvesters
	,[2465] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3641394 } -- The Wild Hunt
	,[2432] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 3729461 } -- Ve'nari
	,[2470] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4083292 } -- Korthia
	,[2472] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4067928 } -- Korthia Codex
	,[2478] =	{ ["expansion"] = LE_EXPANSION_SHADOWLANDS, ["texture"] = 4226232 } -- Zereth Mortis
	-- LE_EXPANSION_DRAGONFLIGHT
	,[2523] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4528811 } -- Dark Talons
	,[2507] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687628 } -- Dragonscale Expedition
	,[2574] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 5244643 } -- Dream Wardens
	,[2511] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687629 } -- Iskaara Tuskarr
	,[2564] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 5140835 } -- Loamm Niffen
	,[2503] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687627 } -- Maruuk Centaur
	,[2510] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4687630 } -- Valdrakken Accord
	,[2524] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4528812 } -- Obsidian Warders
	,[2517] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4640487 } -- Wrathion
	,[2518] =	{ ["expansion"] = LE_EXPANSION_DRAGONFLIGHT, ["texture"] = 4640488 } -- Sabellian
	-- LE_EXPANSION_WAR_WITHIN
	,[2570] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 5891368 } -- Hallowfall Arathi
	,[2594] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6029027 } -- The Assembly of the Deeps
	,[2590] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6029029 } -- Council of Dornogal
	,[2600] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 5891370 } -- The Severed Threads
	,[2653] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6351805 } -- The Cartels of Undermine
	,[2673] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439627 } -- Bilgewater
	,[2669] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439629 } -- Darkfuse
	,[2675] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439628 } -- Blackwater
	,[2677] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439630 } -- Steamwheedle
	,[2671] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6439631 } -- Venture Co.
	,[2658] =	{ ["expansion"] = LE_EXPANSION_WAR_WITHIN, ["texture"] = 6937966 } -- K'aresh Trust
}
-- Add localized faction names
for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	local info = C_Reputation.GetFactionDataByID(k);
	if(info) then
		v.name = info.name;
	end
end


_V["WQT_FILTER_TO_OFFICIAL"] = {
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

_V["WQT_DEFAULTS"] = {
	global = {
		versionCheck = 1;
		updateSeen = false;
		
		["colors"] = {
			["timeCritical"] = RED_FONT_COLOR:GenerateHexColor();
			["timeShort"] = _V["WQT_ORANGE_FONT_COLOR"]:GenerateHexColor();
			["timeMedium"] = _V["WQT_GREEN_FONT_COLOR"]:GenerateHexColor();
			["timeLong"] = _V["WQT_BLUE_FONT_COLOR"]:GenerateHexColor();
			["timeVeryLong"] = _V["WQT_PURPLE_FONT_COLOR"]:GenerateHexColor();
			["timeNone"] = _V["WQT_COLOR_CURRENCY"]:GenerateHexColor();
			
			["rewardNone"] = _V["WQT_COLOR_NONE"]:GenerateHexColor();
			["rewardWeapon"] = _V["WQT_COLOR_WEAPON"]:GenerateHexColor();
			["rewardArmor"] = _V["WQT_COLOR_ARMOR"]:GenerateHexColor();
			["rewardConduit"] = _V["WQT_COLOR_RELIC"]:GenerateHexColor();
			["rewardRelic"] = _V["WQT_COLOR_RELIC"]:GenerateHexColor();
			["rewardAnima"] = _V["WQT_COLOR_ARTIFACT"]:GenerateHexColor();
			["rewardArtifact"] = _V["WQT_COLOR_ARTIFACT"]:GenerateHexColor();
			["rewardItem"] = _V["WQT_COLOR_ITEM"]:GenerateHexColor();
			["rewardXp"] = _V["WQT_COLOR_ITEM"]:GenerateHexColor();
			["rewardGold"] = _V["WQT_COLOR_GOLD"]:GenerateHexColor();
			["rewardCurrency"] = _V["WQT_COLOR_CURRENCY"]:GenerateHexColor();
			["rewardHonor"] = _V["WQT_COLOR_HONOR"]:GenerateHexColor();
			["rewardReputation"] = _V["WQT_COLOR_CURRENCY"]:GenerateHexColor();
			["rewardMissing"] = _V["WQT_COLOR_MISSING"]:GenerateHexColor();
			
			["rewardTextWeapon"] = _V["WQT_COLOR_WEAPON"]:GenerateHexColor();
			["rewardTextArmor"] = _V["WQT_COLOR_ARMOR"]:GenerateHexColor();
			["rewardTextConduit"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextRelic"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextAnima"] = GREEN_FONT_COLOR:GenerateHexColor();
			["rewardTextArtifact"] = GREEN_FONT_COLOR:GenerateHexColor();
			["rewardTextItem"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextXp"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextGold"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextCurrency"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextHonor"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
			["rewardTextReputation"] = _V["WQT_WHITE_FONT_COLOR"]:GenerateHexColor();
		};
		
		["general"] = {
			sortBy = _V["SORT_IDS"].reward;
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
			zoneQuests = _V["ENUM_ZONE_QUESTS"].zone;
			
			sl_callingsBoard = true;
			sl_genericAnimaIcons = false;
			
			dislikedQuests = {};
			
			loadUtilities = true;
			
			useTomTom = true;
			TomTomAutoArrow = true;
			TomTomArrowOnClick = false;
		};
		
		["list"] = {
			typeIcon = true;
			factionIcon = true;
			showZone = true;
			warbandIcon = false;
			amountColors = true;
			colorTime = true;
			fullTime = false;
			rewardNumDisplay = 1;
		};

		["pin"] = {
			-- Mini icons
			typeIcon = true;
			numRewardIcons = 0;
			rarityIcon = false;
			timeIcon = false;
			warbandIcon = false;
			continentVisible = _V["ENUM_PIN_CONTINENT"].none;
			zoneVisible = _V["ENUM_PIN_ZONE"].all;
			
			filterPoI = true;
			scale = 1;
			disablePoI = false;
			fadeOnPing = true;
			eliteRing = false;
			labelColors = true;
			ringType = _V["RING_TYPES"].time;
			centerType = _V["PIN_CENTER_TYPES"].reward;
			label = _V["ENUM_PIN_LABEL"].none;
		};

		["filters"] = {
				[_V["FILTER_TYPES"].faction] = {["name"] = FACTION
						,["misc"] = {
							["none"] = true,
							["other"] = true},
							["flags"] = {} -- Faction filters are assigned later
						}
				,[_V["FILTER_TYPES"].type] = {["name"] = TYPE
						, ["flags"] = {
							["Default"] = true,
							["Elite"] = true,
							["PvP"] = true,
							["Petbattle"] = true,
							["Dungeon"] = true,
							["Raid"] = true,
							["Profession"] = true,
							["Invasion"] = true,
							["Assault"] = true,
							["Bonus"] = true,
							["Dragonrider"] = true
						}}
				,[_V["FILTER_TYPES"].reward] = {["name"] = REWARD
						, ["flags"] = {
							["Item"] = true,
							["Armor"] = true,
							["Gold"] = true,
							["Currency"] = true,
							["Anima"] = true,
							["Conduits"] = true,
							["Artifact"] = true,
							["Relic"] = true,
							["None"] = true,
							["Experience"] = true,
							["Honor"] = true,
							["Reputation"] = true
						}}
			};
			
		["profiles"] = {
			
		};
	}
}

for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	if v.expansion >= LE_EXPANSION_LEGION then
		_V["WQT_DEFAULTS"].global.filters[1].flags[k] = true;
	end
end