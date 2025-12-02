local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Profiles = addon.WQT_Profiles;

local SETTING_SPACING = 2;
local SETTINGS_PADDING_TOP = 5;
local SETTINGS_PADDING_BOTTOM = 15;

--------------------------------
-- WQT_SettingsBaseMixin
--------------------------------

WQT_SettingsBaseMixin = {};

function WQT_SettingsBaseMixin:OnLoad()
	self.tooltipOffsetY = -self:GetHeight();


	local baseLevel = self:GetFrameLevel();
	if (self.DisabledOverlay) then
		self.DisabledOverlay.parent = self
		self.DisabledOverlay:SetFrameLevel(baseLevel + 4);
	end

	if (self.NewFeature) then
		self.NewFeature:SetFrameLevel(baseLevel + 5);
	end

	local topInset = Round(SETTING_SPACING / 2);
	self:SetHitRectInsets(0, 0, -topInset, topInset - SETTING_SPACING);
end

function WQT_SettingsBaseMixin:AnchorTooltip(anchorFrame, anchorType)
	local offsetX = self.tooltipOffsetX or 0;
	local offsetY = self.tooltipOffsetY or 0;
	GameTooltip:SetOwner(anchorFrame or self, anchorType or "ANCHOR_RIGHT", offsetX, offsetY);
end

function WQT_SettingsBaseMixin:OnEnter(anchorFrame, anchorType)
	local tooltipText = self.tooltip;
	if (tooltipText) then
		self:AnchorTooltip(anchorFrame, anchorType);
		if (self.label) then
			GameTooltip_SetTitle(GameTooltip, self.label);
		end
		GameTooltip_AddNormalLine(GameTooltip, tooltipText, true);
		if (self.suggestReload) then
			GameTooltip_AddHighlightLine(GameTooltip, _L["SUGGEST_RELOAD"], true);
		end
		GameTooltip:Show();
	end

	if (self.BgHighlight) then
		self.BgHighlight:Show();
	end
end

function WQT_SettingsBaseMixin:OnLeave()
	GameTooltip:Hide();

	if (self.BgHighlight) then
		self.BgHighlight:Hide();
	end
end

function WQT_SettingsBaseMixin:Init(data)
	self.label = data.label;
	self.tooltip = data.tooltip;
	self.disabledTooltip = data.disabledTooltip;
	self.suggestReload = data.suggestReload;
	self.valueChangedFunc = data.valueChangedFunc;
	self.isDisabled = data.isDisabled;
	self.categoryID = data.categoryID;
	self.tag = data.tag;

	if (self.Label) then
		self.Label:SetText(data.label);
	end
	
	if (self.NewFeature) then
		self.NewFeature:SetShown(data.isNew);
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

		WQT_CallbackRegistry:TriggerEvent("WQT.SettingChanged", self.categoryID, self.tag);
	end
end

function WQT_SettingsBaseMixin:UpdateState()
	local isDisabled = self:IsDisabled();
	self:SetDisabled(isDisabled);

	if (self.BgHighlight) then
		self.BgHighlight:SetDesaturated(isDisabled);
	end
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

function WQT_SettingsQuestListMixin:Init(data)
	self:UpdateState();
end

function WQT_SettingsQuestListMixin:OnLoad()
	self.Preview:SetEnabledMixin(false);

	-- 74160s == 20h 36m
	local SETTINGS_QUEST_TIME = 74160;

	self.Preview.UpdateTime = function(rewardFrame) 
		local timeFrame = rewardFrame:GetTimeFontString();

		local timeString = "";
		if (WQT.settings.list.fullTime) then
			timeString = SecondsToTime(SETTINGS_QUEST_TIME, true, false);
		else
			timeString = D_HOURS:format(SETTINGS_QUEST_TIME / SECONDS_PER_HOUR);
		end
		timeFrame:SetText(timeString);
		if (WQT.settings.list.colorTime) then
			local color = WQT_Utils:GetColor(_V["COLOR_IDS"].timeMedium)
			timeFrame:SetVertexColor(color:GetRGB());
		else
			timeFrame:SetVertexColor(_V["WQT_WHITE_FONT_COLOR"]:GetRGB());
		end

		return true;
	 end;

	self.Preview.Update = function(frame, questInfo, shouldShowZone)
		WQT_ListButtonMixin.Update(frame, questInfo, shouldShowZone);
		frame.TrackedBorder:Hide();
		frame.Highlight:Hide();
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
	self.dummyQuestInfo.GetReward = function(dummy, index)
		if (index < 1 or index > #dummy.rewardList) then
			return nil;
		end
		return dummy.rewardList[index];
	end
end

function WQT_SettingsQuestListMixin:UpdateState()
	if (not self.dummyQuestInfo) then return; end

	self.Preview:Update(self.dummyQuestInfo, true);
end

--------------------------------
-- WQT_SettingsCheckboxMixin
--------------------------------

WQT_SettingsCheckboxMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsCheckboxMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);
	self.CheckBox.parent = self;
	self.DisabledOverlay.parent = self;
end

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

function WQT_SettingsSliderMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);

	self.TextBox.parent = self;

	local enterFunc = function(...) self:OnEnter(self); end;
	local leaveFunc = function(...) self:OnLeave(); end;

	self.SliderWithSteppers.Slider:HookScript("OnEnter", enterFunc);
	self.SliderWithSteppers.Slider:HookScript("OnLeave", leaveFunc);
	self.SliderWithSteppers.Back:HookScript("OnEnter", enterFunc);
	self.SliderWithSteppers.Back:HookScript("OnLeave", leaveFunc);
	self.SliderWithSteppers.Forward:HookScript("OnEnter", enterFunc);
	self.SliderWithSteppers.Forward:HookScript("OnLeave", leaveFunc);
	self.SliderWithSteppers:HookScript("OnEnter", enterFunc);
	self.SliderWithSteppers:HookScript("OnLeave", leaveFunc);

	self.SliderWithSteppers:RegisterCallback("OnValueChanged",
		function(_, value, ...)
			self:OnValueChanged(value, true);
		end, self);
end

function WQT_SettingsSliderMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.userInteracting = false;

	self.getValueFunc = data.getValueFunc;
	self.min = data.min or 0;
	self.max = data.max or 1;
	local steps = (self.max - self.min) / data.valueStep;
	local currentValue = self:GetValue();
	self.current = currentValue;
	self.SliderWithSteppers:Init(currentValue, self.min, self.max, steps);

	self:UpdateState();
end

function WQT_SettingsSliderMixin:GetValue()
	if(type(self.getValueFunc) =="function") then
		return self.getValueFunc();
	end
	return self.min or 0;
end

function WQT_SettingsSliderMixin:Reset()
	WQT_SettingsBaseMixin.Reset(self);
end

function WQT_SettingsSliderMixin:UpdateState()
	WQT_SettingsBaseMixin.UpdateState(self);
	if (self.getValueFunc) then
		local currentValue = self.getValueFunc();
		self.SliderWithSteppers:SetValue(currentValue);
		self.current = currentValue;
		self:UpdateTextBoxText();
	end
end

function WQT_SettingsSliderMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	self.SliderWithSteppers:SetEnabled(not value);
	self.TextBox:SetEnabled(not value);
	self:UpdateTextBoxText();
