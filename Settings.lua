local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
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
	local tooltipText = not self:IsDisabled() and self.tooltip or self.disabledTooltip;
	if (tooltipText) then
		GameTooltip:SetOwner(anchorFrame or self, anchorType or "ANCHOR_RIGHT");
		if (self.label) then
			GameTooltip_SetTitle(GameTooltip, self.label);
		end
		GameTooltip_AddNormalLine(GameTooltip, tooltipText, true);
		if (self.suggestReload) then
			GameTooltip_AddHighlightLine(GameTooltip, _L["SUGGEST_RELOAD"], true);
		end
		GameTooltip:Show();
	end
end

function WQT_SettingsBaseMixin:OnLeave()
	GameTooltip:Hide();
end

function WQT_SettingsBaseMixin:Init(data)
	self.label = data.label;
	self.tooltip = data.tooltip;
	self.disabledTooltip = data.disabledTooltip;
	self.suggestReload = data.suggestReload;
	self.valueChangedFunc = data.valueChangedFunc;
	self.isDisabled = data.isDisabled;
	if (self.Label) then
		local labelText = data.label;
		if (data.isNew) then
			labelText = labelText .. " |TInterface\\OPTIONSFRAME\\UI-OptionsFrame-NewFeatureIcon:12|t";
		end
		self.Label:SetText(labelText);
	end
	
	if (self.DisabledOverlay) then
		self.DisabledOverlay:SetFrameLevel(self:GetFrameLevel() + 2)
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
	return false;
end

function WQT_SettingsBaseMixin:OnValueChanged(value, userInput, ...)
	if (userInput) then
		if (self.valueChangedFunc) then
			self.valueChangedFunc(value, ...);
		end
		self.parentFrame:UpdateList();
	end
end

function WQT_SettingsBaseMixin:UpdateState()
	self:SetDisabled(self:IsDisabled());
end

function WQT_SettingsBaseMixin:SetDisabled(value)
	if (self.Label and not self.staticLabelFont) then
		self.Label:SetFontObject(value and "GameFontDisable" or "GameFontNormal");
	end
	
	if (self.DisabledOverlay) then
		self.DisabledOverlay:SetShown(value);
	end
end

--------------------------------
-- WQT_SettingsQuestListMixin
--------------------------------

WQT_SettingsQuestListMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsQuestListMixin:OnLoad()
	self.Preview:SetEnabledMixin(false);
	self.Preview.UpdateTime = function(rewardFrame) 
		-- Time display
		-- 74160s == 20h 36m
		local timeString = "";
		if (WQT.settings.list.fullTime) then
			timeString = SecondsToTime(74160, true, false);
		else
			timeString = D_HOURS:format(74160 / SECONDS_PER_HOUR);
		end
		rewardFrame.Time:SetText(timeString);
		if (WQT.settings.list.colorTime) then
			local color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeMedium)
			rewardFrame.Time:SetVertexColor(color:GetRGB());
		else
			rewardFrame.Time:SetVertexColor(_V["WQT_WHITE_FONT_COLOR"]:GetRGB());
		end

		return true;
	 end;


	self.dummyQuestInfo = {};
	self.dummyQuestInfo.questID = 76586;
	self.dummyQuestInfo.factionID = 2600;
	self.dummyQuestInfo.mapID = 2214;
	self.dummyQuestInfo.title = "Worm Sign, Sealed, Delivered";
	self.dummyQuestInfo.hasWarbandBonus = true;
	self.dummyQuestInfo.isValid = true;
	self.dummyQuestInfo.passedFilter = true;
	self.dummyQuestInfo.classification = Enum.QuestClassification.WorldQuest;
	
	self.dummyQuestInfo.time = { ["seconds"] = 291863; };
	self.dummyQuestInfo.rewardList = {
		{
			["type"] = WQT_REWARDTYPE.equipment;
			["quality"] = 4;
			["texture"] = 5371389;
			["amount"] = 603;
		};
		{
			["type"] = WQT_REWARDTYPE.item;
			["quality"] = 3;
			["texture"] = 133016;
			["amount"] = 25;
		};
		{
			["type"] = WQT_REWARDTYPE.currency;
			["quality"] = 1;
			["texture"] = 5872053;
			["amount"] = 2;
			["id"] = 2902;
		};
		{
			["type"] = WQT_REWARDTYPE.gold;
			["quality"] = 1;
			["texture"] = 133784;
			["amount"] = 83400000;
		};
		{
			["type"] = WQT_REWARDTYPE.reputation;
			["quality"] = 3;
			["texture"] = 5891367;
			["amount"] = 150;
		};
	};
	self.dummyQuestInfo.tagInfo = {
		["quality"] = 0,
		["isElite"] = true,
		["worldQuestType"] = 2,
		["tagID"] = 111,
	};
	self.dummyQuestInfo.IsDisliked = function() return false; end
	self.dummyQuestInfo.IsExpired = function() return false; end
	self.dummyQuestInfo.IsCriteria = function() return false; end
	self.dummyQuestInfo.GetTagInfo = function() return self.dummyQuestInfo.tagInfo; end
	self.dummyQuestInfo.GetTagInfoQuality = function() return self.dummyQuestInfo.tagInfo.quality; end
	self.dummyQuestInfo.IterateRewards = function() return ipairs(self.dummyQuestInfo.rewardList) end
