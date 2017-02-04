local addonName, addon = ...

local L = {}
local locale = GetLocale();

L["EMPOWERING"]		= "Empowering";
L["QUESTLOG"]		= "Questlog";
L["WORLDQUEST"]		= "World Quests"
L["COMBATLOCK"]		= "Disabled during combat.";
L["FILTER"] 		= "Filter: %s";
L["OPTIONS_INFO"] 	= "[WQT] Options can be found under the filter button."
L["NO_FACTION"] 	= "No Faction";
L["OTHER_FACTION"] 	= "Other";
L["TIME"]			= "Time";
L["FACTION"]		= "Faction";
L["TYPE"]			= "Type";
L["ZONE"]			= "Zone";
L["NAME"]			= "Name";
L["REWARD"]			= "Reward";
L["SETTINGS"]		= "Settings";
L["DEFAULT_TAB"]	= "Default Tab";
L["DEFAULT_TAB_TT"]	= "Set WQT as the default tab when you log in.\nDoes not apply to characters below lvl 110.";
L["SAVE_SETTINGS"]	= "Save Filters/Sort";
L["SAVE_SETTINGS_TT"]	= "Save filter and sort settings\nbetween sessions and reloads."
L["PIN_DISABLE"]	= "Disable pin changes";
L["PIN_DISABLE_TT"]	= "Prevent WQT from making changes to map pins.";
L["FILTER_PINS"]	= "Filter map pins";
L["FILTER_PINS_TT"]	= "Applies filters to\npins on the map.";
L["PIN_REWARDS"]	= "Map pin rewards";
L["PIN_REWARDS_TT"]	= "Show quest reward icons on map pins.";
L["PIN_COLOR"]		= "Map pin color ring";
L["PIN_COLOR_TT"]	= "Show a colored ring around pins\ndepending on reward type.";
L["PIN_TIME"]		= "Map pin time";
L["PIN_TIME_TT"]	= "Add time left to map pins.";
L["PIN_BIGGER"]		= "Bigger map pins";
L["PIN_BIGGER_TT"]	= "Slightly increase map pin size for visability.\nOnly available with Map pin rewards enabled";
L["SHOW_TYPE"]		= "Show Type";
L["SHOW_TYPE_TT"]	= "Show type icon\nin the quest list.";
L["SHOW_FACTION"]	= "Show Faction";
L["SHOW_FACTION_TT"]	= "Show faction icon\nin the quest list.";

L["TYPE_DEFAULT"]	= "Default";
L["TYPE_ELITE"]		= "Elite";
L["TYPE_PVP"]		= "PvP";
L["TYPE_PETBATTLE"]	= "Petbattle";
L["TYPE_DUNGEON"]	= "Dungeon";
L["TYPE_RAID"]		= "Raid";
L["TYPE_PROFESSION"]	= "Profession";
L["TYPE_INVASION"]	= "Invasion";
L["TYPE_EMISSARY"]	= "Emissary";

L["REWARD_ITEM"]	= "Item";
L["REWARD_ARMOR"]	= "Armor";
L["REWARD_GOLD"]	= "Gold";
L["REWARD_RESOURCES"]	= "Resources";
L["REWARD_ARTIFACT"]	= "Artifact";
L["REWARD_RELIC"]	= "Relic";

