﻿local _, addon = ...

if GetLocale() ~= "koKR" then return end;

local L = addon.L;
L["IS_AZIAN_CLIENT"]	= true

L["ALWAYS_ALL"] = "항상 모든 퀘스트"
L["ALWAYS_ALL_TT"] = "현재 지역과 관련된 확장팩에 대한 모든 퀘스트를 항상 표시합니다"
L["AMOUNT_COLORS"] = "수량 색상"
L["AMOUNT_COLORS_TT"] = "보상 유형에 따라 퀘스트 목록에 보상 수량을 색칠합니다."
L["AUTO_EMISARRY"] = "사절만 자동"
L["AUTO_EMISARRY_TT"] = "세계 지도 현상 수배 게시판의 사절을 클릭하면 '사절만' 필터가 일시적으로 활성화됩니다."
L["CONTAINER_DRAG"] = "이동"
L["CONTAINER_DRAG_TT"] = "다른 위치로 드래그합니다."
L["DEFAULT_TAB"] = "기본 탭"
L["DEFAULT_TAB_TT"] = "로그인 했을 때 WQT를 기본 탭으로 설정합니다. 최대 레벨 캐릭터에만 적용됩니다."
L["EMISSARY_COUNTER"] = "사절 카운터"
L["EMISSARY_COUNTER_TT"] = "각 사절의 진행 상황을 나타내는 사절 탭에 카운터를 추가합니다."
L["FILTER_PINS"] = "지도 표시 필터"
L["FILTER_PINS_TT"] = [=[지도 상의 표시에
필터를 적용합니다.]=]
L["GROUP_SEARCH_INFO"] = "블리자드는 부가 기능이 전역 퀘스트의 대부분의 퀘스트를 위한 그룹을 자동으로 찾지 못하게합니다. 이 때문에 플레이어는 검색 창을 수동으로 채원야합니다."
L["LIST_FULL_TIME"] = "시간 확장"
L["LIST_FULL_TIME_TT"] = "시간에 일, 분, 시간을 추가하여 시간에 보조 비율을 포함시킵니다."
L["LIST_SETTINGS"] = "목록 설정"
L["LOAD_UTILITIES"] = "유틸리티 부르기"
L["LOAD_UTILITIES_TT"] = "기록과 거리 정렬과 같은 유틸리티 기능을 불러옵니다.\\n|cFFFF5555이 기능을 비활성화하려면 재시작해야 합니다.|r"
L["LOAD_UTILITIES_TT_DISABLED"] = "|cFFFF5555애드온 목록에 World Quest Tab Utilities가 활성화되어 있지 않습니다.|r"
L["MAP_FILTER_DISABLED"] = "세계 지도 필터로 비활성화."
L["MAP_FILTER_DISABLED_BUTTON_INFO"] = "우-클릭으로 이 필터 다시 활성화"
L["MAP_FILTER_DISABLED_INFO"] = "세계 지도의 오른쪽 상단에 있는 돋보기에서 일부 필터를 사용하지 않도록 설정했습니다. 목록에서 일부 퀘스트를 숨기고 일부 필터 설정을 비활성화 할 수 있습니다."
L["MAP_FILTER_DISABLED_TITLE"] = "일부 세계 지도 필터가 비활성화되었습니다"
L["NO_FACTION"] = "진영 없음"
L["NUMBERS_FIRST"] = "%g만"
L["NUMBERS_SECOND"] = "%g억"
L["NUMBERS_THIRD"] = "%g조"
L["PIN_BIGGER"] = "큰 핀"
L["PIN_BIGGER_TT"] = "가시성을 높이기 위해 핀 크기를 키웁니다."
L["PIN_DISABLE"] = "표시 변경 비활성화"
L["PIN_DISABLE_TT"] = "WQT가 지도 표시를 변경하지 못하게 막습니다."
L["PIN_REWARD_TYPE"] = "보상 유형 아이콘"
L["PIN_REWARD_TYPE_TT"] = "핀에 보상 유형 아이콘을 추가합니다."
L["PIN_REWARDS"] = "보상 지도 표시"
L["PIN_REWARDS_TT"] = "지도 표시에 퀘스트 보상 아이콘을 표시합니다."
L["PIN_RING_DEFAULT_TT"] = "핀 고리에 특별한 변경이 없습니다."
L["PIN_RIMG_TIME_TT"] = "남은 시간에 따른 고리 색상입니다."
L["PIN_RING_COLOR"] = "보상 색상"
L["PIN_RING_COLOR_TT"] = "보상 유형에 따른 고리 색상입니다."
L["PIN_RING_DEFAULT"] = "기본값"
L["PIN_RING_TIME"] = "남은 시간"
L["PIN_RING_TITLE"] = "고리 유형"
L["PIN_SETTINGS"] = "지도 핀 설정"
L["PIN_TIME"] = "시간 지도 표시"
L["PIN_TIME_TT"] = "지도 표시에 남은 시간을 추가합니다."
L["PIN_TYPE"] = "퀘스트 유형 아이콘"
L["PIN_TYPE_TT"] = "특별 퀘스트 유형의 핀에 퀘스트 유형 아이콘을 추가합니다."
L["QUEST_COUNTER"] = "퀘스트 로그 카운터"
L["QUEST_COUNTER_INFO"] = "숨겨진 |cFFFFd100%d|r개의 퀘스트는 퀘스트 한도에 포함되며 포기할 수 없습니다. 이것은 블리자드의 마지막 문제입니다."
L["QUEST_COUNTER_TITLE"] = "숨겨진 퀘스트"
L["QUEST_COUNTER_TT"] = "기본 퀘스트 로그에 퀘스트의 숫자를 표시합니다."
L["SAVE_SETTINGS"] = "필터/정렬 저장"
L["SAVE_SETTINGS_TT"] = [=[세션과 다시 불러오기 간에
필터와 정렬 설정을 저장합니다.]=]
L["SHOW_FACTION"] = "진영 표시"
L["SHOW_FACTION_TT"] = [=[퀘스트 목록에
진영 아이콘을 표시합니다.]=]
L["SHOW_TYPE"] = "유형 표시"
L["SHOW_TYPE_TT"] = [=[퀘스트 목록에
유형 아이콘을 표시합니다.]=]
L["SHOW_ZONE"] = "지역 표시"
L["SHOW_ZONE_TT"] = "목록에 여러 지역의 퀘스트가 포함된 경우 지역 이름을 표시합니다."
L["TIME"] = "시간"
L["TOMTOM_AUTO_ARROW"] = "추적으로 목표지점 설정"
L["TOMTOM_AUTO_ARROW_TT"] = "Shift-클릭 또는 드롭다운 메뉴의 '추적' 설정을 사용하여 퀘스트를 추적하면 TomTom 목표지점아 자동으로 생성됩니다."
L["TOMTOM_CLICK_ARROW"] = "클릭으로 목표지점 설정"
L["TOMTOM_CLICK_ARROW_TT"] = "마지막으로 클릭한 전역 퀘스트에 TomTom 목표지점과 화살표를 만듭니다. 이 방법으로 추가한 이전 목표지점은 제거됩니다."
L["TYPE_EMISSARY"] = "사절"
L["TYPE_EMISSARY_TT"] = "현재 선택된 사절에 대한 퀘스트만 표시합니다. 이 필터는 다른 모든 필터를 덮어 씌웁니다."
L["TYPE_INVASION"] = "침공"
L["USE_TOMTOM"] = "TomTom 허용"
L["USE_TOMTOM_TT"] = "애드온에 TomTom 기능을 추가합니다."
L["WHATS_NEW"] = "새 기능"
L["WHATS_NEW_TT"] = "World Quest Tab의 패치 노트를 봅니다."
L["WQT_FULLSCREEN_BUTTON_TT"] = "좌-클릭으로 전역 퀘스트 목록을 전환합니다. 우-클릭 드래그로 위치를 변경합니다"
L["PRECISE_FILTER"] = "정밀 필터"
L["PRECISE_FILTER_TT"] = "하나의 범주가 아닌 모든 필터 범주와 일치하는 퀘스트만 표시하도록 필터링합니다."