local addonName, addon = ...


addon.WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");
addon.debug = true;
addon.variables = {};
local _L = addon.L;
local _V = addon.variables;

------------------------
-- PUBLIC
------------------------

WQT_REWARDTYPE = {
	["missing"] = 100
	,["equipment"] = 1
	,["relic"] = 2
	,["artifact"] = 3
	,["item"] = 4
	,["gold"] = 5
	,["currency"] = 6
	,["honor"] = 7
	,["reputation"] = 8
	,["xp"] = 9
	,["none"] = 10
};

WQT_GROUP_INFO = _L["GROUP_SEARCH_INFO"];

------------------------
-- LOCAL
------------------------

local WQT_ZANDALAR = {
	[864] =  {["x"] = 0.39, ["y"] = 0.32} -- Vol'dun
	,[863] = {["x"] = 0.57, ["y"] = 0.28} -- Nazmir
	,[862] = {["x"] = 0.55, ["y"] = 0.61} -- Zuldazar
	,[1165] = {["x"] = 0.55, ["y"] = 0.61} -- Dazar'alor
}
local WQT_KULTIRAS = {
	[942] =  {["x"] = 0.55, ["y"] = 0.25} -- Stromsong Valley
	,[896] = {["x"] = 0.36, ["y"] = 0.67} -- Drustvar
	,[895] = {["x"] = 0.56, ["y"] = 0.54} -- Tiragarde Sound
	,[1161] = {["x"] = 0.56, ["y"] = 0.54} -- Boralus
	,[1169] = {["x"] = 0.78, ["y"] = 0.61} -- Tol Dagor
}
local WQT_LEGION = {
	[630] =  {["x"] = 0.33, ["y"] = 0.58} -- Azsuna
	,[680] = {["x"] = 0.46, ["y"] = 0.45} -- Suramar
	,[634] = {["x"] = 0.60, ["y"] = 0.33} -- Stormheim
	,[650] = {["x"] = 0.46, ["y"] = 0.23} -- Highmountain
	,[641] = {["x"] = 0.34, ["y"] = 0.33} -- Val'sharah
	,[790] = {["x"] = 0.46, ["y"] = 0.84} -- Eye of Azshara
	,[646] = {["x"] = 0.54, ["y"] = 0.68} -- Broken Shore
	,[627] = {["x"] = 0.45, ["y"] = 0.64} -- Dalaran
	
	,[830]	= {["x"] = 0.86, ["y"] = 0.15} -- Krokuun
	,[885]	= {["x"] = 0.86, ["y"] = 0.15} -- Antoran Wastes
	,[882]	= {["x"] = 0.86, ["y"] = 0.15} -- Mac'Aree
}

------------------------
-- SHARED
------------------------

_V["WQT_COLOR_ARMOR"] =  CreateColor(0.85, 0.5, 0.95) ;
_V["WQT_COLOR_ARTIFACT"] = CreateColor(0, 0.75, 0);
_V["WQT_COLOR_CURRENCY"] = CreateColor(0.6, 0.4, 0.1) ;
_V["WQT_COLOR_GOLD"] = CreateColor(0.85, 0.7, 0) ;
_V["WQT_COLOR_HONOR"] = CreateColor(0.8, 0.26, 0);
_V["WQT_COLOR_ITEM"] = CreateColor(0.85, 0.85, 0.85) ;
_V["WQT_COLOR_MISSING"] = CreateColor(0.7, 0.1, 0.1);
_V["WQT_COLOR_RELIC"] = CreateColor(0.3, 0.7, 1);
_V["WQT_WHITE_FONT_COLOR"] = CreateColor(0.8, 0.8, 0.8);
_V["WQT_ORANGE_FONT_COLOR"] = CreateColor(1, 0.6, 0);
_V["WQT_GREEN_FONT_COLOR"] = CreateColor(0, 0.75, 0);
_V["WQT_BLUE_FONT_COLOR"] = CreateColor(0.1, 0.68, 1);

_V["WQT_BOUNDYBOARD_OVERLAYID"] = 3;
_V["WQT_TYPE_BONUSOBJECTIVE"] = 99;
_V["WQT_LISTITTEM_HEIGHT"] = 32;
_V["WQT_REFRESH_DEFAULT"] = 60;

_V["WQT_QUESTIONMARK"] = "Interface/ICONS/INV_Misc_QuestionMark";
_V["WQT_EXPERIENCE"] = "Interface/ICONS/XP_ICON";
_V["WQT_HONOR"] = "Interface/ICONS/Achievement_LegionPVPTier4";
_V["WQT_FACTIONUNKNOWN"] = "Interface/addons/WorldQuestTab/Images/FactionUnknown";

