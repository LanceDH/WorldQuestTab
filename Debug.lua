local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

------------------------
-- Debug Tooltip
------------------------
function WQT:debugPrint(...)
	if (addon.debugPrint) then 
		print("WQT", ...);
	end
end

local function AddIndentedDoubleLine(tooltip, a, b, level, color)
	local indented = string.rep("    ", level) .. a;
	if (type(b) == "table" and b.GetRGBA) then
		b = floor(b.r*100)/100 .. "/" ..  floor(b.g*100)/100 .. "/" ..  floor(b.b*100)/100;
	elseif (type(b) == "table" and b.GetXY) then
		b = "{" ..floor(b.x*100)/100 .. " | " .. floor(b.y*100)/100 .. "}";
	elseif (type(b) == "boolean") then
		b = b and "true" or "false";
	elseif  (type(a) == "string" and a:find("Bits") and type(b) == "number" and b > 0) then
		local bits = b;
		local o = "";
		local index = 0;
		while (bits > 0) do
			local rest = bits% 2
			if (rest > 0) then
				o = o .. (o == "" and "" or ", ") .. index;
			end
			bits = (bits - rest) / 2
			index = index + 1;
		end
		b = string.format("%s (%s)", b, o);
	elseif (b == nil) then
		b = "nil";
	end
	tooltip:AddDoubleLine(indented, b, color.r, color.g, color.b, color.r, color.g, color.b);
end

local function KeySortFunc(a, b)
	return a < b;
end

function WQT:AddDebugToTooltip(tooltip, questInfo, level)
	if (not addon.debug) then return end;
	level = level or -1;
	local color = LIGHTBLUE_FONT_COLOR;

	-- First all non table values;
	local sortedKeys = {}
	for key, value in pairs(questInfo) do
		if ((type(value) ~= "table" or value.GetRGBA) and type(value) ~= "function") then
			tinsert(sortedKeys, key);
		end
	end
	table.sort(sortedKeys, KeySortFunc);
	for _, key in ipairs(sortedKeys) do
		AddIndentedDoubleLine(tooltip, key, questInfo[key], level+1, color);
	end
	wipe(sortedKeys);

	-- Actual tables
	for key, value in pairs(questInfo) do
		if (type(value) == "table" and not value.GetRGBA and key ~= "debug") then
			tinsert(sortedKeys, key);
		end
	end

	table.sort(sortedKeys, KeySortFunc);
	for _, key in ipairs(sortedKeys) do
		AddIndentedDoubleLine(tooltip, key, "", level+1, color);
		self:AddDebugToTooltip(tooltip, questInfo[key], level + 1)
	end
end

function WQT:AddFunctionDebugToTooltip(tooltip, questInfo, level)
	local color = GRAY_FONT_COLOR;

	local classifictaion = C_QuestInfoSystem.GetQuestClassification(questInfo.questID)
	AddIndentedDoubleLine(tooltip, "classifictaion", classifictaion, 0, color);
	local difficultyLevel = C_QuestLog.GetQuestDifficultyLevel(questInfo.questID);
	AddIndentedDoubleLine(tooltip, "difficultyLevel", difficultyLevel, 0, color);
	local expLevel = GetQuestExpansion(questInfo.questID);
	AddIndentedDoubleLine(tooltip, "expansion", expLevel, 0, color);
	-- Time
	local seconds, timeString, timeColor, timeStringShort = WQT_Utils:GetQuestTimeString(questInfo, true, true);
	AddIndentedDoubleLine(tooltip, "time", "", 0, color);
	AddIndentedDoubleLine(tooltip, "seconds", seconds, 1, color);
	AddIndentedDoubleLine(tooltip, "timeString", timeString, 1, color);
	AddIndentedDoubleLine(tooltip, "color", timeColor, 1, color);
	AddIndentedDoubleLine(tooltip, "timeStringShort", timeStringShort, 1, color);
	AddIndentedDoubleLine(tooltip, "isExpired", questInfo:IsExpired(), 1, color);
	-- Faction
	local factionInfo = WQT_Utils:GetFactionDataInternal(questInfo.factionID);
	AddIndentedDoubleLine(tooltip, "faction", "", 0, color);
	AddIndentedDoubleLine(tooltip, "name", factionInfo.name, 1, color);
	AddIndentedDoubleLine(tooltip, "playerFaction", factionInfo.playerFaction, 1, color);
	AddIndentedDoubleLine(tooltip, "texture", factionInfo.texture, 1, color);
	AddIndentedDoubleLine(tooltip, "expansion", factionInfo.expansion, 1, color);
	-- MapInfo
	local mapInfo = WQT_Utils:GetCachedMapInfo(questInfo.mapID);
	AddIndentedDoubleLine(tooltip, "mapInfo", "", 0, color);
	if (mapInfo) then
		AddIndentedDoubleLine(tooltip, "name", mapInfo.name, 1, color);
		AddIndentedDoubleLine(tooltip, "mapID", mapInfo.mapID, 1, color);
		AddIndentedDoubleLine(tooltip, "parentMapID", mapInfo.parentMapID, 1, color);
		AddIndentedDoubleLine(tooltip, "mapType", mapInfo.mapType, 1, color);
	else
		AddIndentedDoubleLine(tooltip, "Map info missing", "", 1, color);
	end
