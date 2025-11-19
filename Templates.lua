local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Profiles = addon.WQT_Profiles;

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
	self:SetIconColorRGBA(color:GetRGB());
end

function WQT_MiniIconMixin:SetIconColorRGBA(r, g, b, a)
	self.r = r;
	self.g = g;
	self.b = b;
	self.hasCustomColor = true;
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
		if(self.hasCustomColor) then
			r, g, b = self.r, self.g, self.b;
		elseif (self.left) then
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
		self.container:SetShown(self.isSelected);
		if (self.Arrow) then
			self.Arrow:SetAtlas(self.isSelected and "common-icon-backarrow" or "common-icon-forwardarrow");
		end
		if (self.ActiveTexture) then
			self.ActiveTexture:SetShown(self.isSelected);
		end
	end
end

function WQT_ContainerButtonMixin:OnMouseDown()
	if (not self.Icons) then return end
	local offset = self.pressOffset or 2;
	for k, frame in ipairs(self.Icons) do
		frame:AdjustPointsOffset(offset, -offset);
	end
end

function WQT_ContainerButtonMixin:OnMouseUp()
	if (not self.Icons) then return end
	local offset = self.pressOffset or 2;
	for k, frame in ipairs(self.Icons) do
		frame:AdjustPointsOffset(-offset, offset);
	end
end

function WQT_ContainerButtonMixin:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(WQT_WORLD_QUEST_TAB);
	GameTooltip:Show();
end

function WQT_ContainerButtonMixin:OnLeave()
	GameTooltip:Hide();
end

WQT_WorldMapContainerButtonMixin = CreateFromMixins(WQT_ContainerButtonMixin);

function WQT_WorldMapContainerButtonMixin:Refresh() end

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
-- Layout Frames
----------------------------

local function IsLayoutFrame(frame)
	return frame.IsLayoutFrame and frame:IsLayoutFrame();
end


local noTableGetLayoutChildrenMixin = {}

-- Replace GetLayout to not create a table every time
function noTableGetLayoutChildrenMixin:GetLayoutChildren()
	if (not self.children) then
		self.children = {};
	end
	wipe(self.children);
	local children = self.children;
	self:AddLayoutChildren(children, self:GetChildren());
	self:AddLayoutChildren(children, self:GetRegions());
	self:AddLayoutChildren(children, self:GetAdditionalRegions());
	if not self:IgnoreLayoutIndex() then
		table.sort(children, LayoutIndexComparator);
	end

	return children;
end

WQT_HorizontalLayoutMixin = CreateFromMixins(HorizontalLayoutMixin, noTableGetLayoutChildrenMixin);


-- Arranges children right to left bottom to top with 'stride' children per column
-- A child's strideSize determines how many spaces it will take up per column
-- This is bare minimum for a for a specific use case
WQT_GridLayoutMixin = CreateFromMixins(LayoutMixin, noTableGetLayoutChildrenMixin);

function WQT_GridLayoutMixin:GetChildStrideSize(child)
	return child.strideSize or 1;
end

function WQT_GridLayoutMixin:GetStride()
	return self.stride or 1;
end

function WQT_GridLayoutMixin:LayoutChildren(children, expandToWidth, expandToHeight)
	local frameLeftPadding, frameRightPadding, frameTopPadding, frameBottomPadding = self:GetPadding();
	local spacing = self.spacing or 0;
	local stride = self:GetStride();
	local childrenWidth, childrenHeight = 0, 0;
	local hasExpandableChild = false;

	local totalStride = 0;
	local columnMax = 0;
	local columCurrent = 0;
	local rightOffset = 0;
	local columnHeight = 0;
	local columnWidth = 0;

	for i, child in ipairs(children) do
		if (not self.skipChildLayout and IsLayoutFrame(child)) then
			child:Layout();
		end

		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetChildPadding(child);
		local childWidth, childHeight = self:GetChildSize(child);
		local strideSize = min(self:GetChildStrideSize(child), stride);

		if (totalStride % stride == 0) then
			childrenWidth = childrenWidth + columnWidth;
			rightOffset = childrenWidth;
			columnHeight = 0;
			columnWidth = 0;
		end

		columnWidth = max(columnWidth, childWidth + leftPadding + rightPadding);

		child:ClearAllPoints();
		child:SetPoint("BOTTOMRIGHT", self, -rightOffset - frameRightPadding - rightPadding, columnHeight + bottomPadding);

		columnHeight = columnHeight + childHeight + bottomPadding + topPadding;
		childrenHeight = max(childrenHeight, columnHeight);

		columnMax = max(columnMax, columCurrent)
		totalStride = totalStride + strideSize;
	end

	childrenWidth = childrenWidth + columnWidth;

	return childrenWidth, childrenHeight, hasExpandableChild;
