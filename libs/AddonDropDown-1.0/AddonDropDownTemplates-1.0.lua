local MAJOR, MINOR = "AddonDropDownTemplates-1.0", 8
local ADDT, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not ADDT then return end -- No Upgrade needed.

-- UIDropDownMenuButtonTemplate
function ADDT:CreateButtonTemplate(lib, name, parent, id)
	local button = CreateFrame("BUTTON", name, parent, "UIDropDownMenuButtonTemplate", id);
	button:SetSize(100, 16);
	
	--[[
	-- $parentHighlight
	local tex = button:CreateTexture(name .. "Highlight", "BACKGROUND");
	tex:SetAllPoints();
	tex:Hide();
	tex:SetTexture("Interface\QuestFrame\UI-QuestTitleHighlight");
	tex:SetBlendMode("ADD");
	
	-- $parentCheck
	tex = button:CreateTexture(name .. "Check", "ARTWORK");
	tex:SetTexture("Interface\Common\UI-DropDownRadioChecks");
	tex:SetSize(16, 16);
	tex:SetPoint("LEFT");
	tex:SetTexCoord(0, 0.5, 0.5, 1.0);
	
	-- $parentUnCheck
	tex = button:CreateTexture(name .. "UnCheck", "ARTWORK");
	tex:SetTexture("Interface\Common\UI-DropDownRadioChecks");
	tex:SetSize(16, 16);
	tex:SetPoint("LEFT");
	tex:SetTexCoord(0.5, 1, 0.5, 1);
	
	-- $parentIcon
	tex = button:CreateTexture(name .. "Icon", "ARTWORK");
	tex:Hide();
	tex:SetSize(16, 16);
	tex:SetPoint("RIGHT");
	
	]]--
	-- parentColorSwatch
	local frameCS = _G[name .. "ColorSwatch"] -- CreateFrame("BUTTON", name.."ColorSwatch", button);
	frameCS:Hide();
	frameCS:SetSize(16, 16);
	frameCS:SetPoint("RIGHT", -6, 0);
	
	-- parentSwatchBg
	local texSwatchBg = _G[name .. "ColorSwatchSwatchBg"] --frameCS:CreateTexture(name.."ColorSwatchSwatchBg", "BACKGROUND");
	texSwatchBg:SetSize(14, 14);
	texSwatchBg:SetPoint("CENTER");
	texSwatchBg:SetColorTexture(1, 1, 1);
	
	frameCS:SetScript("OnClick", function(self) 
		CloseMenus();
		lib:OpenColorPicker(self:GetParent());
	end);
	frameCS:SetScript("OnEnter", function(self) 
		lib:CloseDropDownMenus(self:GetParent():GetParent():GetID()+1);
		texSwatchBg:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		lib:StopCounting(self:GetParent():GetParent());
	end);
	frameCS:SetScript("OnLeave", function(self) 
		texSwatchBg:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
		lib:StartCounting(self:GetParent():GetParent());
	end);
	
	frameCS:SetNormalTexture("Interface/ChatFrame/ChatFrameColorSwatch");
	frameCS.NormalTexture = frameCS:GetNormalTexture();
	-- End of parentColorSwatch
	
	-- parentExpandArrow
	local frame = _G[name .. "ExpandArrow"] -- CreateFrame("BUTTON", name.."ExpandArrow", button);
	button.expandArrow = frame;
	frame:SetMotionScriptsWhileDisabled(true);
	frame:Hide();
	frame:SetSize(16, 16);
	frame:SetPoint("RIGHT");
	
	frame:SetScript("OnClick", function(self) 
		lib:ToggleDropDownMenu(self:GetParent():GetParent():GetID() + 1, self:GetParent().value, nil, nil, nil, nil, self:GetParent().menuList, self);
	end);
	frame:SetScript("OnEnter", function(self) 
		local level = self:GetParent():GetParent():GetID() + 1;
		lib:CloseDropDownMenus(level);
		
		if (self:IsEnabled()) then
			local listFrame = _G["ADD_DropDownList" .. level];
			if (not listFrame or not listFrame:IsShown() or select(2, listFrame:GetPoint()) ~= self) then
				lib:ToggleDropDownMenu(level, self:GetParent().value, nil, nil, nil, nil, self:GetParent().menuList, self);
			end
		end
		
		lib:StopCounting(self:GetParent():GetParent());
	end);
	frame:SetScript("OnLeave", function(self) 
		lib:StartCounting(self:GetParent():GetParent());
	end);
	
	frame:SetNormalTexture("Interface/ChatFrame/ChatFrameExpandArrow");
	frame.NormalTexture = frame:GetNormalTexture();
	-- End of parentExpandArrow
	
	-- parentInvisibleButton
	local frame = _G[name .. "InvisibleButton"] --CreateFrame("BUTTON", name.."InvisibleButton", button);
	button.invisibleButton = frame;
	frame:Hide();
	frame:RegisterForClicks("AnyUp")
	frame:SetPoint("TOPLEFT");
	frame:SetPoint("BOTTOMRIGHT");
	frame:SetPoint("RIGHT", frameCS, "LEFT");
	
	frame:SetScript("OnEnter", function(self) 
			lib:StopCounting(self:GetParent():GetParent());
			lib:CloseDropDownMenus(self:GetParent():GetParent():GetID() + 1);
			
			local parent = self:GetParent();
			if ( parent.tooltipTitle and parent.tooltipWhileDisabled) then
				if ( parent.tooltipOnButton ) then
					GameTooltip:SetOwner(parent, "ANCHOR_RIGHT");
					GameTooltip:AddLine(parent.tooltipTitle, 1.0, 1.0, 1.0);
					GameTooltip:AddLine(parent.tooltipText, nil, nil, nil, true);
					GameTooltip:Show();
				else
					GameTooltip_AddNewbieTip(parent, parent.tooltipTitle, 1.0, 1.0, 1.0, parent.tooltipText, 1);
				end
			end
		
			if (parent.funcEnter) then
				parent.funcEnter();
			end
		end);
	frame:SetScript("OnLeave", function(self) 
			lib:StartCounting(self:GetParent():GetParent());
			GameTooltip:Hide();
			
			local parent = self:GetParent();
			if (parent.funcLeave) then
				parent.funcLeave();
			end
		end);
	frame:SetScript("OnClick", function(self, button, down) 
			local parent = self:GetParent();
			if (parent.funcDisabled) then
				parent:funcDisabled(button, down);
			end
		end);
	-- End of parentInvisibleButton
	
	button:SetScript("OnLoad", function(self) 
			self:SetFrameLevel(self:GetParent():GetFrameLevel()+2);
		end);
		
	button:SetScript("OnClick", function(self, button, down) 
			lib:OnClick(self, button, down);
		end);
		
	button:SetScript("OnEnter", function(self, ...) 
			if ( self.hasArrow ) then
				local level =  self:GetParent():GetID() + 1;
				local listFrame = _G["ADD_DropDownList"..level];
				if ( not listFrame or not listFrame:IsShown() or select(2, listFrame:GetPoint()) ~= self ) then
					lib:ToggleDropDownMenu(level, self.value, nil, nil, nil, nil, self.menuList, self.expandArrow);
				end
			else
				lib:CloseDropDownMenus(self:GetParent():GetID() + 1);
			end
			_G[self:GetName().."Highlight"]:Show();
			lib:StopCounting(self:GetParent());
			if ( self.tooltipTitle ) then
				if ( self.tooltipOnButton ) then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
					GameTooltip:AddLine(self.tooltipTitle, 1.0, 1.0, 1.0);
					GameTooltip:AddLine(self.tooltipText, nil, nil, nil, true);
					GameTooltip:Show();
				else
					GameTooltip_AddNewbieTip(self, self.tooltipTitle, 1.0, 1.0, 1.0, self.tooltipText, 1);
				end
			end
			
			if ( self.mouseOverIcon ~= nil ) then
				self.Icon:SetTexture(self.mouseOverIcon);
				self.Icon:Show();
			end
			
			if (self.funcEnter) then
				self.funcEnter();
			end
		end);
		
	button:SetScript("OnLeave", function(self) 
			_G[self:GetName().."Highlight"]:Hide();
			lib:StartCounting(self:GetParent());
			GameTooltip:Hide();
			
			if ( self.mouseOverIcon ~= nil ) then
				if ( self.icon ~= nil ) then
					self.Icon:SetTexture(self.icon);
				else
					self.Icon:Hide();
				end
			end
			
			if (self.funcLeave) then
				self.funcLeave();
			end
		end);
		
	button:SetScript("OnEnable", function(self) 
			self.invisibleButton:Hide();
		end);
		
	button:SetScript("OnDisable", function(self) 
			self.invisibleButton:Show();
		end);
	
	button:SetNormalFontObject(GameFontHighlightSmallLeft);
	button:SetHighlightFontObject(GameFontHighlightSmallLeft);
	button:SetDisabledFontObject(GameFontDisableSmallLeft);
	
	return button;
