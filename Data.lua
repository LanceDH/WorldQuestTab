local addonName, addon = ...

addon.WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");
addon.externals = {};
addon.variables = {};
addon.debug = false;
addon.debugPrint = false;
addon.setupPhase = true;
addon.WQT_Utils = {};
local WQT_Utils = addon.WQT_Utils;
local _L = addon.L;
local _V = addon.variables;
local WQT = addon.WQT;
local _playerFaction = UnitFactionGroup("Player");

addon.WQT_Profiles =  {};
local WQT_Profiles = addon.WQT_Profiles;

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

_V["CONDUIT_SUBTYPE"] = {
	["endurance"] = 1,
	["finesse"] = 2,
	["potency"] = 3,
}

-- Combos
WQT_REWARDTYPE.gear = bit.bor(WQT_REWARDTYPE.weapon, WQT_REWARDTYPE.equipment);

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
_V["WQT_GREEN_FONT_COLOR"] = CreateColor(0, 0.75, 0);
_V["WQT_BLUE_FONT_COLOR"] = CreateColor(0.2, 0.60, 1);
_V["WQT_PURPLE_FONT_COLOR"] = CreateColor(0.73, 0.33, 0.82);

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

_V["ENUM_PIN_CONTINENT"] = {
	["none"] = 1
	,["tracked"] = 2
	,["all"] = 3
}

_V["PIN_VISIBILITY_CONTINENT"] = {
	[_V["ENUM_PIN_CONTINENT"].none] = {["label"] = NONE, ["tooltip"] = _L["PIN_VISIBILITY_NONE_TT"]} 
	,[_V["ENUM_PIN_CONTINENT"].tracked] = {["label"] = _L["PIN_VISIBILITY_TRACKED"], ["tooltip"] = _L["PIN_VISIBILITY_TRACKED_TT"]} 
	,[_V["ENUM_PIN_CONTINENT"].all] = {["label"] = ALL, ["tooltip"] = _L["PIN_VISIBILITY_ALL_TT"]} 
}

_V["ENUM_PIN_ZONE"] = {
	["none"] = 1
	,["tracked"] = 2
	,["all"] = 3
}

_V["PIN_VISIBILITY_ZONE"] = {
	[_V["ENUM_PIN_ZONE"].none] = {["label"] = NONE, ["tooltip"] = _L["PIN_VISIBILITY_NONE_TT"]} 
	,[_V["ENUM_PIN_ZONE"].tracked] = {["label"] = _L["PIN_VISIBILITY_TRACKED"], ["tooltip"] = _L["PIN_VISIBILITY_TRACKED_TT"]} 
	,[_V["ENUM_PIN_ZONE"].all] = {["label"] = ALL, ["tooltip"] = _L["PIN_VISIBILITY_ALL_TT"]} 
}

_V["SETTING_TYPES"] = {
	["category"] = 1
	,["subTitle"] = 2
	,["checkBox"] = 3
	,["slider"] = 4
	,["dropDown"] = 5
	,["button"] = 6
}

local function MakeIndexArg1(list)
	for k, v in pairs(list) do
		v.arg1 = k;
	end
end

MakeIndexArg1(_V["PIN_CENTER_LABELS"]);
MakeIndexArg1(_V["RING_TYPES_LABELS"]);
MakeIndexArg1(_V["PIN_VISIBILITY_CONTINENT"]);
MakeIndexArg1(_V["PIN_VISIBILITY_ZONE"]);