_V["WQT_CVAR_LIST"] = {
		["Petbattle"] = "showTamers"
		,["Artifact"] = "worldQuestFilterArtifactPower"
		,["Armor"] = "worldQuestFilterEquipment"
		,["Gold"] = "worldQuestFilterGold"
		,["Currency"] = "worldQuestFilterResources"
	}
	
_V["WQT_TYPEFLAG_LABELS"] = {
		[2] = {["Default"] = DEFAULT, ["Elite"] = ELITE, ["PvP"] = PVP, ["Petbattle"] = PET_BATTLE_PVP_QUEUE, ["Dungeon"] = TRACKER_HEADER_DUNGEON, ["Raid"] = RAID, ["Profession"] = BATTLE_PET_SOURCE_4, ["Invasion"] = _L["TYPE_INVASION"], ["Assault"] = SPLASH_BATTLEFORAZEROTH_8_1_FEATURE2_TITLE}
		,[3] = {["Item"] = ITEMS, ["Armor"] = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT, ["Gold"] = WORLD_QUEST_REWARD_FILTERS_GOLD, ["Currency"] = WORLD_QUEST_REWARD_FILTERS_RESOURCES, ["Artifact"] = ITEM_QUALITY6_DESC
			, ["Relic"] = RELICSLOT, ["None"] = NONE, ["Experience"] = POWER_TYPE_EXPERIENCE, ["Honor"] = HONOR, ["Reputation"] = REPUTATION}
	};

_V["WQT_SORT_OPTIONS"] = {[1] = _L["TIME"], [2] = FACTION, [3] = TYPE, [4] = ZONE, [5] = NAME, [6] = REWARD}
	
_V["WQT_FILTER_FUNCTIONS"] = {
		[2] = { -- Types
			function(quest, flags) return (flags["PvP"] and quest.type == LE_QUEST_TAG_TYPE_PVP); end 
			,function(quest, flags) return (flags["Petbattle"] and quest.type == LE_QUEST_TAG_TYPE_PET_BATTLE); end 
			,function(quest, flags) return (flags["Dungeon"] and quest.type == LE_QUEST_TAG_TYPE_DUNGEON); end 
			,function(quest, flags) return (flags["Raid"] and quest.type == LE_QUEST_TAG_TYPE_RAID); end 
			,function(quest, flags) return (flags["Profession"] and quest.type == LE_QUEST_TAG_TYPE_PROFESSION); end 
			,function(quest, flags) return (flags["Invasion"] and quest.type == LE_QUEST_TAG_TYPE_INVASION); end 
			,function(quest, flags) return (flags["Assault"] and quest.type == LE_QUEST_TAG_TYPE_FACTION_ASSAULT); end 
			,function(quest, flags) return (flags["Elite"] and (quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.isElite)); end 
			,function(quest, flags) return (flags["Default"] and (quest.type ~= LE_QUEST_TAG_TYPE_PVP and quest.type ~= LE_QUEST_TAG_TYPE_PET_BATTLE and quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON 
					and quest.type ~= _V["WQT_TYPE_BONUSOBJECTIVE"]  and quest.type ~= LE_QUEST_TAG_TYPE_PROFESSION and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.type ~= LE_QUEST_TAG_TYPE_INVASION 
					and quest.type ~= LE_QUEST_TAG_TYPE_FACTION_ASSAULT and not quest.isElite)); end 
			}
		,[3] = { -- Reward filters
			function(quest, flags) return (flags["Armor"] and quest.reward.type == WQT_REWARDTYPE.equipment); end 
			,function(quest, flags) return (flags["Relic"] and quest.reward.type == WQT_REWARDTYPE.relic); end 
			,function(quest, flags) return (flags["Item"] and quest.reward.type == WQT_REWARDTYPE.item); end 
			,function(quest, flags) return (flags["Artifact"] and quest.reward.type == WQT_REWARDTYPE.artifact); end 
			,function(quest, flags) return (flags["Honor"] and (quest.reward.type == WQT_REWARDTYPE.honor or quest.reward.subType == WQT_REWARDTYPE.honor)); end 
			,function(quest, flags) return (flags["Gold"] and (quest.reward.type == WQT_REWARDTYPE.gold or quest.reward.subType == WQT_REWARDTYPE.gold) ); end 
			,function(quest, flags) return (flags["Currency"] and (quest.reward.type == WQT_REWARDTYPE.currency or quest.reward.subType == WQT_REWARDTYPE.currency)); end 
			,function(quest, flags) return (flags["Experience"] and quest.reward.type == WQT_REWARDTYPE.xp); end 
			,function(quest, flags) return (flags["Reputation"] and quest.reward.type == WQT_REWARDTYPE.reputation or quest.reward.subType == WQT_REWARDTYPE.reputation); end
			,function(quest, flags) return (flags["None"] and quest.reward.type == WQT_REWARDTYPE.none); end
			}
	};