end

function WQT_SettingsQuestListMixin:UpdateState()
	if (not self.dummyQuestInfo) then return; end

	self.Preview:Update(self.dummyQuestInfo, true);
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

WQT_SettingsSliderMixin = CreateFromMixins(WQT_SettingsBaseMixin, CallbackRegistryMixin);

function WQT_SettingsSliderMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self.min = data.min or 0;
	self.max = data.max or 1;
	local steps = (self.max - self.min) / data.valueStep;
	self.SliderWithSteppers:Init(0, self.min, self.max, steps);
	-- Can't get the callback thing working. Don't know why. I'm over it
	self.SliderWithSteppers.Slider:HookScript("OnValueChanged", function(_, value) 
			self:OnValueChanged(value, true)
		end)

	self:UpdateState();
end

function WQT_SettingsSliderMixin:Reset()
	WQT_SettingsBaseMixin.Reset(self);
end

function WQT_SettingsSliderMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if (self.getValueFunc) then
		local currentValue = self.getValueFunc();
		self.SliderWithSteppers:SetValue(currentValue);
		self.TextBox:SetText(Round(currentValue*100)/100);
		self.current = currentValue;
	end
end

function WQT_SettingsSliderMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	self.SliderWithSteppers:SetEnabled(not value);
	self.TextBox:SetEnabled(not value);
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
-- WQT_SettingsColorMixin
--------------------------------

WQT_SettingsColorMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsColorMixin:OnLoad()
	-- New colorpicker no longer has a way to check when confirm is pressed
	ColorPickerFrame:HookScript("OnHide", function() 
		self.Label:Show();
		self.ExampleText:Hide();
		self.ExampleRing:Hide();
	end);
end

function WQT_SettingsColorMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self.defaultColor = data.defaultColor;
	self.colorID = data.colorID;

	CooldownFrame_SetDisplayAsPercentage(self.ExampleRing.Ring, 0.35);
	self.ExampleRing.Pointer:SetRotation(0.65*6.2831);
	self.ExampleRing.Ring:Show();
end

function WQT_SettingsColorMixin:UpdateState()
	if (self.getValueFunc) then
		local color = self.getValueFunc(self.colorID);
		self:SetWidgetRGB(color:GetRGB());

		-- Hex is more costly but doesn't have as meany issues 0.001 differences
		local canReset = color:GenerateHexColor() ~= self.defaultColor:GenerateHexColor();
		self:SetResetEnabled(canReset);
	end
end

function WQT_SettingsColorMixin:SetResetEnabled(enable)
	self.ResetButton:SetEnabled(enable);
	self.ResetButton.Icon:SetDesaturated(not enable);
	if (enable) then
		self.ResetButton.Icon:SetVertexColor(1, 1, 1);
	else
		self.ResetButton.Icon:SetVertexColor(.7, .7, .7);
	end
end

function WQT_SettingsColorMixin:ResetColor(userInput)
	local r, g, b = self.defaultColor:GetRGB();
	self:SetWidgetRGB(r, g, b);
	self:OnValueChanged(self.colorID, userInput, r, g, b);