end

function WQT_SettingsSliderMixin:UpdateTextBoxText()
	local currentValue = self:GetValue();
	local text = RoundToSignificantDigits(currentValue, 2);
	if (not self.TextBox:IsEnabled()) then
		text = GRAY_FONT_COLOR:WrapTextInColorCode(text);
	end
	self.TextBox:SetText(text);
end

function WQT_SettingsSliderMixin:OnValueChanged(value, userInput)
	-- Prevent non-number input
	value = tonumber(value);
	if (not value) then 
		-- Reset displayed values
		self:UpdateState();
		return;
	end

	value = RoundToSignificantDigits(value, 2);
	value = Clamp(value, self.min, self.max);
	if (userInput and value ~= self.current) then
		WQT_SettingsBaseMixin.OnValueChanged(self, value, userInput);
	end
end

--------------------------------
-- WQT_SettingsColorMixin
--------------------------------

WQT_SettingsColorMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsColorMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);

	self.Picker.parent = self;

	ColorPickerFrame:HookScript("OnHide", function()
		self:StopPicking();
	end);

	CooldownFrame_SetDisplayAsPercentage(self.ExampleRing.Ring, 0.35);
	self.ExampleRing.Pointer:SetRotation(0.65*6.2831);
	self.ExampleRing.Ring:Show();
end

function WQT_SettingsColorMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);
	self.getValueFunc = data.getValueFunc;
	self.defaultColor = data.defaultColor;
	self.colorID = data.colorID;

	self:UpdateState();
end

function WQT_SettingsColorMixin:UpdateState()
	if (self.getValueFunc) then
		local color = self.getValueFunc(self.colorID);
		self:SetWidgetRGB(color:GetRGB());

		-- Comparing hex because of floating point inaccuracies
		local canReset = color:GenerateHexColor() ~= self.defaultColor:GenerateHexColor();
		self:SetResetEnabled(canReset);
	end

	self:Layout();
end

function WQT_SettingsColorMixin:SetResetEnabled(enable)
	self.ResetButton:SetShown(enable);
	self:Layout();
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

function WQT_SettingsColorMixin:UpdateFromPicker()
	local r, g, b = ColorPickerFrame:GetColorRGB();
	self:SetWidgetRGB(r, g, b);
	self:OnValueChanged(self.colorID, true, r, g, b);
end

function WQT_SettingsColorMixin:StartPicking()
	if (not self.getValueFunc) then return; end
	
	local color = self.getValueFunc(self.colorID);
	local r, g, b = color:GetRGB();
	
	local colorInfo = {
		["swatchFunc"] = function () self:UpdateFromPicker() end,
		["cancelFunc"] = function () self:ResetColor(true); self:StopPicking(); end,
		["r"] = r,
		["g"] = g,
		["b"] = b,
		["extraInfo"] = "test"
	}
	
	self.Label:Hide();
	self.ExampleText:Show();
	self.ExampleRing:Show();
	self:Layout();

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

function WQT_SettingsDropDownMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);

	self.Dropdown.parent = self;
end

function WQT_SettingsDropDownMixin:Init(data)
	WQT_SettingsBaseMixin.Init(self, data);

	self.Dropdown.data = data;
	self.Dropdown:SetupMenu(function(dropdown, rootDescription) self:DropdownSetup(dropdown, rootDescription) end);
	
	self:UpdateState();
end

function WQT_SettingsDropDownMixin:SetDisabled(value)
	WQT_SettingsBaseMixin.SetDisabled(self, value);
	self.Dropdown:SetEnabled(not value);
end

function WQT_SettingsDropDownMixin:DropdownSetup(dropdown, rootDescription)
	local tag = string.format("WQT_SETTINGS_DROPDOWN_%s", dropdown.data.tag);
	rootDescription:SetTag(tag);

	local options = dropdown.data.options;
	if (type(options) == "function") then
		options = options();
	end

	local function IsSelectedFunc(id) return id == dropdown.data.getValueFunc() end
	local function OnValueSetFunc(id) self:OnValueChanged(id, true); end
	local function OnTooltipFunc(tooltip, radio)
		GameTooltip_SetTitle(tooltip, radio.displayInfo.label);
		GameTooltip_AddNormalLine(tooltip, radio.displayInfo.tooltip);
	end

	for _, displayInfo in ipairs(options) do
		local label = displayInfo.label or "Invalid label";
		local id = displayInfo.id;
		local radio = rootDescription:CreateRadio(label, IsSelectedFunc, OnValueSetFunc, id);
		radio.displayInfo = displayInfo;
		radio:SetTooltip(OnTooltipFunc);
	end
end

function WQT_SettingsDropDownMixin:OnEnter(anchorFrame, anchorType)
	WQT_SettingsBaseMixin.OnEnter(self, anchorFrame, anchorType);

	local options = self.Dropdown.data.options;
	if (type(options) ==  "function") then
		options = options();
	end

	if (options) then
		for k, option in ipairs(options) do
			if (option.label and option.tooltip) then
				local text = WHITE_FONT_COLOR:WrapTextInColorCode(option.label .. ": ") .. option.tooltip;
				GameTooltip_AddBlankLineToTooltip(GameTooltip);
				GameTooltip_AddNormalLine(GameTooltip, text, true);
			end
		end
		GameTooltip:Show();
	end
end

--------------------------------
-- WQT_SettingsButtonMixin
--------------------------------
WQT_SettingFunctionalButtonMixin = {};

function WQT_SettingFunctionalButtonMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);
	if (not self.label) then return; end
	self.Label:SetText(self.label);
end

function WQT_SettingFunctionalButtonMixin:OnEnter()
	if (not self.parent) then return; end
	self.parent:OnEnter(self.parent);
end

function WQT_SettingFunctionalButtonMixin:OnLeave()
	if (not self.parent) then return; end
	self.parent:OnLeave();
end

function WQT_SettingFunctionalButtonMixin:OnMouseDown()
	self.Label:AdjustPointsOffset(1, -1);
end

function WQT_SettingFunctionalButtonMixin:OnMouseUp()
	self.Label:AdjustPointsOffset(-1, 1);
end


WQT_SettingsButtonMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsButtonMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);
	self.Label = self.Button.Label;
	self.Button.parent = self;
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
	WQT_SettingsBaseMixin.OnLoad(self);
	self.Label = self.Button.Label;

	self.Button.parent = self;
	self.ButtonConfirm.parent = self;
	self.ButtonDecline.parent = self;

	WQT_CallbackRegistry:RegisterCallback("WQT.Settings.CategoryToggled",
		function()
			self:SetPickingState(false);
		end, self);

	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function()
			self:SetPickingState(false);
		end, self);

	self:Layout();
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
	self:SetPickingState(false);
end

function WQT_SettingsConfirmButtonMixin:OnValueChanged(value, userInput)
	self:SetPickingState(false);
	WQT_SettingsBaseMixin.OnValueChanged(self, value, userInput);
end

function WQT_SettingsConfirmButtonMixin:SetPickingState(isPicking)
	self.isPicking = isPicking;

	self.Button:SetShown(not self.isPicking);
	self.ButtonConfirm:SetShown(self.isPicking);
	self.ButtonDecline:SetShown(self.isPicking);
	self:Layout();
end