if locale == "deDE" then
L["COMBATLOCK"] = "Nicht verfügbar während eines Kampfes."
L["DEFAULT_TAB"] = "Standardtab"
L["DEFAULT_TAB_TT"] = [=[Aktiviert WQT als Standardtab nach dem Einloggen.
Nicht aktiv für Charaktere unter Level 110.]=]
L["EMPOWERING"] = "Macht verleihen"
L["FACTION"] = "Fraktion"
L["FILTERS"] = "Filter: %s"
L["NAME"] = "Name"
L["NO_FACTION"] = "Keine Fraktion"
L["OTHER_FACTION"] = "Sonstige"
L["PIN_BIGGER"] = "Größere Kartenpins"
L["PIN_COLOR_TT"] = "Zeigt einen farbigen Ring um Pins abhängig von der Art der Belohnung."
L["PIN_REWARDS_TT"] = "Zeige Quest Belohnung auf Kartenpins an. "
L["PIN_TIME_TT"] = "Zeigt die verbleibende Zeit auf Kartenpins an."
L["QUESTLOG"] = "Questlog"
L["REWARD"] = "Belohnung"
L["REWARD_ARMOR"] = "Rüstung"
L["REWARD_ARTIFACT"] = "Artifakt"
L["REWARD_GOLD"] = "Gold"
L["REWARD_ITEM"] = "Gegenstand"
L["REWARD_RELIC"] = "Relikt"
L["REWARD_RESOURCES"] = "Ressourcen"
L["SAVE_SETTINGS"] = "Speichere Filter/Sortierung"
L["SAVE_SETTINGS_TT"] = [=[Speichere Filter- und Sortierungseinstellungen
sitzungs- und reloadübergreifend]=]
L["SETTINGS"] = "Einstellungen"
L["SHOW_FACTION"] = "Zeige Fraktion"
L["SHOW_FACTION_TT"] = "Zeige Fraktionsicon in der Questliste."
L["TIME"] = "Zeit"
L["TYPE_DEFAULT"] = "Standard"
L["TYPE_ELITE"] = "Elite"
L["TYPE_INVASION"] = "Invasion"
L["TYPE_PETBATTLE"] = "Haustierkampf"
L["TYPE_PROFESSION"] = "Beruf"
L["TYPE_PVP"] = "PvP"
L["TYPE_RAID"] = "Schlachtzug"
L["WORLDQUEST"] = "Weltquests"
L["ZONE"] = "Zone"
end

if locale == "esES" or locale == "esMX" then
L["EMPOWERING"]		= "Potenciando";
end

if locale == "ptBR" then
L["EMPOWERING"]		= "Fortalecendo";
end

