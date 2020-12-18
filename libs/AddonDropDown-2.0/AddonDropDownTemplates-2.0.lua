local MAJOR, MINOR = "AddonDropDownTemplates-2.0", 2
local ADDT, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not ADDT then return end -- No Upgrade needed.

local PADDING_MENU = {["left"] = 15, ["top"] = 15, ["right"] = 15, ["bottom"] = 15};
local PADDING_LIST = {["left"] = 15, ["top"] = 15, ["right"] = 15, ["bottom"] = 15};
local AUTO_CLOSE_TIME = 2;

local ButtonInfo = {};

--[[
List of button attributes
marked with x is supported
======================================================
[x] info.text = [STRING]  --  The text of the button
[x] info.value = [ANYTHING]  --  The value that UIDROPDOWNMENU_MENU_VALUE is set to when the button is clicked
[x] info.func = [function(button, arg1, arg2, checked)]  --  The function that is called when you click the button
[x] info.checked = [nil, true, function]  --  Check the button if true or function returns true
[x] info.isNotRadio = [nil, true]  --  Check the button uses radial image if false check box image if true
[x] info.isTitle = [nil, true]  --  If it's a title the button is disabled and the font color is set to yellow
[x] info.disabled = [nil, true, function]  --  Disable the button and show an invisible button that still traps the mouseover event so menu doesn't time out
[x] info.tooltipWhileDisabled = [nil, 1] -- Show the tooltip, even when the button is disabled.
[x] info.hasArrow = [nil, true]  --  Show the expand arrow for multilevel menus
[ ] info.hasColorSwatch = [nil, true]  --  Show color swatch or not, for color selection
[ ] info.r = [1 - 255]  --  Red color value of the color swatch
[ ] info.g = [1 - 255]  --  Green color value of the color swatch
[ ] info.b = [1 - 255]  --  Blue color value of the color swatch
[ ] info.colorCode = [STRING] -- "|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
[ ] info.swatchFunc = [function()]  --  Function called by the color picker on color change
[ ] info.hasOpacity = [nil, 1]  --  Show the opacity slider on the colorpicker frame
[ ] info.opacity = [0.0 - 1.0]  --  Percentatge of the opacity, 1.0 is fully shown, 0 is transparent
[ ] info.opacityFunc = [function()]  --  Function called by the opacity slider when you change its value
[ ] info.cancelFunc = [function(previousValues)] -- Function called by the colorpicker when you click the cancel button (it takes the previous values as its argument)
[ ] info.notClickable = [nil, 1]  --  Disable the button and color the font white
[x] info.notCheckable = [nil, 1]  --  Shrink the size of the buttons and don't display a check box
[ ] info.owner = [Frame]  --  Dropdown frame that "owns" the current dropdownlist
[x] info.keepShownOnClick = [nil, 1]  --  Don't hide the dropdownlist after a button is clicked
[x] info.tooltipTitle = [nil, STRING] -- Title of the tooltip shown on mouseover
[x] info.tooltipText = [nil, STRING] -- Text of the tooltip shown on mouseover
[ ] info.tooltipOnButton = [nil, 1] -- Show the tooltip attached to the button instead of as a Newbie tooltip.
[ ] info.justifyH = [nil, "CENTER"] -- Justify button text
[x] info.arg1 = [ANYTHING] -- This is the first argument used by info.func
[x] info.arg2 = [ANYTHING] -- This is the second argument used by info.func
[ ] info.fontObject = [FONT] -- font object replacement for Normal and Highlight
[ ] info.menuTable = [TABLE] -- This contains an array of info tables to be displayed as a child menu
[ ] info.noClickSound = [nil, 1]  --  Set to 1 to suppress the sound when clicking the button. The sound only plays if .func is set.
[ ] info.padding = [nil, NUMBER] -- Number of pixels to pad the text on the right side
[ ] info.leftPadding = [nil, NUMBER] -- Number of pixels to pad the button on the left side
[ ] info.minWidth = [nil, NUMBER] -- Minimum width for this line
[ ] info.customFrame = frame -- Allows this button to be a completely custom frame, should inherit from UIDropDownCustomMenuEntryTemplate and override appropriate methods.
[ ] info.icon = [TEXTURE] -- An icon for the button.
[ ] info.mouseOverIcon = [TEXTURE] -- An override icon when a button is moused over.
[x] info.funcEnter = [function()] -- Function on enter button
[x] info.funcLeave = [function()] -- Function on leave button
[x] info.funcDisabled = [function()]  --  The function that is called when you click the button

]]