-- Not where they should be. Count them as invalid. Thanks Blizzard
_V["BUGGED_POI"] =  {
	[69964] = 864
	,[74441] = 864
	,[72128] = 864
	,[69849] = 864
	,[66004] = 864
	,[66356] = 864
	,[69882] = 864
	,[69865] = 864
	,[69850] = 864
	,[69951] = 864
	,[69961] = 864
	,[69960] = 864
	,[69956] = 864
	,[69954] = 864
	,[69970] = 864
	,[69953] = 864
	,[69975] = 864
	,[69973] = 864
	,[69969] = 864
	,[69972] = 864
	,[69858] = 864
	,[69861] = 864
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
--   valueChangedFunc (function(value, ...)): what actions should be taken when the value is changed. Value is nil for buttons
--   isDisabled (boolean|function()): Boolean or function returning if the setting should be disabled
--   getValueFunc (function()): Function returning the current value of the setting
--   isNew (boolean): Mark the setting as new by adding an exclamantion mark to the label
-- SLIDER SPECIFIC
--   min (number): min value
--   max (number): max value
--   valueStep (number): step the slider makes when moved
-- COLOR SPECIFIC
--   defaultColor (Color): the default color for this setting
-- DROPDOWN SPECIFIC
--   options (table): a list for options in following format 
--			{[id1] = {["label"] = "Displayed label"
--			 		,["tooltip"] = "additional tooltip info (optional)"
--					,["arg1"] = required first return value
--					,["arg2"] = optional second return value in valueChangedFunc
--					}
--			 ,[id2] = ...}

_V["SETTING_CATEGORIES"] = {
	{["id"]="DEBUG", ["label"] = "Debug"}
	,{["id"]="PROFILES", ["label"] = _L["PROFILES"]}
	,{["id"]="GENERAL", ["label"] = GENERAL, ["expanded"] = true}
	,{["id"]="GENERAL_OLDCONTENT", ["parentCategory"] = "GENERAL", ["label"] = _L["PREVIOUS_EXPANSIONS"]}
	,{["id"]="QUESTLIST", ["label"] = _L["QUEST_LIST"]}
	,{["id"]="MAPPINS", ["label"] = _L["MAP_PINS"]}
	,{["id"]="MAPPINS_MINIICONS", ["parentCategory"] = "MAPPINS", ["label"] = _L["MINI_ICONS"], ["expanded"] = true}
	,{["id"]="COLORS", ["label"] = _L["CUSTOM_COLORS"]}
	,{["id"]="COLORS_TIME", ["parentCategory"] = "COLORS", ["label"] = _L["TIME_COLORS"], ["expanded"] = true}
	,{["id"]="COLORS_REWARD_RING", ["parentCategory"] = "COLORS", ["label"] = _L["REWARD_COLORS_RING"]}
	,{["id"]="COLORS_REWARD_AMOUNT", ["parentCategory"] = "COLORS", ["label"] = _L["REWARD_COLORS_AMOUNT"]}
	,{["id"]="WQTU", ["label"] = "Utilities"}
	,{["id"]="TOMTOM", ["label"] = "TomTom"}
}

local function UpdateColorID(id, r, g, b) 
	local color = WQT_Utils:UpdateColor(_V["COLOR_IDS"][id], r, g, b);
	if (color) then
		WQT.settings.colors[id] = color:GenerateHexColor();
		WQT_ListContainer:DisplayQuestList();
		WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
	end
end

local function GetColorByID(id)
	return WQT_Utils:GetColor(_V["COLOR_IDS"][id]);
end

_V["SETTING_LIST"] = {
	-- Time
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = _L["TIME_CRITICAL"], ["tooltip"] = _L["TIME_CRITICAL_TT"], ["defaultColor"] = RED_FONT_COLOR
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeCritical" ,["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = _L["TIME_SHORT"], ["tooltip"] = _L["TIME_SHORT_TT"], ["defaultColor"] = _V["WQT_ORANGE_FONT_COLOR"]
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeShort",["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = _L["TIME_MEDIUM"], ["tooltip"] = _L["TIME_MEDIUM_TT"], ["defaultColor"] = _V["WQT_GREEN_FONT_COLOR"]
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeMedium",["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = _L["TIME_LONG"], ["tooltip"] = _L["TIME_LONG_TT"], ["defaultColor"] = _V["WQT_BLUE_FONT_COLOR"]
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeLong",["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = _L["TIME_VERYLONG"], ["tooltip"] = _L["TIME_VERYLONG_TT"], ["defaultColor"] = _V["WQT_PURPLE_FONT_COLOR"]
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeVeryLong",["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_TIME", ["label"] = NONE, ["tooltip"] = _L["TIME_NONE_TT"], ["defaultColor"] = _V["WQT_COLOR_CURRENCY"]
			, ["valueChangedFunc"] = UpdateColorID, ["colorID"] = "timeNone",["getValueFunc"] = GetColorByID
		},
	-- Rewards
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = NONE, ["defaultColor"] = _V["WQT_COLOR_NONE"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardNone", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = WEAPON, ["defaultColor"] = _V["WQT_COLOR_WEAPON"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardWeapon", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = ARMOR, ["defaultColor"] = _V["WQT_COLOR_ARMOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardArmor", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = _L["REWARD_CONDUITS"], ["defaultColor"] = _V["WQT_COLOR_RELIC"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardConduit", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = RELICSLOT, ["defaultColor"] = _V["WQT_COLOR_RELIC"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardRelic", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = WORLD_QUEST_REWARD_FILTERS_ANIMA, ["defaultColor"] = _V["WQT_COLOR_ARTIFACT"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardAnima", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = ITEM_QUALITY6_DESC, ["defaultColor"] = _V["WQT_COLOR_ARTIFACT"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardArtifact", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = ITEMS, ["defaultColor"] = _V["WQT_COLOR_ITEM"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardItem", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = POWER_TYPE_EXPERIENCE, ["defaultColor"] = _V["WQT_COLOR_ITEM"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardXp", ["getValueFunc"] = GetColorByID
		},	
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = WORLD_QUEST_REWARD_FILTERS_GOLD, ["defaultColor"] = _V["WQT_COLOR_GOLD"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardGold", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = CURRENCY, ["defaultColor"] = _V["WQT_COLOR_CURRENCY"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardCurrency", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = REPUTATION, ["defaultColor"] = _V["WQT_COLOR_CURRENCY"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardReputation", ["getValueFunc"] = GetColorByID
		},	
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = HONOR, ["defaultColor"] = _V["WQT_COLOR_HONOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardHonor", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_RING", ["label"] = ADDON_MISSING, ["defaultColor"] = _V["WQT_COLOR_MISSING"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardMissing", ["getValueFunc"] = GetColorByID
		},	
	-- Rewards
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = WEAPON, ["defaultColor"] = _V["WQT_COLOR_WEAPON"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextWeapon", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = ARMOR, ["defaultColor"] = _V["WQT_COLOR_ARMOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextArmor", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = _L["REWARD_CONDUITS"], ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextConduit", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = RELICSLOT, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextRelic", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = ITEMS, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextItem", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = POWER_TYPE_EXPERIENCE, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextXp", ["getValueFunc"] = GetColorByID
		},	
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = WORLD_QUEST_REWARD_FILTERS_GOLD, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextGold", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = CURRENCY, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextCurrency", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = REPUTATION, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextReputation", ["getValueFunc"] = GetColorByID
		},	
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = HONOR, ["defaultColor"] = _V["WQT_WHITE_FONT_COLOR"], 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextHonor", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = WORLD_QUEST_REWARD_FILTERS_ANIMA, ["defaultColor"] = GREEN_FONT_COLOR, 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextAnima", ["getValueFunc"] = GetColorByID
		},
	{["template"] = "WQT_SettingColorTemplate", ["categoryID"] = "COLORS_REWARD_AMOUNT", ["label"] = ITEM_QUALITY6_DESC, ["defaultColor"] = GREEN_FONT_COLOR, 
			["valueChangedFunc"] = UpdateColorID, ["colorID"] = "rewardTextArtifact", ["getValueFunc"] = GetColorByID
		},
		
	{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "PROFILES", ["label"] = _L["CURRENT_PROFILE"], ["tooltip"] = _L["CURRENT_PROFILE_TT"], ["options"] = function() return WQT_Profiles:GetProfiles() end
			, ["valueChangedFunc"] = function(arg1, arg2)
				if (arg1 == WQT_Profiles:GetActiveProfileId()) then
					-- Trying to load currently active profile
					return;
				end
				WQT_Profiles:Load(arg1);
				
				WQT_WorldQuestFrame:ApplyAllSettings();
			end
			,["getValueFunc"] = function() return WQT_Profiles:GetIndexById(WQT.db.char.activeProfile) end
			}
	,{["template"] = "WQT_SettingTextInputTemplate", ["categoryID"] = "PROFILES", ["label"] = _L["PROFILE_NAME"] , ["tooltip"] = _L["PROFILE_NAME_TT"] 
			, ["valueChangedFunc"] = function(value) 
				WQT_Profiles:ChangeActiveProfileName(value);
			end
			,["getValueFunc"] = function() 
				return WQT_Profiles:GetActiveProfileName(); 
			end
			,["isDisabled"] = function() return WQT_Profiles:DefaultIsActive() end
			}
	,{["template"] = "WQT_SettingButtonTemplate", ["categoryID"] = "PROFILES", ["label"] = _L["NEW_PROFILE"], ["tooltip"] = _L["NEW_PROFILE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT_Profiles:CreateNew();
			end
			}
	,{["template"] = "WQT_SettingConfirmButtonTemplate", ["categoryID"] = "PROFILES", ["label"] =_L["RESET_PROFILE"], ["tooltip"] = _L["RESET_PROFILE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT_Profiles:ResetActive();
				WQT_WorldQuestFrame:ApplyAllSettings();
			end
			}
	,{["template"] = "WQT_SettingConfirmButtonTemplate", ["categoryID"] = "PROFILES", ["label"] =_L["REMOVE_PROFILE"], ["tooltip"] = _L["REMOVE_PROFILE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT_Profiles:Delete(WQT_Profiles:GetActiveProfileId());
				WQT_WorldQuestFrame:ApplyAllSettings();
			end
			,["isDisabled"] = function() return WQT_Profiles:DefaultIsActive()  end
			}
	-- General settings
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["DEFAULT_TAB"], ["tooltip"] = _L["DEFAULT_TAB_TT"]
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
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["PRECISE_FILTER"], ["tooltip"] = _L["PRECISE_FILTER_TT"]
			, ["valueChangedFunc"] = function(value) 
				for i=1, 3 do
					if (not WQT:IsUsingFilterNr(i)) then
						WQT:SetAllFilterTo(i, not value);
					end
				end
			
				WQT.settings.general.preciseFilters = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.general.preciseFilters end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["ALWAYS_ALL"], ["tooltip"] = _L["ALWAYS_ALL_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.alwaysAllQuests = value;
				local mapAreaID = WorldMapFrame.mapID;
				WQT_WorldQuestFrame.dataProvider:LoadQuestsInZone(mapAreaID);
				WQT_ListContainer:UpdateQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.alwaysAllQuests end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL", ["label"] = _L["AUTO_EMISARRY"], ["tooltip"] = _L["AUTO_EMISARRY_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.autoEmisarry = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.autoEmisarry end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL_OLDCONTENT", ["label"] = _L["CALLINGS_BOARD"], ["tooltip"] = _L["CALLINGS_BOARD_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.sl_callingsBoard = value;
				WQT_CallingsBoard:UpdateVisibility();
			end
			,["getValueFunc"] = function() return WQT.settings.general.sl_callingsBoard end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL_OLDCONTENT", ["label"] = _L["GENERIC_ANIMA"], ["tooltip"] = _L["GENERIC_ANIMA_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.sl_genericAnimaIcons = value;
				WQT_WorldQuestFrame.dataProvider:ReloadQuestRewards();
			end
			,["getValueFunc"] = function() return WQT.settings.general.sl_genericAnimaIcons end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL_OLDCONTENT", ["label"] = _L["EMISSARY_COUNTER"], ["tooltip"] = _L["EMISSARY_COUNTER_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.bountyCounter = value;
				WQT_WorldQuestFrame:UpdateBountyCounters();
				WQT_WorldQuestFrame:RepositionBountyTabs();
			end
			,["getValueFunc"] = function() return WQT.settings.general.bountyCounter end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL_OLDCONTENT", ["label"] = _L["EMISSARY_REWARD"], ["tooltip"] = _L["EMISSARY_REWARD_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.bountyReward = value;
				WQT_WorldQuestFrame:UpdateBountyCounters();
			end
			,["getValueFunc"] = function() return WQT.settings.general.bountyReward end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "GENERAL_OLDCONTENT", ["label"] = _L["EMISSARY_SELECTED_ONLY"], ["tooltip"] = _L["EMISSARY_SELECTED_ONLY_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.bountySelectedOnly = value;
				WQT_ListContainer:UpdateQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.general.bountySelectedOnly end
			}
	-- Quest List
	,{["frameName"] = "WQT_SettingsQuestListPreview", ["categoryID"] = "QUESTLIST"}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_TYPE"], ["tooltip"] = _L["SHOW_TYPE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.typeIcon = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.typeIcon end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_FACTION"], ["tooltip"] = _L["SHOW_FACTION_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.factionIcon = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.factionIcon end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SHOW_ZONE"], ["tooltip"] = _L["SHOW_ZONE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.showZone = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.showZone end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["SETTINGS_WARBAND_ICON"], ["tooltip"] = _L["SETTINGS_WARBAND_ICON_TT"]
			, ["valueChangedFunc"] = function(value)
				WQT.settings.list.warbandIcon = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.warbandIcon end
			}
	,{["template"] = "WQT_SettingSliderTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["REWARD_NUM_DISPLAY"], ["tooltip"] = _L["REWARD_NUM_DISPLAY_TT"], ["min"] = 0, ["max"] = 5, ["valueStep"] = 1
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.rewardNumDisplay = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.rewardNumDisplay end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["AMOUNT_COLORS"], ["tooltip"] = _L["AMOUNT_COLORS_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.amountColors = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.amountColors end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["LIST_COLOR_TIME"], ["tooltip"] = _L["LIST_COLOR_TIME_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.colorTime = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.colorTime end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["LIST_FULL_TIME"], ["tooltip"] = _L["LIST_FULL_TIME_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.list.fullTime = value;
				WQT_ListContainer:DisplayQuestList();
			end
			,["getValueFunc"] = function() return WQT.settings.list.fullTime end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "QUESTLIST", ["label"] = _L["PIN_FADE_ON_PING"], ["tooltip"] = _L["PIN_FADE_ON_PING_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.fadeOnPing = value;
			end
			,["getValueFunc"] = function() return WQT.settings.pin.fadeOnPing end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	-- Map Pin
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_DISABLE"], ["tooltip"] = _L["PIN_DISABLE_TT"], ["suggestReload"] = true
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.disablePoI = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
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
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_ELITE_RING"], ["tooltip"] = _L["PIN_ELITE_RING_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.eliteRing  = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.eliteRing end
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
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_CENTER"], ["tooltip"] = _L["PIN_CENTER_TT"], ["options"] = _V["PIN_CENTER_LABELS"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.centerType = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.centerType end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_RING_TITLE"], ["tooltip"] = _L["PIN_RING_TT"], ["options"] = _V["RING_TYPES_LABELS"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.ringType = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.ringType end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}	
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_VISIBILITY_ZONE"], ["tooltip"] = _L["PIN_VISIBILITY_ZONE_TT"], ["options"] = _V["PIN_VISIBILITY_ZONE"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.zoneVisible = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.zoneVisible end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	,{["template"] = "WQT_SettingDropDownTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["PIN_VISIBILITY_CONTINENT"], ["tooltip"] = _L["PIN_VISIBILITY_CONTINENT_TT"], ["options"] = _V["PIN_VISIBILITY_CONTINENT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.continentVisible = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.continentVisible end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI end
			}
	-- Pin icons
	--,{["template"] = "WQT_SettingSubTitleTemplate", ["categoryID"] = "MAPPINS", ["label"] = _L["MINI_ICONS"]}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS_MINIICONS", ["label"] = _L["PIN_TYPE"], ["tooltip"] = _L["PIN_TYPE_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.typeIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function()  return WQT.settings.pin.typeIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI; end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS_MINIICONS", ["label"] = _L["PIN_RARITY_ICON"], ["tooltip"] = _L["PIN_RARITY_ICON_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.rarityIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.rarityIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI;  end
			}		
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS_MINIICONS", ["label"] = _L["PIN_TIME_ICON"], ["tooltip"] = _L["PIN_TIME_ICON_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.timeIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.timeIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI;  end
			}	
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "MAPPINS_MINIICONS", ["label"] = _L["SETTINGS_WARBAND_ICON"], ["tooltip"] = _L["SETTINGS_WARBAND_ICON_TT"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.warbandIcon = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData()
			end
			,["getValueFunc"] = function() return WQT.settings.pin.warbandIcon; end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI;  end
			}	
	,{["template"] = "WQT_SettingSliderTemplate", ["categoryID"] = "MAPPINS_MINIICONS", ["label"] = _L["REWARD_NUM_DISPLAY_PIN"], ["tooltip"] = _L["REWARD_NUM_DISPLAY_PIN_TT"], ["min"] = 0, ["max"] = 3, ["valueStep"] = 1
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.pin.numRewardIcons = value;
				WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
			end
			,["getValueFunc"] = function() return WQT.settings.pin.numRewardIcons end
			,["isDisabled"] = function() return WQT.settings.pin.disablePoI; end
			}
}

_V["SETTING_UTILITIES_LIST"] = {
	{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "WQTU", ["label"] = _L["LOAD_UTILITIES"], ["tooltip"] = _L["LOAD_UTILITIES_TT"], ["disabledTooltip"] = _L["LOAD_UTILITIES_TT_DISABLED"]
			, ["valueChangedFunc"] = function(value) 
				WQT.settings.general.loadUtilities = value;
				if (value and not C_AddOns.IsAddOnLoaded("WorldQuestTabUtilities")) then
					--C_AddOns.LoadAddOn("WorldQuestTabUtilities");
					--WQT_ListContainer:UpdateQuestList();
				end
			end
			,["getValueFunc"] = function() return WQT.settings.general.loadUtilities end
			,["isDisabled"] = function() return C_AddOns.GetAddOnEnableState("WorldQuestTabUtilities") == 0 end
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
	[2] = {["Invasion"] = true, ["Assault"] = true}
	,[3] = {["Artifact"] = true, ["Relic"] = true}
}

_V["WQT_SORT_OPTIONS"] = {[1] = _L["TIME"], [2] = FACTION, [3] = TYPE, [4] = ZONE, [5] = NAME, [6] = REWARD, [7] = QUALITY}
_V["SORT_OPTION_ORDER"] = {
	[1] = {"seconds", "rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "title"},
	[2] = {"faction", "rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds", "title"},
	[3] = {"criteria", "questType", "questRarity", "elite", "rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds", "title"},
	[4] = {"zone", "rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds", "title"},
	[5] = {"title", "rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds"},
	[6] = {"rewardType", "rewardQuality", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds", "title"},
	[7] = {"rewardQuality", "rewardType", "rewardAmount", "numRewards", "canUpgrade", "rewardId", "seconds", "title"},
}
_V["SORT_FUNCTIONS"] = {
	["rewardType"] = function(a, b) 
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
		end
	,["rewardQuality"] = function(a, b) 
			local aQuality = a:GetRewardQuality();
			local bQuality = b:GetRewardQuality();
			if (not aQuality or not bQuality) then
				return aQuality and not bQuality;
			end

			if (aQuality and bQuality and aQuality ~= bQuality) then 
				return aQuality > bQuality; 
			end 
		end
	,["canUpgrade"] = function(a, b) 
			local aCanUpgrade = a:GetRewardCanUpgrade();
			local bCanUpgrade = b:GetRewardCanUpgrade();
			if (aCanUpgrade and bCanUpgrade and aCanUpgrade ~= bCanUpgrade) then
				return aCanUpgrade and not bCanUpgrade; 
			end
		end
	,["seconds"] = function(a, b) 
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end

			if (a.time.seconds ~= b.time.seconds) then
				return a.time.seconds < b.time.seconds;
			end
		end
	,["rewardAmount"] = function(a, b) 
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end

			local amountA = a:GetRewardAmount();
			local amountB = b:GetRewardAmount();

			if (C_QuestLog.QuestCanHaveWarModeBonus(a.questID)) then
				local rewardA = a:GetReward(1);
				amountA = WQT_Utils:CalculateWarmodeAmount(rewardA);
			end

			if (C_QuestLog.QuestCanHaveWarModeBonus(b.questID)) then
				local rewardB = b:GetReward(1);
				amountB = WQT_Utils:CalculateWarmodeAmount(rewardB);
			end

			if (amountA ~= amountB) then 
				return amountA > amountB;
			end 
		end
	,["rewardId"] = function(a, b)
			local aId = a:GetRewardId();
			local bId = b:GetRewardId();
			if (aId and bId and aId ~= bId) then 
				return aId < bId; 
			end 
		end
	,["faction"] = function(a, b) 
			if (a.factionID ~= b.factionID) then 
				if(not a.factionID or not b.factionID) then
					return b.factionID == nil;
				end

				local factionA = WQT_Utils:GetFactionDataInternal(a.factionID);
				local factionB = WQT_Utils:GetFactionDataInternal(b.factionID);
				return factionA.name < factionB.name; 
			end
		end

	,["questType"] = function(a, b) 
			if (a.isBonusQuest ~= b.isBonusQuest) then
				return b.isBonusQuest;
			end
			
			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			if (tagInfoA and tagInfoB and tagInfoA.worldQuestType and tagInfoB.worldQuestType and tagInfoA.worldQuestType ~= tagInfoB.worldQuestType) then 
				return tagInfoA.worldQuestType > tagInfoB.worldQuestType; 
			end 
		end
	,["questRarity"] = function(a, b)
			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			if (tagInfoA and tagInfoB and tagInfoA.quality and tagInfoB.quality and tagInfoA.quality ~= tagInfoB.quality) then 
				return tagInfoA.quality > tagInfoB.quality; 
			end
		end
	,["title"] = function(a, b)
			if (a.title ~= b.title) then 
				return a.title < b.title;
			end 
		end
	,["elite"] = function(a, b) 
			local tagInfoA = a:GetTagInfo();
			local tagInfoB = b:GetTagInfo();
			local aIsElite = tagInfoA and tagInfoA.isElite;
			local bIsElite = tagInfoB and tagInfoB.isElite;
			if (aIsElite ~= bIsElite) then 
				return aIsElite and not bIsElite; 
			end 
		end
	,["criteria"] = function(a, b) 
			local aIsCriteria = a:IsCriteria(WQT.settings.general.bountySelectedOnly);
			local bIsCriteria = b:IsCriteria(WQT.settings.general.bountySelectedOnly);
			if (aIsCriteria ~= bIsCriteria) then return aIsCriteria and not bIsCriteria; end 
		end
	,["zone"] = function(a, b) 
			local mapInfoA = WQT_Utils:GetCachedMapInfo(a.mapID);
			local mapInfoB = WQT_Utils:GetCachedMapInfo(b.mapID);
			if (not mapInfoA or not mapInfoB) then
				return mapInfoA;
			end

			if (mapInfoA and mapInfoA.name and mapInfoB and mapInfoB.name and mapInfoA.mapID ~= mapInfoB.mapID) then 
				if (WQT.settings.list.alwaysAllQuests and (mapInfoA.mapID == WorldMapFrame.mapID or mapInfoB.mapID == WorldMapFrame.mapID)) then 
					return mapInfoA.mapID == WorldMapFrame.mapID and mapInfoB.mapID ~= WorldMapFrame.mapID;
				end
				return mapInfoA.name < mapInfoB.name;
			elseif (mapInfoA.mapID == mapInfoB.mapID) then
				if (a.isBonusQuest ~= b.isBonusQuest) then
					return b.isBonusQuest;
				end
			end
		end
	,["numRewards"] = function(a, b) 
			local aNumRewards = #a.rewardList;
			local bNumRewards = #b.rewardList;
			if (aNumRewards ~= bNumRewards) then
				return aNumRewards > bNumRewards;
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
		,[WQT_REWARDTYPE.anima] = {["texture"] =  "Interface/Addons/WorldQuestTab/Images/AnimaIcon", ["scale"] = 1.15, ["l"] = 0, ["r"] = 1, ["t"] = 0, ["b"] = 1, ["color"] = CreateColor(0.8, 0.8, 0.9)} -- Anima
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

-- /run print(string.format("%.2f %.2f", WorldMapFrame:GetNormalizedCursorPosition()))
-- /run print(WorldMapFrame.mapID)
-- /run print(FlightMapFrame.mapID)

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
		versionCheck = "";
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
			sortBy = 1;
			fullScreenContainerPos = {["anchor"] = "TOPLEFT", ["x"] = 0, ["y"] = -25};
		
			defaultTab = false;
			saveFilters = true;
			preciseFilters = false;
			emissaryOnly = false;
			autoEmisarry = true;
			questCounter = true;
			bountyCounter = true;
			bountyReward = false;
			bountySelectedOnly = true;
			showDisliked = true;
			
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
			alwaysAllQuests = false;
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
			timeLabel = false;
			fadeOnPing = true;
			eliteRing = false;
			ringType = _V["RING_TYPES"].time;
			centerType = _V["PIN_CENTER_TYPES"].reward;
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

-- This is just easier to maintain than changing the entire string every time
-- version			Version number 
-- minor			Minor version number (gets added after version number)
-- intro			Message for some extra details
-- new				List of new additions
-- changes			List of things that got changed
-- fixes			List of bugfixes

local patchNotes = {
		{["version"] = "11.2.04";
			["changes"] = {
				"Slightly lightened up the visuals of map pins";
			};
			["fixes"] = {
				"Fixed a possible error in areas such as Island Expeditions with Always All Quests enabled";
				"Fixed a possible error with other add-ons adding tabs to the world map";
			};
		};
		{["version"] = "11.2.03";
			["new"] = {
				"Warband bonus reward icons for both the quest list and map pins (default off)";
			};
			["fixes"] = {
				"Fixed tooltip rewards not showing if its appearance isn't collected yet";
				"Fixed tooltips not showing a message regarding one-time warband bonus reputation";
				"Fixed a possible error for characters level 70-79";
				"Fixed some issues with Asian reward amount. Maybe, I can't actually test this myself";
				"Fixed the zhTW loca just straight up not getting loaded (woops)";
				"Fixed an error in the settings with Warmode enabled";
			};
		};
		{["version"] = "11.2.02";
			["changes"] = {
				"Increased the max rewards in the quest list from 4 to 5";
			};
			["fixes"] = {
				"Fixed an issue where some settings wouldn't save between reloads";
				"Fixed an issue that caused some quests to show up while on the Azeroth map that shouldn't";
				"Fixed incorrect reward amounts using War Mode";
				"Fixed item level on relic rewards";
				"Fixed Zereth Mortis quests not showing while on the Shadowlands map";
			};
		};
		{["version"] = "11.2.01";
			["intro"] = {
				"Update for patch 11.2";
				"Note: It's possible you might not see all quests available in K'aresh unless you are physically inside the zone. This is an issue on Blizzard's end.";
			};
			["changes"] = {
				"Made some changes to which quests show up in the list";
				"Using the Blizzard's map filters will once again affect the pins and quest list";
			};
			["fixes"] = {
				"Fixed a possible error with the custom Shadowlands bounty board";
			};
		};
		{["version"] = "11.1.01";
			["intro"] = {
				[[Shoutout to the people who tried their best to keep things running for the past 4 years. I'd name you all but I only now realize how many of you there are.
				<br/>If you created a fork, helped those forks, or even guided other people to said forks; Thank you.]];
				"Please note that maintaining this add-on is low priority. Which means updates might be slow and unreliable.";
			};
			["changes"] = {
				"Compatibility with patch 11.1.7";
				"Visual update to match the new UI";
				"A bunch of refactoring of which you hopefully only notice positive things";
				"Things that didn't survive:<br/>- Quest counter on the normal quest tab<br/>- Anything LFG related<br/>- Support for WQT Utilities<br/>- Daily quest things such as old Nzoth quests";
			};
		}
	}

local FORMAT_VERSION_MINOR = "%s|cFF888888.%s|r"
local FORMAT_H1 = "%s<h1 align='center'>%s</h1>";
local FORMAT_H2 = "%s<h2>%s:</h2>";
local FORMAT_p = "%s<p>%s</p>";
local FORMAT_WHITESPACE = "%s<h3>&#160;</h3>"
local FORMAT_WHITESPACE_DOUBLE = "%s<h3>&#160;</h3><h3>&#160;</h3>"

local function AddNotes(updateMessage, title, notes)
	if (not notes) then return updateMessage; end
	if (title) then
		updateMessage = FORMAT_H2:format(updateMessage, title);
	end
	for k, note in ipairs(notes) do
		updateMessage = FORMAT_p:format(updateMessage, note);
		updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	end
	updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	return updateMessage;
end

local function FormatPatchNotes(notes)
	local updateMessage = "<html><body><h3>&#160;</h3>";
	updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	for i=1, #notes do
		local patch = notes[i];
		local version = patch.minor and FORMAT_VERSION_MINOR:format(patch.version, patch.minor) or patch.version;
		updateMessage = FORMAT_H1:format(updateMessage, version);
		updateMessage = AddNotes(updateMessage, nil, patch.intro);
		updateMessage = AddNotes(updateMessage, "New", patch.new);
		updateMessage = AddNotes(updateMessage, "Changes", patch.changes);
		updateMessage = AddNotes(updateMessage, "Fixes", patch.fixes);

		updateMessage = FORMAT_WHITESPACE_DOUBLE:format(updateMessage);
	end
	return updateMessage .. "</body></html>";
end

_V["LATEST_UPDATE"] =  FormatPatchNotes(patchNotes);
_DeepWipeTable(patchNotes);