end

function WQT_SettingsColorMixin:SetWidgetRGB(r, g, b)
	self.ExampleText:SetVertexColor(r, g, b);
	self.ExampleRing.Ring:SetSwipeColor(r, g, b);
	self.ExampleRing.RingBG:SetVertexColor(r, g, b);
	self.ExampleRing.Pointer:SetVertexColor(r*1.1, g*1.1, b*1.1);
	self.Picker.Color:SetVertexColor(r, g, b);
end

function WQT_SettingsColorMixin:UpdateFromPicker(isConfirmed)
	local r, g, b = ColorPickerFrame:GetColorRGB();
	self:SetWidgetRGB(r, g, b);
	self:OnValueChanged(self.colorID, true, r, g, b);
end

function WQT_SettingsColorMixin:StartPicking()
	if (not self.getValueFunc) then return; end
	
	self.parentFrame:UpdateList();
	
	local color = self.getValueFunc(self.colorID);
	local r, g, b = color:GetRGB();
	
	local colorInfo = {
		["swatchFunc"] = function () self:UpdateFromPicker() end,
		["opacityFunc"] = function () self:UpdateFromPicker(true) end,
		["cancelFunc"] = function () self:ResetColor(); self:StopPicking(); end,
		["r"] = r,
		["g"] = g,
		["b"] = b,
		["extraInfo"] = "test"
	}
	
	self.Label:Hide();
	self.ExampleText:Show();
	self.ExampleRing:Show();

	ColorPickerFrame:SetupColorPickerAndShow(colorInfo);
end

function WQT_SettingsColorMixin:StopPicking()
	self.Label:Show();
	self.ExampleText:Hide();
	self.ExampleRing:Hide();
	self:UpdateState();
end

--------------------------------
-- WQT_SettingsDropDownMixin
--------------------------------

WQT_SettingsDropDownMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsDropDownMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	self.Dropdown:SetEnabled(not value);
end

function WQT_SettingsDropDownMixin:DropdownSetup(dropdown, rootDescription)
	local tag = string.format("WQT_SETTINGS_DROPDOWN_%s", dropdown.data.label);
	rootDescription:SetTag(tag);

	local options = dropdown.data.options;
	if (type(options) ==  "function") then
		options = options();
	end

	for index, displayInfo in pairs(options) do
		local label = displayInfo.label or "Invalid label";
		local id = displayInfo.arg1;
		local radio = rootDescription:CreateRadio(
			label,
			function() return index == dropdown.data.getValueFunc() end,
			function() self:OnValueChanged(id, true); end,
			id);

		radio:SetOnEnter(function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
			GameTooltip_SetTitle(GameTooltip, label);
			GameTooltip_AddNormalLine(GameTooltip, displayInfo.tooltip);
			GameTooltip:Show();
		end);
	
		radio:SetOnLeave(function(button)
			GameTooltip:Hide();
		end);
	end
end

function WQT_SettingsDropDownMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);

	self.Dropdown.data = data;
	self.Dropdown:SetupMenu(function(dropdown, rootDescription) self:DropdownSetup(dropdown, rootDescription) end);
	
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
-- WQT_SettingsConfirmButtonMixin
--------------------------------

WQT_SettingsConfirmButtonMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsConfirmButtonMixin:OnLoad()
	self.Label = self.Button.Label;
end

function WQT_SettingsConfirmButtonMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.Button:Disable();
	else
		self.Button:Enable();
	end
end

function WQT_SettingsConfirmButtonMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
end

function WQT_SettingsConfirmButtonMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	local width = (self:GetWidth() - 67) / 2;
	self.ButtonConfirm:SetWidth(width);
	
	if (self.isPicking == true) then
		self.Button:Show();
		self.ButtonConfirm:Hide();
		self.ButtonDecline:Hide();
		self.isPicking = false;
	end
end

function WQT_SettingsConfirmButtonMixin:OnValueChanged(value, userInput)
	self:SetPickingState(false);
	WQT_SettingsBaseMixin.OnValueChanged(self, value, userInput);
end