end

-- Allow children to spread across the space left over in the parent's size
-- If a parent has size 150, a child with size 30, a child with flexSize 2, and a child with flexSize 3
-- The children would end up with sizes 30, 48 (2/5*120), 72 (3/5*120)
local flexLayoutFrame = CreateFromMixins(LayoutMixin, noTableGetLayoutChildrenMixin);

function flexLayoutFrame:GetChildFlexSize(child)
	return child.flexSize or 0;
end

WQT_HorizontalFlexLayoutMixin = CreateFromMixins(flexLayoutFrame);

function WQT_HorizontalFlexLayoutMixin:LayoutChildren(children, expandToWidth, expandToHeight)
	local leftOffset, rightOffset, frameTopPadding, frameBottomPadding = self:GetPadding();
	local spacing = self.spacing or 0;
	local hasExpandableChild = false;

	local availableFlexSpace = self:GetWidth() - leftOffset - rightOffset;
	local totalflexSize = 0;

	for i, child in ipairs(children) do
		if (not self.skipChildLayout and IsLayoutFrame(child)) then
			child:Layout();
		end

		local flexSize = self:GetChildFlexSize(child);
		if (flexSize > 0) then
			totalflexSize = totalflexSize + self:GetChildFlexSize(child);
		else
			availableFlexSpace = availableFlexSpace - self:GetChildWidth(child);
		end

		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetChildPadding(child);
		availableFlexSpace = availableFlexSpace - leftPadding - rightPadding;
		if (i > 1) then
			availableFlexSpace = availableFlexSpace - spacing;
		end
	end

	local flexSpaceChunk = totalflexSize > 1 and availableFlexSpace / totalflexSize or availableFlexSpace;

	for i, child in ipairs(children) do
		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetChildPadding(child);
		local childWidth, childHeight = self:GetChildSize(child);

		if (child.expand) then
			hasExpandableChild = true;

			if expandToHeight then
				childHeight = expandToHeight - topPadding - bottomPadding - frameTopPadding - frameBottomPadding;
				child:SetHeight(childHeight);
				

				local ignoreRectYes = true;
				childWidth = self:GetChildWidth(child, ignoreRectYes);
			end
		end

		local flexSize = self:GetChildFlexSize(child);
		if (flexSize > 0) then
			childWidth = flexSize * flexSpaceChunk;
			
			child:SetWidth(childWidth);
			if (IsLayoutFrame(child)) then
				child:SetFixedWidth(childWidth);
				if (not self.skipChildLayout) then
					child:Layout();
				end
			end
		end

		child:ClearAllPoints();

		leftOffset = leftOffset + leftPadding;
		if (child.align == "bottom") then
			local bottomOffset = frameBottomPadding + bottomPadding;
			child:SetPoint("BOTTOMLEFT", leftOffset, bottomOffset);
		elseif (child.align == "center") then
			local topOffset = (frameTopPadding - frameBottomPadding + topPadding - bottomPadding) / 2;
			child:SetPoint("LEFT", leftOffset, -topOffset);
		else
			local topOffset = frameTopPadding + topPadding;
			child:SetPoint("TOPLEFT", leftOffset, -topOffset);
		end
		leftOffset = leftOffset + childWidth + rightPadding + spacing;
	end

	return self:GetWidth(), self:GetHeight(), hasExpandableChild;
