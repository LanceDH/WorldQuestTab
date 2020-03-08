local addonName, addon = ...

addon.WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");
addon.externals = {};
addon.variables = {};
addon.debug = false;
addon.WQT_Utils = {};
local WQT_Utils = addon.WQT_Utils;
local _L = addon.L;
local _V = addon.variables;
local WQT = addon.WQT;
local _emptyTable = {};
local _playerFaction = UnitFactionGroup("Player");

------------------------
-- PUBLIC
------------------------

WQT_REWARDTYPE = {
	["none"] = 			0
	,["weapon"] = 		2^0
	,["equipment"] =		2^1
	,["relic"] = 		2^2
	,["artifact"] = 		2^3
	,["spell"] = 		2^4
	,["item"] = 			2^5
	,["gold"] = 			2^6
	,["currency"] = 		2^7
	,["honor"] = 		2^8
	,["reputation"] =	2^9
	,["xp"] = 			2^10
	,["missing"] = 		2^11
};

WQT_GROUP_INFO = _L["GROUP_SEARCH_INFO"];
WQT_CONTAINER_DRAG = _L["CONTAINER_DRAG"];
WQT_CONTAINER_DRAG_TT = _L["CONTAINER_DRAG_TT"];
WQT_FULLSCREEN_BUTTON_TT = _L["WQT_FULLSCREEN_BUTTON_TT"];

------------------------
-- LOCAL
------------------------

local function _DeepWipeTable(t)
	for k, v in pairs(t) do
		if (type(v) == "table") then
			_DeepWipeTable(v)
		end
	end
	wipe(t);
	t = nil;
end

