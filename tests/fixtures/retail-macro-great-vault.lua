-- Captured with /ptip capture macro on 2026-10-23 08:14.
return {
    calls = {
        ["C_AddOns.GetAddOnInfo"] = {
            Auctionator = {
                [1] = "Auctionator",
                [2] = "Auctionator",
                [3] = "A lightweight addon that makes it easy and fast to buy, sell and manage auctions",
                [4] = true,
                [5] = "",
                [6] = "INSECURE",
                n = 6,
            },
            DialogueUI = {
                [1] = "DialogueUI",
                [2] = "Dialogue UI",
                [3] = "Quest Dialogue UI",
                [4] = true,
                [5] = "",
                [6] = "INSECURE",
                n = 6,
            },
            EllesmereUI = {
                [1] = "EllesmereUI",
                [4] = false,
                [5] = "MISSING",
                [6] = "INSECURE",
                n = 6,
            },
            Questie = {
                [1] = "Questie",
                [4] = false,
                [5] = "MISSING",
                [6] = "INSECURE",
                n = 6,
            },
        },
        GetMacroIndexByName = {
            ["Great Vault"] = {
                [1] = 12,
                n = 1,
            },
        },
        GetMacroInfo = {
            ["1"] = {
                [1] = "_M6+s01",
                [2] = 1074161825,
                [3] = "#showtooltip\n#m6\n/click M6Prime s01\n",
                n = 3,
            },
            ["10"] = {
                [1] = "EnhanceQoLFlaskMacro",
                [2] = 7548903,
                [3] = "#showtooltip item:241326\n/use item:241326\n",
                n = 3,
            },
            ["11"] = {
                [1] = "EnhanceQoLHealthMacro",
                [2] = 136074,
                [3] = "#showtooltip\n/cast [nocombat] Recuperate\n/castsequence [combat] reset=combat item:241305\n",
                n = 3,
            },
            ["12"] = {
                [1] = "Great Vault",
                [2] = 1850547,
                [3] = "/run C_AddOns.LoadAddOn(\"Blizzard_WeeklyRewards\"); WeeklyRewardsFrame:Show()\n",
                n = 3,
            },
            ["121"] = {
                [1] = "Hammer",
                [2] = 135963,
                [3] = "#showtooltip\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][@target] Hammer of Justice\n",
                n = 3,
            },
            ["122"] = {
                [1] = "Holy Shock",
                [2] = 134400,
                [3] = "#showtooltip\n/cast [@mouseover,exists][@focus,exists][] Holy Shock\n",
                n = 3,
            },
            ["123"] = {
                [1] = "Judgement",
                [2] = 135959,
                [3] = "#showtooltip\n/cast [@mouseover,harm,exists][@target,harm,exists][] Judgment\n",
                n = 3,
            },
            ["124"] = {
                [1] = "Rebuke",
                [2] = 523893,
                [3] = "#showtooltip\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][@target] Rebuke\n",
                n = 3,
            },
            ["125"] = {
                [1] = "Summer",
                [2] = 134400,
                [3] = "#showtooltip\n/use [@self]Blessing of Winter\n/use [@self]Blessing of Spring\n/use [@mouseover][@focus,help][@target,help][@self]Blessing of Autumn\n/use [@mouseover][@focus,help][@target,help][@self]Blessing of Summer\n",
                n = 3,
            },
            ["13"] = {
                [1] = "HealTrinket",
                [2] = 338784,
                [3] = "#showtooltip\n/use [@mouseover,help][@target, help][@player][]14\n",
                n = 3,
            },
            ["14"] = {
                [1] = "Kick",
                [2] = 134400,
                [3] = "#showtooltip\n/stopcasting\n/cast [@mouseover,harm][harm,@focus][@target,harm][] Wind Shear\n",
                n = 3,
            },
            ["15"] = {
                [1] = "KickFocus",
                [2] = 134400,
                [3] = "#showtooltip\n/stopcasting\n/cast [harm,@focus]Wind Shear\n",
                n = 3,
            },
            ["16"] = {
                [1] = "MISTS",
                [2] = 413591,
                [3] = "/run BattlefieldMapFrame:Show()\n/run BattlefieldMapFrame:SetScale(1.5)\n/run BattlefieldMapFrame:InstantPanAndZoom(0.65, 0.6, 0.35)\n/cleartarget\n/tar Mistcaller\n/tar Mistveil Matria\n/tar Mistveil Nightb\n",
                n = 3,
            },
            ["17"] = {
                [1] = "Moon",
                [2] = 134400,
                [3] = "/worldmarker 7\n",
                n = 3,
            },
            ["18"] = {
                [1] = "Skull",
                [2] = 134400,
                [3] = "/worldmarker 8\n",
                n = 3,
            },
            ["19"] = {
                [1] = "Square",
                [2] = 1990984,
                [3] = "/worldmarker 1\n",
                n = 3,
            },
            ["2"] = {
                [1] = "Asc/HTT",
                [2] = 134400,
                [3] = "#showtooltip\n/cast [known:Ascendance]Ascendance;[known:Healing Tide Totem]Healing Tide Totem\n",
                n = 3,
            },
            ["20"] = {
                [1] = "Star",
                [2] = 134400,
                [3] = "/worldmarker 5\n",
                n = 3,
            },
            ["21"] = {
                [1] = "Stop",
                [2] = 132094,
                [3] = "/stopcasting\n",
                n = 3,
            },
            ["22"] = {
                [1] = "TBoth",
                [2] = 135241,
                [3] = "#showtooltip 13\n#show 13\n/use 13\n/use 14\n",
                n = 3,
            },
            ["23"] = {
                [1] = "Triangle",
                [2] = 1990985,
                [3] = "/worldmarker 2\n",
                n = 3,
            },
            ["24"] = {
                [1] = "Trinket1",
                [2] = 135241,
                [3] = "#showtooltip 13\n#show 13\n/use 13\n",
                n = 3,
            },
            ["25"] = {
                [1] = "Trinket2",
                [2] = 338784,
                [3] = "#showtooltip 14\n#show 14\n/use [@cursor][@player][] 14\n",
                n = 3,
            },
            ["26"] = {
                [1] = "Wraps",
                [2] = 413580,
                [3] = "/run GenericTraitUI_LoadUI()GenericTraitFrame:SetSystemID(29)GenericTraitFrame:SetTreeID(1115)ToggleFrame(GenericTraitFrame)\n",
                n = 3,
            },
            ["3"] = {
                [1] = "Circle",
                [2] = 1990986,
                [3] = "/worldmarker 6\n",
                n = 3,
            },
            ["32"] = {
                n = 0,
            },
            ["4"] = {
                [1] = "Clear",
                [2] = 135768,
                [3] = "/clearworldmarker 0\n",
                n = 3,
            },
            ["5"] = {
                [1] = "Cross",
                [2] = 134400,
                [3] = "/worldmarker 4\n",
                n = 3,
            },
            ["6"] = {
                [1] = "Diamond",
                [2] = 1990987,
                [3] = "/worldmarker 3\n",
                n = 3,
            },
            ["7"] = {
                [1] = "Drinking",
                [2] = 3717419,
                [3] = "/p MANA!\n",
                n = 3,
            },
            ["8"] = {
                [1] = "EngRes",
                [2] = 134400,
                [3] = "#showtooltip\n/use [@mouseover,dead][@target,dead][]Disposable Spectrophasic Reanimator\n",
                n = 3,
            },
            ["9"] = {
                [1] = "EnhanceQoLDrinkMacro",
                [2] = 967547,
                [3] = "#showtooltip\n/castsequence reset=combat item:260261\n",
                n = 3,
            },
            ["Great Vault"] = {
                [1] = "Great Vault",
                [2] = 1850547,
                [3] = "/run C_AddOns.LoadAddOn(\"Blizzard_WeeklyRewards\"); WeeklyRewardsFrame:Show()\n",
                n = 3,
            },
        },
        GetMacroItem = {
            ["1"] = {
                n = 0,
            },
            ["10"] = {
                [1] = "Flask of the Shattered Sun",
                [2] = "|cnIQ1:|Hitem:241326::::::::80:66:::::::::|h[Flask of the Shattered Sun |A:Professions-ChatIcon-Quality-12-Tier2:17:15::1|a]|h|r",
                n = 2,
            },
            ["11"] = {
                n = 0,
            },
            ["12"] = {
                n = 0,
            },
            ["121"] = {
                n = 0,
            },
            ["122"] = {
                n = 0,
            },
            ["123"] = {
                n = 0,
            },
            ["124"] = {
                n = 0,
            },
            ["125"] = {
                n = 0,
            },
            ["13"] = {
                n = 0,
            },
            ["14"] = {
                n = 0,
            },
            ["15"] = {
                n = 0,
            },
            ["16"] = {
                n = 0,
            },
            ["17"] = {
                n = 0,
            },
            ["18"] = {
                n = 0,
            },
            ["19"] = {
                n = 0,
            },
            ["2"] = {
                n = 0,
            },
            ["20"] = {
                n = 0,
            },
            ["21"] = {
                n = 0,
            },
            ["22"] = {
                [1] = "Faded Ebony Scale",
                [2] = "|cnIQ4:|Hitem:223513::::::::80:66::3:4:10341:11311:3209:8767:1:28:2474:::::|h[Faded Ebony Scale]|h|r",
                n = 2,
            },
            ["23"] = {
                n = 0,
            },
            ["24"] = {
                n = 0,
            },
            ["25"] = {
                n = 0,
            },
            ["26"] = {
                n = 0,
            },
            ["3"] = {
                n = 0,
            },
            ["4"] = {
                n = 0,
            },
            ["5"] = {
                n = 0,
            },
            ["6"] = {
                n = 0,
            },
            ["7"] = {
                n = 0,
            },
            ["8"] = {
                n = 0,
            },
            ["9"] = {
                [1] = "Bloom Nectar",
                [2] = "|cnIQ1:|Hitem:260261::::::::80:66:::::::::|h[Bloom Nectar]|h|r",
                n = 2,
            },
        },
        GetMacroSpell = {
            ["1"] = {
                n = 0,
            },
            ["10"] = {
                n = 0,
            },
            ["11"] = {
                [1] = 1231411,
                n = 1,
            },
            ["12"] = {
                n = 0,
            },
            ["121"] = {
                [1] = 853,
                n = 1,
            },
            ["122"] = {
                n = 0,
            },
            ["123"] = {
                [1] = 275779,
                n = 1,
            },
            ["124"] = {
                [1] = 96231,
                n = 1,
            },
            ["125"] = {
                n = 0,
            },
            ["13"] = {
                n = 0,
            },
            ["14"] = {
                n = 0,
            },
            ["15"] = {
                n = 0,
            },
            ["16"] = {
                n = 0,
            },
            ["17"] = {
                n = 0,
            },
            ["18"] = {
                n = 0,
            },
            ["19"] = {
                n = 0,
            },
            ["2"] = {
                n = 0,
            },
            ["20"] = {
                n = 0,
            },
            ["21"] = {
                n = 0,
            },
            ["22"] = {
                n = 0,
            },
            ["23"] = {
                n = 0,
            },
            ["24"] = {
                n = 0,
            },
            ["25"] = {
                n = 0,
            },
            ["26"] = {
                n = 0,
            },
            ["3"] = {
                n = 0,
            },
            ["4"] = {
                n = 0,
            },
            ["5"] = {
                n = 0,
            },
            ["6"] = {
                n = 0,
            },
            ["7"] = {
                n = 0,
            },
            ["8"] = {
                n = 0,
            },
            ["9"] = {
                n = 0,
            },
        },
        GetNumMacros = {
            [""] = {
                [1] = 26,
                [2] = 5,
                n = 2,
            },
        },
        GetProfessionInfo = {
            ["6"] = {
                [1] = "Herbalism",
                [2] = 4620675,
                [3] = 54,
                [4] = 100,
                [5] = 2,
                [6] = 197,
                [7] = 182,
                [8] = 0,
                [9] = -1,
                [10] = 0,
                [11] = "Midnight Herbalism",
                n = 11,
            },
            ["7"] = {
                [1] = "Mining",
                [2] = 4620679,
                [3] = 63,
                [4] = 100,
                [5] = 2,
                [6] = 203,
                [7] = 186,
                [8] = 0,
                [9] = -1,
                [10] = 0,
                [11] = "Midnight Mining",
                n = 11,
            },
        },
        GetProfessions = {
            [""] = {
                [1] = 6,
                [2] = 7,
                n = 6,
            },
        },
        GetQuestDifficultyColor = {
            ["1"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["10"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["11"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["12"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["13"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["14"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["15"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["16"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["17"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["18"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["19"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["2"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["20"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["21"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["22"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["23"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["24"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["25"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["26"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["27"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["28"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["29"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["3"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["30"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["31"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["32"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["33"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["34"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["35"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["36"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["37"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["38"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["39"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["4"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["40"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["41"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["42"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["43"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["44"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["45"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["46"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["47"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["48"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["49"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["5"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["50"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["51"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["52"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["53"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["54"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["55"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["56"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["57"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["58"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["59"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["6"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["60"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["61"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["62"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["63"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["7"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["8"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
            ["9"] = {
                [1] = {
                    b = 0.5,
                    font = "QuestDifficulty_Trivial",
                    g = 0.5,
                    r = 0.5,
                },
                [2] = {
                    b = 0.69999999999999996,
                    font = "QuestDifficulty_Trivial",
                    g = 0.69999999999999996,
                    r = 0.69999999999999996,
                },
                n = 2,
            },
        },
        GetSpellBonusDamage = {
            ["1"] = {
                [1] = 0,
                n = 1,
            },
            ["2"] = {
                [1] = 522,
                n = 1,
            },
            ["3"] = {
                [1] = 522,
                n = 1,
            },
            ["4"] = {
                [1] = 522,
                n = 1,
            },
            ["5"] = {
                [1] = 522,
                n = 1,
            },
            ["6"] = {
                [1] = 522,
                n = 1,
            },
            ["7"] = {
                [1] = 522,
                n = 1,
            },
        },
        GetSpellBonusHealing = {
            [""] = {
                [1] = 568,
                n = 1,
            },
        },
        NumTaxiNodes = {
            [""] = {
                [1] = 0,
                n = 1,
            },
        },
        UnitClass = {
            player = {
                [1] = "Paladin",
                [2] = "PALADIN",
                [3] = 2,
                n = 3,
            },
        },
        UnitFactionGroup = {
            player = {
                [1] = "Alliance",
                [2] = "Alliance",
                n = 2,
            },
        },
        UnitLevel = {
            player = {
                [1] = 80,
                n = 1,
            },
        },
        UnitName = {
            player = {
                [1] = "Player",
                n = 2,
            },
        },
        UnitRace = {
            player = {
                [1] = "Dwarf",
                [2] = "Dwarf",
                [3] = 3,
                n = 3,
            },
        },
    },
    captured = "2026-10-23 08:14",
    client = {
        build = "70529",
        locale = "enUS",
        version = "12.1.5",
    },
    comparisons = {},
    data = {
        dataInstanceID = 2378,
        id = 32,
        lines = {
            {
                leftColor = {
                    b = 1,
                    color = true,
                    g = 1,
                    r = 1,
                },
                leftText = "Great Vault",
                lineIndex = 1,
                type = 0,
            },
        },
        type = 25,
    },
    enums = {
        ItemClass = {
            Armor = 4,
            Battlepet = 17,
            Consumable = 0,
            Container = 1,
            CurrencyTokenObsolete = 10,
            Gem = 3,
            Glyph = 16,
            Housing = 20,
            ItemEnhancement = 8,
            Key = 13,
            Miscellaneous = 15,
            PermanentObsolete = 14,
            Profession = 19,
            Projectile = 6,
            Questitem = 12,
            Quiver = 11,
            Reagent = 5,
            Recipe = 9,
            Tradegoods = 7,
            Weapon = 2,
            WoWToken = 18,
        },
        TooltipDataItemBinding = {
            Account = 1,
            AccountUntilEquipped = 9,
            BindOnEquip = 7,
            BindOnPickup = 6,
            BindOnUse = 8,
            BindToAccount = 4,
            BindToAccountUntilEquipped = 10,
            BindToBnetAccount = 5,
            BnetAccount = 2,
            Quest = 0,
            Soulbound = 3,
        },
        TooltipDataLineType = {
            AuraCaster = 51,
            AzeriteEssencePower = 5,
            AzeriteEssenceSlot = 4,
            AzeriteItemPowerDescription = 9,
            Blank = 1,
            CurrencyTotal = 14,
            DisabledLine = 42,
            EquipSlot = 21,
            ErrorLine = 41,
            FlavorText = 37,
            GemSocket = 3,
            GemSocketEnchantment = 30,
            ItemBinding = 20,
            ItemEnchantmentPermanent = 15,
            ItemLevel = 31,
            ItemName = 22,
            ItemQuality = 35,
            ItemSpellTriggerLearn = 38,
            ItemSpellTriggerOnEquip = 45,
            ItemSpellTriggerOnProc = 46,
            ItemSpellTriggerOnUse = 44,
            ItemUpgradeLevel = 32,
            LearnTransmogIllusion = 40,
            LearnTransmogSet = 39,
            LearnableSpell = 6,
            NestedBlock = 19,
            None = 0,
            ProfessionCraftingQuality = 12,
            QuestObjective = 8,
            QuestPlayer = 18,
            QuestTitle = 17,
            RuneforgeLegendaryPowerDescription = 10,
            SellPrice = 11,
            Separator = 23,
            SpellDescription = 34,
            SpellName = 13,
            SpellPassive = 33,
            ToyDescription = 28,
            ToyDuration = 27,
            ToyEffect = 26,
            ToyName = 24,
            ToySource = 29,
            ToyText = 25,
            TradeTimeRemaining = 36,
            UnitCriteriaProgress = 50,
            UnitDead = 49,
            UnitLevel = 47,
            UnitName = 2,
            UnitOwner = 16,
            UnitThreat = 7,
            UnitType = 48,
            UsageRequirement = 43,
        },
        TooltipDataType = {
            Achievement = 12,
            AzeriteEssence = 8,
            BattlePet = 6,
            CompanionPet = 9,
            Corpse = 3,
            CorruptionCleanser = 20,
            Currency = 5,
            Debug = 26,
            EnhancedConduit = 13,
            EquipmentSet = 14,
            Flyout = 22,
            InstanceLock = 15,
            Item = 0,
            Macro = 25,
            MinimapMouseover = 21,
            Mount = 10,
            Object = 4,
            Outfit = 27,
            PetAction = 11,
            PvPBrawl = 16,
            Quest = 23,
            QuestPartyProgress = 24,
            RecipeRankInfo = 17,
            Spell = 1,
            Totem = 18,
            Toy = 19,
            Unit = 2,
            UnitAura = 7,
        },
    },
    hidden = 0,
    lines = {
        {
            left = {
                color = {
                    1,
                    1,
                    1,
                },
                shown = true,
                text = "Great Vault",
            },
            right = {
                color = {
                    1,
                    1,
                    1,
                },
                shown = false,
            },
        },
    },
    present = {
        BreakUpLargeNumbers = true,
        ["C_CurrencyInfo.GetCoinTextureString"] = true,
        ["C_Item.GetDetailedItemLevelInfo"] = true,
        ["C_Item.GetItemInfoInstant"] = true,
        ["C_Item.GetItemLocation"] = true,
        ["C_Item.GetItemNameByID"] = true,
        ["C_Item.GetStackCount"] = true,
        ["C_Item.RequestLoadItemDataByID"] = true,
        ["C_QuestLog.IsOnQuest"] = true,
        ["C_QuestLog.IsQuestFlaggedCompleted"] = true,
        ["C_Spell.GetSpellName"] = true,
        ["C_Spell.GetSpellTexture"] = true,
        ["C_UnitAuras.GetAuraDataByAuraInstanceID"] = true,
        ["C_UnitAuras.GetAuraDataByIndex"] = true,
        GetCoinTextureString = false,
        GetInboxItem = true,
        GetInboxItemLink = true,
        GetMacroIndexByName = true,
        GetMacroInfo = true,
        GetMacroItem = true,
        GetMacroSpell = true,
        GetNumMacros = true,
        GetNumSkillLines = false,
        GetPetActionInfo = true,
        GetProfessionInfo = true,
        GetProfessions = true,
        GetSkillLineInfo = false,
        GetSpellInfo = false,
        GetSpellTexture = false,
        SetPortraitTexture = true,
        UnitAura = false,
        UnitEffectiveLevel = true,
        UnitTokenFromGUID = true,
        issecretvalue = true,
    },
    settings = {
        auraPanels = true,
        backdropAlphaUnits = 0.94999999999999996,
        backdropStyle = "native",
        bodyFont = "2002",
        cursorDisableInCombat = false,
        cursorUnits = false,
        detailsKey = "ALWAYS",
        footerAlphaUnits = 0,
        headerTopAlphaUnits = 0.68999999999999995,
        iconRight = true,
        imbuePanels = true,
        layout = "pretty",
        minWidth = 203,
        minimapPanels = false,
        originalKey = "NONE",
        qualityTint = false,
        socketHint = false,
        statColorAttack = {
            0.9803922176361084,
            0.58431375026702881,
            0.40392160415649409,
        },
        statColorCriticalStrike = {
            0,
            0.96862751245498657,
            0.02745098248124123,
        },
        statColorHaste = {
            0,
            0.9490196704864502,
            0.090196080505847931,
        },
        statColorMastery = {
            0,
            0.9490196704864502,
            0.090196080505847931,
        },
        statColorMinor = {
            0,
            0.9490196704864502,
            0.090196080505847931,
        },
        statColorPrimary = {
            0.87843143939971924,
            0.91372555494308472,
            0.89019614458084106,
        },
        statColorVersatility = {
            0,
            0.9490196704864502,
            0.090196080505847931,
        },
        styles = {
            auraName = {
                caps = false,
            },
            createdName = {
                caps = false,
            },
            enchants = {
                after = 8,
                before = 8,
                color = {
                    0,
                    0.87843143939971924,
                    0.08235294371843338,
                },
            },
            gems = {
                after = 4,
                before = 4,
                size = 13,
            },
            itemSource = {
                color = {
                    0,
                    0.87843143939971924,
                    0.08235294371843338,
                },
            },
            itemUpgrade = {
                color = {
                    0.98431378602981567,
                    0.92549026012420654,
                    0.29803922772407532,
                },
            },
            macroName = {
                caps = false,
            },
            objectTitle = {
                caps = false,
            },
            questTitle = {
                caps = false,
            },
            secondaryStats = {
                color = {
                    0,
                    0.87843143939971924,
                    0.08235294371843338,
                },
            },
            setName = {
                caps = false,
            },
            spellTitle = {
                caps = false,
            },
            title = {
                caps = false,
            },
            unitBadges = {
                size = 15,
            },
            unitName = {
                caps = false,
            },
        },
        swapDamage = true,
        titleFont = "2002",
        tooltipScale = 0.90000000000000002,
    },
    tooltip = "GameTooltip",
    tooltipType = "Macro",
}
