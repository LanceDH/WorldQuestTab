local addonName, addon = ...

local _legionZoneIds = {1014, 1015, 1033, 1017, 1024, 1018};
local BWQ_WHITE_FONT_COLOR = CreateColor(0.8, 0.8, 0.8);
local questList = {};
local updatedDuringCombat = false;
-- 1007 Broken Isles
local questInfoPool = {};
local factionIcons = {
	[1894] = "Interface/ICONS/INV_LegionCircle_Faction_Warden"
	,[1859] = "Interface/ICONS/INV_LegionCircle_Faction_NightFallen"
	,[1900] = "Interface/ICONS/INV_LegionCircle_Faction_CourtofFarnodis"
	,[1948] = "Interface/ICONS/INV_LegionCircle_Faction_Valarjar"
	,[1828] = "Interface/ICONS/INV_LegionCircle_Faction_HightmountainTribes"
	,[1883] = "Interface/ICONS/INV_LegionCircle_Faction_DreamWeavers"
}

function BWQ_Tab_Onclick(self)
	if self:GetID() == 1 then
		HideUIPanel(BWQ_WorldQuestFrame);
		BWQ_TabNormal.Highlight:Show();
		BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	else
		BWQ_TabWorld.Highlight:Show();
		ShowUIPanel(BWQ_WorldQuestFrame);
		BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	end
end

function BWQ_Quest_OnEnter(self)
	WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT");

	if ( not HaveQuestData(self.questId) ) then
		WorldMapTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		WorldMapTooltip:Show();
		return;
	end

	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(self.questId);
		local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(self.questId);
		local color = WORLD_QUEST_QUALITY_COLORS[rarity];
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

	WorldMap_AddQuestRewardsToTooltip(self.questId);

	-- if ( self.worldQuest and WorldMapTooltip.AddDebugWorldQuestInfo ) then
		-- WorldMapTooltip:AddDebugWorldQuestInfo(self.questId);
	-- end

	WorldMapTooltip:Show();
end

local function GetOrCreateQuestInfo()
	for k, info in ipairs(questInfoPool) do
		if info.id == -1 then
			return info;
		end
	end

	local info = {["id"] = -1, ["title"] = "", ["timeString"] = "", ["color"] = BWQ_WHITE_FONT_COLOR, ["minutes"] = 0, ["faction"] = 0, ["type"] = 0, ["rarity"] = 0, ["isElite"] = false, ["tradeskill"] = 0, ["numObjectives"] = 0};
	table.insert(questInfoPool, info);
	
	return info
end

local function SortQuestList(list)
	table.sort(list, function(a, b) 
			if a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
	end);
end

local function SortQuestListByZone(list)
	table.sort(list, function(a, b) 
		if a.zoneId == b.zoneId then
			if a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
		end
		return a.zoneId < b.zoneId;
	end);
end

local function GetQuestTimeString(questId)
	local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questId);
	local timeString = "";
	local color = BWQ_WHITE_FONT_COLOR;
	if ( timeLeftMinutes ) then
		if ( timeLeftMinutes <= WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			-- Grace period, show the actual time left
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(timeLeftMinutes * 60);
		elseif timeLeftMinutes <= 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = SecondsToTime((timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) * 60);
		elseif timeLeftMinutes < 24 * 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = D_HOURS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 60);
		else
			timeString = D_DAYS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 1440);
		end
	end
	
	return timeLeftMinutes, timeString, color;
end

