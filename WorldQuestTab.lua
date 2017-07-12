local addonName, addon = ...

local WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");

local _L = addon.L

WQT_TAB_NORMAL = _L["QUESTLOG"];
WQT_TAB_WORLD = _L["WORLDQUEST"];

local WQT_REWARDTYPE_ARMOR = 1;
local WQT_REWARDTYPE_RELIC = 2;
local WQT_REWARDTYPE_ARTIFACT = 3;
local WQT_REWARDTYPE_ITEM = 4;
local WQT_REWARDTYPE_GOLD = 5;
local WQT_REWARDTYPE_CURRENCY = 6;
local WQT_REWARDTYPE_HONOR = 7;
local WQT_REWARDTYPE_XP = 8;
local WQT_REWARDTYPE_NONE = 9;

local WQT_WHITE_FONT_COLOR = CreateColor(0.8, 0.8, 0.8);
local WQT_ORANGE_FONT_COLOR = CreateColor(1, 0.6, 0);
local WQT_GREEN_FONT_COLOR = CreateColor(0, 0.75, 0);
local WQT_BLUE_FONT_COLOR = CreateColor(0.1, 0.68, 1);
local WQT_COLOR_ARTIFACT = CreateColor(0, 0.75, 0);
local WQT_COLOR_GOLD = CreateColor(0.85, 0.7, 0) ;
local WQT_COLOR_CURRENCY = CreateColor(0.6, 0.4, 0.1) ;
local WQT_COLOR_ITEM = CreateColor(0.85, 0.85, 0.85) ;
local WQT_COLOR_ARMOR = CreateColor(0.7, 0.3, 0.9) ;
local WQT_COLOR_RELIC = CreateColor(0.3, 0.7, 1);
local WQT_COLOR_MISSING = CreateColor(0.7, 0.1, 0.1);
local WQT_COLOR_HONOR = CreateColor(0.8, 0.26, 0);
local WQT_COLOR_AREA_NAME = CreateColor(1.0, 0.9294, 0.7607);
local WQT_ARTIFACT_R, WQT_ARTIFACT_G, WQT_ARTIFACT_B = GetItemQualityColor(6);

local WQT_LISTITTEM_HEIGHT = 32;
local WQT_REFRESH_DEFAULT = 60;

local WQT_QUESTIONMARK = "Interface/ICONS/INV_Misc_QuestionMark";
local WQT_EXPERIENCE = "Interface/ICONS/XP_ICON";
local WQT_HONOR = "Interface/ICONS/Achievement_LegionPVPTier4";
local WQT_FACTIONUNKNOWN = "Interface/addons/WorldQuestTab/Images/FactionUnknown";

local WQT_TYPEFLAG_LABELS = {
		[2] = {["Default"] = _L["TYPE_DEFAULT"], ["Elite"] = _L["TYPE_ELITE"], ["PvP"] = _L["TYPE_PVP"], ["Petbattle"] = _L["TYPE_PETBATTLE"], ["Dungeon"] = _L["TYPE_DUNGEON"]
			, ["Raid"] = _L["TYPE_RAID"], ["Profession"] = _L["TYPE_PROFESSION"], ["Invasion"] = _L["TYPE_INVASION"]}--, ["Emissary"] = _L["TYPE_EMISSARY"]}
		,[3] = {["Item"] = _L["REWARD_ITEM"], ["Armor"] = _L["REWARD_ARMOR"], ["Gold"] = _L["REWARD_GOLD"], ["Currency"] = _L["REWARD_RESOURCES"], ["Artifact"] = _L["REWARD_ARTIFACT"]
			, ["Relic"] = _L["REWARD_RELIC"], ["None"] = _L["REWARD_NONE"], ["Experience"] = _L["REWARD_EXPERIENCE"], ["Honor"] = _L["REWARD_HONOR"]}
	};

local WQT_FILTER_FUNCTIONS = {
		[2] = { -- Types
			function(quest, flags) return (flags["PvP"] and quest.type == LE_QUEST_TAG_TYPE_PVP); end 
			,function(quest, flags) return (flags["Petbattle"] and quest.type == LE_QUEST_TAG_TYPE_PET_BATTLE); end 
			,function(quest, flags) return (flags["Dungeon"] and quest.type == LE_QUEST_TAG_TYPE_DUNGEON); end 
			,function(quest, flags) return (flags["Raid"] and quest.type == LE_QUEST_TAG_TYPE_RAID); end 
			,function(quest, flags) return (flags["Profession"] and quest.type == LE_QUEST_TAG_TYPE_PROFESSION); end 
			,function(quest, flags) return (flags["Invasion"] and quest.type == LE_QUEST_TAG_TYPE_INVASION); end 
			,function(quest, flags) return (flags["Elite"] and (quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.isElite)); end 
			,function(quest, flags) return (flags["Default"] and (quest.type ~= LE_QUEST_TAG_TYPE_PVP and quest.type ~= LE_QUEST_TAG_TYPE_PET_BATTLE and quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON  and quest.type ~= LE_QUEST_TAG_TYPE_PROFESSION and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.type ~= LE_QUEST_TAG_TYPE_INVASION and not quest.isElite)); end 
			}
		,[3] = { -- Reward filters
			function(quest, flags) return (flags["Armor"] and quest.rewardType == WQT_REWARDTYPE_ARMOR); end 
			,function(quest, flags) return (flags["Relic"] and quest.rewardType == WQT_REWARDTYPE_RELIC); end 
			,function(quest, flags) return (flags["Item"] and quest.rewardType == WQT_REWARDTYPE_ITEM); end 
			,function(quest, flags) return (flags["Artifact"] and quest.rewardType == WQT_REWARDTYPE_ARTIFACT); end 
			,function(quest, flags) return (flags["Honor"] and (quest.rewardType == WQT_REWARDTYPE_HONOR or quest.subRewardType == WQT_REWARDTYPE_HONOR)); end 
			,function(quest, flags) return (flags["Gold"] and (quest.rewardType == WQT_REWARDTYPE_GOLD or quest.subRewardType == WQT_REWARDTYPE_GOLD) ); end 
			,function(quest, flags) return (flags["Currency"] and (quest.rewardType == WQT_REWARDTYPE_CURRENCY or quest.subRewardType == WQT_REWARDTYPE_CURRENCY)); end 
			,function(quest, flags) return (flags["Experience"] and quest.rewardType == WQT_REWARDTYPE_XP); end 
			,function(quest, flags) return (flags["None"] and quest.rewardType == WQT_REWARDTYPE_NONE); end
			}
	};

