-- Talents as the game shows them in play: the data holds the next rank, and
-- the current rank follows a second "Passive", with no "Next Rank:" label;
-- and a panel that follows a line rewritten in place.
return function(test)
    local SPELL, PASSIVE, DESCRIPTION = 1, 51, 52
    local GOLD = { 1, .82, 0 }
    local current = "Increases the critical strike damage bonus of your Frost spells by 40%."
    local nextRank = "Increases the critical strike damage bonus of your Frost spells by 60%."
    local capture = {
        enums = { TooltipDataType = { Item = 0, Spell = SPELL },
            TooltipDataLineType = { None = 0, SpellPassive = PASSIVE, SpellDescription = DESCRIPTION } },
        data = { type = SPELL, id = 11207, lines = {
            { type = 0, lineIndex = 3, leftText = "" },
            { type = PASSIVE, lineIndex = 4, leftText = "Passive" },
            { type = DESCRIPTION, lineIndex = 5, leftText = nextRank },
        } },
        lines = {
            { left = { text = "Ice Shards" } },
            { left = { text = "Rank |cffffffff2|r/5" } },
            { left = { text = " ", color = GOLD } },
            { left = { text = "Passive" } },
            { left = { text = nextRank, color = GOLD } },
            { left = { text = "Passive" } },
            { left = { text = current, color = GOLD } },
            { left = { text = "|c0042b1fePress F6 to submit an issue for this Spell", color = GOLD } },
        },
    }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua", "Core/TooltipPlacement.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Data/Stats.lua", "Data/SpellRanks.lua", "Game/SpellAmounts.lua", "Data/Coefficients.lua", "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Spell.lua",
        "Integration/Native.lua", "Integration/Placement.lua", "Integration/Hooks.lua" },
        capture)
    local model = ns.TooltipTypes[SPELL].read(world.main, capture.data, ns.Game)
    test.check("the rank is read", { model.talent.rank, model.talent.max }, { 2, 5 })
    test.check("the current rank's text is the description", model.description, { current })
    test.check("the data's description is the next rank", model.talent.description, { nextRank })
    test.check("only other addons' rows stay", #model.extras, 1)

    -- Drawn through the game's handover, then a line rewritten in place.
    C_Timer.After = function(_, callback) callback() end
    ns.Hooks.install()
    for _, postCall in ipairs(world.postCalls[SPELL]) do postCall(world.main, capture.data) end
    local panel = ns.ui.shownPanel(world.main)
    local function shows(text)
        for _, font in ipairs(panel.pool) do
            if font._shown and ns.util.uncolored(font._text or "") == text then return true end
        end
        return false
    end
    test.check("the panel shows the next rank", shows(nextRank), true)
    local rewritten = "Increases the critical strike damage bonus of your Frost spells by 80%."
    world.main:GetLeftLine(7):SetText(rewritten)
    panel._scripts.OnUpdate(panel, .3)
    test.check("a line rewritten in place is read again", shows(rewritten), true)
end