---------------------------------
--
--	Button Mixin
--
---------------------------------
-- SetupInfo(info)
-- GetDefaultSize()
-- UpdateCheckbox()
-- UpdateVisuals()
-- OnClick(button, down)
-- OnEnter()
-- OnLeave()
-- OnDisable()
-- OnEnable()

local ListButtonMixin = {};

function ListButtonMixin:SetupInfo(info)
	self.text:SetText(info.text);
	local width = self.text:GetStringWidth();
	
	self.text:SetPoint("RIGHT", self);
	if (info.notCheckable) then
		self.text:SetPoint("LEFT", self);
	else
		width = width + 20;
		self.text:SetPoint("LEFT", self, "LEFT",  20, 0);
	end
	
	-- Copy info over as the input table will be re-used for the next entry
	wipe(self.info);
	for k, v in pairs(info) do
		self.info[k] = info[k];
	end
	self:UpdateVisuals();

	self:SetWidth(width);
end

function ListButtonMixin:GetDefaultSize()
	local width = self.text:GetStringWidth();
	if (not self.info.notCheckable) then
		width = width + 40;
	else
		width = width + 10;
	end
	
	if ( self.info.hasArrow ) then
		width = width + 10;
	end
	return width, self:GetHeight(), not self.info.overflow;
end

function ListButtonMixin:UpdateCheckbox()
	self.checkIcon:SetShown(not self.info.notCheckable);
	
	if (not self.info.notCheckable) then
		local isChecked = self.info.checked;
		if (type(isChecked) == "function") then
			isChecked = isChecked();
		end
		local left = isChecked and 0 or 0.5;
		local top = self.info.isNotRadio and 0 or 0.5;
		self.checkIcon:SetTexCoord(left, left + 0.5, top, top + 0.5);
	end
	
	
end

function ListButtonMixin:UpdateVisuals()
	local textFont = GameFontHighlightSmallLeft;
	self:Enable();
	
	-- Update enabled
	local shouldDisable = self.info.disabled;
	if (type(shouldDisable) == "function") then
		shouldDisable = shouldDisable();
	end
	
	if (shouldDisable) then
		self:Disable();
		textFont = GameFontDisableSmallLeft;
	end

	self:UpdateCheckbox();
	
	if (self.info.isTitle) then
		self:Disable();
		textFont = GameFontNormalSmallLeft;
	end
	
	self.expandArrow:SetShown(self.info.hasArrow);
	
	self.text:SetFontObject(textFont);
end

function ListButtonMixin:OnClick(button, down)
	if (self.info.func and not self.info.hasArrow) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		local checked = self.info.checked;
		if ( type (checked) == "function" ) then
			checked = checked(self);
		end

		self.info.func(self, self.info.arg1, self.info.arg2, not checked);
		
		self:GetParent():Refresh();
	end
	
	if (not self.info.keepShownOnClick) then
		ADDT:ReleaseAllFrames();
	end
end

