local _, addon = ...

if GetLocale() ~= "ruRU" then return end;

local L = addon.L;

L["DEFAULT_TAB"] = "По умолчанию"
L["DEFAULT_TAB_TT"] = [=[Установить WQT как панель по умолчанию.
Не применяется к персонажам ниже 110 уровня.]=]
L["FILTER_PINS"] = "Фильтр меток"
L["FILTER_PINS_TT"] = "Применить фильтры к меткaм на карте"
L["NO_FACTION"] = "Без фрaкции"
L["NUMBERS_FIRST"] = "%gk"
L["NUMBERS_SECOND"] = "%gm"
L["NUMBERS_THIRD"] = "%gb"
L["PIN_DISABLE"] = "Отключить изменение меток"
L["PIN_DISABLE_TT"] = "Запретить WQT изменять метки на карте."
L["PIN_REWARDS"] = "Нагрaды на метках"
L["PIN_REWARDS_TT"] = "Показать награды на метках"
L["PIN_TIME"] = "Время на метках"
L["PIN_TIME_TT"] = "Добавить оставшееся время к меткам на карте"
L["SAVE_SETTINGS"] = "Сохранить фильтры"
L["SAVE_SETTINGS_TT"] = [=[Сохранить настройки фильтров между 
игровыми сессиями и перезагрузками.]=]
L["SHOW_FACTION"] = "Показать фракцию"
L["SHOW_FACTION_TT"] = [=[Показать иконку фракции
в панели задач.]=]
L["SHOW_TYPE"] = "Показaть тип"
L["SHOW_TYPE_TT"] = "Показать тип иконки в журнале заданий."
L["TIME"] = "Время"
L["TYPE_EMISSARY"] = "Посланник"
L["TYPE_INVASION"] = "Вторжение"
L["PRECISE_FILTER"] = "Точный Фильтр"
L["PRECISE_FILTER_TT"] = "Показывать только задания соответствующие всем выбранным категориям фильтров сразу."