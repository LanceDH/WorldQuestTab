WorldMapTabsLib by LanceDH
Source: https://github.com/LanceDH/WorldMapTabsLib

## Purpose
World Map Tabs Lib allows for multiple add-ons to share the tab space on the world map UI without worry about overlapping each other.
Additionally, it offers an easy way of setting up a tab that integrates with the official tabs.

## Notes
When creating or linking both a tab and content frame through the library the content frame will automatically be shown or hidden when your tab is active.
Both the tab and content frame will have an attribute called 'displayMode' which contains the ID for your tab and frame.
Registering a callback for "QuestLog.SetDisplayMode", you can compare your ID with the payload to determine if your tab was selected or not.
Alternatively, when using a custom Mixin you can react in your SetChecked function for true or false, and react accordingly.

When creating a tab from a template or providing a completely custom tab it is **required** to have a SetChecked function, even if it contains no functionality.
It is highly advised to inherit from "QuestLogTabButtonTemplate" for functionality and a similar appearance to the offical tabs.
This library contains a Mixin called WMTL_DefaultTabMixin which can be used with "QuestLogTabButtonTemplate" to provide support for textures, as well as not requiring an inactive variant of the active texure or atlas.


## Example setups
### Out of the box:
```lua
local tabLib = LibStub("WorldMapTabsLib-1.0");
local tabData = {
	tooltipText = "Test Tab";
	activeTexture = "Interface/ICONS/Spell_nature_polymorph";
}
local newTab = tabLib:CreateTab(tabData);
local contentFrame = tabLib:CreateContentFrameForTab(newTab);
contentFrame.tex = contentFrame:CreateTexture(nil, "ARTWORK")
contentFrame.tex:SetAllPoints(contentFrame)
contentFrame.tex:SetColorTexture(0, 1, 0);
```

### Using templates:
Note: The tab template needs to have a SetChecked(checked) function
```lua
local newTab = tabLib:CreateTab("XmlTabTemplate");
tabLib:CreateContentFrameForTab(newTab, "XmlFrameTemplate");
```

```xml
<Ui>
	<Frame name="XmlTabTemplate" parent="QuestMapFrame" inherits="QuestLogTabButtonTemplate" virtual="true">
		<KeyValues>
			<KeyValue key="activeAtlas" value="GM-icon-difficulty-mythicSelected" type="string" />
			<KeyValue key="inactiveAtlas" value="GM-icon-difficulty-mythicAssist" type="string" />
			<KeyValue key="tooltipText" value="Test Tab" type="string" />
		</KeyValues>
	</Frame>
	<Frame name="XmlFrameTemplate" parent="QuestMapFrame" setAllPoints="true" virtual="true">
		<Layers>
			<Layer level="BACKGROUND">
				<Texture>
					<Color r="0" g="0" b="1" />
				</Texture>
			</Layer>
		</Layers>
	</Frame>		
</Ui>
```

### Pre-made frames
Note: The tab needs to have a SetChecked(checked) function
```lua
local tabLib = LibStub("WorldMapTabsLib-1.0");
tabLib:AddCustomTab(XmlCreatedTab);
tabLib:LinkTabToContentFrame(XmlCreatedTab, XmlCreatedFrame);
```

```xml
<Ui>
	<Frame name="XmlCreatedTab" parent="QuestMapFrame" inherits="QuestLogTabButtonTemplate">
		<KeyValues>
			<KeyValue key="activeAtlas" value="GM-icon-difficulty-mythicSelected" type="string" />
			<KeyValue key="inactiveAtlas" value="GM-icon-difficulty-mythicAssist" type="string" />
			<KeyValue key="tooltipText" value="Test Tab" type="string" />
		</KeyValues>
	</Frame>
	<Frame name="XmlCreatedFrame" parent="QuestMapFrame" setAllPoints="true">
		<Layers>
			<Layer level="BACKGROUND">
				<Texture>
					<Color r="1" g="0" b="0" />
				</Texture>
			</Layer>
		</Layers>
	</Frame>			
</Ui>
```

## Documentation

### lib:CreateTab(data [, name])

Creates a tab and integrates it with the others.

#### Params:

**data:**
	Template name string to create a frame from. Or table containing data to create a default tab (see below).

**name:** (optional)
	Optional name for the tab that's about to be created. A fallback will be used otherwise. 

#### Retruns:

**tab:**
	Your newly created tab with a displayMode attribute containing your tab's ID

#### Notes:
When providing a template it is highly advised it inherits from "QuestLogTabButtonTemplate". The template **requires** a SetChecked function.

The data table can consist of the following fields. At a minimum the data should contain either activeAtlas or activeTexture.
- tooltipText: Text to show when hovering over the tab
- activeAtlas: Atlas name to show when the tab is active
- inactiveAtlas: Atlas name to show when the tab is inactive. If nil will use activeAtlas at lower opacity
- useAtlasSize: Use the size of the atlas. Otherwise it will be resized to 29x29 to fit the tab
- activeTexture: Texture name to show when the tab is active
- inactiveTexture: Texture name to show when the tab is inactive. If nil will use activeTexture at lower opacity

### lib:AddCustomTab(tab)

Integrates the provided tab with the others.
When creating your own tab it is highly advised it inherits from "QuestLogTabButtonTemplate". The frame **requires** a SetChecked function.

#### Params:

**tab:**
	An existing tab frame to be positioned with the other tabs. 

#### Returns:

**tab:**
	Your created tab with a displayMode attreibute containing your tab's ID


### lib:CreateContentFrameForTab(tab [, template [, name]])

Creates a content frame spanning the position of the quest log.
Links it to the provided tab so the content will be toggled depending on the tab state.

#### Params:

**tab:**
	Your tab created or added using the above functions, and provided with the displayMode attribute.

**template:** (optional)
	Optional template used to create your content frame. If nil, will create an empty frame.

**name:** (optional)
	Optional name for the content frame that's about to be created. A fallback will be used otherwise. 

#### Returns:

**contentFrame:**
	Your created content frame with a matching displayMode attribute.


### lib:LinkTabToContentFrame(tab, contentFrame)

Link a tab and a content frame to each other so the content will be toggled depending on the tab state.
You only need to use this if you want to link a custom made content frame that wasn't created using CreateContentFrameForTab.

#### Params:

**tab**
	Your tab created or added using the above functions, and provided with the displayMode attribute.

**contentFrame**
	Your custom content frame.

