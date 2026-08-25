local name = "EllesmereUI";
local addonName, addon = ...
local _L = addon.loca;

local categoryBgColor = CreateColor(1, 1, 1, 0.05);

local function ApplyColorToQuestFrame(skinner, frame)
	local r, g, b = categoryBgColor:GetRGB();-- skinner.GetAccentColor();
	frame.Highlight.Left:SetColorTexture(r, g, b);
	frame.Highlight.Right:SetColorTexture(r, g, b);
	frame.Highlight.Center:SetColorTexture(r, g, b);
end

local function ApplyColorToSetting(skinner, frame)
	if (frame.BgHighlight) then
		local r, g, b = categoryBgColor:GetRGB();-- skinner.GetAccentColor();
		frame.BgHighlight:SetColorTexture(r, g, b, 0.4);
	end
end

local function ApplySkin(skinner)
	do -- QuestScrollframe
		
		do -- Tab
			-- This is copied and altered from Ellesmere code because there is no API for it
			-- "Things most likely to blow up in the future" for 1000, Alex
			local tab = WQT_QuestMapTab;
			local icon = tab.Icon
			local overlay = tab.IconOverlay
			skinner.SquareIcon(icon)
			icon:SetDrawLayer("ARTWORK")
			for k, r in ipairs({tab:GetRegions()}) do
				if (r ~= icon and r ~= overlay and r.IsObjectType and r:IsObjectType("Texture") and r.SetAlpha) then
					r:SetAlpha(0);
				end
			end
			for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetCheckedTexture", "GetHighlightTexture" }) do
				local fn = tab[g];
				local t = fn and fn(tab);
				if (t and t.SetAlpha) then
					t:SetAlpha(0);
				end
			end

			local box = CreateFrame("Frame", nil, tab);
			tab:SetHeight(tab:GetHeight() - 14);
			tab:SetHitRectInsets(0, 0, -7, -7);
			box:SetPoint("TOPLEFT", icon, "TOPLEFT", -7, 7);
			box:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 8, -8);
			box:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 2));
			local fill = EllesmereUI.SolidTex(box, "BACKGROUND", 0.08, 0.08, 0.08, 0.92);
			fill:SetAllPoints(box)
			local PP = EllesmereUI.PanelPP or EllesmereUI.PP;
			PP.CreateBorder(box, 0, 0, 0, 1, 1, "OVERLAY", 7)
			local hov = EllesmereUI.SolidTex(tab, "HIGHLIGHT", 1, 1, 1, 0.1)
			hov:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
			hov:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		end
	
	
		-- Sort
		local sort = WQT_ListContainer:GetSortDropdown();
		skinner.Dropdown(sort);

		-- Filter
		local filter = WQT_ListContainer:GetFilterDropdown();
		skinner.Button(filter);

		-- Searchbox
		local searchBox = WQT_ListContainer:GetSearchBox();
		skinner.EditBox(searchBox);

		-- Scrollbar
		local scrollBar = WQT_ListContainer:GetScrollBar();
		skinner.ScrollBar(scrollBar);

		-- Borderframe
		local borderFrame = WQT_ListContainer:GetBorderFrame();
		borderFrame:SetAlpha(0);

		-- Background
		local function BackgroundUpdated()
			WQT_ListContainer.Background:SetAlpha(0);
			WQT_SettingsFrame.Background:SetAlpha(0);
		end
		WQT_CallbackRegistry:RegisterCallback("WQT.ScrollList.BackgroundUpdated", BackgroundUpdated);

		-- Quest buttons
		local function OnAcquiredQuestFrame(_, frame, data, isNew)
				if (not isNew) then return; end

				ApplyColorToQuestFrame(skinner, frame);
				frame.Highlight:SetAlpha(0.05);
				frame.TrackedBorder:SetPoint("BOTTOMRIGHT", -1, 1);
				frame.TrackedBorder:SetAlpha(0.1);
				frame.TrackedBorder.Left:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
				frame.TrackedBorder.Right:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
				frame.TrackedBorder.Center:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
			end

		local function OnInitializedQuestFrame(_, frame, data)
				local questInfo = data.questInfo;
				local isSuperTracked = questInfo.questID == C_SuperTrack.GetSuperTrackedQuestID();
				local trackAlpha = isSuperTracked and 0.12 or 0.07;
				frame.TrackedBorder:SetAlpha(trackAlpha);
			end

		local scrollBox = WQT_ListContainer:GetQuestScrollBox();
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, OnAcquiredQuestFrame);
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnInitializedQuestFrame);

		-- Full screen container
		skinner.Panel(WQT_WorldMapContainer);
	end


	do -- Settings
		-- Title
		skinner.Font(WQT_SettingsFrame.TitleText);
		skinner.White(WQT_SettingsFrame.TitleText);

		-- Background
		WQT_SettingsFrame.BorderFrame:SetAlpha(0);
		WQT_SettingsFrame.Background:SetAlpha(0);

		-- Scrollbar
		local scrollBar = WQT_SettingsFrame.ScrollBar;
		skinner.ScrollBar(scrollBar);
	
		-- Settings list
		local function UpdateCategoryExpandedTexture(frame)
			if (not frame.collapseTex) then return; end
			local expanded = frame.isExpanded;
			local atlas = expanded and "QuestLog-icon-Shrink" or "QuestLog-icon-Expand";
			local useAtlasSize = true;
			frame.collapseTex:SetAtlas(atlas, useAtlasSize);
			frame.BGRight:SetColorTexture(categoryBgColor:GetRGBA());
		end

		local function OnAcquiredSettingFrame(_, frame, data, isNew)
			if (not isNew) then return; end

			ApplyColorToSetting(skinner, frame);

			local template = data.template;
			if (template == "WQT_SettingDropDownTemplate") then
				skinner.Dropdown(frame.Dropdown);
			elseif (template == "WQT_SettingConfirmButtonTemplate") then
				skinner.Button(frame.Button);
				skinner.Button(frame.ButtonConfirm);
				skinner.Button(frame.ButtonDecline);
			elseif (template == "WQT_SettingButtonTemplate") then
				skinner.Button(frame.Button);
			elseif (template == "WQT_SettingColorTemplate") then
				skinner.Button(frame.Picker, { "Color" });
				skinner.Button(frame.ResetButton, { "Icon" });
			elseif (template == "WQT_SettingCheckboxTemplate") then
				skinner.Checkbox(frame.CheckBox);
			elseif (template == "WQT_SettingSliderTemplate") then
				skinner.EditBox(frame.TextBox);
				frame.TextBox:SetTextInsets(4, 0, 0, 0);
			elseif (template == "WQT_SettingsQuestListPreviewTemplate") then
				frame.Background:SetAlpha(0);
			elseif (template == "WQT_SettingCategoryTemplate") then
				frame.BGLeft:SetPoint("LEFT", 0, 0);
				frame.BGRight:SetPoint("RIGHT", 0, 0);
				frame.HighlightLeft:SetPoint("TOPLEFT", frame.BGLeft, "TOPLEFT", 0, 0);
				frame.HighlightLeft:SetPoint("BOTTOMLEFT", frame.BGLeft, "BOTTOMLEFT", 0, 0);
				frame.HighlightRight:SetPoint("TOPRIGHT", frame.BGRight, "TOPRIGHT", 0, 0);
				frame.HighlightRight:SetPoint("BOTTOMRIGHT", frame.BGRight, "BOTTOMRIGHT", 0, 0);
				frame.BGLeft:SetColorTexture(categoryBgColor:GetRGBA());
				frame.BGMiddle:SetColorTexture(categoryBgColor:GetRGBA());
				frame.BGRight:SetColorTexture(categoryBgColor:GetRGBA());
				frame.HighlightLeft:SetColorTexture(categoryBgColor:GetRGBA());
				frame.HighlightMiddle:SetColorTexture(categoryBgColor:GetRGBA());
				frame.HighlightRight:SetColorTexture(categoryBgColor:GetRGBA());
				frame.collapseTex = frame:CreateTexture(nil, "OVERLAY");
				frame.collapseTex:SetDesaturated(true);
				frame.collapseTex:SetPoint("RIGHT", -20, 0);
				hooksecurefunc(frame, "UpdateState", UpdateCategoryExpandedTexture);
			elseif (template == "WQT_SettingSubCategoryTemplate") then
				frame.Background:SetPoint("TOPLEFT", 20, -5);
				frame.Background:SetPoint("RIGHT", -20, 0);
				frame.Background:SetColorTexture(categoryBgColor:GetRGBA());
				frame.Background:RemoveMaskTexture(frame.Mask);
				frame.Highlight:SetPoint("TOPLEFT", frame.Background, "TOPLEFT", 0, 0);
				frame.Highlight:SetPoint("BOTTOMRIGHT", frame.Background, "BOTTOMRIGHT", 0, 0);
				frame.Highlight:SetColorTexture(categoryBgColor:GetRGBA());
			elseif (template == "WQT_SettingTextInputTemplate") then
				skinner.EditBox(frame.TextBox);
				frame.TextBox:SetPoint("BOTTOMLEFT", 40, 3);
				frame.TextBox:SetTextInsets(8, 8, 0, 0);
			elseif (template == "WQT_SettingSeparatorTemplate") then
				frame.Texture:SetVertexColor(0.85, 0.85, 0.85);
			end
		end

		local function OnInitializedSettingFrame(_, frame, data)
			if (frame.BgHighlight) then
				frame.BgHighlight:SetAlpha(frame:IsDisabled() and 0.05 or 0.1);
			end
		end

		local scrollBox = WQT_SettingsFrame.ScrollBox;
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, OnAcquiredSettingFrame);
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnInitializedSettingFrame);
	end

	do -- Flightmap
		--Button
		skinner.Button(WQT_FlightMapContainerButton, { "Icon", "Arrow" });
	
		--Container
		skinner.Shell(WQT_FlightMapContainer);
		WQT_FlightMapContainer:HookScript("OnShow", function() 
				WQT_FlightMapContainer:SetPoint("BOTTOMLEFT", FlightMapFrame, "BOTTOMRIGHT", -2, 0);
			end)
	end
end


local _defaultSettings = {
		enabled = true;
	};

local ElvUIExternal = CreateAndInitFromMixin(WQT_ExternalMixin, name, _defaultSettings);

function ElvUIExternal:OnLoad()
	if (not EllesmereUI or not EllesmereUI.RegisterSkin) then
		return;
	end

	self:GenerateBasicSettings();

	local settings = self.activeSettings;
	if (not settings.enabled) then return; end

	EllesmereUI.RegisterSkin("World Quest Tab", ApplySkin);
end
