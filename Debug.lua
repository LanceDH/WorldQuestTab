local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
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
	ScrollUtil.InitScrollBoxListWithScrollBar(self.CallbackScrollBox, self.CallbackScrollBar, view);

	self.callbackDataProvider = CreateDataProvider();
	self.CallbackScrollBox:SetDataProvider(self.callbackDataProvider, ScrollBoxConstants);

	ScrollUtil.RegisterAlternateRowBehavior(self.CallbackScrollBox, ApplyAlternateState);

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
		if (not WQT_DevFrame.CallbackScrollBox:IsShown()) then return; end
		local wasAtEnd = self.CallbackScrollBox:IsAtEnd();
		local hadScroll = self.CallbackScrollBox:HasScrollableExtent();

		local data = {};
		data.timestamp = GetTime();
		data.eventName = event;
		data.eventPayload = {...};
		self.callbackDataProvider:Insert(data);

		if (wasAtEnd or (not hadScroll and self.CallbackScrollBox:HasScrollableExtent())) then
			self.CallbackScrollBox:ScrollToEnd();
		end
	end);

end

function WQT_DevMixin:OnUpdate()
	if (not self:IsShown()) then return end;

	if (WorldMapFrame:IsShown()) then
		self.worldMapMousePos:SetText(string.format("WorldMapMouse: %.2f %.2f", WorldMapFrame:GetNormalizedCursorPosition()));
	end
end


function WQT_DevMixin:DoDebugThing()

end
