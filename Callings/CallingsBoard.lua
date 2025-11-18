local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Profiles = addon.WQT_Profiles;

local MAX_CALLINGS = 3;

local MAP_ANCHORS = {
	[1543] = { ["Point"] = "BOTTOMLEFT"}, -- The Maw
	[1536] = { ["Point"] = "BOTTOMLEFT"}, -- Maldraxxus
	[1698] = { ["Point"] = "BOTTOMLEFT"}, -- Maldraxxus
	[1525] = { ["Point"] = "BOTTOMLEFT"}, -- Revendreth
	[1699] = { ["Point"] = "BOTTOMLEFT"}, -- Revendreth Covenant
	[1700] = { ["Point"] = "BOTTOMLEFT"}, -- Revendreth Covenant
	[1670] = { ["Point"] = "BOTTOMRIGHT"}, -- Oribos
	[1671] = { ["Point"] = "BOTTOMRIGHT"}, -- Oribos
	[1672] = { ["Point"] = "BOTTOMRIGHT"}, -- Oribos
	[1673] = { ["Point"] = "BOTTOMRIGHT"}, -- Oribos
	[1533] = { ["Point"] = "BOTTOMLEFT"}, -- Bastion
	[1707] = { ["Point"] = "BOTTOMLEFT"}, -- Bastion Covenant
	[1708] = { ["Point"] = "BOTTOMLEFT"}, -- Bastion Covenant
	[1565] = { ["Point"] = "BOTTOMLEFT"}, -- Ardenweald
	[1701] = { ["Point"] = "BOTTOMLEFT"}, -- Ardenweald Covenant
	[1702] = { ["Point"] = "BOTTOMLEFT"}, -- Ardenweald Covenant
	[1703] = { ["Point"] = "BOTTOMLEFT"}, -- Ardenweald Covenant
	[1550] = { ["Point"] = "BOTTOMLEFT", ["y"] = 80}, -- Shadowlands
	[1970] = { ["Point"] = "BOTTOMLEFT"}, -- Zereth
}

local CovenantCallingsEvents = {
	"COVENANT_CALLINGS_UPDATED",
	"QUEST_TURNED_IN",
	"QUEST_ACCEPTED",
	"TASK_PROGRESS_UPDATE",
}

local function CompareCallings(a, b)
	if (a.calling.isLockedToday or b.calling.isLockedToday) then
		if (a.calling.isLockedToday == b.calling.isLockedToday) then
			return a:GetID() < b:GetID();
		end
		return not a.calling.isLockedToday;
	end
	return a.timeRemaining < b.timeRemaining;
end

WQT_CallingsBoardMixin = {};

function WQT_CallingsBoardMixin:OnLoad()
	self:SetParent(WorldMapFrame.ScrollContainer);
	self:SetPoint("BOTTOMLEFT", 15, 15);
	self:SetFrameStrata("HIGH")
	
	local numDisplays = #self.Displays;
	
	for i=1, numDisplays do
		local display = self.Displays[i];
		display.miniIcons = CreateAndInitFromMixin(WQT_MiniIconOverlayMixin, display, 270, 20, 40)
	end

	FrameUtil.RegisterFrameForEvents(self, CovenantCallingsEvents);
	
	self.lastUpdate = 0;
	self:UpdateCovenant();
	
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
			self:OnMapChanged(WorldMapFrame:GetMapID());
		end)
		
	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID, tag)
			if (tag == "CALLINGS_BOARD") then
				self:UpdateVisibility();
			end
		end,
		self);
	
	self:RequestUpdate();
end

function WQT_CallingsBoardMixin:RequestUpdate()
	C_CovenantCallings.RequestCallings();
end

function WQT_CallingsBoardMixin:OnEvent(event, ...)
	if (event == "COVENANT_CALLINGS_UPDATED") then
		local now = GetTime();
		if (now - self.lastUpdate > 0.5) then
			local callings = ...;
			self:UpdateCovenant();
			self:ProcessCallings(callings);
			
			self.lastUpdate = now;
		end
	elseif (event == "QUEST_TURNED_IN" or event == "QUEST_ACCEPTED") then
		local questID = ...;
		if (C_QuestLog.IsQuestCalling(questID)) then
			self:Update();
			self:RequestUpdate();
		end
	elseif (event == "TASK_PROGRESS_UPDATE") then
		self:Update();
	end
end

function WQT_CallingsBoardMixin:OnShow()
	-- Guarantee this thing gets updated whenever it's presented
	self:Update();
	self:RequestUpdate();
end

function WQT_CallingsBoardMixin:Update()
	self:UpdateCovenant();
	for k, display in ipairs(self.Displays) do
		display:Update();
	end
	self:PlaceDisplays();
end

