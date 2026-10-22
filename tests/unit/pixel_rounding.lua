-- Rounding is per region, including pool entries created after the first draw.
-- The harness records this policy; only the client can verify rasterization.
return function(test)
    local ns, world = test.load({ "Core/Util.lua", "Core/Palette.lua", "Core/Settings.lua",
        "Locale/Locale.lua", "Locale/English.lua", "Game/Game.lua", "Game/TooltipData.lua",
        "Panel/Layout.lua", "Panel/Render.lua", "Tooltips/Object.lua" },
        { enums = { TooltipDataType = { Item = 0, Object = 4 } } })
    local ui = ns.ui
    GetPhysicalScreenSize = function() return 1920, 1080 end
    UIParent:SetScale(.8)
    ns.setOption("backdropStyle", "native")

    local function roundedTree(region)
        if not region:GetRoundLayoutToNearestPixel() then return false end
        for _, child in ipairs(region._children) do
            if not roundedTree(child) then return false end
        end
        return true
    end

    local anchor = CreateFrame("Frame", nil, UIParent)
    local model = ui.objectModel({ name = "Mailbox", details = {}, quests = {}, extras = {} })
    local preview
    for _, scale in ipairs({ .75, 1, 1.25 }) do
        ns.setOption("tooltipScale", scale)
        preview = ui.renderPreview(anchor, model, 4)
        test.check("preview regions retain native rounding at scale " .. scale,
            { roundedTree(preview), preview:GetScale() }, { true, scale })
    end

    local nativeClose = CreateFrame("Button", nil, ItemRefTooltip)
    ItemRefTooltip.CloseButton = nativeClose
    local main = ui.getPanel(ItemRefTooltip)
    ui.drawChrome(main, ItemRefTooltip, { tooltipType = "item", color = { 1, 1, 1 }, tag = "Equipped" })
    test.check("live panels round their close button, equipped label and native border regions",
        { roundedTree(main), main.close ~= nil, main.equipped ~= nil,
            main.nativeBorder and main.nativeBorder.Center ~= nil },
        { true, true, true, true })

    local style, color = ui.styleOf("objectTitle"), { 1, 1, 1 }
    local function fillPools()
        ui.clearPool(main)
        for index = 1, 12 do
            ui.styledAt(main, "Another row", 8, index * 16, 200, style, color)
            ui.hiddenTextAt(main, world.secret, 8, index * 16, 200, style, color)
            ui.acquireTexture(main)
        end
    end
    fillPools()
    test.check("text, secret text and texture pools configure later entries",
        { roundedTree(main), #main.pool >= 12, #main.hiddenPool, #main.texturePool }, { true, true, 12, 12 })

    world.counts = {}
    fillPools()
    local roundingCalls = world.counts.SetRoundLayoutToNearestPixel or 0
    world.counts = nil
    test.check("pool reuse adds no rounding setter calls", roundingCalls, 0)
    test.check("the preview's original parent and scale remain intact",
        { preview:GetParent() == anchor, UIParent:GetScale() }, { true, .8 })
    test.check("native source frames and borrowed close controls keep their rounding policy",
        { UIParent:GetRoundLayoutToNearestPixel(), GameTooltip:GetRoundLayoutToNearestPixel(),
            ItemRefTooltip:GetRoundLayoutToNearestPixel(), nativeClose:GetRoundLayoutToNearestPixel(),
            anchor:GetRoundLayoutToNearestPixel() }, { false, false, false, false, false })
end