local WQT_ZONE_MAPCOORDS = {
		[1007] 	= { -- Legion
			[1015] = {["x"] = 0.33, ["y"] = 0.58} -- Azsuna
			,[1033] = {["x"] = 0.46, ["y"] = 0.45} -- Suramar
			,[1017] = {["x"] = 0.60, ["y"] = 0.33} -- Stormheim
			,[1024] = {["x"] = 0.46, ["y"] = 0.23} -- Highmountain
			,[1018] = {["x"] = 0.34, ["y"] = 0.33} -- Val'sharah
			,[1096] = {["x"] = 0.46, ["y"] = 0.84} -- Eye of Azshara
			,[1021] = {["x"] = 0.54, ["y"] = 0.68} -- Broken Shore
			,[1014] = {["x"] = 0.45, ["y"] = 0.64} -- Dalaran
		}
		
		,[13] 	= { --Kalimdor
			[261] 	= {["x"] = 0.42, ["y"] = 0.82} -- Silithus
			,[61]	= {["x"] = 0.5, ["y"] = 0.72} -- Thousand Needles
			,[720]	= {["x"] = 0.47, ["y"] = 0.91} -- Uldum
			,[161]	= {["x"] = 0.55, ["y"] = 0.84} -- Tanaris
			,[201]	= {["x"] = 0.5, ["y"] = 0.81} -- Ungoro
			,[121]	= {["x"] = 0.43, ["y"] = 0.7} -- Feralas
			,[141]	= {["x"] = 0.55, ["y"] = 0.67} -- Dustwallow
			,[607]	= {["x"] = 0.51, ["y"] = 0.67} -- S Barrens
			,[9]	= {["x"] = 0.47, ["y"] = 0.6} -- Mulgore
			,[101]	= {["x"] = 0.41, ["y"] = 0.57} -- Desolace
			,[81]	= {["x"] = 0.43, ["y"] = 0.46} -- Stonetalon
			,[11]	= {["x"] = 0.52, ["y"] = 0.5} -- N Barrens
			,[4]	= {["x"] = 0.58, ["y"] = 0.5} -- Durotar
			,[43]	= {["x"] = 0.49, ["y"] = 0.41} -- Stonetalon
			,[42]	= {["x"] = 0.46, ["y"] = 0.23} -- Dakshore
			,[181]	= {["x"] = 0.59, ["y"] = 0.37} -- Azshara
			,[606]	= {["x"] = 0.54, ["y"] = 0.32} -- Hyjal
			,[182]	= {["x"] = 0.49, ["y"] = 0.25} -- Felwood
			,[241]	= {["x"] = 0.53, ["y"] = 0.19} -- Moonglade
			,[281]	= {["x"] = 0.58, ["y"] = 0.23} -- Winterspring
			,[41]	= {["x"] = 0.42, ["y"] = 0.1} -- Teldrassil
			,[464]	= {["x"] = 0.33, ["y"] = 0.27} -- Azuremyst
			,[476]	= {["x"] = 0.3, ["y"] = 0.18} -- Bloodmyst
		}
		
		,[14]	= { -- Eastern Kingdoms
			[673]	= {["x"] = 0.47, ["y"] = 0.87} -- Cape of STV
			,[37]	= {["x"] = 0.47, ["y"] = 0.87} -- N STV
			,[19]	= {["x"] = 0.54, ["y"] = 0.89} -- Blasted Lands
			,[14]	= {["x"] = 0.54, ["y"] = 0.78} -- Swamp of Sorrow
			,[32]	= {["x"] = 0.49, ["y"] = 0.79} -- Deadwind
			,[34]	= {["x"] = 0.45, ["y"] = 0.8} -- Duskwood
			,[39]	= {["x"] = 0.4, ["y"] = 0.79} -- Westfall
			,[30]	= {["x"] = 0.47, ["y"] = 0.75} -- Elwynn
			,[36]	= {["x"] = 0.51, ["y"] = 0.75} -- Redridge
			,[29]	= {["x"] = 0.49, ["y"] = 0.7} -- Burning Steppes
			,[28]	= {["x"] = 0.47, ["y"] = 0.65} -- Searing Gorge
			,[17]	= {["x"] = 0.52, ["y"] = 0.65} -- Badlands
			,[27]	= {["x"] = 0.44, ["y"] = 0.61} -- Dun Morogh
			,[35]	= {["x"] = 0.52, ["y"] = 0.6} -- Loch Modan
			,[700]	= {["x"] = 0.56, ["y"] = 0.55} -- Twilight Highlands
			,[40]	= {["x"] = 0.5, ["y"] = 0.53} -- Wetlands
			,[16]	= {["x"] = 0.51, ["y"] = 0.46} -- Arathi Highlands
			,[26]	= {["x"] = 0.57, ["y"] = 0.4} -- Hinterlands
			,[24]	= {["x"] = 0.46, ["y"] = 0.4} -- Hillsbrad
			,[684]	= {["x"] = 0.4, ["y"] = 0.48} -- Ruins of Gilneas
			,[21]	= {["x"] = 0.41, ["y"] = 0.39} -- Silverpine
			,[20]	= {["x"] = 0.39, ["y"] = 0.32} -- Tirisfall
			,[22]	= {["x"] = 0.49, ["y"] = 0.31} -- W Plaugelands
			,[23]	= {["x"] = 0.54, ["y"] = 0.32} -- E Plaguelands
			,[463]	= {["x"] = 0.56, ["y"] = 0.23} -- Ghostlands
			,[462]	= {["x"] = 0.54, ["y"] = 0.18} -- Eversong
			,[499]	= {["x"] = 0.55, ["y"] = 0.05} -- Quel'Danas
		}
		
		,[466]	= { -- Outland
			[473]	= {["x"] = 0.74, ["y"] = 0.8} -- Shadowmoon Valley
			,[478]	= {["x"] = 0.45, ["y"] = 0.77} -- Terrokar
			,[477]	= {["x"] = 0.3, ["y"] = 0.65} -- Nagrand
			,[465]	= {["x"] = 0.52, ["y"] = 0.51} -- Hellfire
			,[466]	= {["x"] = 0.33, ["y"] = 0.47} -- Zangarmarsh
			,[475]	= {["x"] = 0.36, ["y"] = 0.23} -- Blade's Edge
			,[479]	= {["x"] = 0.57, ["y"] = 0.2} -- Netherstorm
		}
		
		,[485]	= { -- Northrend
			[486]	= {["x"] = 0.22, ["y"] = 0.59} -- Borean Tundra
			,[493]	= {["x"] = 0.25, ["y"] = 0.41} -- Sholazar Basin
			,[492]	= {["x"] = 0.41, ["y"] = 0.26} -- Icecrown
			,[488]	= {["x"] = 0.47, ["y"] = 0.55} -- Crystalsong
			,[495]	= {["x"] = 0.61, ["y"] = 0.21} -- Stormpeaks
			,[496]	= {["x"] = 0.77, ["y"] = 0.32} -- Zul'Drak
			,[490]	= {["x"] = 0.71, ["y"] = 0.53} -- Grizzly Hillsbrad
			,[491]	= {["x"] = 0.78, ["y"] = 0.74} -- Howling Fjord
		}
		
		,[862]	= { -- Pandaria
			[951]	= {["x"] = 0.9, ["y"] = 0.68} -- Timeless Isles
			,[806]	= {["x"] = 0.67, ["y"] = 0.52} -- Jade Forest
			,[857]	= {["x"] = 0.53, ["y"] = 0.75} -- Karasang
			,[807]	= {["x"] = 0.51, ["y"] = 0.65} -- Four Winds
			,[858]	= {["x"] = 0.35, ["y"] = 0.62} -- Dread Waste
			,[811]	= {["x"] = 0.5, ["y"] = 0.52} -- Eternal Blossom
			,[809]	= {["x"] = 0.45, ["y"] = 0.35} -- Kun-lai Summit
			,[929]	= {["x"] = 0.48, ["y"] = 0.05} -- Isle of Giants
			,[810]	= {["x"] = 0.32, ["y"] = 0.45} -- Townlong Steppes
			,[928]	= {["x"] = 0.2, ["y"] = 0.11} -- Isle of Thunder
		}
		
		,[962]	= { -- Draenor
			[950]	= {["x"] = 0.24, ["y"] = 0.49} -- Nagrand
			,[941]	= {["x"] = 0.34, ["y"] = 0.29} -- Frostridge
			,[949]	= {["x"] = 0.49, ["y"] = 0.21} -- Gorgrond
			,[946]	= {["x"] = 0.43, ["y"] = 0.56} -- Talador
			,[948]	= {["x"] = 0.46, ["y"] = 0.73} -- Spired of Arak
			,[947]	= {["x"] = 0.58, ["y"] = 0.67} -- Shadowmoon
			,[945]	= {["x"] = 0.58, ["y"] = 0.47} -- Tanaan Jungle
			,[978]	= {["x"] = 0.73, ["y"] = 0.43} -- Ashran
		}
		
		,[1184]	= {
			[1135]	= {["x"] = 0.8, ["y"] = 0.73}
		}
		
		,[-1]		= {} -- All of Azeroth
	}

-- Some magic to get collect all Azeroth quests on the continent map
local WQT_AZEROTH_COORDS = {
		[1007]	= {["x"] = 0.6, ["y"] = 0.41}
		,[13]	= {["x"] = 0.19, ["y"] = 0.5}
		,[14]	= {["x"] = 0.88, ["y"] = 0.56}
		,[485]	= {["x"] = 0.49, ["y"] = 0.13}
		,[862]	= {["x"] = 0.46, ["y"] = 0.92}
	}
for cId, cCoords in pairs(WQT_AZEROTH_COORDS) do
	for zId, zCoords in pairs(WQT_ZONE_MAPCOORDS[cId]) do
		WQT_ZONE_MAPCOORDS[-1][zId] = cCoords;
	end
	WQT_AZEROTH_COORDS[cId] = nil;
end
WQT_AZEROTH_COORDS = nil;

-- for zId, zCoords in pairs(WQT_ZONE_MAPCOORDS[1007]) do
	-- WQT_ZONE_MAPCOORDS[1184][zId] = {["x"] = -1, ["y"] = -1};
-- end
	
local WQT_SORT_OPTIONS = {[1] = _L["TIME"], [2] = _L["FACTION"], [3] = _L["TYPE"], [4] = _L["ZONE"], [5] = _L["NAME"], [6] = _L["REWARD"]}
	
local WQT_FACTION_ICONS = {
	 [1894] = "Interface/ICONS/INV_LegionCircle_Faction_Warden"
	,[1859] = "Interface/ICONS/INV_LegionCircle_Faction_NightFallen"
	,[1900] = "Interface/ICONS/INV_LegionCircle_Faction_CourtofFarnodis"
	,[1948] = "Interface/ICONS/INV_LegionCircle_Faction_Valarjar"
	,[1828] = "Interface/ICONS/INV_LegionCircle_Faction_HightmountainTribes"
	,[1883] = "Interface/ICONS/INV_LegionCircle_Faction_DreamWeavers"
	,[1090] = "Interface/ICONS/INV_LegionCircle_Faction_KirinTor"
	,[2045] = "Interface/Addons/WorldQuestTab/Images/Faction2045" -- Armies of Legionfall 7.2 Legionfall
	,[609] = "Interface/Addons/WorldQuestTab/Images/Faction609" -- Cenarion Circle - Call of the Scarab
	,[910] = "Interface/Addons/WorldQuestTab/Images/Faction910" -- Brood of Nozdormu - Call of the Scarab
	,[1515] = "Interface/Addons/WorldQuestTab/Images/Faction1515" -- Dreanor Arakkoa Outcasts
	,[1681] = "Interface/Addons/WorldQuestTab/Images/Faction1681" -- Dreanor Vol'jin's Spear
	,[1682] = "Interface/Addons/WorldQuestTab/Images/Faction1682" -- Dreanor Wrynn's Vanguard
	,[1731] = "Interface/Addons/WorldQuestTab/Images/Faction1731" -- Dreanor Council of Exarchs
	,[1445] = "Interface/Addons/WorldQuestTab/Images/Faction1445" -- Draenor Frostwolf Orcs
}
	
local WQT_DEFAULTS = {
	global = {	
		version = "";
		sortBy = 1;
		defaultTab = false;
		showTypeIcon = true;
		showFactionIcon = true;
		saveFilters = false;
		filterPoI = false;
		bigPoI = false;
		disablePoI = false;
		showPinReward = true;
		showPinRing = true;
		showPinTime = true;
		funQuests = true;
		emissaryOnly = false;
		useTomTom = true;
		preciseFilter = true;
		filters = {
				[1] = {["name"] = _L["FACTION"]
				, ["flags"] = {[GetFactionInfoByID(1859)] = false, [GetFactionInfoByID(1894)] = false, [GetFactionInfoByID(1828)] = false, [GetFactionInfoByID(1883)] = false
								, [GetFactionInfoByID(1948)] = false, [GetFactionInfoByID(1900)] = false, [GetFactionInfoByID(1090)] = false, [GetFactionInfoByID(2045)] = false, [_L["OTHER_FACTION"]] = false, [_L["NO_FACTION"]] = false}}
				,[2] = {["name"] = _L["TYPE"]
						, ["flags"] = {["Default"] = false, ["Elite"] = false, ["PvP"] = false, ["Petbattle"] = false, ["Dungeon"] = false, ["Raid"] = false, ["Profession"] = false, ["Invasion"] = false}}--, ["Emissary"] = false}}
				,[3] = {["name"] = _L["REWARD"]
						, ["flags"] = {["Item"] = false, ["Armor"] = false, ["Gold"] = false, ["Currency"] = false, ["Artifact"] = false, ["Relic"] = false, ["None"] = false, ["Experience"] = false, ["Honor"] = false}}
			}
	}
}
	
------------------------------------------------------------
	
local _questList = {};
local _questPool = {};
local _questDisplayList = {};
local _filterOrders = {}

------------------------------------------------------------

function WQT:ScrollFrameSetEnabled(enabled)

	WQT_WorldQuestFrame:EnableMouse(enabled)
	WQT_QuestScrollFrame:EnableMouse(enabled);
	WQT_QuestScrollFrame:EnableMouseWheel(enabled);
	local buttons = WQT_QuestScrollFrame.buttons;
	for k, button in ipairs(buttons) do
		button:EnableMouse(enabled);
	end
end

