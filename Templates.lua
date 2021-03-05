local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;
local ADD = LibStub("AddonDropDown-2.0");

--------------------------------
-- WQT_MiniIconMixin
--------------------------------

WQT_MiniIconMixin = {};

function WQT_MiniIconMixin:Reset()
	self:Hide();
	
	self.Icon:Show();
	self.Icon:SetTexture(nil);
	self.Icon:SetScale(1);
	self.Icon:SetSize(10, 10);
	self.Icon:SetTexCoord(0, 1, 0, 1);
	self.Icon:SetVertexColor(1, 1, 1);
	self.Icon:SetDesaturated(false);
	
	self.BG:Show();
	self.BG:SetTexture("Interface/GLUES/Models/UI_MainMenu_Legion/UI_Legion_Shadow");
	self.BG:SetScale(1);
	self.BG:SetVertexColor(1, 1, 1);
	self.BG:SetAlpha(0.75);
	
	self.texure = "";
	self.scale = 1;
	self.left = nil;
	self.right = nil;
	self.top = nil;
	self.bottom = nil;
	self.isDesaturated = false;
	self.hasCustomColor = false;
	self.r = 1;
	self.g = 1;
	self.b = 1;
end

function WQT_MiniIconMixin:SetIconColor(color)
	self.r, self.g, self.b = color:GetRGB();
	self:Update();
end

function WQT_MiniIconMixin:SetIconColorRGBA(r, g, b, a)
	self.r = r;
	self.g = g;
	self.b = b;
	self:Update();
end

function WQT_MiniIconMixin:SetDesaturated(desaturate)
	self.isDesaturated = desaturate;
	self:Update();
end

function WQT_MiniIconMixin:SetIconCoords(left, right, top, bottom)
	self.l = left;
	self.r = right;
	self.t = top;
	self.b = bottom;
	self:Update();
end

function WQT_MiniIconMixin:SetIconScale(scale)
	self.scale = scale;
	self:Update();
end

function WQT_MiniIconMixin:SetIconSize(width, height)
	self.Icon:SetSize(width, height);
end

function WQT_MiniIconMixin:SetBackgroundScale(scale)
	self.BG:SetScale(scale);
end

function WQT_MiniIconMixin:SetBackgroundShown(value)
	self.BG:SetShown(value);
end

function WQT_MiniIconMixin:SetupIcon(texture, left, right, top, bottom)
	self:Reset();
	
	if (not texture) then return; end
	
	self.texture = texture;
	self.left = left;
	self.right = right;
	self.top = top;
	self.bottom = bottom;
	
	self:Update();
	self:Show();
end

function WQT_MiniIconMixin:SetupRewardIcon(rewardType, subType)
	self:Reset();
	
	local rewardTypeAtlas = WQT_Utils:GetRewardIconInfo(rewardType, subType);
	
	if not (rewardTypeAtlas) then
		return;
	end
	
	self.texture = rewardTypeAtlas.texture;
	self.left = rewardTypeAtlas.l;
	self.right = rewardTypeAtlas.r;
	self.top = rewardTypeAtlas.t;
	self.bottom = rewardTypeAtlas.b;
	self.scale = rewardTypeAtlas.scale;
	if (rewardTypeAtlas.color) then
		self.r, self.g, self.b = rewardTypeAtlas.color:GetRGB();
	end
	
	self:Update();
	self:Show();
end

function WQT_MiniIconMixin:Update()
	if (self.left) then
		self.Icon:SetTexture(self.texture);
		self.Icon:SetTexCoord(self.left, self.right, self.top, self.bottom);
	else
		self.Icon:SetTexCoord(0, 1, 0, 1);
		self.Icon:SetAtlas(self.texture);
	end
	self.Icon:SetScale(self.scale);
	
	local r, g, b = 1, 1, 1;
	self.Icon:SetDesaturated(false);
	if (self.isDesaturated) then
		if (self.left) then
			r, g, b = 0.8, 0.8, 0.8;
		else
			self.Icon:SetDesaturated(true);
		end
	else
		if (self.r) then
			r, g, b = self.r, self.g, self.b;
		end
	end
	self.Icon:SetVertexColor(r, g, b);
end

--------------------------------
-- WQT_ScrollFrameMixin
--------------------------------

WQT_ScrollFrameMixin = {};

function WQT_ScrollFrameMixin:OnLoad()
	self.offset = 0;
	self.scrollStep = 30;
	self.max = 0;
	self.ScrollBar:SetMinMaxValues(0, 0);
	self.ScrollBar:SetValue(0);
	self.ScrollChild:SetPoint("RIGHT", self)
end

function WQT_ScrollFrameMixin:OnShow()
	self:SetChildHeight(self.ScrollChild:GetHeight());
end

function WQT_ScrollFrameMixin:UpdateChildFramePosition()
	if (self.ScrollChild) then
		self.ScrollChild:SetPoint("TOPLEFT", self, 0, self.offset);
	end
end

function WQT_ScrollFrameMixin:ScrollValueChanged(value)
	self.offset = max(0, min(value, self.max));
	self:UpdateChildFramePosition();
end

function WQT_ScrollFrameMixin:OnMouseWheel(delta)
	self.offset = self.offset - delta * self.scrollStep;
	self.offset = max(0, min(self.offset, self.max));
	self:UpdateChildFramePosition();
	self.ScrollBar:SetValue(self.offset);
end

function WQT_ScrollFrameMixin:SetChildHeight(height)
	self.ScrollChild:SetHeight(height);
	self.max = max(0, height - self:GetHeight());
	self.offset = min(self.offset, self.max);
	self.ScrollBar:SetMinMaxValues(0, self.max);
end

----------------------------
-- Containers
----------------------------

WQT_ContainerButtonMixin = {};

