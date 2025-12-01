local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;

local _pinType = {
		["zone"] = 1
		,["continent"] = 2
		,["world"] = 3
	}
	
local _pinTypeScales = {
		[_pinType.zone] = 1
		,[_pinType.continent] = 1
		,[_pinType.world] = 0.5
	}
	
local ICON_ANGLE_START = 270;
local ICON_ANGLE_DISTANCE = 50;
local ICON_CENTER_DISTANCE = 13;
local ICON_MAX_AMOUNT = floor(360/ICON_ANGLE_DISTANCE);
local PIN_FRAME_LEVEL_BASE = 2300;
local PIN_FRAME_LEVEL_FOCUS = 3000;
local LABEL_OFFSET = 2;
	
------------------------------------
-- Locals
------------------------------------

local function OnPinRelease(pool, pin)
	pin:ClearFocus();
	pin:ClearTimer();
	pin.questID = nil;
	pin.nudgeX = 0;
	pin.nudgeY = 0;
	pin.isExpired = false;
	pin.isFaded = false;
	pin.timeIcon = nil;

	pin:ReleaseMiniIcons();
	pin:ResetInRangePins();
	pin:ResetNudge();
	pin:Hide();
	pin:ClearAllPoints();
end

local function ShouldShowPin(questInfo, mapType, settingsZoneVisible, settingsPinContinent, settingsFilterPins, isFlightMap)
	-- Don't show if not valid
	if (not questInfo.isValid) then return false; end

	-- Don't show if filtering and doesn't pass
	if (settingsFilterPins and not questInfo.passedFilter) then return false; end
	
	if (isFlightMap) then return true; end

	if (mapType == Enum.UIMapType.Continent) then
		-- Never show on continent
		if (settingsPinContinent == _V["ENUM_PIN_CONTINENT"].none) then
			return false;
		end
		-- Show only if tracked
		if (settingsPinContinent == _V["ENUM_PIN_CONTINENT"].tracked and not C_QuestLog.GetQuestWatchType(questInfo.questID)) then
			return false;
		end
	elseif (mapType >= Enum.UIMapType.Zone) then
		-- Never show on continent
		if (settingsZoneVisible == _V["ENUM_PIN_ZONE"].none) then
			return false;
		end
		-- Show only if tracked
		if (settingsZoneVisible == _V["ENUM_PIN_ZONE"].tracked and not C_QuestLog.GetQuestWatchType(questInfo.questID)) then
			return false;
		end
	end
	
	return true;
end

local function GetPinType(mapType) 
	if (mapType == Enum.UIMapType.Continent) then
		return _pinType.continent;
	end
	
	return _pinType.zone;
end

------------------------------------
-- DataProvider
------------------------------------

WQT_PinDataProvider = {};

function WQT_PinDataProvider:Init()
	self.frame = CreateFrame("FRAME");
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...); end);
	self.frame:RegisterEvent("SUPER_TRACKING_CHANGED");
	self.frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self.frame:RegisterEvent("CVAR_UPDATE");

	self.miniIconPool =  CreateFramePool("FRAME", nil, "WQT_MiniIconTemplate", function(pool, iconFrame) iconFrame:Reset() end);
	self.pinPool = CreateFramePool("FRAME", nil, "WQT_PinTemplate", OnPinRelease, nil, function(pin)
		pin:Init(self);
	end);
	self.activePins = {};
	self.pingedQuests = {};
	self.hookedCanvasChanges = {};

	WQT_CallbackRegistry:RegisterCallback(
		"WQT.DataProvider.FilteredListUpdated",
		function()
				self:RefreshAllData();
			end,
		self);

	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID)
			if (categoryID == "MAPPINS"
				or categoryID == "MAPPINS_MINIICONS") then
				self:RefreshAllData();
			end
		end,
		self);

	-- Remove pins on changing map. Quest info being processed will trigger showing them if they are needed.
	EventRegistry:RegisterCallback(
		"MapCanvas.MapSet",
		function()
				self:RemoveAllData();
			end,
		self);

	WQT_CallbackRegistry:RegisterCallback(
		"WQT.MapButton.HidePins",
		function(callback, hidePins)
				if (self.hidePinsByMapButton == hidePins) then return; end
				self.hidePinsByMapButton = hidePins;
				self:RefreshAllData();
			end,
		self);

	WQT_PinDataProvider:HookPinHidingToMapFrame(WorldMapFrame);
end

local function HideOfficialPin(pin)
	if (WQT.settings.pin.disablePoI) then return; end
	pin:Hide();
end

function WQT_PinDataProvider:HookPinHidingToMapFrame(mapFrame)
	if (not self.hookedPins) then
		self.hookedPins = {};
	end

	if (not mapFrame.RegisterPin) then return; end

	local templatedToSuppress = {
		["BonusObjectivePinTemplate"] = true;
		[WorldMap_WorldQuestDataProviderMixin:GetPinTemplate()] = true;
	};

	if(FlightMap_WorldQuestDataProviderMixin) then
		templatedToSuppress[FlightMap_WorldQuestDataProviderMixin:GetPinTemplate()] = true;
	end

	hooksecurefunc(mapFrame, "RegisterPin", function(_, pin)
		if (templatedToSuppress[pin.pinTemplate]) then
			local isHooked = self.hookedPins[pin];
			if (not isHooked) then
				self.hookedPins[pin] = true;
				pin:HookScript("OnShow", HideOfficialPin);
				pin:Hide();
			end
		end
	end);
end

function WQT_PinDataProvider:OnEvent(event, ...)
	if (event == "SUPER_TRACKING_CHANGED") then
		self:RefreshAllData();
	elseif (event == "QUEST_WATCH_LIST_CHANGED") then
		self:UpdateAllVisuals();
	elseif (event == "CVAR_UPDATE") then
		local cvar, value = ...;
		if (cvar == "questPOIWQ") then
			self:RefreshAllData();
		end
	end