function WQT_CallingsBoardMixin:OnMapChanged(mapID)
	self:UpdateCovenant();
	local anchorPoint = MAP_ANCHORS[mapID];

	if (not anchorPoint or self.covenantID == 0) then
		self.showOnCurrentMap = false;
		self:UpdateVisibility();
		return;
	end
	
	self:ClearAllPoints();
	local x = anchorPoint.x or -30;
	local y = anchorPoint.y or 15;
	if(anchorPoint.Point == "BOTTOMLEFT") then
		x = 15;
	end
	self:SetPoint(anchorPoint.Point, x, y);
	self.showOnCurrentMap = true;
	
	self:UpdateVisibility();
end

function WQT_CallingsBoardMixin:UpdateCovenant()
	local covenantID = C_Covenants.GetActiveCovenantID();
	if (self.covenantID == covenantID) then
		return;
	end

	self.covenantID = covenantID;
	local data = C_Covenants.GetCovenantData(covenantID);
	self.covenantData = data;
	if (data) then
		for k, display in ipairs(self.Displays) do
			display:SetCovenant(data);
		end
		local bgAtlas = string.format("covenantsanctum-level-border-%s", data.textureKit:lower());
		self.BG:SetAtlas(bgAtlas);
	end
end

function WQT_CallingsBoardMixin:ProcessCallings(callings)
	if (self.isUpdating) then
		-- 1 Update at a time, ty
		return;
	end
	self.isUpdating = true;

	self.callings = callings;
	-- Better safe than error
	if (not callings or not self.covenantData) then 
		self.isUpdating = false;
		return; 
	end
	
	local numDisplays = #self.Displays;
	
	for i=1, numDisplays do
		local display = self.Displays[i];
		local calling = callings[i];
		calling = CovenantCalling_Create(calling);
		display:Setup(calling, self.covenantData);
	end
	
	table.sort(self.Displays, CompareCallings);
	
	self:PlaceDisplays();
	
	self.isUpdating = false;
end

function WQT_CallingsBoardMixin:PlaceDisplays()
	local numDisplays = #self.Displays;
	local numInactive = 0;
	for i=1, numDisplays do
		local display = self.Displays[i];
		local width = display:GetWidth();
		local x = -((numDisplays-1) * width)/2;
		x = x + width * (i-1);
		
		if (display.calling and not display.calling.questID) then
			-- Not risking Constants.Callings.MaxCallings 
			display.calling.index = MAX_CALLINGS - numInactive;
			numInactive = numInactive + 1;
		end
		
		display:SetPoint("CENTER", self, x, 0);
	end
end

function WQT_CallingsBoardMixin:UpdateVisibility()
	if (not WQT.settings.general.sl_callingsBoard) then
		-- If we're not welcome, don't show;
		self:Hide();
		return;
	end
	
	self:SetShown(self.showOnCurrentMap);
end

function WQT_CallingsBoardMixin:CalculateUncappedObjectives(calling)
	local numCompleted = 0;
	local numTotal = 0;

	for objectiveIndex = 1, calling.numObjectives do
		local objectiveText, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(calling.questID, objectiveIndex, false);
		
		if(objectiveType == "progressbar") then
			return GetQuestProgressBarPercent(calling.questID), 100;
		end
		
		if objectiveText and #objectiveText > 0 and numRequired > 0 then
			for objectiveSubIndex = 1, numRequired do
				if objectiveSubIndex <= numFulfilled then
					numCompleted = numCompleted + 1;
				end
				numTotal = numTotal + 1;
			end
		end
	end
	
	return numCompleted, numTotal;
end

function WQT_CallingsBoardMixin:GetQuestData(questID) 
	for k, display in ipairs(self.Displays) do
		if (display.calling and display.calling.questID == questID) then
			return display.questInfo, display.calling;
		end
	end
end

WQT_CallingsBoardDisplayMixin = {};

function WQT_CallingsBoardDisplayMixin:OnLoad()
	self.calling = CovenantCalling_Create();
	self.timeRemaining = 0;
end

function WQT_CallingsBoardDisplayMixin:SetCovenant(covenantData)
	self.covenantData = covenantData;
	
	if(covenantData) then
		local bgAtlas = string.format("covenantsanctum-level-border-%s", covenantData.textureKit:lower());
		self.ProgressBar.BG:SetAtlas(bgAtlas);
		
		local r, g, b = 1, 1, 1;
		if(covenantData.ID == Enum.CovenantType.Kyrian) then
			r = 0.6;
			g = 0.74;
			b = 0.85;
		elseif(covenantData.ID == Enum.CovenantType.Venthyr) then
			r = 0.86;
			g = 0.11;
			b = 0.11;
		elseif(covenantData.ID == Enum.CovenantType.NightFae) then
			r = 0.31;
			g = 0.55;
			b = 1;
		elseif(covenantData.ID == Enum.CovenantType.Necrolord) then
			r = 0.05;
			g = 0.74;
			b = 0.42;
		end
		
		self.ProgressBar.Glow:SetVertexColor(r, g, b);
	end