function WQT_ContainerButtonMixin:OnClick()
	self:SetSelected(not self.isSelected);
end

function WQT_ContainerButtonMixin:SetSelected(isSelected)
	self.isSelected = isSelected;	
	if (self.container) then
		if (self.isSelected) then
			self.container:Show();
			self.Selected:SetAlpha(0.5);
			WQT_WorldQuestFrame:SelectTab(WQT_TabWorld);
		else
			self.container:Hide();
			self.Selected:SetAlpha(0);
			WQT_WorldQuestFrame:SelectTab(WQT_TabNormal);
		end
	end
end

function WQT_ContainerButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(TRACKER_HEADER_WORLD_QUESTS, 1, 1, 1, true);
	GameTooltip:Show();
end

function WQT_ContainerButtonMixin:OnLeave()
	GameTooltip:Hide();
end

----------------------------
-- WQT_MiniIconOverlayMixin
----------------------------

WQT_MiniIconOverlayMixin = {};

function WQT_MiniIconOverlayMixin:Init(anchor, startAngle, distance, spacingAngle)
	self.miniIconPool = CreateFramePool("FRAME", anchor, "WQT_MiniIconTemplate");
	self.anchor = anchor;
	self.startAngle = startAngle or 270;
	self.distance = distance or 20;
	self.spacingAngle = spacingAngle or 32;
	self.activeIcons = {};
end

function WQT_MiniIconOverlayMixin:Reset()
	self.miniIconPool:ReleaseAll();
	wipe(self.activeIcons);
end

function WQT_MiniIconOverlayMixin:Create()
	local icon = self.miniIconPool:Acquire();
	tinsert(self.activeIcons, icon);
	icon:Show();
	self:UpdatePlacement();
	return icon;
end

function WQT_MiniIconOverlayMixin:UpdatePlacement()
	local numIcons = self.miniIconPool:GetNumActive();
	-- Counters
	local offsetAngle = self.spacingAngle;
	local startAngle = self.startAngle;
	
	-- position of first counter
	startAngle = startAngle - offsetAngle * (numIcons -1) /2
	
	for k, icon in ipairs(self.activeIcons) do
		local x = cos(startAngle) * self.distance;
		local y = sin(startAngle) * self.distance;
		icon:SetPoint("CENTER", self.anchor, "CENTER", x, y);
		icon:SetParent(self.anchor);
		icon:Show();
		-- Offset next counter
		startAngle = startAngle + offsetAngle;
	end
end


----------------------------
-- Utilities
----------------------------

local cachedTypeData = {};
local cachedZoneInfo = {};

function WQT_Utils:GetSetting(...)
	local settings =  WQT.settings;
	local index = 1;
	local param = select(index, ...);
	
	while (param ~= nil) do
		if(settings[param] == nil) then 
			return nil 
		end;
		settings = settings[param];
		index = index + 1;
		param = select(index, ...);
	end
	
	if (type(settings) == "table") then
		return nil 
	end;
	
	return settings;
end

function WQT_Utils:GetLocal(key)
	return _L[key or ""];
end

function WQT_Utils:GetVariable(key)
	local val = _V[key or ""];
	
	if (not val) then return; end
	
	if (type(val) == "table") then
		return CopyTable(val);
	end
	
	return val;
end

function WQT_Utils:GetCachedMapInfo(zoneId)
	zoneId = zoneId or 0;
	local zoneInfo = cachedZoneInfo[zoneId];
	if (not zoneInfo) then
		zoneInfo = C_Map.GetMapInfo(zoneId);
		if (zoneInfo and zoneInfo.name) then
			cachedZoneInfo[zoneId] = zoneInfo;
		end
	end
	
	return zoneInfo;
end

function WQT_Utils:GetFactionDataInternal(id)
	if (not id) then  
		-- No faction
		return _V["WQT_NO_FACTION_DATA"];
	end;
	local factionData = _V["WQT_FACTION_DATA"];

	if (not factionData[id]) then
		-- Add new faction in case it's not in our data yet
		factionData[id] = { ["expansion"] = 0 ,["faction"] = nil ,["texture"] = 1103069, ["unknown"] = true } 
		factionData[id].name = GetFactionInfoByID(id) or "Unknown Faction";
		WQT:debugPrint("Added new faction", id,factionData[id].name);
	end
	
	return factionData[id];
end

function WQT_Utils:GetCachedTypeIconData(questInfo)
	
	if (questInfo.isDaily or questInfo.isAllyQuest) then
		return "QuestDaily", 17, 17, true;
	elseif (questInfo.isQuestStart) then
		return "QuestNormal", 17, 17, true;
	elseif (C_QuestLog.IsThreatQuest(questInfo.questId)) then
		 return "worldquest-icon-nzoth", 14, 14, true;
	end
	
	local tagInfo = questInfo:GetTagInfo();
	-- If there is no tag info, it's a bonus objective
	if (not tagInfo) then
		return "QuestBonusObjective", 21, 21, true;
	end
	
	local isNew = false;
	local originalType = tagInfo.worldQuestType;
	tagInfo.worldQuestType = tagInfo.worldQuestType or _V["WQT_TYPE_BONUSOBJECTIVE"];
	local cachedData = cachedTypeData[tagInfo.worldQuestType];
	if (not cachedData) then 
		-- creating basetype
		cachedTypeData[tagInfo.worldQuestType] = {};
		cachedData = cachedTypeData[tagInfo.worldQuestType];
		isNew = true;
	end
	if (tagInfo.tradeskillLineID) then
		local cachedSubType = cachedData[tagInfo.tradeskillLineID];
		if (not cachedSubType) then 
			-- creating subtype
			cachedData[tagInfo.tradeskillLineID] = {};
			cachedSubType = cachedData[tagInfo.tradeskillLineID];
			isNew = true;
		end
		-- cachedData becomes subtype
		cachedData = cachedSubType;
	end
	
	if (isNew) then
		local atlasTexture, sizeX, sizeY  = QuestUtil.GetWorldQuestAtlasInfo(originalType, false, tagInfo.tradeskillLineID);
		cachedData.texture = atlasTexture;
		cachedData.x = sizeX;
		cachedData.y = sizeY;
	end

	return cachedData.texture or "", cachedData.x or 0, cachedData.y or 0;