function WQT_Tab_Onclick(self, button)
	if(button == "RightButton") then
		WQT:UpdateQuestList();
	end

	id = self and self:GetID() or nil;
	if WQT_WorldQuestFrame.selectedTab ~= self then
		Lib_HideDropDownMenu(1);
		--PlaySound("igMainMenuOptionCheckBoxOn");
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); -- 7.3
	end
	
	WQT_WorldQuestFrame.selectedTab = self;
	
	WQT_TabNormal:SetAlpha(1);
	WQT_TabWorld:SetAlpha(1);
	-- because hiding stuff in combat doesn't work
	if not InCombatLockdown() then
		WQT_TabNormal:SetFrameLevel(WQT_TabNormal:GetParent():GetFrameLevel()+(self == WQT_TabNormal and 2 or 1));
		WQT_TabWorld:SetFrameLevel(WQT_TabWorld:GetParent():GetFrameLevel()+(self == WQT_TabWorld and 2 or 1));
	 
		WQT_WorldQuestFrameFilterButton:SetFrameLevel(WQT_WorldQuestFrameFilterButton:GetParent():GetFrameLevel());
		WQT_WorldQuestFrameSortButton:SetFrameLevel(WQT_WorldQuestFrameSortButton:GetParent():GetFrameLevel());
		
		WQT_WorldQuestFrame:SetFrameLevel(0);
	end

	if (not QuestScrollFrame.Contents:IsShown() and not QuestMapFrame.DetailsFrame:IsShown()) or id == 1 then
		WQT_WorldQuestFrame:SetAlpha(0);
		WQT_TabNormal.Highlight:Show();
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		ShowUIPanel(QuestScrollFrame);
		if not InCombatLockdown() then
			WQT:ScrollFrameSetEnabled(false)
		end
	elseif id == 2 then
		WQT_TabWorld.Highlight:Show();
		WQT_WorldQuestFrame:SetAlpha(1);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		HideUIPanel(QuestScrollFrame);
		if not InCombatLockdown() then
			WQT_WorldQuestFrame:SetFrameLevel(WQT_WorldQuestFrame:GetParent():GetFrameLevel()+3);
			WQT:ScrollFrameSetEnabled(true)
		end
	elseif id == 3 then
		WQT_WorldQuestFrame:SetAlpha(0);
		WQT_TabNormal:SetAlpha(0);
		WQT_TabWorld:SetAlpha(0);
		HideUIPanel(QuestScrollFrame);
		WQT_TabNormal:SetFrameLevel(WQT_TabNormal:GetParent():GetFrameLevel()-1);
		WQT_TabWorld:SetFrameLevel(WQT_TabWorld:GetParent():GetFrameLevel()-1);
		WQT_WorldQuestFrameFilterButton:SetFrameLevel(0);
		WQT_WorldQuestFrameSortButton:SetFrameLevel(0);
	end
end

function WQT_Quest_OnClick(self, button)
	--PlaySound("igMainMenuOptionCheckBoxOn");
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); -- 7.3
	if not self.questId or self.questId== -1 then return end
	if IsShiftKeyDown() then
		if IsWorldQuestHardWatched(self.questId) or (IsWorldQuestWatched(self.questId) and GetSuperTrackedQuestID() == self.questId) then
			BonusObjectiveTracker_UntrackWorldQuest(self.questId);
		else
			BonusObjectiveTracker_TrackWorldQuest(self.questId, true);
		end
	elseif button == "LeftButton" then
		if IsWorldQuestHardWatched(self.questId) then
			SetSuperTrackedQuestID(self.questId);
		else
			BonusObjectiveTracker_TrackWorldQuest(self.questId);
		end
		SetMapByID(self.zoneId or 1007);
	elseif button == "RightButton" then
		if WQT_TrackDropDown:GetParent() ~= self then
			 -- If the dropdown is linked to another button, we must move and close it first
			WQT_TrackDropDown:SetParent(self);
			Lib_HideDropDownMenu(1);
		end
		Lib_ToggleDropDownMenu(1, nil, WQT_TrackDropDown, "cursor", -10, -10);
	end
	
	WQT:DisplayQuestList();
end

function WQT_Quest_OnLeave(self)
	HideUIPanel(self.highlight);
	WorldMapTooltip:Hide();
	WQT_PoISelectIndicator:Hide();
	WQT_MapZoneHightlight:Hide();
	if (self.resetLabel) then
		WorldMapFrameAreaLabel:SetText("");
		self.resetLabel = false;
	end
end

function WQT_Quest_OnEnter(self)
	
	ShowUIPanel(self.highlight);
	WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT");

	-- Item comparison
	if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
		GameTooltip_ShowCompareItem(WorldMapTooltip.ItemTooltip.Tooltip, WorldMapTooltip.BackdropFrame);
	else
		for i, tooltip in ipairs(WorldMapTooltip.ItemTooltip.Tooltip.shoppingTooltips) do
			tooltip:Hide();
		end
	end
	
	-- Put the ping on the relevant map pin
	local pin = WorldMap_GetActiveTaskPOIForQuestID(self.questId);
	if pin then
		WQT_PoISelectIndicator:SetParent(pin);
		WQT_PoISelectIndicator:ClearAllPoints();
		WQT_PoISelectIndicator:SetPoint("CENTER", pin, 0, -1);
		WQT_PoISelectIndicator:SetFrameLevel(pin:GetFrameLevel()+1);
		WQT_PoISelectIndicator:Show();
	end
	
	-- local button = nil;
	-- for i = 1, NUM_WORLDMAP_TASK_POIS do
		-- button = _G["WorldMapFrameTaskPOI"..i];
		-- if button.questID == self.questId then
			-- WQT_PoISelectIndicator:SetParent(button);
			-- WQT_PoISelectIndicator:ClearAllPoints();
			-- WQT_PoISelectIndicator:SetPoint("CENTER", button, 0, -1);
			-- WQT_PoISelectIndicator:SetFrameLevel(button:GetFrameLevel()+2);
			-- WQT_PoISelectIndicator:Show();
			-- break;
		-- end
	-- end
	
	-- April fools
	if WQT.versionCheck and self.questId < 0 then
		WorldMapTooltip:SetText(("%s -> %s -> %s"):format(FILTER, _L["SETTINGS"], "Fun Quests"));
		return;
	end
	
	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if ( not HaveQuestData(self.questId) ) then
		WorldMapTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		WorldMapTooltip:Show();
		return;
	end
	
	-- self.reward.icon:SetTexture(self.info.rewardTexture);

	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(self.questId);
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(self.questId);
	local color = WORLD_QUEST_QUALITY_COLORS[rarity or 1];
	
	WorldMapTooltip:SetText(title, color.r, color.g, color.b);
	
	if ( factionID ) then
		local factionName = GetFactionInfoByID(factionID);
		if ( factionName ) then
			if (capped) then
				WorldMapTooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
			else
				WorldMapTooltip:AddLine(factionName);
			end
		end
	end

	WorldMap_AddQuestTimeToTooltip(self.questId);

	for objectiveIndex = 1, self.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(self.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			WorldMapTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(self.questId);
	if ( percent ) then
		GameTooltip_InsertFrame(WorldMapTooltip, WorldMapTaskTooltipStatusBar);
		WorldMapTaskTooltipStatusBar.Bar:SetValue(percent);
		WorldMapTaskTooltipStatusBar.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
	end

	if self.info.rewardTexture ~= "" then
		if self.info.rewardTexture == WQT_QUESTIONMARK then
			WorldMapTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		else
			GameTooltip_AddQuestRewardsToTooltip(WorldMapTooltip, self.questId);
		end
	end

	-- Add debug lines
	-- for k, v in pairs(self.info)do
		-- WorldMapTooltip:AddDoubleLine(k, tostring(v));
	-- end
	
	WorldMapTooltip:Show();

	-- If we are on a continent, we want to highlight the relevant zone
	WQT:ShowWorldmapHighlight(self, self.info.zoneId);
end

function WQT:ShowWorldmapHighlight(button, zoneId)
	local areaId = GetCurrentMapAreaID();

	if not WQT_ZONE_MAPCOORDS[areaId] or not WQT_ZONE_MAPCOORDS[areaId][zoneId] then return; end;

	local adjustedX, adjustedY = WQT_ZONE_MAPCOORDS[areaId][zoneId].x, WQT_ZONE_MAPCOORDS[areaId][zoneId].y;
	local width = WorldMapButton:GetWidth();
	local height = WorldMapButton:GetHeight();
	
	-- Now we cheat by acting like we moved our mouse over the relevant zone
	local name, fileName, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY, minLevel, maxLevel, petMinLevel, petMaxLevel = UpdateMapHighlight( adjustedX, adjustedY );
	if ( fileName ) then
		WQT_MapZoneHightlight.texture:SetTexCoord(0, texPercentageX, 0, texPercentageY);
		WQT_MapZoneHightlight.texture:SetTexture("Interface\\WorldMap\\"..fileName.."\\"..fileName.."Highlight");
		textureX = textureX * width;
		textureY = textureY * height;
		scrollChildX = scrollChildX * width;
		scrollChildY = -scrollChildY * height;
		if ( (textureX > 0) and (textureY > 0) ) then
			WQT_MapZoneHightlight:SetWidth(textureX);
			WQT_MapZoneHightlight:SetHeight(textureY);
			WQT_MapZoneHightlight:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", scrollChildX, scrollChildY);
			WQT_MapZoneHightlight:Show();
			WorldMapFrameAreaLabel:SetVertexColor(WQT_COLOR_AREA_NAME:GetRGB());
			WorldMapFrameAreaLabel:SetText(name);
		end
	end
	
	button.resetLabel = true;
end

local function GetAbreviatedNumber(number)
	if type(number) ~= "number" then return "NaN" end;
	if (number >= 1000 and number < 10000) then
		local rest = number - floor(number/1000)*1000
		if rest < 100 then
			return floor(number / 1000) .. "k";
		else
			return floor(number / 100)/10 .. "k";
		end
	elseif (number >= 10000 and number < 1000000) then
		return floor(number / 1000) .. "k";
	elseif (number >= 1000000 and number < 10000000) then
		local rest = number - floor(number/1000000)*1000000
		if rest < 100000 then
			return floor(number / 1000000) .. "m";
		else
			return floor(number / 100000)/10 .. "m";
		end
	elseif (number >= 10000000 and number < 1000000000) then
		return floor(number / 1000000) .. "m";
	elseif (number >= 1000000000 and number < 10000000000) then
		local rest = number - floor(number/1000000000)*1000000000
		if rest < 100000000 then
			return floor(number / 1000000000) .. "b";
		else
			return floor(number / 100000000)/10 .. "b";
		end
	elseif (number >= 10000000) then
		return floor(number / 1000000000) .. "b";
	end
	return number 
end

local function GetQuestFromList(list, id)

	for k, quest in pairs(list) do
		if quest.id == id then return quest; end
	end
	return nil;
end

local function IsArtifactItem(numItems, itemId)
	-- Because spanish sometimes have a different spell name, and items like petbattle bandages are also 0-8
	local _, itemLink, _, itemLevel, itemMinLevel, _, _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfo(itemId);
	return numItems == 1 and itemLevel == 110 and itemClassID == 0 and itemSubClassID == 8;
end

local function IsRelicItem(itemId)
	local itemClassID, itemSubClassID = select(12, GetItemInfo(itemId));
	return (itemClassID == 3 and itemSubClassID == 11);
end

local function ShowOverlayMessage(message)
	local scrollFrame = WQT_QuestScrollFrame;
	local buttons = scrollFrame.buttons;
	message = message or "";
	
	ShowUIPanel(WQT_WorldQuestFrame.blocker);
	WQT_WorldQuestFrame.blocker.text:SetText(message);
	WQT_QuestScrollFrame:EnableMouseWheel(false);
	
	WQT_WorldQuestFrameFilterButton:Disable();
	WQT_WorldQuestFrameSortButton:Disable();
	
	for k, button in ipairs(buttons) do
		button:Disable();
	end
end

local function HideOverlayMessage()
	local scrollFrame = WQT_QuestScrollFrame;
	local buttons = scrollFrame.buttons;
	HideUIPanel(WQT_WorldQuestFrame.blocker);
	WQT_QuestScrollFrame:EnableMouseWheel(true);

	WQT_WorldQuestFrameFilterButton:Enable();
	WQT_WorldQuestFrameSortButton:Enable();
	
	for k, button in ipairs(buttons) do
		button:Enable();
	end
end

local function GetOrCreateQuestInfo()
	for k, info in ipairs(_questPool) do
		if info.id == -1 then
			return info;
		end
	end

	local info = {["id"] = -1, ["title"] = "z", ["timeString"] = "", ["timeStringShort"] = "", ["color"] = WQT_WHITE_FONT_COLOR, ["minutes"] = 0
					, ["faction"] = "", ["type"] = 0, ["rarity"] = 0, ["isElite"] = false, ["tradeskill"] = 0
					, ["numObjectives"] = 0, ["numItems"] = 0, ["rewardTexture"] = "", ["rewardQuality"] = 1
					, ["rewardType"] = 0, ["isCriteria"] = false, ["ringColor"] = WQT_COLOR_MISSING, ["zoneId"] = -1}; 
					
	table.insert(_questPool, info);
	
	return info
end

local function GetSortedFilterOrder(filterId)
	local filter = WQT.settings.filters[filterId];
	local tbl = {};
	for k, v in pairs(filter.flags) do
		table.insert(tbl, k);
	end
	table.sort(tbl, function(a, b) 
				if(a == _L["REWARD_NONE"] or b == _L["REWARD_NONE"])then
					return a ~= _L["REWARD_NONE"] and b == _L["REWARD_NONE"];
				end
				if(a == _L["NO_FACTION"] or b == _L["NO_FACTION"])then
					return a ~= _L["NO_FACTION"] and b == _L["NO_FACTION"];
				end
				if(a == _L["OTHER_FACTION"] or b == _L["OTHER_FACTION"])then
					return a ~= _L["OTHER_FACTION"] and b == _L["OTHER_FACTION"];
				end
				return a < b; 
			end)
	return tbl;
end

local function Sort_questList(list)
	table.sort(list, function(a, b) 
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
	end);
end

local function Sort_questListByZone(list)
	table.sort(list, function(a, b) 
		if a.zoneId == b.zoneId then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
		end
		return (GetMapNameByID(a.zoneId) or "zz") < (GetMapNameByID(b.zoneId) or "zz");
	end);
end

local function Sort_questListByFaction(list)
	table.sort(list, function(a, b) 
		if a.faction == b.faction then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
		end
		return a.faction < b.faction;
	end);
end

local function Sort_questListByType(list)
	table.sort(list, function(a, b) 
		local aIsCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(a.id);
		local bIsCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(b.id);
		if aIsCriteria == bIsCriteria then
			if a.type == b.type then
				if a.rarity == b.rarity then
					if (a.isElite and b.isElite) or (not a.isElite and not b.isElite) then
						-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
						if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
							return a.title < b.title;
						end	
						return a.minutes < b.minutes;
					end
					return b.isElite;
				end
				return a.rarity < b.rarity;
			end
			return a.type < b.type;
		end
		return aIsCriteria and not bIsCriteria;
	end);
end

local function Sort_questListByName(list)
	table.sort(list, function(a, b) 
		return a.title < b.title;
	end);
end

local function Sort_questListByReward(list)
	table.sort(list, function(a, b) 
		if a.rewardType == b.rewardType then
			if not a.rewardQuality or not b.rewardQuality or a.rewardQuality == b.rewardQuality then
				if not a.numItems or not b.numItems or a.numItems == b.numItems then
					-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
					if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
						return a.title < b.title;
					end	
					return a.minutes < b.minutes;
				
				end
				return a.numItems > b.numItems;
			end
			return a.rewardQuality > b.rewardQuality;
		elseif a.rewardType == 0 or b.rewardType == 0 then
			return a.rewardType > b.rewardType;
		end
		return a.rewardType < b.rewardType;
	end);
end

local function GetQuestTimeString(questId)
	local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questId);
	local timeString = "";
	local timeStringShort = "";
	local color = WQT_WHITE_FONT_COLOR;
	if ( timeLeftMinutes ) then
		if ( timeLeftMinutes <= WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			-- Grace period, show the actual time left
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(timeLeftMinutes * 60);
		elseif timeLeftMinutes <= 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = SecondsToTime((timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) * 60);
			color = WQT_ORANGE_FONT_COLOR;
		elseif timeLeftMinutes < 24 * 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = D_HOURS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 60);
			color = WQT_GREEN_FONT_COLOR
		else
			timeString = D_DAYS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 1440);
			color = WQT_BLUE_FONT_COLOR;
		end
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	-- Attempt Russian
	if t and not str then
		str = string.match(timeString, ' (.[\128-\191]*)');
	end
	if t and str then
		timeStringShort = t..str;
	end

	return timeLeftMinutes, timeString, color, timeStringShort;
