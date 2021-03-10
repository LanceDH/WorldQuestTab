local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-2.0");
local WQT_Utils = addon.WQT_Utils;

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
local PIN_FRAME_LEVEL_BASE = 2200;
local PIN_FRAME_LEVEL_FOCUS = 3000;
	
------------------------------------
-- Locals
------------------------------------

local function SortPinsByMapPos(a, b)
	local aX, aY = a:GetNudgedPosition();
	local bX, bY = b:GetNudgedPosition();
	if (aX and bX) then
		-- If 2 pins are close with the left being slightly higher, we still want left to be in front
		if (aY ~= bY) then
			return aY < bY;
		else
			if (aX ~= bY) then
				return aX > bX;
			end
		end 
	end

	return a.questId < b.questId;
end
	
local function OnPinRelease(pool, pin)
	pin:ClearFocus();
	pin.questId = nil;
	pin.nudgeX = 0;
	pin.nudgeY = 0;
	pin.updateTime = 0;
	pin.updateInterval = 1;
	pin.isExpired = false;
	pin.isFaded = false;
	pin.timeIcon = nil;
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
		if (settingsPinContinent == _V["ENUM_PIN_CONTINENT"].tracked and not C_QuestLog.GetQuestWatchType(questInfo.questId)) then
			return false;
		end
	elseif (mapType >= Enum.UIMapType.Zone) then
		-- Never show on continent
		if (settingsZoneVisible == _V["ENUM_PIN_ZONE"].none) then
			return false;
		end
		-- Show only if tracked
		if (settingsZoneVisible == _V["ENUM_PIN_ZONE"].tracked and not C_QuestLog.GetQuestWatchType(questInfo.questId)) then
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

	self.pinPool = CreateFramePool("BUTTON", nil, "WQT_PinTemplate", OnPinRelease);
	self.activePins = {};
	self.pingedQuests = {};
	self.hookedCanvasChanges = {};
	
	WQT_WorldQuestFrame:RegisterCallback("UpdateQuestList", function() 
			self:RefreshAllData();
		end, addonName);
		
	-- Fix pings and fades when switching map
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			wipe(self.pingedQuests);
			self:UpdateQuestPings();
		end);
		
	self.clusterDistance = 0.5;
	self.clusterSpread = 0.2;
	self.enableNudging = true;
	self.pinClusters = {};
	self.pinClusterLookup = {};
end

function WQT_PinDataProvider:OnEvent(event, ...)
	if (event == "SUPER_TRACKING_CHANGED") then
		self:UpdateAllVisuals();
	elseif (event == "QUEST_WATCH_LIST_CHANGED") then
		self:UpdateAllVisuals();
	end
end

function WQT_PinDataProvider:RemoveAllData()
	self.pinPool:ReleaseAll();
	wipe(self.activePins);
	wipe(self.pingedQuests);
	wipe(self.pinClusters);
	wipe(self.pinClusterLookup);
end

function WQT_PinDataProvider:RefreshAllData()
	-- Protection against coroutines I guess. 
	-- TaskPOI_OnEnter can trigger this function a second time when the first one isn't done yet
	if (self.isUpdating) then
		return;
	end
	
	local wqp = WQT_Utils:GetMapWQProvider();

	self.isUpdating = true;
	self:RemoveAllData();
	if (WQT_Utils:GetSetting("pin", "disablePoI")) then 
		self.isUpdating = false;
		return; 
	end
	WQT_WorldQuestFrame:HideOfficialMapPins();
	
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
	local settingsContinentPins = WQT_Utils:GetSetting("pin", "continentPins");
	local settingsContinentVisible = WQT_Utils:GetSetting("pin", "continentVisible");
	local settingsZoneVisible = WQT_Utils:GetSetting("pin", "zoneVisible");
	local settingsFilterPoI  = WQT_Utils:GetSetting("pin", "filterPoI");
	local mapInfo = WQT_Utils:GetCachedMapInfo(mapID);
	local canvas = parentMapFrame:GetCanvas();
	
	wipe(self.activePins);
	
	if (mapInfo.mapType >= Enum.UIMapType.Continent) then
		for k, questInfo in ipairs(WQT_WorldQuestFrame.dataProvider:GetIterativeList()) do
			local officialShow = true;
			if (wqp.focusedQuestID) then
				officialShow = C_QuestLog.IsQuestCalling(wqp.focusedQuestID) and wqp:ShouldHighlightInfo(questInfo.questId);
			end

			if (officialShow and ShouldShowPin(questInfo, mapInfo.mapType, settingsZoneVisible, settingsContinentVisible, settingsFilterPoI, isFlightMap)) then
				local pinType = GetPinType(mapInfo.mapType);
				local posX, posY = WQT_Utils:GetQuestMapLocation(questInfo.questId, mapID);
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

