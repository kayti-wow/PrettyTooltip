-- How retail colors a line it will not act on: an effect greyed, as one from
-- another specialization's gear, or red, as one the character cannot use.
-- Retail/Game/TooltipDataExtension.lua puts it in place of Game/TooltipData.lua's,
-- and Tooltips/Item.lua keeps such lines in that color.
local _, ns = ...
local isSecret = ns.util.isSecret
local tooltipData = {}
ns.Retail.TooltipData = tooltipData

-- The line's own color when the game greys or reds it, as { r, g, b }; nil
-- for any other color, or one it cannot read.
function tooltipData.inactiveColor(color)
    if isSecret(color) or type(color) ~= "table" then return end
    local r, g, b = color.r, color.g, color.b
    if isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return
    end
    local grey = r < .7 and math.abs(r - g) < .06 and math.abs(g - b) < .06
    local red = r > .9 and g < .3 and b < .3
    if grey or red then return { r, g, b } end
end