end

function WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated)
	local timeLeftMinutes = 0
	local timeLeftSeconds = 0
	local timeString = "";
	local timeStringShort = "";
	local color = _V["WQT_COLOR_CURRENCY"];
	local category = _V["TIME_REMAINING_CATEGORY"].none;
	
	if (not questInfo or not questInfo.questId) then return timeLeftSeconds, timeString, color ,timeStringShort, timeLeftMinutes, category end
	
	-- Time ran out, waiting for an update
	if (questInfo:IsExpired()) then
		timeString = RAID_INSTANCE_EXPIRES_EXPIRED;
		timeStringShort = "Exp."
		color = GRAY_FONT_COLOR;
		return 0, timeString, color,timeStringShort , 0, _V["TIME_REMAINING_CATEGORY"].expired;
	end
	
	timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInfo.questId) or 0;
	timeLeftSeconds =  C_TaskQuest.GetQuestTimeLeftSeconds(questInfo.questId) or 0;
	if ( timeLeftSeconds  and timeLeftSeconds > 0) then
		local displayTime = timeLeftSeconds
		if (displayTime < SECONDS_PER_HOUR  and displayTime >= SECONDS_PER_MIN ) then
			displayTime = displayTime + SECONDS_PER_MIN ;
		end
	
		if ( timeLeftSeconds < WORLD_QUESTS_TIME_CRITICAL_MINUTES * SECONDS_PER_MIN  ) then
			color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeCritical);--RED_FONT_COLOR;
			timeString = SecondsToTime(displayTime, displayTime > SECONDS_PER_MIN  and true or false, unabreviated);
			category = _V["TIME_REMAINING_CATEGORY"].critical;
		elseif displayTime < SECONDS_PER_HOUR   then
			timeString = SecondsToTime(displayTime, true);
			color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeShort);--_V["WQT_ORANGE_FONT_COLOR"];
			category = _V["TIME_REMAINING_CATEGORY"].short
		elseif displayTime < SECONDS_PER_DAY   then
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_HOURS:format(displayTime / SECONDS_PER_HOUR);
			end
			color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeMedium);--_V["WQT_GREEN_FONT_COLOR"];
			category = _V["TIME_REMAINING_CATEGORY"].medium;
		else
			if (fullString) then
				timeString = SecondsToTime(displayTime, true, unabreviated);
			else
				timeString = D_DAYS:format(displayTime / SECONDS_PER_DAY );
			end
			local tagInfo = questInfo:GetTagInfo();
			local isWeek = tagInfo and tagInfo.isElite and tagInfo.quality == Enum.WorldQuestQuality.Epic
			if (isWeek) then
				color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeVeryLong);
				category = _V["TIME_REMAINING_CATEGORY"].veryLong;
			else
				color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeLong);
				category = _V["TIME_REMAINING_CATEGORY"].long;
			end
		end
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	if t and str then
		timeStringShort = t..str;
	end
	
	return timeLeftSeconds, timeString, color, timeStringShort ,timeLeftMinutes, category;
end

function WQT_Utils:GetPinTime(questInfo)
	local seconds, _, color, timeStringShort, _, category = WQT_Utils:GetQuestTimeString(questInfo);
	local start = 0;
	local timeLeft = seconds;
	local total = 0;
	local maxTime, offset;
	if (timeLeft > 0) then
		if timeLeft >= 1440*60 then
			maxTime = 5760*60;
			offset = -720*60;
			local tagInfo = questInfo:GetTagInfo();
			if (timeLeft > maxTime or (tagInfo.isElite and tagInfo.quality == Enum.WorldQuestQuality.Epic)) then
				maxTime = 1440 * 7*60;
				offset = 0;
			end
			
		elseif timeLeft >= 60*59 then --Minute display doesn't start until 59min left
			maxTime = 1440*60;
			offset = 60*60;
		elseif timeLeft >= 15*60 then
			maxTime= 60*60;
			offset = -10*60;
		else
			maxTime = 15*60;
			offset = 0;
		end
		start = (maxTime - timeLeft);
		total = (maxTime + offset);
		timeLeft = (timeLeft + offset);
	end
	return start, total, timeLeft, seconds, color, timeStringShort, category;
end

function WQT_Utils:GetMapInfoForQuest(questId)
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	return WQT_Utils:GetCachedMapInfo(zoneId);
end

function WQT_Utils:ItterateAllBonusObjectivePins(func)
	if(WorldMapFrame.pinPools.BonusObjectivePinTemplate) then
		for mapPin in pairs(WorldMapFrame.pinPools.BonusObjectivePinTemplate.activeObjects) do
			func(mapPin)
		end
	end
	if(WorldMapFrame.pinPools.ThreatObjectivePinTemplate) then
		for mapPin in pairs(WorldMapFrame.pinPools.ThreatObjectivePinTemplate.activeObjects) do
			func(mapPin)
		end
	end
end

