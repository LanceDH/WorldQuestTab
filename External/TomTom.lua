local name = "TomTom";
local addonName, addon = ...
local _L = addon.loca;

local _superTracked;

local function GetArgsFromQuestID(questID)
	if (not questID) then return; end
	local zoneID = C_TaskQuest.GetQuestZoneID(questID);
	if (not zoneID) then return; end
	local title = C_TaskQuest.GetQuestInfoByQuestID(questID);
	local x, y = C_TaskQuest.GetQuestLocation(questID, zoneID)
	if (not title or not x or not y) then return; end
	return zoneID, title, x, y;
end

local function AddTomTomArrowByQuestId(questID)
	local zoneID, title, x, y = GetArgsFromQuestID(questID);
	if (zoneID) then
		local wp = TomTom:AddWaypoint(zoneID, x, y, {["title"] = title, ["crazy"] = true, ["from"] = addonName});
	end
end

local function RemoveTomTomArrowbyQuestId(questID)
	local zoneID, title, x, y = GetArgsFromQuestID(questID);
	if (zoneID) then
		local key = TomTom:GetKeyArgs(zoneID, x, y, title);
		local wp = TomTom.waypoints[zoneID] and TomTom.waypoints[zoneID][key];
		if (wp) then
			TomTom:RemoveWaypoint(wp);
		end
	end
end

local function TomTomIsChecked(questInfo)
	local questId = questInfo.questID;
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
	local title = C_TaskQuest.GetQuestInfoByQuestID(questId);

	return TomTom:WaypointExists(zoneId, x, y, title);
end

local function TomTomOnPressed(questInfo)
	local questId = questInfo.questID;
	
	if (TomTomIsChecked(questInfo)) then
		RemoveTomTomArrowbyQuestId(questId);
	else
		AddTomTomArrowByQuestId(questId);
	end
end

local function ModifyContextMenu(owner, rootDescription, questInfo)
	local count = 0;
	for k, desc in rootDescription:EnumerateElementDescriptions() do
		count = count + 1;
	end
	local checkbox = MenuTemplates.CreateCheckbox(_L:Get("TOMTOM_PIN"), TomTomIsChecked, TomTomOnPressed, questInfo);
	rootDescription:Insert(checkbox, count);
end


local function OnQuestWatchChanged(source, questInfo)
	local settings = source.activeSettings;
	local questID = questInfo.questID;

	if (settings.TomTomArrowOnClick) then
		local superTrackedID = C_SuperTrack.GetSuperTrackedQuestID();
		if (_superTracked and superTrackedID ~= _superTracked and (not settings.TomTomAutoArrow or not WQT_Utils:QuestIsWatchedManual(_superTracked))) then
			RemoveTomTomArrowbyQuestId(_superTracked);
		end

		if (questID == superTrackedID and not IsShiftKeyDown()) then
			_superTracked = questID;
			RemoveTomTomArrowbyQuestId(questID);
			AddTomTomArrowByQuestId(questID);
		end
	end

	if (settings.TomTomAutoArrow) then
		local watchType = C_QuestLog.GetQuestWatchType(questID);
		if (watchType == Enum.QuestWatchType.Manual and IsShiftKeyDown()) then
			AddTomTomArrowByQuestId(questID);
		elseif (not watchType) then
			RemoveTomTomArrowbyQuestId(questID);
		end
	end
end

local function OnEventTriggered(source, event, ...)
	if(event == "QUEST_TURNED_IN") then
		local questID = ...;
		RemoveTomTomArrowbyQuestId(questID);
	end
end


local _defaultSettings = {
		useTomTom = true;
		TomTomAutoArrow = true;
		TomTomArrowOnClick = false;
	};

local TomTomExternal = CreateAndInitFromMixin(WQT_ExternalMixin, name, _defaultSettings);

function TomTomExternal:GetRequiredEvents()
	return { "QUEST_TURNED_IN" };
end

function TomTomExternal:OnLoad()
	local settings = self.activeSettings;
	-- Add options to settings menu
	do
		local category = self:GenerateSettingsCategory();

		do -- Enable
			self:GenerateEnableSetting(category, "useTomTom");
		end

		do -- Auto Arrow
			local data = category:AddCheckbox("TOMTOM_AUTO_ARROW", _L:Get("TOMTOM_AUTO_ARROW"), _L:Get("TOMTOM_AUTO_ARROW_TT"));
			data:SetGetValueFunction(function() return settings.TomTomAutoArrow; end);
			data:SetValueChangedFunction(function(value) settings.TomTomAutoArrow = value; end);
			data:SetIsDisabledFunction(function() return not settings.useTomTom; end);
		end

		do -- Click Arrow
			local data = category:AddCheckbox("TOMTOM_CLICK_ ARROW", _L:Get("TOMTOM_CLICK_ARROW"), _L:Get("TOMTOM_CLICK_ARROW_TT"));
			data:SetGetValueFunction(function() return settings.TomTomArrowOnClick; end);
			data:SetValueChangedFunction(function(value)
				settings.TomTomArrowOnClick = value;
				if (not value and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
			end);
			data:SetIsDisabledFunction(function() return not settings.useTomTom; end);
		end
	end

	-- Add option to quest right click
	Menu.ModifyMenu("WQT_QUEST_CONTEXTMENU", self:CreateEnabledCheckCall(ModifyContextMenu, "useTomTom"));
	WQT_CallbackRegistry:RegisterCallback("WQT.QuestWatchChanged", self:CreateEnabledCheckCall(OnQuestWatchChanged, "useTomTom"), self);
	WQT_CallbackRegistry:RegisterCallback("WQT.RegisterdEventTriggered", self:CreateEnabledCheckCall(OnEventTriggered, "useTomTom"), self);
end


