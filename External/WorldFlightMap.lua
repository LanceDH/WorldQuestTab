local addonName, addon = ...

local _V = addon.variables;

local function ReAnchor(anchor)
	local anchorType = _V["LIST_ANCHOR_TYPE"];
	if (anchor == anchorType.taxi or anchor == anchorType.flight) then
		WQT_WorldQuestFrame:ChangeAnchorLocation(anchorType.world);
	end
end

local function ReApplyPinAlphas(pin)
	pin.alphaFactor = 1;
	pin.startAlpha = 1;
	pin.endAlpha = 1;
end

local WorldFlightMapExternal = CreateFromMixins(WQT_ExternalMixin);

function WorldFlightMapExternal:GetName()
	return "WorldFlightMap";
end

function WorldFlightMapExternal:Init()
	WQT_WorldQuestFrame:RegisterCallback("AnchorChanged", ReAnchor);
	WQT_WorldQuestFrame:RegisterCallback("MapPinInitialized", ReApplyPinAlphas);
end

tinsert(addon.externals, WorldFlightMapExternal);