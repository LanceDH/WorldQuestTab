---
--- Author: LanceDH
--- Source: https://github.com/LanceDH/LibWorldMapTabs
---
--- Copyright (c) 2025 LanceDH
--- 
--- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
--- (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, 
--- merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished 
--- to do so, subject to the following conditions:
--- 
--- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--- 
--- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
--- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
--- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
--- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--- 

local lib, oldminor = LibStub:NewLibrary('LibWorldMapTabs', 4);

if not lib then return; end

-- Just in case, unregister callbacks of old version
EventRegistry:UnregisterCallback("WorldMapOnShow", lib);
EventRegistry:UnregisterCallback("QuestLog.SetDisplayMode", lib);

lib.tabs = lib.tabs or {};
lib.contentFrames = lib.contentFrames or {};
lib.internal = lib.internal or {};

local MAX_TABS_PER_COLUMN = 8;
local DISPLAYMODE_FORMAT = "LWMT_%d";
local TAB_NAME_FORMAT = "LWMT_Tab_%d";
local CONTENT_FRAME_NAME_FORMAT = "LWMT_Content_%s";

----------------------
-- Default Mixin
----------------------
if (not LWMT_DefaultTabMixin) then
	LWMT_DefaultTabMixin = CreateFromMixins(SidePanelTabButtonMixin);

	function LWMT_DefaultTabMixin:OnMouseDown(button)
		if (not self.Icon) then return; end
		SidePanelTabButtonMixin.OnMouseDown(self, button);
	end

	function LWMT_DefaultTabMixin:OnMouseUp(button, upInside)
		if (not self.Icon) then return; end
		SidePanelTabButtonMixin.OnMouseUp(self, button, upInside);
	end

	function LWMT_DefaultTabMixin:OnEnter()
		if (not self.tooltipText) then return; end
		SidePanelTabButtonMixin.OnEnter(self);
	end

	function LWMT_DefaultTabMixin:SetChecked(checked)
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
end

----------------------
-- Local Functions
----------------------
function lib.internal:PlaceTabs()
	if (not QuestMapFrame or not QuestMapFrame:IsShown()) then return; end
	local shownTabs = {};
	local unofficialTabs = {};
	local mapChildren = { QuestMapFrame:GetChildren() };

	local officialModes = {};
	for id, value in pairs(QuestLogDisplayMode) do
		officialModes[value] = true;
	end

	for k, child in ipairs(mapChildren) do
		if (child.displayMode and child.OnEnter and child:IsShown()) then
			if (officialModes[child.displayMode]) then
				tinsert(shownTabs, child);
			else
				tinsert(unofficialTabs, child);
			end
		end
	end

	-- Clear points to avoid circular anchoring
	for k, tab in ipairs(unofficialTabs) do
		tab:ClearAllPoints();
	end

	-- Place unknown tabs
	for k, tab in ipairs(unofficialTabs) do
		local numShown = #shownTabs;
		local row = numShown % MAX_TABS_PER_COLUMN;

		local relativePoint = "BOTTOMLEFT";
		local offsetX = 0;
		local offsetY = -3;
		local anchorTab = shownTabs[numShown];

		if (row == 0) then
			anchorTab = shownTabs[numShown + 1 - MAX_TABS_PER_COLUMN ];
			relativePoint = "TOPRIGHT";
			offsetY = 0;
		end

		tab:SetPoint("TOPLEFT", anchorTab, relativePoint, offsetX, offsetY);
		tinsert(shownTabs, tab);
	end

	mapChildren = nil;
	officialModes = nil;
	shownTabs = nil;
	unofficialTabs = nil;
end

function lib.internal:OnMouseUpInternal(tab, button, upInside)
	if (button == "LeftButton" and upInside) then
		lib:SetDisplayMode(tab.displayMode);
	end
end

function lib.internal:OnShowInternal(tab)
	if(tab.fromDirectShowCall) then
		lib.internal:PlaceTabs();
	end
	tab.fromDirectShowCall = false;
end

function lib.internal:OnHideInternal(tab, ...)
	if (not QuestMapFrame:IsVisible()) then return; end

	-- If the active tab gets hidden directly, revert to official quest tab
	if (QuestMapFrame:IsVisible() and lib.activeDisplayMode == tab.displayMode) then
		QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests);
	end

	lib.internal:PlaceTabs();
