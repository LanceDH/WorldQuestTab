local name = "ElvUI";
local addonName, addon = ...
local WQT = addon.WQT;

local function ApplySkin()
	local E = unpack(ElvUI);
	local S = E:GetModule("Skins");

	local blizzardSkins = E.private.skins.blizzard;
	if (not blizzardSkins.enable) then return; end

	if (blizzardSkins.worldmap) then
		do -- Tab
			local tab = WQT_QuestMapTab;
			tab:CreateBackdrop();
			tab:Size(30, 40);

			local function PositionTabIcons(icon, _, anchor)
				if (anchor) then
					icon:SetPoint("CENTER");
				end
			end

			tab.Icon:ClearAllPoints();
			tab.Icon:SetPoint("CENTER");
			hooksecurefunc(tab.Icon, "SetPoint", PositionTabIcons);

			tab.Background:SetAlpha(0);

			tab.SelectedTexture:SetDrawLayer("ARTWORK");
			tab.SelectedTexture:SetColorTexture(1, 0.82, 0, 0.3);
			tab.SelectedTexture:SetAllPoints();

			for _, region in next, { tab:GetRegions() } do
				if (region:IsObjectType("Texture") and region:GetAtlas() == "QuestLog-Tab-side-Glow-hover") then
					region:SetColorTexture(1, 1, 1, 0.3);
					region:SetAllPoints();
				end
			end
		end

		do -- QuestScrollframe
			-- Sort
			local sort = WQT_ListContainer:GetSortDropdown();
			local width = sort:GetWidth();
			S:HandleDropDownBox(sort, width);

			-- Filter
			local filter = WQT_ListContainer:GetFilterDropdown();
			local isFilterButton = true;
			local filterDirection = "right";
			S:HandleButton(filter, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, isFilterButton, filterDirection);

			-- Searchbox
			local searchBox = WQT_ListContainer:GetSearchBox();
			S:HandleEditBox(searchBox);

			-- Filterbar
			local filterBar = WQT_ListContainer:GetFilterBar();
			filterBar.leftPadding = 0;
			filterBar.rightPadding = 0;
			filterBar:SetAlpha(0.8);

			-- Scrollbar
			local scrollBar = WQT_ListContainer:GetScrollBar();
			S:HandleTrimScrollBar(scrollBar);

			-- Borderframe
			local borderFrame = WQT_ListContainer:GetBorderFrame();
			borderFrame:SetAlpha(0);

			-- Background
			local function BackgroundUpdated()
				WQT_ListContainer.Background:SetDrawLayer("BACKGROUND", -1);
				WQT_ListContainer.Background:SetVertexColor(1, 0.5, 1);
				WQT_ListContainer.Background:SetAlpha(0.9);

				if (E.private.skins.parchmentRemoverEnable) then
					WQT_ListContainer:StripTextures();
					WQT_ListContainer:SetTemplate("Transparent");
				else
					WQT_ListContainer:SetTemplate();
					WQT_ListContainer.Center:Hide();
				end
			end
			WQT_CallbackRegistry:RegisterCallback("WQT.ScrollList.BackgroundUpdated", BackgroundUpdated);

			-- Quest List
			local function OnAcquiredQuestFrame(_, frame, data, isNew)
				if (not isNew) then return; end

				frame.Highlight:StripTextures();
				frame.Highlight:SetAlpha(0.15);
				
				frame.Separator:SetAlpha(0.6);
				frame.Separator:SetHeight(E:Scale(1));

				frame.TrackedBorder:StripTextures();
				frame.TrackedBorder:SetPoint("BOTTOMRIGHT", -1, 1);
				frame.TrackedBorder:SetAlpha(0.1);
				frame.TrackedBorder.Left:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
				frame.TrackedBorder.Right:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
				frame.TrackedBorder.Center:SetColorTexture(GOLD_FONT_COLOR:GetRGB());
			end

			local function OnInitializedQuestFrame(_, frame, data)
				local r, g, b = unpack(E.media.rgbvaluecolor);
				frame.Highlight.Left:SetColorTexture(r, g, b);
				frame.Highlight.Right:SetColorTexture(r, g, b);
				frame.Highlight.Center:SetColorTexture(r, g, b);

				local questInfo = data.questInfo;
				local isSuperTracked = questInfo.questID == C_SuperTrack.GetSuperTrackedQuestID();
				local trackAlpha = isSuperTracked and 0.12 or 0.07;
				frame.TrackedBorder:SetAlpha(trackAlpha);
			end

			local scrollBox = WQT_ListContainer:GetQuestScrollBox();
			scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, OnAcquiredQuestFrame);
			scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnInitializedQuestFrame);
		end

		do -- Settings
			-- Title
			WQT_SettingsFrame.TitleText:FontTemplate(nil, 16)

			-- Background
			local borderFrame = WQT_SettingsFrame.BorderFrame;
			borderFrame:SetAlpha(0);
			WQT_SettingsFrame.Background:SetDrawLayer("BACKGROUND", -1);
			WQT_SettingsFrame.Background:SetVertexColor(1, 0.5, 1);
			WQT_SettingsFrame.Background:SetAlpha(0.9);
			WQT_SettingsFrame:StripTextures();
			WQT_SettingsFrame:SetTemplate("Transparent");

			-- Scrollbar
			local scrollBar = WQT_SettingsFrame.ScrollBar;
			S:HandleTrimScrollBar(scrollBar);

			-- Settings list
			local function UpdateCategoryExpandedTexture(frame, expanded)
				if (not frame.collapseTex) then return; end
				expanded = type(expanded) == "nil" and frame.isExpanded or expanded;
				local atlas = expanded and "QuestLog-icon-Shrink" or "QuestLog-icon-Expand";
				local useAtlasSize = true;
				frame.collapseTex:SetAtlas(atlas, useAtlasSize);
			end

			local function OnAcquiredSettingFrame(_, frame, data, isNew)
				if (not isNew) then return; end

				local template = data.template;
				if (template == "WQT_SettingDropDownTemplate") then
					local width = frame.Dropdown:GetWidth();
					S:HandleDropDownBox(frame.Dropdown, width);
				elseif (template == "WQT_SettingConfirmButtonTemplate") then
					S:HandleButton(frame.Button);
					S:HandleButton(frame.ButtonConfirm);
					S:HandleButton(frame.ButtonDecline);
				elseif (template == "WQT_SettingButtonTemplate") then
					S:HandleButton(frame.Button);
				elseif (template == "WQT_SettingColorTemplate") then
					S:HandleButton(frame.Picker);
					S:HandleButton(frame.ResetButton);
				elseif (template == "WQT_SettingCheckboxTemplate") then
					S:HandleCheckBox(frame.CheckBox);
				elseif (template == "WQT_SettingSliderTemplate") then
					S:HandleStepSlider(frame.SliderWithSteppers, true);
					frame.SliderWithSteppers:SetHeight(30);
					frame.SliderWithSteppers:SetPoint("BOTTOMLEFT", 40, 0);
					S:HandleNextPrevButton(frame.SliderWithSteppers.Back, "left");
					S:HandleNextPrevButton(frame.SliderWithSteppers.Forward, "right");
					S:HandleEditBox(frame.TextBox);
				elseif (template == "WQT_SettingsQuestListPreviewTemplate") then
					frame.Background:Hide();
				elseif (template == "WQT_SettingCategoryTemplate") then
					frame:StripTextures();
					frame:CreateBackdrop("Transparent");
					frame.BGRight:SetAlpha(0);
					frame.backdrop:Point("TOPLEFT", 2, -1);
					frame.backdrop:Point("BOTTOMRIGHT", -2, 3);
					frame.hl = frame:CreateTexture(nil, "HIGHLIGHT");
					frame.hl:SetInside(frame.backdrop);
					frame.hl:SetBlendMode("ADD");
					frame.collapseTex = frame.backdrop:CreateTexture(nil, "OVERLAY");
					frame.collapseTex:Point("RIGHT", -10, 0);
					UpdateCategoryExpandedTexture(frame, data.data.expanded);
				elseif (template == "WQT_SettingSubCategoryTemplate") then
					local striptTextures = true;
					local createBackdrop = true;
					S:HandleButton(frame, striptTextures, nil, nil, createBackdrop);
					frame.backdrop:SetInside(frame, 30, 5);
				elseif (template == "WQT_SettingTextInputTemplate") then
					S:HandleEditBox(frame.TextBox);
					frame.TextBox:Point("BOTTOMLEFT", 44, 3);
					frame.TextBox:Point("RIGHT", -44, 0);
				elseif (template == "WQT_SettingSeparatorTemplate") then
					frame.Texture:SetVertexColor(0.75, 0.75, 0.75);
				end
			end

			local function OnInitializedSettingFrame(_, frame, data)
				local template = data.template;
				local r, g, b = unpack(E.media.rgbvaluecolor);
				if (frame.BgHighlight) then
					frame.BgHighlight:SetColorTexture(r, g, b);
				end
				if (frame.hl) then
					frame.hl:SetColorTexture(r, g, b, 0.25);
				end
				if (template == "WQT_SettingCategoryTemplate") then
					UpdateCategoryExpandedTexture(frame);
				end
			end

			local scrollBox = WQT_SettingsFrame.ScrollBox;
			scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, OnAcquiredSettingFrame);
			scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnInitializedSettingFrame);
		end

		do -- FullScreenContainer
			WQT_WorldMapContainer:StripTextures();
			WQT_WorldMapContainer:SetTemplate('Transparent');
		end
	end

	if (blizzardSkins.taxi) then
		do -- Flightmap
			local striptTextures = true;
			local createBackdrop = true;
			S:HandleButton(WQT_FlightMapContainerButton, striptTextures, nil, nil, createBackdrop);
			WQT_FlightMapContainerButton.backdrop:SetInside(WQT_FlightMapContainerButton, 2, 2);

			WQT_FlightMapContainerButton.Icon:SetAtlas("Worldquest-icon");
			WQT_FlightMapContainerButton.Arrow:SetAtlas("common-icon-forwardarrow");

			WQT_FlightMapContainer:StripTextures();
			WQT_FlightMapContainer:SetTemplate('Transparent');
		end
	end
end

local ElvUIExternal = CreateFromMixins(WQT_ExternalMixin);

function ElvUIExternal:GetName()
	return name;
end

function ElvUIExternal:Init()
	ApplySkin();
end

WQT:AddExternal(ElvUIExternal);
