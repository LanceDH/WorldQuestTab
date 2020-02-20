-- Mixin to create an external add-on addition
WQT_ExternalMixin = {};

function WQT_ExternalMixin:GetName()
	-- Override me
	return "";
end

function WQT_ExternalMixin:Init()
	-- Override me
end

function WQT_ExternalMixin:IsLoaded()
	local name = self:GetName();
	if (name ~= "") then
		return IsAddOnLoaded(name);
	end
	return false;
end

function WQT_ExternalMixin:IsLoadable()
	local name = self:GetName();
	if (name ~= "") then
		return select(2, GetAddOnInfo(name));
	end
	return false;
end