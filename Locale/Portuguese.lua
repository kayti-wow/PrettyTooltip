-- The Portuguese clients, Brazil's and Portugal's, whose game strings are the
-- same: what the game has no string for, in Portuguese, and the client's own
-- names for skills, dispel types, quest kinds, and schools. Only those clients
-- load it (the .toc's AllowLoadTextLocale), after Locale\English.lua, so
-- whatever it leaves out stays English. Wordings marked "unconfirmed" are
-- guesses until a Portuguese capture shows them.
local _, ns = ...
local locale = ns.Locale

locale.supported = true
locale.features = { coefficients = true }

local formats = locale.formats
formats.weaponSpeed = "Velocidade %s"
-- "Ensina a fazer", "Ensina a confeccionar".
formats.recipeTeaches = "Usar: Ensina a %s"
-- Unconfirmed.
formats.baseManaCost = "%d%% da mana base"
-- Unconfirmed: as the map's legend names them.
formats.rare = "Raro"
formats.rareElite = "Elite Raro"

-- "Vigor +16 e Armadura +100".
locale.listSeparators = { ", e ", " e ", ", " }

-- Descriptions name most schools after "de", and Holy and Arcane as
-- adjectives: "dano de Fogo", "dano Sagrado", "feitiços Arcanos".
locale.descriptions.school = { "dano de %s", "dano %s", "feitiços de %s", "feitiços %s", "feitiços %ss" }
locale.schoolWords = { Arcane = "Arcano", Fire = "Fogo", Frost = "Gelo", Holy = "Sagrado", Nature = "Natureza",
    Shadow = "Sombra", Holyfire = "Fogo Sagrado", Frostfire = "Fogofrio" }

-- Amounts and durations from the native Spell table (Forever 1.60.1.70450).
local descriptions = locale.descriptions
descriptions.clause = "^[^%d]-"
descriptions.range = { "%d a %d", "%d - %d", "%d-%d" }
descriptions.over = { "ao longo de %d s", "por %d s", "durante %d s" }
descriptions.overBefore = false
descriptions.eachSecond = "a cada segundo por %d s"
descriptions.every = { "a cada %d s", "a cada %d segundos" }
descriptions.everyFor = { "por %d s", "durante %d s" }
descriptions.lasts = "dura %d s"
descriptions.perSecondAfter = { "a cada segundo" }
descriptions.units = { "s", "seg", "segundo", "segundos", "min", "minuto", "minutos", "hora", "horas", "m", "metro", "metros", "alvo", "alvos", "vezes", "cargas", "aplicações" }
descriptions.unitBoundaries = true
descriptions.heals = { "cura", "curar", "curando", "regenera", "absorve" }
descriptions.damageSchool = { "dano de %s", "dano %s" }

-- Older English equip wordings; the Portuguese client prints the game's own.
locale.statWordings = {}

local skills = locale.skills
skills.Alchemy = "Alquimia"
skills.Blacksmithing = "Ferraria"
skills.Enchanting = "Encantamento"
skills.Engineering = "Engenharia"
skills.Leatherworking = "Couraria"
skills.Tailoring = "Alfaiataria"
skills.Cooking = "Culinária"
skills["First Aid"] = "Primeiros Socorros"
skills.Fishing = "Pesca"
skills.Mining = "Mineração"
skills.Herbalism = "Herborismo"
skills.Skinning = "Esfolamento"
skills.Lockpicking = "Arrombamento"

local dispels = locale.dispels
dispels.Magic = "Magia"
dispels.Curse = "Maldição"
dispels.Disease = "Doença"
dispels.Poison = "Veneno"

locale.questTags = { Elite = true, Masmorra = true, Raide = true, Grupo = true, JxJ = true }

-- The addon's own words: a first draft, for a Portuguese speaker to review.
local L = ns.L

-- The panels -------------------------------------------------------------------

-- The spell strip. Portuguese spells measure their range in meters.
L["Cast"] = "Lançamento"
L["Cooldown"] = "Recarga"
L["Range"] = "Alcance"
L["Cost"] = "Custo"
L["Free"] = "Grátis"
L["None"] = "Nenhuma"
L["Self"] = "Si mesmo"
L["%s yd"] = "%s m"
L["Base Mana"] = "Mana base"
L["Next Rank"] = "Próximo grau"
L["Rank %s"] = "Grau %s"

-- Items. The game's own short form of item level.
L["%s Slot"] = "%s espaço"
L["%s Slots"] = "%s espaços"
L["Requires %s %s"] = "Requer %s %s"
L["Recipe"] = "Receita"
L["Made by %s"] = "Feito por %s"
L["Expected value"] = "Valor estimado"
L["iLvl %s"] = "Nvl %s"
L["Creates"] = "Cria"
L["Reagents"] = "Reagentes"
L["Equipped"] = "Equipado"
L["Equipped With"] = "Equipado com"

-- Auras, flight paths, macros, and pet abilities.
L["Buff"] = "Bônus"
L["Debuff"] = "Penalidade"
L["%s stacks"] = "%s acúmulos"
L["No time limit"] = "Sem limite de tempo"
L["by %s"] = "de %s"
L["You are here"] = "Você está aqui"
L["Macro"] = "Macro"
L["Macro: %s"] = "Macro: %s"
L["Autocast"] = "Auto"
L["Autocast off"] = "Auto desligado"
L["Active"] = "Ativo"

-- World objects.
L["Herb"] = "Planta"
L["Mining node"] = "Veio de minério"
L["Fishing pool"] = "Cardume"
L["Quest object"] = "Objeto de missão"
L["Auction"] = "Leilão"
L["%s to %s"] = "%s a %s"
L["Your skill %s"] = "Sua perícia %s"

-- Quests and units.
L["Legendary"] = "Lendária"
L["Heroic"] = "Heroica"
L["Group"] = "Grupo"
L["Scenario"] = "Cenário"
L["World event"] = "Evento mundial"
L["Completed"] = "Concluída"
L["Ready to turn in"] = "Pronta para entregar"
L["In progress"] = "Em andamento"
L["AFK"] = "Ausente"
L["DND"] = "Ocupado"

-- The spell power rows.
L["Healing per Second"] = "Cura por segundo"
L["Healing per Mana"] = "Cura por ponto de mana"
L["Damage per Mana"] = "Dano por ponto de mana"
L["Spell Power Coefficient"] = "Coeficiente de poder mágico"
L["Spell Power Coefficient over time"] = "Coeficiente de poder mágico ao longo do tempo"
L["Healing Power Coefficient"] = "Coeficiente de poder de cura"
L["Healing Power Coefficient over time"] = "Coeficiente de poder de cura ao longo do tempo"
L["each"] = "cada"

-- Stats --------------------------------------------------------------------------

L["All Stats"] = "Todos os atributos"
L["Attack Power vs %s"] = "Poder de ataque contra %s"
L["Hit Chance"] = "Chance de acerto"
L["Critical Strike Chance"] = "Chance de acerto crítico"
L["Hit Rating"] = "Índice de acerto"
L["Critical Strike Rating"] = "Índice de acerto crítico"
L["Haste Rating"] = "Índice de aceleração"
L["Expertise Rating"] = "Índice de aptidão"
L["Defense Skill"] = "Perícia em defesa"
L["Defense Rating"] = "Índice de defesa"
L["Dodge Chance"] = "Chance de esquiva"
L["Dodge Rating"] = "Índice de esquiva"
L["Parry Chance"] = "Chance de aparar"
L["Parry Rating"] = "Índice de aparo"
L["Block Chance"] = "Chance de bloqueio"
L["Block Rating"] = "Índice de bloqueio"
L["Shield Block Value"] = "Valor de bloqueio do escudo"
L["Resilience Rating"] = "Índice de resiliência"
L["All Resistances"] = "Todas as resistências"
L["Spell Damage Power"] = "Dano mágico"
L["Spell Damage Power vs %s"] = "Dano mágico contra %s"
L["Spell Penetration"] = "Penetração de feitiço"
L["Spell Hit Chance"] = "Chance de acerto de feitiço"
L["Spell Critical Strike Chance"] = "Chance de crítico de feitiço"
L["Spell Hit Rating"] = "Índice de acerto de feitiço"
L["Spell Critical Strike Rating"] = "Índice de crítico de feitiço"
L["Spell Haste Rating"] = "Índice de aceleração de feitiço"
-- The school's name follows in brackets: "Poder mágico (Fogo)".
L["%s Spell Power"] = "Poder mágico (%s)"
L["%s Spell Damage Power"] = "Dano mágico (%s)"
L["Healing Power"] = "Poder de cura"
L["Health per 5 sec"] = "Vida a cada 5 s"
L["Mana per 5 sec"] = "Mana a cada 5 s"
L["Beasts"] = "feras"
L["Demons"] = "demônios"
L["Dragonkin"] = "dracônicos"
L["Elementals"] = "elementais"
L["Giants"] = "gigantes"
L["Humanoids"] = "humanoides"
L["Mechanical"] = "mecânicos"
L["Undead"] = "mortos-vivos"

-- Stat categories, schools, and classes, as the style editor names them.
L["Primary attributes"] = "Atributos primários"
L["Attack"] = "Ataque"
L["Defense"] = "Defesa"
L["Magic"] = "Magia"
L["Healing"] = "Cura"
L["Mana"] = "Mana"
L["Negative values"] = "Valores negativos"
L["Arcane"] = "Arcano"
L["Fire"] = "Fogo"
L["Frost"] = "Gelo"
L["Holy"] = "Sagrado"
L["Nature"] = "Natureza"
L["Shadow"] = "Sombra"
L["Holyfire"] = "Fogo Sagrado"
L["Frostfire"] = "Fogofrio"
L["Warrior"] = "Guerreiro"
L["Paladin"] = "Paladino"
L["Hunter"] = "Caçador"
L["Rogue"] = "Ladino"
L["Priest"] = "Sacerdote"
L["Shaman"] = "Xamã"
L["Mage"] = "Mago"
L["Warlock"] = "Bruxo"
L["Druid"] = "Druida"

-- The style editor ---------------------------------------------------------------

L["PrettyTooltip Style Editor"] = "Editor de estilo do PrettyTooltip"
L["Click any part of the sample to restyle it. Tooltips use the new look the next time they open."] =
    "Clique em qualquer parte do exemplo para mudar o estilo dela. As dicas usam o novo visual na próxima vez que abrirem."
L["Click any part of the sample to edit it."] = "Clique em qualquer parte do exemplo para editá-la."
L["%s: click to edit"] = "%s: clique para editar"
L["There is no item with ID %s."] = "Não há item com o ID %s."
L["Loading item %s..."] = "Carregando o item %s..."
L["The sample failed to draw: %s"] = "Não foi possível desenhar o exemplo: %s"
L["Nothing to show for %s ID %s."] = "Nada para mostrar para o ID %s %s."
L["%s (not installed)"] = "%s (não instalado)"
L["Custom"] = "Personalizada"
L["Automatic"] = "Automática"
L["ID, or shift-click a link"] = "ID, ou Shift-clique em um link"
L["Clear"] = "Limpar"
L["Reset to default"] = "Restaurar o padrão"
L["Click to choose its color; right-click for the default."] =
    "Clique para escolher a cor; clique com o botão direito para a cor padrão."
L["Selected Part"] = "Parte selecionada"
L["Font"] = "Fonte"
L["Name font"] = "Fonte do nome"
L["Text font"] = "Fonte do texto"
L["Size"] = "Tamanho"
L["Color"] = "Cor"
L["Outline"] = "Contorno"
L["Same as global settings"] = "Igual às configurações gerais"
L["Thick outline"] = "Contorno grosso"
L["All caps"] = "Maiúsculas"
L["Letters"] = "Letras"
L["Reset this part"] = "Restaurar esta parte"
L["All Tooltips"] = "Todas as dicas"
L["Game default"] = "Padrão do jogo"
L["Text size"] = "Tamanho do texto"
L["Panel style"] = "Estilo do painel"
L["Blizzard border"] = "Borda da Blizzard"
L["Flat"] = "Plano"
L["Padding"] = "Margem interna"
L["Min width"] = "Largura mín."
L["Icon on the right"] = "Ícone à direita"
L["Moves the item or spell icon, and the item level badge under it, to the right of the name."] =
    "Move o ícone do item ou feitiço, e a placa de nível do item abaixo dele, para a direita do nome."
L["Tint the panel"] = "Tingir o painel"
L["Washes the panel in the item's quality color, or the spell's school or resource. Off, every panel is neutral; the name keeps its quality color."] =
    "Tinge o painel com a cor de qualidade do item, ou da escola ou do recurso do feitiço. Desligado, todo painel é neutro; o nome mantém a cor de qualidade."
L["Separators"] = "Separadores"
L["The gold dividers between sections and the thin rules above other addons' rows. Off, they are hidden along with the space around them."] =
    "Os divisores dourados entre as seções e as linhas finas acima das linhas de outros addons. Desligado, eles somem junto com o espaço ao redor."
L["School colors"] = "Cores das escolas"
L["%s Panel"] = "Painel: %s"
L["Show icon"] = "Mostrar ícone"
L["The icon or portrait in the header, for the kind of tooltip shown."] =
    "O ícone ou retrato no cabeçalho, para o tipo de dica mostrado."
L["Band top"] = "Faixa superior"
L["Band bottom"] = "Faixa inferior"
L["Backdrop"] = "Fundo"
L["Glow"] = "Brilho"
L["Footer"] = "Rodapé"
L["Item Details"] = "Detalhes de itens"
L["Spell Details"] = "Detalhes de feitiços"
L["Unit Details"] = "Detalhes de unidades"
L["Object Details"] = "Detalhes de objetos"
L["Quest Details"] = "Detalhes de missões"
L["Quest parchment"] = "Pergaminho de missão"
L["DialogueUI's brown parchment for quest tooltips, Quest Items, and items that begin a quest, with darker ink for readability. Requires DialogueUI to be installed."] =
    "O pergaminho marrom do DialogueUI para dicas de missão, itens de missão e itens que iniciam uma missão, com tinta mais escura para facilitar a leitura. Requer o DialogueUI."
L["Level badge"] = "Placa de nível"
L["The item level on a plate under the icon, for equipment."] =
    "O nível do item em uma placa abaixo do ícone, para equipamentos."
L["The level on a plate under the portrait. Off, the level stays in the info line."] =
    "O nível em uma placa abaixo do retrato. Desligado, o nível fica na linha de informações."
L["Stat markers"] = "Marcadores de atributos"
L["The small diamond before each stat; enchants use a green one."] =
    "O pequeno losango antes de cada atributo; encantamentos usam um verde."
L["Stat colors"] = "Cores dos atributos"
L["Each kind of stat in its color below, and the school colors. Off, every stat is parchment."] =
    "Cada tipo de atributo na sua cor abaixo, e as cores das escolas. Desligado, todo atributo fica cor de pergaminho."
L["Abbreviated Equip Effects"] = "Efeitos de Equipado abreviados"
L["Where the game's own item tooltip shows, in the Blizzard layout or with items not restyled, its Equip effects are shortened, as +1% Critical Strike Chance, and the game's colors kept, but for spell power and chance on hit effects in their stat colors. Hold the default tooltip modifier for the full wording."] =
    "Onde a dica de item do jogo aparece, no layout Blizzard ou com itens não redesenhados, os efeitos de Equipado são encurtados, como +1% Chance de acerto crítico, e as cores do jogo mantidas, exceto o poder mágico e os efeitos de chance ao acertar, nas cores de atributo. Segure a tecla para a dica do jogo para ver o texto completo."
L["Disenchant"] = "Desencantar"
L["Green, blue, and purple armor and weapons list what they disenchant into, with each result's chance and the Enchanting it needs; with Auctionator, the expected value."] =
    "Armaduras e armas verdes, azuis e roxas mostram no que se desencantam, com a chance de cada resultado e o Encantamento necessário; com o Auctionator, o valor estimado."
L["Sell price"] = "Preço de venda"
L["The vendor price in the footer; for a stack, the price of one and of the whole stack."] =
    "O preço do vendedor no rodapé; para uma pilha, o preço de uma unidade e da pilha inteira."
L["Swap Damage Stats"] = "Trocar dados de dano"
L["A weapon's damage on the large line, with its speed and damage per second on the small one under it."] =
    "O dano de uma arma na linha grande, com a velocidade e o dano por segundo na pequena logo abaixo."
L["Spell power"] = "Poder mágico"
L["Under the description, each amount's spell power coefficient and its split into base and spell power. No game API has coefficients: they come from Forever's client data, and ones marked ~ are estimates."] =
    "Abaixo da descrição, o coeficiente de poder mágico de cada valor e sua divisão entre base e poder mágico. Nenhuma API do jogo fornece coeficientes: eles vêm dos dados do cliente do Forever, e os marcados com ~ são estimativas."
L["Rates"] = "Taxas"
L["Under the spell power breakdown, the average a cast deals or heals per second and per mana. Per second, what lands at once counts over the cast time (instants as the 1.5 sec global cooldown) and what comes over time over its duration. Crits and talents do not count."] =
    "Abaixo da divisão de poder mágico, a média que um lançamento causa ou cura por segundo e por ponto de mana. Por segundo, o que chega de uma vez conta sobre o tempo de lançamento (os instantâneos como a recarga global de 1,5 s) e o que chega ao longo do tempo, sobre sua duração. Críticos e talentos não contam."
L["Health bar"] = "Barra de vida"
L["The game's own health bar at the bottom of player and NPC panels. The game fills it, so it stays live without the addon reading health, which WoW Forever keeps from addons."] =
    "A barra de vida do jogo na parte de baixo dos painéis de jogadores e PNJs. O jogo a preenche, então ela fica atualizada sem que o addon leia a vida, que o WoW Forever esconde dos addons."
L["Gathering"] = "Coleta"
L["What a herb or ore node holds: its yield over all the times it can be gathered, then the stone, gems, and other herbs it may give and the chance each time. On a dead creature that can be skinned, the Skinning it needs and the leather, hides, and scales it may give. From Classic's loot tables."] =
    "O que uma planta ou veio de minério contém: o rendimento em todas as vezes que pode ser coletado, depois as pedras, gemas e outras plantas que pode dar e a chance a cada vez. Em uma criatura morta que pode ser esfolada, o Esfolamento necessário e o couro, as peles e as escamas que pode dar. Das tabelas de saque do Classic."
L["Class colors"] = "Cores das classes"
L["Reset all fonts and colors"] = "Restaurar todas as fontes e cores"
L["More options"] = "Mais opções"
L["IDs"] = "IDs"
L["The item's, spell's, or NPC's ID at the bottom of its panel, under other addons' rows."] =
    "O ID do item, feitiço ou PNJ na parte de baixo do painel, abaixo das linhas de outros addons."
L["Item ID: %s"] = "ID do item: %s"
L["NPC ID: %s"] = "ID do PNJ: %s"

-- The kinds of tooltip, their samples' tabs, and the lookup by ID.
L["Items"] = "Itens"
L["Spells"] = "Feitiços"
L["Objects"] = "Objetos"
L["Units"] = "Unidades"
L["Buffs"] = "Auras"
L["Quests"] = "Missões"
L["Macros"] = "Macros"
L["Item ID"] = "ID do item"
L["Spell ID"] = "ID do feitiço"
L["Object ID"] = "ID do objeto"
L["Unit ID"] = "ID da unidade"
L["Buff ID"] = "ID da aura"
L["Quest ID"] = "ID da missão"
L["Macro ID"] = "ID da macro"
L["Weapon"] = "Arma"
L["Set piece"] = "Peça de conjunto"
L["Potion"] = "Poção"
L["Quest item"] = "Item de missão"
L["Fireball"] = "Bola de Fogo"
L["Ability"] = "Habilidade"
L["Heal"] = "Cura"
L["Ore"] = "Minério"
L["Chest"] = "Baú"
L["Quest"] = "Missão"
L["Player"] = "Jogador"
L["Enemy"] = "Inimigo"
L["Vendor"] = "Vendedor"
L["Rare"] = "Raro"
L["Rare elite"] = "Elite raro"
L["Boss"] = "Chefe"
L["Curse"] = "Maldição"
L["Poison"] = "Veneno"
L["Ready"] = "Pronta"
L["New"] = "Nova"
L["Targeting"] = "Seleção de alvo"

-- The style parts, and what each says about its color.
L["Item name"] = "Nome do item"
L["Quality color unless set."] = "Cor de qualidade, a menos que definida."
L["Type and slot"] = "Tipo e compartimento"
L["Half the quality color, red for a type you cannot use."] =
    "Meio-tom da cor de qualidade, vermelho para um tipo que você não pode usar."
L["Binding and level"] = "Vínculo e nível"
L["The required level is red while you are below it."] = "O nível exigido fica vermelho enquanto você estiver abaixo dele."
L["Damage per second"] = "Dano por segundo"
L["Damage and speed"] = "Dano e velocidade"
L["Armor"] = "Armadura"
L["Stats"] = "Atributos"
L["Colored by category unless set."] = "Coloridos por categoria, a menos que definidos."
L["Equip effects"] = "Efeitos de Equipado"
L["On-hit numbers use the spell tooltip's school colors unless set."] =
    "Os números dos efeitos ao acertar usam as cores de escola da dica de feitiço, a menos que definidos."
L["Enchants"] = "Encantamentos"
L["Use and other effects"] = "Usar e outros efeitos"
L["Flavor text"] = "Texto de ambientação"
L["Set name and count"] = "Nome e contagem do conjunto"
L["Set pieces"] = "Peças do conjunto"
L["Owned pieces bright, missing ones grey, unless set."] =
    "Peças que você tem claras, as que faltam cinza, a menos que definidas."
L["Set bonuses"] = "Bônus de conjunto"
L["Active bonuses green, inactive ones grey, unless set."] =
    "Bônus ativos verdes, inativos cinza, a menos que definidos."
L["Other addons' rows"] = "Linhas de outros addons"
L["Durability, crafter, requirements, and sell price."] = "Durabilidade, artesão, requisitos e preço de venda."
L["Item level badge"] = "Placa de nível do item"
L["Crafted item's name"] = "Nome do item criado"
L["On recipes; quality color unless set."] = "Em receitas; cor de qualidade, a menos que definida."
L["On recipes; the count you carry red while short, unless set."] =
    "Em receitas; a quantidade que você carrega em vermelho se faltar, a menos que definida."
L["Section captions"] = "Títulos de seção"
L["Creates and Reagents on recipes."] = "Cria e Reagentes nas receitas."
L["Disenchant results"] = "Resultados de desencantar"
L["The Enchanting needed red while yours is too low, grey without Enchanting, unless set."] =
    "O Encantamento necessário em vermelho enquanto o seu for baixo demais, cinza sem Encantamento, a menos que definido."
L["Spell name"] = "Nome do feitiço"
L["School and rank badges"] = "Placas de escola e grau"
L["Colored by school unless set."] = "Coloridas pela escola, a menos que definidas."
L["Cost, cast, cooldown, range"] = "Custo, lançamento, recarga, alcance"
L["The cost takes its resource color unless set."] = "O custo usa a cor do recurso, a menos que definida."
L["Strip captions"] = "Legendas da faixa"
L["Requirements and details"] = "Requisitos e detalhes"
L["Unmet requirements red, time remaining orange, unless set."] =
    "Requisitos não cumpridos em vermelho, tempo restante em laranja, a menos que definidos."
L["Description"] = "Descrição"
L["Numbers in the school color unless set."] = "Números na cor da escola, a menos que definidos."
L["Object name"] = "Nome do objeto"
L["Kind of object"] = "Tipo de objeto"
L["Tinted by the skill it needs, unless set."] = "Tingido pela perícia necessária, a menos que definido."
L["Skill and requirements"] = "Perícia e requisitos"
L["The skill in its skill-up color, unmet requirements red, unless set."] =
    "A perícia na cor de progresso, requisitos não cumpridos em vermelho, a menos que definidos."
L["Quest lines"] = "Linhas de missão"
L["Quest names gold, finished objectives green, unless set."] =
    "Nomes de missão dourados, objetivos cumpridos em verde, a menos que definidos."
L["Contents"] = "Conteúdo"
L["A herb or ore node's yield over its taps, then what else it may hold and the chance each tap. Turned off by Gathering contents in the options."] =
    "O rendimento de uma planta ou veio de minério em todas as coletas, depois o que mais pode conter e a chance a cada coleta. Desligado por Coleta nas opções."
L["Prices"] = "Preços"
L["The yielded item's sell price, and its auction price with Auctionator."] =
    "O preço de venda do item obtido, e seu preço no leilão com o Auctionator."
L["Name"] = "Nome"
L["Class color for players, reaction color for NPCs, unless set."] =
    "Cor da classe para jogadores, cor de reação para PNJs, a menos que definida."
L["Guild or role"] = "Guilda ou função"
L["Level, race, and class"] = "Nível, raça e classe"
L["The level in its difficulty color, unless set."] = "O nível na cor de dificuldade, a menos que definido."
L["Badges"] = "Placas"
L["Elite, rare, faction, PvP, AFK, and dead."] = "Elite, raro, facção, JxJ, ausente e morto."
L["Skinning"] = "Esfolamento"
L["On a dead creature that can be skinned: the Skinning it needs, in its skill-up color, and what it may give. Turned off by Gathering contents in the options."] =
    "Em uma criatura morta que pode ser esfolada: o Esfolamento necessário, na cor de progresso, e o que pode dar. Desligado por Coleta nas opções."
L["Target and owner"] = "Alvo e dono"
L["Buff or debuff, dispel type in the game's colors, and stacks."] =
    "Bônus ou penalidade, tipo de dissipação nas cores do jogo, e acúmulos."
L["Numbers in the aura's color unless set."] = "Números na cor da aura, a menos que definidos."
L["Time and caster"] = "Duração e lançador"
L["Quest name"] = "Nome da missão"
L["Dungeon"] = "Masmorra"
L["The level in its difficulty color, tags, and where the quest stands."] =
    "O nível na cor de dificuldade, as marcações e o andamento da missão."
L["Section caption"] = "Título de seção"
L["Objectives"] = "Objetivos"
L["Finished objectives green unless set."] = "Objetivos cumpridos em verde, a menos que definidos."
L["Macro lines"] = "Linhas de macro"
L["Commands gold, conditions grey, unless set."] = "Comandos dourados, condições cinza, a menos que definidos."

-- The options page ---------------------------------------------------------------

L["A full reskin of tooltips. Changes apply the next time a tooltip opens."] =
    "Um novo visual completo para as dicas. As mudanças valem na próxima vez que uma dica abrir."
L["Open the style editor"] = "Abrir o editor de estilo"
L["Style editor"] = "Editor de estilo"
L["The look of every kind of tooltip, with a live sample: fonts, sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, as disenchant results, the spell power breakdown, and the health bar. Also /ptip."] =
    "O visual de cada tipo de dica, com um exemplo ao vivo: fontes, tamanhos e cores de cada parte, tamanho do texto, tons e opacidades, e os detalhes próprios de cada tipo, como os resultados de desencantar, a divisão de poder mágico e a barra de vida. Também com /ptip."
L["Restyled Tooltips"] = "Dicas redesenhadas"
L["Restyle"] = "Redesenhar"
L["Follow cursor"] = "Seguir o cursor"
L["Disable in combat"] = "Desativar em combate"
L["Use the default tooltip position during combat, then resume following the cursor afterward."] =
    "Usar a posição padrão da dica durante o combate e voltar a seguir o cursor depois."
L["Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip, with the details modifier's rows added to it."] =
    "Desenha o painel do PrettyTooltip. Desligado, este tipo mantém a dica do jogo, com as linhas da tecla para os detalhes adicionadas."
L["Not restyled yet; this kind keeps the game's own tooltip."] =
    "Ainda não redesenhado; este tipo mantém a dica do jogo."
L["Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags and other panels keep theirs. Off, its position is left to the game and other addons."] =
    "Mostra a dica deste tipo junto ao cursor quando o jogo a colocaria no canto padrão; bolsas e outros painéis mantêm a sua. Desligado, a posição fica a cargo do jogo e de outros addons."
L["Restyle items"] = "Redesenhar itens"
L["Restyle spells"] = "Redesenhar feitiços"
L["Restyle players and npcs"] = "Redesenhar jogadores e PNJs"
L["Restyle buffs and debuffs"] = "Redesenhar bônus e penalidades"
L["Restyle weapon imbues"] = "Redesenhar imbuições de arma"
L["Restyle herbs, ore, chests, and other objects"] = "Redesenhar plantas, minérios, baús e outros objetos"
L["Restyle flight paths"] = "Redesenhar rotas de voo"
L["Restyle quests"] = "Redesenhar missões"
L["Restyle macros"] = "Redesenhar macros"
L["Restyle currencies"] = "Redesenhar moedas"
L["Restyle dungeon and raid lockouts"] = "Redesenhar vínculos de masmorra e raide"
L["Restyle pet abilities"] = "Redesenhar habilidades de ajudante"
L["Restyle minimap"] = "Redesenhar o minimapa"
L["Restyle mounts, toys, and pets"] = "Redesenhar montarias, brinquedos e mascotes"
L["Restyle achievements"] = "Redesenhar conquistas"
L["Restyle totems"] = "Redesenhar totens"
L["Restyle flyout buttons"] = "Redesenhar botões expansíveis"
L["Players and NPCs"] = "Jogadores e PNJs"
L["Buffs and debuffs"] = "Bônus e penalidades"
L["Weapon imbues"] = "Imbuições de arma"
L["Herbs, ore, chests, and other objects"] = "Plantas, minérios, baús e outros objetos"
L["Flight paths"] = "Rotas de voo"
L["Currencies"] = "Moedas"
L["Dungeon and raid lockouts"] = "Vínculos de masmorra e raide"
L["Pet abilities"] = "Habilidades de ajudante"
L["Minimap"] = "Minimapa"
L["Mounts, toys, and pets"] = "Montarias, brinquedos e mascotes"
L["Achievements"] = "Conquistas"
L["Totems"] = "Totens"
L["Flyout buttons"] = "Botões expansíveis"
L["Layout Style"] = "Estilo de layout"
L["PrettyTooltip"] = "PrettyTooltip"
L["Draw the PrettyTooltip panel for each kind turned on under Restyled Tooltips."] =
    "Desenha o painel do PrettyTooltip para cada tipo ligado em Dicas redesenhadas."
L["Keep the game's own tooltips. Item Equip effects are shortened, and the details modifier adds disenchant results, the spell power breakdown and rates, gathering contents, and IDs."] =
    "Mantém as dicas do jogo. Os efeitos de Equipado dos itens são encurtados, e a tecla para os detalhes adiciona os resultados de desencantar, a divisão de poder mágico e as taxas, o conteúdo de coleta e os IDs."
L["Default Tooltip Modifier"] = "Tecla para a dica do jogo"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Never"] = "Nunca"
L["Hold Ctrl to see the game's own tooltip instead of the panel."] =
    "Segure Ctrl para ver a dica do jogo em vez do painel."
L["Hold Alt to see the game's own tooltip instead of the panel."] =
    "Segure Alt para ver a dica do jogo em vez do painel."
L["Never show the game's own tooltip in place of the panel."] = "Nunca mostrar a dica do jogo no lugar do painel."
L["Tooltip Details Modifier"] = "Tecla para os detalhes"
L["Shift"] = "Shift"
L["Always Show"] = "Mostrar sempre"
L["Hold Shift to see disenchant results, the spell power breakdown and rates, gathering contents, and IDs. Each can still be turned off in the style editor."] =
    "Segure Shift para ver os resultados de desencantar, a divisão de poder mágico e as taxas, o conteúdo de coleta e os IDs. Cada um ainda pode ser desligado no editor de estilo."
L["Always show disenchant results, the spell power breakdown and rates, gathering contents, and IDs, as each one's setting in the style editor allows."] =
    "Mostra sempre os resultados de desencantar, a divisão de poder mágico e as taxas, o conteúdo de coleta e os IDs, conforme a configuração de cada um no editor de estilo."
L["Style Editor Appearance"] = "Visual do editor de estilo"
L["Blizzard"] = "Blizzard"
L["Use the game's settings frame borders and controls."] = "Usar as bordas e os controles da janela de opções do jogo."
L["Use the flat editor appearance."] = "Usar o visual plano do editor."

-- Commands and the report window.
L["PrettyTooltip: hover something first; there is no tooltip to dump."] =
    "PrettyTooltip: passe o cursor sobre algo primeiro; não há dica para exibir."
L["PrettyTooltip: this tooltip cannot be read right now (%s)."] =
    "PrettyTooltip: esta dica não pode ser lida agora (%s)."
L["PrettyTooltip: the options cannot open during combat. Try again once it ends."] =
    "PrettyTooltip: as opções não podem ser abertas em combate. Tente de novo quando ele terminar."
L["Press Ctrl+C to copy the selected text, and paste it into your bug report."] =
    "Pressione Ctrl+C para copiar o texto selecionado e cole-o no seu relatório de erro."
L["Select all"] = "Selecionar tudo"

-- The samples ---------------------------------------------------------------------
-- The names of quests, people, and places are guesses at the Portuguese
-- client's; a reviewer should check them against the client.

L["Axe"] = "Machado"
L["Plate"] = "Placas"
L["Polearm"] = "Arma de haste"
L["Mail"] = "Malha"
L["Consumable"] = "Consumível"
L["Plans"] = "Diagrama"
L["Shields"] = "Escudos"
L["Human"] = "Humano"
L["Humanoid"] = "Humanoide"
L["Beast"] = "Fera"
L["Innkeeper"] = "Taverneiro"
L["Your attacks have a chance to cleave a nearby enemy."] =
    "Seus ataques têm chance de atingir também um inimigo próximo."
L["Wounds the target for 40 to 60 damage."] = "Fere o alvo, causando de 40 a 60 de dano."
L["Sample flavor text sits here, in gold."] = "Um texto de ambientação de exemplo, em dourado."
L["Redemption Armor"] = "Armadura da Redenção"
L["Increases the amount healed by your Judgement of Light by 20."] =
    "Aumenta em 20 a cura do seu Julgamento da Luz."
L["Reduces cooldown on your Lay on Hands by 12 min."] = "Reduz em 12 min a recarga da sua Imposição das Mãos."
L["Dropped by: %s"] = "Saque de: %s"
L["Argent Dawn"] = "Aurora Argêntea"
L["Restores 1050 to 1750 health."] = "Restaura de 1050 a 1750 de vida."
L["A schedule of gold pickups."] = "Uma agenda de coletas de ouro."
L["Hurls a fiery ball that causes 16 to 25 Fire damage and an additional 2 Fire damage over 4 sec."] =
    "Arremessa uma bola flamejante que causa de 16 a 25 de dano de Fogo e mais 2 de dano de Fogo ao longo de 4 s."
L["Bashes the target with your shield for 8 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 6 sec."] =
    "Golpeia o alvo com seu escudo, causando 8 de dano. Também interrompe o lançamento de feitiços e impede feitiços dessa escola por 6 s."
L["Heals a friendly target for 42 to 51."] = "Cura um alvo amigo em 42 a 51."
L["Spell ID: %s"] = "ID do feitiço: %s"
L["Gathered here %s times"] = "Coletado aqui %s vezes"
L["Bruiseweed"] = "Ervamossa"
L["Mithril Deposit"] = "Depósito de Mithril"
L["Battered Chest"] = "Baú Surrado"
L["Sealed Supply Crate"] = "Caixa de Suprimentos Lacrada"
L["Heavy Supplies"] = "Suprimentos Pesados"
L["Supply Crate: 2/5"] = "Caixa de Suprimentos: 2/5"
L["Report to the quartermaster"] = "Apresente-se ao intendente"
L["Defias Pillager"] = "Pilhador Défias"
L["The Defias Brotherhood"] = "A Irmandade Défias"
L["Defias Pillager slain: 4/10"] = "Pilhador Défias morto: 4/10"
L["Innkeeper Farley"] = "Taverneiro Farley"
L["Mother Fang"] = "Mãe Presa"
L["Foe Reaper 4000"] = "Ceifa-inimigos 4000"
L["Increases Stamina by 26."] = "Aumenta o Vigor em 26."
L["Causes 84 Shadow damage over 24 sec. This damage is dealt slowly at first, and builds up as the Curse reaches its full duration."] =
    "Causa 84 de dano de Sombra ao longo de 24 s. Esse dano é lento no início e aumenta conforme a Maldição chega à duração total."
L["Inflicts 9 Nature damage every 3 sec."] = "Inflige 9 de dano de Natureza a cada 3 s."
L["The Fury Runs Deep"] = "Fúria profunda"
L["Arugal Must Die"] = "Arugal tem que morrer"
L["The Stockade"] = "O Cárcere"
L["Shadowfang Keep"] = "Bastilha da Presa Negra"
L["Silverpine Forest"] = "Floresta de Pinhaprata"
L["Wolves Across the Border"] = "Só louco não come lobo"
L["Dalar Dawnweaver"] = "Dalar Teceaurora"
L["Motley Garmason wants Kam Deepfury's head brought to him at Dun Modr."] =
    "Motley Garmason quer que você leve a cabeça de Kam Fúria Funda até ele em Dun Modr."
L["Eliminate the wolves to the east of Northshire and bring their paws to Eagan Peltskinner."] =
    "Elimine os lobos a leste de Vila Norte e leve as patas deles para Eagan Esfolapele."
L["Dalar Dawnweaver wants Arugal dead and his head brought to him."] =
    "Dalar Teceaurora quer Arugal morto e a cabeça dele entregue a ele."
L["Ended by"] = "Concluída com"
L["Started by"] = "Iniciada por"
L["Found in"] = "Encontrado em"
L["Rares"] = "Raros"
