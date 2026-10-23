-- A client's style parts go after the part each names, so the style editor
-- lists them where they are drawn. One naming a part that does not exist
-- stops the load, rather than going missing until its tooltip is drawn.
return function(test)
    local function contribute(element)
        return function(_, ns) ns.contribute("settings", { defaults = { extraOn = true }, elements = { element } }) end
    end
    local function load(element)
        return pcall(test.load, { "Core/Util.lua", contribute(element), "Core/Palette.lua", "Core/Settings.lua" })
    end

    local ok, ns = load({ after = "title", key = "extraPart", label = "Extra", size = 12, color = { 1, 1, 1 } })
    local after
    for index, part in ipairs(ok and ns.ELEMENTS or {}) do
        if part.key == "title" then after = ns.ELEMENTS[index + 1].key end
    end
    test.check("a part after the one it names", after, "extraPart")
    test.check("with its style and default", ok and { ns.style("extraPart").size, ns.option("extraOn") }, { 12, true })

    local failed, problem = load({ after = "noSuchPart", key = "lostPart", label = "Lost", size = 12 })
    test.check("one naming a missing part stops the load", { failed, tostring(problem):find("noSuchPart", 1, true) ~= nil },
        { false, true })
end