local WQT_ZANDALAR = {
	[864] =  {["x"] = 0.39, ["y"] = 0.32} -- Vol'dun
	,[863] = {["x"] = 0.57, ["y"] = 0.28} -- Nazmir
	,[862] = {["x"] = 0.55, ["y"] = 0.61} -- Zuldazar
	,[1165] = {["x"] = 0.55, ["y"] = 0.61} -- Dazar'alor
	,[1355] = {["x"] = 0.86, ["y"] = 0.14} -- Nazjatar
}
local WQT_KULTIRAS = {
	[942] =  {["x"] = 0.55, ["y"] = 0.25} -- Stromsong Valley
	,[896] = {["x"] = 0.36, ["y"] = 0.67} -- Drustvar
	,[895] = {["x"] = 0.56, ["y"] = 0.54} -- Tiragarde Sound
	,[1161] = {["x"] = 0.56, ["y"] = 0.54} -- Boralus
	,[1169] = {["x"] = 0.78, ["y"] = 0.61} -- Tol Dagor
	,[1355] = {["x"] = 0.86, ["y"] = 0.14} -- Nazjatar
	,[1462] = {["x"] = 0.17, ["y"] = 0.28} -- Mechagon
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
local WQT_KALIMDOR = { 
	[81] 	= {["x"] = 0.42, ["y"] = 0.82} -- Silithus
	,[64]	= {["x"] = 0.5, ["y"] = 0.72} -- Thousand Needles
	,[249]	= {["x"] = 0.47, ["y"] = 0.91} -- Uldum
	,[1527]	= {["x"] = 0.47, ["y"] = 0.91} -- Uldum BfA
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
local WQT_EASTERN_KINGDOMS = {
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
local WQT_OUTLAND = {
	[104]	= {["x"] = 0.74, ["y"] = 0.8} -- Shadowmoon Valley
	,[108]	= {["x"] = 0.45, ["y"] = 0.77} -- Terrokar
	,[107]	= {["x"] = 0.3, ["y"] = 0.65} -- Nagrand
	,[100]	= {["x"] = 0.52, ["y"] = 0.51} -- Hellfire
	,[102]	= {["x"] = 0.33, ["y"] = 0.47} -- Zangarmarsh
	,[105]	= {["x"] = 0.36, ["y"] = 0.23} -- Blade's Edge
	,[109]	= {["x"] = 0.57, ["y"] = 0.2} -- Netherstorm
}
local WQT_NORTHREND = {
	[114]	= {["x"] = 0.22, ["y"] = 0.59} -- Borean Tundra
	,[119]	= {["x"] = 0.25, ["y"] = 0.41} -- Sholazar Basin
	,[118]	= {["x"] = 0.41, ["y"] = 0.26} -- Icecrown
	,[127]	= {["x"] = 0.47, ["y"] = 0.55} -- Crystalsong
	,[120]	= {["x"] = 0.61, ["y"] = 0.21} -- Stormpeaks
	,[121]	= {["x"] = 0.77, ["y"] = 0.32} -- Zul'Drak
	,[116]	= {["x"] = 0.71, ["y"] = 0.53} -- Grizzly Hillsbrad
	,[113]	= {["x"] = 0.78, ["y"] = 0.74} -- Howling Fjord
}
local WQT_PANDARIA = {
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
	,[1530]	= {["x"] = 0.51, ["y"] = 0.53} -- Vale Of Eternal Blossom BfA
}
local WQT_DRAENOR = {
	[550]	= {["x"] = 0.24, ["y"] = 0.49} -- Nagrand
	,[525]	= {["x"] = 0.34, ["y"] = 0.29} -- Frostridge
	,[543]	= {["x"] = 0.49, ["y"] = 0.21} -- Gorgrond
	,[535]	= {["x"] = 0.43, ["y"] = 0.56} -- Talador
	,[542]	= {["x"] = 0.46, ["y"] = 0.73} -- Spired of Arak
	,[539]	= {["x"] = 0.58, ["y"] = 0.67} -- Shadowmoon
	,[534]	= {["x"] = 0.58, ["y"] = 0.47} -- Tanaan Jungle
	,[558]	= {["x"] = 0.73, ["y"] = 0.43} -- Ashran
}

local ZonesByExpansion = {
	[LE_EXPANSION_BATTLE_FOR_AZEROTH] = {
		875; -- Zandalar
		864; -- Vol'dun
		863; -- Nazmir
		862; -- Zuldazar
		1165; -- Dazar'alor
		876; -- Kul Tiras
		942; -- Stromsong Valley
		896; -- Drustvar
		895; -- Tiragarde Sound
		1161; -- Boralus
		1169; -- Tol Dagor
		1355; -- Nazjatar
		1462; -- Mechagon
		--Classic zones with BfA WQ
		14; -- Arathi Highlands
		62; -- Darkshore
		1527; -- Uldum
		1530; -- Vale of Eternam Blossom
	}
	,[LE_EXPANSION_LEGION] = {
		619; -- Broken Isles
		630; -- Azsuna
		680; -- Suramar
		634; -- Stormheim
		650; -- Highmountain
		641; -- Val'sharah
		790; -- Eye of Azshara
		646; -- Broken Shore
		627; -- Dalaran
		830; -- Krokuun
		885; -- Antoran Wastes
		882; -- Mac'Aree
		905; -- Argus
	}
	,[LE_EXPANSION_WARLORDS_OF_DRAENOR] = {
		572; -- Draenor
		525; -- Frostfire Ridge
		543; -- Gorgrond
		534; -- Tanaan Jungle
		535; -- Talador
		550; -- Nagrand
		542; -- Spires of Arak
		588; -- Ashran
	}
}

-- A list of every zones linked to an expansion level
_V["WQT_ZONE_EXPANSIONS"] = {}


local function AddZonesToList(t)
	for mapID, v in pairs(t) do
		_V["WQT_ZONE_EXPANSIONS"][mapID] = 0;
	end
end

AddZonesToList(WQT_ZANDALAR);
AddZonesToList(WQT_KULTIRAS);
AddZonesToList(WQT_LEGION);
AddZonesToList(WQT_KALIMDOR);
AddZonesToList(WQT_EASTERN_KINGDOMS);
AddZonesToList(WQT_DRAENOR);
AddZonesToList(WQT_PANDARIA);
AddZonesToList(WQT_NORTHREND);
AddZonesToList(WQT_OUTLAND);

for expId, zones in pairs(ZonesByExpansion) do
	for k, zoneId in ipairs(zones) do
		_V["WQT_ZONE_EXPANSIONS"][zoneId] = expId;
	end
end

_DeepWipeTable(ZonesByExpansion);

------------------------
-- SHARED
------------------------

_V["PATH_CUSTOM_ICONS"] = "Interface/Addons/WorldQuestTab/Images/CustomIcons";
_V["LIST_ANCHOR_TYPE"] = {["flight"] = 1, ["world"] = 2, ["full"] = 3, ["taxi"] = 4};
_V["CURRENT_EXPANSION"] = LE_EXPANSION_BATTLE_FOR_AZEROTH;

_V["WQT_COLOR_NONE"] =  CreateColor(0.45, 0.45, .45) ;
_V["WQT_COLOR_ARMOR"] =  CreateColor(0.85, 0.6, 1) ;
_V["WQT_COLOR_WEAPON"] =  CreateColor(1, 0.40, 1) ;
_V["WQT_COLOR_ARTIFACT"] = CreateColor(0, 0.75, 0);
_V["WQT_COLOR_CURRENCY"] = CreateColor(0.6, 0.4, 0.1) ;
_V["WQT_COLOR_GOLD"] = CreateColor(0.95, 0.8, 0) ;
_V["WQT_COLOR_HONOR"] = CreateColor(0.8, 0.26, 0);
_V["WQT_COLOR_ITEM"] = CreateColor(0.85, 0.85, 0.85) ;
_V["WQT_COLOR_MISSING"] = CreateColor(0.7, 0.1, 0.1);
_V["WQT_COLOR_RELIC"] = CreateColor(0.3, 0.7, 1);
_V["WQT_WHITE_FONT_COLOR"] = CreateColor(0.8, 0.8, 0.8);
_V["WQT_ORANGE_FONT_COLOR"] = CreateColor(1, 0.5, 0);
_V["WQT_GREEN_FONT_COLOR"] = CreateColor(0, 0.75, 0);
_V["WQT_BLUE_FONT_COLOR"] = CreateColor(0.2, 0.60, 1);
_V["WQT_PURPLE_FONT_COLOR"] = CreateColor(0.73, 0.33, 0.82);

_V["WQT_BOUNDYBOARD_OVERLAYID"] = 3;
_V["WQT_TYPE_BONUSOBJECTIVE"] = 99;
_V["WQT_LISTITTEM_HEIGHT"] = 32;

_V["DEBUG_OUTPUT_TYPE"] = {
	["invalid"] = 0
	,["setting"] = 1
	,["quest"] = 2
	,["worldQuest"] = 3
	,["addon"] = 4
}

_V["FILTER_TYPES"] = {
	["faction"] = 1
	,["type"] = 2
	,["reward"] = 3
}

_V["PIN_CENTER_TYPES"] =	{
	["blizzard"] = 1
	,["reward"] = 2
}

_V["PIN_CENTER_LABELS"] ={
	[_V["PIN_CENTER_TYPES"].blizzard] = {["label"] = _L["BLIZZARD"], ["tooltip"] = _L["PIN_BLIZZARD_TT"]} 
	,[_V["PIN_CENTER_TYPES"].reward] = {["label"] = REWARD, ["tooltip"] = _L["PIN_REWARD_TT"]}
}

_V["RING_TYPES"] = {
	["default"] = 1
	,["reward"] = 2
	,["time"] = 3
	,["rarity"] = 4
}

_V["RING_TYPES_LABELS"] ={
	[_V["RING_TYPES"].default] = {["label"] = _L["PIN_RING_DEFAULT"], ["tooltip"] = _L["PIN_RING_DEFAULT_TT"]} 
	,[_V["RING_TYPES"].reward] = {["label"] = _L["PIN_RING_COLOR"], ["tooltip"] = _L["PIN_RING_COLOR_TT"]}
	,[_V["RING_TYPES"].time] = {["label"] = _L["PIN_RING_TIME"], ["tooltip"] = _L["PIN_RIMG_TIME_TT"]}
	,[_V["RING_TYPES"].rarity] = {["label"] = RARITY, ["tooltip"] = _L["PIN_RING_QUALITY_TT"]}
}

-- Setup date to display in the settings;
local _ringTypeDropDownInfo = {}

for k, id in pairs(_V["RING_TYPES"]) do
	_ringTypeDropDownInfo[id] = _V["RING_TYPES_LABELS"][id];
end

local _pinCenterDropDownInfo = {}

for k, id in pairs(_V["PIN_CENTER_TYPES"]) do
	_pinCenterDropDownInfo[id] = _V["PIN_CENTER_LABELS"][id];
end

_V["SETTING_TYPES"] = {
	["category"] = 1
	,["subTitle"] = 2
	,["checkBox"] = 3
	,["slider"] = 4
	,["dropDown"] = 5
	,["button"] = 6
}

-------------------------------
-- Settings List
-------------------------------
-- This list gets turned into a settings menu based on the data provided.
-- GENERAL
--   (either) template: A frame template which inherits the base mixin WQT_SettingsBaseMixin;
--   (or) frameName: The name of a specific frame using the mixin WQT_SettingsBaseMixin;
--   label (string): The text the label should have
--   tooltip (string): Text displayed in the tooltip
--   valueChangedFunc (function(value)): what actions should be taken when the value is changed. Value is nil for buttons
--   isDisabled (boolean|function()): Boolean or function returning if the setting should be disabled
--   getValueFunc (function()): Function returning the current value of the setting
--   isNew (boolean): Mark the setting as new by adding an exclamantion mark to the label
-- SLIDER SPECIFIC
--   min (number): min value
--   max (number): max value
--   valueStep (number): step the slider makes when moved
-- DROPDOWN SPECIFIC
--   options (table): a list for options in following format {[id] = {["label"] = "Displayed label", ["tooltip"] = "additional tooltip info (optional)"}, ...}

_V["SETTING_CATEGORIES"] = {
	{["id"]="DEBUG", ["label"] = "Debug"}
	,{["id"]="GENERAL", ["label"] = GENERAL}
	,{["id"]="QUESTLIST", ["label"] = _L["QUEST_LIST"]}
	,{["id"]="MAPPINS", ["label"] = _L["MAP_PINS"]}
	,{["id"]="WQTU", ["label"] = "Utilities"}
	,{["id"]="TOMTOM", ["label"] = "TomTom"}
}

_V["SETTING_LIST"] = {
	-- General settings
	{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["DEFAULT_TAB"], ["tooltip"] = _L["DEFAULT_TAB_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.defaultTab = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.defaultTab end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["SAVE_SETTINGS"], ["tooltip"] = _L["SAVE_SETTINGS_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.saveFilters = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.saveFilters end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["PRECISE_FILTER"], ["tooltip"] = _L["PRECISE_FILTER_TT"], ["isNew"] = true
			, ["valueChangedFunc"] = function(value) 
				for i=1, 3 do
					if (not WQT:IsUsingFilterNr(i)) then
						WQT:SetAllFilterTo(i, not value);
					end
				end
			
				WQT.settings.general.preciseFilters = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.general.preciseFilters end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["LFG_BUTTONS"], ["tooltip"] = _L["LFG_BUTTONS_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.useLFGButtons = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.useLFGButtons end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["AUTO_EMISARRY"], ["tooltip"] = _L["AUTO_EMISARRY_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.autoEmisarry = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.autoEmisarry end
			}		
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["QUEST_COUNTER"], ["tooltip"] = _L["QUEST_COUNTER_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.questCounter = value;
				WQT_QuestLogFiller:UpdateVisibility();
			end
			,["getValueFunc"] = function() return WQT.settings.general.questCounter; end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["EMISSARY_COUNTER"], ["tooltip"] = _L["EMISSARY_COUNTER_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.bountyCounter = value;
				WQT_WorldQuestFrame:UpdateBountyCounters();
				WQT_WorldQuestFrame:RepositionBountyTabs();
			end
			,["getValueFunc"] = function() return WQT.settings.general.bountyCounter end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["ALWAYS_ALL"], ["tooltip"] = _L["ALWAYS_ALL_TT"], ["isNew"] = true
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.alwaysAllQuests = value;
				local mapAreaID = WorldMapFrame.mapID;
				WQT_WorldQuestFrame.dataProvider:LoadQuestsInZone(mapAreaID);
				WQT_QuestScrollFrame:UpdateQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.alwaysAllQuests end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["INCLUDE_DAILIES"], ["tooltip"] = _L["INCLUDE_DAILIES_TT"], ["isNew"] = true
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.includeDaily = value;
				local mapAreaID = WorldMapFrame.mapID;
				WQT_WorldQuestFrame.dataProvider:LoadQuestsInZone(mapAreaID);
				if (not value) then
					WQT_Utils:RefreshOfficialDataProviders();
				end
			end
			,["getValueFunc"] = function() return WQT.settings.list.includeDaily end
			}

	-- Quest List
	,{["frameName"] = "WQT_SettingsQuestListPreview", ["categoryID"] = "QUESTLIST"}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_TYPE"], ["tooltip"] = _L["SHOW_TYPE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.typeIcon = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.typeIcon end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_FACTION"], ["tooltip"] = _L["SHOW_FACTION_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.factionIcon = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.factionIcon end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_ZONE"], ["tooltip"] = _L["SHOW_ZONE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.showZone = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.showZone end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["AMOUNT_COLORS"], ["tooltip"] = _L["AMOUNT_COLORS_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.amountColors = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.amountColors end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["LIST_COLOR_TIME"], ["tooltip"] = _L["LIST_COLOR_TIME_TT"], ["isNew"] = true
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.colorTime = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.colorTime end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["LIST_FULL_TIME"], ["tooltip"] = _L["LIST_FULL_TIME_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.fullTime = value;
				WQT_QuestScrollFrame:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.fullTime end
			}	

	-- Map Pin
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_DISABLE"], ["tooltip"] = _L["PIN_DISABLE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.disablePoI = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
				if (value) then
					WQT_Utils:RefreshOfficialDataProviders();
				end
			end
			,["getValueFunc"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["FILTER_PINS"], ["tooltip"] = _L["FILTER_PINS_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.filterPoI = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.filterPoI end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}		
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_SHOW_CONTINENT"], ["tooltip"] = _L["PIN_SHOW_CONTINENT_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.continentPins = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.continentPins end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_FADE_ON_PING"], ["tooltip"] = _L["PIN_FADE_ON_PING_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.fadeOnPing = value;
			end
			,["getValueFunc"] = function() return WQT.settings.pin.fadeOnPing end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	-- Pin appearance
	,{["template"] =" WQT_SettingSubTitleTemplate", ["categoryID"] = "MAPPINS", ["label"] = APPEARANCE_LABEL}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_TIME"], ["tooltip"] = _L["PIN_TIME_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.timeLabel  = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.timeLabel  end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}		
	,{["template"] = "WQT_SettingSliderTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_SCALE"], ["tooltip"] = _L["PIN_SCALE_TT"], ["min"] = 0.8, ["max"] = 1.5, ["valueStep"] = 0.01
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.scale = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.scale end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_CENTER"], ["tooltip"] = _L["PIN_CENTER_TT"], ["options"] = _pinCenterDropDownInfo
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.centerType = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.centerType end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_RING_TITLE"], ["tooltip"] = _L["PIN_RING_TT"], ["options"] = _ringTypeDropDownInfo
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.ringType = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.ringType end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_ELITE_RING"], ["tooltip"] = _L["PIN_ELITE_RING_TT"], ["isNew"] = true
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.eliteRing  = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.eliteRing end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}	
	-- Pin icons
	,{["template"] = "WQT_SettingSubTitleTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["MINI_ICONS"]}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_TYPE"], ["tooltip"] = _L["PIN_TYPE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.typeIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function()  return WQT.settings.pin.typeIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI; end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_RARITY_ICON"], ["tooltip"] = _L["PIN_RARITY_ICON_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.rarityIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.rarityIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI;  end
			}		
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_TIME_ICON"], ["tooltip"] = _L["PIN_TIME_ICON_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.timeIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.timeIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI;  end
			}				
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_REWARD_TYPE"], ["tooltip"] = _L["PIN_REWARD_TYPE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.rewardTypeIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.rewardTypeIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI; end
			}	
}

_V["SETTING_UTILITIES_LIST"] = {
	{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "WQTU", ["label"] = _L["LOAD_UTILITIES"], ["tooltip"] = _L["LOAD_UTILITIES_TT"], ["disabledTooltip"] = _L["LOAD_UTILITIES_TT_DISABLED"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.loadUtilities = value;
				if (value and not IsAddOnLoaded("WorldQuestTabUtilities")) then
					LoadAddOn("WorldQuestTabUtilities");
					WQT_QuestScrollFrame:UpdateQuestList();
				end
			end
			,["getValueFunc"] = function() return WQT.settings.general.loadUtilities end
			,["isDisabled"] = function() return GetAddOnEnableState(nil, "WorldQuestTabUtilities") == 0 end
			}	
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

_V["QUESTS_NOT_COUNTING"] = {
		[261] = true -- Account Wide
		,[256] = true -- PvP Conquest
		,[102] = true -- Island Weekly Quest
		,[270] = true -- Threat Emissary
	}

_V["NUMBER_ABBREVIATIONS_ASIAN"] = {
		{["value"] = 1000000000, ["format"] = _L["NUMBERS_THIRD"]}
		,{["value"] = 100000000, ["format"] = _L["NUMBERS_SECOND"], ["decimal"] = true}
		,{["value"] = 100000, ["format"] = _L["NUMBERS_FIRST"]}
		,{["value"] = 1000, ["format"] = _L["NUMBERS_FIRST"], ["decimal"] = true}
	}

_V["NUMBER_ABBREVIATIONS"] = {
		{["value"] = 10000000000, ["format"] = _L["NUMBERS_THIRD"]}
		,{["value"] = 1000000000, ["format"] = _L["NUMBERS_THIRD"], ["decimal"] = true}
		,{["value"] = 10000000, ["format"] = _L["NUMBERS_SECOND"]}
		,{["value"] = 1000000, ["format"] = _L["NUMBERS_SECOND"], ["decimal"] = true}
		,{["value"] = 10000, ["format"] = _L["NUMBERS_FIRST"]}
		,{["value"] = 1000, ["format"] = _L["NUMBERS_FIRST"], ["decimal"] = true}
	}

_V["WARMODE_BONUS_REWARD_TYPES"] = {
		[WQT_REWARDTYPE.artifact] = true;
		[WQT_REWARDTYPE.gold] = true;
		[WQT_REWARDTYPE.currency] = true;
	}

_V["WQT_CVAR_LIST"] = {
		["Petbattle"] = "showTamers"
		,["Artifact"] = "worldQuestFilterArtifactPower"
		,["Armor"] = "worldQuestFilterEquipment"
		,["Gold"] = "worldQuestFilterGold"
		,["Currency"] = "worldQuestFilterResources"
	}
	
_V["WQT_TYPEFLAG_LABELS"] = {
		[2] = {["Default"] = DEFAULT, ["Elite"] = ELITE, ["PvP"] = PVP, ["Petbattle"] = PET_BATTLE_PVP_QUEUE, ["Dungeon"] = TRACKER_HEADER_DUNGEON, ["Raid"] = RAID, ["Profession"] = BATTLE_PET_SOURCE_4, ["Invasion"] = _L["TYPE_INVASION"], ["Assault"] = SPLASH_BATTLEFORAZEROTH_8_1_FEATURE2_TITLE
			, ["Daily"] = DAILY, ["Threat"] = REPORT_THREAT}
		,[3] = {["Item"] = ITEMS, ["Armor"] = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT, ["Gold"] = WORLD_QUEST_REWARD_FILTERS_GOLD, ["Currency"] = WORLD_QUEST_REWARD_FILTERS_RESOURCES, ["Artifact"] = ITEM_QUALITY6_DESC
			, ["Relic"] = RELICSLOT, ["None"] = NONE, ["Experience"] = POWER_TYPE_EXPERIENCE, ["Honor"] = HONOR, ["Reputation"] = REPUTATION}
	};

_V["WQT_SORT_OPTIONS"] = {[1] = _L["TIME"], [2] = FACTION, [3] = TYPE, [4] = ZONE, [5] = NAME, [6] = REWARD, [7] = QUALITY}
_V["SORT_OPTION_ORDER"] = {
	[1] = {"seconds", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "title"}
	,[2] = {"faction", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title"}
	,[3] = {"criteria", "questType", "questRarity", "elite", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title"}
	,[4] = {"zone", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title"}
	,[5] = {"title", "rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds"}
	,[6] = {"rewardType", "rewardQuality", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title"}
	,[7] = {"rewardQuality", "rewardType", "rewardAmount", "canUpgrade", "rewardId", "seconds", "title"}
}
_V["SORT_FUNCTIONS"] = {
	["rewardType"] = function(a, b) 
			if (a.reward.type and b.reward.type and a.reward.type ~= b.reward.type) then 
				if (a.reward.type == WQT_REWARDTYPE.none or b.reward.type == WQT_REWARDTYPE.none) then
					return a.reward.type > b.reward.type; 
				end
			
				return a.reward.type < b.reward.type; 
			end 
		end
	,["rewardQuality"] = function(a, b) if (a.reward.quality and b.reward.quality and a.reward.quality ~= b.reward.quality) then return a.reward.quality > b.reward.quality; end end
	,["canUpgrade"] = function(a, b) if (a.reward.canUpgrade and b.reward.canUpgrade and a.reward.canUpgrade ~= b.reward.canUpgrade) then return a.reward.canUpgrade and not b.reward.canUpgrade; end end
	,["seconds"] = function(a, b) if (a.time.seconds ~= b.time.seconds) then return a.time.seconds < b.time.seconds; end end
	,["rewardAmount"] = function(a, b) 
			local amountA = a.reward.amount;
			local amountB = b.reward.amount;
			if (C_PvP.IsWarModeDesired()) then
				local bonus = C_PvP.GetWarModeRewardBonus() / 100;
				if (_V["WARMODE_BONUS_REWARD_TYPES"][a.reward.type] and C_QuestLog.QuestHasWarModeBonus(a.questId)) then
					amountA = amountA + floor(amountA * bonus);
				end
				if (_V["WARMODE_BONUS_REWARD_TYPES"][b.reward.type] and C_QuestLog.QuestHasWarModeBonus(b.questId)) then
					amountB = amountB + floor(amountB * bonus);
				end
			end

			if (amountA ~= amountB) then 
				return amountA > amountB;
			end 
		end
	,["rewardId"] = function(a, b)
			if (a.reward.id and b.reward.id and a.reward.id ~= b.reward.id) then 
				return a.reward.id < b.reward.id; 
			end 
		end
	,["faction"] = function(a, b) 
			local _, factionIdA = C_TaskQuest.GetQuestInfoByQuestID(a.questId);
			local _, factionIdB = C_TaskQuest.GetQuestInfoByQuestID(b.questId);
			if (factionIdA ~= factionIdB) then 
				local factionA = WQT_Utils:GetFactionDataInternal(factionIdA);
				local factionB = WQT_Utils:GetFactionDataInternal(factionIdB);
				return factionA.name < factionB.name; 
			end 
		end
	,["questType"] = function(a, b) 
			if (a.isQuestStart ~= b.isQuestStart) then
				return a.isQuestStart and not b.isQuestStart;
			end		
			if (a.isDaily ~= b.isDaily) then
				return a.isDaily and not b.isDaily;
			end			
	
			local _, _, typeA = GetQuestTagInfo(a.questId);
			local _, _, typeB = GetQuestTagInfo(b.questId);
			if (typeA and typeB and typeA ~= typeB) then 
				return typeA >typeB; 
			end 
		end
	,["questRarity"] = function(a, b)
			local _, _, _, rarityA = GetQuestTagInfo(a.questId);
			local _, _, _, rarityB = GetQuestTagInfo(b.questId);
			if (rarityA and rarityB and rarityA ~= rarityB) then 
				return rarityA > rarityB; 
			end
		end
	,["title"] = function(a, b)
			local titleA = C_TaskQuest.GetQuestInfoByQuestID(a.questId);
			local titleB = C_TaskQuest.GetQuestInfoByQuestID(b.questId);
			if (titleA ~= titleB) then 
				return titleA < titleB;
			end 
		end
	,["elite"] = function(a, b) 
			local _, _, _, _, isEliteA = GetQuestTagInfo(a.questId);
			local _, _, _, _, isEliteB = GetQuestTagInfo(b.questId);
			if (isEliteA ~= isEliteB) then 
				return isEliteA and not isEliteB; 
			end 
		end
	,["criteria"] = function(a, b) 
			local aIsCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(a.questId);
			local bIsCriteria = WorldMapFrame.overlayFrames[_V["WQT_BOUNDYBOARD_OVERLAYID"]]:IsWorldQuestCriteriaForSelectedBounty(b.questId);
			if (aIsCriteria ~= bIsCriteria) then return aIsCriteria and not bIsCriteria; end 
		end
	,["zone"] = function(a, b) 
			local mapInfoA = WQT_Utils:GetMapInfoForQuest(a.questId);
			local mapInfoB = WQT_Utils:GetMapInfoForQuest(b.questId);
			if (mapInfoA and mapInfoA.name and mapInfoB and mapInfoB.name and mapInfoA.mapID ~= mapInfoB.mapID) then 
				if (WQT.settings.list.alwaysAllQuests and (mapInfoA.mapID == WorldMapFrame.mapID or mapInfoB.mapID == WorldMapFrame.mapID)) then 
					return mapInfoA.mapID == WorldMapFrame.mapID and mapInfoB.mapID ~= WorldMapFrame.mapID;
				end
				return mapInfoA.name < mapInfoB.name;
			end
		end
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
	}	

_V["FILTER_FUNCTIONS"] = {
		[2] = { -- Types
			["PvP"] 			= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_PVP; end 
			,["Petbattle"] 	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_PET_BATTLE; end 
			,["Dungeon"] 	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_DUNGEON; end 
			,["Raid"] 		= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_RAID; end 
			,["Profession"] 	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_PROFESSION; end 
			,["Invasion"] 	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_INVASION; end 
			,["Assault"]	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_FACTION_ASSAULT; end 
			,["Elite"]		= function(questInfo, questType) return select(5, GetQuestTagInfo(questInfo.questId)) and questType ~= LE_QUEST_TAG_TYPE_DUNGEON; end
			,["Default"]	= function(questInfo, questType) return questType == LE_QUEST_TAG_TYPE_NORMAL and not select(5, GetQuestTagInfo(questInfo.questId)); end 
			,["Daily"]		= function(questInfo, questType) return questInfo.isDaily; end 
			,["Threat"]		= function(questInfo, questType) return  C_QuestLog.IsThreatQuest(questInfo.questId); end 
			}
		,[3] = { -- Reward filters
			["Armor"]		= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.equipment + WQT_REWARDTYPE.weapon) > 0; end
			,["Relic"]		= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.relic) > 0; end
			,["Item"]		= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.spell + WQT_REWARDTYPE.item) > 0; end
			,["Artifact"]	= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.artifact) > 0; end
			,["Honor"]		= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.honor) > 0; end
			,["Gold"]		= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.gold) > 0; end
			,["Currency"]	= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.currency) > 0; end
			,["Experience"]	= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.xp) > 0; end
			,["Reputation"]	= function(questInfo, questType) return bit.band(questInfo.reward.typeBits, WQT_REWARDTYPE.reputation) > 0; end
			,["None"]		= function(questInfo, questType) return questInfo.reward.typeBits == 0; end
			}
	};

_V["WQT_CONTINENT_GROUPS"] = {
		[875]	= {876} 
		,[1011]	= {876}  -- Zandalar flightmap
		,[876]	= {875}
		,[1014]	= {875} -- Kul Tiras flightmap
		,[1504]	= {875, 876} -- Nazjatar flightmap
	}

_V["WQT_ZONE_MAPCOORDS"] = {
		[875]	= WQT_ZANDALAR -- Zandalar
		,[1011]	= WQT_ZANDALAR -- Zandalar flightmap
		,[876]	= WQT_KULTIRAS -- Kul Tiras
		,[1014]	= WQT_KULTIRAS -- Kul Tiras flightmap
		,[1504]	= { -- Nazjatar flightmap
			[1355] = {["x"] = 0, ["y"] = 0} -- Nazjatar
		}
		,[619] 	= WQT_LEGION 
		,[993] 	= WQT_LEGION -- Flightmap	
		,[905] 	= WQT_LEGION -- Argus
		,[12] 	= WQT_KALIMDOR 
		,[1209] 	= WQT_KALIMDOR -- Flightmap
		,[13]	= WQT_EASTERN_KINGDOMS
		,[1208]	= WQT_EASTERN_KINGDOMS -- Flightmap
		,[101]	= WQT_OUTLAND
		,[1467]	= WQT_OUTLAND -- Flightmap
		,[113]	= WQT_NORTHREND 
		,[1384]	= WQT_NORTHREND  -- Flightmap
		,[424]	= WQT_PANDARIA
		,[989]	= WQT_PANDARIA -- Flightmap
		,[572]	= WQT_DRAENOR
		,[990]	= WQT_DRAENOR -- Flightmap
		,[224]	= { -- Stranglethorn Vale
			[210] = {["x"] = 0.42, ["y"] = 0.62} -- Cape
			,[50] = {["x"] = 0.67, ["y"] = 0.40} -- North
		}
		,[947]		= {	
		} -- All of Azeroth
	}

_V["WQT_NO_FACTION_DATA"] = { ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 131071, ["name"]=_L["NO_FACTION"] } -- No faction
_V["WQT_FACTION_DATA"] = {
	[67] = 		{ ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 2203914 } -- Horde
	,[469] = 	{ ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 2203912 } -- Alliance
	,[609] = 	{ ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 1396983 } -- Cenarion Circle - Call of the Scarab
	,[910] = 	{ ["expansion"] = 0 ,["playerFaction"] = nil ,["texture"] = 236232 } -- Brood of Nozdormu - Call of the Scarab
	,[1090] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450997 } -- Kirin Tor
	,[1445] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["playerFaction"] = nil ,["texture"] = 133283 } -- Draenor Frostwolf Orcs
	,[1515] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["playerFaction"] = nil ,["texture"] = 1002596 } -- Dreanor Arakkoa Outcasts
	,[1731] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["playerFaction"] = nil ,["texture"] = 1048727 } -- Dreanor Council of Exarchs
	,[1681] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["playerFaction"] = nil ,["texture"] = 1042727 } -- Dreanor Vol'jin's Spear
	,[1682] = 	{ ["expansion"] = LE_EXPANSION_WARLORDS_OF_DRAENOR ,["playerFaction"] = nil ,["texture"] = 1042294 } -- Dreanor Wrynn's Vanguard
	,[1828] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450996 } -- Highmountain Tribes
	,[1859] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450998 } -- Nightfallen
	,[1883] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450995 } -- Dreamweavers
	,[1894] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1451000 } -- Wardens
	,[1900] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450994 } -- Court of Farnodis
	,[1948] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1450999 } -- Valarjar
	,[2045] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1708507 } -- Legionfall
	,[2103] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Horde" ,["texture"] = 2058217 } -- Zandalari Empire
	,[2165] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1708506 } -- Army of the Light
	,[2170] = 	{ ["expansion"] = LE_EXPANSION_LEGION ,["playerFaction"] = nil ,["texture"] = 1708505 } -- Argussian Reach
	,[2156] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Horde" ,["texture"] = 2058211 } -- Talanji's Expedition
	,[2157] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Horde" ,["texture"] = 2058207 } -- The Honorbound
	,[2158] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Horde" ,["texture"] = 2058213 } -- Voldunai
	,[2159] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Alliance" ,["texture"] = 2058204 } -- 7th Legion
	,[2160] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Alliance" ,["texture"] = 2058209 } -- Proudmoore Admirality
	,[2161] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Alliance" ,["texture"] = 2058208 } -- Order of Embers
	,[2162] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Alliance" ,["texture"] = 2058210 } -- Storm's Wake
	,[2163] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = nil ,["texture"] = 2058212 } -- Tortollan Seekers
	,[2164] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = nil ,["texture"] = 2058205 } -- Champions of Azeroth
	,[2373] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Horde" ,["texture"] = 2909044 } -- Unshackled
	,[2391] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = nil ,["texture"] = 2909316 } -- Rustbolt
	,[2400] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = "Alliance" ,["texture"] = 2909043 } -- Waveblade Ankoan
	,[2417] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = nil ,["texture"] = 3196264 } -- Uldum Accord
	,[2415] = 	{ ["expansion"] = LE_EXPANSION_BATTLE_FOR_AZEROTH ,["playerFaction"] = nil ,["texture"] = 3196265 } -- Rajani
}
-- Add localized faction names
for k, v in pairs(_V["WQT_FACTION_DATA"]) do
	v.name = GetFactionInfoByID(k);
