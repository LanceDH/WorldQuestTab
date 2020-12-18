local addonName, addon = ...
local WQT = addon.WQT;
local _L = addon.L
local _V = addon.variables;
local ADD = LibStub("AddonDropDown-2.0");
local WQT_Utils = addon.WQT_Utils;
local WQT_Profiles = addon.WQT_Profiles;

local _profileReferenceList = {};

local function ReferenceListSort(a, b)
	-- Default always on top, and in case of duplicate labels
	if (a.arg1 == 0 or b.arg1 == 0) then
		return a.arg1 < b.arg1;
	end
	
	if(a.label:lower() == b.label:lower()) then
		if(a.label == b.label) then
			-- Juuuust incase
			return a.arg1 < b.arg1;
		end
		return a.label < b.label;
	end
	
	-- Alphabetical 
	return a.label:lower() < b.label:lower();
end

local function ClearDefaults(a, b)
	if(not a or not b) then return; end
	for k, v in pairs(b) do
		if (type(a[k]) == "table" and type(v) == "table") then
			ClearDefaults(a[k], v);
			if (next(a[k]) == nil) then
				a[k] = nil;
			end
		elseif (a[k] ~= nil and a[k] == v) then
			a[k] = nil;
		end
	end
end

local function ProfileNameIsAvailable(name)
	for k, v in pairs(WQT.db.global.profiles) do
		if (v.name == name) then
			return false;
		end
	end
	return true;
end

local function ForceCopy(a, b)
	for k, v in pairs(b) do
		if (type(v) == "table") then
			ForceCopy(a[k], v);
		else
			a[k] = v;
		end
	end
end

local function CopyIfNil(a, b)
	for k, v in pairs(b) do
		local curVal = a[k];
		if (curVal == nil) then
			-- No value, add the default one
			if (type(v) == "table") then
				a[k] = CopyTable(v);
			else
				a[k] = v;
			end
		elseif (type(curVal) == "table") then
			CopyIfNil(curVal, v);
		end
	end
end