_V["WQT_CONTINENT_GROUPS"] = {
		[875]	= {876} 
		,[876]	= {875}
	}

_V["WQT_ZONE_EXPANSIONS"] = {
		[875] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Zandalar
		,[864] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Vol'dun
		,[863] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Nazmir
		,[862] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Zuldazar
		,[1165] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Dazar'alor
		,[876] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Kul Tiras
		,[942] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Stromsong Valley
		,[896] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Drustvar
		,[895] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Tiragarde Sound
		,[1161] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Boralus
		,[1169] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Tol Dagor
		-- Classic zones with BfA WQ
		,[14] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Arathi Highlands
		,[62] = LE_EXPANSION_BATTLE_FOR_AZEROTH -- Darkshore

		,[619] = LE_EXPANSION_LEGION -- Broken Isles
		,[630] = LE_EXPANSION_LEGION -- Azsuna
		,[680] = LE_EXPANSION_LEGION -- Suramar
		,[634] = LE_EXPANSION_LEGION -- Stormheim
		,[650] = LE_EXPANSION_LEGION -- Highmountain
		,[641] = LE_EXPANSION_LEGION -- Val'sharah
		,[790] = LE_EXPANSION_LEGION -- Eye of Azshara
		,[646] = LE_EXPANSION_LEGION -- Broken Shore
		,[627] = LE_EXPANSION_LEGION -- Dalaran
		,[830] = LE_EXPANSION_LEGION -- Krokuun
		,[885] = LE_EXPANSION_LEGION -- Antoran Wastes
		,[882] = LE_EXPANSION_LEGION -- Mac'Aree
		,[905] = LE_EXPANSION_LEGION -- Argus
	}

