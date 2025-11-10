local name = "WorldFlightMap";
if (not WQT_Utils:ExternalMightLoad(name)) then return; end

local addonName, addon = ...
local WQT = addon.WQT;

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
	return name;
end

function WorldFlightMapExternal:Init()
	WQT_CallbackRegistry:RegisterCallback("WQT.CoreFrame.AnchorUpdated", ReAnchor, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.MapPinProvider.PinInitialized", ReApplyPinAlphas, self);
end

WQT:AddExternal(WorldFlightMapExternal);