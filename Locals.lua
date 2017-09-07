local addonName, addon = ...

local L = {}
local locale = GetLocale();

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
L["PRECISE_FILTER"]	= "Precise Filter";
L["PRECISE_FILTER_TT"]	= "Filtering only shows quests matching\nall filter categories, rather than just\nany of the categories.";

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
L["REWARD_RESOURCES"]	= "Currency";
L["REWARD_ARTIFACT"]	= "Artifact";
L["REWARD_RELIC"]	= "Relic";
L["REWARD_NONE"]		= "None";
L["REWARD_EXPERIENCE"]	= "Experience";
L["REWARD_HONOR"]	=	"Honor";

L["TRACKDD_TOMTOM"]	= "TomTom add"
L["TRACKDD_TOMTOM_REMOVE"]	= "TomTom remove"
L["NUMBERS_FIRST"]	= "%gk"
L["NUMBERS_SECOND"]	= "%gm"
L["NUMBERS_THIRD"]	= "%gb"
L["IS_AZIAN_CLIENT"]	= false

if locale == "deDE" then
L["COMBATLOCK"] = "Nicht verfügbar während eines Kampfes."
L["DEFAULT_TAB"] = "Standardtab"
L["DEFAULT_TAB_TT"] = [=[Aktiviert WQT als Standardtab nach dem Einloggen.
Nicht aktiv für Charaktere unter Level 110.]=]
L["FACTION"] = "Fraktion"
L["FILTER"] = "Filter: %s"
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
L["TYPE_DUNGEON"] = "Dungeon"
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
L["COMBATLOCK"] = "Desativado durante combate."
L["DEFAULT_TAB"] = "Aba Padrão"
L["DEFAULT_TAB_TT"] = [=[Definir o WQT como aba padrão quando você logar.
 Isso não se aplica a personagens abaixo do nível 110.]=]
L["FACTION"] = "Facção"
L["FILTER"] = "Filtro: %s"
L["FILTER_PINS"] = "Filtrar marcações no mapa"
L["FILTER_PINS_TT"] = [=[Aplica filtros às
marcações no mapa.]=]
L["NAME"] = "Nome"
L["NO_FACTION"] = "Sem Facção"
L["OPTIONS_INFO"] = "As opções [WQT] podem ser encontradas abaixo do botão de filtro."
L["OTHER_FACTION"] = "Outro"
L["PIN_BIGGER"] = "Marcações maiores no mapa"
L["PIN_BIGGER_TT"] = [=[Aumente a visibilidade da marcação no mapa.
Disponível apenas com as marcações de recompensas ativa]=]
L["PIN_COLOR"] = "Cor do anel da marcação"
L["PIN_COLOR_TT"] = [=[Exibe um anel colorido envolta das marcações
dependendo do tipo de recompensa.]=]
L["PIN_DISABLE"] = "Desativa mudanças na marcação"
L["PIN_DISABLE_TT"] = "Prevenir WQT fazer mudanças nas marcações do mapa."
L["PIN_REWARDS"] = "Marcadores de recompensas"
L["PIN_REWARDS_TT"] = "Exibe ícone de recompensas da missão nos marcadores."
L["PIN_TIME"] = "Tempo do marcador"
L["PIN_TIME_TT"] = "Adicionar tempo restante nos marcadores."
L["QUESTLOG"] = "Log de Missões"
L["REWARD"] = "Recompensa"
L["REWARD_ARMOR"] = "Armadura"
L["REWARD_ARTIFACT"] = "Artefato"
L["REWARD_GOLD"] = "Ouro"
L["REWARD_ITEM"] = "Item"
L["REWARD_RELIC"] = "Relíquia"
L["REWARD_RESOURCES"] = "Recursos"
L["SAVE_SETTINGS"] = "Salvar/Organizar Filtros"
L["SAVE_SETTINGS_TT"] = [=[Salva configurações de filtro e ordenação
entre sessões e recarregamentos.]=]
L["SETTINGS"] = "Configurações"
L["SHOW_FACTION"] = "Exibir Facção"
L["SHOW_FACTION_TT"] = [=[Exibir ícone da facção
na lista de missões.]=]
L["SHOW_TYPE"] = "Exibir Tipo"
L["SHOW_TYPE_TT"] = [=[Exibe o ícone do tipo
na lista de missões.]=]
L["TIME"] = "Tempo"
L["TYPE"] = "Tipo"
L["TYPE_DEFAULT"] = "Padrão"
L["TYPE_DUNGEON"] = "Masmorra"
L["TYPE_ELITE"] = "Elite"
L["TYPE_EMISSARY"] = "Emissário"
L["TYPE_INVASION"] = "Invasão"
L["TYPE_PETBATTLE"] = "Batalha de mascote"
L["TYPE_PROFESSION"] = "Profissão"
L["TYPE_PVP"] = "JxJ"
L["TYPE_RAID"] = "Raid"
L["WORLDQUEST"] = "Missões Mundiais"
L["ZONE"] = "Zona"
end

