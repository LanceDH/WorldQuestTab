--[[
-- Remember to add WorldQuestTab to your (optional) dependencies
if (not WQT_WorldQuestFrame) then
	return;
end

local WQT_Utils;


local ExampleExternal = CreateFromMixins(WQT_ExternalMixin);

function ExampleExternal:GetName()
	-- Return Add-on name
	return "Base";
end

-- This function will run the moment the external load
function ExampleExternal:Init(utils)
	WQT_Utils = utils;
	print("Base");
	-- Callbacks for actions the add-on does
	WQT_WorldQuestFrame:RegisterCallback("WorldQuestCompleted", function(...) print("Callback", ...) end);
	-- Hook onto Blizzard's events
	WQT_WorldQuestFrame:HookEvent("QUEST_WATCH_LIST_CHANGED", function () print("event") end);
end

-- Make the add-on load your stuff
-- WQT_WorldQuestFrame:LoadExternal(ExampleExternal);
]]--