function ListButtonMixin:OnEnter()
	local parent = self:GetParent();
	parent:StopAutoCloseCount();

	parent:CloseChildren();

	if (self.info.isTitle) then
		return;
	elseif (self.info.tooltipFunc) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		self.info.tooltipFunc(GameTooltip);
		GameTooltip:Show();
	elseif ( self.info.tooltipTitle ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(self.info.tooltipTitle, 1.0, 1.0, 1.0);
		GameTooltip:AddLine(self.info.tooltipText, nil, nil, nil, true);
		GameTooltip:Show();
	elseif (self.info.hasArrow) then
		local newDropDown = ADDT:GetFrame(nil, "MENU", parent.initFunc, parent.level+1, self.info.value);
		newDropDown:SetPoint("TOPLEFT", self, "RIGHT", 0, 20);
		newDropDown:SetFrameLevel(self:GetFrameLevel()+2);
		newDropDown:Show();
		newDropDown:LinkParent(parent);
	end
		
	self.highlight:Show();
end

function ListButtonMixin:OnLeave()
	GameTooltip:Hide();

	self.highlight:Hide();
	
	local parent = self:GetParent();
	parent:StartAutoCloseCount();
end

function ListButtonMixin:OnDisable()
	self.checkIcon:SetDesaturated(true);
	self.checkIcon:SetAlpha(0.5);
	self.invisibleButton:Show();
end

function ListButtonMixin:OnEnable()
	self.checkIcon:SetDesaturated(false);
	self.checkIcon:SetAlpha(1);
	self.invisibleButton:Hide();
end

---------------------------------
--	Button pool
---------------------------------

local function buttonCreateFunc(pool, button)
	button:Hide();
	button:SetSize(100, 16);
	if (button.Text) then
		button.Text:SetText("");
	end

	if (button.expandArrow) then return; end
	
	Mixin(button, ListButtonMixin);
	
	button:SetNormalFontObject(GameFontHighlightSmallLeft);
	button:SetHighlightFontObject(GameFontHighlightSmallLeft);
	button:SetDisabledFontObject(GameFontDisableSmallLeft);
	
	-- parentExpandArrow
	local arrow = CreateFrame("BUTTON", nil, button);
	button.expandArrow = arrow;
	arrow:SetMotionScriptsWhileDisabled(true);
	arrow:Hide();
	arrow:SetSize(16, 16);
	arrow:SetPoint("RIGHT");
	
	arrow:SetScript("OnClick",  function(...) button:OnClick(...) end);
	arrow:SetScript("OnEnter",  function(...) button:OnEnter(...) end);
	arrow:SetScript("OnLeave",  function(...) button:OnLeave(...) end);
	
	arrow:SetNormalTexture("Interface/ChatFrame/ChatFrameExpandArrow");
	arrow.NormalTexture = arrow:GetNormalTexture();
	-- End of parentExpandArrow
	
	-- Check icon
	button.checkIcon = button:CreateTexture(nil, "ARTWORK");
	button.checkIcon:Show();
	button.checkIcon:SetSize(16, 16);
	button.checkIcon:SetPoint("LEFT", button);
	button.checkIcon:SetTexture("Interface/Common/UI-DropDownRadioChecks");
	button.checkIcon:SetTexCoord(0, 0.5, 0, 0.5);
	
	-- Custom Text
	button.text = button:CreateFontString(nil, "ARTWORK");
	button.text:SetPoint("LEFT", button);
	button.text:Show();
	button.text:SetFontObject(GameFontHighlightSmallLeft);
	
	-- Highlight
	button.highlight = button:CreateTexture(nil, "BACKGROUND");
	button.highlight:Hide();
	button.highlight:SetAllPoints();
	button.highlight:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight");
	button.highlight:SetBlendMode("ADD");
	
	--------------
	-- Scripts	--
	--------------
	button:SetScript("OnEnter", button.OnEnter);
	button:SetScript("OnLeave", button.OnLeave);
	button:SetScript("OnClick", button.OnClick);
	button:SetScript("OnDisable", button.OnDisable);
	button:SetScript("OnEnable", button.OnEnable);

	button.info = {};
	
	-- parentInvisibleButton
	local frame = CreateFrame("BUTTON", nil, button);
	button.invisibleButton = frame;
	frame:Hide();
	frame:RegisterForClicks("AnyUp")
	frame:SetAllPoints();

	frame:SetScript("OnEnter", function(self) 
			local parentButton = self:GetParent();
			local parentdd = parentButton:GetParent();
			parentdd:StopAutoCloseCount();
		
			parentdd:CloseChildren();
			
			if (parentButton.info.tooltipFunc) then
				GameTooltip:SetOwner(parentButton, "ANCHOR_RIGHT");
				parentButton.info.tooltipFunc(GameTooltip);
				GameTooltip:Show();
			elseif ( parentButton.info.tooltipTitle and parentButton.info.tooltipWhileDisabled) then
					GameTooltip:SetOwner(parentButton, "ANCHOR_RIGHT");
					GameTooltip:AddLine(parentButton.info.tooltipTitle, 1.0, 1.0, 1.0);
					GameTooltip:AddLine(parentButton.info.tooltipText, nil, nil, nil, true);
					GameTooltip:Show();
			end
		
			if (parentButton.info.funcEnter) then
				parentButton.info.funcEnter();
			end
		end);
	frame:SetScript("OnLeave", function(self) 
			local parentButton = self:GetParent();
			local parentdd = parentButton:GetParent();
			parentdd:StartAutoCloseCount();

			if (parentButton.info.funcLeave) then
				parentButton.info.funcLeave();
			end
			
			GameTooltip:Hide();
		end);
	frame:SetScript("OnClick", function(self, button, down) 
			local parentButton = self:GetParent();
			if (parentButton.info.funcDisabled) then
				parentButton.info:funcDisabled(button, down);
			end
		end);
		
end

local buttonPool = CreateFramePool("BUTTON", nil, nil, buttonCreateFunc);

function ADDT:GetButton(info)
	local button = buttonPool:Acquire();
	button:SetupInfo(info);
	return button
end

function ADDT:ReleaseButton(button)
	buttonPool:Release(button);
end

function ADDT:ReleaseAllButtons()
	buttonPool:ReleaseAll();
end

---------------------------------
--
--	Frame Mixin
--
---------------------------------
-- CreateButtonInfo([template])
-- Init(initFunc, level[, value])
-- AddButton(info)
-- Refresh([reconstruct])
-- Close()
-- SetMenuType([ddType])
-- UpdateHeight()
-- CloseChildren()
-- OnHide()
-- OnMouseUp(button)
-- OnUpdate(elapsed)
-- StartAutoCloseCount()
-- StopAutoCloseCount()
-- GetSourceParent()
-- LinkParent(parent)

local frameMixin = {};

function frameMixin:CreateButtonInfo(template)
	wipe(ButtonInfo)
	
	if (template) then
		if (template:lower() == "option") then
			ButtonInfo.notCheckable = true;
		elseif (template:lower() == "title") then
			ButtonInfo.notCheckable = true;
			ButtonInfo.isTitle = true;
		elseif (template:lower() == "checkbox") then
			ButtonInfo.keepShownOnClick = true;
			ButtonInfo.isNotRadio = true;
		elseif (template:lower() == "radio") then
			ButtonInfo.keepShownOnClick = true;
		elseif (template:lower() == "expand") then
			ButtonInfo.notCheckable = true;
			ButtonInfo.hasArrow = true;
			ButtonInfo.keepShownOnClick = true;
		elseif (template:lower() == "cancel") then
			ButtonInfo.notCheckable = true;
			ButtonInfo.text = CANCEL;
		end
	end

	return ButtonInfo;
end

function frameMixin:Init(initFunc, level, value)
	self.initFunc = initFunc;
	self.level = level;
	self.value = value;
	initFunc(self);
end

function frameMixin:AddButton(info)
	local button = ADDT:GetButton(info);
	
	local numButtons = #self.buttons
	button:SetParent(self);
	if (numButtons == 0) then
		button:SetPoint("TOPLEFT", self, self.padding.left, -self.padding.top);
	else
		local prevButton = self.buttons[numButtons];
		button:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT");
	end
	
	button:Show();
	tinsert(self.buttons, button);
	
	self:UpdateHeight();
end

function frameMixin:Refresh(reconstruct)
	if (reconstruct) then
		for k, button in ipairs(self.buttons) do
			ADDT:ReleaseButton(button);
		end
		wipe(self.buttons);
		self.initFunc(self);
		return;
	end

	for i = 1, #self.buttons do
		local button = self.buttons[i];
		button:UpdateVisuals();
	end
end

function frameMixin:Close()
	ADDT:ReleaseFrame(self);
end

function frameMixin:SetMenuType(ddType)
	if (ddType and ddType:lower() == "menu") then
		self.padding = PADDING_MENU;
		self:SetBackdrop( {
			["bgFile"] = "Interface/Tooltips/UI-Tooltip-Background", 
			["edgeFile"] = "Interface/Tooltips/UI-Tooltip-Border", ["tile"] = true, ["tileSize"] = 16, ["edgeSize"] = 16, 
			["insets"] = { ["left"] = 3, ["right"] = 3, ["top"] = 3, ["bottom"] = 3 }
		});
	else
		self.padding = PADDING_LIST;
		self:SetBackdrop( {
			["bgFile"] = "Interface/DialogFrame/UI-DialogBox-Background-Dark", 
			["edgeFile"] = "Interface/DialogFrame/UI-DialogBox-Border", ["tile"]  = true, ["tileSize"]  = 32, ["edgeSize"] = 32, 
			["insets"]  = { ["left"] = 11, ["right"] = 11, ["top"] = 11, ["bottom"] = 9 }
		});
	end
	
	self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
end

function frameMixin:UpdateHeight()
	local totalHeight = 0;
	local minWidth = 0;
	local needsArrowSpace = false;
	
	for k, button in ipairs(self.buttons) do
		local width, height, respectSize = button:GetDefaultSize();
		if (respectSize and width > minWidth) then
			minWidth = width;
		end
		totalHeight = totalHeight + height;
		needsArrowSpace = needsArrowSpace or button.info.hasArrow;
	end

	for k, button in ipairs(self.buttons) do
		local newWidth = minWidth;
		button:SetWidth(newWidth);
	end
	
	minWidth = minWidth + self.padding.left + self.padding.right;
	totalHeight = totalHeight + self.padding.top + self.padding.bottom;
	
	if (needsArrowSpace) then
		minWidth = minWidth - 5;
	end
	
	
	self:SetSize(minWidth, totalHeight);
	self:Show();
end

function frameMixin:CloseChildren()
	if (self.childFrame) then
		self.childFrame:CloseChildren();
		ADDT:ReleaseFrame(self.childFrame);
	end
end

function frameMixin:OnHide()
	self:CloseChildren();
end

function frameMixin:OnMouseUp(button)
	if (button == "LeftButton") then
		self:Close();
	end
end

function frameMixin:OnUpdate(elapsed)
	if (self.countAutoClose) then
		if (self.countDown > 0) then
			self.countDown = self.countDown - elapsed;
			if (self.countDown <= 0) then
				ADDT:ReleaseFrame(self);
			end
		end
	end
end

function frameMixin:StartAutoCloseCount()
	if (self.level > 1 ) then
		self.parentFrame:StartAutoCloseCount();
		return;
	end
	self.countAutoClose = true;
	self.countDown = AUTO_CLOSE_TIME;
end

function frameMixin:StopAutoCloseCount()
	if (self.level > 1 and self.parentFrame) then
		self.parentFrame:StopAutoCloseCount();
		return;
	end
	self.countAutoClose = false;
end

function frameMixin:GetSourceParent()
	if (self.level > 1 and self.parentFrame) then
		return self.parentFrame:GetSourceParent();
	end
	return self.sourceParent;
end

function frameMixin:LinkParent(parent)
	self.parentFrame = parent;
	parent.childFrame = self;
end

---------------------------------
--	Frame pool
---------------------------------

local function FrameCreateFunc(pool, frame)
	frame:Hide();

	frame:SetSize(100, 16);
	
	-- Clear active dropdown reference
	if (frame.level == 1) then
		frame.sourceParent.activeDropDown = nil;
	end
	
	frame.level = nil;
	frame.initFunc = nil;
	frame.level = nil;
	frame.countAutoClose = false;
	frame.childFrame = nil;
	frame.parentFrame = nil;
	frame.sourceParent = nil;
	frame:ClearAllPoints();
	
	
	if (not frame.buttons) then  
		frame.buttons = {};
		Mixin(frame, frameMixin);
		
		-- If frame gets hidden it's children should follow suit
		frame:SetScript("OnHide", frame.OnHide);
		frame:SetScript("OnUpdate", frame.OnUpdate);
		frame:SetScript("OnLeave", frame.StartAutoCloseCount);
		frame:SetScript("OnEnter", frame.StopAutoCloseCount);
		frame:SetScript("OnMouseUp", frame.OnMouseUp);
	else
		for k, button in ipairs(frame.buttons) do
			ADDT:ReleaseButton(button);
		end
		wipe(frame.buttons);
	end
end


local framePool = CreateFramePool("FRAME", nil, "BackdropTemplate", FrameCreateFunc);

function ADDT:GetNumActiveFrames()
	return framePool:GetNumActive();
end

function ADDT:GetFrame(parent, ddType, initFunc, level, value)
	local frame = framePool:Acquire();
	frame.sourceParent = parent;
	
	-- Cast some voodoo
	frame:SetFrameStrata("FULLSCREEN_DIALOG");
	frame:SetToplevel(true);
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
	frame:SetScale(uiScale);
	
	frame:SetMenuType(ddType);
	frame:Init(initFunc, level, value);

	return frame;
end

function ADDT:ReleaseFrame(frame)
	framePool:Release(frame);
end

function ADDT:ReleaseAllFrames()
	framePool:ReleaseAll();
end