local function AddQuestToList(list, qInfo, zoneId)
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(qInfo.questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(qInfo.questId);
	local minutes, timeString, color = GetQuestTimeString(qInfo.questId);
	if minutes == 0 then return end;
	local faction = factionId and GetFactionInfoByID(factionId) or "";
	--print(factionId, faction);
	
	local info = GetOrCreateQuestInfo();
	info.id = qInfo.questId;
	info.title = title;
	info.timeString = timeString;
	info.color = color;
	info.minutes = minutes;
	info.faction = faction;
	info.factionId = factionId;
	info.type = worldQuestType;
	info.rarity = rarity;
	info.isElite = isElite;
	info.zoneId = zoneId;
	info.tradeskill = tradeskillLineIndex;
	info.numObjectives = qInfo.numObjectives;
	table.insert(list, info)
end

local function DisplayQuestType(frame, questType, rarity, isElite, tradeskillLineIndex)
	local inProgress = false;

	frame:Show();
	
	if isElite then
		frame.elite:Show();
	else
		frame.elite:Hide();
	end
	
	if rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		frame.bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		frame.bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		frame.bg:SetSize(28, 28);
	elseif rarity == LE_WORLD_QUEST_QUALITY_RARE then
		frame.bg:SetAtlas("worldquest-questmarker-rare");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
		--ApplyAtlasTexturesToPOI(button, "worldquest-questmarker-rare", "worldquest-questmarker-rare-down", "worldquest-questmarker-rare", 18, 18);
	elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
		frame.bg:SetAtlas("worldquest-questmarker-epic");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
		--ApplyAtlasTexturesToPOI(button, "worldquest-questmarker-epic", "worldquest-questmarker-epic-down", "worldquest-questmarker-epic", 18, 18);
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
	else
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-questmarker-questbang");
			frame.texture:SetSize(6, 15);
		end
	end
end

local function DisplayReward(frame, questId)
	if GetNumQuestLogRewards(questId) > 0 then
		local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(1, questId);
		frame.icon:Show();
		frame.icon:SetTexture(texture);
		if numItems > 1 then
			frame.amount:SetText(numItems);
			frame.amount:Show();
		end
		return true;
	elseif GetQuestLogRewardMoney(questId) > 0 then
		frame.icon:SetTexture("Interface/ICONS/INV_Misc_Coin_01");
		local gold = floor(abs(GetQuestLogRewardMoney(questId) / 10000))
		frame.amount:SetText(gold);
		frame.amount:Show();
		return true;
	elseif GetNumQuestLogRewardCurrencies(questId) > 0 then
		local name, texture, numItems = GetQuestLogRewardCurrencyInfo(1, questId)
		frame.icon:SetTexture(texture);
		frame.amount:SetText(numItems);
		frame.amount:Show();
		return true;
	end
	return false;
end

function addon:UpdateQuestList()
	if InCombatLockdown() or UnitLevel("player") < 110 then return end
	local scrollFrame = BWQ_QuestScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	if buttons == nil then return; end
	
	--local list = LoreLibraryList.filteredList --_addon:GetFilteredList(true);
	--if not list then list = {} end
	
	local mapAreaID = GetCurrentMapAreaID();
	local list = questList;
	
	for i=#list, 1, -1 do
		list[i].id = -1;
		table.remove(list, i);
	end
	
	if mapAreaID == 1007 then
		for k, zoneId in ipairs(_legionZoneIds) do
			for k2, info in ipairs(C_TaskQuest.GetQuestsForPlayerByMapID(zoneId)) do
				AddQuestToList(list, info, zoneId);
			end
		end
	elseif C_TaskQuest.GetQuestsForPlayerByMapID(mapAreaID) then
		for k, info in ipairs(C_TaskQuest.GetQuestsForPlayerByMapID(mapAreaID)) do
			AddQuestToList(list, info, mapAreaID);
		end
	end

	SortQuestList(list);
	
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		button:Hide();
		button.reward.amount:Hide();
		button.trackedBorder:Hide();
		if ( displayIndex <= #list) then
			local q = list[displayIndex];
			button:Show();
			button.title:SetText(q.title);
			button.time:SetTextColor(q.color.r, q.color.g, q.color.b, 1);
			button.time:SetText(q.timeString);
			button.extra:SetText(mapAreaID == 1007 and GetMapNameByID(q.zoneId) or q.faction);
			button.faction.icon:SetTexture(factionIcons[q.factionId] or "");
			DisplayQuestType(button.type, q.type, q.rarity, q.isElite, q.tradeskill)
			if DisplayReward(button.reward, q.id) then
				button.reward:Show();
			end
			if GetSuperTrackedQuestID() == q.id then
				button.trackedBorder:Show();
			end
			
			button.zoneId = q.zoneId;
			button.questId = q.id;
			button.numObjectives = q.numObjectives;
		end
	end
	
	HybridScrollFrame_Update(BWQ_QuestScrollFrame, #list * 40, scrollFrame:GetHeight());
	
end

QuestMapFrame:Hide()
BWQ_QuestScrollFrame.scrollBar.doNotHide = true;
HybridScrollFrame_CreateButtons(BWQ_QuestScrollFrame, "BWQ_QuestTemplate", 1, 0);
HybridScrollFrame_Update(BWQ_QuestScrollFrame, 200, BWQ_QuestScrollFrame:GetHeight());
	
BWQ_QuestScrollFrame.update = function() addon:UpdateQuestList() end;

BWQ_WorldQuestFrame:SetScript("OnShow", function() addon:UpdateQuestList() end);

addon.events = CreateFrame("FRAME", "BWQ_EventFrame"); 
addon.events:RegisterEvent("WORLD_MAP_UPDATE");
addon.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

function addon.events:WORLD_MAP_UPDATE(loaded_addon)
	-- Only update when map is visible
	if not InCombatLockdown() then
		addon:UpdateQuestList()
	end
end

----------
-- Slash
----------

SLASH_BWQSLASH1 = '/bwq';
local function slashcmd(msg, editbox)

end
SlashCmdList["BWQSLASH"] = slashcmd