-- Exercise the real tooltip callbacks, rather than only the individual readers.
return function(test)
    local fixture = { enums = { TooltipDataType = { Item = 0, Object = 33, UnitAura = 7 } },
        data = { type = 33, id = 1, lines = { { lineIndex = 1, leftText = "Mailbox" } } },
        lines = { { left = { text = "Mailbox" } } } }
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua", "Data/Stats.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua", "Tooltips/Aura.lua", "Integration/Native.lua",
        "Integration/Hooks.lua", "Integration/ItemLite.lua", "Integration/Cursor.lua",
        "UI/Commands.lua", "UI/Capture.lua" }, fixture)
    local tooltip, secret, locked = world.main, world.secret, world.secretTable
    local realKey = ns.TooltipTypes[33].key
    ns.Hooks.install()
    ns.ItemLite.register()
    ns.Cursor.register()
    ns.Commands.register()
    local callback = world.postCalls[33][1]
    local function reset()
        tooltip._data = fixture.data
        tooltip:SetAlpha(1)
        callback(tooltip, fixture.data)
    end
    reset()
    local panel = ns.ui.panels[tooltip]
    test.check("ordinary callback draws the replacement", panel:IsShown(), true)
    test.check("ordinary callback hides the native tooltip", tooltip:GetAlpha(), 0)
    for _, bad in ipairs({ secret, locked, { lines = secret }, { lines = locked } }) do
        callback(tooltip, bad)
        test.check("unreadable callback data restores the native tooltip", tooltip:GetAlpha(), 1)
        test.check("unreadable callback data hides the replacement", panel:IsShown(), false)
        reset()
    end
    ns.TooltipTypes[33].key = function() error("bad third-party data") end
    callback(tooltip, fixture.data)
    test.check("a failed key function restores the native tooltip", tooltip:GetAlpha(), 1)
    test.check("a failed key function hides the replacement", panel:IsShown(), false)
    ns.TooltipTypes[33].key = realKey
    reset()
    tooltip:SetAlpha(secret)
    test.check("secret alpha stops the addon from hiding the tooltip", panel:IsShown(), false)
    test.check("the secret alpha is left for the native widget", issecretvalue(tooltip:GetAlpha()), true)
    reset()
    tooltip:GetScript("OnShow")(tooltip)
    test.check("ordinary show hooks still work after restricted content", panel:IsShown(), true)
    tooltip:SetShown(secret)
    test.check("secret visibility hook arguments do not throw", true, true)
    tooltip:SetShown(true)

    -- A forbidden/protected tooltip must receive no cosmetic mutations.
    ns.Native.restoreNative(tooltip)
    local mutations = 0
    local setAlpha = tooltip.SetAlpha
    tooltip.SetAlpha = function(...) mutations = mutations + 1 return setAlpha(...) end
    tooltip.IsForbidden = function() return true end
    callback(tooltip, fixture.data)
    ns.Native.refitNative(tooltip, panel)
    ns.Native.fadeOut(tooltip)
    test.check("forbidden tooltips are not rendered or refitted", mutations, 0)
    tooltip.IsForbidden = function() return false end
    tooltip.IsProtected = function() return true end
    callback(tooltip, fixture.data)
    test.check("protected tooltips are not restyled", mutations, 0)
    tooltip.IsProtected = function() return false end
    tooltip.SetAlpha = setAlpha

    -- Both sides of appended rows must preserve the distinction between an
    -- empty string and text that the game refused to disclose.
    local left = tooltip:GetLeftLine(1)
    local originalText = left:GetText()
    left:SetText(secret)
    test.check("secret appended text rejects the custom model", ns.TooltipData.appendedRows(tooltip, {}), nil)
    left:SetText(originalText)

    local post = world.postCalls[0][1]
    post(tooltip, locked)
    post(tooltip, 3)
    post(tooltip, { lines = 3 })
    post(tooltip, { lines = { { lineIndex = 1, leftText = secret } } })
    post(tooltip, { lines = { { lineIndex = secret } } })
    test.check("item callbacks tolerate inaccessible data and secret indices", true, true)
    local processing = tooltip.GetProcessingTooltipInfo
    tooltip.GetProcessingTooltipInfo = function() return locked end
    post(tooltip, { lines = {} })
    test.check("an inaccessible processing-info table is not indexed", true, true)
    tooltip.GetProcessingTooltipInfo = processing

    -- /ptip dump must label restricted fields, never stringify their values.
    local report
    ns.showReport = function(_, lines) report = table.concat(lines, "\n") end
    tooltip._data = { type = 33, id = secret, lines = { { type = secret, leftText = secret }, locked } }
    SlashCmdList.PRETTYTOOLTIP("dump")
    test.check("diagnostic output labels restricted values", report and report:find("<restricted>", 1, true) ~= nil, true)
    tooltip._data = nil
    left:SetText(secret)
    report = nil
    SlashCmdList.PRETTYTOOLTIP("dump")
    test.check("lines-only diagnostics label restricted text", report and report:find("<restricted>", 1, true) ~= nil, true)
    left:SetText(originalText)

    -- Cursor placement must not calculate with secret geometry or replay it.
    tooltip._data = fixture.data
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 30)
    GameTooltip_SetDefaultAnchor(tooltip, UIParent)
    local oldPoint = tooltip.GetPoint
    tooltip.GetPoint = function() return "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", secret, 30 end
    for _, hook in ipairs(world.postCalls[33]) do hook(tooltip, fixture.data) end
    tooltip.GetPoint = oldPoint
    test.check("secret anchors are not replaced by cursor placement", ({ tooltip:GetPoint() })[1], "BOTTOMRIGHT")
    GetCursorPosition = function() return secret, 100 end
    for _, hook in ipairs(world.postCalls[33]) do hook(tooltip, fixture.data) end
    test.check("secret cursor geometry does not move the tooltip", ({ tooltip:GetPoint() })[1], "BOTTOMRIGHT")

    -- Aura data may be a readable container with secret individual fields.
    local auraData = { type = 7, id = 123, lines = { { lineIndex = 1, leftText = "Buff" } } }
    tooltip.GetProcessingTooltipInfo = function()
        return { getterName = "GetUnitAuraByAuraInstanceID", getterArgs = { "player", 5 } }
    end
    ns.Game.aura = function()
        return { duration = secret, expirationTime = secret, applications = secret,
            sourceUnit = secret, dispelName = secret, isHarmful = secret, isHelpful = true }
    end
    local model = ns.TooltipTypes[7].read(tooltip, auraData, ns.Game)
    test.check("secret aura duration is not used for a timer", model.duration, nil)
    test.check("secret aura expiry is not used for a timer", model.expires, nil)
    test.check("secret aura stacks are not compared", model.stacks, nil)
    test.check("aura cache is held outside the Blizzard frame", rawget(tooltip, "prettyTooltipAura"), nil)
    test.check("aura data is cached for readable redraws", ns.keptAuras[tooltip] ~= nil, true)
    tooltip:GetScript("OnTooltipCleared")(tooltip)
    test.check("clearing the tooltip releases cached aura data", ns.keptAuras[tooltip], nil)
    tooltip.GetProcessingTooltipInfo = function() return locked end
    model = ns.TooltipTypes[7].read(tooltip, auraData, ns.Game)
    test.check("inaccessible processing info leaves a plaintext aura", model.name, "Buff")
    test.check("inaccessible processing info adds no timer", model.duration, nil)

    -- A deferred callback must check frame access again, not rely on the
    -- permissions that applied when its tooltip was first rendered.
    local pending = {}
    C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
    callback(tooltip, fixture.data)
    tooltip.IsForbidden = function() return true end
    tooltip.IsShown = function() error("must not query a now-forbidden tooltip") end
    for _, fn in ipairs(pending) do fn() end
    test.check("deferred work rechecks permissions before accessing the tooltip", true, true)
end