end

function WQT_PinDataProvider:RemoveAllData()
	self.pinPool:ReleaseAll();
	wipe(self.activePins);
	wipe(self.pingedQuests);
end

function WQT_PinDataProvider:AcquireMiniIcon()
	local icon = self.miniIconPool:Acquire();
	return icon
end

function WQT_PinDataProvider:ReleaseMiniIcon(frame)
	frame:SetParent(nil);
	self.miniIconPool:Release(frame);
end

function WQT_PinDataProvider:RefreshAllData()
	-- Protection against coroutines I guess. 
	-- TaskPOI_OnEnter can trigger this function a second time when the first one isn't done yet
	if (self.isUpdating) then
		return;
	end
	self.isUpdating = true;
	self:RemoveAllData();
	self:PlacePins();
	self.isUpdating = false;
end

function WQT_PinDataProvider:PlacePins()
	if (self.hidePinsByMapButton) then return; end

	if (not C_CVar.GetCVarBool("questPOIWQ")) then return; end

	if (WQT_Utils:GetSetting("pin", "disablePoI")) then 
		self.isUpdating = false;
		return;
	end
	
	local parentMapFrame;
	local isFlightMap = false;
	if (WorldMapFrame:IsShown()) then
		parentMapFrame = WorldMapFrame;
	elseif (FlightMapFrame and FlightMapFrame:IsShown()) then
		isFlightMap = true;
		parentMapFrame = FlightMapFrame;
	end

	if (not parentMapFrame) then
		self.isUpdating = false;
		return;
	end
	
	local mapID = parentMapFrame:GetMapID();
	local mapInfo = WQT_Utils:GetCachedMapInfo(mapID);
	if (not mapInfo) then return; end
	local settingsContinentVisible = WQT_Utils:GetSetting("pin", "continentVisible");
	local settingsZoneVisible = WQT_Utils:GetSetting("pin", "zoneVisible");
	local settingsFilterPoI  = WQT_Utils:GetSetting("pin", "filterPoI");
	
	local canvas = parentMapFrame:GetCanvas();
	
	wipe(self.activePins);
	if (mapInfo.mapType >= Enum.UIMapType.Continent) then
		for k, questInfo in ipairs(WQT_WorldQuestFrame.dataProvider.fitleredQuestsList) do
			if (ShouldShowPin(questInfo, mapInfo.mapType, settingsZoneVisible, settingsContinentVisible, settingsFilterPoI, isFlightMap)) then
				local pinType = GetPinType(mapInfo.mapType);
				local posX, posY = WQT_Utils:GetQuestMapLocation(questInfo.questID, mapID);
				if (posX and posX > 0 and posY > 0) then
					local pin = self.pinPool:Acquire();
					pin:SetParent(canvas);
					tinsert(self.activePins, pin);
					pin:Setup(questInfo, #self.activePins, posX, posY, pinType, parentMapFrame);
				end
			end
		end
	end

	-- Slightly spread out overlapping pins
	self:FixOverlaps(canvas);
	self:UpdateQuestPings();

	if (not self.hookedCanvasChanges[parentMapFrame]) then
		hooksecurefunc(parentMapFrame, "OnCanvasScaleChanged", function() 
				self:FixOverlaps(canvas)
			end);
		self.hookedCanvasChanges[parentMapFrame] = true;
	end

	self.isUpdating = false;
end

local PIN_CLUSTER_RANGE = 0.5;
local PIN_REPOSITION_DISTANCE = 0.42;
local COS_45_DEG = 0.7071;

local function SortPinsByXPos(pinA, pinB)
	local ax = pinA:GetPosition();
	local bx = pinB:GetPosition();
	if (ax and bx and ax ~= bx) then
		return ax < bx;
	end
	return pinA.questID < pinB.questID;
end

local function SortPinsByNudgedPos(pinA, pinB)
	local aX, aY = pinA:GetNudgedPosition();
	local bX, bY = pinB:GetNudgedPosition();
	if (aY and aY and aY ~= bY) then
		return aY < bY;
	end

	return pinA.questID < pinB.questID;
end

local function SortPinNumInRange(pinA, pinB)
	local numA = pinA:GetNumInRangePins();
	local numB = pinB:GetNumInRangePins();
	if (numA ~= numB) then
		return numA > numB;
	end
	return SortPinsByXPos(pinA, pinB);
end

function WQT_PinDataProvider:FixOverlaps(canvas)
	if (not canvas) then return; end

	local pinSize = 0;
	for k, pin in ipairs(self.activePins) do
		pin:ResetNudge();
		pin:ResetInRangePins();
		if (pinSize == 0) then
			pinSize = pin:GetButton():GetSize();
		end
	end
	if (pinSize > 0) then
		local pinScale = WQT_Utils:GetSetting("pin", "scale");
		pinSize = pinSize * pinScale;
		local canvasScale = canvas:GetParent():GetCanvasScale();
		local pinLengthX = pinSize / (canvas:GetWidth() * canvasScale) ;
		local pinLengthY = pinSize / (canvas:GetHeight() * canvasScale);
		local pinLengthRatio = pinLengthX / pinLengthY;
		local scaling = (canvas:GetWidth() * canvas:GetParent():GetCanvasScale()) / canvas:GetParent():GetWidth();
		scaling = 1 / scaling;
		local clusterDistance = pinLengthX * PIN_CLUSTER_RANGE;
		local cluserDistanceSqd = clusterDistance * clusterDistance;

		-- Link nearby pins
		local hasLinkedPins = false;
		table.sort(self.activePins, SortPinsByXPos);
		for indexA = 1, #self.activePins, 1 do
			local pinA = self.activePins[indexA];
			local ax, ay = pinA:GetPosition();
			ay = ay * pinLengthRatio;
			for indexB = 1, #self.activePins, 1 do
				if (indexA < indexB) then
					local pinB = self.activePins[indexB];
					local bx, by = pinB:GetPosition();
					local xdiff = indexB > indexA and ax - bx or bx-ax;
					if (xdiff > -clusterDistance) then
						if (xdiff > clusterDistance) then
							break;
						end

						by = by * pinLengthRatio;
						local distanceSquared = SquaredDistanceBetweenPoints(ax, ay, bx, by);
						if(distanceSquared < cluserDistanceSqd) then
							pinA:AddInRangePin(pinB);
							pinB:AddInRangePin(pinA);
							hasLinkedPins = true;
						end
					end
				end
			end
		end

		if (hasLinkedPins) then
			-- Cluster pins in their groups
			table.sort(self.activePins, SortPinNumInRange);
			local spreadx = pinLengthX * PIN_REPOSITION_DISTANCE;
			local spreadY = pinLengthY * PIN_REPOSITION_DISTANCE;
			local columnOffset = spreadx * COS_45_DEG;
			local alreadyClusteredPins = {};
			local validPins = {};
			for _, sourcePin in ipairs(self.activePins) do
				local numInRange = sourcePin:GetNumInRangePins();
				if (numInRange == 0) then break; end

				wipe(validPins);
				if (not alreadyClusteredPins[sourcePin]) then
					tinsert(validPins, sourcePin);
					alreadyClusteredPins[sourcePin] = true;

					local centerX, centerY = sourcePin:GetPosition();
					for k2, inRangePin in sourcePin:IterateInRangePins() do
						if (not alreadyClusteredPins[inRangePin]) then
							local pinX, pinY = inRangePin:GetPosition();
							centerX = centerX + pinX;
							centerY = centerY + pinY;
							tinsert(validPins, inRangePin);
							alreadyClusteredPins[inRangePin] = true;
						end
					end

					local numPassedPins = #validPins;
					if (numPassedPins >= 2) then
						local numColumns = ceil(sqrt(numPassedPins));
						local numRows = ceil(numPassedPins / numColumns);
						local xWidth = (numColumns-1) * columnOffset;
						centerX = centerX / numPassedPins;
						centerX = centerX - xWidth * 0.5;
						centerY = centerY / numPassedPins;
						centerY = centerY - (numRows-1) * spreadY * 0.5;
						local placedCount = 0;
						for k, pin in ipairs(validPins) do
							local mathIndex = k-1;
							local column = mathIndex % numColumns;
							local x = centerX + column * columnOffset;
							local row = floor(mathIndex / numColumns) ;
							local y = centerY + row * spreadY;
							-- Shift every other column down slightly
							y = y + (column%2) * spreadY * 0.5 * COS_45_DEG;
							pin:SetNudge(x, y);
							placedCount = placedCount + 1;
						end
					end
				end
			end
		end
	end

	-- Placement time
	table.sort(self.activePins, SortPinsByNudgedPos);
	for k, pin in ipairs(self.activePins) do
		pin.index = k;
		pin:UpdatePlacement();
	end
end

function WQT_PinDataProvider:UpdateAllPlacements()
	for pin in self.pinPool:EnumerateActive() do
		pin:UpdatePlacement();
	end
end

function WQT_PinDataProvider:UpdateAllVisuals()
	for pin in self.pinPool:EnumerateActive() do
		pin:UpdateVisuals();
		pin:UpdatePinTime();
	end
end

function WQT_PinDataProvider:UpdateQuestPings()
	local settingPinFadeOnPing = WQT_Utils:GetSetting("pin", "fadeOnPing");
	local fadeOthers = false;
	
	if (settingPinFadeOnPing) then
		for pin in pairs(self.pingedQuests) do
			fadeOthers = true;
			break;
		end
	end

	if (fadeOthers) then
		for pin in self.pinPool:EnumerateActive() do
			if (not self.pingedQuests[pin.questID])then
				pin:FadeOut();
			end
		end
	else
		-- Delay until next frame to prevent freezing when quickly hovering over a lot of quests
		if (not self.delayedFadeTimer) then
			self.delayedFadeTimer = C_Timer.NewTicker(0, function()
					self.delayedFadeTimer = nil;
			
					if (settingPinFadeOnPing) then
						for pin in pairs(self.pingedQuests) do
							return;
						end
					end
			
					for pin in self.pinPool:EnumerateActive() do
						if (not self.pingedQuests[pin.questID])then
							if (pin.isFaded) then
								pin:FadeIn();
							end
						end
					end
				end, 1);
		end
	end
end

function WQT_PinDataProvider:SetQuestIDPinged(questId, shouldPing)
	if (not questId) then return; end
	self.pingedQuests[questId] = shouldPing or nil;
	
	-- Official pins
	if (WQT_Utils:GetSetting("pin", "disablePoI")) then 
		if (not shouldPing or InCombatLockdown()) then return; end
		if (WorldMapFrame:IsShown()) then
			local WQProvider = WQT_Utils:GetMapWQProvider();
			if (WQProvider) then
				WQProvider:PingQuestID(questId);
			end
		end
		if (FlightMapFrame and FlightMapFrame:IsShown()) then
			local FlightWQProvider = WQT_Utils:GetFlightWQProvider();
			if (FlightWQProvider) then
				FlightWQProvider:PingQuestID(questId);
			end
		end
		
		return;
	end 

	-- Custom pins
	for pin in self.pinPool:EnumerateActive() do
		if (pin.questID == questId) then
			if (shouldPing) then
				pin:Focus(true);
			else
				pin:ClearFocus();
			end
			break;
		end
	end
	
	self:UpdateQuestPings();
end

------------------------------------
-- Pin Label
------------------------------------

WQT_PinLabelMixin = {};

function WQT_PinLabelMixin:GetLabelText()
	return self.LabelText;
end

function WQT_PinLabelMixin:UpdateVisuals(questInfo)
	-- Label
	local settingPinTimeLabel = WQT_Utils:GetSetting("pin", "label");
	local labelColor = _V["WQT_WHITE_FONT_COLOR"];
	local labelFontString = self:GetLabelText();
	local _, _, _, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo);
	
	local showLabel = settingPinTimeLabel == _V["ENUM_PIN_LABEL"].time and timeStringShort ~= "";
	-- Only setting up for reward amount. Time label is done in UpdateTime()
	if (settingPinTimeLabel == _V["ENUM_PIN_LABEL"].amount) then
		local questCanWarmode = C_QuestLog.QuestCanHaveWarModeBonus(questInfo.questID);
		local mainReward = questInfo:GetReward(1);
		showLabel = mainReward and true or false;
		if (mainReward) then
			local amountString, rawAmount = WQT_Utils:GetDisplayRewardAmount(mainReward, questCanWarmode);
			showLabel = rawAmount > 1;
			labelFontString:SetText(amountString);
			if (WQT_Utils:GetSetting("pin", "labelColors")) then
				local _, textColor = WQT_Utils:GetRewardTypeColorIDs(mainReward.type);
				labelColor = textColor;
			end
		end
	end

	labelFontString:SetVertexColor(labelColor:GetRGB());
	self:SetShown(showLabel);