end

function WQT:SetQuestReward(info)

	local _, texture, numItems, quality, rewardType, color, rewardId, itemId = nil, nil, 0, 1, 0, WQT_COLOR_MISSING, 0, 0;
	
	if GetNumQuestLogRewards(info.id) > 0 then
		_, texture, numItems, quality, _, itemId = GetQuestLogRewardInfo(1, info.id);
		
		if itemId and IsArtifactItem(numItems, itemId) then -- Artifact
			local text = GetSpellDescription(select(3, GetItemSpell(itemId)));
			numItems = tonumber(string.match(text:gsub("[%p| ]", ""), '%d+'));
			if (text:find(THIRD_NUMBER)) then -- Billion just in case
				local int, dec=text:match("(%d+)%.?%,?(%d*)");
				int = tonumber(int .. dec); 
				numItems = int/(10^dec:len()) * 1000000000;
			elseif (text:find(SECOND_NUMBER)) then -- Million
				local int, dec = text:match("(%d+)%.?%,?(%d*)");
				int = tonumber(int .. dec); 
				numItems = int/(10^dec:len()) * 1000000;
			end
			rewardType = WQT_REWARDTYPE_ARTIFACT;
			color = WQT_COLOR_ARTIFACT;
		elseif itemId and select(9, GetItemInfo(itemId)) ~= "" then -- Gear
			rewardType = WQT_REWARDTYPE_ARMOR;
			color = WQT_COLOR_ARMOR;
		elseif itemId and IsRelicItem(itemId) then -- Relic
			local _, link = GetItemInfo(itemId);
			for k, v in pairs(GetItemStats(link)) do
				if (k == "RELIC_ITEM_LEVEL_INCREASE") then
					numItems = v;
					break;
				end
			end
			rewardType = WQT_REWARDTYPE_RELIC;	
			color = WQT_COLOR_RELIC;
		else	-- Normal items
			rewardType = WQT_REWARDTYPE_ITEM;
			color = WQT_COLOR_ITEM;
		end
	elseif GetQuestLogRewardHonor(info.id) > 0 then
		numItems = GetQuestLogRewardHonor(info.id);
		texture = WQT_HONOR;
		color = WQT_COLOR_HONOR;
		rewardType = WQT_REWARDTYPE_HONOR;
	elseif GetQuestLogRewardMoney(info.id) > 0 then
		numItems = floor(abs(GetQuestLogRewardMoney(info.id) / 10000))
		texture = "Interface/ICONS/INV_Misc_Coin_01";
		rewardType = WQT_REWARDTYPE_GOLD;
		color = WQT_COLOR_GOLD;
	elseif GetNumQuestLogRewardCurrencies(info.id) > 0 then
		_, texture, numItems, rewardId = GetQuestLogRewardCurrencyInfo(1, info.id)
		if (GetNumQuestLogRewardCurrencies(info.id) > 1 and rewardId == 1342 or rewardId == 1226) then
			_, texture, numItems, rewardId = GetQuestLogRewardCurrencyInfo(2, info.id)
		end
		rewardType = WQT_REWARDTYPE_CURRENCY;
		color = WQT_COLOR_CURRENCY;
	elseif haveData and GetQuestLogRewardXP(info.id) > 0 then
		numItems = GetQuestLogRewardXP(info.id);
		texture = WQT_EXPERIENCE;
		color = WQT_COLOR_ITEM;
		rewardType = WQT_REWARDTYPE_XP;
	elseif GetNumQuestLogRewards(info.id) == 0 then
		texture = "";
		color = WQT_COLOR_ITEM;
		rewardType = WQT_REWARDTYPE_NONE;
	end
	
	info.rewardQuality = quality or 1;
	info.rewardTexture = texture or WQT_QUESTIONMARK;
	info.numItems = numItems or 0;
	info.rewardType = rewardType or 0;
	info.ringColor = color;
end

function WQT:SetSubReward(info) 
	local subType = nil;
	if info.rewardType ~= WQT_REWARDTYPE_CURRENCY and GetNumQuestLogRewardCurrencies(info.id) > 0 then
		subType = WQT_REWARDTYPE_CURRENCY;
	elseif info.rewardType ~= WQT_REWARDTYPE_HONOR and GetQuestLogRewardHonor(info.id) > 0 then
		subType = WQT_REWARDTYPE_HONOR;
	elseif info.rewardType ~= WQT_REWARDTYPE_GOLD and GetQuestLogRewardMoney(info.id) > 0 then
		subType = WQT_REWARDTYPE_GOLD;
	end
	info.subRewardType = subType;
end

