local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-1.0");
local WQT_Utils = addon.WQT_Utils;

local SETTINGS_PADDING_TOP = 5;
local SETTINGS_PADDING_BOTTOM = 15;

--------------------------------
-- WQT_SettingsBaseMixin
--------------------------------

WQT_SettingsBaseMixin = {};

function WQT_SettingsBaseMixin:OnLoad()
	-- Override me
end

function WQT_SettingsBaseMixin:OnEnter(anchorFrame, anchorType)
	if (self.label and self.tooltip) then
		GameTooltip:SetOwner(anchorFrame or self, anchorType or "ANCHOR_RIGHT");
		GameTooltip:SetText(self.label, 1, 1, 1, true);
		GameTooltip:AddLine(self.tooltip, nil, nil, nil, true);
		GameTooltip:Show();
	end
end

function WQT_SettingsBaseMixin:OnLeave()
	GameTooltip:Hide();
end

function WQT_SettingsBaseMixin:Init(data)
	self.label = data.label;
	self.tooltip = data.tooltip;
	self.valueChangedFunc = data.valueChangedFunc;
	self.isDisabled = data.isDisabled;
	if (self.Label) then
		self.Label:SetText(data.label);
	end
end

function WQT_SettingsBaseMixin:Reset()
	self.label = nil;
	self.tooltip = nil;
	self.valueChangedFunc = nil;
	if (self.Label and not self.staticLabelFont) then
		self.Label:SetFontObject("GameFontNormal")
	end
end

function WQT_SettingsBaseMixin:IsDisabled()
	if (type(self.isDisabled) == "function") then
		return self.isDisabled();
	end
	return  self.isDisabled;
end

function WQT_SettingsBaseMixin:OnValueChanged(value, userInput)
	if (userInput and self.valueChangedFunc) then
		self.valueChangedFunc(value);
		WQT_SettingsFrame:UpdateList();
	end
end

function WQT_SettingsBaseMixin:UpdateState()
	self:SetDisabled(self:IsDisabled());
end

function WQT_SettingsBaseMixin:SetDisabled(value)
	if (self.Label and not self.staticLabelFont) then
		self.Label:SetFontObject(value and "GameFontDisable" or "GameFontNormal");
	end
end

--------------------------------
-- WQT_SettingsQuestListMixin
--------------------------------

WQT_SettingsQuestListMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsQuestListMixin:OnLoad()
	local questFrame = self.Preview;
	questFrame.Faction:SetScript("OnEnter", nil);
	questFrame.Title:SetText("Example Quest Title");
	questFrame.Faction.Icon:SetTexture(2058205);
	local typeFrame = questFrame.Type;
	typeFrame.Texture:Show();
	typeFrame.Elite:SetShown(true);
	typeFrame.Bg:SetAtlas("worldquest-questmarker-rare");
	typeFrame.Bg:SetTexCoord(0, 1, 0, 1);
	typeFrame.Bg:SetSize(18, 18);
	
	typeFrame.Texture:SetAtlas("worldquest-icon-dungeon");
	typeFrame.Texture:SetSize(16, 17);
	typeFrame:Show();
	
	questFrame.Time:SetVertexColor(0, 0.75, 0);
	local mapInfo = WQT_Utils:GetCachedMapInfo(942);
	self.zoneName = mapInfo.name;
	questFrame.Extra:SetText(self.zoneName);
	
	questFrame.Reward:Show();
	questFrame.Reward.Icon:SetTexture(1733697);
	questFrame.Reward.Icon:Show();
	questFrame.Reward.Amount:SetText(410);
	questFrame.Reward.Amount:Show();
	questFrame.Reward.IconBorder:SetVertexColor(0, 0.44, 0.87);
	questFrame.Reward.IconBorder:Show();
end