end

function WQT:ShowDebugTooltipForQuest(questInfo, anchor)
	if (not addon.debug) then return end;
	WQT_DebugTooltip:SetOwner(anchor, "ANCHOR_LEFT");
	if (IsShiftKeyDown()) then
		WQT_DebugTooltip:SetText("Info Through Functions");
		self:AddFunctionDebugToTooltip(WQT_DebugTooltip, questInfo)
	else
		WQT_DebugTooltip:SetText("Info Through QuestInfo");
		self:AddDebugToTooltip(WQT_DebugTooltip, questInfo)
	end
	WQT_DebugTooltip:Show();
end

function WQT:HideDebugTooltip()
	WQT_DebugTooltip:Hide();
end

------------------------
-- Debug Panel
------------------------

local function GetPayloadString(payload)
	if (payload == nil or not type(payload) == "table" or #payload == 0) then
		return "";
	end
	local args = {};

	for k, v in ipairs(payload) do
		table.insert(args, tostring(v));
	end

	return table.concat(args, ", ");
end

local function FormatTimeStamp(timestamp)
	local units = ConvertSecondsToUnits(timestamp);
	local seconds = units.seconds + units.milliseconds;
	if units.hours > 0 then
		return string.format("%.2d:%.2d:%06.3fs", units.hours, units.minutes, seconds);
	else
		return string.format("%.2d:%06.3fs", units.minutes, seconds);
	end
end

local function InitCallbackEntry(frame, data)
	frame.Timestamp:SetText(FormatTimeStamp(data.timestamp));
	frame.EventName:SetText(data.eventName);
	frame.Arguments:SetText(GetPayloadString(data.eventPayload));
end

local function ApplyAlternateState(frame, alternate)
	frame.BG:SetAlpha(alternate and 0.0 or 0.05);
end


--[[

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

function WQT_SettingElementDataMixin:MarkAsNew(isNew)
	self.elementData.data.isNew = isNew;
end


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
end

function WQT_SettingsCategoryDataMixin:AddToDataprovider(dataprovider)
	dataprovider:Insert(self.elementData);

	if (self.elementData.data.expanded) then
		for k, child in ipairs(self.children) do
			child:AddToDataprovider(dataprovider);
		end
	end
end

function WQT_SettingsCategoryDataMixin:AddSubCategory(categoryID, label, expanded)
	if (type(categoryID) ~= "string") then error("'categoryID' must be a string value"); return; end
	local category = CreateAndInitFromMixin(WQT_SettingsCategoryDataMixin, categoryID, label, expanded, true);
	table.insert(self.children, category);
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
	if (type(tag) ~= "string") then WQT:debugPrint("AddTextInput has invalid tag", tag); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingTextInputTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddButton(tag, label, tooltip)
	if (type(tag) ~= "string") then WQT:debugPrint("AddButton has invalid tag", tag); return; end
	local settingMixin = CreateAndInitFromMixin(WQT_SettingElementDataMixin, "WQT_SettingButtonTemplate", label, tooltip, self.categoryID, tag);

	table.insert(self.children, settingMixin);
	return settingMixin;
end

function WQT_SettingsCategoryDataMixin:AddConfirmButton(tag, label, tooltip)
	if (type(tag) ~= "string") then WQT:debugPrint("AddConfirmButton has invalid tag", tag); return; end
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
	for k, child in ipairs(self.children) do
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




WQT_SettingsDataMixin = {};

function WQT_SettingsDataMixin:Init()
	self.categories = {};
end

function WQT_SettingsDataMixin:AddCategory(categoryID, label, expanded)
	local category = CreateAndInitFromMixin(WQT_SettingsCategoryDataMixin, categoryID, label, expanded, false);
	table.insert(self.categories, category);
	return category;
end

function WQT_SettingsDataMixin:AddToDataprovider(dataprovider)
	for k, category in ipairs(self.categories) do
		category:AddToDataprovider(dataprovider);
	end
end

function WQT_SettingsDataMixin:GetCategoryByID(categoryID)
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
]]

local CATEGORY_DEFAULT_EXPANDED = true;

WQT_DevMixin = {};

function WQT_DevMixin:TAXIMAP_OPENED()
	self.flightMapID:SetText(string.format("FlightMap: %s", FlightMapFrame.mapID or 0));
end

function WQT_DevMixin:OnShow()
	self:Layout();

	if (self.initialized) then return; end
	self.initialized = true;

	local view = CreateScrollBoxListLinearView();
	view:SetElementInitializer("WQT_CallbackEntryTemplate", function(frame, data)
		InitCallbackEntry(frame, data);
	end);
	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);

	self.callbackDataProvider = CreateDataProvider();
	self.ScrollBox:SetDataProvider(self.callbackDataProvider, ScrollBoxConstants);

	ScrollUtil.RegisterAlternateRowBehavior(self.ScrollBox, ApplyAlternateState);

	self:SetScript("OnUpdate", function() self:OnUpdate(); end);

	self:RegisterEvent("TAXIMAP_OPENED");

	self:SetScript("OnEvent", function(self, event, ...)
			if (self[event]) then 
				self[event](self, ...);
			end
		end)

	EventRegistry:RegisterCallback("MapCanvas.MapSet",
		function(_, mapID)
			self.worldMapID:SetText(string.format("WorldMap: %s", WorldMapFrame.mapID or 0));
		end, 
		self);

	hooksecurefunc(WQT_CallbackRegistry, "TriggerEvent", function(registry, event, ...)
		local wasAtEnd = self.ScrollBox:IsAtEnd();
		local hadScroll = self.ScrollBox:HasScrollableExtent();

		local data = {};
		data.timestamp = GetTime();
		data.eventName = event;
		data.eventPayload = {...};
		self.callbackDataProvider:Insert(data);

		if (wasAtEnd or (not hadScroll and self.ScrollBox:HasScrollableExtent())) then
			self.ScrollBox:ScrollToEnd();
		end
	end);

