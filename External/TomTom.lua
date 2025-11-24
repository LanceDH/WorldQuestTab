local name = "TomTom";
if (not WQT_Utils:ExternalMightLoad(name)) then return; end

local addonName, addon = ...
local WQT = addon.WQT;

local _L = addon.L;

local _activeSettings;

local _defaultSettings = {
		useTomTom = true;
		TomTomAutoArrow = true;
		TomTomArrowOnClick = false;
	};

local function AddTomTomArrowByQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			TomTom:AddWaypoint(zoneId, x, y, {["title"] = title, ["crazy"] = true, ["from"] = addonName});
		end
	end
end

local function RemoveTomTomArrowbyQuestId(questId)
	if (not questId) then return; end
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	if (zoneId) then
		local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
		local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
		if (title and x and y) then
			local key = TomTom:GetKeyArgs(zoneId, x, y, title);
			local wp = TomTom.waypoints[zoneId] and TomTom.waypoints[zoneId][key];
			if (wp) then
				TomTom:RemoveWaypoint(wp);
			end
		end
	end
end

local function QuestListChangedHook(questId, added)
	-- We don't have settings (yet?)
	if (not _activeSettings) then return; end
	
	-- Update TomTom arrows when quests change. Might be new that needs tracking or completed that needs removing
	local autoArrow = _activeSettings.TomTomAutoArrow;
	local clickArrow = _activeSettings.TomTomArrowOnClick;
	if (questId and TomTom and _activeSettings.useTomTom and (clickArrow or autoArrow) and QuestUtils_IsQuestWorldQuest(questId)) then
		
		if (added) then
			local questHardWatched = WQT_Utils:QuestIsWatchedManual(questId);
			if (clickArrow or questHardWatched) then
				--If click arrow is active, we want to clear the previous click arrow
				if (clickArrow and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
				
				if (clickArrow and not questHardWatched) then
					WQT_WorldQuestFrame.softTomTomArrow = questId;
				end

				AddTomTomArrowByQuestId(questId);
			end
			
		else
			if (WQT_WorldQuestFrame.softTomTomArrow == questId) then
				WQT_WorldQuestFrame.softTomTomArrow = nil;
			end
			RemoveTomTomArrowbyQuestId(questId)
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
	local hasArrow = TomTomIsChecked(questInfo);

	QuestListChangedHook(questId, not hasArrow);
end

local function EventTriggered(source, event, ...)
	if(event == "QUEST_WATCH_LIST_CHANGED") then
		QuestListChangedHook(...);
	elseif(event == "QUEST_TURNED_IN") then
		local questID = ...;
		RemoveTomTomArrowbyQuestId(questID);
	end
end


local TomTomExternal = CreateFromMixins(WQT_ExternalMixin);

function TomTomExternal:GetName()
	return name;
end

function TomTomExternal:GetRequiredEvents()
	return { "QUEST_WATCH_LIST_CHANGED",  "QUEST_TURNED_IN"};
end

function TomTomExternal:Init()
	local isOK = TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints;
	if (not isOK) then
		print("WQT - Something is wrong with TomTom. Either it failed to load correctly, or an update changed its functionality.");
		return;
	end

	_activeSettings = WQT_Utils:RegisterExternalSettings("TomTom", _defaultSettings);

	-- Add options to settings menu
	do
		local expanded = false;
		local category = WQT_SettingsFrame.dataContainer:AddCategory("TOMTOM", "TomTom", expanded);

		do -- Enable
			local data = category:AddCheckbox("TOMTOM_ENABLE", _L["USE_TOMTOM"], _L["USE_TOMTOM_TT"]);
			data:SetGetValueFunction(function() return _activeSettings.useTomTom; end);
			data:SetValueChangedFunction(function(value) _activeSettings.useTomTom = value; end);
		end

		do -- Auto Arrow
			local data = category:AddCheckbox("TOMTOM_AUTO_ARROW", _L["TOMTOM_AUTO_ARROW"], _L["TOMTOM_AUTO_ARROW_TT"]);
			data:SetGetValueFunction(function() return _activeSettings.TomTomAutoArrow; end);
			data:SetValueChangedFunction(function(value) _activeSettings.TomTomAutoArrow = value; end);
			data:SetIsDisabledFunction(function() return not _activeSettings.useTomTom; end);
		end

		do -- Click Arrow
			local data = category:AddCheckbox("TOMTOM_CLICK_ ARROW", _L["TOMTOM_CLICK_ARROW"], _L["TOMTOM_CLICK_ARROW_TT"]);
			data:SetGetValueFunction(function() return _activeSettings.TomTomArrowOnClick; end);
			data:SetValueChangedFunction(function(value)
				_activeSettings.TomTomArrowOnClick = value;
				if (not value and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
			end);
			data:SetIsDisabledFunction(function() return not _activeSettings.useTomTom; end);
		end
	end

	-- Add option to quest right click
	Menu.ModifyMenu("WQT_QUEST_CONTEXTMENU", function(owner, rootDescription, questInfo)
		if(not _activeSettings or not _activeSettings.useTomTom) then return; end
		local count = 0;
		for k, v in rootDescription:EnumerateElementDescriptions() do
			count = count + 1;
		end
		local checkbox = MenuTemplates.CreateCheckbox(_L["TOMTOM_PIN"], TomTomIsChecked, TomTomOnPressed, questInfo);
		rootDescription:Insert(checkbox, count);
	end);

	WQT_CallbackRegistry:RegisterCallback("WQT.RegisterdEventTriggered", EventTriggered, self);
end

WQT:AddExternal(TomTomExternal);