end

-- UIDropDownListTemplate
function ADDT:CreateListTemplate(lib, name, id)
	local button = CreateFrame("BUTTON", name, nil, nil, id);
	button:Hide();
	
	-- Backdrop
	local temp = CreateFrame("Frame", name.."Backdrop", button);
	temp:SetAllPoints();
	temp:SetBackdrop( {
		["bgFile"] = "Interface/DialogFrame/UI-DialogBox-Background-Dark", 
		["edgeFile"] = "Interface/DialogFrame/UI-DialogBox-Border", ["tile"]  = true, ["tileSize"]  = 32, ["edgeSize"] = 32, 
		["insets"]  = { ["left"] = 11, ["right"] = 11, ["top"] = 11, ["bottom"] = 9 }
	});
	-- MenuBackdrop
	temp = CreateFrame("Frame", name.."MenuBackdrop", button);
	temp:SetAllPoints();
	temp:SetBackdrop( {
		["bgFile"] = "Interface/Tooltips/UI-Tooltip-Background", 
		["edgeFile"] = "Interface/Tooltips/UI-Tooltip-Border", ["tile"] = true, ["tileSize"] = 16, ["edgeSize"] = 16, 
		["insets"] = { ["left"] = 4, ["right"] = 4, ["top"] = 4, ["bottom"] = 4 }
	});
	
	temp:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	temp:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
	
	-- Menu buttons
	for i = 1, 8 do
		self:CreateButtonTemplate(lib, name .. "Button" .. i, button, i)
	end
	
	-- Scripts
	button:SetScript("OnClick", function(self) self:Hide() end);
	button:SetScript("OnEnter", function(self, motion) lib:StopCounting(self, motion) end);
	button:SetScript("OnLeave", function(self, motion) lib:StartCounting(self, motion) end);
	button:SetScript("OnUpdate", function(self, elapsed) lib:OnUpdate(self, elapsed) end);
	button:SetScript("OnShow", function(self) 
			for i=1, lib.MAXBUTTONS do
					if (not self.noResize) then
						_G[self:GetName().."Button"..i]:SetWidth(self.maxWidth);
					end
				end
				if (not self.noResize) then
					self:SetWidth(self.maxWidth+25);
				end
				self.showTimer = nil;
				if ( self:GetID() > 1 ) then
					self.parent = _G["ADD_DropDownList"..(self:GetID() - 1)];
			end
		end);
	button:SetScript("OnHide", function(self) lib:OnHide(self) end);
	
	return button;