function WQT_PinDataProvider:FixOverlaps(canvas)
	if (not self.enableNudging or not canvas) then return; end
	
	local canvasScale = 1/canvas:GetParent():GetCanvasScale();
	local scaling = 25/(canvas:GetWidth() * canvas:GetParent():GetCanvasScale());
	local canvasRatio = canvas:GetWidth() /canvas:GetHeight();
	local clusterDistance = self.clusterDistance * scaling;
	local clusterSpread = self.clusterSpread * scaling 
	local clusters = self.pinClusters;
	local clusterdLookup = self.pinClusterLookup;
	local cluster;

	for k, pin in ipairs(self.activePins) do
		pin:ResetNudge()
	end
	
	-- Put close proximity quests in a cluster.
	for k1, pinA in ipairs(self.activePins) do
		if (not clusterdLookup[k1]) then
			for k2, pinB in ipairs(self.activePins) do
				if (pinA ~= pinB) then
					local aX, aY = pinA:GetNudgedPosition();
					local bX, bY = pinB:GetNudgedPosition();
					local distanceSquared = SquaredDistanceBetweenPoints(aX, aY, bX, bY);
					
					if (distanceSquared < clusterDistance * clusterDistance) then
						if (not cluster) then 
							cluster = {pinA, pinB}
						else 
							tinsert(cluster, pinB);
						end
						clusterdLookup[k1] = true;
						clusterdLookup[k2] = true;
						
						local centerX, centerY = 0, 0;
						for k, pin in ipairs(cluster) do
							local pinX, pinY = pin:GetPosition();
							centerX = centerX + pinX;
							centerY = centerY + pinY;
						end
						centerX = centerX / #cluster;
						centerY = centerY / #cluster;
						
						for k, pin in ipairs(cluster) do
							pin:SetNudge(centerX, centerY);
						end
						
					end
				end
			end
			if (cluster) then
				tinsert(clusters, cluster);
				cluster = nil;
			end
		end
	end
	
	-- Spread out the quests in each cluster in a circle around the center point
	-- Puts all quests in a circle around the center of the cluster. Works with small clusters.
	local mapID = canvas:GetParent().mapID;
	for kC, pins in ipairs(clusters) do
		local centerX, centerY = pins[1]:GetNudgedPosition();
		-- Keep pins in relatively the same localtion. This will make it so 2 pins don't switch positions once clustered
		table.sort(pins, function(a, b) 
				local aX, aY = a:GetPosition();
				local bX, bY = b:GetPosition();
				-- Don't calculate same position or missing position
				if (not aX or not bX or (aX == bX and aY == bY)) then
					return a.questId < b.questId;
				end
				
				-- Keep in mind Y axis is inverse
				local degA = math.deg(math.atan2((centerY - aY), (aX-centerX)));
				local degB = math.deg(math.atan2((centerY - bY), (bX-centerX)));
				degA = degA < 0 and degA+360 or degA;
				degB = degB < 0 and degB+360 or degB;
				return degA < degB;
			end);
		-- Get the rotation of the first pin. This is where we start placing them on the circle
		local firstX, firstY = pins[1]:GetPosition();
		local startAngle = math.deg(math.atan2((centerY - firstY), (firstX-centerX)));
		local spread = clusterSpread;
		
		-- Slightly increase spread distance based on number of pins in the cluster
		if (#pins > 2) then
			spread = spread + (#pins * 0.0005);
		end
		
		-- Place every pin at aqual distance
		for kP, pin in ipairs(pins) do
			local angle = -startAngle - (kP-1) * (360 / #pins);
			local offsetX = cos(angle) * spread;
			local offsetY = sin(angle) * spread * canvasRatio;
			pin:SetNudge(centerX + offsetX, centerY + offsetY);
		end
	end
	
	-- Sort pins to place them like dragon scales (lower is more in front)
	table.sort(self.activePins, SortPinsByMapPos);
	for k, pin in ipairs(self.activePins) do
		pin.index = k;
		pin:UpdatePlacement();
	end
	
	wipe(self.pinClusters);
	wipe(self.pinClusterLookup);
end

function WQT_PinDataProvider:UpdateAllPlacements()
	for pin in self.pinPool:EnumerateActive() do
		pin:UpdatePlacement();
	end
end

function WQT_PinDataProvider:UpdateAllVisuals()
	for pin in self.pinPool:EnumerateActive() do
		pin:UpdateVisuals();
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
			if (not self.pingedQuests[pin.questId])then
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
						if (not self.pingedQuests[pin.questId])then
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
		if (not shouldPing) then return; end
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
		if (pin.questId == questId) then
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
-- Pin
------------------------------------

WQT_PinMixin = {};

function WQT_PinMixin:OnLoad()
	self.UpdateTooltip = function() WQT_Utils:ShowQuestTooltip(self, self.questInfo) end;
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	self.updateTime = 0;
	self.iconPool =  CreateFramePool("FRAME", self, "WQT_MiniIconTemplate", function(pool, iconFrame) iconFrame:Reset() end);
	self.icons = {};
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

function WQT_PinMixin:PlaceMiniIcons()
	local numIcons = #self.icons;
	if (numIcons > 0) then
		local angle = ICON_ANGLE_START - (ICON_ANGLE_DISTANCE*(numIcons-1))/2
		local numIcons = min(#self.icons, ICON_MAX_AMOUNT);
		for i = 1, numIcons do
			local iconFrame = self.icons[i];
			iconFrame:SetPoint("CENTER", ICON_CENTER_DISTANCE * cos(angle), ICON_CENTER_DISTANCE * sin(angle));
			iconFrame:Show();
			angle = angle + ICON_ANGLE_DISTANCE;
		end
	end
end

function WQT_PinMixin:AddIcon()
	local iconFrame = self.iconPool:Acquire();
	tinsert(self.icons, iconFrame);
	return iconFrame;
end

function WQT_PinMixin:SetIconsDesaturated(desaturate)
	for k, icon in ipairs(self.icons) do
		icon:SetDesaturated(desaturate);
	end
end

function WQT_PinMixin:Setup(questInfo, index, x, y, pinType, parentMapFrame)
	local isWatched = QuestUtils_IsQuestWatched(questInfo.questId);
	self:SetupCanvasType(pinType, parentMapFrame, isWatched);
	
	self.index = index;
	self.questInfo = questInfo;
	self.questId = questInfo.questId;
	
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
	WQT_WorldQuestFrame:TriggerCallback("MapPinInitialized", self);
end

function WQT_PinMixin:UpdateVisuals()
	local questInfo = self.questInfo;
	if (not questInfo:DataIsValid()) then return end;
	
	local settingCenterType = WQT_Utils:GetSetting("pin", "centerType");
	local _, _, _, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo);
	local tagInfo = questInfo:GetTagInfo();
	local questQuality = tagInfo and tagInfo.quality;
	local questType = tagInfo and tagInfo.worldQuestType;
	local isDisliked = questInfo:IsDisliked();
	local typeAtlas, typeAtlasWidth, typeAtlasHeight =  WQT_Utils:GetCachedTypeIconData(questInfo);
	local isWatched = QuestUtils_IsQuestWatched(questInfo.questId);

	-- Ring coloration
	local ringType = WQT_Utils:GetSetting("pin", "ringType");
	local now = time();
	local r, g, b = _V["WQT_COLOR_CURRENCY"]:GetRGB();
	self.RingBG:SetShown(ringType == _V["RING_TYPES"].time and 1 or 0);
	self.Ring:SetCooldownUNIX(now, now);
	self.Pointer:Hide();
	self.Ring:Show();
	self.RingBG:Show();
	if (ringType == _V["RING_TYPES"].reward) then
		r, g, b = questInfo:GetRewardColor():GetRGB();
	elseif (questQuality and ringType == _V["RING_TYPES"].rarity) then
		if (questQuality > Enum.WorldQuestQuality.Common and WORLD_QUEST_QUALITY_COLORS[questQuality]) then
			r, g, b = WORLD_QUEST_QUALITY_COLORS[questQuality].color:GetRGB();
		end
	elseif (ringType == _V["RING_TYPES"].hide) then
		self.Ring:Hide();
		self.RingBG:Hide();
	end
	
	if (isDisliked) then
		r, g, b = 1, 1, 1;
	end
	
	self.RingBG:SetVertexColor(r*0.25, g*0.25, b*0.25);
	self.Ring:SetSwipeColor(r*.8, g*.8, b*.8);
	
	-- Elite indicator
	local isElite = tagInfo and tagInfo.isElite;
	local settingEliteRing = WQT_Utils:GetSetting("pin", "eliteRing");
	local useEliteRing = settingEliteRing and ringType ~= _V["RING_TYPES"].hide;
	self.RingBG:SetTexture("Interface/Addons/WorldQuestTab/Images/PoIRing");
	self.Ring:SetSwipeTexture("Interface/Addons/WorldQuestTab/Images/PoIRing");
	if (useEliteRing) then
		self.CustomUnderlay:SetShown(false);
		if(isElite) then
			self.RingBG:SetTexture("Interface/Addons/WorldQuestTab/Images/PoIRingElite");
			self.Ring:SetSwipeTexture("Interface/Addons/WorldQuestTab/Images/PoIRingElite");
		else
			
		end
	else
		self.CustomUnderlay:SetShown(isElite);
	end
	
	self.CustomUnderlay:SetDesaturated(isDisliked);
	
	-- Setup mini icons
	self.iconPool:ReleaseAll();
	wipe(self.icons);
	
	-- Quest Type Icon
	local typeAtlas, typeAtlasWidth, typeAtlasHeight =  WQT_Utils:GetCachedTypeIconData(questInfo);
	local showTypeIcon = WQT_Utils:GetSetting("pin", "typeIcon") and (not tagInfo or (questType and questType > 0 and questType ~= Enum.QuestTagType.Normal) or questInfo.isAllyQuest);
	if (showTypeIcon and typeAtlas) then
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

	-- Quest tracked icon
	if (WQT_Utils:GetSetting("pin", "timeIcon")) then
		local start, total, timeLeft, seconds, color, timeStringShort, timeCategory = WQT_Utils:GetPinTime(self.questInfo);
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
	
	-- Reward Type Icon
	local numRewardIcons = WQT_Utils:GetSetting("pin", "numRewardIcons");
	for k, rewardInfo in questInfo:IterateRewards() do
		if (k <= numRewardIcons) then
			local iconFrame = self:AddIcon();
			iconFrame:SetupRewardIcon(rewardInfo.type, rewardInfo.subType);
		end
	end
	
	-- Quest tracked icon
	if (isWatched) then
		local iconFrame = self:AddIcon();
		iconFrame:SetupIcon("worldquest-emissary-tracker-checkmark");
		iconFrame:SetIconScale(1.1);
	end
	
	self:PlaceMiniIcons();
	
	-- Main Icon
	self.CustomTypeIcon:SetShown(false);
	self.CustomSelectedGlow:Hide()
	self.CustomBountyRing:Hide()

	self.Icon:SetTexture("Interface/PETBATTLES/BattleBar-AbilityBadge-Neutral");
	self.Icon:SetTexCoord(0.06, 0.93, 0.05, 0.93);
	self.Icon:SetDesaturated(false);
	self.Icon:SetScale(1);
	self.Icon:Show();

	if(settingCenterType == _V["PIN_CENTER_TYPES"].reward) then
		local rewardTexture = questInfo:GetRewardTexture();
		self.Icon:SetTexture(rewardTexture);
		self.Icon:SetTexCoord(0, 1, 0, 1);
	elseif(settingCenterType == _V["PIN_CENTER_TYPES"].blizzard) then
		self.CustomTypeIcon:SetShown(true);
		local selected = questInfo.questId == C_SuperTrack.GetSuperTrackedQuestID();
		local showSlectedGlow = tagInfo and questQuality ~= Enum.WorldQuestQuality.Common and selected;
		local selectedBountyOnly = WQT_Utils:GetSetting("general", "bountySelectedOnly");
		
		self.CustomBountyRing:SetShown(questInfo:IsCriteria(selectedBountyOnly));
		self.CustomSelectedGlow:SetShown(showSlectedGlow);
		if (tagInfo) then
			if (questQuality == Enum.WorldQuestQuality.Rare) then
				self.Icon:SetAtlas("worldquest-questmarker-rare");
				self.CustomSelectedGlow:SetAtlas("worldquest-questmarker-rare");
			elseif (questQuality == Enum.WorldQuestQuality.Epic) then
				self.Icon:SetAtlas("worldquest-questmarker-epic")
				self.CustomSelectedGlow:SetAtlas("worldquest-questmarker-epic");
			else
				self.Icon:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
				if (selected) then
					self.Icon:SetTexCoord(0.52, 0.605, 0.395, 0.48);
				else
					self.Icon:SetTexCoord(0.895, 0.98, 0.395, 0.48);
				end
				self.Icon:SetScale(1.1);
			end
		else
			self.Icon:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
			self.Icon:SetTexCoord(0.895, 0.98, 0.395, 0.48);
			self.Icon:SetDesaturated(true);
		end
		
		-- Mimic default icon
		self.CustomTypeIcon:SetAtlas(typeAtlas);
		self.CustomTypeIcon:SetSize(typeAtlasWidth, typeAtlasHeight);
		self.CustomTypeIcon:SetScale(.8);
	elseif(settingCenterType == _V["PIN_CENTER_TYPES"].none) then
		self.Icon:Hide();
	end
	
	if (isDisliked) then
		self.Icon:SetDesaturated(true);
	end
	self.CustomTypeIcon:SetDesaturated(isDisliked);

	-- Time
	local settingPinTimeLabel =  WQT_Utils:GetSetting("pin", "timeLabel");
	local showTimeString = settingPinTimeLabel and timeStringShort ~= "";
	self.Time:SetShown(showTimeString);
	self.TimeBG:SetShown(showTimeString);
	local timeOffset = 4;
	if(#self.icons > 0) then
		timeOffset = (#self.icons % 2 == 0) and 2 or 0;
	end
	self.Time:SetPoint("TOP", self, "BOTTOM", 1, timeOffset);

	self:SetIconsDesaturated(isDisliked);
	self:UpdatePinTime();
	self:UpdatePlacement();
end

function WQT_PinMixin:OnUpdate(elapsed)
	self.updateTime = self.updateTime + elapsed;
	if (self.isExpired or self.updateTime < self.updateInterval) then return; end
	self.updateTime = self.updateTime - self.updateInterval;
	
	local timeLeft = self:UpdatePinTime();
	-- For the last minute we want to update every second for the time label
	self.updateInterval = timeLeft > SECONDS_PER_MIN * 16 and 60 or 1;
	
end

function WQT_PinMixin:UpdatePinTime()
	local start, total, timeLeft, seconds, color, timeStringShort, timeCategory = WQT_Utils:GetPinTime(self.questInfo);
	local isDisliked = self.questInfo:IsDisliked();
	
	if (WQT_Utils:GetSetting("pin", "ringType") == _V["RING_TYPES"].time) then
		local r, g, b = color:GetRGB();
		local now = time();
		self.Pointer:SetShown(total > 0);
		if (isDisliked) then
			r, g, b = .8, .8, .8;
		end
		
		if (total > 0) then
			self.Pointer:SetRotation((timeLeft)/(total)*6.2831);
			self.Pointer:SetVertexColor(r*1.1, g*1.1, b*1.1);
			self.Ring:SetCooldownUNIX(now-start,  start + timeLeft);
		else
			self.Ring:SetCooldownUNIX(now,  now);
		end
		self.RingBG:SetVertexColor(r*0.25, g*0.25, b*0.25);
		self.Ring:SetSwipeColor(r*.8, g*.8, b*.8);
	end
	
	-- Time text under pin
	if(WQT_Utils:GetSetting("pin", "timeLabel")) then
		self.Time:SetText(timeStringShort);
		if (isDisliked) then
			self.Time:SetVertexColor(1, 1, 1);
		else
			self.Time:SetVertexColor(color.r, color.g, color.b);
		end
	end

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
	
	self:SetIconsDesaturated(isDisliked);
	
	if (timeCategory == _V["TIME_REMAINING_CATEGORY"].expired) then
		self.isExpired = true;
		return SECONDS_PER_HOUR;
	end
	
	return timeLeft;
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
	self:SetFrameLevel(self.baseFrameLevel + self.index);
	WQT_WorldQuestFrame:TriggerCallback("MapPinPlaced", self);
end

function WQT_PinMixin:GetAlphas()
	if (self.questInfo:IsDisliked()) then
		return min(self.startAlpha,0.5), 0.5;
	end
	
	return self.startAlpha, self.endAlpha;
end

function WQT_PinMixin:OnEnter()
	self:Focus();
	if (self.questInfo) then
		WQT_Utils:ShowQuestTooltip(self, self.questInfo);
		
		-- Highlight quest in list
		if (self.questId ~= WQT_QuestScrollFrame.PoIHoverId) then
			WQT_QuestScrollFrame.PoIHoverId = self.questId;
			WQT_QuestScrollFrame:DisplayQuestList();
		end
	end
end

function WQT_PinMixin:OnLeave()
	self:ClearFocus();

	GameTooltip:Hide();
	WQT:HideDebugTooltip()
	-- Stop highlight quest in list
	WQT_QuestScrollFrame.PoIHoverId = nil;
	WQT_QuestScrollFrame:DisplayQuestList();
end

function WQT_PinMixin:OnClick(button)
	WQT_Utils:HandleQuestClick(self, self.questInfo, button);
end

function WQT_PinMixin:ApplyScaledPosition(manualScale)
	local canvas = self:GetParent();
	local scale = manualScale or self.scale / self.parentMapFrame:GetCanvasScale();
	local posX, posY = self:GetNudgedPosition();
	posX = (canvas:GetWidth() * posX)/scale;
	posY = -(canvas:GetHeight() * posY)/scale;
	self:ClearAllPoints();
	self:SetPoint("CENTER", canvas, "TOPLEFT", posX, posY);
end

function WQT_PinMixin:Focus(playPing)
	if (not self.questId) then return; end
	local canvas = self:GetParent();
	local parentScaleFactor = self.scale / self.parentMapFrame:GetCanvasScale();
	
	self.fadeInAnim:Stop();
	self.fadeOutAnim:Stop();
	
	self.isFaded = false;
	
	self.isFocussed = true;
	self:SetAlpha(1);
	self:SetScale(parentScaleFactor);
	self:Show();
	self:ApplyScaledPosition();
	
	if (playPing and not self.ringAnim:IsPlaying()) then
		self.Ping:Show();
		self.PingStatic:Show();
		self.ringAnim:Play();
		self.ringAnim2:Play();
	end

	self.baseFrameLevel = PIN_FRAME_LEVEL_FOCUS;
	self:UpdatePlacement(1);
end

function WQT_PinMixin:ClearFocus()
	if (not self.questId) then return; end
	self:SetAlpha(self.currentAlpha);
	self:SetScale(self.currentScale);
	self:SetShown(self.currentAlpha > 0.05);
	self:ApplyScaledPosition(self.currentScale);
	self.isFocussed = false;
	
	if (self.ringAnim:IsPlaying()) then
		self.Ping:Hide();
		self.PingStatic:Hide();
		self.ringAnim:Stop();
		self.ringAnim2:Stop();
	end
	self.baseFrameLevel = PIN_FRAME_LEVEL_BASE;
	self:UpdatePlacement();
end

function WQT_PinMixin:FadeIn()
	if(self.fadeOutAnim:IsPlaying()) then self.fadeOutAnim:Stop(); end

	self.isFaded = false;

	if (not self.fadeInAnim:IsPlaying()) then
		self:SetAlpha(0.5);
		self.fadeInAnim.Alpha:SetFromAlpha(self:GetAlpha());
		self.fadeInAnim.Alpha:SetToAlpha(self.currentAlpha);
		self.fadeInAnim:Play();
	end
end

function WQT_PinMixin:FadeOut()
	if(self.fadeInAnim:IsPlaying()) then self.fadeInAnim:Stop(); end
	self.isFaded = true;
	if (not self.fadeOutAnim:IsPlaying()) then
		self.fadeOutAnim.Alpha:SetFromAlpha(self:GetAlpha());
		self.fadeOutAnim:Play();
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
