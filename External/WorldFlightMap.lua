local name = "WorldFlightMap";
local addonName, addon = ...
local WQT = addon.WQT;

local _V = addon.variables;

local function ReAnchor(source, anchor)
	local enumListAnchorType = _V:GetListAnchorTypeEnum();
	if (anchor == enumListAnchorType.taxi or anchor == enumListAnchorType.flight) then
		WQT_WorldQuestFrame:ChangeAnchorLocation(enumListAnchorType.world);
	end
end

local function ReApplyPinAlphas(source, pin)
	pin.alphaFactor = 1;
	pin.startAlpha = 1;
	pin.endAlpha = 1;
end

local WorldFlightMapExternal = CreateAndInitFromMixin(WQT_ExternalMixin, name);

function WorldFlightMapExternal:OnLoad()
	WQT_CallbackRegistry:RegisterCallback("WQT.CoreFrame.AnchorUpdated", ReAnchor, self);
	WQT_CallbackRegistry:RegisterCallback("WQT.MapPinProvider.PinInitialized", ReApplyPinAlphas, self);
end