end

function ADDT:CreateMenuTemplate(lib, name, parent, id, frameType)
	frameType = frameType or "FRAME";
	local button = CreateFrame(frameType, name, parent, nil, id);
	button:SetSize(40, 32);
	
	-- parentLeft
	local tex = button:CreateTexture(nil, "ARTWORK");
	button.Left = tex;
	tex:SetTexture("Interface/Glues/CharacterCreate/CharacterCreate-LabelFrame");
	tex:SetSize(25, 64);
	tex:SetPoint("TOPLEFT", -15, 17);
	tex:SetTexCoord(0, 0.1953125, 0, 1);
	
	-- parentRight
	tex = button:CreateTexture(nil, "ARTWORK");
	button.Right = tex;
	tex:SetTexture("Interface/Glues/CharacterCreate/CharacterCreate-LabelFrame");
	tex:SetSize(25, 64);
	tex:SetPoint("TOPRIGHT", 15, 17);
	tex:SetTexCoord(0.8046875, 1, 0, 1);
	
	-- parentMiddle
	tex = button:CreateTexture(nil, "ARTWORK");
	button.Middle = tex;
	tex:SetTexture("Interface/Glues/CharacterCreate/CharacterCreate-LabelFrame");
	tex:SetPoint("TOPLEFT", button.Left, "TOPRIGHT");
	tex:SetPoint("BOTTOMRIGHT", button.Right, "BOTTOMLEFT");
	tex:SetTexCoord(0.1953125, 0.8046875, 0, 1);
	
	--parentText
	local fontString = button:CreateFontString(nil, "ARTWORK");
	button.Text = fontString;
	fontString:SetFontObject(GameFontHighlightSmall);
	fontString:SetNonSpaceWrap(false);
	fontString:SetJustifyH("RIGHT");
	fontString:SetSize(0, 10);
	fontString:SetPoint("RIGHT", button.Right, "RIGHT", -43, 2);
	--parentIcon
	tex = button:CreateTexture(nil, "OVERLAY");
	button.Icon = tex;
	tex:Hide();
	tex:SetSize(16, 16);
	tex:SetPoint("LEFT", 30, 2);
	
	-- parentButton
	local frame = CreateFrame("BUTTON", nil, button);
	button.Button = frame;
	frame:SetMotionScriptsWhileDisabled(true);
	frame:SetSize(24, 24);
	frame:SetPoint("TOPRIGHT", button.Right, "TOPRIGHT", -16, -18);
	
	frame:SetScript("OnEnter", function(self)
			local parent = self:GetParent();
			local myscript = parent:GetScript("OnEnter");
			if(myscript ~= nil) then
				myscript(parent);
			end
		end);
	frame:SetScript("OnLeave", function(self)
			local parent = self:GetParent();
			local myscript = parent:GetScript("OnLeave");
			if(myscript ~= nil) then
				myscript(parent);
			end
		end);
		
	frame:SetScript("OnClick", function(self)
			lib:ToggleDropDownMenu(nil, nil, self:GetParent());
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		end);
		
	frame:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up");
	frame.NormalTexture = frame:GetNormalTexture();
	frame.NormalTexture:SetSize(24, 24);
	frame.NormalTexture:SetPoint("RIGHT");
	
	frame:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down");
	frame.PushedTexture  = frame:GetPushedTexture();
	frame.PushedTexture :SetSize(24, 24);
	frame.PushedTexture :SetPoint("RIGHT");
	
	frame:SetDisabledTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Disabled");
	frame.DisabledTexture  = frame:GetDisabledTexture();
	frame.DisabledTexture :SetSize(24, 24);
	frame.DisabledTexture :SetPoint("RIGHT");
	
	frame:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight");
	frame.HighlightTexture  = frame:GetHighlightTexture();
	frame.HighlightTexture :SetSize(24, 24);
	frame.HighlightTexture :SetPoint("RIGHT");
	-- End of parentButton
	
	button:SetScript("OnHide", function(self) lib:CloseDropDownMenus(); end);
	
	button:SetScript("OnEnable", function(self) 
			button.Text:SetVertexColor(WHITE_FONT_COLOR:GetRGB());
			button.Button:Enable();
		end);
		
	button:SetScript("OnDisable", function(self) 
			button.Text:SetVertexColor(DISABLED_FONT_COLOR:GetRGB());
			button.Button:Disable();
		end);
	 
	return button;
end