local function AddCategoryDefaults(category)
	if (not _V["WQT_DEFAULTS"].global[category]) then
		return;
	end
	-- In case a setting doesn't have a newer category yet
	if (not WQT.settings[category]) then
		WQT.settings[category] = {};
	end
	
	CopyIfNil(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
end

local function GetProfileById(id)
	for index, profile in ipairs(_profileReferenceList) do
		if (profile.arg1 == id) then
			return profile, index
		end
	end
end

local function AddProfileToReferenceList(id, name)
	if (not GetProfileById(id)) then
		tinsert(_profileReferenceList, {["label"] = name, ["arg1"] = id});
	end
end

local function ApplyVersionChanges(profile, version)
	if (version < "8.3.04") then
		profile.pin.numRewardIcons = profile.pin.rewardTypeIcon and 1 or 0;
		profile.pin.rewardTypeIcon = nil;
	end
end

function WQT_Profiles:InitSettings()
	self.externalDefaults = {};

	-- Version checking
	local settingVersion = WQT.db.global.versionCheck or"0";
	local currentVersion = GetAddOnMetadata(addonName, "version");
	if (settingVersion < currentVersion) then
		WQT.db.global.updateSeen = false;
		WQT.db.global.versionCheck  = currentVersion;
	end
	
	-- Setup profiles
	WQT.settings = {["colors"] = {}, ["general"] = {}, ["list"] = {}, ["pin"] = {}, ["filters"] = {}};
	if (not WQT.db.global.profiles[0]) then
		local profile = {
			["name"] = DEFAULT
			,["colors"] = CopyTable(WQT.db.global.colors or {})
			,["general"] = CopyTable(WQT.db.global.general or {})
			,["list"] = CopyTable(WQT.db.global.list or {})
			,["pin"] = CopyTable(WQT.db.global.pin or {})
			,["filters"] = CopyTable(WQT.db.global.filters or {})
		}
		WQT.db.global.colors = nil;
		WQT.db.global.general = nil;
		WQT.db.global.list = nil;
		WQT.db.global.pin = nil;
		WQT.db.global.filters = nil;
		
		WQT.db.global.profiles[0] = profile;
		self:LoadProfileInternal(0, profile);
	end

	
	for id, profile in pairs(WQT.db.global.profiles) do
		ApplyVersionChanges(profile, settingVersion);
		AddProfileToReferenceList(id, profile.name);
	end

	self:Load(WQT.db.char.activeProfile);
end

function WQT_Profiles:GetProfiles()
	-- Make sure names are up to date
	for index, refProfile in ipairs(_profileReferenceList) do
		local profile = WQT.db.global.profiles[refProfile.arg1];
		if (profile) then
			refProfile.label = profile.name;
		end
	end
	
	-- Sort
	table.sort(_profileReferenceList, ReferenceListSort);

	return _profileReferenceList;
end

function WQT_Profiles:CreateNew()
	local id = time();
	if (GetProfileById(id)) then
		-- Profile for current timestamp already exists. Don't spam the bloody button
		return;
	end
	
	-- Get current settings to copy over
	local currentSettings = WQT.db.global.profiles[WQT.db.char.activeProfile];

	if (not currentSettings) then
		return;
	end
	
	-- Create new profile
	local profile = {
		["name"] = self:GetFirstValidProfileName()
		,["colors"] = CopyTable(currentSettings.colors or {})
		,["general"] = CopyTable(currentSettings.general or {})
		,["list"] = CopyTable(currentSettings.list or {})
		,["pin"] = CopyTable(currentSettings.pin or {})
		,["filters"] = CopyTable(currentSettings.filters or {})
	}
	
	WQT.db.global.profiles[id] = profile;
	AddProfileToReferenceList(id, profile.name);
	self:Load(id);
end

function WQT_Profiles:LoadIndex(index)
	local profile = _profileReferenceList[index];
	
	if (profile) then
		self:LoadDefault();
		return;
	end
	
	self:Load(profile.id);
end

function WQT_Profiles:LoadProfileInternal(id, profile)

	WQT.db.char.activeProfile = id;
	WQT.settings = profile;
	
	-- Add defaults
	AddCategoryDefaults("colors");
	AddCategoryDefaults("general");
	AddCategoryDefaults("list");
	AddCategoryDefaults("pin");
	AddCategoryDefaults("filters");
	
	
	local externals = WQT.settings.external;
	if (not externals) then
		WQT.settings.external = {};
		externals = WQT.settings.external
	end
	
	for external, settings in pairs(self.externalDefaults) do
		local externalSettings = externals[external];
		if (not externalSettings) then
			externals[external] = {};
			externalSettings = externals[external];
		end
		CopyIfNil(externalSettings, settings);
	end
	
	-- Make sure our colors are up to date
	WQT_Utils:LoadColors();
end


function WQT_Profiles:Load(id)
	WQT_Profiles:ClearDefaultsFromActive();

	if (not id or id == 0) then
		self:LoadDefault();
		return;
	end

	local profile = WQT.db.global.profiles[id];
	
	if (not profile) then
		-- Profile not found
		self:LoadDefault();
		return;
	end
	self:LoadProfileInternal(id, profile);
	WQT_WorldQuestFrame:TriggerCallback("LoadProfile");
end

function WQT_Profiles:Delete(id)
	if (not id or id == 0) then
		-- Trying to delete the default profile? That's a paddlin'
		return;
	end
	
	local profile, index = GetProfileById(id);
	
	if (index) then
		tremove(_profileReferenceList, index);
		WQT.db.global.profiles[id] = nil;
	end

	self:LoadDefault();
end

function WQT_Profiles:LoadDefault()
	self:LoadProfileInternal(0, WQT.db.global.profiles[0]);
end

function WQT_Profiles:DefaultIsActive()
	return not WQT or not WQT.db.global or not WQT.db.char.activeProfile or WQT.db.char.activeProfile == 0
end

function WQT_Profiles:IsValidProfileId(id)
	if (not id or id == 0) then 
		return false;
	end
	return WQT.db.global.profiles[id] and true or false;
end

function WQT_Profiles:GetFirstValidProfileName(baseName)
	if(not baseName) then
		local playerName = UnitName("player"); -- Realm still returns nill, sick
		local realmName = GetRealmName();
		baseName = ITEM_SUFFIX_TEMPLATE:format(playerName, realmName);
	end
	
	if (ProfileNameIsAvailable(baseName)) then
		return baseName;
	end
	-- Add a number
	local suffix = 2;
	local combinedName = ITEM_SUFFIX_TEMPLATE:format(baseName, suffix);
	
	while (not ProfileNameIsAvailable(combinedName)) do
		suffix = suffix + 1;
		combinedName = ITEM_SUFFIX_TEMPLATE:format(baseName, suffix);
	end
	
	return combinedName;
end

function WQT_Profiles:ChangeActiveProfileName(newName)
	local profileId = self:GetActiveProfileId();
	if (not profileId or profileId == 0) then
		-- Don't change the default profile name
		return;
	end
	-- Add suffix number in case of duplicate
	newName = WQT_Profiles:GetFirstValidProfileName(newName);
	
	local profile = GetProfileById(profileId);
	if(profile) then
		profile.label = newName;
		WQT.db.global.profiles[profileId].name = newName;
	end
end

function WQT_Profiles:GetActiveProfileId()
	return WQT.db.char.activeProfile;
end

function WQT_Profiles:GetIndexById(id)
	local profile, index = GetProfileById(id);
	return index or 0;
end

function WQT_Profiles:GetActiveProfileName()
	local activeProfile = WQT.db.char.activeProfile;
	if(activeProfile == 0) then
		return DEFAULT;
	end
	
	local profile = WQT.db.global.profiles[activeProfile or 0];
	
	return profile and profile.name or "Invalid Profile";
end

function WQT_Profiles:ClearDefaultsFromActive()
	local category = "general";
	
	ClearDefaults(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "list";
	ClearDefaults(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "pin";
	ClearDefaults(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "filters";
	ClearDefaults(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	category = "colors";
	ClearDefaults(WQT.settings[category], _V["WQT_DEFAULTS"].global[category]);
	
	--External
	local externals = WQT.settings.external;
	for external, settings in pairs(self.externalDefaults) do
		ClearDefaults(externals[external], settings);
	end
	
	WQT_WorldQuestFrame:TriggerCallback("ClearDefaults");
end

function WQT_Profiles:ResetActive()
	local category = "general";
	wipe(WQT.settings[category]);
	WQT.settings[category]= CopyTable(_V["WQT_DEFAULTS"].global[category]);
	category = "list";
	wipe(WQT.settings[category]);
	WQT.settings[category]= CopyTable(_V["WQT_DEFAULTS"].global[category]);
	category = "pin";
	wipe(WQT.settings[category]);
	WQT.settings[category]= CopyTable(_V["WQT_DEFAULTS"].global[category]);
	category = "filters";
	wipe(WQT.settings[category]);
	WQT.settings[category]= CopyTable(_V["WQT_DEFAULTS"].global[category]);
	category = "colors";
	wipe(WQT.settings[category]);
	WQT.settings[category]= CopyTable(_V["WQT_DEFAULTS"].global[category]);
	
	-- Make sure our colors are up to date
	WQT_Utils:LoadColors();
	
	--External
	local externals = WQT.settings.external;
	for external, settings in pairs(self.externalDefaults) do
		if (externals[external]) then
			wipe(externals[external]);
			-- The external has a direct reference to this table, so don't replace it
			CopyIfNil(externals[external], settings);
		end
	end
	
	WQT_WorldQuestFrame:TriggerCallback("ResetActive");
end

function WQT_Profiles:RegisterExternalSettings(key, settings)
	local list = self.externalDefaults[key];
	if (not list) then
		list = {};
		self.externalDefaults[key] = list;
	end
	
	CopyIfNil(list, settings);
	self:Load(WQT.db.char.activeProfile);
	
	return WQT.settings.external[key];
end