end

function WQT_PinLabelMixin:UpdateTime(timeString, color)
	if (WQT_Utils:GetSetting("pin", "label") ~= _V["ENUM_PIN_LABEL"].time) then
		return;
	end

	if (not WQT_Utils:GetSetting("pin", "labelColors")) then
		color = _V["WQT_WHITE_FONT_COLOR"];
	end

	local labelFontString = self:GetLabelText();
	labelFontString:SetText(timeString);
	labelFontString:SetVertexColor(color:GetRGB());
end

------------------------------------
-- Pin Icon
------------------------------------

WQT_PinButtonMixin = {};

function WQT_PinButtonMixin:OnLoad()
	self.UpdateTooltip = function() WQT_Utils:ShowQuestTooltip(self, self.questInfo) end;
end

function WQT_PinButtonMixin:OnEnter()
	self:GetParent():Focus();
	if (self.questInfo) then
		WQT_Utils:ShowQuestTooltip(self, self.questInfo);
		-- Highlight quest in list
		if (self.questID ~= WQT_ListContainer.PoIHoverId) then
			WQT_ListContainer.PoIHoverId = self.questID;
			WQT_ListContainer:DisplayQuestList();
		end
	end
end

function WQT_PinButtonMixin:OnLeave()
	self:GetParent():ClearFocus();
	GameTooltip:Hide();
	WQT:HideDebugTooltip()
	-- Stop highlight quest in list
	WQT_ListContainer.PoIHoverId = nil;
	WQT_ListContainer:DisplayQuestList();