-- Copy of QuestUtils_AddQuestRewardsToTooltip to prevent SetTooltipMoney from causing taint 
local function AddQuestRewardsToTooltip(tooltip, questID, style)
	local hasAnySingleLineRewards = false;
	local isWarModeDesired = C_PvP.IsWarModeDesired();
	local questHasWarModeBonus = C_QuestLog.QuestCanHaveWarModeBonus(questID);

	-- xp
	local totalXp, baseXp = GetQuestLogRewardXP(questID);
	if ( baseXp > 0 ) then
		GameTooltip_AddColoredLine(tooltip, BONUS_OBJECTIVE_EXPERIENCE_FORMAT:format(baseXp), HIGHLIGHT_FONT_COLOR);
		if (isWarModeDesired and questHasWarModeBonus) then
			tooltip:AddLine(WAR_MODE_BONUS_PERCENTAGE_XP_FORMAT:format(C_PvP.GetWarModeRewardBonus()));
		end
		hasAnySingleLineRewards = true;
	end
	local artifactXP = GetQuestLogRewardArtifactXP(questID);
	if ( artifactXP > 0 ) then
		GameTooltip_AddColoredLine(tooltip, BONUS_OBJECTIVE_ARTIFACT_XP_FORMAT:format(artifactXP), HIGHLIGHT_FONT_COLOR);
		hasAnySingleLineRewards = true;
	end

	-- currency
	if not style.atLeastShowAzerite then
		local numAddedQuestCurrencies, usingCurrencyContainer = QuestUtils_AddQuestCurrencyRewardsToTooltip(questID, tooltip, tooltip.ItemTooltip);
		if ( numAddedQuestCurrencies > 0 ) then
			hasAnySingleLineRewards = not usingCurrencyContainer or numAddedQuestCurrencies > 1;
		end
	end

	-- honor
	local honorAmount = GetQuestLogRewardHonor(questID);
	if ( honorAmount > 0 ) then
		GameTooltip_AddColoredLine(tooltip, BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT:format("Interface\\ICONS\\Achievement_LegionPVPTier4", honorAmount, HONOR), HIGHLIGHT_FONT_COLOR);
		hasAnySingleLineRewards = true;
	end

	-- money
	local money = GetQuestLogRewardMoney(questID);
	if ( money > 0 ) then
		GameTooltip_AddColoredLine(tooltip, GetMoneyString(money), HIGHLIGHT_FONT_COLOR);
		if (isWarModeDesired and QuestUtils_IsQuestWorldQuest(questID) and questHasWarModeBonus) then
			tooltip:AddLine(WAR_MODE_BONUS_PERCENTAGE_FORMAT:format(C_PvP.GetWarModeRewardBonus()));
		end
		hasAnySingleLineRewards = true;
	end

	-- items
	local showRetrievingData = false;
	local numQuestRewards = GetNumQuestLogRewards(questID);
	local numCurrencyRewards = GetNumQuestLogRewardCurrencies(questID);
	if numQuestRewards > 0 and (not style.prioritizeCurrencyOverItem or numCurrencyRewards == 0) then
		if style.fullItemDescription then
			-- we want to do a full item description
			local itemIndex, rewardType = QuestUtils_GetBestQualityItemRewardIndex(questID);  -- Only support one item reward currently
			if not EmbeddedItemTooltip_SetItemByQuestReward(tooltip.ItemTooltip, itemIndex, questID, rewardType) then
				showRetrievingData = true;
			end
			-- check for item compare input of flag
			if not showRetrievingData then
				if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
					GameTooltip_ShowCompareItem(tooltip.ItemTooltip.Tooltip, tooltip.BackdropFrame);
				else
					for i, tooltip in ipairs(tooltip.ItemTooltip.Tooltip.shoppingTooltips) do
						tooltip:Hide();
					end
				end
			end
		else
			-- we want to do an abbreviated item description
			local name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(1, questID);
			if numItems > 1 then
				text = string.format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(numItems), name);
			elseif texture and name then
				text = string.format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name);
			end
			if text then
				local color = ITEM_QUALITY_COLORS[quality];
				tooltip:AddLine(text, color.r, color.g, color.b);
			end
		end
	end

	-- spells
	local numQuestSpellRewards = GetNumQuestLogRewardSpells(questID);
	if numQuestSpellRewards > 0 and not tooltip.ItemTooltip:IsShown() then
		if not EmbeddedItemTooltip_SetSpellByQuestReward(tooltip.ItemTooltip, 1, questID) then
			showRetrievingData = true;
		end
	end

	-- atLeastShowAzerite: show azerite if nothing else is awarded
	-- and in the case of double azerite, only show the currency container one
	if style.atLeastShowAzerite and not hasAnySingleLineRewards and not tooltip.ItemTooltip:IsShown() then
		local numAddedQuestCurrencies, usingCurrencyContainer = QuestUtils_AddQuestCurrencyRewardsToTooltip(questID, tooltip, tooltip.ItemTooltip);
		if ( numAddedQuestCurrencies > 0 ) then
			hasAnySingleLineRewards = not usingCurrencyContainer or numAddedQuestCurrencies > 1;
			if usingCurrencyContainer and numAddedQuestCurrencies > 1 then
				EmbeddedItemTooltip_Clear(tooltip.ItemTooltip);
				tooltip.ItemTooltip:Hide();
				tooltip:Show();
			end
		end
	end
	return hasAnySingleLineRewards, showRetrievingData;
end

