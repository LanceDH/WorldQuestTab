local addonName, addon = ...

local WQT = addon.WQT;
local _L = addon.L;
local WQT_Utils;

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
			TomTom:AddWaypoint(zoneId, x, y, {["title"] = title, ["crazy"] = true});
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

local _settings = {
	{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "TOMTOM", ["label"] = _L["USE_TOMTOM"], ["tooltip"] = _L["USE_TOMTOM_TT"]
			, ["valueChangedFunc"] = function(value) 
				_activeSettings.useTomTom = value;
			end
			,["getValueFunc"] = function() return _activeSettings.useTomTom; end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "TOMTOM", ["label"] = _L["TOMTOM_AUTO_ARROW"], ["tooltip"] = _L["TOMTOM_AUTO_ARROW_TT"]
			, ["valueChangedFunc"] = function(value) 
				_activeSettings.TomTomAutoArrow = value;
			end
			,["getValueFunc"] = function() return _activeSettings.TomTomAutoArrow; end
			,["isDisabled"] = function() return not _activeSettings.useTomTom; end
			}
	,{["template"] = "WQT_SettingCheckboxTemplate", ["categoryID"] = "TOMTOM", ["label"] = _L["TOMTOM_CLICK_ARROW"], ["tooltip"] = _L["TOMTOM_CLICK_ARROW_TT"]
			, ["valueChangedFunc"] = function(value) 
				_activeSettings.TomTomArrowOnClick = value;
					
				if (not value and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					WQT_Utils:RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
			end
			,["getValueFunc"] = function() return _activeSettings.TomTomArrowOnClick; end
			,["isDisabled"] = function() return not _activeSettings.useTomTom; end
			}
}

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
				AddTomTomArrowByQuestId(questId);
				--If click arrow is active, we want to clear the previous click arrow
				if (clickArrow and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
				
				if (clickArrow and not questHardWatched) then
					WQT_WorldQuestFrame.softTomTomArrow = questId;
				end
			end
			
		else
			RemoveTomTomArrowbyQuestId(questId)
		end
	end
end

local function TomTomIsOK()
	return TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints;
end

local function TomTomIsChecked(questInfo)
	if (not TomTomIsOK()) then return false; end
	
	local questId = questInfo.questID;
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
	local title = C_TaskQuest.GetQuestInfoByQuestID(questId);

	return TomTom:WaypointExists(zoneId, x, y, title);
end

local function TomTomOnPressed(questInfo)
	if (not TomTomIsOK()) then 
		print("Something is wrong with TomTom. Either it failed to load correctly, or an update changed its functionality."); 
		return;
	end

	local questId = questInfo.questID;
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
	local title = C_TaskQuest.GetQuestInfoByQuestID(questId);

	if (TomTom:WaypointExists(zoneId, x, y, title)) then
		RemoveTomTomArrowbyQuestId(questId);
	else
		AddTomTomArrowByQuestId(questId);
	end
end

local function AddTomTomToQuestContext(source, rootDescription, questInfo)
	if(not _activeSettings or not _activeSettings.useTomTom) then return; end
	rootDescription:CreateCheckbox(_L["TOMTOM_PIN"], TomTomIsChecked, TomTomOnPressed, questInfo);
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
	return "TomTom";
end

function TomTomExternal:GetRequiredEvents()
	return { "QUEST_WATCH_LIST_CHANGED",  "QUEST_TURNED_IN"};
end

function TomTomExternal:Init(utils)
	WQT_Utils = utils;
	
	_activeSettings = WQT_Utils:RegisterExternalSettings("TomTom", _defaultSettings);
	WQT_Utils:AddExternalSettingsOptions(_settings);

	WQT_CallbackRegistry:RegisterCallback("WQT.QuestContextSetup", AddTomTomToQuestContext, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.RegisterdEventTriggered", EventTriggered, self);
end

WQT_WorldQuestFrame:LoadExternal(TomTomExternal);
