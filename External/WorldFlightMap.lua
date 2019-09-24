local addonName, addon = ...

local _V = addon.variables;
local _externalName = "WorldFlightMap";

local function ReAnchor(...)
	if (not IsAddOnLoaded(_externalName)) then return; end
	
	local event, anchor = ...;
	local anchorType = _V["LIST_ANCHOR_TYPE"];
	if (anchor == anchorType.taxi or anchor == anchorType.flight) then
		WQT_WorldQuestFrame:ChangeAnchorLocation(anchorType.world);
	end
end

local function WFM_LoadFunc()
	WQT_WorldQuestFrame:RegisterCallback("AnchorChanged", ReAnchor);
	
	return _externalName, true;
end

tinsert(addon.externals, WFM_LoadFunc);