function WQT_SettingsQuestListMixin:UpdateState()
	local questFrame = self.Preview;
	questFrame.Title:ClearAllPoints()
	questFrame.Title:SetPoint("RIGHT", questFrame.Reward, "LEFT", -5, 0);
	if (WQT.settings.list.factionIcon) then
		questFrame.Title:SetPoint("BOTTOMLEFT", questFrame.Faction, "RIGHT", 5, 1);
	elseif (WQT.settings.list.typeIcon) then
		questFrame.Title:SetPoint("BOTTOMLEFT", questFrame.Type, "RIGHT", 5, 1);
	else
		questFrame.Title:SetPoint("BOTTOMLEFT", questFrame, "LEFT", 10, 0);
	end

	-- Faction Icon
	if (WQT.settings.list.factionIcon) then
		questFrame.Faction:Show();
		questFrame.Faction:SetWidth(questFrame.Faction:GetHeight());
	else
		questFrame.Faction:Hide();
		questFrame.Faction:SetWidth(0.1);
	end
	
	-- Type icon
	if (WQT.settings.list.typeIcon) then
		questFrame.Type:Show();
		questFrame.Type:SetWidth(questFrame.Type:GetHeight());
	else
		questFrame.Type:Hide();
		questFrame.Type:SetWidth(0.1);
	end
	
	-- Zone name
	questFrame.Extra:SetText(WQT.settings.list.showZone and self.zoneName or "");

	-- Adjust time and zone sizes
	local extraSpace = WQT.settings.list.factionIcon and 0 or 14;
	extraSpace = extraSpace + (WQT.settings.list.typeIcon and 0 or 14);
	local timeWidth = extraSpace + (WQT.settings.list.fullTime and 70 or 60);
	local zoneWidth = extraSpace + (WQT.settings.list.fullTime and 80 or 90);
	if (not WQT.settings.list.showZone) then
		timeWidth = timeWidth + zoneWidth;
		zoneWidth = 0.1;
	end
	questFrame.Time:SetWidth(timeWidth)
	questFrame.Extra:SetWidth(zoneWidth)
	
	-- Time display
	-- 74160s == 20h 36m
	local timeString;
	if (WQT.settings.list.fullTime) then
		timeString = SecondsToTime(74160, true, false);
	else
		timeString = D_HOURS:format(74160 / SECONDS_PER_HOUR);
	end
	questFrame.Time:SetText(timeString);
	
	-- Reward colors
	if ( WQT.settings.list.amountColors) then
		questFrame.Reward.Amount:SetVertexColor(0.85, 0.6, 1);
	else
		questFrame.Reward.Amount:SetVertexColor(1, 1, 1);
	end
end

--------------------------------
-- WQT_SettingsCheckboxMixin
--------------------------------

WQT_SettingsCheckboxMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsCheckboxMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self:UpdateState();
end

function WQT_SettingsCheckboxMixin:Reset()
	WQT_SettingsBaseMixin.Reset(self);
	self.CheckBox:Enable();
end

function WQT_SettingsCheckboxMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if (self.getValueFunc) then
		self.CheckBox:SetChecked(self.getValueFunc());
	end
end

function WQT_SettingsCheckboxMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.CheckBox:Disable();
	else
		self.CheckBox:Enable();
	end
end

--------------------------------
-- WQT_SettingsSliderMixin
--------------------------------

WQT_SettingsSliderMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsSliderMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self.min = data.min or 0;
	self.max = data.max or 1;
	self.Slider:SetMinMaxValues(self.min, self.max);
	self.Slider:SetValueStep(data.valueStep);
	self.Slider:SetObeyStepOnDrag(data.valueStep and true or false)
	self:UpdateState();
end

function WQT_SettingsSliderMixin:Reset()
	WQT_SettingsBaseMixin.Reset(self);
end

function WQT_SettingsSliderMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if (self.getValueFunc) then
		local currentValue = self.getValueFunc();
		self.Slider:SetValue(currentValue);
		self.TextBox:SetText(Round(currentValue*100)/100);
		self.current = currentValue;
	end
end

function WQT_SettingsSliderMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.Slider:Disable();
		self.TextBox:Disable();
	else
		self.Slider:Enable();
		self.TextBox:Enable();
	end
end

function WQT_SettingsSliderMixin:OnValueChanged(value, userInput)
	-- Prevent non-number input
	value = tonumber(value);
	if (not value) then 
		-- Reset displayed values
		self:UpdateState();
		return; 
	end
	value = Round(value*100)/100;
	value = min(self.max, max(self.min, value));
	if (userInput and value ~= self.current) then
		WQT_SettingsBaseMixin.OnValueChanged(self, value, userInput);
	end
	self:UpdateState();
end

--------------------------------
-- WQT_SettingsDropDownMixin
--------------------------------

