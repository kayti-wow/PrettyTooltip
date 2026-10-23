-- Retail's flight map: its node pins fill GameTooltip with lines themselves
-- (FlightMap_FlightPointPinMixin's OnMouseEnter), never through the classic
-- map's TaxiNodeOnButtonEnter that Tooltips/FlightPath.lua hooks. The panel
-- is drawn once the pin shows the tooltip, from the same lines: the node's
-- name and zone, then its cost or "You are here". It loads just after that
-- file; Integration/Hooks.lua installs the hook with its own
-- (descriptor.extension.install).
local _, ns = ...
local TAXI = "taxi"
local descriptor = ns.TooltipTypes and ns.TooltipTypes[TAXI]
if not descriptor then return end
local util = ns.util

-- Whether the tooltip's owner is a flight map pin, by the node it shows.
local function onFlightPin(tooltip)
    local owner = util.call(tooltip.GetOwner, tooltip)
    if not util.canModify(owner) then return false end
    local node = util.readable(owner.taxiNodeData)
    return type(node) == "table"
end

descriptor.extension = {
    install = function()
        hooksecurefunc(GameTooltip, "Show", function(tooltip)
            if not util.canModify(tooltip) or not util.call(tooltip.IsShown, tooltip) then return end
            if not onFlightPin(tooltip) or (util.number((util.call(tooltip.NumLines, tooltip))) or 0) == 0 then
                return
            end
            ns.Hooks.renderLines(tooltip, TAXI)
        end)
    end,
}