end



WQT_VerticalFlexLayoutMixin = CreateFromMixins(flexLayoutFrame);

function WQT_VerticalFlexLayoutMixin:LayoutChildren(children, expandToWidth, expandToHeight)
	local frameLeftPadding, frameRightPadding, frameTopPadding, frameBottomPadding = self:GetPadding();
	local spacing = self.spacing or 0;
	local hasExpandableChild = false;
	local availableFlexSpace = self:GetHeight() - frameTopPadding - frameBottomPadding;
	local totalflexSize = 0;

	for i, child in ipairs(children) do
		if (not self.skipChildLayout and IsLayoutFrame(child)) then
			child:Layout();
		end

		local flexSize = self:GetChildFlexSize(child);
		if (flexSize > 0) then
			totalflexSize = totalflexSize + self:GetChildFlexSize(child);
		else
			availableFlexSpace = availableFlexSpace - self:GetChildHeight(child);
		end

		local _, _, topPadding, bottomPadding = self:GetChildPadding(child);
		availableFlexSpace = availableFlexSpace - topPadding - bottomPadding;
		if (i > 1) then
			availableFlexSpace = availableFlexSpace - spacing;
		end
	end

	local flexSpaceChunk = totalflexSize > 1 and availableFlexSpace / totalflexSize or availableFlexSpace;

	for i, child in ipairs(children) do
		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetChildPadding(child);
		local childWidth, childHeight = self:GetChildSize(child);

		if (child.expand) then
			hasExpandableChild = true;

			if (expandToWidth) then
				childWidth = expandToWidth - leftPadding - rightPadding - frameLeftPadding - frameRightPadding;
				child:SetWidth(childWidth);

				local ignoreRectYes = true;
				childHeight = self:GetChildHeight(child, ignoreRectYes);
			end
		end

		local flexSize = self:GetChildFlexSize(child);
		if (flexSize > 0) then
			childHeight = flexSize * flexSpaceChunk;
			
			child:SetHeight(childHeight);
			if (IsLayoutFrame(child)) then
				child:SetFixedHeight(childHeight);
				if (not self.skipChildLayout) then
					child:Layout();
				end
			end
		end

		child:ClearAllPoints();

		frameTopPadding = frameTopPadding + topPadding;
		if (child.align == "right") then
			local rightOffset = frameRightPadding + rightPadding;
			child:SetPoint("TOPRIGHT", -rightOffset, -frameTopPadding);
		elseif (child.align == "center") then
			local leftOffset = (frameLeftPadding - frameRightPadding + leftPadding - rightPadding) / 2;
			child:SetPoint("TOP", leftOffset, -frameTopPadding);
		else
			local leftOffset = frameLeftPadding + leftPadding;
			child:SetPoint("TOPLEFT", leftOffset, -frameTopPadding);
		end

		-- Determine topOffset for next frame
		frameTopPadding = frameTopPadding + childHeight + bottomPadding + spacing;
	end

	return self:GetWidth(), self:GetHeight(), hasExpandableChild;
end


----------------------------
-- Utilities
----------------------------

local cachedTypeData = {};
local cachedZoneInfo = {};

local function stringVersionToNumber(s)
	local a, b, c = strmatch(s, "(%d+)%.(%d+)%.(%d+)");
	if (not a) then return 0; end
	return tonumber(a) * 10000 +  tonumber(b) * 100 +  tonumber(c);
end

function WQT_Utils:GetAddonVersion()
	local version = C_AddOns.GetAddOnMetadata(addonName, "version");
	return stringVersionToNumber(version);
end

function WQT_Utils:GetSettingsVersion()
	local version = WQT.db.global.versionCheck or 0;

	if (type(version) == "string") then
		local number = stringVersionToNumber(version);
		return number, version;
	end

	return version;
end

function WQT_Utils:ExternalMightLoad(addonName)
	return C_AddOns.IsAddOnLoaded(addonName) or C_AddOns.IsAddOnLoadOnDemand(addonName);
