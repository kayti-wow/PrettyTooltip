-- Every tooltip type's tab in the editor draws, including the types whose
-- details section has no title, on every client's .toc.
return function(test)
    local clients = {}
    for client in pairs(test.tocs) do clients[#clients + 1] = client end
    table.sort(clients)
    for _, client in ipairs(clients) do
        local ns, world = test.load(test.tocs[client], { enums = test.enums })
        ns.openEditor()
        local labels = {}
        for _, tooltipType in ipairs(ns.editorSamples.order) do
            labels[ns.L[ns.editorSamples.tooltipTypes[tooltipType].label]] = true
        end
        local clicked = 0
        for _, object in ipairs(world.objects) do
            local label = object.Text and object.Text:GetText()
            local onClick = object.GetScript and object:GetScript("OnClick")
            if label and labels[label] and onClick then
                local ok, problem = pcall(onClick, object)
                if not ok then test.check(client .. ": the " .. label .. " tab draws", problem, nil) end
                clicked = clicked + 1
            end
        end
        test.check(client .. ": every tab was tried", clicked, #ns.editorSamples.order)
    end
end