_V["WQT_ZONE_MAPCOORDS"] = {
		[875]	= WQT_ZANDALAR -- Zandalar
		,[1011]	= WQT_ZANDALAR -- Zandalar flightmap
		,[876]	= WQT_KULTIRAS -- Kul Tiras
		,[1014]	= WQT_KULTIRAS -- Kul Tiras flightmap

		,[619] 	= WQT_LEGION -- Legion
		,[993] 	= WQT_LEGION -- Legion flightmap	
		,[905] 	= WQT_LEGION -- Legion Argus
		
		,[12] 	= { --Kalimdor
			[81] 	= {["x"] = 0.42, ["y"] = 0.82} -- Silithus
			,[64]	= {["x"] = 0.5, ["y"] = 0.72} -- Thousand Needles
			,[249]	= {["x"] = 0.47, ["y"] = 0.91} -- Uldum
			,[71]	= {["x"] = 0.55, ["y"] = 0.84} -- Tanaris
			,[78]	= {["x"] = 0.5, ["y"] = 0.81} -- Ungoro
			,[69]	= {["x"] = 0.43, ["y"] = 0.7} -- Feralas
			,[70]	= {["x"] = 0.55, ["y"] = 0.67} -- Dustwallow
			,[199]	= {["x"] = 0.51, ["y"] = 0.67} -- S Barrens
			,[7]	= {["x"] = 0.47, ["y"] = 0.6} -- Mulgore
			,[66]	= {["x"] = 0.41, ["y"] = 0.57} -- Desolace
			,[65]	= {["x"] = 0.43, ["y"] = 0.46} -- Stonetalon
			,[10]	= {["x"] = 0.52, ["y"] = 0.5} -- N Barrens
			,[1]	= {["x"] = 0.58, ["y"] = 0.5} -- Durotar
			,[63]	= {["x"] = 0.49, ["y"] = 0.41} -- Ashenvale
			,[62]	= {["x"] = 0.46, ["y"] = 0.23} -- Dakshore
			,[76]	= {["x"] = 0.59, ["y"] = 0.37} -- Azshara
			,[198]	= {["x"] = 0.54, ["y"] = 0.32} -- Hyjal
			,[77]	= {["x"] = 0.49, ["y"] = 0.25} -- Felwood
			,[80]	= {["x"] = 0.53, ["y"] = 0.19} -- Moonglade
			,[83]	= {["x"] = 0.58, ["y"] = 0.23} -- Winterspring
			,[57]	= {["x"] = 0.42, ["y"] = 0.1} -- Teldrassil
			,[97]	= {["x"] = 0.33, ["y"] = 0.27} -- Azuremyst
			,[106]	= {["x"] = 0.3, ["y"] = 0.18} -- Bloodmyst
		}
		
		,[13]	= { -- Eastern Kingdoms
			[210]	= {["x"] = 0.47, ["y"] = 0.87} -- Cape of STV
			,[50]	= {["x"] = 0.47, ["y"] = 0.87} -- N STV
			,[17]	= {["x"] = 0.54, ["y"] = 0.89} -- Blasted Lands
			,[51]	= {["x"] = 0.54, ["y"] = 0.78} -- Swamp of Sorrow
			,[42]	= {["x"] = 0.49, ["y"] = 0.79} -- Deadwind
			,[47]	= {["x"] = 0.45, ["y"] = 0.8} -- Duskwood
			,[52]	= {["x"] = 0.4, ["y"] = 0.79} -- Westfall
			,[37]	= {["x"] = 0.47, ["y"] = 0.75} -- Elwynn
			,[49]	= {["x"] = 0.51, ["y"] = 0.75} -- Redridge
			,[36]	= {["x"] = 0.49, ["y"] = 0.7} -- Burning Steppes
			,[32]	= {["x"] = 0.47, ["y"] = 0.65} -- Searing Gorge
			,[15]	= {["x"] = 0.52, ["y"] = 0.65} -- Badlands
			,[27]	= {["x"] = 0.44, ["y"] = 0.61} -- Dun Morogh
			,[48]	= {["x"] = 0.52, ["y"] = 0.6} -- Loch Modan
			,[241]	= {["x"] = 0.56, ["y"] = 0.55} -- Twilight Highlands
			,[56]	= {["x"] = 0.5, ["y"] = 0.53} -- Wetlands
			,[14]	= {["x"] = 0.51, ["y"] = 0.46} -- Arathi Highlands
			,[26]	= {["x"] = 0.57, ["y"] = 0.4} -- Hinterlands
			,[25]	= {["x"] = 0.46, ["y"] = 0.4} -- Hillsbrad
			,[217]	= {["x"] = 0.4, ["y"] = 0.48} -- Ruins of Gilneas
			,[21]	= {["x"] = 0.41, ["y"] = 0.39} -- Silverpine
			,[18]	= {["x"] = 0.39, ["y"] = 0.32} -- Tirisfall
			,[22]	= {["x"] = 0.49, ["y"] = 0.31} -- W Plaugelands
			,[23]	= {["x"] = 0.54, ["y"] = 0.32} -- E Plaguelands
			,[95]	= {["x"] = 0.56, ["y"] = 0.23} -- Ghostlands
			,[94]	= {["x"] = 0.54, ["y"] = 0.18} -- Eversong
			,[122]	= {["x"] = 0.55, ["y"] = 0.05} -- Quel'Danas
		}
		
		,[101]	= { -- Outland
			[104]	= {["x"] = 0.74, ["y"] = 0.8} -- Shadowmoon Valley
			,[108]	= {["x"] = 0.45, ["y"] = 0.77} -- Terrokar
			,[107]	= {["x"] = 0.3, ["y"] = 0.65} -- Nagrand
			,[100]	= {["x"] = 0.52, ["y"] = 0.51} -- Hellfire
			,[102]	= {["x"] = 0.33, ["y"] = 0.47} -- Zangarmarsh
			,[105]	= {["x"] = 0.36, ["y"] = 0.23} -- Blade's Edge
			,[109]	= {["x"] = 0.57, ["y"] = 0.2} -- Netherstorm
		}
		
		,[113]	= { -- Northrend
			[114]	= {["x"] = 0.22, ["y"] = 0.59} -- Borean Tundra
			,[119]	= {["x"] = 0.25, ["y"] = 0.41} -- Sholazar Basin
			,[118]	= {["x"] = 0.41, ["y"] = 0.26} -- Icecrown
			,[127]	= {["x"] = 0.47, ["y"] = 0.55} -- Crystalsong
			,[120]	= {["x"] = 0.61, ["y"] = 0.21} -- Stormpeaks
			,[121]	= {["x"] = 0.77, ["y"] = 0.32} -- Zul'Drak
			,[116]	= {["x"] = 0.71, ["y"] = 0.53} -- Grizzly Hillsbrad
			,[113]	= {["x"] = 0.78, ["y"] = 0.74} -- Howling Fjord
		}
		
		,[424]	= { -- Pandaria
			[554]	= {["x"] = 0.9, ["y"] = 0.68} -- Timeless Isles
			,[371]	= {["x"] = 0.67, ["y"] = 0.52} -- Jade Forest
			,[418]	= {["x"] = 0.53, ["y"] = 0.75} -- Karasang
			,[376]	= {["x"] = 0.51, ["y"] = 0.65} -- Four Winds
			,[422]	= {["x"] = 0.35, ["y"] = 0.62} -- Dread Waste
			,[390]	= {["x"] = 0.5, ["y"] = 0.52} -- Eternal Blossom
			,[379]	= {["x"] = 0.45, ["y"] = 0.35} -- Kun-lai Summit
			,[507]	= {["x"] = 0.48, ["y"] = 0.05} -- Isle of Giants
			,[388]	= {["x"] = 0.32, ["y"] = 0.45} -- Townlong Steppes
			,[504]	= {["x"] = 0.2, ["y"] = 0.11} -- Isle of Thunder
		}
		
		,[572]	= { -- Draenor
			[550]	= {["x"] = 0.24, ["y"] = 0.49} -- Nagrand
			,[525]	= {["x"] = 0.34, ["y"] = 0.29} -- Frostridge
			,[543]	= {["x"] = 0.49, ["y"] = 0.21} -- Gorgrond
			,[535]	= {["x"] = 0.43, ["y"] = 0.56} -- Talador
			,[542]	= {["x"] = 0.46, ["y"] = 0.73} -- Spired of Arak
			,[539]	= {["x"] = 0.58, ["y"] = 0.67} -- Shadowmoon
			,[534]	= {["x"] = 0.58, ["y"] = 0.47} -- Tanaan Jungle
			,[558]	= {["x"] = 0.73, ["y"] = 0.43} -- Ashran
		}
		
		,[947]		= {	
		} -- All of Azeroth
	}