if locale == "frFR" then
L["COMBATLOCK"] = "Désactivé en combat."
L["DEFAULT_TAB"] = "Onglet par défaut"
L["DEFAULT_TAB_TT"] = [=[Définir WQT comme onglet par défaut quand vous vous connectez.
Ne s'applique pas en dessous du niveau 110.]=]
L["EMPOWERING"] = "Renforcement"
L["FACTION"] = "Faction"
L["FILTERS"] = "Filtres : %s"
L["NAME"] = "Nom"
L["NO_FACTION"] = "Sans faction"
L["OPTIONS_INFO"] = "[WQT] Les paramètres peuvent être trouvés dans le bouton filtre."
L["OTHER_FACTION"] = "Autre"
L["PIN_TIME_TT"] = "Ajouter le temps restant sur les points de la carte."
L["QUESTLOG"] = "Journal de quêtes"
L["REWARD"] = "Récompense"
L["REWARD_ARMOR"] = "Équipement"
L["REWARD_ARTIFACT"] = "Puissance prodigieuse"
L["REWARD_GOLD"] = "Or"
L["REWARD_ITEM"] = "Objet"
L["REWARD_RELIC"] = "Relique"
L["REWARD_RESOURCES"] = "Ressources de domaine"
L["SAVE_SETTINGS"] = "Sauvegarder Filtres/Tri"
L["SAVE_SETTINGS_TT"] = "Sauvegarder les paramètres des filtres et du tri entre les sessions de jeu et les rechargements"
L["SETTINGS"] = "Paramètres"
L["SHOW_FACTION"] = "Montrer la faction"
L["SHOW_FACTION_TT"] = "Afficher l'icône de la faction dans la liste de quête."
L["SHOW_TYPE"] = "Montrer le type"
L["SHOW_TYPE_TT"] = "Montrer l'icône de type dans la liste des Expéditions."
L["TIME"] = "Temps"
L["TYPE"] = "Type"
L["TYPE_DEFAULT"] = "Défaut"
L["TYPE_DUNGEON"] = "Donjon"
L["TYPE_ELITE"] = "Élite"
L["TYPE_EMISSARY"] = "Émissaire"
L["TYPE_INVASION"] = "Invasion"
L["TYPE_PETBATTLE"] = "Combat de mascottes"
L["TYPE_PROFESSION"] = "Métier"
L["TYPE_PVP"] = "PvP"
L["TYPE_RAID"] = "Raid"
L["WORLDQUEST"] = "Expéditions"
L["ZONE"] = "Zone"

end

if locale == "itIT" then
L["EMPOWERING"]		= "Potenziamento";
end

if locale == "ruRU" then
L["COMBATLOCK"] = "Отключено во время боя."
L["DEFAULT_TAB"] = "По умолчанию"
L["DEFAULT_TAB_TT"] = [=[Установить WQT как панель по умолчанию.
Не применяется к персонажам ниже 110 уровня.]=]
L["EMPOWERING"] = "Усиление"
L["FACTION"] = "Фракция"
L["FILTER_PINS"] = "Фильтр меток"
L["FILTER_PINS_TT"] = "Применить фильтры к меткaм на карте"
L["FILTERS"] = "Фильтры: %s"
L["NAME"] = "Назвaние"
L["NO_FACTION"] = "Без фрaкции"
L["OPTIONS_INFO"] = "[WQT] Опции нaходятся под кнопкой фильтров."
L["OTHER_FACTION"] = "Другиe"
L["PIN_BIGGER"] = "Большиe метки"
L["PIN_BIGGER_TT"] = [=[Слегка увеличить метки на кaрте. 
Доступно только при включенных метках на карте.]=]
L["PIN_COLOR"] = "Цвет метки"
L["PIN_COLOR_TT"] = "Показать цветное кольцо вокруг метки в зависимости от типа награды."
L["PIN_REWARDS"] = "Нагрaды на метках"
L["PIN_REWARDS_TT"] = "Показать награды на метках"
L["PIN_TIME"] = "Время на метках"
L["PIN_TIME_TT"] = "Добавить оставшееся время к меткам на карте"
L["QUESTLOG"] = "Журнал заданий"
L["REWARD"] = "Наградa"
L["REWARD_ARMOR"] = "Броня"
L["REWARD_ARTIFACT"] = "Артефакт"
L["REWARD_GOLD"] = "Золото"
L["REWARD_ITEM"] = "Предметы"
L["REWARD_RELIC"] = "Реликвия"
L["REWARD_RESOURCES"] = "Ресурсы оплота"
L["SAVE_SETTINGS"] = "Сохранить фильтры"
L["SAVE_SETTINGS_TT"] = [=[Сохранить настройки фильтров между 
игровыми сессиями и перезагрузками.]=]
L["SETTINGS"] = "Настройки"
L["SHOW_FACTION"] = "Показать фракцию"
L["SHOW_FACTION_TT"] = [=[Показать иконку фракции
в панели задач.]=]
L["SHOW_TYPE"] = "Показaть тип"
L["SHOW_TYPE_TT"] = "Показать тип иконки в журнале заданий."
L["TIME"] = "Время"
L["TYPE"] = "Тип"
L["TYPE_DEFAULT"] = "По умолчанию"
L["TYPE_DUNGEON"] = "Подземелья"
L["TYPE_ELITE"] = "Элитные"
L["TYPE_EMISSARY"] = "Посланник"
L["TYPE_INVASION"] = "Вторжение"
L["TYPE_PETBATTLE"] = "Бои питомцев"
L["TYPE_PROFESSION"] = "Профессия"
L["TYPE_PVP"] = "ПвП"
L["TYPE_RAID"] = "Рейд"
L["WORLDQUEST"] = "Мировые квесты"
L["ZONE"] = "Зона"
end

if locale == "zhCN" then
L["COMBATLOCK"] = "战斗中无法使用"
L["DEFAULT_TAB"] = "默认选项卡"
L["DEFAULT_TAB_TT"] = [=[设置WQT作为你登录后的默认选项卡。
不会对110级以下的角色生效。]=]
L["EMPOWERING"] = "强化"
L["FACTION"] = "阵营"
L["FILTER_PINS"] = "过滤地图显示"
L["FILTER_PINS_TT"] = "在地图上显示过滤后的任务信息。"
L["FILTERS"] = "过滤：%s"
L["NAME"] = "名称"
L["NO_FACTION"] = "无阵营"
L["OPTIONS_INFO"] = "[WQT] 配置选项可以在过滤器菜单中找到。"
L["OTHER_FACTION"] = "其他"
L["PIN_BIGGER"] = "大图标"
L["PIN_BIGGER_TT"] = [=[略微的增加图标的尺寸。
只有勾选地图显示奖励时才会生效。]=]
L["PIN_COLOR"] = "地图显示边框"
L["PIN_COLOR_TT"] = "根据奖励类型在图标周围显示彩色边框。"
L["PIN_REWARDS"] = "在地图上显示奖励图标"
L["PIN_REWARDS_TT"] = "在地图上显示奖励图标。"
L["PIN_TIME"] = "在地图上显示剩余时间"
L["PIN_TIME_TT"] = "在地图上显示任务剩余时间。"
L["QUESTLOG"] = "任务日志"
L["REWARD"] = "奖励"
L["REWARD_ARMOR"] = "装备"
L["REWARD_ARTIFACT"] = "能量"
L["REWARD_GOLD"] = "金币"
L["REWARD_ITEM"] = "物品"
L["REWARD_RELIC"] = "圣物"
L["REWARD_RESOURCES"] = "资源"
L["SAVE_SETTINGS"] = "保存过滤/排序"
L["SAVE_SETTINGS_TT"] = "保存过滤与排序设置。"
L["SETTINGS"] = "设置"
L["SHOW_FACTION"] = "显示阵营"
L["SHOW_FACTION_TT"] = "在任务列表显示任务阵营图标。"
L["SHOW_TYPE"] = "显示类型"
L["SHOW_TYPE_TT"] = "在任务列表显示任务类型图标。"
L["TIME"] = "时间"
L["TYPE"] = "类型"
L["TYPE_DEFAULT"] = "默认"
L["TYPE_DUNGEON"] = "地下城"
L["TYPE_ELITE"] = "精英"
L["TYPE_EMISSARY"] = "使者"
L["TYPE_PETBATTLE"] = "宠物对战"
L["TYPE_PROFESSION"] = "专业"
L["TYPE_PVP"] = "PvP"
L["WORLDQUEST"] = "世界任务"
L["ZONE"] = "区域"
end

if locale == "zhTW" then
L["COMBATLOCK"] = "戰鬥中無法使用"
L["DEFAULT_TAB"] = "預設標籤"
L["DEFAULT_TAB_TT"] = [=[將WQT設定為預設啟用標籤。
這不適用於等級110以下角色。]=]
L["EMPOWERING"] = "强化"
L["FACTION"] = "陣營"
L["FILTER_PINS"] = "過濾地圖顯示"
L["FILTERS"] = "過濾: %s"
L["NAME"] = "名稱"
L["NO_FACTION"] = "無陣營"
L["OPTIONS_INFO"] = "[WQT]設定選項可以在過濾按鍵下找到"
L["OTHER_FACTION"] = "其它"
L["PIN_BIGGER"] = "地圖上顯示大型圖示"
L["PIN_BIGGER_TT"] = [=[增加地圖示大小以提高可見性
僅於啟用地圖上顯示獎勵圖示時有效]=]
L["PIN_COLOR"] = "依獎勵著色圖示週邊"
L["PIN_COLOR_TT"] = "根據獎勵類型在圖示周圍著色顯示"
L["PIN_REWARDS"] = "地圖上顯示獎勵圖示"
L["PIN_REWARDS_TT"] = "在圖示上顯示任務獎勵圖示"
L["PIN_TIME"] = "地圖上顯示剩餘時間"
L["PIN_TIME_TT"] = "在圖示上加入任務剩餘時間"
L["QUESTLOG"] = "任務日誌"
L["REWARD"] = "獎勵"
L["REWARD_ARMOR"] = "護甲"
L["REWARD_ARTIFACT"] = "神兵之力"
L["REWARD_GOLD"] = "金錢"
L["REWARD_ITEM"] = "物品"
L["REWARD_RELIC"] = "聖物"
L["REWARD_RESOURCES"] = "大廳資源"
L["SAVE_SETTINGS"] = "儲存過濾/排序"
L["SETTINGS"] = "設定"
L["SHOW_FACTION"] = "顯示陣營"
L["SHOW_FACTION_TT"] = "在任務清單顯示陣營圖示"
L["SHOW_TYPE"] = "顯示類型"
L["SHOW_TYPE_TT"] = "在任務清單顯示類型圖示"
L["TIME"] = "時間"
L["TYPE"] = "類型"
L["TYPE_DEFAULT"] = "預設"
L["TYPE_DUNGEON"] = "地域"
L["TYPE_ELITE"] = "精英"
L["TYPE_EMISSARY"] = "特使任務"
L["TYPE_INVASION"] = "入侵"
L["TYPE_PETBATTLE"] = "寵物戰鬥"
L["TYPE_PROFESSION"] = "專業"
L["TYPE_PVP"] = "PvP"
L["TYPE_RAID"] = "團隊"
L["WORLDQUEST"] = "世界任務"
L["ZONE"] = "地區"
end

if locale == "koKO" then
L["EMPOWERING"]		= "강화";
end

addon.L = L;