end

function WQT_CallingsBoardDisplayMixin:Setup(calling, covenantData)
	self.calling = calling;
	self:SetCovenant(covenantData);
	
	self.timeRemaining = 0;
	self.questInfo = nil;
	
	if (self.calling.questID) then
		local questInfo = WQT_Utils:QuestCreationFunc();
		questInfo:Init(self.calling.questID);
		self.questInfo = questInfo;
		self.timeRemaining = C_TaskQuest.GetQuestTimeLeftSeconds(calling.questID) or 0;
	end
	
	self:Update();
end

function WQT_CallingsBoardDisplayMixin:Update()
	if (not self.covenantData) then return; end
	
	self.Bang:Hide();
	self.Glow:Hide();
	
	-- If we have no calling data yet, just make it look like an empty one for now
	if (not self.calling) then
		local tempIcon = ("Interface/Pictures/Callings-%s-Head-Disable"):format(self.covenantData.textureKit);
		self.Icon:SetTexture(tempIcon);
		return;
	end

	local icon;
	if (self.calling.isLockedToday) then 
		icon = ("Interface/Pictures/Callings-%s-Head-Disable"):format(self.covenantData.textureKit);
	else
		icon = self.calling.icon;
	end
	
	self.Icon:SetTexture(icon);
	self.Highlight:SetTexture(icon);

	if (self.calling.questID) then
		local questID = self.calling.questID;
		local onQuest = C_QuestLog.IsOnQuest(questID);
		local questComplete =  C_QuestLog.IsComplete(questID);
		self.Glow:SetShown(not onQuest);

		local bangAtlas = self.calling:GetBang();
		self.Bang:SetAtlas(bangAtlas);
		self.BangHighlight:SetAtlas(bangAtlas);
		self.Bang:SetShown(bangAtlas);
	end
	
	self:UpdateProgress();
end

function WQT_CallingsBoardDisplayMixin:UpdateProgress()
	self.miniIcons:Reset();
	self.BangHighlight:Hide();
	self.ProgressBar:Hide();
	
	if (not self.calling:IsActive()) then
		return;
	end
	
	local progress, goal = WQT_CallingsBoardMixin:CalculateUncappedObjectives(self.calling);

	if (progress >= goal) then 
		self.BangHighlight:Show();
		return;
	end
	
	if (goal > 4) then 
		self.ProgressBar:Show();
		local perc = progress / goal;
		local width = self.ProgressBar:GetWidth();
		
		self.ProgressBar.Glow:SetPoint("RIGHT", self.ProgressBar, "LEFT", perc * width, 0);
	
		return
	end
	
	for i=1, goal do
		local icon = self.miniIcons:Create();
		local atlas = ("%sassaultsquest-32x32"):format(self.covenantData.textureKit);
		local vertCol = 1; 
		local desaturate;
		
		if (i > progress) then
			vertCol = 0.65;
			desaturate = true;
		end
		icon:SetupIcon(atlas);
		icon:SetIconSize(12, 12);
		icon:SetDesaturated(desaturate);
		icon:SetIconColorRGBA(vertCol, vertCol, vertCol);
	end
end



function WQT_CallingsBoardDisplayMixin:OnEnter()
	if (not self.calling) then return; end
	
	if (self.calling.isLockedToday) then 
		local days = MAX_CALLINGS - self.calling.index + 1;
		local daysUntilString = _G["BOUNTY_BOARD_NO_CALLINGS_DAYS_" .. days] or BOUNTY_BOARD_NO_CALLINGS_DAYS_1;
		
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(daysUntilString, HIGHLIGHT_FONT_COLOR:GetRGB());
		GameTooltip:Show();
	else
		self.Highlight:Show();
		if (self.calling:IsActive()) then
			WQT_Utils:ShowQuestTooltip(self, self.questInfo, _V["TOOLTIP_STYLES"].callingActive);
		else
			WQT_Utils:ShowQuestTooltip(self, self.questInfo, _V["TOOLTIP_STYLES"].callingAvailable);
		end
	end
end

function WQT_CallingsBoardDisplayMixin:OnLeave()
	self.Highlight:Hide();
	GameTooltip:Hide();
end

function WQT_CallingsBoardDisplayMixin:OnClick()
	if (self.calling.isLockedToday) then return; end

	local openDetails = false;
	
	if (self.calling:GetState() == Enum.CallingStates.QuestActive and not WorldMapFrame:IsMaximized()) then
		openDetails = true;
	end
	
	if (openDetails) then
		QuestMapFrame_OpenToQuestDetails(self.calling.questID);
	else
		local mapID = GetQuestUiMapID(self.calling.questID, true);
		if ( mapID ~= 0 ) then
			WorldMapFrame:SetMapID(mapID);
		else
			OpenWorldMap(C_TaskQuest.GetQuestZoneID(self.calling.questID));
		end
	end
end