end

function WQT_PinButtonMixin:OnClick(button)
	WQT_Utils:HandleQuestClick(self, self.questInfo, button);
end

function WQT_PinButtonMixin:GetIcon()
	return self.Icon;
end

function WQT_PinButtonMixin:GetRingBG()
	return self.RingBG;
end

function WQT_PinButtonMixin:GetRing()
	return self.Ring;
end

function WQT_PinButtonMixin:GetPointer()
	return self.Pointer;
end

function WQT_PinButtonMixin:GetCustomUnderlay()
	return self.CustomUnderlay;
end

function WQT_PinButtonMixin:GetCustomTypeIcon()
	return self.CustomTypeIcon;
end

function WQT_PinButtonMixin:GetCustomSelectedGlow()
	return self.CustomSelectedGlow;
end

function WQT_PinButtonMixin:GetCustomBountyRing()
	return self.CustomBountyRing;
end

function WQT_PinButtonMixin:GetMiniPins()
	return self.pinRoot.miniIcons;
end

function WQT_PinButtonMixin:PlaceMiniIcons()
	local icons = self:GetMiniPins();
	local numIcons = #icons;
	if (numIcons > 0) then
		local angle = ICON_ANGLE_START - (ICON_ANGLE_DISTANCE*(numIcons-1))/2
		local numIcons = min(#icons, ICON_MAX_AMOUNT);
		for i = 1, numIcons do
			local iconFrame = icons[i];

			local posX = ICON_CENTER_DISTANCE * cos(angle);
			local posY = ICON_CENTER_DISTANCE * sin(angle);
			PixelUtil.SetPoint(iconFrame, "CENTER", self, "CENTER", posX, posY);
			iconFrame:Show();
			angle = angle + ICON_ANGLE_DISTANCE;
		end
	end
end

function WQT_PinButtonMixin:IterateMiniIcons()
	return ipairs(self:GetMiniPins());
end

function WQT_PinButtonMixin:AddIcon()
	local icon = self.pinRoot:AcquireMiniIcon();
	icon:SetParent(self);
	return icon;
end

function WQT_PinButtonMixin:SetIconsDesaturated(desaturate)
	for k, icon in self:IterateMiniIcons() do
		icon:SetDesaturated(desaturate);
	end
end

function WQT_PinButtonMixin:GetIconBottomDifference()
	local maxBottomDiff = 0;
	local selfBottom = self:GetBottom();
	for k, icon in self:IterateMiniIcons() do
		local diff = selfBottom - icon:GetBottom();
		maxBottomDiff = max(maxBottomDiff, diff);
	end
	return maxBottomDiff;
end

function WQT_PinButtonMixin:UpdateTime(start, timeLeft, total, color, timeCategory)
	if (WQT_Utils:GetSetting("pin", "ringType") ~= _V["RING_TYPES"].time) then
		return;
	end

	local ringBGTexture = self:GetRingBG();
	local ringCooldown = self:GetRing();
	local pointerTexture = self:GetPointer();
	local r, g, b = color:GetRGB();
	local now = time();

	pointerTexture:SetShown(total > 0);
	if (total > 0) then
		pointerTexture:SetRotation((timeLeft) / (total) * 6.2831);
		pointerTexture:SetVertexColor(r * 1.1, g * 1.1, b * 1.1);
		ringCooldown:SetCooldownUNIX(now - start, start + timeLeft);
	else
		ringCooldown:SetCooldownUNIX(now, now);
	end
	ringBGTexture:SetVertexColor(r, g, b);
	ringCooldown:SetSwipeColor(r, g, b);

	-- Small icon indicating time category
	if (self.timeIcon) then
		if (timeCategory == _V["TIME_REMAINING_CATEGORY"].medium) then
			self.timeIcon.Icon:SetTexCoord(0.25, 0.5, 0.5, 1);
		elseif (timeCategory == _V["TIME_REMAINING_CATEGORY"].short) then
			self.timeIcon.Icon:SetTexCoord(0.5, 0.75, 0.5, 1);
		elseif (timeCategory == _V["TIME_REMAINING_CATEGORY"].critical) then
			self.timeIcon.Icon:SetTexCoord(0.75, 1, 0.5, 1);
		else
			self.timeIcon.Icon:SetTexCoord(0, 0.25, 0.5, 1);
		end
		
		self.timeIcon.Icon:SetVertexColor(color:GetRGB());
	end
end

function WQT_PinButtonMixin:UpdateVisuals(questInfo)
	if (not questInfo) then return; end

	self.questInfo = questInfo;
	local questQuality = questInfo:GetTagInfoQuality();
	local isDisliked = questInfo:IsDisliked();
	local tagInfo = questInfo:GetTagInfo();
	local typeAtlas, typeAtlasWidth, typeAtlasHeight =  WQT_Utils:GetCachedTypeIconData(questInfo);
	local isTracked = QuestUtils_IsQuestWatched(questInfo.questID);
	local isSuperTracked = questInfo.questID == C_SuperTrack.GetSuperTrackedQuestID();

	-- Ring coloration
	local ringType = WQT_Utils:GetSetting("pin", "ringType");
	local now = time();
	local ringBGTexture = self:GetRingBG();
	local ringCooldown = self:GetRing();
	local pointerTexture = self:GetPointer();
	local r, g, b = _V["WQT_COLOR_CURRENCY"]:GetRGB();
	ringBGTexture:SetShown(ringType == _V["RING_TYPES"].time and 1 or 0);
	ringCooldown:SetCooldownUNIX(now, now);
	pointerTexture:Hide();
	ringCooldown:Show();
	ringBGTexture:Show();
	if (ringType == _V["RING_TYPES"].reward) then
		r, g, b = questInfo:GetRewardColor():GetRGB();
	elseif (questQuality and ringType == _V["RING_TYPES"].rarity) then
		if (questQuality > Enum.WorldQuestQuality.Common and WORLD_QUEST_QUALITY_COLORS[questQuality]) then
			r, g, b = WORLD_QUEST_QUALITY_COLORS[questQuality].color:GetRGB();
		end
	elseif (ringType == _V["RING_TYPES"].hide) then
		ringCooldown:Hide();
		ringBGTexture:Hide();
	end
	
	if (isDisliked) then
		r, g, b = 1, 1, 1;
	end
	
	ringBGTexture:SetVertexColor(r, g, b);
	ringCooldown:SetSwipeColor(r, g, b);

	-- Elite indicator
	local customUnderlayTexture = self:GetCustomUnderlay();
	local isElite = tagInfo and tagInfo.isElite;
	local settingEliteRing = WQT_Utils:GetSetting("pin", "eliteRing");
	local useEliteRing = settingEliteRing and ringType ~= _V["RING_TYPES"].hide;
	ringBGTexture:SetTexture("Interface/Addons/WorldQuestTab/Images/PoIRingBG");
	ringCooldown:SetSwipeTexture("Interface/Addons/WorldQuestTab/Images/PoIRingBar");
	if (useEliteRing) then
		customUnderlayTexture:SetShown(false);
		if(isElite) then
			ringBGTexture:SetTexture("Interface/Addons/WorldQuestTab/Images/PoIRingBGElite");
			ringCooldown:SetSwipeTexture("Interface/Addons/WorldQuestTab/Images/PoIRingBarElite");
		end
	else
		customUnderlayTexture:SetShown(isElite);
	end
	
	customUnderlayTexture:SetDesaturated(isDisliked);

	-- Main Icon
	local settingCenterType = WQT_Utils:GetSetting("pin", "centerType");
	local customTypeIconTexture = self:GetCustomTypeIcon();
	local customSelectedGlowTexture = self:GetCustomSelectedGlow();
	local customBountyRingTexture = self:GetCustomBountyRing();
	customTypeIconTexture:SetShown(false);
	customSelectedGlowTexture:Hide()
	customBountyRingTexture:Hide()

	local iconTexture = self:GetIcon();
	iconTexture:SetTexture("Interface/PETBATTLES/BattleBar-AbilityBadge-Neutral");
	iconTexture:SetTexCoord(0.06, 0.93, 0.05, 0.93);
	iconTexture:SetDesaturated(false);
	iconTexture:SetScale(1);
	iconTexture:Show();

	local hasIcon = true;

	if(settingCenterType == _V["PIN_CENTER_TYPES"].reward) then
		local rewardTexture = questInfo:GetRewardTexture();
		iconTexture:SetTexture(rewardTexture);
		iconTexture:SetTexCoord(0, 1, 0, 1);

		hasIcon = questInfo:GetRewardType() ~= WQT_REWARDTYPE.none;
	elseif(settingCenterType == _V["PIN_CENTER_TYPES"].blizzard) then
		customTypeIconTexture:SetShown(true);
		local showSlectedGlow = tagInfo and questQuality ~= Enum.WorldQuestQuality.Common and isSuperTracked;
		local selectedBountyOnly = WQT_Utils:GetSetting("general", "bountySelectedOnly");
		
		customBountyRingTexture:SetShown(questInfo:IsCriteria(selectedBountyOnly));
		customSelectedGlowTexture:SetShown(showSlectedGlow);
		if (tagInfo) then
			if (questQuality == Enum.WorldQuestQuality.Rare) then
				iconTexture:SetAtlas("worldquest-questmarker-rare");
				customSelectedGlowTexture:SetAtlas("worldquest-questmarker-rare");
			elseif (questQuality == Enum.WorldQuestQuality.Epic) then
				iconTexture:SetAtlas("worldquest-questmarker-epic")
				customSelectedGlowTexture:SetAtlas("worldquest-questmarker-epic");
			else
				iconTexture:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
				if (isSuperTracked) then
					iconTexture:SetTexCoord(0.52, 0.605, 0.395, 0.48);
				else
					iconTexture:SetTexCoord(0.895, 0.98, 0.395, 0.48);
				end
				iconTexture:SetScale(1.1);
			end
		else
			iconTexture:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
			iconTexture:SetTexCoord(0.895, 0.98, 0.395, 0.48);
			iconTexture:SetDesaturated(true);
		end
		
		-- Mimic default icon
		
		customTypeIconTexture:SetAtlas(typeAtlas);
		customTypeIconTexture:SetSize(typeAtlasWidth, typeAtlasHeight);
		customTypeIconTexture:SetScale(.8);
	elseif(settingCenterType == _V["PIN_CENTER_TYPES"].faction) then
		local factionData = WQT_Utils:GetFactionDataInternal(questInfo.factionID);
		iconTexture:SetTexture(factionData.texture);
	elseif(settingCenterType == _V["PIN_CENTER_TYPES"].none) then
		iconTexture:Hide();
	end
	
	iconTexture:SetAlpha(hasIcon and 1.0 or 0.7);

	if (isDisliked) then
		iconTexture:SetDesaturated(true);
	end
	customTypeIconTexture:SetDesaturated(isDisliked);


	-- Setup mini icons
	local questType = tagInfo and tagInfo.worldQuestType;

	self.timeIcon = nil;
	-- Quest Type Icon
	if (typeAtlas and typeAtlas ~= "Worldquest-icon" and WQT_Utils:GetSetting("pin", "typeIcon") ) then
		local iconFrame = self:AddIcon();
		iconFrame:SetupIcon(typeAtlas);
		iconFrame:SetIconScale(questType == Enum.QuestTagType.PvP and 0.8 or 1);
	end
	
	-- Quest rarity Icon
	if (questQuality and questQuality > Enum.WorldQuestQuality.Common and WQT_Utils:GetSetting("pin", "rarityIcon")) then
		local color = WORLD_QUEST_QUALITY_COLORS[questQuality];
		if (color) then
			local iconFrame = self:AddIcon();
			iconFrame:SetupIcon(_V["PATH_CUSTOM_ICONS"], 0, 0.25, 0, 0.5);
			iconFrame:SetIconColor(color.color);
			iconFrame:SetIconScale(1.15);
			iconFrame:SetBackgroundShown(false);
		end
	end

	-- Time Icon
	if (WQT_Utils:GetSetting("pin", "timeIcon")) then
		local _, _, color, _, _, timeCategory = WQT_Utils:GetQuestTimeString(questInfo);
		if (timeCategory >= _V["TIME_REMAINING_CATEGORY"].critical) then
			local iconFrame = self:AddIcon();
			iconFrame:SetupIcon(_V["PATH_CUSTOM_ICONS"], 0, 0.25, 0.5, 1);
			if (timeCategory == _V["TIME_REMAINING_CATEGORY"].medium) then
				iconFrame:SetIconCoords(0.25, 0.5, 0.5, 1);
			elseif (timeCategory == _V["TIME_REMAINING_CATEGORY"].short) then
				iconFrame:SetIconCoords(0.5, 0.75, 0.5, 1);
			elseif (timeCategory == _V["TIME_REMAINING_CATEGORY"].critical) then
				iconFrame:SetIconCoords(0.75, 1, 0.5, 1);
			end
			
			iconFrame:SetIconColor(color);
			iconFrame:SetIconScale(1);
			iconFrame:SetBackgroundShown(false);
			self.timeIcon = iconFrame;
		end
	end

	-- Warband icon
	if (questInfo.hasWarbandBonus and WQT_Utils:GetSetting("pin", "warbandIcon")) then
		local iconFrame = self:AddIcon();
		iconFrame:SetupIcon("warbands-icon");
		iconFrame:SetIconScale(1.3);
	end

	-- Reward Type Icon
	local numRewardIcons = WQT_Utils:GetSetting("pin", "numRewardIcons");
	for k, rewardInfo in questInfo:IterateRewards() do
		if (k <= numRewardIcons) then
			local iconFrame = self:AddIcon();
			iconFrame:SetupRewardIcon(rewardInfo.type, rewardInfo.subType);
		end
	end
	
	-- Quest Tracking
	if (isTracked) then
		local iconFrame = self:AddIcon();
		iconFrame:SetupIcon(isSuperTracked and  "Waypoint-MapPin-Minimap-Tracked" or "Waypoint-MapPin-Minimap-Untracked");
		iconFrame:SetIconScale(1.7);
	end
	
	self:PlaceMiniIcons();
	self:SetIconsDesaturated(isDisliked);
end

------------------------------------
-- Pin Core
------------------------------------

WQT_PinMixin = {};

function WQT_PinMixin:ClearTimer()
	if (self.timer) then
		self.timer:Cancel();
		self.timer = nil;
	end
end

function WQT_PinMixin:GetButton()
	return self.Button;
end

function WQT_PinMixin:GetLabel()
	return self.Label;
end

function WQT_PinMixin:GetPing()
	return self:GetButton().Ping;
end

function WQT_PinMixin:GetPingStatic()
	return self:GetButton().PingStatic;
end

function WQT_PinMixin:GetFadeInAnim()
	return self.fadeInAnim;
end

function WQT_PinMixin:GetFadeOutAnim()
	return self.fadeOutAnim;
end

function WQT_PinMixin:GetRingAnim()
	return self:GetButton().ringAnim;
end

function WQT_PinMixin:GetRingAnim2()
	return self:GetButton().ringAnim2;
end

function WQT_PinMixin:Init(dataProvider)
	self.dataProvider = dataProvider;
	self.miniIcons = {};
	local button = self:GetButton();
	button.pinRoot = self;

	self.inRangePins = {};
	self.inRangePinsLookup = {};
end

function WQT_PinMixin:ResetInRangePins()
	wipe(self.inRangePinsLookup);
	wipe(self.inRangePins);
end

function WQT_PinMixin:AddInRangePin(pin)
	if (self.inRangePinsLookup[pin]) then return; end

	self.inRangePinsLookup[pin] = true;
	tinsert(self.inRangePins, pin);
end

function WQT_PinMixin:GetNumInRangePins()
	return #self.inRangePins;
end

function WQT_PinMixin:IterateInRangePins()
	return ipairs(self.inRangePins);
end

function WQT_PinMixin:ReleaseMiniIcons()
	if (self.miniIcons) then
		for k, frame in ipairs(self.miniIcons) do
			self.dataProvider:ReleaseMiniIcon(frame);
		end

		wipe(self.miniIcons);
	end
end

function WQT_PinMixin:AcquireMiniIcon()
	local icon = self.dataProvider:AcquireMiniIcon();
	icon:SetParent(self);
	tinsert(self.miniIcons, icon);
	return icon;
end

function WQT_PinMixin:SetupCanvasType(pinType, parentMapFrame, isWatched)
	self.parentMapFrame = parentMapFrame;
	self.scaleFactor  = 1;
	self.startScale  = _pinTypeScales[pinType] or 1;
	self.endScale  = 1;
	self.alphaFactor = 1;
	self.startAlpha = 1;
	self.endAlpha = 1;
	if (FlightMapFrame and parentMapFrame == FlightMapFrame) then
		self.alphaFactor = 2;
		self.startAlpha = isWatched and 1 or 0;
		self.endAlpha = 1.0;
	end
end

function WQT_PinMixin:Setup(questInfo, index, x, y, pinType, parentMapFrame)
	local isWatched = QuestUtils_IsQuestWatched(questInfo.questID);
	self:SetupCanvasType(pinType, parentMapFrame, isWatched);

	self.index = index;
	self.questInfo = questInfo;
	self.questID = questInfo.questID;
	
	local scale = WQT_Utils:GetSetting("pin", "scale")

	self.scale = scale
	self:SetScale(scale);
	self.currentScale = scale;
	self:SetAlpha(self.startAlpha);
	self.currentAlpha = self.startAlpha;
	self:ResetNudge();
	self.posX = x;
	self.posY = y;
	self.baseFrameLevel = PIN_FRAME_LEVEL_BASE;

	self:UpdateVisuals();
	self:UpdatePinTime();

	WQT_CallbackRegistry:TriggerEvent("WQT.MapPinProvider.PinInitialized", self);
end

function WQT_PinMixin:UpdateVisuals()
	local questInfo = self.questInfo;
	if (not questInfo:DataIsValid()) then return end;

	self:ReleaseMiniIcons();
	self:UpdatePlacement();

	local buttonFrame = self:GetButton();
	buttonFrame:UpdateVisuals(questInfo);

	local labelFrame = self:GetLabel();
	labelFrame:UpdateVisuals(questInfo);

	-- Offsetting the label to leave room for visible mini icons
	-- Must happen after placement or GetBottom won't work
	if (labelFrame:IsShown()) then
		local bottomOffset = buttonFrame:GetIconBottomDifference()
		RoundToNearestMultiple(bottomOffset, 0);
		bottomOffset = bottomOffset - LABEL_OFFSET;
		PixelUtil.SetPoint(labelFrame, "TOP", self.Button, "BOTTOM", 0, -bottomOffset);
	end
end

function WQT_PinMixin:UpdatePinTime()
	local start, total, timeLeft, seconds, color, timeStringShort, timeCategory = WQT_Utils:GetPinTime(self.questInfo);
	local isDisliked = self.questInfo:IsDisliked();

	-- Ring
	local ringColor = isDisliked and _V["WQT_WHITE_FONT_COLOR"] or color;
	local buttonFrame = self:GetButton();
	buttonFrame:UpdateTime(start, timeLeft, total, ringColor, timeCategory);
	buttonFrame:SetIconsDesaturated(isDisliked);
	self:GetLabel():UpdateTime(timeStringShort, ringColor);

	if (timeCategory == _V["TIME_REMAINING_CATEGORY"].expired) then
		self.isExpired = true;
		timeLeft = 0;
	end

	self:ClearTimer();

	local timerInterval = WQT_Utils:TimeLeftToUpdateTime(timeLeft, true);
	if (timerInterval > 0) then
		self.timer = C_Timer.NewTimer(timerInterval, function() self:UpdatePinTime() end);
	end
end

function WQT_PinMixin:UpdatePlacement(alpha)
	local zoomPercent = self.parentMapFrame:GetCanvasZoomPercent();
	local parentScaleFactor = self.scale / self.parentMapFrame:GetCanvasScale();
	parentScaleFactor = parentScaleFactor * Lerp(self.startScale, self.endScale, Saturate(self.scaleFactor * zoomPercent));
	self:SetScale(parentScaleFactor);
	
	local startAlpha, targetAlpha = self:GetAlphas();
	local newAlpha = alpha or Lerp(startAlpha, targetAlpha, Saturate(self.alphaFactor * zoomPercent));
	self:SetAlpha(newAlpha);
	self:SetShown(newAlpha > 0.05);
	self.currentAlpha = newAlpha;
	self.currentScale = parentScaleFactor;

	self:ApplyScaledPosition(parentScaleFactor);
	self:SetFrameLevel(PIN_FRAME_LEVEL_BASE + self.index);
	self.Label:SetFrameLevel(self.baseFrameLevel + self.index);
	self.Button:SetFrameLevel(self.baseFrameLevel + self.index);
end

function WQT_PinMixin:GetAlphas()
	if (self.questInfo:IsDisliked()) then
		return min(self.startAlpha,0.5), 0.5;
	end
	
	return self.startAlpha, self.endAlpha;
end

function WQT_PinMixin:ApplyScaledPosition(manualScale)
	local canvas = self:GetParent();
	local scale = manualScale or self.scale / self.parentMapFrame:GetCanvasScale();
	local posX, posY = self:GetNudgedPosition();
	posX = (canvas:GetWidth() * posX)/scale;
	posY = -(canvas:GetHeight() * posY)/scale;
	self:ClearAllPoints();
	PixelUtil.SetPoint(self, "CENTER", canvas, "TOPLEFT", posX, posY);
end

function WQT_PinMixin:Focus(playPing)
	if (not self.questID) then return; end
	local parentScaleFactor = self.scale / self.parentMapFrame:GetCanvasScale();
	
	local fadeInAnim = self:GetFadeInAnim();
	local fadeOutAnim = self:GetFadeOutAnim();
	fadeInAnim:Stop();
	fadeOutAnim:Stop();
	
	self.isFaded = false;
	
	self.isFocussed = true;
	self:SetAlpha(1);
	self:SetScale(parentScaleFactor);
	self:Show();
	self:ApplyScaledPosition();
	
	local ringAnim = self:GetRingAnim();
	if (playPing and not ringAnim:IsPlaying()) then
		local pingTexture = self:GetPing();
		local pingStaticTexture = self:GetPingStatic();
		pingTexture:Show();
		pingStaticTexture:Show();
		ringAnim:Play();
		local ringAnim2 = self:GetRingAnim2();
		ringAnim2:Play();
	end

	self.baseFrameLevel = PIN_FRAME_LEVEL_FOCUS;
	self:UpdatePlacement(1);
end

function WQT_PinMixin:ClearFocus()
	if (not self.questID) then return; end
	self:SetAlpha(self.currentAlpha);
	self:SetScale(self.currentScale);
	self:SetShown(self.currentAlpha > 0.05);
	self:ApplyScaledPosition(self.currentScale);
	self.isFocussed = false;
	
	local ringAnim = self:GetRingAnim();
	if (ringAnim:IsPlaying()) then
		local pingTexture = self:GetPing();
		local pingStaticTexture = self:GetPingStatic();
		pingTexture:Hide();
		pingStaticTexture:Hide();
		ringAnim:Stop();
		local ringAnim2 = self:GetRingAnim2();
		ringAnim2:Stop();
	end
	self.baseFrameLevel = PIN_FRAME_LEVEL_BASE;
	self:UpdatePlacement();
end

function WQT_PinMixin:FadeIn()
	local fadeInAnim = self:GetFadeInAnim();
	local fadeOutAnim = self:GetFadeOutAnim();
	if(fadeOutAnim:IsPlaying()) then fadeOutAnim:Stop(); end

	self.isFaded = false;
	if (not fadeInAnim:IsPlaying()) then
		self:SetAlpha(0.5);
		fadeInAnim.Alpha:SetFromAlpha(self:GetAlpha());
		fadeInAnim.Alpha:SetToAlpha(self.currentAlpha);
		fadeInAnim:Play();
	end
end

function WQT_PinMixin:FadeOut()
	local fadeInAnim = self:GetFadeInAnim();
	local fadeOutAnim = self:GetFadeOutAnim();
	if(fadeInAnim:IsPlaying()) then fadeInAnim:Stop(); end
	self.isFaded = true;
	if (not fadeOutAnim:IsPlaying()) then
		fadeOutAnim.Alpha:SetFromAlpha(self:GetAlpha());
		fadeOutAnim:Play();
	end
end

function WQT_PinMixin:ResetNudge()
	self.nudgeX = nil;
	self.nudgeY = nil;
end

function WQT_PinMixin:GetPosition()
	return self.posX, self.posY;
end

function WQT_PinMixin:GetNudgedPosition()
	if (self.nudgeX and self.nudgeY)then
		
		return self.nudgeX, self.nudgeY;
	end
	return self:GetPosition();
end

function WQT_PinMixin:SetNudge(x, y)
	self.nudgeX = x;
	self.nudgeY = y;
end