WQT_SettingsDropDownMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsDropDownMixin:OnLoad()
	self.DropDown = ADD:CreateMenuTemplate(nil, self, nil, "BUTTON");
	self.DropDown:SetSize(150, 22);
	self.DropDown:SetPoint("BOTTOMLEFT", self, 27, 0);
	self.DropDown:EnableMouse(true);
	self.DropDown:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); end);
	self.DropDown:SetScript("OnEnter", function() self:OnEnter(self.DropDown) end);
	self.DropDown:SetScript("OnLeave", function() self:OnLeave() end);
end

function WQT_SettingsDropDownMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.DropDown:Disable();
	else
		self.DropDown:Enable();
	end
end

function WQT_SettingsDropDownMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	
	if (data.options) then
		ADD:Initialize(self.DropDown, function(dropDown, level)
			local info = ADD:CreateInfo();
			info.func = function(option, value, label) 
					self:OnValueChanged(value, true);
					ADD:SetText(dropDown, label);
				end
			local selected;
			if (data.getValueFunc) then
				selected = data.getValueFunc();
			end
			
			for id, displayInfo in pairs(data.options) do
				info.value = id;
				info.arg1 = id;
				info.text = displayInfo.label; 
				info.arg2 = displayInfo.label;
				info.tooltipTitle = displayInfo.label;
				info.tooltipText = displayInfo.tooltip;
				info.tooltipOnButton = true;

				if id == selected then
					info.checked = 1;
				else
					info.checked = nil;
				end
				ADD:AddButton(info, level);
			end
		end);
		if (data.getValueFunc) then
			local id = data.getValueFunc();
			local label = data.options[id].label;
			ADD:SetText(self.DropDown, label);
		end
	end
	
	self:UpdateState();
end

--------------------------------
-- WQT_SettingsButtonMixin
--------------------------------

WQT_SettingsButtonMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsButtonMixin:OnLoad()
	self.Label = self.Button.Label;
end

function WQT_SettingsButtonMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.Button:Disable();
	else
		self.Button:Enable();
	end
end

function WQT_SettingsButtonMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self:UpdateState();
end

--------------------------------
-- WQT_SettingsFrameMixin
--------------------------------

WQT_SettingsFrameMixin = {};

function WQT_SettingsFrameMixin:OnLoad()
	-- Because we can't destroy frames, keep a pool of each type to re-use
	self.categoryPool = CreateFramePool("BUTTON", self.ScrollFrame.ScrollChild, "WQT_SettingCategoryTemplate");
	self.checkBoxPool = CreateFramePool("FRAME", self.ScrollFrame.ScrollChild, "WQT_SettingCheckboxTemplate", function(pool, frame) frame:Reset(); end);
	self.subTitlePool = CreateFramePool("FRAME", self.ScrollFrame.ScrollChild, "WQT_SettingSubTitleTemplate", function(pool, frame) frame:Reset(); end);
	self.sliderPool = CreateFramePool("FRAME", self.ScrollFrame.ScrollChild, "WQT_SettingSliderTemplate", function(pool, frame) frame:Reset(); end);
	self.dropDownPool = CreateFramePool("FRAME", self.ScrollFrame.ScrollChild, "WQT_SettingDropDownTemplate", function(pool, frame) frame:Reset(); end);
	self.buttonPool = CreateFramePool("FRAME", self.ScrollFrame.ScrollChild, "WQT_SettingButtonTemplate", function(pool, frame) frame:Reset(); end);
	
	self.categoryless = {};
	self.categories = {};
	self.categoriesLookup = {};
	
	self.bufferedSettings = {};
end

function WQT_SettingsFrameMixin:LoadWQTSettings()
	-- Initialize 'official' settings
	self.WQTLoaded = true;
	for k, data in ipairs(_V["SETTING_CATEGORIES"]) do
		self:RegisterCategory(data);
	end
	self:SetCategoryExpanded("GENERAL", true);
	
	self:AddSettingList(_V["SETTING_LIST"]);

	-- Add buffered settings from other add-ons
	self:AddSettingList(self.bufferedSettings);
end

function WQT_SettingsFrameMixin:SetCategoryExpanded(id, value)
	local category = self.categoriesLookup[id];
	
	if (category) then
		category.isExpanded = value;
		if (category.isExpanded) then
			category.ExpandIcon:SetAtlas("friendslist-categorybutton-arrow-down", true);
		else
			category.ExpandIcon:SetAtlas("friendslist-categorybutton-arrow-right", true);
		end
		self:Refresh();
	end