end


function lib.internal:WorldMapOnShow(...)
	-- Delay to next frame because addons not using this library might be anchoring their tab on WorldMapOnShow
	C_Timer.After(0, function() lib.internal:PlaceTabs(); end);
	
	if (not lib.tabs) then return end
	-- If the tab for the currently active content is hidden, default back to official quests
	for _, tab in ipairs(lib.tabs) do
		if (tab.displayMode == lib.activeDisplayMode) then
			if (not tab:IsShown()) then
				QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests);
			end
			break;
		end
	end
end

function lib.internal:OnSetDisplayMode(source, displayMode)
	if (displayMode) then
		for k, contentFrame in ipairs(lib.contentFrames) do
			contentFrame:Hide();
		end
		for k, tab in ipairs(lib.tabs) do
			tab:SetChecked(false);
		end

		lib.activeDisplayMode = nil;
	end
end

EventRegistry:RegisterCallback("WorldMapOnShow", function(...) lib.internal:WorldMapOnShow(...); end, lib);
EventRegistry:RegisterCallback("QuestLog.SetDisplayMode", function(...) lib.internal:OnSetDisplayMode(...); end, lib);

function lib.internal:RegisterTab(tab)
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

	tab.displayMode = string.format(DISPLAYMODE_FORMAT, #lib.tabs);
	tinsert(lib.tabs, tab);

	tab:Show();
	tab:SetChecked(false);

	local originalSetShown = tab.SetShown;
	tab.SetShown = function(...)
		tab.fromDirectShowCall = true;
		originalSetShown(...);
	end;

	local originalShow = tab.Show;
	tab.Show = function(...)
		tab.fromDirectShowCall = true;
		originalShow(...);
	end;

	tab:HookScript("OnMouseUp", function(...) lib.internal:OnMouseUpInternal(...); end);
	tab:HookScript("OnShow", function(...) lib.internal:OnShowInternal(...); end);
	tab:HookScript("OnHide", function(...) lib.internal:OnHideInternal(...); end);
	
	self:PlaceTabs();
end

----------------------
-- Public functions
----------------------

-- Create a basic tab using provided data, or from a provided template
function lib:CreateTab(data, name)
	name = name or string.format(TAB_NAME_FORMAT, #lib.tabs);
	local usingTemplate = type(data) == "string";
	local template = usingTemplate and data or "LargeSideTabButtonTemplate";
	local newTab = CreateFrame("BUTTON", name, QuestMapFrame, template);
	if (not usingTemplate) then
		Mixin(newTab, LWMT_DefaultTabMixin);
	end

	if (type(data) == "table") then
		newTab.tooltipText = data.tooltipText;
		newTab.useAtlasSize = data.useAtlasSize;
		newTab.activeAtlas = data.activeAtlas;
		newTab.inactiveAtlas = data.inactiveAtlas or newTab.activeAtlas;
		newTab.activeTexture = data.activeTexture;
		newTab.inactiveTexture = data.inactiveTexture or newTab.activeTexture;
	end

	lib.internal:RegisterTab(newTab);

	return newTab;
end

-- Add a custom made tab to the list
function lib:AddCustomTab(tab)
	tab:SetParent(QuestMapFrame);
	lib.internal:RegisterTab(tab);

	return tab;
end

-- Create a base content frame attached to the provided tab
-- Attached to the QuestMapFrame and will show and hide if the tab is selected
function lib:CreateContentFrameForTab(tab, template, name)
	if (not tab or not tab.displayMode) then
		error("First parameter should be a tab frame with the displayMode attribute.");
	end

	name = name or string.format(CONTENT_FRAME_NAME_FORMAT, tab.displayMode);
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
	lib.activeDisplayMode = displayMode;

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
