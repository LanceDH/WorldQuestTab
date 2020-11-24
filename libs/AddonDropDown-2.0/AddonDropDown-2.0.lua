local MAJOR, MINOR = "AddonDropDown-2.0", 1
local ADD, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not ADD then return end -- No Upgrade needed.

local ADDT = LibStub:GetLibrary("AddonDropDownTemplates-2.0")

function ADD:CloseAll()
	ADDT:ReleaseAllFrames();
end

function ADD:LinkDropDown(frame, ddFunc, anchorframe, anchorSource, x, y, displayType)
	displayType = displayType or "MENU";
	anchorframe = anchorframe or "TOPLEFT";
	anchorSource = anchorSource or "BOTTOMLEFT";
	x = x or 0;
	y = y or 0;
	

	local function OnClick() 
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		-- Toggle off
		if (frame.activeDropDown) then
			ADDT:ReleaseFrame(frame.activeDropDown);
			return;
		end
		
		-- Clear everything and start new
		ADDT:ReleaseAllFrames();

		local dd = ADDT:GetFrame(frame, displayType, ddFunc, 1);
		dd:SetPoint(anchorframe, frame, anchorSource, x, y);
		dd:Show();

		frame.activeDropDown = dd;
	end
	
	if (frame:GetScript("OnClick")) then
		frame:HookScript("OnClick", OnClick);
	else
		frame:SetScript("OnClick", OnClick);
	end
	
	
	local function OnHide() 
		if (frame.activeDropDown) then
			ADDT:ReleaseFrame(frame.activeDropDown);
			return;
		end
	end

	if (frame:GetScript("OnHide")) then
		frame:HookScript("OnHide", OnHide);
	else
		frame:SetScript("OnHide", OnHide);
	end

end

function ADD:CursorDropDown(parent, ddFunc, x, y)
	x = x or 0;
	y = y or 0;

	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	-- Toggle off
	if (parent.activeDropDown) then
		ADDT:ReleaseFrame(parent.activeDropDown);
		return;
	end
	
	ADDT:ReleaseAllFrames();
	local dd = ADDT:GetFrame(parent, "MENU", ddFunc, 1);

	local uiScale;
	local uiParentScale = UIParent:GetScale();
	if ( GetCVar("useUIScale") == "1" ) then
		uiScale = tonumber(GetCVar("uiscale"));
		if ( uiParentScale < uiScale ) then
			uiScale = uiParentScale;
		end
	else
		uiScale = uiParentScale;
	end
	local cursorX, cursorY = GetCursorPosition();
	cursorX = cursorX/uiScale;
	cursorY =  cursorY/uiScale;
	cursorX = cursorX + x;
	cursorY = cursorY + y;
	
	parent.activeDropDown = dd;
	
	dd:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", cursorX, cursorY);
	dd:Show();
end



local MenuButtonMixin = {};

function MenuButtonMixin:SetDisplayText(text)
	self.Text:SetText(text);
end

function ADD:CreateMenuTemplate(name, parent)
	local button = CreateFrame("BUTTON", name, parent);
	Mixin(button, MenuButtonMixin);
	
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
	fontString:SetPoint("LEFT", button.Left, "LEFT", 28, 2);
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
	
	button:SetScript("OnHide", function(self) ADD:CloseAll() end);
	
	button:SetScript("OnEnable", function(self) 
			button.Text:SetVertexColor(WHITE_FONT_COLOR:GetRGB());
			button.Button:Enable();
		end);
		
	button:SetScript("OnDisable", function(self) 
			button.Text:SetVertexColor(DISABLED_FONT_COLOR:GetRGB());
			button.Button:Disable();
		end);
		
	frame:SetScript("OnClick", function(self)
			button:Click();
		end);
	 
	return button;
end




