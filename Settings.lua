local addonName, addon = ...
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
	self.func = data.func;
	self.isDisabled = data.isDisabled;
	if (self.Label) then
		self.Label:SetText(data.label);
	end
end

function WQT_SettingsBaseMixin:Reset()
	self.label = nil;
	self.tooltip = nil;
	self.func = nil;
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
	if (userInput and self.func) then
		self.func(value);
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
-- WQT_ScrollFrameMixin
--------------------------------

WQT_ScrollFrameMixin = {};

function WQT_ScrollFrameMixin:OnLoad()
	self.offset = 0;
	self.scrollStep = 30;
	self.max = 0;
end

function WQT_ScrollFrameMixin:UpdateChildFramePosition()
	if (self.scrollChild) then
		self.scrollChild:SetPoint("TOPLEFT", self, 0, self.offset);
	end
end

function WQT_ScrollFrameMixin:OnMouseWheel(delta)
	self.offset = self.offset - delta * self.scrollStep;
	self.offset = max(0, min(self.offset, self.max));
	self:UpdateChildFramePosition();
end

function WQT_ScrollFrameMixin:SetChildHeight(height)
	self.scrollChild:SetHeight(height);
	self.max = max(0, height - self:GetHeight());
	self.offset = min(self.offset, self.max);
end




--------------------------------
-- WQT_SettingsFrameMixin
--------------------------------

WQT_SettingsFrameMixin = {};

function WQT_SettingsFrameMixin:OnLoad()
	-- Because we can't destroy frames, keep a pool of each type to re-use
	self.categoryPool = CreateFramePool("BUTTON", self.ScrollFrame.scrollChild, "WQT_SettingCategoryTemplate");
	self.checkBoxPool = CreateFramePool("FRAME", self.ScrollFrame.scrollChild, "WQT_SettingCheckboxTemplate", function(pool, frame) frame:Reset(); end);
	self.subTitlePool = CreateFramePool("FRAME", self.ScrollFrame.scrollChild, "WQT_SettingSubTitleTemplate", function(pool, frame) frame:Reset(); end);
	self.sliderPool = CreateFramePool("FRAME", self.ScrollFrame.scrollChild, "WQT_SettingSliderTemplate", function(pool, frame) frame:Reset(); end);
	self.dropDownPool = CreateFramePool("FRAME", self.ScrollFrame.scrollChild, "WQT_SettingDropDownTemplate", function(pool, frame) frame:Reset(); end);
	
	self.ScrollFrame.buttonHeight = 40;
	self.ScrollFrame.scrollChild:SetWidth(self.ScrollFrame:GetWidth());
	self.ScrollFrame.scrollChild:SetPoint("RIGHT", self.ScrollFrame)
	self.ScrollFrame.scrollBar:SetValueStep(40);
	
	self.categoryless = {};
	self.categories = {};
	self.categoriesLookup = {};
end

function WQT_SettingsFrameMixin:RegisterCategory(id, label)
	if (self.categoriesLookup[id]) then
		print("A setting with id", id, "already exists");
		return;
	end
	
	local category =  self:CreateCategory(id, label)
	tinsert(self.categories, category);
	self.categoriesLookup[id] = category;
end

function WQT_SettingsFrameMixin:CreateCategory(id, title)
	local category = self.categoryPool:Acquire();
	category.Title:SetText(title)
	category.id = id;
	category.isExpanded = true;
	category.settings = {};
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

function WQT_SettingsFrameMixin:AddSetting(data)
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
	end

	-- Get a frame from the pool, initialize it, and link it to a category
	if (pool) then
		local frame = pool:Acquire();
		frame:Init(data);
		local category = self.categoriesLookup[data.categoryID];
		local list = category and category.settings or self.categoryless;
		tinsert(list, frame);
	end
end

function WQT_SettingsFrameMixin:AddSettingList(list)
	for k, setting in ipairs(list) do
		self:AddSetting(setting);
	end
	self:PlaceAllSettings();
end

function WQT_SettingsFrameMixin:PlaceSetting(setting)
	setting:ClearAllPoints();
	if (self.previous) then
		setting:SetPoint("TOPLEFT", self.previous, "BOTTOMLEFT");
	else
		setting:SetPoint("TOPLEFT", self.ScrollFrame.scrollChild, 0, -SETTINGS_PADDING_TOP);
	end
	setting:SetPoint("RIGHT", self.ScrollFrame.scrollChild);
	setting:Show();
	
	self.previous = setting;
	self.totalHeight = self.totalHeight + setting:GetHeight();
end

function WQT_SettingsFrameMixin:PlaceAllSettings()
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