function WQT_SettingsConfirmButtonMixin:SetPickingState(isPicking)
	self.isPicking = isPicking;
	if (self.isPicking) then
		self.Button:Hide();
		self.ButtonConfirm:Show();
		self.ButtonDecline:Show();
		return;
	end
	
	self.Button:Show();
	self.ButtonConfirm:Hide();
	self.ButtonDecline:Hide();
end

--------------------------------
-- WQT_SettingsTextInputMixin
--------------------------------

WQT_SettingsTextInputMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsTextInputMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self:UpdateState();
end

function WQT_SettingsTextInputMixin:Reset()
	WQT_SettingsBaseMixin.Reset(self);
end

function WQT_SettingsTextInputMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if (self.getValueFunc) then
		local currentValue = self.getValueFunc() or "";
		self.TextBox:SetText(currentValue);
		self.current = currentValue;
	end
end

function WQT_SettingsTextInputMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	if (value) then
		self.TextBox:Disable();
	else
		self.TextBox:Enable();
	end
end

function WQT_SettingsTextInputMixin:OnValueChanged(value, userInput)
	if (not value or value == "") then 
		-- Reset displayed values
		self:UpdateState();
		return; 
	end

	if (userInput and value ~= self.current) then
		WQT_SettingsBaseMixin.OnValueChanged(self, value, userInput);
	end
	self:UpdateState();
end

--------------------------------
-- WQT_SettingsCategoryMixin
--------------------------------

WQT_SettingsCategoryMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsCategoryMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.id = data.id;
	self.isExpanded = data.expanded;
	self.settings = {};
	self.subCategories = {};
end

function WQT_SettingsCategoryMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if(self.ExpandIcon) then
		self.ExpandIcon:SetAtlas(self.isExpanded and "UI-QuestTrackerButton-Secondary-Collapse" or "UI-QuestTrackerButton-Secondary-Expand", true);
	elseif(self.BGRight) then
		self.BGRight:SetAtlas(self.isExpanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true);
	end
end

function WQT_SettingsCategoryMixin:SetExpanded(value)
	self.isExpanded = value;
	self.parentFrame:Refresh();
end

--------------------------------
-- WQT_SettingsFrameMixin
--------------------------------

WQT_SettingsFrameMixin = {};

function WQT_SettingsFrameMixin:OnLoad()
	-- Because we can't destroy frames, keep a pool of each type to re-use
	self.categoryPool = CreateFramePool("BUTTON", self.ScrollBox.ScrollContent, "WQT_SettingCategoryTemplate");
	self.subCategoryPool = CreateFramePool("BUTTON", self.ScrollBox.ScrollContent, "WQT_SettingSubCategoryTemplate");
	
	self.templatePools = {};
	
	self.categoryless = {};
	self.categories = {};
	self.categoriesLookup = {};
	
	self.bufferedSettings = {};
	self.bufferedCategories = {};

	self.TitleText:SetText(SETTINGS);

	ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, CreateScrollBoxLinearView());
end

function WQT_SettingsFrameMixin:Init(categories, settings)
	-- Initialize 'official' settings
	self.isInitialized = true;
	self:RegisterCategories(categories);

	if (settings) then
		self:AddSettingList(settings);
	end

	-- Add buffered settings from other add-ons
	self:RegisterCategories(self.bufferedCategories);
	self:AddSettingList(self.bufferedSettings);
end

function WQT_SettingsFrameMixin:SetCategoryExpanded(id, value)
	local category = self.categoriesLookup[id];
	
	if (category) then
		category:SetExpanded(value);
	end
end

function WQT_SettingsFrameMixin:RegisterCategories(categories)
	if (categories) then
		for k, data in ipairs(categories) do
			self:RegisterCategory(data);
		end
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
	if (not self.isInitialized) then
		tinsert(self.bufferedCategories, data);
		return;
	end

	if (type(data) ~= "table") then
		local temp = {["id"] = data};
		data = temp;
	end
	
	local isSubCategory = data.parentCategory ~= nil;
	
	local category;
	if (isSubCategory) then
		local parent = self.categoriesLookup[data.parentCategory];
		if (not parent) then return; end
		category = self.subCategoryPool:Acquire();
		tinsert(parent.subCategories, category);
	else
		category = self.categoryPool:Acquire();
	end
	
	category:Init(data);
	category.Title:SetText(data.label or data.id)
	category.parentFrame = self;
	
	if (not isSubCategory) then
		tinsert(self.categories, category);
	end
	self.categoriesLookup[data.id] = category;
	return category;