if true then return end

	local testView = CreateScrollBoxListLinearView(4, 4);
	self.view = testView;
	testView:SetVirtualized(false);
	testView:SetElementExtentCalculator(function (index, elementData)
		local frames = testView:GetFrames();
		local frame = frames[index];
		if (frame) then 
			return frame:GetHeight();
		end
		return 0;
	end);
	testView:SetElementFactory(function(factory, elementData)
		factory(elementData.template, function(frame, data)
			frame:Init(data.data);
		end);
	end);
	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox2, self.ScrollBar2, testView);

	self.dataProvider = CreateDataProvider();


	self.settingsData = CreateAndInitFromMixin(WQT_SettingsDataMixin);

	

	WQT_CallbackRegistry:RegisterCallback("WQT.Settings.CategoryToggled",
		function(_, categoryID)
			local foundCategory = self.settingsData:GetCategoryByID(categoryID);
			if (foundCategory) then
				foundCategory:ToggleExpanded();
				self:DoDebugThing();
			end
		end,
		self);

	WQT_CallbackRegistry:RegisterCallback("WQT.SettingChanged",
		function(_, categoryID)
			if (categoryID == "PROFILES") then
				-- Delaying a frame because it causes issues if it's triggered by a dropdown change
				C_Timer.After(0, function() self:DoDebugThing(); end);
			else
				for k, frame in self.ScrollBox2:EnumerateFrames() do
					frame:UpdateState();
				end
			end
		end,
		self);
end

function WQT_DevMixin:OnUpdate()
	if (not self:IsShown()) then return end;

	if (WorldMapFrame:IsShown()) then
		self.worldMapMousePos:SetText(string.format("WorldMapMouse: %.2f %.2f", WorldMapFrame:GetNormalizedCursorPosition()));
	end
end


function WQT_DevMixin:DoDebugThing()
	self.dataProvider = CreateDataProvider();
		
	self.settingsData:AddToDataprovider(self.dataProvider);


	self.ScrollBox2:SetDataProvider(self.dataProvider , ScrollBoxConstants.RetainScrollPosition);

	-- Required to correct placement of text frames
	self.ScrollBox2:FullUpdateInternal();
	--self.ScrollBox2:Update(true);
end