local function AddQuestToList(list, qInfo, zoneId)
	local haveData = HaveQuestRewardData(qInfo.questId);
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(qInfo.questId);
	local minutes, timeString, color, timeStringShort = GetQuestTimeString(qInfo.questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(qInfo.questId);
	local faction = factionId and GetFactionInfoByID(factionId) or _L["NO_FACTION"];
	local info = GetOrCreateQuestInfo();
	
	info.id = qInfo.questId;
	info.mapX = qInfo.x;
	info.mapY = qInfo.y;
	info.mapF = qInfo.floor;
	info.title = title;
	info.timeString = timeString;
	info.timeStringShort = timeStringShort;
	info.color = color;
	info.minutes = minutes;
	info.faction = faction;
	info.factionId = factionId;
	info.type = worldQuestType or -1;
	info.rarity = rarity;
	info.isElite = isElite;
	info.zoneId = zoneId;
	info.tradeskill = tradeskillLineIndex;
	info.numObjectives = qInfo.numObjectives;
	info.passedFilter = true;
	info.isCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(qInfo.questId);
	WQT:SetQuestReward(info);
	-- If the quest as a second reward e.g. Mark of Honor + Honor points
	WQT:SetSubReward(info);
	
	if (list and not (info.type == -1 and info.numItems == 0)) then
		table.insert(list, info)
	end

	if not haveData then
		C_TaskQuest.RequestPreloadRewardData(qInfo.questId);
		return nil;
	end;

	return info;
end

local function DisplayQuestType(frame, questInfo)
	local inProgress = false;
	local isCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(questInfo.id);
	local questType, rarity, isElite, tradeskillLineIndex = questInfo.type, questInfo.rarity, questInfo.isElite, questInfo.tradeskill
	
	frame:Show();
	frame:SetWidth(frame:GetHeight());
	frame.texture:Show();
	frame.texture:Show();
	
	if isElite then
		frame.elite:Show();
	else
		frame.elite:Hide();
	end
	
	if not rarity or rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		frame.bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		frame.bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		frame.bg:SetSize(28, 28);
	elseif rarity == LE_WORLD_QUEST_QUALITY_RARE then
		frame.bg:SetAtlas("worldquest-questmarker-rare");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
	elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
		frame.bg:SetAtlas("worldquest-questmarker-epic");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
	end
	
	local tradeskillLineID = tradeskillLineIndex and select(7, GetProfessionInfo(tradeskillLineIndex));
	if ( questType == LE_QUEST_TAG_TYPE_PVP ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-pvp-ffa", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PET_BATTLE ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-petbattle", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PROFESSION and WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID] ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas(WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID], true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_DUNGEON ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-dungeon", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_RAID ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-raid", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_INVASION ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-burninglegion", true);
		end
	else
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-questmarker-questbang");
			frame.texture:SetSize(6, 15);
		end
	end
	
	if ( isCriteria ) then
		if ( isElite ) then
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-dragon-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, -1);
		else
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, 0);
		end
		frame.criteriaGlow:Show();
	else
		frame.criteriaGlow:Hide();
	end
end

function WQT:IsFiltering()
	if WQT.settings.emissaryOnly then return true; end
	for k, category in pairs(WQT.settings.filters)do
		for k2, flag in pairs(category.flags) do
			if flag then return true; end
		end
	end
	return false;
end

function WQT:isUsingFilterNr(id)
	-- TODO see if we can change this to only check once every time we go through all quests
	if not WQT.settings.filters[id] then return false end
	local flags = WQT.settings.filters[id].flags;
	for k, flag in pairs(flags) do
		if flag then return true; end
	end
	return false;
end

function WQT:PassesAllFilters(quest)
	--if quest.minutes == 0 then return true; end
	if quest.id < 0 then return true; end
	
	if not WQT:IsFiltering() then return true; end

	if WQT.settings.emissaryOnly then 
		return WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(quest.id);
	end
	
	local precise = WQT.settings.preciseFilter;
	local passed = true;
	
	if precise then
		if WQT:isUsingFilterNr(1) then 
			passed = WQT:PassesFactionFilter(quest) and true or false; 
		end
		if (WQT:isUsingFilterNr(2) and passed) then
			passed = WQT:PassesFlagId(2, quest) and true or false;
		end
		if (WQT:isUsingFilterNr(3) and passed) then
			passed = WQT:PassesFlagId(3, quest) and true or false;
		end
	else
		if WQT:isUsingFilterNr(1) and WQT:PassesFactionFilter(quest) then return true; end
		if WQT:isUsingFilterNr(2) and WQT:PassesFlagId(2, quest) then return true; end
		if WQT:isUsingFilterNr(3) and WQT:PassesFlagId(3, quest) then return true; end
	end
	
	return precise and passed or false;
end

function WQT:PassesFactionFilter(quest)
	-- Factions (1)
	local flags = WQT.settings.filters[1].flags
	if flags[quest.faction] ~= nil and flags[quest.faction] then return true; end
	if quest.faction ~= _L["NO_FACTION"] and flags[quest.faction] == nil and flags[_L["OTHER_FACTION"]] then return true; end
	return false;
end

function WQT:PassesFlagId(flagId ,quest)
	local flags = WQT.settings.filters[flagId].flags

	for k, func in ipairs(WQT_FILTER_FUNCTIONS[flagId]) do
		if(func(quest, flags)) then return true; end
	end
	return false;
end

function WQT:UpdateFilterDisplay()
	local isFiltering = WQT:IsFiltering();
	WQT_WorldQuestFrame.filterBar.clearButton:SetShown(isFiltering);
	-- If we're not filtering, we 'hide' everything
	if not isFiltering then
		WQT_WorldQuestFrame.filterBar.text:SetText(""); 
		WQT_WorldQuestFrame.filterBar:SetHeight(0.1);
		return;
	end

	local filterList = "";
	local haveLabels = false;
	-- If we are filtering, 'show' things
	WQT_WorldQuestFrame.filterBar:SetHeight(20);
	-- Emissary has priority
	if (WQT.settings.emissaryOnly) then
		filterList = _L["TYPE_EMISSARY"];	
	else
		for kO, option in pairs(WQT.settings.filters) do
			haveLabels = (WQT_TYPEFLAG_LABELS[kO] ~= nil);
			for kF, flag in pairs(option.flags) do
				if flag then
					local label = haveLabels and WQT_TYPEFLAG_LABELS[kO][kF] or kF;
					filterList = filterList == "" and label or string.format("%s, %s", filterList, label);
				end
			end
		end
	end

	WQT_WorldQuestFrame.filterBar.text:SetText(_L["FILTER"]:format(filterList)); 
end

function WQT:UpdatePin(PoI, quest, flightPinNr)
	local bw = PoI:GetWidth();
	local bh = PoI:GetHeight();

	if (not PoI.WQTOverlay) then
		local pinNr = flightPinNr or string.match(PoI:GetName(), "(%d+)");
		PoI.WQTOverlay = CreateFrame("FRAME", "WQT_Overlay" .. pinNr, PoI, "WQT_PinTemplate");
		--PoI.WQTOverlay:SetFlattensRenderLayers(true);
		PoI.WQTOverlay:SetPoint("TOPLEFT");
		PoI.WQTOverlay:SetPoint("BOTTOMRIGHT");
		PoI.WQTOverlay:Show();
	end
	
	-- Ring stuff
	if (WQT.settings.showPinRing) then
		PoI.WQTOverlay.ring:SetVertexColor(quest.ringColor:GetRGB());
	else
		PoI.WQTOverlay.ring:SetVertexColor(WQT_COLOR_CURRENCY:GetRGB());
	end
	PoI.WQTOverlay.ring:SetAlpha((WQT.settings.showPinReward or WQT.settings.showPinRing) and 1 or 0);
	
	-- Icon stuff
	PoI.WQTOverlay.icon:SetAlpha((WQT.settings.showPinReward and quest.rewardTexture ~= "") and 1 or 0);
	SetPortraitToTexture(PoI.WQTOverlay.icon, quest.rewardTexture);
	
	-- Time
	PoI.WQTOverlay.time:SetAlpha((WQT.settings.showPinTime and quest.timeStringShort ~= "")and 1 or 0);
	PoI.WQTOverlay.timeBG:SetAlpha((WQT.settings.showPinTime and quest.timeStringShort ~= "") and 0.65 or 0);
	PoI.WQTOverlay.time:SetFontObject(flightPinNr and "WQT_NumberFontOutlineBig" or "WQT_NumberFontOutline");
	PoI.WQTOverlay.time:SetHeight(flightPinNr and 32 or 18);
	if(WQT.settings.showPinTime) then
		PoI.WQTOverlay.time:SetText(quest.timeStringShort)
		PoI.WQTOverlay.time:SetVertexColor(quest.color.r, quest.color.g, quest.color.b) 
	end
	
	-- Glow
	PoI.WQTOverlay.glow:SetAlpha(WQT.settings.showPinReward and (quest.isCriteria and (quest.isElite and 0.65 or 1) or 0) or 0);
	if (not flightPinNr and quest.isElite) then
		PoI.WQTOverlay.glow:SetWidth(bw+36);
		PoI.WQTOverlay.glow:SetHeight(bh+36);
		PoI.WQTOverlay.glow:SetTexture("Interface/QUESTFRAME/WorldQuest")
		PoI.WQTOverlay.glow:SetTexCoord(0, 0.09765625, 0.546875, 0.953125)
	else
		PoI.WQTOverlay.glow:SetWidth(bw+27);
		PoI.WQTOverlay.glow:SetHeight(bh+27);
		PoI.WQTOverlay.glow:SetTexture("Interface/QUESTFRAME/WorldQuest")
		PoI.WQTOverlay.glow:SetTexCoord(0.546875, 0.619140625, 0.6875, 0.9765625)
	end
end

function WQT:UpdateFlightMapPins()
	if WQT.settings.disablePoI then return; end
	local quest = nil;
	local questsById;
	local missingRewardData = false;
	local continentId = GetTaxiMapID();
	
	for id in pairs(WQT.FlightMapList) do
		WQT.FlightMapList[id].id = -1;
		WQT.FlightMapList[id] = nil;
	end
	
	for zoneId, data in pairs(WQT_ZONE_MAPCOORDS[continentId] or {}) do
		questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneId, continentId);
		if questsById and type(questsById) == "table" then
			for k2, info in ipairs(questsById) do
				quest = AddQuestToList(nil, info, zoneId);
				if quest then
					WQT.FlightMapList[quest.id] = quest;
					if WQT:IsFiltering() and not WQT:PassesAllFilters(quest) then
						quest.passedFilter = false;
					end
				else 
					missingRewardData = true;
				end
			end
		end
	end
	
	-- If nothing is missing, we can stop updating until we open the map the next time
	if not missingRewardData then
		WQT.UpdateFlightMap = false
	end
	
	quest = nil;
	for k, PoI in pairs(WQT.FlightmapPins.activePins) do
		quest = WQT.FlightMapList[k]
		if (quest) then
			WQT:UpdatePin(PoI, quest, k)
			if (quest.isElite) then
				PoI.WQTOverlay.glow:SetWidth(PoI:GetWidth()+61);
				PoI.WQTOverlay.glow:SetHeight(PoI:GetHeight()+61);
				PoI.WQTOverlay.glow:SetTexture("Interface/QUESTFRAME/WorldQuest")
				PoI.WQTOverlay.glow:SetTexCoord(0, 0.09765625, 0.546875, 0.953125)
			else
				PoI.WQTOverlay.glow:SetWidth(PoI:GetWidth()+50);
				PoI.WQTOverlay.glow:SetHeight(PoI:GetHeight()+50);
				PoI.WQTOverlay.glow:SetTexture("Interface/QUESTFRAME/WorldQuest")
				PoI.WQTOverlay.glow:SetTexCoord(0.546875, 0.619140625, 0.6875, 0.9765625)
			end
		end

		quest = nil;
	end
