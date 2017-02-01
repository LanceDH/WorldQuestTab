local addonName, addon = ...

local L = {}
local locale = GetLocale();

L["EMPOWERING"]		= "Empowering";
L["QUESTLOG"]		= "Questlog";
L["WORLDQUEST"]		= "World Quests"
L["COMBATLOCK"]		= "Disabled during combat.";
L["FILTER"] 		= "Filter: %s";
L["SORT_BY"] 		= "By %s";
L["OPTIONS_INFO"] 	= "[WQT] Options can be found under the filter button."
L["NO_FACTION"] 	= "No Faction";
L["OTHER_FACTION"] 	= "Other";
L["TIME"]			= "Time";
L["FACTION"]		= "Faction";
L["TYPE"]			= "Type";
L["ZONE"]			= "Zone";
L["NAME"]			= "Name";
L["REWARD"]			= "Reward";
L["SETTINGS"]		= "Settings";
L["DEFAULT_TAB"]	= "Default Tab";
L["DEFAULT_TAB_TT"]	= "Set WQT as the default tab when you log in.\nDoes not apply to characters below lvl 110.";
L["SAVE_SETTINGS"]	= "Save Filters/Sort";
L["SAVE_SETTINGS_TT"]	= "Save filter and sort settings\nbetween sessions and reloads."
L["FILTER_PINS"]	= "Filter map pins";
L["FILTER_PINS_TT"]	= "Applies filters to\npins on the map.";
L["PIN_REWARDS"]	= "Map pin rewards";
L["PIN_REWARDS_TT"]	= "Show quest reward icons on map pins.";
L["PIN_COLOR"]		= "Map pin color ring";
L["PIN_COLOR_TT"]	= "Show a colored ring around pins\ndepending on reward type.";
L["PIN_TIME"]		= "Map pin time";
L["PIN_TIME_TT"]	= "Add time left to map pins.";
L["PIN_BIGGER"]		= "Bigger map pins";
L["PIN_BIGGER_TT"]	= "Slightly increase map pin size for visability.\nOnly available with Map pin rewards enabled";
L["SHOW_TYPE"]		= "Show Type";
L["SHOW_TYPE_TT"]	= "Show type icon\nin the quest list.";
L["SHOW_FACTION"]	= "Show Faction";
L["SHOW_FACTION_TT"]	= "Show faction icon\nin the quest list.";

L["TYPE_DEFAULT"]	= "Default";
L["TYPE_ELITE"]		= "Elite";
L["TYPE_PVP"]		= "PvP";
L["TYPE_PETBATTLE"]	= "Petbattle";
L["TYPE_DUNGEON"]	= "Dungeon";
L["TYPE_RAID"]		= "Raid";
L["TYPE_PROFESSION"]	= "Profession";
L["TYPE_INVASION"]	= "Invasion";
L["TYPE_EMISSARY"]	= "Emissary";

L["REWARD_ITEM"]	= "Item";
L["REWARD_ARMOR"]	= "Armor";
L["REWARD_GOLD"]	= "Gold";
L["REWARD_RESOURCES"]	= "Resources";
L["REWARD_ARTIFACT"]	= "Artifact";
L["REWARD_RELIC"]	= "Relic";

if locale == "deDE" then
L["EMPOWERING"]		= "Macht verleihen";
end

if locale == "esES" or locale == "esMX" then
L["EMPOWERING"]		= "Potenciando";
end

if locale == "ptBR" then
L["EMPOWERING"]		= "Fortalecendo";
end

if locale == "frFR" then
L["EMPOWERING"]		= "Renforcement";
end

if locale == "itIT" then
L["EMPOWERING"]		= "Potenziamento";
end

if locale == "ruRU" then
L["EMPOWERING"]		= "Усиление";
end

if locale == "zhCN" then
L["COMBATLOCK"] = "战斗中无法使用"
L["EMPOWERING"] = "强化"
L["FACTION"] = "阵营"
L["FILTER_PINS"] = "过滤地图显示"
L["NAME"] = "名称"
L["NO_FACTION"] = "无阵营"
L["PIN_REWARDS"] = "在地图上显示奖励图标"
L["PIN_TIME"] = "在地图上显示剩余时间"
L["QUESTLOG"] = "任务日志"
L["REWARD"] = "奖励"
L["REWARD_ARMOR"] = "装备"
L["REWARD_ARTIFACT"] = "能量"
L["REWARD_GOLD"] = "金币"
L["REWARD_ITEM"] = "物品"
L["REWARD_RESOURCES"] = "资源"
L["SETTINGS"] = "设置"
L["SHOW_FACTION"] = "显示阵营"
L["SHOW_TYPE"] = "显示类型"
L["SORT_BY"] = "按 %s"
L["TIME"] = "时间"
L["TYPE"] = "类型"
L["TYPE_DEFAULT"] = "默认"
L["TYPE_DUNGEON"] = "地下城"
L["TYPE_ELITE"] = "精英"
L["TYPE_EMISSARY"] = "使者"
L["TYPE_PETBATTLE"] = "宠物对战"
L["TYPE_PROFESSION"] = "专业"
L["WORLDQUEST"] = "世界任务"
L["ZONE"] = "区域"
end

if locale == "zhTW" then
L["EMPOWERING"]		= "强化";
end

if locale == "koKO" then
L["EMPOWERING"]		= "강화";
end

addon.L = L;