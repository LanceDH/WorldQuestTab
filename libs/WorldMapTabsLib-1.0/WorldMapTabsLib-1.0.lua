local lib, oldminor = LibStub:NewLibrary('WorldMapTabsLib-1.0', 2);

if not lib then return; end

lib.tabs = {};
lib.contentFrames = {};

----------------------
-- Default Mixin
----------------------
WMTL_DefaultTabMixin = CreateFromMixins(SidePanelTabButtonMixin);

function WMTL_DefaultTabMixin:OnMouseDown(button)
	if (not self.Icon) then return; end
	SidePanelTabButtonMixin.OnMouseDown(self, button);
end

function WMTL_DefaultTabMixin:OnMouseUp(button, upInside)
	if (not self.Icon) then return; end
	SidePanelTabButtonMixin.OnMouseUp(self, button, upInside);
end

function WMTL_DefaultTabMixin:OnEnter()
	if (not self.tooltipText) then return; end
	SidePanelTabButtonMixin.OnEnter(self);
end

function WMTL_DefaultTabMixin:SetChecked(checked)
	if (not self.Icon or not self.SelectedTexture) then return; end

	local alpha = 1;
	if (self.activeAtlas) then
		-- Ensure inactiveAtlas isn't empty
		if (not self.inactiveAtlas) then
			self.inactiveAtlas = self.activeAtlas;
		end

		SidePanelTabButtonMixin.SetChecked(self, checked);

		if(not checked) then
			alpha = self.activeAtlas == self.inactiveAtlas and 0.55 or 1;
		end

		if (not self.useAtlasSize) then
			self.Icon:SetSize(28, 28);
		end

	elseif (self.activeTexture) then
		-- Ensure inactiveTexture isn't empty
		if (not self.inactiveTexture) then
			self.inactiveTexture = self.activeTexture;
		end

		if (checked) then
			self.Icon:SetTexture(self.activeTexture);
		else
			self.Icon:SetTexture(self.inactiveTexture or self.activeTexture);
			alpha = self.activeTexture == self.inactiveTexture and 0.55 or 1;
		end
		self.Icon:SetSize(28, 28);
		self.SelectedTexture:SetShown(checked);
	end

	self.Icon:SetAlpha(alpha);
end

----------------------
-- Local Functions
----------------------
local MAX_TABS_PER_COLUMN = 8;

local function PlaceTabs()
	if (#lib.tabs == 0) then return; end
	local shownTabs = {};

	for i = 1, #QuestMapFrame.TabButtons, 1 do
		local tab = QuestMapFrame.TabButtons[i];
		if (tab:IsShown()) then
			tinsert(shownTabs, tab);
		end
	end

	for k, tab in ipairs(lib.tabs) do
		if (tab:IsShown()) then
			tab:ClearAllPoints();
			local numShown = #shownTabs;
			local column = floor(numShown / MAX_TABS_PER_COLUMN);
			local row = numShown % MAX_TABS_PER_COLUMN;
			local anchorTab = shownTabs[numShown];

			if (row == 0) then
				if (column == 1) then
					anchorTab = QuestMapFrame.QuestsTab;
				else
					anchorTab = shownTabs[numShown - MAX_TABS_PER_COLUMN];
				end
				tab:SetPoint("TOPLEFT", anchorTab, "TOPRIGHT", 0, 0);
			else
				tab:SetPoint("TOPLEFT", anchorTab, "BOTTOMLEFT", 0, -3);
			end
			tinsert(shownTabs, tab);
		end
	end

	wipe(shownTabs);
end

local function OnMouseUpInternal(tab, button, upInside)
	if (button == "LeftButton" and upInside) then
		lib:SetDisplayMode(tab.displayMode);
	end
end

local function OnShowInternal(tab)
	PlaceTabs();
end

local function OnHideInternal(tab, ...)
	if (not QuestMapFrame:IsVisible()) then return; end

	-- If the active tab gets hidden directly, revert to official quest tab
	if (QuestMapFrame:IsVisible() and QuestMapFrame.displayMode == tab.displayMode) then
		QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests);
	end

	PlaceTabs();
end

-- If the tab for the currently active content is hidden, default back to official quests
local function WorldMapOnShow(...)
	if (not lib.tabs) then return end

	for _, tab in ipairs(lib.tabs) do
		if (tab.displayMode == QuestMapFrame.displayMode) then
			if (not tab:IsShown()) then
				QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests);
			end
			break;
		end
	end
