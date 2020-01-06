local addonName, addon = ...

local WQT = addon.WQT;
local _L = addon.L;
local _V = addon.variables;
local WQT_Utils = addon.WQT_Utils;

local _settings = {
	{["type"] = _V["SETTING_TYPES"].checkBox, ["categoryID"] = "TOMTOM", ["label"] = _L["USE_TOMTOM"], ["tooltip"] = _L["USE_TOMTOM_TT"]
			, ["func"] = function(value) 
				WQT.settings.general.useTomTom = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.useTomTom; end
			}
	,{["type"] = _V["SETTING_TYPES"].checkBox, ["categoryID"] = "TOMTOM", ["label"] = _L["TOMTOM_AUTO_ARROW"], ["tooltip"] = _L["TOMTOM_AUTO_ARROW_TT"]
			, ["func"] = function(value) 
				WQT.settings.general.TomTomAutoArrow = value;
			end
			,["getValueFunc"] = function() return WQT.settings.general.TomTomAutoArrow; end
			,["isDisabled"] = function() return not WQT.settings.general.useTomTom; end
			}	
	,{["type"] = _V["SETTING_TYPES"].checkBox, ["categoryID"] = "TOMTOM", ["label"] = _L["TOMTOM_CLICK_ARROW"], ["tooltip"] = _L["TOMTOM_CLICK_ARROW_TT"]
			, ["func"] = function(value) 
				WQT.settings.general.TomTomArrowOnClick = value;
					
				if (not value and WQT_WorldQuestFrame.softTomTomArrow and not IsWorldQuestHardWatched(WQT_WorldQuestFrame.softTomTomArrow)) then
					WQT_Utils:RemoveTomTomArrowbyQuestId(WQT_WorldQuestFrame.softTomTomArrow);
				end
			end
			,["getValueFunc"] = function() return WQT.settings.general.TomTomArrowOnClick; end
			,["isDisabled"] = function() return not WQT.settings.general.useTomTom; end
			}		
}

local function AddTomTomSettings()
	for k, setting in ipairs(_settings) do
		tinsert(_V["SETTING_LIST"], setting);
	end
end

local WorldFlightMapExternal = CreateFromMixins(WQT_ExternalMixin);

function WorldFlightMapExternal:GetName()
	return "TomTom";
end

function WorldFlightMapExternal:Init()
	AddTomTomSettings();
end

tinsert(addon.externals, WorldFlightMapExternal);