--------------------------------
-- WQT_SettingsTextInputMixin
--------------------------------

WQT_SettingsTextInputMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsTextInputMixin:OnLoad()
	WQT_SettingsBaseMixin.OnLoad(self);

	self.TextBox.parent = self;
end

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
-- WQT_SettingsTextMixin
--------------------------------

WQT_SettingsTextMixin = CreateFromMixins(WQT_SettingsBaseMixin);

function WQT_SettingsTextMixin:Init(data)
	-- Force absurd height to make sure we get the correct GetStringHeight after SetText
	self.Label:SetHeight(200);
	WQT_SettingsBaseMixin.Init(self, data);
	self.Label:SetFontObject(data.font or "GameFontHighlight");
	local color = data.color or NORMAL_FONT_COLOR;
	self.Label:SetTextColor(color:GetRGB());

	self.finalTopPadding = data.topPadding or self.topPadding;
	self.finalBottomPadding = data.bottomPadding or self.bottomPadding;
	self.finalLeftPadding = self.baseLeftPadding + (data.leftPadding or 0);

	local topPadding = self.finalTopPadding or 0;
	local bottomPadding = self.finalBottomPadding or 0;
	self.Label:SetPoint("TOPLEFT", self, self.finalLeftPadding, -topPadding);
	local stringHeight = self.Label:GetStringHeight();
	self:SetHeight(stringHeight + topPadding + bottomPadding);
	self.Label:SetHeight(stringHeight);
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

	self:UpdateState();
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
	WQT_CallbackRegistry:TriggerEvent("WQT.Settings.CategoryToggled", self.categoryID, self.isExpanded);
end



--------------------------------
-- Data Mixins
--------------------------------

--------------------------------
-- WQT_SettingElementDataMixin
--------------------------------

WQT_SettingElementDataMixin = {};

function WQT_SettingElementDataMixin:Init(template, label, tooltip, categoryID, tag)
	self.elementData = {};
	self.elementData.template = template;
	self.elementData.data = {
		label = label;
		tooltip = tooltip;
		categoryID = categoryID;
		tag = tag;
	}
end

function WQT_SettingElementDataMixin:AddToDataprovider(dataprovider)
	if (self.elementData.data.isVisibleFunc and not self.elementData.data:isVisibleFunc()) then return; end
	dataprovider:Insert(self.elementData);
end

function WQT_SettingElementDataMixin:SetValueToKey(key, value)
	self.elementData.data[key] = value;
end

function WQT_SettingElementDataMixin:SetValueChangedFunction(func)
	if (type(func) ~= "function") then error("'func' must be a function value"); end;
	self.elementData.data.valueChangedFunc = func;
end

function WQT_SettingElementDataMixin:SetGetValueFunction(func)
	if (type(func) ~= "function") then error("'func' must be a function value"); end;
	self.elementData.data.getValueFunc = func;
end

function WQT_SettingElementDataMixin:SetIsDisabledFunction(func)
	if (type(func) ~= "function") then error("'func' must be a function value"); end;
	self.elementData.data.isDisabled = func;
end

function WQT_SettingElementDataMixin:SetIsVisibleFunction(func)
	if (type(func) ~= "function") then error("'func' must be a function value"); end;
	
	self.elementData.data.isVisibleFunc = func;
end

function WQT_SettingElementDataMixin:MarkAsNew()
	self.elementData.data.isNew = true;
end

function WQT_SettingElementDataMixin:MarkAsSuggestReload()
	self.elementData.data.suggestReload = true;
end

--------------------------------
-- WQT_SettingsCategoryDataMixin
--------------------------------

WQT_SettingsCategoryDataMixin = {};

function WQT_SettingsCategoryDataMixin:Init(categoryID, label, initialExpanded, isSubCategory)
	self.categoryID = categoryID;
	self.elementData = {
		template = isSubCategory and "WQT_SettingSubCategoryTemplate" or "WQT_SettingCategoryTemplate",
		data = {
			label = label;
			id = categoryID;
			tag = categoryID;
			categoryID = categoryID;
			expanded = initialExpanded;
		}
	}

	self.children = {};
	self.subCategories = {};
end

function WQT_SettingsCategoryDataMixin:AddToDataprovider(dataprovider)
	dataprovider:Insert(self.elementData);

	if (self.elementData.data.expanded) then
		for k, child in ipairs(self.children) do
			child:AddToDataprovider(dataprovider);
		end
		for k, child in ipairs(self.subCategories) do
			child:AddToDataprovider(dataprovider);
		end
	end
end

function WQT_SettingsCategoryDataMixin:AddSubCategory(categoryID, label, expanded)
	if (type(categoryID) ~= "string") then error("'categoryID' must be a string value"); return; end
	local category = CreateAndInitFromMixin(WQT_SettingsCategoryDataMixin, categoryID, label, expanded, true);


	table.insert(self.subCategories, category);
	return category;
end

function WQT_SettingsCategoryDataMixin:AddCheckbox(tag, label, tooltip)
	if (type(tag) ~= "string") then error("'tag' must be a string value"); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingCheckboxTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddSlider(tag, label, tooltip, min, max, step)
	if (type(tag) ~= "string") then error("'tag' must be a string value"); return; end
	if (type(min) ~= "number") then error("'min' must be a number value"); return; end
	if (type(max) ~= "number") then error("'max' must be a number value"); return; end
	if (type(step) ~= "number") then error("'step' must be a number value"); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingSliderTemplate", label, tooltip, self.categoryID, tag);
	settingMixin:SetValueToKey("min", min);
	settingMixin:SetValueToKey("max", max);
	settingMixin:SetValueToKey("valueStep", step);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddDropdown(tag, label, tooltip, options)
	if (type(tag) ~= "string") then error("'tag' must be a string value"); return; end
	if (type(options) ~= "table" and type(options) ~= "function") then error("'options' must be either a table or function value"); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingDropDownTemplate", label, tooltip, self.categoryID, tag);
	settingMixin:SetValueToKey("options", options);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:CreateText(tag, label, font, color, bottomPadding)
	if (type(tag) ~= "string") then error("'tag' must be a string value"); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingTextTemplate", label, nil, self.categoryID, tag);
	settingMixin:SetValueToKey("font", font or "GameFontHighlight");
	settingMixin:SetValueToKey("color", color or NORMAL_FONT_COLOR);
	settingMixin:SetValueToKey("bottomPadding", bottomPadding);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

local function UpdateColorID(id, r, g, b)
	local color = WQT_Utils:UpdateColor(_V["COLOR_IDS"][id], r, g, b);
	if (color) then
		WQT.settings.colors[id] = color:GenerateHexColor();
		WQT_ListContainer:DisplayQuestList();
		WQT_WorldQuestFrame.pinDataProvider:RefreshAllData();
	end
end

local function GetColorByID(id)
	return WQT_Utils:GetColor(_V["COLOR_IDS"][id]);
end