end

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
		local data = C_Reputation.GetFactionDataByID(id);
		factionData[id] = { ["expansion"] = 0,["faction"] = nil ,["texture"] = 1103069, ["unknown"] = true, ["name"] = data and data.name or "Unknown Faction" };
		WQT:DebugPrint("Added new faction", factionData[id].name);
	end
	
	return factionData[id];
end

function WQT_Utils:GetCachedTypeIconData(questInfo)
	local tagInfo = questInfo:GetTagInfo();
	-- If there is no tag info, it's a bonus objective
	if (questInfo.isBonusQuest or not tagInfo) then
		return "Bonus-Objective-Star", 16, 16, false;
	end
	
	local tagID = tagInfo.tagID or 0;
	local cachedData = cachedTypeData[tagID];
	if (not cachedData) then 
		-- creating basetype
		cachedData = {};
		local atlasTexture, sizeX, sizeY = QuestUtil.GetWorldQuestAtlasInfo(questInfo.questID, tagInfo);
		cachedData.texture = atlasTexture;
		cachedData.x = sizeX;
		cachedData.y = sizeY;
		
		cachedTypeData[tagID] = cachedData;
	end

	return cachedData.texture or "", cachedData.x or 0, cachedData.y or 0;
end

function WQT_Utils:GetQuestTimeString(questInfo, fullString, unabreviated)
	local timeLeftMinutes = 0
	local timeLeftSeconds = 0
	local timeString = "";
	local timeStringShort = "";
	local color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeNone);
	local category = _V["TIME_REMAINING_CATEGORY"].none;
	
	if (not questInfo or not questInfo.questID) then return timeLeftSeconds, timeString, color ,timeStringShort, timeLeftMinutes, category end
	
	-- Time ran out, waiting for an update
	if (questInfo:IsExpired()) then
		timeString = RAID_INSTANCE_EXPIRES_EXPIRED;
		timeStringShort = "Exp."
		color = GRAY_FONT_COLOR;
		return 0, timeString, color,timeStringShort , 0, _V["TIME_REMAINING_CATEGORY"].expired;
	end
	
	timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questInfo.questID) or 0;
	timeLeftSeconds = C_TaskQuest.GetQuestTimeLeftSeconds(questInfo.questID) or 0;
	if ( timeLeftSeconds and timeLeftSeconds > 0) then
		local displayTime = timeLeftSeconds
		if (displayTime < SECONDS_PER_HOUR  and displayTime >= SECONDS_PER_MIN ) then
			displayTime = displayTime + SECONDS_PER_MIN ;
		end
	
		if ( timeLeftSeconds < WORLD_QUESTS_TIME_CRITICAL_MINUTES * SECONDS_PER_MIN  ) then
			color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeCritical);--RED_FONT_COLOR;
			timeString = SecondsToTime(displayTime, displayTime > SECONDS_PER_MIN and (not fullString) or false, unabreviated);
			category = _V["TIME_REMAINING_CATEGORY"].critical;
		elseif displayTime < SECONDS_PER_HOUR   then
			timeString = SecondsToTime(displayTime, not fullString, unabreviated);
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
			if (timeLeft > maxTime or (tagInfo and tagInfo.isElite and tagInfo.quality == Enum.WorldQuestQuality.Epic)) then
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

function WQT_Utils:TimeLeftToUpdateTime(timeLeft, showingSecondary)
	if (timeLeft and timeLeft > 0) then
		local minutesForUpdatePerSecond = showingSecondary and 60 or 2;
		return timeLeft > SECONDS_PER_MIN * minutesForUpdatePerSecond and SECONDS_PER_MIN or 1;
	end

	return 0;
end