end

function WQT:CleanMapPins()
	local PoI;
	for i = 1, NUM_WORLDMAP_TASK_POIS do
		PoI = _G["WorldMapFrameTaskPOI"..i];
		if PoI.WQTOverlay then
			PoI.WQTOverlay:SetAlpha(0);
		end
	end
	
	if (WQT.FlightMapList) then
		for k, PoI in pairs(WQT.FlightmapPins.activePins) do
			if PoI.WQTOverlay then
				PoI.WQTOverlay:SetAlpha(0);
			end
		end
	end
end

function WQT:UpdateMapPoI()
	if WQT.settings.disablePoI then return; end
	if InCombatLockdown() then
		return;
	end
	local PoI, quest;
	
	WQT:UpdateQuestFilters();
	
	for i = 1, NUM_WORLDMAP_TASK_POIS do
		PoI = _G["WorldMapFrameTaskPOI"..i];
		quest = GetQuestFromList(_questList, PoI.questID);
		if (quest) then
			if (WQT.settings.showPinReward and WQT.settings.bigPoI) then
				PoI:SetWidth(25);
				PoI:SetHeight(25);
			end
			WQT:UpdatePin(PoI, quest);
			
			if (WQT.settings.filterPoI and not quest.passedFilter) then
				PoI:Hide();
			end
			
			if (PoI.WQTOverlay) then
				PoI.WQTOverlay:SetAlpha(1);
			end
		end
	end
end

function WQT:ApplySort()
	local list = _questList;
	local sortOption = Lib_UIDropDownMenu_GetSelectedValue(WQT_WorldQuestFrameSortButton);
	if sortOption == 2 then -- faction
		Sort_questListByFaction(list);
	elseif sortOption == 3 then -- type
		Sort_questListByType(list);
	elseif sortOption == 4 then -- zone
		Sort_questListByZone(list);
	elseif sortOption == 5 then -- name
		Sort_questListByName(list);
	elseif sortOption == 6 then -- reward
		Sort_questListByReward(list)
	else -- time or anything else
		Sort_questList(list)
	end
end

function WQT:UpdateQuestList()
	if (InCombatLockdown() or not WorldMapFrame:IsShown()) then return end
	
	local mapAreaID = GetCurrentMapAreaID();
	local list = _questList;
	local continentZones =WQT_ZONE_MAPCOORDS[mapAreaID];
	local quest = nil;
	local questsById = nil
	local missingRewardData = false;
	
	for id in pairs(list) do
		list[id].id = -1;
		list[id].rewardTexture = nil;
		list[id] = nil;
	end
	
	if continentZones then
		for zoneId, data in pairs(continentZones) do
			questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneId, mapAreaID);
			if questsById and type(questsById) == "table" then
				for k2, info in ipairs(questsById) do
					quest = AddQuestToList(list, info, zoneId);
					if not quest then 
						missingRewardData = true
					end;
				end
			end
		end
	else
		questsById = C_TaskQuest.GetQuestsForPlayerByMapID(mapAreaID);
		if questsById and type(questsById) == "table" then
			for k, info in ipairs(questsById) do
				quest = AddQuestToList(list, info, mapAreaID);
				if not quest then
					missingRewardData = true
				end;
			end
		end
	end
	
	-- If we were missing reward data, redo this function
	if missingRewardData and not addon.errorTimer then
		addon.errorTimer = C_Timer.NewTimer(0.5, function() addon.errorTimer = nil; WQT:UpdateQuestList() end);
	end
	
	WQT:UpdateQuestFilters();
	if WQT.versionCheck and #_questDisplayList > 0 and self.settings.funQuests then
		WQT:ImproveList();
	end

	WQT:ApplySort();
	WQT:DisplayQuestList();
end

function WQT:UpdateQuestFilters()
	for i=#_questDisplayList, 1, -1 do
		table.remove(_questDisplayList, i);
	end
	
	for k, quest in ipairs(_questList) do
		quest.passedFilter = WQT:PassesAllFilters(quest)
		if quest.passedFilter then
			table.insert(_questDisplayList, quest);
		end
	end
end