function WQT_SettingsCategoryDataMixin:AddColorPicker(tag, label, tooltip, colorID, defaultColor)
	if (type(tag) ~= "string") then error("'tag' must be a string value"); return; end
	if (type(colorID) ~= "string") then error("'colorID' must be a string value"); return; end
	if (type(defaultColor) ~= "table" or not defaultColor.GetRGB) then error("'defaultColor' must be a ColorMixin value"); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingColorTemplate", label, tooltip, self.categoryID, tag);
	settingMixin:SetValueToKey("colorID", colorID);
	settingMixin:SetValueToKey("defaultColor", defaultColor);
	settingMixin:SetValueChangedFunction(UpdateColorID);
	settingMixin:SetGetValueFunction(GetColorByID);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddTextInput(tag, label, tooltip)
	if (type(tag) ~= "string") then error("AddTextInput has invalid tag", tag); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingTextInputTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddButton(tag, label, tooltip)
	if (type(tag) ~= "string") then error("AddButton has invalid tag", tag); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingButtonTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddConfirmButton(tag, label, tooltip)
	if (type(tag) ~= "string") then error("AddConfirmButton has invalid tag", tag); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingConfirmButtonTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddCustomTemplate(template, tag)
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, template, nil, nil, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:GetCategoryByID(categoryID)
	local foundCategory = nil;
	for k, child in ipairs(self.subCategories) do
		if (child.categoryID == categoryID) then
			foundCategory = child;
			break;
		end
	end

	return foundCategory;
end

function WQT_SettingsCategoryDataMixin:ToggleExpanded()
	self.elementData.data.expanded = not self.elementData.data.expanded;
end

--------------------------------
-- WQT_SettingsDataContainerMixin
--------------------------------

WQT_SettingsDataContainerMixin = {};

function WQT_SettingsDataContainerMixin:Init()
	self.categories = {};
end

function WQT_SettingsDataContainerMixin:AddCategory(categoryID, label, expanded)
	local category = CreateAndInitFromMixin(WQT_SettingsCategoryDataMixin, categoryID, label, expanded, false);
	table.insert(self.categories, category);
	return category;
end

function WQT_SettingsDataContainerMixin:AddToDataprovider(dataprovider)
	for k, category in ipairs(self.categories) do
		category:AddToDataprovider(dataprovider);
	end
end

function WQT_SettingsDataContainerMixin:GetCategoryByID(categoryID)
	local foundCategory = nil;
	for k, category in ipairs(self.categories) do
		if (category.categoryID == categoryID) then
			foundCategory = category;
			break;
		end
		local subCategory = category:GetCategoryByID(categoryID);
		if (subCategory) then
			foundCategory = subCategory;
			break;
		end
	end

	return foundCategory;
end

--------------------------------
-- WQT_SettingsFrameMixin
--------------------------------

WQT_SettingsFrameMixin = {};

function WQT_SettingsFrameMixin:OnLoad()
	self.TitleText:SetText(SETTINGS);

	self.dataContainer = CreateAndInitFromMixin(WQT_SettingsDataContainerMixin);

	self.cachedTemplateHeights = {};
	self.dummyFrameFactory = CreateFrameFactory();

	local paddingTop = 5;
	local paddingBottom = 14;
	local paddingLeft = 2;
	local paddingRight = paddingLeft;
	local view = CreateScrollBoxListLinearView(paddingTop, paddingBottom, paddingLeft, paddingRight, SETTING_SPACING);
	view:SetElementExtentCalculator(function (index, elementData)
		local height = self.cachedTemplateHeights[elementData.template];
		local isDynamic = height and height < 0;

		if (not height) then
			height = 0;
			local info = C_XMLUtil.GetTemplateInfo(elementData.template);
			for k, keyValue in ipairs(info.keyValues) do
				if (keyValue.key == "dynamicHeight" and keyValue.value:lower() == "true") then
					self.cachedTemplateHeights[elementData.template] = -1;
					isDynamic = true;
					break;
				end
			end

			if (not isDynamic) then
				height = info.height;
				self.cachedTemplateHeights[elementData.template] = height;
			end
		end

		if (isDynamic) then
			-- To "predict" the height of the frame, we set up a dummy frame and get it's height
			local dummyFrame = self.dummyFrameFactory:Create(self, elementData.template);
			dummyFrame:SetPoint("LEFT", self);
			dummyFrame:SetPoint("RIGHT", self);
			dummyFrame:Init(elementData.data);
			height = dummyFrame:GetHeight();
			self.dummyFrameFactory:Release(dummyFrame);
		end

		return height or 0;
	end);

	view:SetElementFactory(function(factory, elementData)
		factory(elementData.template, function(frame, data)
			frame:Init(data.data);
		end);
	end);

	ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, view);
end

local function CreateDropdownOption(id, label, tooltip)
	return { id = id, label = label, tooltip = tooltip};
end

