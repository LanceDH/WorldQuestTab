local _, addon = ...

if GetLocale() ~= "frFR" then return end;

local L = addon.L;

L["DEFAULT_TAB"] = "Onglet par défaut"
L["DEFAULT_TAB_TT"] = [=[Définir WQT comme onglet par défaut quand vous vous connectez.
Ne s'applique pas en dessous du niveau 110.]=]
L["NO_FACTION"] = "Sans faction"
L["NUMBERS_FIRST"] = "%gk"
L["NUMBERS_SECOND"] = "%gm"
L["NUMBERS_THIRD"] = "%gb"
L["PIN_TIME_TT"] = "Ajouter le temps restant sur les points de la carte."
L["SAVE_SETTINGS"] = "Sauvegarder Filtres/Tri"
L["SAVE_SETTINGS_TT"] = [=[Sauvegarder les paramètres des filtres et du tri 
entre les sessions de jeu et les rechargements]=]
L["SHOW_FACTION"] = "Montrer la faction"
L["SHOW_FACTION_TT"] = "Afficher l'icône de la faction dans la liste de quête."
L["SHOW_TYPE"] = "Montrer le type"
L["SHOW_TYPE_TT"] = "Montrer l'icône de type dans la liste des Expéditions."
L["TIME"] = "Temps"
L["TYPE_EMISSARY"] = "Émissaire"
L["TYPE_INVASION"] = "Invasion"