if locale == "frFR" then
L["COMBATLOCK"] = "Désactivé en combat."
L["DEFAULT_TAB"] = "Onglet par défaut"
L["DEFAULT_TAB_TT"] = [=[Définir WQT comme onglet par défaut quand vous vous connectez.
Ne s'applique pas en dessous du niveau 110.]=]
L["FACTION"] = "Faction"
L["FILTER"] = "Filtre : %s"
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
L["FACTION"] = "Фракция"
L["FILTER"] = "Фильтр: %s"
L["FILTER_PINS"] = "Фильтр меток"
L["FILTER_PINS_TT"] = "Применить фильтры к меткaм на карте"
L["NAME"] = "Назвaние"
L["NO_FACTION"] = "Без фрaкции"
L["NUMBERS_FIRST"] = "%gk"
L["NUMBERS_SECOND"] = "%gm"
L["NUMBERS_THIRD"] = "%gb"
L["OPTIONS_INFO"] = "[WQT] Опции нaходятся под кнопкой фильтров."
L["OTHER_FACTION"] = "Другиe"
L["PIN_BIGGER"] = "Большиe метки"
L["PIN_BIGGER_TT"] = [=[Слегка увеличить метки на кaрте. 
Доступно только при включенных метках на карте.]=]
L["PIN_COLOR"] = "Цвет метки"
L["PIN_COLOR_TT"] = "Показать цветное кольцо вокруг метки в зависимости от типа награды."
L["PIN_DISABLE"] = "Отключить изменение меток"
L["PIN_DISABLE_TT"] = "Запретить WQT изменять метки на карте."
L["PIN_REWARDS"] = "Нагрaды на метках"
L["PIN_REWARDS_TT"] = "Показать награды на метках"
L["PIN_TIME"] = "Время на метках"
L["PIN_TIME_TT"] = "Добавить оставшееся время к меткам на карте"
L["PRECISE_FILTER"] = "Точный Фильтр"
L["PRECISE_FILTER_TT"] = "Показывать только задания соответствующие всем выбранным категориям фильтров сразу."
L["QUESTLOG"] = "Журнал заданий"
L["REWARD"] = "Наградa"
L["REWARD_ARMOR"] = "Броня"
L["REWARD_ARTIFACT"] = "Артефакт"
L["REWARD_EXPERIENCE"] = "Опыт"
L["REWARD_GOLD"] = "Золото"
L["REWARD_HONOR"] = "Честь"
L["REWARD_ITEM"] = "Предметы"
L["REWARD_NONE"] = "Нет"
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
L["TRACKDD_TOMTOM"] = "Добавить в TomTom"
L["TRACKDD_TOMTOM_REMOVE"] = "Убрать из TomTom"
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
L["FACTION"] = "阵营"
L["FILTER"] = "过滤： %s"
L["FILTER_PINS"] = "过滤地图显示"
L["FILTER_PINS_TT"] = "在地图上显示过滤后的任务信息。"
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
L["NUMBERS_FIRST"]	= "%g万"
L["NUMBERS_SECOND"]	= "%g亿"
L["NUMBERS_THIRD"]	= "%g"
L["IS_AZIAN_CLIENT"]	= true
end

if locale == "zhTW" then
L["COMBATLOCK"] = "戰鬥中無法使用"
L["DEFAULT_TAB"] = "預設標籤"
L["DEFAULT_TAB_TT"] = [=[將WQT設定為預設啟用標籤。
這不適用於等級110以下角色。]=]
L["FACTION"] = "陣營"
L["FILTER"] = "過濾: %s"
L["FILTER_PINS"] = "過濾地圖顯示"
L["FILTER_PINS_TT"] = "將過濾套用到地圖上的任務點"
L["NAME"] = "名稱"
L["NO_FACTION"] = "無陣營"
L["NUMBERS_FIRST"] = "%g万"
L["NUMBERS_SECOND"] = "%g亿"
L["NUMBERS_THIRD"] = "%g"
L["OPTIONS_INFO"] = "[WQT]設定選項可以在過濾按鍵下找到"
L["OTHER_FACTION"] = "其它"
L["PIN_BIGGER"] = "地圖上顯示大型圖示"
L["PIN_BIGGER_TT"] = [=[增加地圖示大小以提高可見性
僅於啟用地圖上顯示獎勵圖示時有效]=]
L["PIN_COLOR"] = "依獎勵著色圖示週邊"
L["PIN_COLOR_TT"] = "根據獎勵類型在圖示周圍著色顯示"
L["PIN_DISABLE"] = "停用任務點更改"
L["PIN_DISABLE_TT"] = "防止世界任務追蹤更改地圖任務點。"
L["PIN_REWARDS"] = "地圖上顯示獎勵圖示"
L["PIN_REWARDS_TT"] = "在圖示上顯示任務獎勵圖示"
L["PIN_TIME"] = "地圖上顯示剩餘時間"
L["PIN_TIME_TT"] = "在圖示上加入任務剩餘時間"
L["PRECISE_FILTER"] = "精確過濾"
L["PRECISE_FILTER_TT"] = "過濾器只顯示與所有類別匹配的任務，而不僅僅是任何類別。"
L["QUESTLOG"] = "任務日誌"
L["REWARD"] = "獎勵"
L["REWARD_ARMOR"] = "護甲"
L["REWARD_ARTIFACT"] = "神兵之力"
L["REWARD_EXPERIENCE"] = "經驗值"
L["REWARD_GOLD"] = "金錢"
L["REWARD_HONOR"] = "榮譽"
L["REWARD_ITEM"] = "物品"
L["REWARD_NONE"] = "無"
L["REWARD_RELIC"] = "聖物"
L["REWARD_RESOURCES"] = "大廳資源"
L["SAVE_SETTINGS"] = "儲存過濾/排序"
L["SAVE_SETTINGS_TT"] = "在每次登入與重載間儲存過濾與排序設置。"
L["SETTINGS"] = "設定"
L["SHOW_FACTION"] = "顯示陣營"
L["SHOW_FACTION_TT"] = "在任務清單顯示陣營圖示"
L["SHOW_TYPE"] = "顯示類型"
L["SHOW_TYPE_TT"] = "在任務清單顯示類型圖示"
L["TIME"] = "時間"
L["TRACKDD_TOMTOM"] = "加入TomTom"
L["TRACKDD_TOMTOM_REMOVE"] = "從TomTom移除"
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
L["IS_AZIAN_CLIENT"]	= true
end

if locale == "koKR" then
L["COMBATLOCK"] = "전투 중엔 비활성됩니다."
L["DEFAULT_TAB"] = "기본 탭"
L["DEFAULT_TAB_TT"] = [=[로그인 했을 때 WQT를 기본 탭으로 설정합니다.
110 레벨 미만의 캐릭터엔 적용하지 않습니다.]=]
L["FACTION"] = "평판 진영"
L["FILTER"] = "필터: %s"
L["FILTER_PINS"] = "지도 표시 필터"
L["FILTER_PINS_TT"] = [=[지도 상의 표시에
필터를 적용합니다.]=]
L["NAME"] = "이름"
L["NO_FACTION"] = "진영 없음"
L["NUMBERS_FIRST"] = "%g만"
L["NUMBERS_SECOND"] = "%g억"
L["NUMBERS_THIRD"] = "%g조"
L["OPTIONS_INFO"] = "[WQT] 필터 버튼 아래에서 옵션을 찾을 수 있습니다."
L["OTHER_FACTION"] = "기타"
L["PIN_BIGGER"] = "큰 지도 표시"
L["PIN_BIGGER_TT"] = [=[가시성을 위해 지도 표시 크기를 약간 키웁니다.
보상이 활성화된 지도 표시에만 사용할 수 있습니다]=]
L["PIN_COLOR"] = "지도 표시 색상화"
L["PIN_COLOR_TT"] = [=[보상 유형에 따라 표시 주변에
색상화된 원을 표시합니다.]=]
L["PIN_DISABLE"] = "표시 변경 비활성화"
L["PIN_DISABLE_TT"] = "WQT가 지도 표시를 변경하지 못하게 막습니다."
L["PIN_REWARDS"] = "보상 지도 표시"
L["PIN_REWARDS_TT"] = "지도 표시에 퀘스트 보상 아이콘을 표시합니다."
L["PIN_TIME"] = "시간 지도 표시"
L["PIN_TIME_TT"] = "지도 표시에 남은 시간을 추가합니다."
L["PRECISE_FILTER"] = "정밀 필터"
L["PRECISE_FILTER_TT"] = "하나의 범주가 아닌 모든 필터 범주와 일치하는 퀘스트만 표시하도록 필터링합니다."
L["QUESTLOG"] = "퀘스트 기록"
L["REWARD"] = "보상"
L["REWARD_ARMOR"] = "방어구"
L["REWARD_ARTIFACT"] = "유물력"
L["REWARD_EXPERIENCE"] = "경험치"
L["REWARD_GOLD"] = "골드"
L["REWARD_HONOR"] = "명예"
L["REWARD_ITEM"] = "아이템"
L["REWARD_NONE"] = "없음"
L["REWARD_RELIC"] = "성물"
L["REWARD_RESOURCES"] = "자원"
L["SAVE_SETTINGS"] = "필터/정렬 저장"
L["SAVE_SETTINGS_TT"] = [=[세션과 다시 불러오기 간에
필터와 정렬 설정을 저장합니다.]=]
L["SETTINGS"] = "설정"
L["SHOW_FACTION"] = "진영 표시"
L["SHOW_FACTION_TT"] = [=[퀘스트 목록에
진영 아이콘을 표시합니다.]=]
L["SHOW_TYPE"] = "유형 표시"
L["SHOW_TYPE_TT"] = [=[퀘스트 목록에
유형 아이콘을 표시합니다.]=]
L["TIME"] = "시간"
L["TRACKDD_TOMTOM"] = "TomTom 추가"
L["TRACKDD_TOMTOM_REMOVE"] = "TomTom 제거"
L["TYPE"] = "유형"
L["TYPE_DEFAULT"] = "기본"
L["TYPE_DUNGEON"] = "던전"
L["TYPE_ELITE"] = "정예"
L["TYPE_EMISSARY"] = "사절"
L["TYPE_INVASION"] = "침략"
L["TYPE_PETBATTLE"] = "애완동물 대전"
L["TYPE_PROFESSION"] = "전문 기술"
L["TYPE_PVP"] = "PvP"
L["TYPE_RAID"] = "공격대"
L["WORLDQUEST"] = "전역 퀘스트"
L["ZONE"] = "지역"
L["IS_AZIAN_CLIENT"]	= true
end

addon.L = L;