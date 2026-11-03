-- Client-safe presentation data only: no roles, unrevealed events or world authority.
local P = {}
P.colors={Ink={23,34,39},Paper={239,229,204},Brass={180,143,78},Teal={36,76,78}}
P.audio={Cue="rbxasset://sounds/action_jump_land.mp3",Room="rbxasset://sounds/action_swim.mp3"}
P.labels={
    ru={Rules="Правила",Profile="Профиль",Social="Действия",Shop="Статус",Drop="Положить",Settings="Настройки",
        Close="Закрыть",Sound="Звук",Motion="Анимации",Contrast="Яркий режим",On="вкл",Off="выкл",
        Header="DOUBLE LIFE  /  ВЕЧЕРНИЙ ПРИЁМ",Action="Взаимодействие",Held="Предмет в руках",Empty="Руки свободны",
        Hint="E / F · подсказки рядом с предметом"},
    en={Rules="Help",Profile="Profile",Social="Actions",Shop="Style",Drop="Put down",Settings="Settings",
        Close="Close",Sound="Sound",Motion="Motion",Contrast="Bright mode",On="on",Off="off",
        Header="DOUBLE LIFE  /  EVENING RECEPTION",Action="Interaction",Held="Carrying an item",Empty="Hands free",
        Hint="E / F · follow nearby prompts"},
}
function P.label(locale,key)
    local language=if string.sub(locale or "",1,2)=="en" then "en" else "ru"
    return P.labels[language][key] or P.labels.ru[key] or key
end
function P.layout(width,height)
    local compact=width<850 or height<620
    return {compact=compact,statusWidth=math.min(390,math.max(150,width-162)),statusHeight=if compact then 86 else 241,
        buttonHeight=44,panelWidth=math.min(620,width-24),panelHeight=math.max(160,math.min(600,height-100)),
        toolbarWidth=math.min(610,width-24)}
end
-- Feedback derives exclusively from this client's approved snapshot.
function P.feedback(previous,current)
    if not previous or previous.round.roundId~=current.round.roundId or previous.round.phase~=current.round.phase then return nil end
    if not previous.hasDossier and current.hasDossier then return "Досье у вас · направляйтесь к выходу" end
    if not previous.evidence and current.evidence then return "Улика подобрана · можно приложить к голосу" end
    if previous.social.held~=current.social.held then return if current.social.held then "Предмет в руках · передача через действия" else "Предмет передан или положен" end
    if current.paintings>previous.paintings then return "Картина осмотрена · "..current.paintings.."/3" end
    if current.refreshments>previous.refreshments then return "Заказ доставлен" end
    return nil
end
function P.held(state)
    return state and (state.hasDossier or state.evidence~=nil or state.social.held~=nil or state.activities.event.hasRelic==true) or false
end
return P
