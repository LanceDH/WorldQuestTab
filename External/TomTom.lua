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

local function QuestListChangedHook(event, ...)
	local questId, added = ...;
	-- We don't have settings (yet?)
	if (not _activeSettings) then return; end
	
	-- Update TomTom arrows when quests change. Might be new that needs tracking or completed that needs removing
	local autoArrow = _activeSettings.TomTomAutoArrow;
	local clickArrow = _activeSettings.TomTomArrowOnClick;
	if (questId and TomTom and _activeSettings.useTomTom and (clickArrow or autoArrow) and QuestUtils_IsQuestWorldQuest(questId)) then
		
		if (added) then
			local questHardWatched = WQT_Utils:QuestIsWatchedManual(questId);
			if (clickArrow or questHardWatched) then
				WQT_Utils:AddTomTomArrowByQuestId(questId);
				--If click arrow is active, we want to clear the previous click arrow
				if (clickArrow and WQT_WorldQuestFrame.softTomTomArrow and not WQT_Utils:QuestIsWatchedManual(WQT_WorldQuestFrame.softTomTomArrow)) then
					WQT_Utils:RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
				
				if (clickArrow and not questHardWatched) then
					WQT_WorldQuestFrame.softTomTomArrow = questId;
				end
			end
			
		else
			WQT_Utils:RemoveTomTomArrowbyQuestId(questId)
		end
	end
end

local function TrackDropDownHook(ddFrame)
	local questInfo = ddFrame:GetSourceParent().questInfo;
	local questId = questInfo.questId;
	local zoneId = C_TaskQuest.GetQuestZoneID(questId);
	local x, y = C_TaskQuest.GetQuestLocation(questId, zoneId)
	local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
	local info = ddFrame:CreateButtonInfo("option");

		-- TomTom functionality
	if (TomTom and _activeSettings.useTomTom) then
	
		if (TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			-- All required functions are found
			if ( not TomTom:WaypointExists(zoneId, x, y, title)) then
				info.text = WQT_Utils:GetLocal("TRACKDD_TOMTOM");
				info.func = function()
					WQT_Utils:AddTomTomArrowByQuestId(questId);
				end
			else
				info.text = WQT_Utils:GetLocal("TRACKDD_TOMTOM_REMOVE");
				info.func = function()
					WQT_Utils:RemoveTomTomArrowbyQuestId(questId);
				end
			end
		else
			-- Something wrong with TomTom
			info.text = "TomTom Unavailable";
			info.func = function()
				print("Something is wrong with TomTom. Either it failed to load correctly, or an update changed its functionality.");
			end
		end
		
		ddFrame:AddButton(info);
	end
end

local TomTomExternal = CreateFromMixins(WQT_ExternalMixin);

function TomTomExternal:GetName()
	return "TomTom";
end

function TomTomExternal:Init(utils)
	WQT_Utils = utils;
	
	_activeSettings = WQT_Utils:RegisterExternalSettings("TomTom", _defaultSettings);
	WQT_Utils:AddExternalSettingsOptions(_settings);
	-- Remove point on quest complete
	WQT_WorldQuestFrame:RegisterCallback("WorldQuestCompleted", function(questId) WQT_Utils:RemoveTomTomArrowbyQuestId(questId) end);
	WQT_WorldQuestFrame:RegisterCallback("InitTrackDropDown", TrackDropDownHook);
	-- Hook onto Blizzard's events
	WQT_WorldQuestFrame:HookEvent("QUEST_WATCH_LIST_CHANGED", QuestListChangedHook);
end

tinsert(addon.externals, TomTomExternal);