end

-- This is just easier to maintain than changing the entire string every time
_V["PATCH_NOTES"] = {
		{["version"] = "8.3.03"
			,["minor"] = "2"
			,["fixes"] = {
				"Fixed an error that could occur when using the WorldFlightMap add-on."
				,"Fixed pin positions for N'zoth quests that move around when the objectives are updated (i.e. Assault: The Black Empire)."
			}
		}
		,{["version"] = "8.3.03"
			,["new"] = {
				"New General setting: Include dailies (default on). Treat certain dailies as world quests. Only affects dailies which Blizzard themselves treats as world quests."
				,"New Quest List setting: Time Colors (default on). Add color coding to times based on the remaining duration. Critital times (15 min) will be colored red regardless."
				,"New Pin setting: Elite Ring (default off). Replace Blizzard's elite dragon with a spiked ring."
			}
			,["changes"] = {	
				"Improved how frames anchor on the full screen world map. This fixes an issue for ElvUI users where the button wouldn't stay put. In addition, the location of the quest list frame will now also be saved between reloads. As a result of this change, their positions have been reset to their defaults."
				,"Made some improvements to map pins to reduce the chance of one completely overlapping another."
				,"Reduces framerate impact when changing zones on the map. Especially when using 'Always All Quests'."
				,"Moved the 'Always All Quest' setting from the 'Quest List' category to 'General'."
			}
			,["fixes"] = {
				"Fixed WQTU 'load' setting not disabling when it is disabled in the add-on list."
				,"Fixed world quests not showing on the Stranglethorn Vale map."
			}
		}
		,{["version"] = "8.3.02"
			,["intro"] = {"Rejoice again, for Blizzard fixed the new Threat Emissary issue right after 8.3 launch. Right now there are no known hidden quests preventing you from using all 25 quest slots!"}
			,["new"] = {
				"Returning setting: Precise Filters (default off). Found under General settings. Enabling this will cause filters to only pass quests that match ALL filters. E.g.: If you have both the 'Gold' and 'Artifact' filters enabled, you will only see quests that give BOTH rewards."
			}
			,["changes"] = {
				"Much like the official Blizzard settings, new WQT settings will be marked with an orange exclamation mark to make them easier to spot."
			}
			,["fixes"] = {
				"Fixed an issue with filters for N'zoth world quests."
				,"Fixed a rare case that could cause the filters and settings to break completely."
				,"Fixed quests in Stranglethorn Vale not highlighting Eastern Kingdoms on the world map."
			}
		}
		,{["version"] = "8.3.01"
			,["intro"] = {"Rejoice, for the long standing issue with PvP Conquest hidden quests counting to your max quests, was finally fixed by Blizzard! ... Alright enough rejoicing, 8.3 introduces the Threat Emissary Quest which has the exact same issue. gg no re"}
			,["new"] = {
				"Support for everything 8.3."
				,"New type filter: Threat. Filters the new N'zoth world quests."
			}
			,["changes"] = {
				"Overhauled the settings menu. With this change, following settings have been reworked:"
				,"'Bigger Pins' is now called 'Pin Scale' which instead uses a slider for more freedom."
				,"'Reward Texture' is now called 'Main Icon Type'."
			}
			,["fixes"] = {
				"Fixed some time display issues around the moment a timer should switch to a different color."
			}
		}
		,{["version"] = "8.2.05"
			,["minor"] = "4"
			,["new"] = {
				"New ring type settings: Rarity. Color the ring depending on the rarity of the quest."
				,"New pin icon: Quest Rarity (default off). Adds a colored icon to rare and epic quests."
				,"New pin icon: Time Remaining (default off). Adds an icon on the pin with a general indication of the time remaining."
			}
			,["changes"] = {
				"While using the 'Always All Quests', looking at the zone not linked to an expansion, will show all quests for the current expansion. I.e.: While in Stormwind you will still see BfA quests."
				,"Changed the looks of the 'tracked quest' marker on map pins."
			}
			,["fixes"] = {
				"Fixed a possible error when pin changes are disabled."
				,"Fixed 'Always All Quests' not including BfA quests in old zones."
			}
		}
		,{["version"] = "8.2.05"
			,["minor"] = "3"
			,["intro"] = {"Season's Greetings"}
			,["changes"] = {
				"Updated Localizations. If they were as outdated as I fear they are... I apologize."
			}
		}
		,{["version"] = "8.2.05"
			,["minor"] = "2"
			,["fixes"] = {
				"Fixed an issue that would cause official cooldown numbers to show on map pins."
				,"Fixed an issue with pin visibility for WorldFlightMap users."
			}
		}
		,{["version"] = "8.2.05"
			,["new"] = {
				"The map pins have been reworked to be completely custom by the add-on, resulting in some new changes:"
				,"- New settings: Pins On Continents (default off). Allows pins to be placed on continent maps."
				,"- New settings: Fade On Highlight (default on). When a quest is highlighted, all other quests are faded for better visibility."
				,"- Using the 'Always All Quests' setting will now show quests in neighbouring zones. I.e. you can see Drustvar quests while looking at Tiragarde Sound."
				,"- Flight maps will show additional pins such as Nazjatar daily quests."
				,"- General improvements to existing pin functionality."
			}
			,["changes"] = {
					"When sorting by reward, quests with no rewards will now be at the bottom of the list."
				}
			,["fixes"] = {
				"Fixed the party sync block from showing through the world quest list."
				,"Fixed dressing room previewing for quests offering weapons."
				,"Fixed issues between the dungeon, elite, and default type filters."
				,"Fixed disabling 'Save Filters/Sort' turning all filters off instead of on."
			}
		}
		,{["version"] = "8.2.04"
			,["new"] = {
				"The entire add-on now works during combat (With the exception of LFG buttons). It's crazy, I know. This became possible after fixing an error someone reported. The cause of this error was also what was preventing changes to the list during combat."
			}
			,["fixes"] = {
				"Fixed errors, and the prevention of closing the map during combat using the Esc key, while using other add-ons such as Mapster."
				,"Map pins for 'hard watched' quests, which show up on the continent maps, will now correctly get a make-over as well."
				,"Fixed some combat error related to LFG buttons."
				,"Fixed being able to track bonus objectives, which would result in not being able to untrack them again."
			}
		},{["version"] = "8.2.03"
			,["minor"] = "6"
			,["fixes"] = {
				"Fixed the quest log dissapearing when opening a full screen map by clicking on a quest in the objectives tracker."
				,"Fixed and error caused by the Stranglethorn Fishing Extravaganza."
			}
		}
		,{["version"] = "8.2.03"
			,["minor"] = "5"
			,["changes"] = {
				"Having reward icons disabled in combination with ring type \"Default\" will now show the default brown ring with other enabled features, rather than disappear completely."
				,"Disabling all pin changes will now ping quests using the official ping functionality. (To the best of it's ability)"
			}
			,["fixes"] = {
				"Fixed a TomTom settings option not correctly enabling/disabling."
				,"Fixed type icons not showing when the \"Reward Texture\" setting is disabled."
				,"Everything in relation to map pins (Official icons, official backgrounds, elite dragon, etc) will now correctly grow with the \"Bigger Pins\" setting enabled."
			}
		}
		,{["version"] = "8.2.03"
			,["minor"] = "4"
			,["fixes"] = {
				"Fixed an issue introduced in 8.2.03.3 preventing interaction with the default quest log. A reminder to nog push out an update at 1am..."
			}
		}
		,{["version"] = "8.2.03"
			,["minor"] = "3"
			,["fixes"] = {
				"Fixed an error related to reward quality colors."
				,"Fixed a number of issues related to combat"
				,"Fixed an issue that could cause the quest list to dissapear completely."
				,"Fixed the quest details frame being positioned slightly off."
				,"Fixed the world quest list bleeding through overlay frames when moving around."
			}
		}
		,{["version"] = "8.2.03"
			,["minor"] = "2"
			,["fixes"] = {
				"Fixed an error for TomTom users when completing a regular quest."
			}
		}
		,{["version"] = "8.2.03"
			,["intro"] = {"Introducing |cFFFFFFFFWorld Quest Tab Utilities|r, available on both WowInterface and Curse.<br/>This is a plug-in for World Quest Tab which adds some additional features. These include an overview of total reward sums for certain quest rewards in the list (i.e. gold or currencies), a sort option by distance to the quest, and a 14 day history graph of rewards from world quests.<br/>It is open for feature suggestions which might be concidered 'out of scope' for default World Quest Tab."}
			,["new"] = {
				"New 'Daily' quest type filter: can be used to filter daily quests from the list."
			}
			,["changes"] = {
				"Certain daily quests are once again part of the list with their own type icon."
				,"Reward amounts in the list will now take warmode bonuses into account."
				,"Quest rewards will prioritize their most impressive reward to display. I.e. showing manapears over gold rewards."
				,"Made this window bigger and tried to improve its readability."
				,"The full-screen button to toggle the quest list can now be dragged to a different position with the right mouse button."
			}
			,["fixes"] = {
				"Fixed support for quests with more then 2 reward types."
				,"Fixed a filtering issue related to zones."
				,"Fixed quest type filters."
				,"Fixed tooltips when hovering over quests in the list. This will also fix interractions with other add-ons such as TipTac."
				,"Fixed sort button text not greying out when being disabled."
				,"Fixed dragging of the full-screen quest list when the cursor goes outside the borders of the map."
				,"Fixed the flight map quest list not showing quests for older continents."
			}
		}
		,{["version"] = "8.2.02"
			,["intro"] = {"Behind the scenes rework resulting in the quest list being more accurate and less likely to miss quests."}
			,["new"] = {
				"New 'Quality' sorting option: Sorts the list by reward quality (epic > rare > ...) before sorting by reward type (equipement > azerite > ...)"
				,"New settings for the quest list:"
				,"- 'Show zone' setting (default on): Show zone label when quests from multiple zones are shown."
				,"- 'Expand times' setting (default off): Adds a secondary scale to timers in the quest list. I.e. adding minutes to hours."
			}
			,["changes"] = {
				"Filter settings now work more like Blizzard's filters. All checked by default, all off means nothing passes. This change resulted in a one time reset of your filters. My apologies."
				,"Like pin settings, moved quest list settings to a separate group."
				,"Times for quests with a total duration over 4 days are now purple."
				,"Timers update in real-time rather than when data is updated."
				,"Timers below 1 minute will now show as seconds."
				,"Flipped faction sorting to ascending."
				,"Using WorldFightMap will now act like the default map. To revert, enable Settings -> List Settings -> Always All Quests."
			}
			,["fixes"] = {
				"Fixed pin ring timers for quests with a duration over 4 days."
				,"Fixed certain error messages in chat while in combat."
				,"Fixed map highlights for WorldFightMap users."
			}
		}
		,{["version"] = "8.2.01"
			,["new"] = {
				"This 'What's new' window."
				,"New map pin features:"
				,"- 'Time left' on ring"
				,"- Reward type icon"
				,"- Quest type icon"
				,"- Bigger pins"
				,"New default pin layout. Check settings to customize."
				,"Quest list for full-screen world map. Click the globe in the top right."
				,"Quest list for flight map. Click the globe in the bottom right."
				,"Support for Mechagon and Nazjatar."
			}
			,["changes"] = {
				"Switched list 'selected' and 'tracker' highlight brightness."
				,"Swapped order of 'type' sort."
				,"Removed 'precise filter'. It was broken for ages."
				,"Sorting will now fall back to sorting by reward, rather than just by title."
			}
			,["fixes"] = {
				"Fixed order of 'Type' sort to prioritize elite and rare over common."
			}
		}
	}

_V["LATEST_UPDATE"] = "";
	
function _V:GeneratePatchNotes()
	_V["LATEST_UPDATE"] =  WQT_Utils:FormatPatchNotes(_V["PATCH_NOTES"], "World Quest Tab");
	_DeepWipeTable(_V["PATCH_NOTES"]);
end