end

local function OnSetDisplayMode(source, displayMode)
	if (displayMode) then
		for k, contentFrame in ipairs(lib.contentFrames) do
			contentFrame:Hide();
		end
		for k, tab in ipairs(lib.tabs) do
			tab:SetChecked(false);
		end
	end
end

EventRegistry:RegisterCallback("WorldMapOnShow", WorldMapOnShow, lib);
EventRegistry:RegisterCallback("QuestLog.SetDisplayMode", OnSetDisplayMode, lib);

local BASE_TAB_ID = 100;

local function RegisterTab(tab)
	-- In case the provided tab doesn't have parentArray set, add it manually
	for _, v in ipairs(QuestMapFrame.TabButtons) do
		if (v == tab) then
			error("The tab you are trying to register is in QuestMapFrame.TabButtons. This will cause taint.");
		end
	end
	for _, v in ipairs(lib.tabs) do
		if (v == tab) then
			error("The tab you are trying to register is already registered");
		end
	end

	local id = BASE_TAB_ID + #lib.tabs;
	tab.displayMode = id;
	tinsert(lib.tabs, tab);

	tab:Show();
	tab:SetChecked(false);

	tab:HookScript("OnMouseUp", OnMouseUpInternal);
	tab:HookScript("OnShow", OnShowInternal);
	tab:HookScript("OnHide", OnHideInternal);
	
	PlaceTabs();
end

----------------------
-- Public functions
----------------------

-- Create a basic tab using provided data, or from a provided template
function lib:CreateTab(data, name)
	name = name or ("WMTL_Tab_" .. #lib.tabs);
	local usingTemplate = type(data) == "string";
	local template = usingTemplate and data or "LargeSideTabButtonTemplate";
	local newTab = CreateFrame("BUTTON", name, QuestMapFrame, template);
	if (not usingTemplate) then
		Mixin(newTab, WMTL_DefaultTabMixin);
	end

	if (type(data) == "table") then
		newTab.tooltipText = data.tooltipText;
		newTab.useAtlasSize = data.useAtlasSize;
		newTab.activeAtlas = data.activeAtlas;
		newTab.inactiveAtlas = data.inactiveAtlas or newTab.activeAtlas;
		newTab.activeTexture = data.activeTexture;
		newTab.inactiveTexture = data.inactiveTexture or newTab.activeTexture;
	end

	RegisterTab(newTab);

	return newTab;
end

-- Add a custom made tab to the list
function lib:AddCustomTab(tab)
	tab:SetParent(QuestMapFrame);
	RegisterTab(tab);

	return tab;
end

-- Create a base content frame attached to the provided tab
-- Attached to the QuestMapFrame and will show and hide if the tab is selected
function lib:CreateContentFrameForTab(tab, template, name)
	if (not tab or not tab.displayMode) then
		error("First parameter should be a tab frame with the displayMode attribute.");
	end

	name = name or ("WMTL_ContentFrame" .. tab.displayMode);
	local contentFrame = CreateFrame("Frame", name, QuestMapFrame.ContentsAnchor, template);
	tinsert(lib.contentFrames, contentFrame);
	contentFrame:SetAllPoints(QuestMapFrame.ContentsAnchor);
	lib:LinkTabToContentFrame(tab, contentFrame)
	return contentFrame;
end

-- Attach an existing frame to a tab, making it show or hide if the tab is selected
function lib:LinkTabToContentFrame(tab, contentFrame)
	if (not tab or not tab.displayMode) then
		error("First parameter should be a tab frame with the displayMode attribute.");
	end

	if (not contentFrame) then
		error("Second parameter should be a content frame.");
	end

	contentFrame.displayMode = tab.displayMode;
	contentFrame:SetParent(QuestMapFrame);

	tinsert(lib.contentFrames, contentFrame);

	-- Hide the frame because we're probably starting on the official quest log
	contentFrame:Hide();
end

-- Set the active tab to one registered in the lib
function lib:SetDisplayMode(displayMode)
	-- We can't call this with a value other than QuestLogDisplayMode or cause taint
	-- So well call it with nil to cause the official tabs to hide and then show things ourselves
	QuestMapFrame:SetDisplayMode();

	for k, contentFrame in ipairs(lib.contentFrames) do
		contentFrame:SetShown(contentFrame.displayMode == displayMode);
	end

	for k, tab in ipairs(lib.tabs) do
		tab:SetChecked(tab.displayMode == displayMode);
	end
end