_V["WQT_NO_FACTION_DATA"] = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/FactionNone", ["name"]=_L["NO_FACTION"] } -- No faction
_V["WQT_FACTION_DATA"] = {
	[1894] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Warden" }
	,[1859] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_NightFallen" }
	,[1900] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_CourtofFarnodis" }
	,[1948] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Valarjar" }
	,[1828] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_HightmountainTribes" }
	,[1883] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_DreamWeavers" }
	,[1090] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_KirinTor" }
	,[2045] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Legionfall" } -- This isn't in until 7.3
	,[2165] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_ArmyoftheLight" }
	,[2170] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_ArgussianReach" }
	,[609] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction609" } -- Cenarion Circle - Call of the Scarab
	,[910] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction910" } -- Brood of Nozdormu - Call of the Scarab
	,[1515] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1515" } -- Dreanor Arakkoa Outcasts
	,[1681] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1681" } -- Dreanor Vol'jin's Spear
	,[1682] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1682" } -- Dreanor Wrynn's Vanguard
	,[1731] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1731" } -- Dreanor Council of Exarchs
	,[1445] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1445" } -- Draenor Frostwolf Orcs
	,[67] = 		{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction67" } -- Horde
	,[469] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction469" } -- Alliance
	-- BfA                                                         
	,[2164] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_Faction_Championsofazeroth_Round" } -- Champions of Azeroth
	,[2156] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Horde" ,["icon"] = 2058211 } -- Talanji's Expedition
	,[2103] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Horde" ,["icon"] = 2058217 } -- Zandalari Empire
	,[2158] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Horde" ,["icon"] = "Interface/ICONS/INV_Faction_Voldunai_Round" } -- Voldunai
	,[2157] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Horde" ,["icon"] = "Interface/ICONS/INV_Faction_HordeWarEffort_Round" } -- The Honorbound
	,[2163] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = nil ,["icon"] = 2058212 } -- Tortollan Seekers
	,[2162] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_Stormswake_Round" } -- Storm's Wake
	,[2160] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_ProudmooreAdmiralty_Round" } -- Proudmoore Admirality
	,[2161] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_OrderofEmbers_Round" } -- Order of Embers
	,[2159] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_AllianceWarEffort_Round" } -- 7th Legion
}
-- Add localized faction names
for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	v.name = GetFactionInfoByID(k);
end



