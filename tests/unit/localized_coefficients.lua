-- Native Spell descriptions from Forever 1.60.1.70450 with fixed tooltip
-- amounts, durations, and distances substituted for the client tokens.
-- These exercise the same spells in every language, including reversed
-- duration order, ranges, periodic totals, ticks, and unrelated numbers.
return function(test)
    local function localizedLabels(locale, L)
        local missing = {}
        for _, key in ipairs({ "Spell Power Coefficient", "Spell Power Coefficient over time",
            "Healing Power Coefficient", "Healing Power Coefficient over time", "each", "%s to %s" }) do
            -- Reading through L's metatable would silently accept English fallback.
            local value = rawget(L, key)
            if type(value) ~= "string" or value == "" or value == key then missing[#missing + 1] = key end
        end
        test.check(locale .. ": coefficient wording has explicit translations", missing, {})
    end
    local cases = {
        { locale = "deDE", file = "deDE", text = {
            [2136] = "Überzieht den Feind mit 39 bis 48 Punkt(en) Feuerschaden.",
            [1042] = "Heilt ein befreundetes Ziel um 425 bis 479 Punkt(e).",
            [145] = "Schleudert eine glühende Kugel hinaus, die 66 bis 83 Punkt(e) Feuerschaden sowie 6 Sek. lang 6 Punkt(e) zusätzlichen Feuerschaden verursacht.",
            [139] = "Heilt das Ziel 15 Sek. lang um 400 Schadenspunkt(e).",
            [8936] = "Heilt ein befreundetes Ziel um 300 bis 350 und über 21 Sek. um weitere 350.",
            [5143] = "Schleudert arkane Geschosse auf den Feind und verursacht 5 Sek. lang pro Sekunde 230 Punkt(e) Arkanschaden.",
            [740] = "Regeneriert 10 Sek. lang alle 2 Sek. 1425 Gesundheit aller Gruppenmitglieder innerhalb von 40 Metern. Der Druide muss diesen Zauber kanalisieren, um ihn aufrechtzuerhalten.",
            [17] = "Nutzt die Seelenkraft des Gruppenmitglieds zum Abschirmen und absorbiert dabei 150 Punkt(e) Schaden. Hält 30 Sek. lang an. Solange der Schild hält, wird das Zauberwirken durch erlittenen Schaden nicht unterbrochen. Nachdem das Ziel einmal abgeschirmt wurde, kann es 15 Sek. lang nicht wieder abgeschirmt werden.",
            [837] = "Schleudert einen Frostblitz auf den Gegner, der 62 bis 68 Frostschaden verursacht und 6 Sek. lang das Bewegungstempo um 40% verringert.",
        } },
        { locale = "frFR", file = "frFR", text = {
            [2136] = "Frappe l'ennemi et lui inflige 39 à 48 points de dégâts de Feu.",
            [1042] = "Rend 425 à 479 points de vie à une cible alliée.",
            [145] = "Projette une boule ardente qui inflige 66 à 83 points de dégâts de Feu et 6 points de dégâts de Feu supplémentaires en 6 s.",
            [139] = "Rend 400 points de vie à la cible en 15 s.",
            [8936] = "Soigne une cible amie pour 300 à 350 puis pour 350 points supplémentaires pendant 21 s.",
            [5143] = "Lance des projectiles des arcanes sur l'ennemi et inflige 230 points de dégâts des Arcanes toutes les secondes pendant 5 s.",
            [740] = "Régénère de 1425 les points de vie des membres du groupe à moins de 40 m toutes les 2 s pendant 10 s. Le personnage druide doit canaliser le sort pendant toute sa durée, sinon celui-ci s’interrompt.",
            [17] = "Puise dans l’âme du membre du groupe pour le protéger et absorbe 150 points de dégâts. Dure 30 s. Tant que le bouclier est actif, les sorts ne sont pas interrompus par les dégâts subis. Après usage, la cible ne peut plus profiter de cette protection pendant 15 s.",
            [837] = "Lance un éclair de givre sur l’ennemi, inflige de 62 à 68 points de dégâts de givre et réduit sa vitesse de déplacement de 40 % pendant 6 s.",
        } },
        { locale = "esES", file = "esES", text = {
            [2136] = "Carga contra el enemigo, causando 39 a 48 p. de daño de Fuego.",
            [1042] = "Cura un objetivo amigo en 425 a 479 p.",
            [145] = "Lanza una bola abrasadora que causa 66 a 83 p. de daño de Fuego y 6 p. de daño de Fuego extra durante 6 s.",
            [139] = "Cura el objetivo en 400 p. de daño durante 15 s.",
            [8936] = "Cura un objetivo amigo en 300 a 350 p. y otro en 350 p. durante 21 s.",
            [5143] = "Lanza misiles Arcanos contra el enemigo y le causa 230 p. de daño Arcano cada segundo durante 5 s.",
            [740] = "Regenera 1425 p. a todos los miembros del grupo en un radio de 40 m cada 2 s durante 10 s. El druida debe canalizar su magia para mantener el hechizo.",
            [17] = "Atrae el alma de un miembro del grupo para protegerlo y absorbe 150 p. de daño. Dura 30 s. Mientras el escudo esté activo, los lanzamientos de hechizos no se interrumpirán al recibir daño. Una vez que haya sido protegido, el objetivo no puede recibir protección de nuevo durante 15 s.",
            [837] = "Lanza al enemigo una descarga de Escarcha que inflige de 62 a 68 p. de daño de Escarcha y reduce un 40% su velocidad de movimiento durante 6 s.",
        } },
        { locale = "esMX", file = "esMX", text = {
            [2136] = "Golpea al enemigo, inflige 39 a 48 p. de daño de Fuego.",
            [1042] = "Sana un objetivo amistoso en 425 a 479 p.",
            [145] = "Lanza una bola ígnea que causa 66 a 83 p. de daño de Fuego y 6 p. de daño de Fuego extra durante 6 s.",
            [139] = "Sana 400 p. de daño al objetivo durante 15 s.",
            [8936] = "Sana 300 a 350 p. a un objetivo aliado y otros 350 p. durante 21 s.",
            [5143] = "Lanza Misiles arcanos contra el enemigo y le inflige 230 p. de daño Arcano por segundo durante 5 s.",
            [740] = "Regenera 1425 p. de salud a todos los miembros del grupo en un radio de 40 m cada 2 s durante 10 s. El druida debe canalizar su magia para mantener el hechizo.",
            [17] = "Refuerza con un escudo el alma de un miembro del grupo y absorbe 150 p. de daño. Dura 30 s. Mientras dura el escudo, el lanzamiento de hechizos no se ve interrumpido por el daño. Una vez protegido, el objetivo no puede volver a recibir protección durante 15 s.",
            [837] = "Lanza una descarga de Escarcha al enemigo que le inflige de 62 a 68 p. de daño de Escarcha y ralentiza su velocidad de movimiento un 40% durante 6 s.",
        } },
        { locale = "ptBR", file = "Portuguese", text = {
            [2136] = "Atinge o inimigo, causando 39 a 48 de dano de Fogo.",
            [1042] = "Cura 425 a 479 pontos de vida de um alvo aliado.",
            [145] = "Lança uma bola flamejante que causa 66 a 83 de dano de Fogo e mais 6 de dano de Fogo ao longo de 6 s.",
            [139] = "Cura 400 pontos de vida do alvo ao longo de 15 s.",
            [8936] = "Cura 300 a 350 pontos de vida de um alvo aliado e mais 350 ao longo de 21 s.",
            [5143] = "Dispara Mísseis Arcanos contra o inimigo, causando 230 de dano Arcano a cada segundo por 5 s.",
            [740] = "Regenera 1425 pontos de vida de todos os integrantes próximos do grupo em um raio de 40 m a cada 2 s por 10 s. O Druida precisa canalizar para manter o feitiço.",
            [17] = "Recorre à alma do integrante do grupo para protegê-lo, absorvendo 150 de dano. Dura 30 s. Enquanto o escudo estiver ativo, receber dano não interrompe o lançamento de feitiços. Ao ser protegido, o alvo não pode ser protegido novamente por 15 s.",
            [837] = "Lança uma seta de gelo contra um inimigo, causando 62 a 68 de dano de Gelo e reduzindo em 40% a velocidade de movimento por 6 s.",
        } },
        { locale = "koKR", file = "koKR", text = {
            [2136] = "적을 강타하여 39~48의 화염 피해를 입힙니다.",
            [1042] = "대상의 생명력을 425~479만큼 회복시킵니다.",
            [145] = "적에게 불타는 구체를 날려 66~83의 화염 피해를 입히고 6초에 걸쳐 총 6의 추가 화염 피해를 입힙니다.",
            [139] = "15초에 걸쳐 대상의 생명력을 총 400만큼 회복시킵니다.",
            [8936] = "대상의 생명력을 300~350만큼 회복시키고 추가로 21초에 걸쳐 총 350의 생명력을 회복시킵니다.",
            [5143] = "5초에 걸쳐 적에게 마법 화살을 날려 매초마다 각각 230의 비전 피해를 입힙니다.",
            [740] = "10초 동안 2초마다 40미터 내 주위 모든 파티원의 생명력을 1425만큼 회복시킵니다. 주문을 유지하려면 계속 정신을 집중해야 합니다.",
            [17] = "파티원의 영적인 힘을 이용하여 즉시 보호막을 생성하여 150의 피해를 흡수합니다. 30초 동안 지속됩니다. 보호막이 지속되는 동안은 피해에 의해 주문 시전이 방해받지 않습니다. 한 번 보호막을 사용한 대상에겐 15초 동안 다시 보호막을 사용할 수 없습니다.",
            [837] = "적에게 얼음 화살을 날려 62에서 68의 냉기 피해를 입히고 6초 동안 이동 속도를 40%만큼 감소시킵니다.",
        } },
        { locale = "zhCN", file = "zhCN", text = {
            [2136] = "施放火焰冲击敌人，对其造成39到48点火焰伤害。",
            [1042] = "治疗友方目标，恢复425到479点生命值。",
            [145] = "发射一枚火球攻击目标，对其造成66到83点火焰伤害，并在6秒内造成额外的6点伤害。",
            [139] = "治疗目标，在15秒内恢复总计400点生命值。",
            [8936] = "治疗友方目标，恢复300到350点生命值，并在21秒内恢复额外的350点生命值。",
            [5143] = "向目标射出数枚奥术飞弹，对其造成每秒230点伤害，持续5秒。",
            [740] = "使40码内附近的所有队伍成员每2秒恢复1425点生命值，持续10秒。德鲁伊必须持续引导才能维持该法术。",
            [17] = "汲取一名队伍成员的灵魂力量，为其施加护盾，吸收150点伤害。持续30秒。护盾存在期间，其施法不会因受到伤害而被打断。受到护盾保护后，该目标在15秒内无法再次受到护盾保护。",
            [837] = "向目标射出一支寒冰箭，对其造成62至68点冰霜伤害并使其移动速度降低40%，持续6秒。",
        } },
        { locale = "zhTW", file = "zhTW", text = {
            [2136] = "施放火焰衝擊敵人，對其造成39到48點火焰傷害。",
            [1042] = "治療友方目標，恢復425到479點生命力。",
            [145] = "發射一枚火球攻擊目標，對其造成66到83點火焰傷害，並在6秒內造成額外的6點火焰傷害。",
            [139] = "治療目標，在15秒內恢復總計400點生命力。",
            [8936] = "治療友方目標，恢復300到350點生命力，並在21秒內恢復額外的350點生命力。",
            [5143] = "向目標射出數枚秘法飛彈，對其造成每秒230點傷害，持續5秒。",
            [740] = "使40碼內的所有隊伍成員每2秒恢復1425點生命力，持續10秒。德魯伊必須引導以維持法術效果。",
            [17] = "汲取隊友的靈魂之力，為其加上魔法護盾，可吸收150點傷害。持續30秒。只要護盾存在，受保護者的施法就不會被傷害打斷。目標在被加上護盾之後的15秒內無法再被加上護盾。",
            [837] = "向敵人射出一支寒冰箭，對其造成62點到68點冰霜傷害，並降低40%的移動速度，持續6秒。",
        } },
        { locale = "ruRU", file = "ruRU", text = {
            [2136] = "Наносит противнику 39 - 48 ед. урона от огня.",
            [1042] = "Исцеляет дружественную цель на 425 - 479 ед. здоровья.",
            [145] = "Бросок огненного шара, который наносит 66 - 83 ед. урона от огня единовременно и 6 ед. урона от огня в течение 6 сек.",
            [139] = "Излечение цели на 400 ед. в течение 15 сек.",
            [8936] = "Исцеление дружественной цели на 300 - 350 ед. и еще 350 ед. в течение 21 сек.",
            [5143] = "Атака противника чародейскими снарядами, наносящими 230 ед. урона от тайной магии раз в секунду в течение 5 сек.",
            [740] = "Восполняет участникам группы в радиусе 40 м 1425 ед. здоровья раз в 2 сек. в течение 10 сек. Требуется поддержание заклинания.",
            [17] = "Вытягивает частичку души участника группы и создает из нее щит, поглощающий 150 ед. урона. Время действия – 30 сек. Пока персонаж защищен, применение заклинаний не может быть прервано получением урона. Повторно применить щит можно только через 15 сек.",
            [837] = "В противника летит ледяная стрела, наносящая от 62 до 68 ед. урона от магии льда и снижающая скорость передвижения на 40% на 6 сек.",
        } },
    }

    for _, case in ipairs(cases) do
        local ns = test.load({ "Core/Util.lua", "Core/Palette.lua", "Locale/Locale.lua", "Locale/English.lua",
            "Locale/" .. case.file .. ".lua", "Game/Game.lua", "Data/Schools.lua", "Data/SpellRanks.lua",
            "Game/SpellAmounts.lua", "Data/Coefficients.lua" }, { client = { locale = case.locale } })
        local util, L = ns.util, ns.L
        localizedLabels(case.locale, L)
        local game = { spellDamage = function() return 30 end, spellHealing = function() return 300 end }
        local function number(value) return (value:gsub("%.", DECIMAL_SEPERATOR)) end
        local function range(low, high) return util.fill(L["%s to %s"], low, high) end
        local function row(share, base, bonus, each)
            return number(share) .. "% · " .. base .. " + " .. bonus .. (each and " " .. L["each"] or "")
        end
        local function check(spellID, cast, cost, expected, expectedRates, healing)
            local rows, rates = ns.spellPowerRows({ spellID = spellID, name = "?", description = { case.text[spellID] },
                cast = { cast, L["Cast"] }, cost = cost and { tostring(cost), MANA } }, "FFFFFF", game)
            local values, labels, rateValues = {}, {}, {}
            for _, found in ipairs(rows or {}) do
                values[#values + 1] = util.plainText(found.right)
                labels[#labels + 1] = found.left
            end
            for _, found in ipairs(rates or {}) do rateValues[#rateValues + 1] = found.right end
            test.check(case.locale .. ": " .. spellID .. " amounts and coefficients", values, expected)
            test.check(case.locale .. ": " .. spellID .. " rates", rateValues, expectedRates)
            local caption = healing and "Healing Power Coefficient" or "Spell Power Coefficient"
            local rank = ns.spellRanks[spellID]
            local expectedLabels = {}
            if rank[2] then expectedLabels[#expectedLabels + 1] = L[caption] end
            if rank[3] then expectedLabels[#expectedLabels + 1] = L[caption .. " over time"] end
            test.check(case.locale .. ": " .. spellID .. " translated captions", labels, expectedLabels)
        end
        check(2136, SPELL_CAST_TIME_INSTANT, 40, { row("42.9", range(27, 36), 12) },
            { number("29.0"), number("1.09") })
        check(1042, util.fill(SPELL_DURATION_SEC, number("2.5")), 275, { row("71.4", range(211, 265), 214) },
            { number("180.8"), number("1.64") }, true)
        check(145, util.fill(SPELL_DURATION_SEC, number("2.5")), 65,
            { row("71.4", range(45, 62), 21), row("0.0", "6", 0) }, { number("30.8"), number("1.24") })
        check(837, util.fill(SPELL_DURATION_SEC, number("1.7")), 35, { row("59.7", range(45, 51), 17) },
            { number("38.2"), number("1.86") })
        check(139, SPELL_CAST_TIME_INSTANT, 100, { row("100.0", "100", 300) },
            { number("26.7"), number("4.00") }, true)
        check(8936, util.fill(SPELL_DURATION_SEC, "2"), 100,
            { row("28.6", range(215, 265), 85), row("49.7", "201", 149) },
            { number("179.2"), number("6.75") }, true)
        check(5143, SPELL_CAST_CHANNELED, 1055, { row("85.8", "225", 5, true) },
            { number("230.0"), number("1.09") })
        check(740, SPELL_CAST_CHANNELED, 1000, { row("33.5", "1405", 20, true) },
            { number("712.5"), number("7.12") }, true)
        check(17, SPELL_CAST_TIME_INSTANT, 100, { row("10.0", "120", 30) },
            { number("100.0"), number("1.50") }, true)
        test.check(case.locale .. ": enabled after native wording checks", ns.Locale.features.coefficients, true)
        local filtered = ns.spellPowerRows({ spellID = 2136, name = "?", cast = { SPELL_CAST_TIME_INSTANT },
            description = { "40 % · " .. util.fill(SPELL_DURATION_SEC, "5") .. " · " .. case.text[2136] } }, "FFFFFF", game)
        test.check(case.locale .. ": percentages and durations before damage are not amounts",
            filtered and util.plainText(filtered[1].right), row("42.9", range(27, 36), 12))
        local rows = ns.spellPowerRows({ name = "Unknown", cast = { SPELL_CAST_TIME_INSTANT },
            description = { "40% · 5 " .. util.fill(SPELL_DURATION_SEC, "10") } }, "FFFFFF", game)
        test.check(case.locale .. ": unrelated numbers cannot create power rows", rows, nil)
    end
    -- Portugal loads the same translations as Brazil, through the .toc condition.
    local portuguese = test.load({ "Locale/Locale.lua", "Locale/English.lua", "Locale/Portuguese.lua" },
        { client = { locale = "ptPT" } })
    localizedLabels("ptPT", portuguese.L)
end
