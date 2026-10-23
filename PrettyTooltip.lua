-- Addon startup. Loads last; setup moves here as its modules are refactored.
-- A client's .toc loads its own files among the shared ones, all before this
-- one (Retail/README.md), so everything is in place when the addon starts.
local addonName, ns = ...

local started = false
function ns.start()
    if started then return end
    started = true
    ns.migrateOptions()
    ns.ItemLite.register()
    if ns.Hooks then ns.Hooks.install() end
    if ns.Details then ns.Details.register() end
    if ns.Cursor then ns.Cursor.register() end
    ns.Options.register()
    ns.Commands.register()
end

local starter = CreateFrame("Frame")
starter:RegisterEvent("ADDON_LOADED")
starter:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    ns.start()
end)