function WQT_Utils:ShowQuestTooltip(button, questInfo, style, xOffset, yOffset)
	style = style or _V["TOOLTIP_STYLES"].default;
	WQT:ShowDebugTooltipForQuest(questInfo, button);

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT", xOffset or 0, yOffset or 0);
	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if (not questInfo.questID or not HaveQuestData(questInfo.questID)) then
		GameTooltip_SetTitle(GameTooltip, RETRIEVING_DATA, RED_FONT_COLOR);
		GameTooltip_SetTooltipWaitingForData(GameTooltip, true);
		GameTooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questID);
	local tagInfo = questInfo:GetTagInfo();
	local qualityColor = WORLD_QUEST_QUALITY_COLORS[tagInfo and tagInfo.quality or Enum.WorldQuestQuality.Common];

	-- title
	GameTooltip_SetTitle(GameTooltip, title, qualityColor.color, true);
	
	-- type
	if (not style.hideType) then
		if (tagInfo and tagInfo.worldQuestType) then
			QuestUtils_AddQuestTypeToTooltip(GameTooltip, questInfo.questID, NORMAL_FONT_COLOR);
		end
	end
	
	-- faction
	if ( factionID ) then
		local factionData = C_Reputation.GetFactionDataByID(factionID)
		local factionName = factionData and factionData.name;
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
		timeColor = seconds <= SECONDS_PER_HOUR and timeColor or HIGHLIGHT_FONT_COLOR;
		timeString = timeColor:WrapTextInColorCode(timeString);
		GameTooltip_AddNormalLine(GameTooltip, MAP_TOOLTIP_TIME_LEFT:format(timeString));
	end

	if (not style.hideObjectives) then
		local numObjectives = C_QuestLog.GetNumQuestObjectives(questInfo.questID);
		for objectiveIndex = 1, numObjectives do
			local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(questInfo.questID, objectiveIndex, false);
	
			if ( objectiveText and #objectiveText > 0 ) then
				local objectiveColor = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
				GameTooltip:AddLine(QUEST_DASH .. objectiveText, objectiveColor.r, objectiveColor.g, objectiveColor.b, true);
			end
			-- Add a progress bar if that's the type
			if(objectiveType == "progressbar") then
				local percent = GetQuestProgressBarPercent(questInfo.questID);
				GameTooltip_ShowProgressBar(GameTooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
			end
		end
	end
	
	if (questInfo.reward.type == WQT_REWARDTYPE.missing) then
		GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	elseif (questInfo:GetReward(1)) then
		GameTooltip_AddBlankLinesToTooltip(GameTooltip, style.prefixBlankLineCount);
		if style.headerText and style.headerColor then
			GameTooltip_AddColoredLine(GameTooltip, style.headerText, style.headerColor, style.wrapHeaderText);
		end
		GameTooltip_AddBlankLinesToTooltip(GameTooltip, style.postHeaderBlankLineCount);
		QuestUtils_AddQuestRewardsToTooltip(GameTooltip, questInfo.questID, style);
	end

	GameTooltip:Show();
end

-- Climb map parents until the first continent type map it can find.
function WQT_Utils:GetContinentForMap(mapId) 
	local info = WQT_Utils:GetCachedMapInfo(mapId);
	if not info then return mapId; end
	local parent = info.parentMapID;
	if not parent or info.mapType <= Enum.UIMapType.Continent then
		return mapId, info.mapType
	end
	return self:GetContinentForMap(parent);
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
	
	local wqPinTemplate = FlightMap_WorldQuestDataProviderMixin:GetPinTemplate();

	for k in pairs(FlightMapFrame.dataProviders) do
		if (k.GetPinTemplate and k:GetPinTemplate() == wqPinTemplate) then
			WQT.FlightmapPins = k;
			break;
		end
	end
	return WQT.FlightmapPins;
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

function WQT_Utils:CalculateWarmodeAmount(rewardInfo)
	if (not rewardInfo) then return 0; end

	local amount = rewardInfo.amount or 1;

	if (not C_PvP.IsWarModeDesired()) then
		return amount;
	end

	local isCurrencyType = rewardInfo.type == WQT_REWARDTYPE.currency or rewardInfo.type == WQT_REWARDTYPE.artifact;
	local isWarmodeRewardType =	isCurrencyType or rewardInfo.type == WQT_REWARDTYPE.gold or rewardInfo.type == WQT_REWARDTYPE.currency;

	if (not isWarmodeRewardType) then
		return amount;
	end

	if (isCurrencyType and rewardInfo.id
		and (not C_CurrencyInfo.DoesWarModeBonusApply(rewardInfo.id)
			or C_CurrencyInfo.GetFactionGrantedByCurrency(rewardInfo.id))) then
		return amount;
	end

	return amount + floor(amount * C_PvP.GetWarModeRewardBonus() / 100);
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

function WQT_Utils:RegisterExternalSettings(key, defaults)
	return WQT_Profiles:RegisterExternalSettings(key, defaults);
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

local function AddInstructionTooltipToDropdownItem(item, text)
	item:SetOnEnter(function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
			GameTooltip_AddInstructionLine(GameTooltip, text);
			GameTooltip:Show();
		end);
	
	item:SetOnLeave(function(button)
			GameTooltip:Hide();
		end);
end

local function QuestContextSetup(frame, rootDescription, questInfo)
	rootDescription:SetTag("WQT_QUEST_CONTEXTMENU", questInfo);

	-- Title
	rootDescription:CreateTitle(questInfo.title);

	-- Tracking here
	if (questInfo.tagInfo and questInfo.tagInfo.worldQuestType) then
		local title = ""
		local func = nil;
		
		if (QuestUtils_IsQuestWatched(questInfo.questID)) then
			title = UNTRACK_QUEST;
			func = function()
						C_QuestLog.RemoveWorldQuestWatch(questInfo.questID);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_ListContainer:DisplayQuestList();
						end
					end
		else
			title = TRACK_QUEST;
			func = function()
						C_QuestLog.AddWorldQuestWatch(questInfo.questID, Enum.QuestWatchType.Manual);
						C_SuperTrack.SetSuperTrackedQuestID(questInfo.questID);
						if WQT_WorldQuestFrame:GetAlpha() > 0 then 
							WQT_ListContainer:DisplayQuestList();
						end
					end
		end	
		local trackBtn = rootDescription:CreateButton(title, func);
		AddInstructionTooltipToDropdownItem(trackBtn, _L["SHORTCUT_TRACK"]);
	end

	-- 9.0 waypoint
	local waypointBtn = rootDescription:CreateButton(
		_L["PLACE_MAP_PIN"],
		function()
			questInfo:SetAsWaypoint();
			C_SuperTrack.SetSuperTrackedUserWaypoint(true);
		end);
	AddInstructionTooltipToDropdownItem(waypointBtn, _L["SHORTCUT_WAYPOINT"]);

	-- Uninterested
	local checkbox = rootDescription:CreateCheckbox(
		_L["UNINTERESTED"],
		function()
			 return WQT_Utils:QuestIsDisliked(questInfo.questID);
		end,
		function()
			local dislike = not WQT_Utils:QuestIsDisliked(questInfo.questID);
 			WQT_Utils:SetQuestDisliked(questInfo.questID, dislike);
		end
	);
	AddInstructionTooltipToDropdownItem(checkbox, _L["SHORTCUT_DISLIKE"]);

	-- Cancel. apparently a function is required for it to close the menu on click
	rootDescription:CreateButton(CANCEL, function() end);
end

function WQT_Utils:HandleQuestClick(frame, questInfo, button)
	if (not questInfo or not questInfo.questID) then return end
	
	local questID =  questInfo.questID;
	local isBonus = QuestUtils_IsQuestBonusObjective(questID);
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
					if(InCombatLockdown()) then
						if(not WQT.combatLockWarned) then
							WQT.combatLockWarned = true;
							print(string.format("|cFFFF5555WQT: %s|r", _L["COMBATLOCK_MAP_CHANGE"]));
						end
					else
						C_Map.OpenWorldMap(zoneID);
					end
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
			MenuUtil.CreateContextMenu(frame, QuestContextSetup, questInfo);
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
	
	WQT_CallbackRegistry:TriggerEvent("WQT.FiltersUpdated");
	
	local soundID;
	if (isDisliked) then
		soundID = SOUNDKIT.UI_70_ARTIFACT_FORGE_APPEARANCE_LOCKED;
	else
		soundID = SOUNDKIT.UI_70_ARTIFACT_FORGE_APPEARANCE_APPEARANCE_CHANGE;
	end
	PlaySound(soundID, nil, false);
end 

function WQT_Utils:EnsureBountyBoards()
	if (not self.bountyBoards) then
		self.bountyBoards = {};
		self.oldBountyBoard = nil;
		self.newBountyBoard = nil;
		for k, overlayFrame in ipairs(WorldMapFrame.overlayFrames) do
			if (overlayFrame.SetNextMapForSelectedBounty) then
				tinsert(self.bountyBoards, overlayFrame);
				if (overlayFrame.IsWorldQuestCriteriaForSelectedBounty) then
					self.oldBountyBoard = overlayFrame;
				else
					self.newBountyBoard = overlayFrame;
				end
			end
		end
	end
end

function WQT_Utils:GetOldBountyBoard()
	self:EnsureBountyBoards();
	return self.oldBountyBoard;
end

function WQT_Utils:GetNewBountyBoard()
	self:EnsureBountyBoards();
	return self.newBountyBoard;
end

function WQT_Utils:GetWoldMapFilterButton()
	if (self.filterButton) then
		return self.filterButton;
	end

	for _, overlayFrame in ipairs(WorldMapFrame.overlayFrames) do
		if (overlayFrame.FilterCounterBanner) then
			self.filterButton = overlayFrame;
			break;
		end
	end

	return self.filterButton;
end

function WQT_Utils:GetCharacterExpansionLevel()
	local playerLevel = UnitLevel("player");
	local expLevel = GetAccountExpansionLevel();

	if (expLevel >= LE_EXPANSION_WAR_WITHIN and playerLevel >= 70) then
		return LE_EXPANSION_WAR_WITHIN;
	elseif (playerLevel >= 10) then
		return LE_EXPANSION_DRAGONFLIGHT;
	end

	return 0;
end

function WQT_Utils:IsFilterDisabledByOfficial(key)
	local officialFilters = _V["WQT_FILTER_TO_OFFICIAL"][key];
	if (officialFilters) then
		for k, filter in ipairs(officialFilters) do
			if (not C_CVar.GetCVarBool(filter)) then
				return true;
			end
		end
	end

	return false
end

function WQT_Utils:GetLocalizedAbbreviatedNumber(number)
	if type(number) ~= "number" then return "NaN" end;

	local intervals = _L["IS_AZIAN_CLIENT"] and _V["NUMBER_ABBREVIATIONS_ASIAN"] or _V["NUMBER_ABBREVIATIONS"];
	
	for i = 1, #intervals do
		local interval = intervals[i];
		local value = interval.value;
		local valueDivTen = value / 10;
		if (number >= value) then
			if (interval.decimal) then
				local rest = number - floor(number/value)*value;
				if (rest < valueDivTen) then
					return interval.format:format(floor(number/value));
				else
					return interval.format:format(floor(number/valueDivTen)/10);
				end
			end
			return interval.format:format(floor(number/valueDivTen));
		end
	end
	
	return number;
end

function WQT_Utils:GetDisplayRewardAmount(rewardInfo, warmode)
	local reward = rewardInfo;
	local amount = reward and reward.amount or 0;
	local display = "";
	if (reward and amount > 0) then
		if (warmode) then
			amount = WQT_Utils:CalculateWarmodeAmount(reward);
		end

		local displayAmount =  amount
		if (reward.type == WQT_REWARDTYPE.gold) then
			displayAmount = floor(displayAmount / 10000);
		end

		display = WQT_Utils:GetLocalizedAbbreviatedNumber(displayAmount);

		if (reward.type == WQT_REWARDTYPE.relic) then
			display = string.format("+%s", display);
		elseif (reward.canUpgrade) then
			display = string.format("%s+", display);
		end
	end

	return display, amount;
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