end

function WQT_SettingsFrameMixin:UpdateCategory(category)
	if (category.isExpanded) then
		for k2, setting in ipairs(category.settings) do
			if (setting.UpdateState) then
				setting:UpdateState();
			end
		end
		
		for k2, subCategory in ipairs(category.subCategories) do
			self:UpdateCategory(subCategory);
		end
	end
end

function WQT_SettingsFrameMixin:UpdateList()
	for k, setting in ipairs(self.categoryless) do
		if (setting.UpdateState) then
			setting:UpdateState();
		end
	end
	
	for k, category in ipairs(self.categories) do
		self:UpdateCategory(category);
	end
end

function WQT_SettingsFrameMixin:AcquireFrameOfTemplate(template)
	if not (template) then return; end
	local pool = self.templatePools[template];
	if (not pool and DoesTemplateExist(template)) then
		pool = CreateFramePool("FRAME", self.ScrollBox.ScrollContent, template, function(pool, frame) frame:Reset(); end);
		self.templatePools[template] = pool;
	end
	
	if (pool) then
		return pool:Acquire();
	end
end

function WQT_SettingsFrameMixin:GetTemplateFromType(settingType)
	if (settingType == _V["SETTING_TYPES"].checkBox) then
		return "WQT_SettingCheckboxTemplate";
	elseif (settingType == _V["SETTING_TYPES"].subTitle) then
		return "WQT_SettingSubTitleTemplate";
	elseif (settingType == _V["SETTING_TYPES"].slider) then
		return "WQT_SettingSliderTemplate";
	elseif (settingType == _V["SETTING_TYPES"].dropDown) then
		return "WQT_SettingDropDownTemplate";
	elseif (settingType == _V["SETTING_TYPES"].button) then
		return "WQT_SettingButtonTemplate";
	end
end

function WQT_SettingsFrameMixin:AddSetting(data, isFromList)
	if (not self.isInitialized) then
		tinsert(self.bufferedSettings, data);
		return;
	end

	-- Support outdated usage of types
	local template = data.template;
	if (data.type) then
		template = self:GetTemplateFromType(data.type);
	end

	-- Get a frame of supplied template, or specific frame from _G
	local frame;
	if (template) then
		frame = self:AcquireFrameOfTemplate(template);
	elseif (data.frameName) then
		frame = _G[data.frameName];
		frame:SetParent(self.ScrollBox.ScrollContent);
	end

	-- Get a frame from the pool, initialize it, and link it to a category
	if (frame) then
		frame.parentFrame = self;
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
		setting:SetPoint("TOPLEFT", self.ScrollBox.ScrollContent, 0, -SETTINGS_PADDING_TOP);
	end
	setting:SetPoint("RIGHT", self.ScrollBox.ScrollContent);
	setting:Show();
	if (setting.UpdateState) then
		setting:UpdateState();
	end
	
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
	
	self:PlaceCategories(self.categories);
	
	self.ScrollBox.ScrollContent:SetHeight(self.totalHeight);
	self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately);
end

function WQT_SettingsFrameMixin:CategoryTreeHasSettings(category)
	if (#category.settings > 0) then
		return true;
	end
	
	for k, subCategory in ipairs(category.subCategories) do
		if (self:CategoryTreeHasSettings(subCategory)) then
			return true;
		end
	end
	
	return false;
end

function WQT_SettingsFrameMixin:PlaceCategories(categories)
	
	for i = 1, #categories do
		local category = categories[i];
		if (self:CategoryTreeHasSettings(category)) then
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
		
		if (category.isExpanded) then
			self:PlaceCategories(category.subCategories);
		else
			for k, subCategory in ipairs(category.subCategories) do
				self:HideCategory(subCategory);
			end
		end
	end
end

function WQT_SettingsFrameMixin:HideCategory(category)
	for k, setting in ipairs(category.settings) do
		setting:ClearAllPoints();
		setting:Hide();
	end
	for k, subCategory in ipairs(category.subCategories) do
		self:HideCategory(subCategory);
	end
	category:ClearAllPoints();
	category:Hide();
end