end

function WQT_SettingsFrameMixin:RegisterCategory(data)
	local category = self.categoriesLookup[data.id];
	-- Category already exists
	if (category) then
		-- Update label if provided
		if (data.label) then
			category.Title:SetText(data.label)
		end
		return;
	end
	
	category =  self:CreateCategory(data)
	
end

function WQT_SettingsFrameMixin:CreateCategory(data)
	local category = self.categoryPool:Acquire();
	category.Title:SetText(data.label or data.id)
	category.id = data.id;
	category.isExpanded = false;
	category.settings = {};
	
	-- Include a specific preview frame if provided
	if (data.previewFrame) then
		local frame = _G[data.previewFrame];
		if (frame) then
			frame:SetParent(self.ScrollFrame.ScrollChild);
			if (frame.UpdateState) then
				frame:UpdateState();
			end
			tinsert(category.settings,frame);
		end
	end
	
	tinsert(self.categories, category);
	self.categoriesLookup[data.id] = category;
	return category;
end

function WQT_SettingsFrameMixin:UpdateList()
	for k, setting in ipairs(self.categoryless) do
		if (setting.UpdateState) then
			setting:UpdateState();
		end
	end
	
	for k, category in ipairs(self.categories) do
		for k2, setting in ipairs(category.settings) do
			if (setting.UpdateState) then
				setting:UpdateState();
			end
		end
	end
end

function WQT_SettingsFrameMixin:AddSetting(data, isFromList)
	if (not self.WQTLoaded) then
		tinsert(self.bufferedSettings, data);
		return;
	end

	local pool;
	-- Get the frame pool depending on the type of setting
	if (data.type == _V["SETTING_TYPES"].checkBox) then
		pool = self.checkBoxPool;
	elseif (data.type == _V["SETTING_TYPES"].subTitle) then
		pool = self.subTitlePool;
	elseif (data.type == _V["SETTING_TYPES"].slider) then
		pool = self.sliderPool;
	elseif (data.type == _V["SETTING_TYPES"].dropDown) then
		pool = self.dropDownPool;
	elseif (data.type == _V["SETTING_TYPES"].button) then
		pool = self.buttonPool;
	end

	-- Get a frame from the pool, initialize it, and link it to a category
	if (pool) then
		local frame = pool:Acquire();
		frame:Init(data);
		local list = self.categoryless;
		local category = self.categoriesLookup[data.categoryID];
		if (category) then
			list = category.settings;
		elseif (data.categoryID) then
			-- Category doesn't exist yet, create a temporary one
			category = self:CreateCategory(data.categoryID);
			list = category.settings;
		end
		tinsert(list, frame);
	end
	if (not isFromList) then
		self:Refresh();
	end
end

function WQT_SettingsFrameMixin:AddSettingList(list)
	for k, setting in ipairs(list) do
		self:AddSetting(setting, true);
	end
	self:Refresh();
end

function WQT_SettingsFrameMixin:PlaceSetting(setting)
	setting:ClearAllPoints();
	if (self.previous) then
		setting:SetPoint("TOPLEFT", self.previous, "BOTTOMLEFT");
	else
		setting:SetPoint("TOPLEFT", self.ScrollFrame.ScrollChild, 0, -SETTINGS_PADDING_TOP);
	end
	setting:SetPoint("RIGHT", self.ScrollFrame.ScrollChild);
	setting:Show();
	
	self.previous = setting;
	self.totalHeight = self.totalHeight + setting:GetHeight();
end

function WQT_SettingsFrameMixin:Refresh()
	self.totalHeight = SETTINGS_PADDING_TOP + SETTINGS_PADDING_BOTTOM;

	self.previous = nil;
	for i = 1, #self.categoryless do
		local current = self.categoryless[i];
		self:PlaceSetting(current);
	end
	
	for i = 1, #self.categories do
		local category = self.categories[i];
		if (#category.settings > 0) then
			self:PlaceSetting(category);
			
			for k, setting in ipairs(category.settings) do
				if (category.isExpanded) then
					self:PlaceSetting(setting);
				else
					setting:ClearAllPoints();
					setting:Hide();
				end
			end
		end
	end
	
	self.ScrollFrame:SetChildHeight(self.totalHeight);
end