function WQT:DisplayQuestList(skipPins)
	if InCombatLockdown() or not WorldMapFrame:IsShown() or not WQT_WorldQuestFrame:IsShown() then return end

	local scrollFrame = WQT_QuestScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	if buttons == nil then return; end

	WQT:ApplySort();
	WQT:UpdateQuestFilters()
	local list = _questDisplayList;
	local r, g, b = 1, 1, 1;
	local continentZones = WQT_ZONE_MAPCOORDS[GetCurrentMapAreaID()];
	HideOverlayMessage();
	
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		button:Hide();
		button.reward.amount:Hide();
		button.trackedBorder:Hide();
		button.info = nil;
		if ( displayIndex <= #list) then
			local q = list[displayIndex];
			button:Show();
			button.title:SetText(q.title);
			button.time:SetTextColor(q.color.r, q.color.g, q.color.b, 1);
			button.time:SetText(q.timeString);
			button.extra:SetText(continentZones and GetMapNameByID(q.zoneId) or "");
			
			button.title:ClearAllPoints()
			button.title:SetPoint("RIGHT", button.reward, "LEFT", -5, 0);
			if WQT.settings.showFactionIcon then
				button.title:SetPoint("BOTTOMLEFT", button.faction, "RIGHT", 5, 1);
			elseif WQT.settings.showTypeIcon then
				button.title:SetPoint("BOTTOMLEFT", button.type, "RIGHT", 5, 1);
			else
				button.title:SetPoint("BOTTOMLEFT", button, "LEFT", 10, 0);
			end
			
			if WQT.settings.showFactionIcon then
				button.faction:Show();
				button.faction.icon:SetTexture(q.factionId and (WQT_FACTION_ICONS[q.factionId] or WQT_FACTIONUNKNOWN) or "");
				button.faction:SetWidth(button.faction:GetHeight());
			else
				button.faction:Hide();
				button.faction:SetWidth(0.1);
			end
			
			if WQT.settings.showTypeIcon then
				DisplayQuestType(button.type, q)
			else
				button.type:Hide()
				button.type:SetWidth(0.1);
			end
			
			-- display reward
			button.reward:Show();
			button.reward.icon:Show();
			r, g, b = GetItemQualityColor(q.rewardQuality);
			button.reward.iconBorder:SetVertexColor(r, g, b);
			button.reward:SetAlpha(1);
			if q.rewardTexture == "" then
				button.reward:SetAlpha(0);
			end
			button.reward.icon:SetTexture(q.rewardTexture);

			if q.numItems and q.numItems > 1 then
				button.reward.amount:SetText(GetAbreviatedNumber(q.numItems));
				r, g, b = 1, 1, 1;
				if q.rewardType == WQT_REWARDTYPE_RELIC then
					button.reward.amount:SetText("+" .. q.numItems);
				elseif q.rewardType == WQT_REWARDTYPE_ARTIFACT then
					r, g, b = GetItemQualityColor(2);
				end

				button.reward.amount:SetVertexColor(r, g, b);
				button.reward.amount:Show();
			end
			
			if GetSuperTrackedQuestID() == q.id or IsWorldQuestWatched(q.id) then
				button.trackedBorder:Show();
			end
			
			button.info = q;
			button.zoneId = q.zoneId;
			button.questId = q.id;
			button.numObjectives = q.numObjectives;
			
			if WQT.versionCheck and self.settings.funQuests then
				WQT:ImproveDisplay(button);
			end
		end
	end
	
	HybridScrollFrame_Update(WQT_QuestScrollFrame, #list * WQT_LISTITTEM_HEIGHT, scrollFrame:GetHeight());

	if (not skipPins and not continentZones and #list ~= 0) then	
		WQT:UpdateMapPoI()
	end
	
	WQT:UpdateFilterDisplay()
	
	if (IsAddOnLoaded("Aurora")) then
		WQT_WorldQuestFrame.Background:SetAlpha(0);
	elseif (#list == 0) then
		WQT_WorldQuestFrame.Background:SetAtlas("NoQuestsBackground", true);
	else
		WQT_WorldQuestFrame.Background:SetAtlas("QuestLogBackground", true);
	end
	
end

function WQT:SetAllFilterTo(id, value)
	local options = WQT.settings.filters[id].flags;
	for k, v in pairs(options) do
		options[k] = value;
	end
end

function WQT:InitFilter(self, level)

	local info = Lib_UIDropDownMenu_CreateInfo();
	info.keepShownOnClick = true;	
	
	if level == 1 then
		info.checked = 	nil;
		info.isNotRadio = nil;
		info.func =  nil;
		info.hasArrow = false;
		info.notCheckable = false;
		
		info.text = _L["TYPE_EMISSARY"];
		info.func = function(_, _, _, value)
				WQT.settings.emissaryOnly = value;
				WQT:DisplayQuestList();
				if (WQT.settings.filterPoI) then
					WorldMap_UpdateQuestBonusObjectives();
				end
			end
		info.checked = function() return WQT.settings.emissaryOnly end;
		Lib_UIDropDownMenu_AddButton(info, level);			
		
		info.hasArrow = true;
		info.notCheckable = true;
		
		for k, v in pairs(WQT.settings.filters) do
			info.text = v.name;
			info.value = k;
			Lib_UIDropDownMenu_AddButton(info, level)
		end
		
		info.text = _L["SETTINGS"];
		info.value = 0;
		Lib_UIDropDownMenu_AddButton(info, level)
	else --if level == 2 then
		info.hasArrow = false;
		info.isNotRadio = true;
		if LIB_UIDROPDOWNMENU_MENU_VALUE then
			if WQT.settings.filters[LIB_UIDROPDOWNMENU_MENU_VALUE] then
				
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(LIB_UIDROPDOWNMENU_MENU_VALUE, true);
								Lib_UIDropDownMenu_Refresh(self, 1, 2);
								WQT:DisplayQuestList();
							end
				Lib_UIDropDownMenu_AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(LIB_UIDROPDOWNMENU_MENU_VALUE, false);
								Lib_UIDropDownMenu_Refresh(self, 1, 2);
								WQT:DisplayQuestList();
							end
				Lib_UIDropDownMenu_AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[LIB_UIDROPDOWNMENU_MENU_VALUE].flags;
				local order = _filterOrders[LIB_UIDROPDOWNMENU_MENU_VALUE] 
				local haveLabels = (WQT_TYPEFLAG_LABELS[LIB_UIDROPDOWNMENU_MENU_VALUE] ~= nil);
				for k, flagKey in pairs(order) do
					info.text = haveLabels and WQT_TYPEFLAG_LABELS[LIB_UIDROPDOWNMENU_MENU_VALUE][flagKey] or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WorldMap_UpdateQuestBonusObjectives();
										end
										WQT:DisplayQuestList();
									end
					info.checked = function() return options[flagKey] end;
					Lib_UIDropDownMenu_AddButton(info, level);			
				end
				
			end
			if LIB_UIDROPDOWNMENU_MENU_VALUE == 0 then
				info.notCheckable = false;
				info.tooltipWhileDisabled = true;
				info.tooltipOnButton = true;
				
				info.text = _L["DEFAULT_TAB"];
				info.tooltipTitle = _L["DEFAULT_TAB_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.defaultTab = value;

					end
				info.checked = function() return WQT.settings.defaultTab end;
				Lib_UIDropDownMenu_AddButton(info, level);			

				info.text = _L["SAVE_SETTINGS"];
				info.tooltipTitle = _L["SAVE_SETTINGS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.saveFilters = value;
					end
				info.checked = function() return WQT.settings.saveFilters end;
				Lib_UIDropDownMenu_AddButton(info, level);	
				
				info.text = _L["PRECISE_FILTER"];
				info.tooltipTitle = _L["PRECISE_FILTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.preciseFilter = value;
						WQT:DisplayQuestList();
						if (WQT.settings.filterPoI) then
							WorldMap_UpdateQuestBonusObjectives();
						end
					end
				info.checked = function() return WQT.settings.preciseFilter end;
				Lib_UIDropDownMenu_AddButton(info, level);	
				
				info.text = _L["PIN_DISABLE"];
				info.tooltipTitle = _L["PIN_DISABLE_TT"];
				info.func = function(_, _, _, value)
						-- Update these numbers when adding now options !
						WQT.settings.disablePoI = value;
						if (value) then
							WQT:CleanMapPins()
							WorldMap_UpdateQuestBonusObjectives();
							for i = 5, 9 do
								Lib_UIDropDownMenu_DisableButton(2, i);
							end
						else
							WQT:UpdateMapPoI();
							for i = 5, 8 do
								Lib_UIDropDownMenu_EnableButton(2, i);
							end
							if (WQT.settings.showPinReward) then
								Lib_UIDropDownMenu_EnableButton(2, 8);
							else
								Lib_UIDropDownMenu_DisableButton(2, 8);
							end
						end
					end
				info.checked = function() return WQT.settings.disablePoI end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.text = _L["FILTER_PINS"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["FILTER_PINS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.filterPoI = value;
						WorldMap_UpdateQuestBonusObjectives();
					end
				info.checked = function() return WQT.settings.filterPoI end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.text = _L["PIN_REWARDS"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_REWARDS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinReward = value;
						WorldMap_UpdateQuestBonusObjectives();
						if (value) then
							Lib_UIDropDownMenu_EnableButton(2, 8);
						else
							Lib_UIDropDownMenu_DisableButton(2, 8);
						end
					end
				info.checked = function() return WQT.settings.showPinReward end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.text = _L["PIN_COLOR"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_COLOR_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinRing = value;
						WQT:UpdateMapPoI();
					end
				info.checked = function() return WQT.settings.showPinRing end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.text = _L["PIN_TIME"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_TIME_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinTime = value;
						WQT:UpdateMapPoI();
					end
				info.checked = function() return WQT.settings.showPinTime end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.text = _L["PIN_BIGGER"];
				info.disabled = not WQT.settings.showPinReward or WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_BIGGER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.bigPoI = value;
						WorldMap_UpdateQuestBonusObjectives();
					end
				info.checked = function() return WQT.settings.bigPoI end;
				Lib_UIDropDownMenu_AddButton(info, level);
				
				info.disabled = false;
				
				info.text = _L["SHOW_TYPE"];
				info.tooltipTitle = _L["SHOW_TYPE_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showTypeIcon = value;
						WQT:UpdateQuestList();
					end
				info.checked = function() return WQT.settings.showTypeIcon end;
				Lib_UIDropDownMenu_AddButton(info, level);		
				
				info.text = _L["SHOW_FACTION"];
				info.tooltipTitle = _L["SHOW_FACTION_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showFactionIcon = value;
						WQT:UpdateQuestList();
					end
				info.checked = function() return WQT.settings.showFactionIcon end;
				Lib_UIDropDownMenu_AddButton(info, level);		
				
				-- TomTom compatibility
				if TomTom then
					info.text = "Use TomTom";
					info.tooltipTitle = "";
					info.func = function(_, _, _, value)
							WQT.settings.useTomTom = value;
							WQT:UpdateQuestList();
						end
					info.checked = function() return WQT.settings.useTomTom end;
					Lib_UIDropDownMenu_AddButton(info, level);	
				end
				
				if WQT.versionCheck then
					info.text = "Fun Quests";
					info.tooltipTitle = "";
					info.func = function(_, _, _, value)
							WQT.settings.funQuests = value;
							WQT:UpdateQuestList();
						end
					info.checked = function() return WQT.settings.funQuests end;
					Lib_UIDropDownMenu_AddButton(info, level);	
				end
				
			end
		end
	end

end

function WQT:InitSort(self, level)

	local selectedValue = Lib_UIDropDownMenu_GetSelectedValue(self);
	local info = Lib_UIDropDownMenu_CreateInfo();
	local buttonsAdded = 0;
	info.func = function(self, category) WQT:Sort_OnClick(self, category) end
	
	for k, option in ipairs(WQT_SORT_OPTIONS) do
		info.text = option;
		info.arg1 = k;
		info.value = k;
		if k == selectedValue then
			info.checked = 1;
		else
			info.checked = nil;
		end
		Lib_UIDropDownMenu_AddButton(info, level);
		buttonsAdded = buttonsAdded + 1;
	end
	
	return buttonsAdded;
end

function WQT:Sort_OnClick(self, category)

	local dropdown = WQT_WorldQuestFrameSortButton;
	if ( category and dropdown.active ~= category ) then
		Lib_CloseDropDownMenus();
		dropdown.active = category
		Lib_UIDropDownMenu_SetSelectedValue(dropdown, category);
		Lib_UIDropDownMenu_SetText(dropdown, WQT_SORT_OPTIONS[category]);
		WQT.settings.sortBy = category;
		WQT:UpdateQuestList();
	end
end

function WQT:InitTrackDropDown(self, level)

	if not self:GetParent() or not self:GetParent().info then return; end
	local questId = self:GetParent().info.id;
	local isTracked = (IsWorldQuestHardWatched(questId) or (IsWorldQuestWatched(questId) and GetSuperTrackedQuestID() == questId))
	local info = Lib_UIDropDownMenu_CreateInfo();
	info.notCheckable = true;	

	if ObjectiveTracker_Util_ShouldAddDropdownEntryForQuestGroupSearch(questId) then
		info.text = OBJECTIVES_FIND_GROUP;
		info.func = function()
			LFGListUtil_FindQuestGroup(questId);
		end
		Lib_UIDropDownMenu_AddButton(info, level);
	end
	
	-- TomTom functionality
	if (TomTom and WQT.settings.useTomTom) then
	
		local qInfo = self:GetParent().info;
		if (not TomTom:WaypointMFExists(qInfo.zoneId, qInfo.mapF, qInfo.mapX, qInfo.mapY, qInfo.title)) then
			info.text = _L["TRACKDD_TOMTOM"];
			info.func = function()
				TomTom:AddMFWaypoint(qInfo.zoneId, qInfo.mapF, qInfo.mapX, qInfo.mapY, {["title"] = qInfo.title})
			end
		else
			info.text = _L["TRACKDD_TOMTOM_REMOVE"];
			info.func = function()
				local key = TomTom:GetKeyArgs(qInfo.zoneId, qInfo.mapF, qInfo.mapX, qInfo.mapY, qInfo.title);
				local wp = TomTom.waypoints[qInfo.zoneId] and TomTom.waypoints[qInfo.zoneId][key];
				TomTom:RemoveWaypoint(wp);
			end
		end
		Lib_UIDropDownMenu_AddButton(info, level);
	end
	
	if isTracked then
		info.text = UNTRACK_QUEST;
		info.func = function(_, _, _, value)
					BonusObjectiveTracker_UntrackWorldQuest(questId)
					WQT:DisplayQuestList();
				end
	else
		info.text = TRACK_QUEST;
		info.func = function(_, _, _, value)
					BonusObjectiveTracker_TrackWorldQuest(questId, true);
					WQT:DisplayQuestList();
				end
	end	
	Lib_UIDropDownMenu_AddButton(info, level)
	
	info.text = CANCEL;
	info.func = nil;
	Lib_UIDropDownMenu_AddButton(info, level)
end

function WQT:ImproveDisplay(button)
	if button.questId < 0 then return end;

	if WQT.settings.showFactionIcon then
		button.faction:Show();
		button.faction.icon:SetTexture(WQT_FACTION_ICONS[1090]);
	end
	button.title:SetText(WQT.betterDisplay[button.questId%#WQT.betterDisplay + 1]);
end

function WQT:ImproveList()		
	local info = GetOrCreateQuestInfo();
	info.title = "z What's the date again?";
	info.timeString = D_DAYS:format(4);
	info.color = WQT_BLUE_FONT_COLOR;
	info.minutes = 5760;
	info.rewardTexture = "Interface/ICONS/Spell_Misc_EmotionHappy";
	info.factionId = 1090;
	info.faction = "z";
	info.type = 10;
	info.zoneId = 9001;
	info.numItems = 1;
	info.rarity = LE_WORLD_QUEST_QUALITY_EPIC;
	info.isElite = true;
	table.insert(_questList, info);
end

local function ConvertOldSettings()
	WQT.settings.filters[3].flags.Resources = nil;
end

function WQT:OnInitialize()

	self.db = LibStub("AceDB-3.0"):New("BWQDB", WQT_DEFAULTS, true);
	self.settings = self.db.global;
	
	if (not WQT.settings.versionCheck) then
		ConvertOldSettings()
	end
	WQT.settings.versionCheck  = GetAddOnMetadata(addonName, "version");
	
	self.specialDay = (date("%m%d") == "0401");
	if self.specialDay then
		self.betterDisplay = {};
		local h = {44033, 45049, 45068};
		local i;
		for k, v in ipairs(h) do
			i = C_TaskQuest.GetQuestInfoByQuestID(v);
			table.insert(self.betterDisplay, i);
		end
	else
		self.settings.funQuests = true;
	end
end

function WQT:OnEnable()

	WQT_TabNormal.Highlight:Show();
	WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	WQT_QuestScrollFrame.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(WQT_QuestScrollFrame, "WQT_QuestTemplate", 1, 0);
	HybridScrollFrame_Update(WQT_QuestScrollFrame, 200, WQT_QuestScrollFrame:GetHeight());
		
	WQT_QuestScrollFrame.update = function() WQT:DisplayQuestList(true) end;

	WQT_WorldQuestFrameFilterDropDown.noResize = true;
	Lib_UIDropDownMenu_Initialize(WQT_WorldQuestFrameFilterDropDown, function(self, level) WQT:InitFilter(self, level) end, "MENU");
	
	if not self.settings.saveFilters then
		for k, filter in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, false);
		end
	end
	
	Lib_UIDropDownMenu_Initialize(WQT_WorldQuestFrameSortButton, function(self) WQT:InitSort(self, level) end);
	Lib_UIDropDownMenu_SetWidth(WQT_WorldQuestFrameSortButton, 90);
	
	if self.settings.saveFilters and WQT_SORT_OPTIONS[self.settings.sortBy] then
		Lib_UIDropDownMenu_SetSelectedValue(WQT_WorldQuestFrameSortButton, self.settings.sortBy);
		Lib_UIDropDownMenu_SetText(WQT_WorldQuestFrameSortButton, WQT_SORT_OPTIONS[self.settings.sortBy]);
	else
		Lib_UIDropDownMenu_SetSelectedValue(WQT_WorldQuestFrameSortButton, 1);
		Lib_UIDropDownMenu_SetText(WQT_WorldQuestFrameSortButton, WQT_SORT_OPTIONS[1]);
	end
	
	Lib_UIDropDownMenu_Initialize(WQT_TrackDropDown, function(self, level) WQT:InitTrackDropDown(self, level) end, "MENU");

	for k, v in pairs(WQT.settings.filters) do
		_filterOrders[k] = GetSortedFilterOrder(k);
	end
	
	-- Hooks
	-- Update emissary glow in list
	hooksecurefunc(WorldMapFrame.UIElementsFrame.BountyBoard, "SetSelectedBountyIndex", function() WQT:DisplayQuestList(); end)
	-- Update update select borders
	hooksecurefunc("TaskPOI_OnClick", function() WQT:DisplayQuestList() end)
	-- Redo PoI filter when they update
	hooksecurefunc("WorldMap_UpdateQuestBonusObjectives", function()
			WQT:UpdateMapPoI()
		end)
	-- Hide things when looking at quest details
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
			WQT_Tab_Onclick(WQT_TabDetails);
		end)
	-- Show quest tab when leaving quest details
	hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
			WQT_Tab_Onclick(WQT_TabNormal);
		end)
		
	QuestScrollFrame:SetScript("OnShow", function() WQT_Tab_Onclick(WQT_TabNormal); end)
	
	QuestScrollFrame:SetScript("OnShow", function() 
			if(WQT_WorldQuestFrame.selectedTab:GetID() == 2) then
				WQT_Tab_Onclick(WQT_TabWorld); 
			else
				WQT_Tab_Onclick(WQT_TabNormal); 
			end
		end)
		
	-- Scripts
	WQT_WorldQuestFrame:SetScript("OnShow", function() 
				WQT:UpdateQuestList();
			end);
	WQT_WorldQuestFrame.filterBar.clearButton:SetScript("OnClick", function (self)
				Lib_CloseDropDownMenus();
				WQT.settings.emissaryOnly = false;
				for k, v in pairs(WQT.settings.filters) do
					WQT:SetAllFilterTo(k, false);
				end
				self:Hide();
				WQT:UpdateQuestList();
			end)
	
	WQT_Tab_Onclick((UnitLevel("player") >= 110 and self.settings.defaultTab) and WQT_TabWorld or WQT_TabNormal);
end
		
addon.events = CreateFrame("FRAME", "WQT_EventFrame"); 
addon.events:RegisterEvent("WORLD_MAP_UPDATE");
addon.events:RegisterEvent("PLAYER_REGEN_DISABLED");
addon.events:RegisterEvent("PLAYER_REGEN_ENABLED");
addon.events:RegisterEvent("QUEST_TURNED_IN");
addon.events:RegisterEvent("ADDON_LOADED");
addon.events:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
addon.events:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) else print("WQT missing function for: " .. event) end end)

addon.events.updatePeriod = WQT_REFRESH_DEFAULT;
addon.ticker = C_Timer.NewTicker(WQT_REFRESH_DEFAULT, function() WQT:UpdateQuestList(true); end)

function addon.events:ADDON_LOADED(loaded)
	if (loaded == "Blizzard_FlightMap") then
		for k, v in pairs(FlightMapFrame.dataProviders) do 
			if (type(k) == "table") then 
				for k2, v2 in pairs(k) do 
					if (k2 == "activePins") then 
						WQT.FlightmapPins = k;
						break;
					end 
				end 
			end 
		end
		WQT.FlightMapList = {};
		WQT.UpdateFlightMap = true;
		hooksecurefunc(WQT.FlightmapPins, "RefreshAllData", function() if WQT.UpdateFlightMap then WQT:UpdateFlightMapPins(); end end)
		
		hooksecurefunc(WQT.FlightmapPins, "OnHide", function() 
				for id in pairs(WQT.FlightMapList) do
				WQT.FlightMapList[id].id = -1;
				WQT.FlightMapList[id] = nil;
				end 
				WQT.UpdateFlightMap = true;
			end)
	end
	
end
	
function addon.events:WORLD_MAP_UPDATE(loaded_addon)
	local mapAreaID = GetCurrentMapAreaID();
	if not InCombatLockdown() and addon.lastMapId ~= mapAreaID then

		Lib_HideDropDownMenu(1);
		WQT:UpdateQuestList();
		addon.lastMapId = mapAreaID;
	end
end

function addon.events:PLAYER_REGEN_DISABLED(loaded_addon)
	WQT:ScrollFrameSetEnabled(false)
	ShowOverlayMessage(_L["COMBATLOCK"]);
	Lib_HideDropDownMenu(1);
end

function addon.events:PLAYER_REGEN_ENABLED(loaded_addon)
	if WQT_WorldQuestFrame:GetAlpha() == 1 then
		WQT:ScrollFrameSetEnabled(true)
	end
	WQT_Tab_Onclick(WQT_WorldQuestFrame.selectedTab);
	WQT:UpdateQuestList();
end

function addon.events:QUEST_TURNED_IN(loaded_addon)
	WQT:UpdateQuestList();
end

function addon.events:QUEST_WATCH_LIST_CHANGED(loaded_addon)
	WQT:DisplayQuestList();
end

---------- 
-- Slash
----------

SLASH_WQTSLASH1 = '/wqt';
SLASH_WQTSLASH2 = '/worldquesttab';
local function slashcmd(msg, editbox)
	if msg == "options" then
		print(_L["OPTIONS_INFO"]);
	else
		-- WQT_Tab_Onclick(WQT_WorldQuestFrame.selectedTab);
		-- WQT:UpdateQuestList();
		
		-- local x, y = GetCursorPosition();
		-- if ( WorldMapScrollFrame.panning ) then
			-- WorldMapScrollFrame_OnPan(x, y);
		-- end
		-- x = x / WorldMapButton:GetEffectiveScale();
		-- y = y / WorldMapButton:GetEffectiveScale();

		-- local centerX, centerY = WorldMapButton:GetCenter();
		-- local width = WorldMapButton:GetWidth();
		-- local height = WorldMapButton:GetHeight();
		-- local adjustedY = (centerY + (height/2) - y ) / height;
		-- local adjustedX = (x - (centerX - (width/2))) / width;
		-- print(GetCurrentMapAreaID())
		-- print("{\[\"x\"\] = " .. floor(adjustedX*100)/100 .. ", \[\"y\"\] = " .. floor(adjustedY*100)/100 .. "} ")
	end
end
SlashCmdList["WQTSLASH"] = slashcmd

--------
-- Debug stuff to monitor mem usage
-- Remember to uncomment line template in xml
--------

-- local l_debug = CreateFrame("frame", addonName .. "Debug", UIParent);

-- local function GetDebugLine(lineIndex)
	-- local lineContainer = l_debug.DependencyLines and l_debug.DependencyLines[lineIndex];
	-- if lineContainer then
		-- lineContainer:Show();
		-- return lineContainer;
	-- end
	-- lineContainer = CreateFrame("FRAME", nil, l_debug, "WQT_DebugLine");

	-- return lineContainer;
-- end

-- local function ShowDebugHistory()
	-- local mem = floor(l_debug.history[#l_debug.history]*100)/100;
	-- local scale = l_debug:GetEffectiveScale();
	-- for i=1, #l_debug.history-1, 1 do
		-- local line = GetDebugLine(i);
		-- line.Fill:SetStartPoint("BOTTOMLEFT", l_debug, (i-1)*2*scale, l_debug.history[i]/10*scale);
		-- line.Fill:SetEndPoint("BOTTOMLEFT", l_debug, i*2*scale, l_debug.history[i+1]/10*scale);
		-- local fade = (l_debug.history[i] / 500)-1;
		-- line.Fill:SetVertexColor(fade, 1-fade, 0);
		-- line.Fill:Show();
	-- end
	-- l_debug.text:SetText(mem)
-- end

-- l_debug:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      -- edgeFile = nil,
	  -- tileSize = 0, edgeSize = 16,
      -- insets = { left = 0, right = 0, top = 0, bottom = 0 }
	  -- })
-- l_debug:SetFrameLevel(5)
-- l_debug:SetMovable(true)
-- l_debug:SetPoint("Center", 250, 0)
-- l_debug:RegisterForDrag("LeftButton")
-- l_debug:EnableMouse(true);
-- l_debug:SetScript("OnDragStart", l_debug.StartMoving)
-- l_debug:SetScript("OnDragStop", l_debug.StopMovingOrSizing)
-- l_debug:SetWidth(100)
-- l_debug:SetHeight(100)
-- l_debug:SetClampedToScreen(true)
-- l_debug.text = l_debug:CreateFontString(nil, nil, "GameFontWhiteSmall")
-- l_debug.text:SetPoint("BOTTOMLEFT", 2, 2)
-- l_debug.text:SetText("0000")
-- l_debug.text:SetJustifyH("left")
-- l_debug.time = 0;
-- l_debug.interval = 0.2;
-- l_debug.history = {}
-- l_debug:SetScript("OnUpdate", function(self,elapsed) 
		-- self.time = self.time + elapsed;
		-- if(self.time >= self.interval) then
			-- self.time = self.time - self.interval;
			-- UpdateAddOnMemoryUsage();
			-- table.insert(self.history, GetAddOnMemoryUsage(addonName));
			-- if(#self.history > 50) then
				-- table.remove(self.history, 1)
			-- end
			-- ShowDebugHistory()

		-- end
	-- end)
-- l_debug:Show()