function WQT_SettingsFrameMixin:Init()
	WQT_CallbackRegistry:RegisterCallback("WQT.Settings.CategoryToggled",
		function(_, categoryID)
			local foundCategory = self.dataContainer:GetCategoryByID(categoryID);
			if (foundCategory) then
				foundCategory:ToggleExpanded();
				self:Reconstruct();
			end
		end,
		self);

	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID)
			if (categoryID == "PROFILES") then
				-- Delaying a frame because it causes issues if it's triggered by a dropdown change
				C_Timer.After(0, function() self:Reconstruct(); end);
			else
				for k, frame in self.ScrollBox:EnumerateFrames() do
					frame:UpdateState();
				end
			end
		end,
		self);

	local CATEGORY_DEFAULT_EXPANDED = true;
	do -- Changelog
		local changeLogCategory = self.dataContainer:AddCategory("CHANGELOG", _L["WHATS_NEW"], not CATEGORY_DEFAULT_EXPANDED);

		local ChangelogSections = {
			Intro = "Intro";
			New = "New";
			Changes = "Changes";
			Fixes = "Fixes";
		}
		local currentCategory = nil;
		local currentVersion = ""

		local function StartVersionCategory(version)
			currentVersion = version;
			local expand = currentCategory == nil;
			currentCategory = changeLogCategory:AddSubCategory(version, version, expand);
		end

		local function AddSection(section, notes)
			if (type(notes) ~= "table" or #notes == 0) then
				securecall(error, "Adding section without notes");
				return;
			end

			local noteColor  = section == ChangelogSections.Intro and GOLD_FONT_COLOR or NORMAL_FONT_COLOR;
			if (section ~= ChangelogSections.Intro) then
				local tag = string.format("%s_%s", currentVersion, section);
				local bottomPadding = 2;
				local data = currentCategory:CreateText(tag, section, "Fancy14Font", WHITE_FONT_COLOR, bottomPadding);
				data:SetValueToKey("leftPadding", -4);
			end
			for k, note in ipairs(notes) do
				local tag = string.format("%s_%s_%s", currentVersion, section, k);
				currentCategory:CreateText(tag, note, "GameFontNormal", noteColor);
			end
		end

		-- do -- 
		-- 	StartVersionCategory("");
		-- 	AddSection(ChangelogSections.Intro, {
				
		-- 	});
		-- 	AddSection(ChangelogSections.New, {
				
		-- 	});
		-- 	AddSection(ChangelogSections.Changes, {
				
		-- 	});
		-- 	AddSection(ChangelogSections.Fixes, {
				
		-- 	});
		-- end

		do -- 11.2.10
			StartVersionCategory("11.2.10");
			AddSection(ChangelogSections.Intro, {
				"Update for patch 11.2.7";
			});
			AddSection(ChangelogSections.Changes, {
				"Some optimizations to quest list updating";
				"Some tweaks to dealing with overlapping pins";
				"Moved the 'Anima' and 'Conduids' reward filters to the 'Other' category";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed some flight maps not showing quests with 'Zone Quests' set to 'Zone Only'";
				"Made quests in Tazavesh show up on the K'aresh map with 'Zone Quests' set to 'Zone Only'";
				"Fixed quests not showing in Stranglethron Vale with 'Zone Quests' set to 'Zone Only'";
				"Fixed quests not showing on the Argus flight map in general";
				"Fixed an issue with TomTom arrows now always working";
				"Fixed some taint issues caused by the tab button";
			});
		end

		do -- 11.2.09
			StartVersionCategory("11.2.09");
			AddSection(ChangelogSections.Changes, {
				"Reworked the settings menu. Let me know if I broke anything";
				"Checkbox and color picker settings can now be clicked across their entire size";
				"Changed the 'Tracking' checkmark on map pins with blizzard's waypoint icon, where a glowing one will indicate if it's your current waypoint";
				"The quest that is the current waypoint now has a brighter border";
			});
		end

		do -- 11.2.08
			StartVersionCategory("11.2.08");
			AddSection(ChangelogSections.New, {
				"Added new setting General - Zone Quests: Choose for zones to only show quests for that zone, include neighbouring zones, or all quests for the related expansion";
			});
			AddSection(ChangelogSections.Changes, {
				"Combined the Always All Quests setting into the new Zone Quests setting";
				"Re-added an icon to make it easier to spot new or changed settings";
				"Lowered CPU usage when nothing is going on. Not that it was needed, but might as well.";
			});
		end

		do -- 11.2.07
			StartVersionCategory("11.2.07");
			AddSection(ChangelogSections.Changes, {
				"Made the reward quality in the quest list more clear";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed the right click menu on map pins not showing";
			});
		end

		do -- 11.2.06
			StartVersionCategory("11.2.06");
			AddSection(ChangelogSections.New, {
				"Added an option to Map Pins - Main Icon Type to show the quest's faction icon";
				"Added an option for the pin label to show the amount of the main quest reward";
				"Added an option to toggle the text colors of the map pin label";
			});
			AddSection(ChangelogSections.Changes, {
				"Moved the map pin Time Label setting into a dropdown together with the new reward amount setting";
				"Slightly increased the interaction area of map pins";
				"Some visual changes to pin labels which seems to have also fixed jittery pin visuals";
				"Reworked how quests info structured. Easier to maintain and seems to have fixed glitchy quest title positioning";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed an issue with the Party Sync feature";
				"Fixed times in the quest list not properly updating below 1 hour with Expand Times enabled";
			});
		end

		do -- 11.2.05
			StartVersionCategory("11.2.05");
			AddSection(ChangelogSections.Intro, {
				"Update for patch 11.2.5";
			});
			AddSection(ChangelogSections.Changes, {
				"Moved the changelog into the settings menu";
				"Minor tweaks to the visuals of quests in the list";
			});
		end

		do -- 11.2.04
			StartVersionCategory("11.2.04");
			AddSection(ChangelogSections.Changes, {
				"Slightly lightened up the visuals of map pins";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed a possible error in areas such as Island Expeditions with Always All Quests enabled";
				"Fixed a possible error with other add-ons adding tabs to the world map";
			});
		end

		do -- 11.2.03
			StartVersionCategory("11.2.03");
			AddSection(ChangelogSections.New, {
				"Warband bonus reward icons for both the quest list and map pins (default off)";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed tooltip rewards not showing if its appearance isn't collected yet";
				"Fixed tooltips not showing a message regarding one-time warband bonus reputation";
				"Fixed a possible error for characters level 70-79";
				"Fixed some issues with Asian reward amount. Maybe, I can't actually test this myself";
				"Fixed the zhTW loca just straight up not getting loaded (woops)";
				"Fixed an error in the settings with Warmode enabled";
			});
		end

		do -- 11.2.02
			StartVersionCategory("11.2.02");
			AddSection(ChangelogSections.Changes, {
				"Increased the max rewards in the quest list from 4 to 5";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed an issue where some settings wouldn't save between reloads";
				"Fixed an issue that caused some quests to show up while on the Azeroth map that shouldn't";
				"Fixed incorrect reward amounts using War Mode";
				"Fixed item level on relic rewards";
				"Fixed Zereth Mortis quests not showing while on the Shadowlands map";
			});
		end

		do -- 11.2.01
			StartVersionCategory("11.2.01");
			AddSection(ChangelogSections.Intro, {
				"Update for patch 11.2";
				"Note: It's possible you might not see all quests available in K'aresh unless you are physically inside the zone. This is an issue on Blizzard's end.";
			});
			AddSection(ChangelogSections.Changes, {
				"Made some changes to which quests show up in the list";
				"Using the Blizzard's map filters will once again affect the pins and quest list";
			});
			AddSection(ChangelogSections.Fixes, {
				"Fixed a possible error with the custom Shadowlands bounty board";
			});
		end

		do -- 11.1.01
			StartVersionCategory("11.1.01");
			AddSection(ChangelogSections.Intro, {
				"Shoutout to the people who tried their best to keep things running for the past 4 years. I'd name you all but I only now realize how many of you there are.";
				"If you created a fork, helped those forks, or even guided other people to said forks; Thank you.";
				"Please note that maintaining this add-on is low priority. Which means updates might be slow and unreliable.";
			});
			AddSection(ChangelogSections.Changes, {
				"Compatibility with patch 11.1.7";
				"Visual update to match the new UI";
				"A bunch of refactoring of which you hopefully only notice positive things";
				"Things that didn't survive:|n- Quest counter on the normal quest tab|n- Anything LFG related|n- Support for WQT Utilities|n- Daily quest things such as old Nzoth quests";
			});
		end
	end -- Changelog

	do -- Profiles
		local category = self.dataContainer:AddCategory("PROFILES", _L["PROFILES"], not CATEGORY_DEFAULT_EXPANDED);

		do -- Active Profile
			local data = category:AddDropdown("CURRENT_PROFILE", _L["CURRENT_PROFILE"], _L["CURRENT_PROFILE_TT"], function() return WQT_Profiles:GetProfiles() end);
			data:SetGetValueFunction(function() return WQT.db.char.activeProfile; end);
			data:SetValueChangedFunction(function(value)
				if (value == WQT_Profiles:GetActiveProfileId()) then return; end
				WQT_Profiles:Load(value);
			end);
		end

		do -- Profile Name
			local data = category:AddTextInput("PROFILE_NAME", _L["PROFILE_NAME"], _L["PROFILE_NAME_TT"]);
			data:SetGetValueFunction(function() return WQT_Profiles:GetActiveProfileName(); end);
			data:SetValueChangedFunction(function(value) return WQT_Profiles:ChangeActiveProfileName(value); end);
			data:SetIsVisibleFunction(function() return not WQT_Profiles:DefaultIsActive() end);
		end

		do -- Create Profile
			local data = category:AddButton("CREATE_PROFILE", _L["NEW_PROFILE"], _L["NEW_PROFILE_TT"]);
			data:SetValueChangedFunction(function() return WQT_Profiles:CreateNew(); end);
		end

		do -- Reset Profile
			local data = category:AddConfirmButton("RESET_PROFILE", _L["RESET_PROFILE"], _L["RESET_PROFILE_TT"]);
			data:SetValueChangedFunction(function() return WQT_Profiles:ResetActive(); end);
		end

		do -- Remove Profile
			local data = category:AddConfirmButton("REMOVE_PROFILE", _L["REMOVE_PROFILE"], _L["REMOVE_PROFILE_TT"]);
			data:SetValueChangedFunction(function() return WQT_Profiles:Delete(WQT_Profiles:GetActiveProfileId()); end);
			data:SetIsVisibleFunction(function() return not WQT_Profiles:DefaultIsActive() end);
		end
	end -- Profiles

	do -- General
		local category = self.dataContainer:AddCategory("GENERAL", GENERAL, CATEGORY_DEFAULT_EXPANDED);

		do -- Default Tab
			local data = category:AddCheckbox("DEFAULT_TAB", _L["DEFAULT_TAB"], _L["DEFAULT_TAB_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.general.defaultTab; end);
			data:SetValueChangedFunction(function(value) WQT.settings.general.defaultTab = value; end);
		end

		do -- Save Filters
			local data = category:AddCheckbox("SAVE_FILTERS", _L["SAVE_SETTINGS"], _L["SAVE_SETTINGS_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.general.saveFilters; end);
			data:SetValueChangedFunction(function(value) WQT.settings.general.saveFilters = value; end);
		end

		do -- Precise Filters
			local data = category:AddCheckbox("PRECISE_FILTERS", _L["PRECISE_FILTER"], _L["PRECISE_FILTER_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.general.preciseFilters; end);
			data:SetValueChangedFunction(function(value)
				for i=1, 3 do
					if (not WQT:IsUsingFilterNr(i)) then
						WQT:SetAllFilterTo(i, not value);
					end
				end
				WQT.settings.general.preciseFilters = value;
			end);
		end

		do -- Auto Emissary
			local data = category:AddCheckbox("AUTO_EMISARRY", _L["AUTO_EMISARRY"], _L["AUTO_EMISARRY_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.general.autoEmisarry; end);
			data:SetValueChangedFunction(function(value) WQT.settings.general.autoEmisarry = value; end);
		end

		do -- Zone Quests
			local options = {
				CreateDropdownOption(_V["ENUM_ZONE_QUESTS"].zone, _L["ZONE_QUESTS_ZONE"], _L["ZONE_QUESTS_ZONE_TT"]);
				CreateDropdownOption(_V["ENUM_ZONE_QUESTS"].neighbor, _L["ZONE_QUESTS_VISIBLE"], _L["ZONE_QUESTS_VISIBLE_TT"]);
				CreateDropdownOption(_V["ENUM_ZONE_QUESTS"].expansion, _L["ZONE_QUESTS_EXPANSION"], _L["ZONE_QUESTS_EXPANSION_TT"]);
			};
		
			local data = category:AddDropdown("ZONE_QUESTS", _L["ZONE_QUESTS"], _L["ZONE_QUESTS_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.general.zoneQuests; end);
			data:SetValueChangedFunction(function(value) WQT.settings.general.zoneQuests = value; end);
			data:MarkAsNew(); -- 11.2.5
		end

		do -- Old Expanpansions
			local subCategory = category:AddSubCategory("GENERAL_OLDCONTENT", _L["PREVIOUS_EXPANSIONS"], not CATEGORY_DEFAULT_EXPANDED);

			do -- SL Calling Board
				local data = subCategory:AddCheckbox("CALLINGS_BOARD", _L["CALLINGS_BOARD"], _L["CALLINGS_BOARD_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.general.sl_callingsBoard; end);
				data:SetValueChangedFunction(function(value) WQT.settings.general.sl_callingsBoard = value; end);
			end

			do -- Generic Anima
				local data = subCategory:AddCheckbox("GENERIC_ANIMA", _L["GENERIC_ANIMA"], _L["GENERIC_ANIMA_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.general.sl_genericAnimaIcons; end);
				data:SetValueChangedFunction(function(value) WQT.settings.general.sl_genericAnimaIcons = value; end);
			end
			
			do -- Bounty Counter
				local data = subCategory:AddCheckbox("BOUNTY_COUNTER", _L["EMISSARY_COUNTER"], _L["EMISSARY_COUNTER_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.general.bountyCounter; end);
				data:SetValueChangedFunction(function(value) WQT.settings.general.bountyCounter = value; end);
			end
			
			do -- Bounty Reward
				local data = subCategory:AddCheckbox("BOUNTY_REWARD", _L["EMISSARY_REWARD"], _L["EMISSARY_REWARD_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.general.bountyReward; end);
				data:SetValueChangedFunction(function(value) WQT.settings.general.bountyReward = value; end);
			end
			
			do -- Bounty Only
				local data = subCategory:AddCheckbox("BOUNTY_SELECTED_ONLY", _L["EMISSARY_SELECTED_ONLY"], _L["EMISSARY_SELECTED_ONLY_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.general.bountySelectedOnly; end);
				data:SetValueChangedFunction(function(value) WQT.settings.general.bountySelectedOnly = value; end);
			end
		end
	end -- General

	do -- Quest List
		local category = self.dataContainer:AddCategory("QUESTLIST", _L["QUEST_LIST"], not CATEGORY_DEFAULT_EXPANDED);

		do -- Preview
			category:AddCustomTemplate("WQT_SettingsQuestListPreviewTemplate", "QUEST_PREVIEW");
		end

		do -- Show Type
			local data = category:AddCheckbox("QUEST_LIST_TYPE", _L["SHOW_TYPE"], _L["SHOW_TYPE_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.typeIcon; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.typeIcon = value; end);
		end

		do -- Faction Icon
			local data = category:AddCheckbox("QUEST_LIST_FACTION", _L["SHOW_FACTION"], _L["SHOW_FACTION_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.factionIcon; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.factionIcon = value; end);
		end

		do -- Show Zone
			local data = category:AddCheckbox("QUEST_ZONE", _L["SHOW_ZONE"], _L["SHOW_ZONE_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.showZone; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.showZone = value; end);
		end

		do -- Warband Icon
			local data = category:AddCheckbox("QUEST_WARBAND", _L["SETTINGS_WARBAND_ICON"], _L["SETTINGS_WARBAND_ICON_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.warbandIcon; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.warbandIcon = value; end);
		end

		do -- Num Rewards
			local valueMin = 0;
			local valueMax = 5;
			local valueStep = 1;
			local data = category:AddSlider("QUEST_NUM_REWARDS", _L["REWARD_NUM_DISPLAY"], _L["REWARD_NUM_DISPLAY_TT"], valueMin, valueMax, valueStep);
			data:SetGetValueFunction(function() return WQT.settings.list.rewardNumDisplay; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.rewardNumDisplay = value; end);
		end

		do -- Amount Colors
			local data = category:AddCheckbox("QUEST_AMOUNT_COLORS", _L["AMOUNT_COLORS"], _L["AMOUNT_COLORS_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.amountColors; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.amountColors = value; end);
		end

		do -- Time Colors
			local data = category:AddCheckbox("QUEST_TIME_COLORS", _L["LIST_COLOR_TIME"], _L["LIST_COLOR_TIME_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.colorTime; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.colorTime = value; end);
		end

		do -- Expanded Time
			local data = category:AddCheckbox("QUEST_FULL_TIME", _L["LIST_FULL_TIME"], _L["LIST_FULL_TIME_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.list.fullTime; end);
			data:SetValueChangedFunction(function(value) WQT.settings.list.fullTime = value; end);
		end

		do -- Fade Pins
			local data = category:AddCheckbox("QUEST_FADE_PINS", _L["PIN_FADE_ON_PING"], _L["PIN_FADE_ON_PING_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.pin.fadeOnPing; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.fadeOnPing = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end
	end -- Quest List

	do -- Map Pins
		local category = self.dataContainer:AddCategory("MAPPINS", _L["MAP_PINS"], not CATEGORY_DEFAULT_EXPANDED);

		do -- Disable Change
			local data = category:AddCheckbox("PIN_DISABLE_CHANGES", _L["PIN_DISABLE"], _L["PIN_DISABLE_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.pin.disablePoI; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.disablePoI = value; end);
			data:MarkAsSuggestReload();
		end

		do -- Filter Pins
			local data = category:AddCheckbox("PIN_FILTER", _L["FILTER_PINS"], _L["FILTER_PINS_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.pin.filterPoI; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.filterPoI = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Elite Ring
			local data = category:AddCheckbox("PIN_ELITE_RING", _L["PIN_ELITE_RING"], _L["PIN_ELITE_RING_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.pin.eliteRing; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.eliteRing = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Pin Scale
			local minValue = 0.8;
			local maxValue = 1.5;
			local valueStep = 0.01;
			local data = category:AddSlider("PIN_SCALE", _L["PIN_SCALE"], _L["PIN_SCALE_TT"], minValue, maxValue, valueStep);
			data:SetGetValueFunction(function() return WQT.settings.pin.scale; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.scale = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Center Type
			local options = {
				CreateDropdownOption(_V["PIN_CENTER_TYPES"].blizzard, _L["BLIZZARD"], _L["PIN_BLIZZARD_TT"]);
				CreateDropdownOption(_V["PIN_CENTER_TYPES"].reward, REWARD, _L["PIN_REWARD_TT"]);
				CreateDropdownOption(_V["PIN_CENTER_TYPES"].faction, FACTION, _L["PIN_FACTION_TT"]);
			};
			
			local data = category:AddDropdown("PIN_CENTER_TYPE", _L["PIN_CENTER"], _L["PIN_CENTER_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.pin.centerType; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.centerType = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Ring Type
			local options = {
				CreateDropdownOption(_V["RING_TYPES"].default, _L["PIN_RING_DEFAULT"], _L["PIN_RING_DEFAULT_TT"]);
				CreateDropdownOption(_V["RING_TYPES"].reward, _L["PIN_RING_COLOR"], _L["PIN_RING_COLOR_TT"]);
				CreateDropdownOption(_V["RING_TYPES"].time, _L["PIN_RING_TIME"], _L["PIN_RIMG_TIME_TT"]);
				CreateDropdownOption(_V["RING_TYPES"].rarity, RARITY, _L["PIN_RING_QUALITY_TT"]);
			};
		
			local data = category:AddDropdown("PIN_RING_TYPE", _L["PIN_RING_TITLE"], _L["PIN_RING_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.pin.ringType; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.ringType = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Label
			local options = {
				CreateDropdownOption(_V["ENUM_PIN_LABEL"].none, NONE, _L["PIN_LABEL_NONE_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_LABEL"].time, _L["PIN_TIME"], _L["PIN_TIME_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_LABEL"].amount, _L["PIN_LABEL_REWARD"], _L["PIN_LABEL_REWARD_TT"]);
			};
		
			local data = category:AddDropdown("PIN_LABEL", _L["PIN_LABEL"], _L["PIN_LABEL_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.pin.label; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.label = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			data:MarkAsNew(); -- 11.2.5
		end

		do -- Label Colors
			local data = category:AddCheckbox("PIN_LABEL_COLORS", _L["PIN_LABEL_COLORS"], _L["PIN_LABEL_COLORS_TT"]);
			data:SetGetValueFunction(function() return WQT.settings.pin.labelColors; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.labelColors = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.label == _V["ENUM_PIN_LABEL"].none; end);
			data:MarkAsNew(); -- 11.2.5
		end

		do -- Zone Visibility
			local options = {
				CreateDropdownOption(_V["ENUM_PIN_ZONE"].none, NONE, _L["PIN_VISIBILITY_NONE_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_ZONE"].tracked, _L["PIN_VISIBILITY_TRACKED"], _L["PIN_VISIBILITY_TRACKED_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_ZONE"].all, ALL, _L["PIN_VISIBILITY_ALL_TT"]);
			};

			local data = category:AddDropdown("PIN_ZONE_VISIBILITY", _L["PIN_VISIBILITY_ZONE"], _L["PIN_VISIBILITY_ZONE_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.pin.zoneVisible; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.zoneVisible = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Continent Visibility
			local options = {
				CreateDropdownOption(_V["ENUM_PIN_CONTINENT"].none, NONE, _L["PIN_VISIBILITY_NONE_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_CONTINENT"].tracked, _L["PIN_VISIBILITY_TRACKED"], _L["PIN_VISIBILITY_TRACKED_TT"]);
				CreateDropdownOption(_V["ENUM_PIN_CONTINENT"].all, ALL, _L["PIN_VISIBILITY_ALL_TT"]);
			};
		
			local data = category:AddDropdown("PIN_CONTINENT_VISIBILITY", _L["PIN_VISIBILITY_CONTINENT"], _L["PIN_VISIBILITY_CONTINENT_TT"], options);
			data:SetGetValueFunction(function() return WQT.settings.pin.continentVisible; end);
			data:SetValueChangedFunction(function(value) WQT.settings.pin.continentVisible = value; end);
			data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
		end

		do -- Mini Icons
			local subCategory = category:AddSubCategory("MAPPINS_MINIICONS", _L["MINI_ICONS"], not CATEGORY_DEFAULT_EXPANDED);

			do -- Pin Type
				local data = subCategory:AddCheckbox("MINI_ICON_PIN_TYPE", _L["PIN_TYPE"], _L["PIN_TYPE_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.pin.typeIcon; end);
				data:SetValueChangedFunction(function(value) WQT.settings.pin.typeIcon = value; end);
				data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			end

			do -- Rarity
				local data = subCategory:AddCheckbox("MINI_ICON_RARITY", _L["PIN_RARITY_ICON"], _L["PIN_RARITY_ICON_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.pin.rarityIcon; end);
				data:SetValueChangedFunction(function(value) WQT.settings.pin.rarityIcon = value; end);
				data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			end

			do -- Time
				local data = subCategory:AddCheckbox("MINI_ICON_TIME", _L["PIN_TIME_ICON"], _L["PIN_TIME_ICON_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.pin.timeIcon; end);
				data:SetValueChangedFunction(function(value) WQT.settings.pin.timeIcon = value; end);
				data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			end

			do -- Warband
				local data = subCategory:AddCheckbox("MINI_ICON_WARBAND", _L["SETTINGS_WARBAND_ICON"], _L["SETTINGS_WARBAND_ICON_TT"]);
				data:SetGetValueFunction(function() return WQT.settings.pin.warbandIcon; end);
				data:SetValueChangedFunction(function(value) WQT.settings.pin.warbandIcon = value; end);
				data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			end

			do -- Num Rewards
				local minValue = 0;
				local maxValue = 3;
				local valueStep = 1;
				local data = subCategory:AddSlider("MINI_ICON_NUM_REWARDS", _L["REWARD_NUM_DISPLAY_PIN"], _L["REWARD_NUM_DISPLAY_PIN_TT"], minValue, maxValue, valueStep);
				data:SetGetValueFunction(function() return WQT.settings.pin.numRewardIcons; end);
				data:SetValueChangedFunction(function(value) WQT.settings.pin.numRewardIcons = value; end);
				data:SetIsDisabledFunction(function() return WQT.settings.pin.disablePoI; end);
			end
		end
	end -- Map Pins

	do -- Colors
		local category = self.dataContainer:AddCategory("CUSTOM_COLORS", _L["CUSTOM_COLORS"], not CATEGORY_DEFAULT_EXPANDED);

		do -- Time Colors
			local subCategory = category:AddSubCategory("CUSTOM_COLORS_TIME", _L["TIME_COLORS"], CATEGORY_DEFAULT_EXPANDED);

			subCategory:AddColorPicker("COLOR_TIME_CRITICAL", _L["TIME_CRITICAL"], _L["TIME_CRITICAL_TT"], "timeCritical", RED_FONT_COLOR);
			subCategory:AddColorPicker("COLOR_TIME_SHORT", _L["TIME_SHORT"], _L["TIME_SHORT_TT"], "timeShort", _V["WQT_ORANGE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_TIME_MEDIUM", _L["TIME_MEDIUM"], _L["TIME_MEDIUM_TT"], "timeMedium", _V["WQT_GREEN_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_TIME_LONG", _L["TIME_LONG"], _L["TIME_LONG_TT"], "timeLong", _V["WQT_BLUE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_TIME_VERY_LONG", _L["TIME_VERYLONG"], _L["TIME_VERYLONG_TT"], "timeVeryLong", _V["WQT_PURPLE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_TIME_NONE", NONE, _L["TIME_NONE_TT"], "timeNone", _V["WQT_COLOR_CURRENCY"]);
		end

		do -- Reward Amount Colors
			local subCategory = category:AddSubCategory("CUSTOM_COLORS_AMOUNT", _L["REWARD_COLORS_AMOUNT"], not CATEGORY_DEFAULT_EXPANDED);

			subCategory:AddColorPicker("COLOR_AMOUNT_WEAPON", WEAPON, nil, "rewardTextWeapon", _V["WQT_COLOR_WEAPON"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_ARMOR", ARMOR, nil, "rewardTextArmor", _V["WQT_COLOR_ARMOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_ITEM", ITEMS, nil, "rewardTextItem", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_XP", POWER_TYPE_EXPERIENCE, nil, "rewardTextXp", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_GOLD", WORLD_QUEST_REWARD_FILTERS_GOLD, nil, "rewardTextGold", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_CURRENCY", CURRENCY, nil, "rewardTextCurrency", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_REPUTATION", REPUTATION, nil, "rewardTextReputation", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_HONOR", HONOR, nil, "rewardTextHonor", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_ANIMA", WORLD_QUEST_REWARD_FILTERS_ANIMA, nil, "rewardTextAnima", GREEN_FONT_COLOR);
			subCategory:AddColorPicker("COLOR_AMOUNT_ARTIFACT", ITEM_QUALITY6_DESC, nil, "rewardTextArtifact", GREEN_FONT_COLOR);
			subCategory:AddColorPicker("COLOR_AMOUNT_CONDUIT", _L["REWARD_CONDUITS"], nil, "rewardTextConduit", _V["WQT_WHITE_FONT_COLOR"]);
			subCategory:AddColorPicker("COLOR_AMOUNT_RELIC", RELICSLOT, nil, "rewardTextRelic", _V["WQT_WHITE_FONT_COLOR"]);
		end

		do -- Reward Ring Colors
			local subCategory = category:AddSubCategory("CUSTOM_COLORS_RING", _L["REWARD_COLORS_RING"], not CATEGORY_DEFAULT_EXPANDED);

			subCategory:AddColorPicker("COLOR_REWARD_NONE", NONE, nil, "rewardNone", _V["WQT_COLOR_NONE"]);
			subCategory:AddColorPicker("COLOR_REWARD_WEAPON", WEAPON, nil, "rewardWeapon", _V["WQT_COLOR_WEAPON"]);
			subCategory:AddColorPicker("COLOR_REWARD_ARMOR", ARMOR, nil, "rewardArmor", _V["WQT_COLOR_ARMOR"]);
			subCategory:AddColorPicker("COLOR_REWARD_ITEM", ITEMS, nil, "rewardItem", _V["WQT_COLOR_ITEM"]);
			subCategory:AddColorPicker("COLOR_REWARD_XP", POWER_TYPE_EXPERIENCE, nil, "rewardXp", _V["WQT_COLOR_ITEM"]);
			subCategory:AddColorPicker("COLOR_REWARD_GOLD", WORLD_QUEST_REWARD_FILTERS_GOLD, nil, "rewardGold", _V["WQT_COLOR_GOLD"]);
			subCategory:AddColorPicker("COLOR_REWARD_CURRENCY", CURRENCY, nil, "rewardCurrency", _V["WQT_COLOR_CURRENCY"]);
			subCategory:AddColorPicker("COLOR_REWARD_REPUTATION", REPUTATION, nil, "rewardReputation", _V["WQT_COLOR_CURRENCY"]);
			subCategory:AddColorPicker("COLOR_REWARD_HONOR", HONOR, nil, "rewardHonor", _V["WQT_COLOR_HONOR"]);
			subCategory:AddColorPicker("COLOR_REWARD_ANIMA", WORLD_QUEST_REWARD_FILTERS_ANIMA, nil, "rewardAnima", _V["WQT_COLOR_ARTIFACT"]);
			subCategory:AddColorPicker("COLOR_REWARD_ARTIFACT", ITEM_QUALITY6_DESC, nil, "rewardArtifact", _V["WQT_COLOR_ARTIFACT"]);
			subCategory:AddColorPicker("COLOR_REWARD_CONDUIT", _L["REWARD_CONDUITS"], nil, "rewardConduit", _V["WQT_COLOR_RELIC"]);
			subCategory:AddColorPicker("COLOR_REWARD_RELIC", RELICSLOT, nil, "rewardRelic", _V["WQT_COLOR_RELIC"]);
			subCategory:AddColorPicker("COLOR_REWARD_MISSING", ADDON_MISSING, nil, "rewardMissing", _V["WQT_COLOR_MISSING"]);
		end
	end -- Colors
end

function WQT_SettingsFrameMixin:Reconstruct()
	if (not self.dataContainer) then return; end

	local dataProvider = CreateDataProvider();
	self.dataContainer:AddToDataprovider(dataProvider);
	self.ScrollBox:SetDataProvider(dataProvider , ScrollBoxConstants.RetainScrollPosition);
end

function WQT_SettingsFrameMixin:OnShow()
	self:Reconstruct();
end