-- Copy of GameTooltip_AddQuestRewardsToTooltip to prevent SetTooltipMoney from causing taint 
function WQT_Utils:AddQuestRewardsToTooltip(tooltip, questID, style)
	style = style or TOOLTIP_QUEST_REWARDS_STYLE_DEFAULT;

	if ( GetQuestLogRewardXP(questID) > 0 or GetNumQuestLogRewardCurrencies(questID) > 0 or GetNumQuestLogRewards(questID) > 0 or
		GetQuestLogRewardMoney(questID) > 0 or GetQuestLogRewardArtifactXP(questID) > 0 or GetQuestLogRewardHonor(questID) > 0 or
		GetNumQuestLogRewardSpells(questID) > 0) then
		if tooltip.ItemTooltip then
			tooltip.ItemTooltip:Hide();
		end

		GameTooltip_AddBlankLinesToTooltip(tooltip, style.prefixBlankLineCount);
		if style.headerText and style.headerColor then
			GameTooltip_AddColoredLine(tooltip, style.headerText, style.headerColor, style.wrapHeaderText);
		end
		GameTooltip_AddBlankLinesToTooltip(tooltip, style.postHeaderBlankLineCount);

		local hasAnySingleLineRewards, showRetrievingData = AddQuestRewardsToTooltip(tooltip, questID, style);

		if hasAnySingleLineRewards and tooltip.ItemTooltip and tooltip.ItemTooltip:IsShown() then
			GameTooltip_AddBlankLinesToTooltip(tooltip, 1);
			if showRetrievingData then
				GameTooltip_AddColoredLine(tooltip, RETRIEVING_DATA, RED_FONT_COLOR);
			end
		end
	end
end

