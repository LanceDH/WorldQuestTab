local _, addon = ...

if GetLocale() ~= "ptBR" then return end;

local L = addon.L;

L["DEFAULT_TAB"] = "Aba Padrão"
L["DEFAULT_TAB_TT"] = [=[Definir o WQT como aba padrão quando você logar.
 Isso não se aplica a personagens abaixo do nível 110.]=]
L["FILTER_PINS"] = "Filtrar marcações no mapa"
L["FILTER_PINS_TT"] = [=[Aplica filtros às
marcações no mapa.]=]
L["NO_FACTION"] = "Sem Facção"
L["NUMBERS_FIRST"] = "%gk"
L["NUMBERS_SECOND"] = "%gm"
L["NUMBERS_THIRD"] = "%gb"
L["PIN_DISABLE"] = "Desativa mudanças na marcação"
L["PIN_DISABLE_TT"] = "Prevenir WQT fazer mudanças nas marcações do mapa."
L["PIN_REWARDS"] = "Marcadores de recompensas"
L["PIN_REWARDS_TT"] = "Exibe ícone de recompensas da missão nos marcadores."
L["PIN_TIME"] = "Tempo do marcador"
L["PIN_TIME_TT"] = "Adicionar tempo restante nos marcadores."
L["SAVE_SETTINGS"] = "Salvar/Organizar Filtros"
L["SAVE_SETTINGS_TT"] = [=[Salva configurações de filtro e ordenação
entre sessões e recarregamentos.]=]
L["SHOW_FACTION"] = "Exibir Facção"
L["SHOW_FACTION_TT"] = [=[Exibir ícone da facção
na lista de missões.]=]
L["SHOW_TYPE"] = "Exibir Tipo"
L["SHOW_TYPE_TT"] = [=[Exibe o ícone do tipo
na lista de missões.]=]
L["TIME"] = "Tempo"
L["TYPE_EMISSARY"] = "Emissário"
L["TYPE_INVASION"] = "Invasão"