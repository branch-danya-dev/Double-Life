-- Public instructions for one's own role. No roster or hidden player data.
local Guide = {}
Guide.goals = {
    Owner = "Защитите досье · пульт в кабинете, этаж 2.",
    Spy = "Окно на террасе → сейф → выход во дворе. Досье: 60 с.",
    CounterAgent = "Проверьте журнал у сейфа, этаж 2. Улика не доказывает вину.",
    Staff = "Стойка кухни: принять заказ → взять сок → доставить к столику.",
    Guest = "Осмотрите 3 картины в галерее и закажите сок у столика.",
    Waiting = "Осмотрите особняк и пройдите практику. Старт от 2 реальных игроков.",
}
function Guide.goal(role)
    return Guide.goals[role] or Guide.goals.Waiting
end
return Guide