function WQT_Utils:ShowQuestTooltip(button, questInfo)
	WQT:ShowDebugTooltipForQuest(questInfo, button);
	
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");

	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if (not questInfo.questId or not HaveQuestData(questInfo.questId)) then
		GameTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		GameTooltip.recalculatePadding = true;
		GameTooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local tagInfo = questInfo:GetTagInfo();
	local qualityColor = WORLD_QUEST_QUALITY_COLORS[tagInfo and tagInfo.quality or Enum.WorldQuestQuality.Common];
	
	GameTooltip:SetText(title, qualityColor.r, qualityColor.g, qualityColor.b, 1, true);
	
	if ( factionID ) then
		local factionName = GetFactionInfoByID(factionID);
		if ( factionName ) then
			if (capped) then
				GameTooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
			else
				GameTooltip:AddLine(factionName);
			end
		end
	end

	-- Add time
	local seconds, timeString, timeColor, _, _, category = WQT_Utils:GetQuestTimeString(questInfo, true, true)
	if (seconds > 0 or category == _V["TIME_REMAINING_CATEGORY"].expired) then
		timeColor = seconds <= SECONDS_PER_HOUR  and timeColor or NORMAL_FONT_COLOR;
		GameTooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(timeString), timeColor.r, timeColor.g, timeColor.b);
	end

	local numObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questId);
	for objectiveIndex = 1, numObjectives do
		local objectiveText, _, finished = GetQuestObjectiveInfo(questInfo.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local objectiveColor = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			GameTooltip:AddLine(QUEST_DASH .. objectiveText, objectiveColor.r, objectiveColor.g, objectiveColor.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(questInfo.questId);
	if ( percent ) then
		GameTooltip_ShowProgressBar(GameTooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
	end

	if (questInfo.reward.type == WQT_REWARDTYPE.missing) then
		GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	else
		self:AddQuestRewardsToTooltip(GameTooltip, questInfo.questId);
		
		-- reposition compare frame
		if((questInfo.reward.type == WQT_REWARDTYPE.equipment or questInfo.reward.type == WQT_REWARDTYPE.weapon) and GameTooltip.ItemTooltip:IsShown()) then
			if IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems") then
				-- Setup compare tootltips
				GameTooltip_ShowCompareItem(GameTooltip.ItemTooltip.Tooltip);
				
				-- If there is room to the right, give priority to show compare tooltips to the right of the tooltip
				local totalWidth = 0;
				if ( ShoppingTooltip1:IsShown()  ) then
						totalWidth = totalWidth + ShoppingTooltip1:GetWidth();
				end
				if ( ShoppingTooltip2:IsShown()  ) then
						totalWidth = totalWidth + ShoppingTooltip2:GetWidth();
				end
				
				if GameTooltip.ItemTooltip.Tooltip:GetRight() + totalWidth < GetScreenWidth() and ShoppingTooltip1:IsShown() then
					ShoppingTooltip1:ClearAllPoints();
					ShoppingTooltip1:SetPoint("TOPLEFT", GameTooltip.ItemTooltip.Tooltip, "TOPRIGHT");
					
					ShoppingTooltip2:ClearAllPoints();
					ShoppingTooltip2:SetPoint("TOPLEFT", ShoppingTooltip1, "TOPRIGHT");
				end
				
				-- Set higher frame level in case things overlap
				local level = GameTooltip:GetFrameLevel();
				ShoppingTooltip1:SetFrameLevel(level +2);
				ShoppingTooltip2:SetFrameLevel(level +1);
			end
		end
	end

	GameTooltip:Show();
	GameTooltip.recalculatePadding = true;
end

-- Climb map parents until the first continent type map it can find.
function WQT_Utils:GetContinentForMap(mapId) 
	local info = WQT_Utils:GetCachedMapInfo(mapId);
	if not info then return mapId; end
	local parent = info.parentMapID;
	if not parent or info.mapType <= Enum.UIMapType.Continent then 
		return mapId, info.mapType
	end 
	return self:GetContinentForMap(parent) 
end

function WQT_Utils:GetMapWQProvider()
	if WQT.mapWQProvider then return WQT.mapWQProvider; end
	
	for k in pairs(WorldMapFrame.dataProviders) do 
		for k1 in pairs(k) do
			if k1=="IsMatchingWorldMapFilters" then 
				WQT.mapWQProvider = k; 
				break;
			end 
		end 
	end
	return WQT.mapWQProvider;
end

function WQT_Utils:GetFlightWQProvider()
	if (WQT.FlightmapPins) then return WQT.FlightmapPins; end
	if (not FlightMapFrame) then return nil; end
	
	for k in pairs(FlightMapFrame.dataProviders) do 
		if (type(k) == "table") then 
			for k2 in pairs(k) do 
				if (k2 == "activePins") then 
					WQT.FlightmapPins = k;
					break;
				end 
			end 
		end 
	end
	return WQT.FlightmapPins;
end

function WQT_Utils:RefreshOfficialDataProviders()
	-- Have to force remove the WQ data from the map because RefreshAllData doesn't do it
	local mapWQProvider = WQT_Utils:GetMapWQProvider();
	if (mapWQProvider) then
		mapWQProvider:RemoveAllData();
	end
	
	-- If there are no dataproviders, we haven't opened the map yet, so don't force a refresh on it
	if (#WorldMapFrame.dataProviders > 0) then 
		WorldMapFrame:RefreshAllDataProviders();
	end

	-- Flight map world quests
	local flightWQProvider = WQT_Utils:GetFlightWQProvider();
	if (flightWQProvider) then
		flightWQProvider:RemoveAllData();
		flightWQProvider:RefreshAllData();
	end
end

-- Compatibility with the TomTom add-on
function WQT_Utils:AddTomTomArrowByQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			TomTom:AddWaypoint(zoneId, x, y, {["title"] = title, ["crazy"] = true});
		end
	end
end

function WQT_Utils:RemoveTomTomArrowbyQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			local key = TomTom:GetKeyArgs(zoneId, x, y, title);
			local wp = TomTom.waypoints[zoneId] and TomTom.waypoints[zoneId][key];
			if (wp) then
				TomTom:RemoveWaypoint(wp);
			end
		end
	end
end

function WQT_Utils:QuestIncorrectlyCounts(questLogIndex)
	local questInfo = C_QuestLog.GetInfo(questLogIndex);
	if (not questInfo or questInfo.isHeader or questInfo.isTask or questInfo.isBounty) then
		return false, questInfo.isHidden;
	end
	
	local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);

	if (tagInfo and tagInfo.tagID == 102) then
		return true, questInfo.isHidden;
	end
	
end

function WQT_Utils:QuestCountsToCap(questLogIndex)
	local questInfo = C_QuestLog.GetInfo(questLogIndex);
	
	if (not questInfo or questInfo.isHeader or questInfo.isTask or questInfo.isBounty) then
		return false, questInfo.isHidden;
	end
	
	local tagInfo = C_QuestLog.GetQuestTagInfo(questInfo.questID);
	local counts = true;
	
	if (tagInfo and tagInfo.tagID and _V["QUESTS_NOT_COUNTING"][tagInfo.tagID]) then
		counts = false;
	end
	
	return counts, questInfo.isHidden;
end

-- Count quests counting to the quest log cap and collect the ones that shouldn't count
function WQT_Utils:GetQuestLogInfo(list)
	local numEntries, questCount = C_QuestLog.GetNumQuestLogEntries();
	local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept();
	
	if (list) then
		wipe(list);
	end

	for questLogIndex = 1, numEntries do
		-- Remove the ones that shouldn't be counted
		if (WQT_Utils:QuestIncorrectlyCounts(questLogIndex)) then
			questCount = questCount - 1;
			if (list) then
				tinsert(list, questLogIndex);
			end
		end
	end
	
	local color = questCount >= maxQuests and RED_FONT_COLOR or (questCount >= maxQuests-2 and _V["WQT_ORANGE_FONT_COLOR"] or _V["WQT_WHITE_FONT_COLOR"]);
	
	return questCount, maxQuests, color;
end

function WQT_Utils:QuestIsWatchedManual(questId)
	return questId and C_QuestLog.GetQuestWatchType(questId) == Enum.QuestWatchType.Manual;
end

function WQT_Utils:QuestIsWatchedAutomatic(questId)
	return questId and C_QuestLog.GetQuestWatchType(questId) == Enum.QuestWatchType.Automatic;
end

function WQT_Utils:GetQuestMapLocation(questId, mapId)
	local isSameMap = true;
	if (mapId) then
		local mapInfo = WQT_Utils:GetMapInfoForQuest(questId);
		if (not mapInfo) then
			return 0, 0;
		end
		isSameMap = mapInfo.mapID == mapId;
	end
	-- Threat quest specific
	if (isSameMap and C_QuestLog.IsThreatQuest(questId)) then
		local completed, x, y = QuestPOIGetIconInfo(questId);
		if (x and y) then
			return x, y;
		end
	end
	-- General tasks
	local x, y = C_TaskQuest.GetQuestLocation(questId, mapId);
	if (x and y) then
		return x, y;
	end
	-- Could not get a position
	return 0, 0;
end

function WQT_Utils:RewardTypePassesFilter(rewardType) 
	local rewardFilters = WQT.settings.filters[_V["FILTER_TYPES"].reward].flags;
	if(rewardType == WQT_REWARDTYPE.equipment or rewardType == WQT_REWARDTYPE.weapon) then
		return rewardFilters.Armor;
	end
	if(rewardType == WQT_REWARDTYPE.spell or rewardType == WQT_REWARDTYPE.item) then
		return rewardFilters.Item;
	end
	if(rewardType == WQT_REWARDTYPE.gold) then
		return rewardFilters.Gold;
	end
	if(rewardType == WQT_REWARDTYPE.currency) then
		return rewardFilters.Currency;
	end
	if(rewardType == WQT_REWARDTYPE.artifact) then
		return rewardFilters.Artifact;
	end
	if(rewardType == WQT_REWARDTYPE.relic) then
		return rewardFilters.Relic;
	end
	if(rewardType == WQT_REWARDTYPE.xp) then
		return rewardFilters.Experience;
	end
	if(rewardType == WQT_REWARDTYPE.honor) then
		return rewardFilters.Honor ;
	end
	if(rewardType == WQT_REWARDTYPE.reputation) then
		return rewardFilters.Reputation;
	end

	return true;
end

function WQT_Utils:GetQuestRewardIcon(questID)
	local texture;
	-- Item
	texture = select(2, GetQuestLogRewardInfo(1, questID));
	if (texture) then return texture; end
	-- Spell
	texture = GetQuestLogRewardSpell(1, questID);
	if (texture) then return texture; end
	-- Honor
	if (GetQuestLogRewardHonor(questID) > 0) then return 1455894 end;
	-- Gold
	if (GetQuestLogRewardMoney(questID) > 0) then return 133784 end;
	-- Currency
	local _, _, amount, currencyId = GetQuestLogRewardCurrencyInfo(1, questID);
	if (currencyId) then
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId);
		texture = select(2, CurrencyContainerUtil.GetCurrencyContainerInfo(currencyId, amount, currencyInfo.name, currencyInfo.iconFileID, currencyInfo.quality));
		if (texture) then return texture; end
	end
end

function WQT_Utils:CalculateWarmodeAmount(rewardType, amount)
	if (C_PvP.IsWarModeDesired() and _V["WARMODE_BONUS_REWARD_TYPES"][rewardType]) then
		amount = amount + floor(amount * C_PvP.GetWarModeRewardBonus() / 100);
	end
	return amount;
end

function WQT_Utils:DeepWipeTable(t)
	for k, v in pairs(t) do
		if (type(v) == "table") then
			self:DeepWipeTable(v)
		end
	end
	wipe(t);
	t = nil;
end

local FORMAT_VERSION_MINOR = "%s|cFF888888.%s|r"
local FORMAT_H1 = "%s<h1 align='center'>%s</h1>";
local FORMAT_H2 = "%s<h2>%s:</h2>";
local FORMAT_p = "%s<p>%s</p>";
local FORMAT_WHITESPACE = "%s<h3>&#160;</h3>"

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

function WQT_Utils:FormatPatchNotes(notes, title)
	local updateMessage = "<html><body><h3>&#160;</h3>";
	updateMessage = FORMAT_H1:format(updateMessage, title);
	updateMessage = FORMAT_WHITESPACE:format(updateMessage);
	for i=1, #notes do
		local patch = notes[i];
		local version = patch.minor and FORMAT_VERSION_MINOR:format(patch.version, patch.minor) or patch.version;
		updateMessage = FORMAT_H1:format(updateMessage, version);
		updateMessage = AddNotes(updateMessage, nil, patch.intro);
		updateMessage = AddNotes(updateMessage, "New", patch.new);
		updateMessage = AddNotes(updateMessage, "Changes", patch.changes);
		updateMessage = AddNotes(updateMessage, "Fixes", patch.fixes);
	end
	return updateMessage .. "</body></html>";
end

function WQT_Utils:RegisterExternalSettings(key, defaults)
	return WQT_Profiles:RegisterExternalSettings(key, defaults);
end

function WQT_Utils:AddExternalSettingsOptions(settings)
	WQT_SettingsFrame:AddSettingList(settings);
end

function WQT_Utils:FilterIsOldContent(typeID, flagID)
	local typeList = _V["FILTER_TYPE_OLD_CONTENT"][typeID];
	if (typeList) then
		return typeList[flagID];
	end
	return false;
end

function WQT_Utils:GetRewardIconInfo(rewardType, subType)
	if (not rewardType) then return; end

	local rewardTypeAtlas = _V["REWARD_TYPE_ATLAS"][rewardType];
	if (rewardTypeAtlas and not rewardTypeAtlas.texture) then
		rewardTypeAtlas = rewardTypeAtlas[subType];
	end
	
	return rewardTypeAtlas;
end

function WQT_Utils:HandleQuestClick(frame, questInfo, button)
	if (not questInfo or not questInfo.questId) then return end
	
	local questID =  questInfo.questId;
	local isBonus = QuestUtils_IsQuestBonusObjective(questID);
	local reward = questInfo:GetReward(1);
	local tagInfo = questInfo:GetTagInfo();
	local isWorldQuest = not isBonus and tagInfo and tagInfo.worldQuestType;
	local playSound = true;
	local soundID = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON;
	
	if (button == "LeftButton") then
		if (IsModifiedClick("QUESTWATCHTOGGLE")) then
			-- 'Hard' tracking quests with shift
			if (isWorldQuest) then
				if (not ChatEdit_TryInsertQuestLinkForQuestID(questID)) then 
					if (QuestUtils_IsQuestWatched(questID)) then
						local hardWatched = WQT_Utils:QuestIsWatchedManual(questID);
						C_QuestLog.RemoveWorldQuestWatch(questID);
						-- If it wasn't actually hard watched, do so now
						if (not hardWatched) then
							C_QuestLog.AddWorldQuestWatch(questID, Enum.QuestWatchType.Manual);
							C_SuperTrack.SetSuperTrackedQuestID(questID);
						end
					else
						C_QuestLog.AddWorldQuestWatch(questID, Enum.QuestWatchType.Manual);
						C_SuperTrack.SetSuperTrackedQuestID(questID);
					end
				end
			else
				playSound = false;
			end
		elseif (IsModifiedClick("DRESSUP")) then
			-- Trying gear with Ctrl
			questInfo:TryDressUpReward();
			playSound = false;
		else
			-- 'Soft' tracking and jumping map to relevant zone
			-- Don't track bonus objectives. The object tracker doesn't like it;
			if (isWorldQuest) then	
				local hardWatched = WQT_Utils:QuestIsWatchedManual(questID);
				-- if it was hard watched, keep it that way
				if (not hardWatched) then
					C_QuestLog.AddWorldQuestWatch(questID, Enum.QuestWatchType.Automatic);
				end
				C_SuperTrack.SetSuperTrackedQuestID(questID);
			end
			if (WorldMapFrame:IsShown()) then
				local zoneID =  C_TaskQuest.GetQuestZoneID(questID);
				if (WorldMapFrame:GetMapID() ~= zoneID) then
					WorldMapFrame:SetMapID(zoneID);
				end
			end
		end
		
	
	elseif (button == "RightButton") then
		if (IsModifiedClick("STICKYCAMERA")) then
			-- Set waypoint at location
			questInfo:SetAsWaypoint();
			C_SuperTrack.SetSuperTrackedUserWaypoint(true);
			soundID = SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE;
		elseif(IsModifiedClick("QUESTWATCHTOGGLE")) then
			local dislike = not WQT_Utils:QuestIsDisliked(questID);
			WQT_Utils:SetQuestDisliked(questID, dislike);
			
			playSound = false;
		else
			-- Context menu
			ADD:CursorDropDown(frame, function(...) WQT:TrackDDFunc(...) end);
		end
	end

	if (playSound) then
		PlaySound(soundID, nil, false);
	end
end

function WQT_Utils:QuestIsDisliked(questID)
	return WQT.settings.general.dislikedQuests[questID] and true or false;
end

function WQT_Utils:SetQuestDisliked(questID, isDisliked)
	if (not isDisliked) then
		isDisliked = nil;
	end
	
	WQT.settings.general.dislikedQuests[questID] = isDisliked;
	
	WQT_QuestScrollFrame:UpdateQuestList();
	
	local soundID;
	if (isDisliked) then
		soundID = SOUNDKIT.UI_70_ARTIFACT_FORGE_APPEARANCE_LOCKED;
	else
		soundID = SOUNDKIT.UI_70_ARTIFACT_FORGE_APPEARANCE_APPEARANCE_CHANGE;
	end
	PlaySound(soundID, nil, false);
end 

--------------------------
-- Colors
--------------------------

local _Colors = {}

local function ExtractColorValueFromHex(str, index)
	return tonumber(str:sub(index, index + 1), 16) / 255;
end

function WQT_Utils:LoadColors()
	local count = 1;
	for colorID, hex in pairs(WQT.settings.colors) do
		-- Create enum index
		_V["COLOR_IDS"][colorID] = count;
		-- assign color to index
		_Colors[count] =  CreateColorFromHexString(hex);
		
		count = count + 1 ;
	end
end

function WQT_Utils:UpdateColor(colorID, r, g, b, a)
	local color = _Colors[colorID];
	if (not color) then return; end

	if (type(r) == "string") then
		local hex = r;
		a, r, g, b = ExtractColorValueFromHex(hex, 1), ExtractColorValueFromHex(hex, 3), ExtractColorValueFromHex(hex, 5), ExtractColorValueFromHex(hex, 7);
	end
	
	color:SetRGBA(r, g, b, a);
	
	return color;
end

function WQT_Utils:GetColor(colorID)
	return _Colors[colorID] or WHITE_FONT_COLOR;
end

function WQT_Utils:GetRewardTypeColorIDs(rewardType)
	local colorIDs = _V["COLOR_IDS"];
	local ring = colorIDs.rewardItem;
	local text = colorIDs.rewardItem;
	
	if (rewardType == WQT_REWARDTYPE.none) then
		ring = colorIDs.rewardNone;
	elseif (rewardType == WQT_REWARDTYPE.weapon) then
		ring = colorIDs.rewardWeapon;
		text = colorIDs.rewardTextWeapon;
	elseif (rewardType == WQT_REWARDTYPE.equipment) then
		ring = colorIDs.rewardArmor;
		text = colorIDs.rewardTextArmor;
	elseif (rewardType == WQT_REWARDTYPE.conduit) then
		ring = colorIDs.rewardConduit;
		text = colorIDs.rewardTextConduit;
	elseif (rewardType == WQT_REWARDTYPE.relic) then
		ring = colorIDs.rewardRelic;
		text = colorIDs.rewardTextRelic;
	elseif (rewardType == WQT_REWARDTYPE.anima) then
		ring = colorIDs.rewardAnima;
		text = colorIDs.rewardTextAnima;
	elseif (rewardType == WQT_REWARDTYPE.artifact) then
		ring = colorIDs.rewardArtifact;
		text = colorIDs.rewardTextArtifact;
	elseif (rewardType == WQT_REWARDTYPE.spell) then
		ring = colorIDs.rewardSpell;
		text = colorIDs.rewardTextSpell;
	elseif (rewardType == WQT_REWARDTYPE.item) then
		ring = colorIDs.rewardItem;
		text = colorIDs.rewardTextItem;
	elseif (rewardType == WQT_REWARDTYPE.gold) then
		ring = colorIDs.rewardGold;
		text = colorIDs.rewardTextGold;
	elseif (rewardType == WQT_REWARDTYPE.currency) then
		ring = colorIDs.rewardCurrency;
		text = colorIDs.rewardTextCurrency;
	elseif (rewardType == WQT_REWARDTYPE.honor) then
		ring = colorIDs.rewardHonor;
		text = colorIDs.rewardTextHonor;
	elseif (rewardType == WQT_REWARDTYPE.reputation) then
		ring = colorIDs.rewardReputation;
		text = colorIDs.rewardTextReputation;
	elseif (rewardType == WQT_REWARDTYPE.xp) then
		ring = colorIDs.Xp;
		text = colorIDs.rewardTextXp;
	elseif (rewardType == WQT_REWARDTYPE.missing) then
		ring = colorIDs.rewardMissing;
	end
	
	return self:GetColor(ring), self:GetColor(text);
end


