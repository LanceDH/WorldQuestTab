local addonName, addon = ...

local _V = addon.variables;

local function ReAnchor(source, anchor)
	local anchorType = _V["LIST_ANCHOR_TYPE"];
	if (anchor == anchorType.taxi or anchor == anchorType.flight) then
		WQT_WorldQuestFrame:ChangeAnchorLocation(anchorType.world);
	end
end

local function ReApplyPinAlphas(source, pin)
	pin.alphaFactor = 1;
	pin.startAlpha = 1;
	pin.endAlpha = 1;
end

local WorldFlightMapExternal = CreateFromMixins(WQT_ExternalMixin);

function WorldFlightMapExternal:GetName()
	return "WorldFlightMap";
end

function WorldFlightMapExternal:Init()
	EventRegistry:RegisterCallback("WQT.CoreFrame.AnchorUpdated", ReAnchor, self);
	EventRegistry:RegisterCallback("WQT.MapPinProvider.PinInitialized", ReApplyPinAlphas, self);
end

WQT_WorldQuestFrame:LoadExternal(WorldFlightMapExternal);