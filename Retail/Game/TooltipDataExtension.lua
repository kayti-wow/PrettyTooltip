-- How retail colors a line it will not act on: an effect greyed, as one from
-- another specialization's gear, or red, as one the character cannot use. It
-- replaces Game/TooltipData.lua's answer (ns.replace), which marks none; this
-- file loads just after it. Tooltips/Item.lua keeps such lines in that color.
local _, ns = ...
local tooltipData = ns.TooltipData

-- The line's own color when the game greys or reds it, as { r, g, b }; nil
-- for any other color, or one it cannot read.
local function inactiveColor(color)
    local rgb = ns.util.rgb(color)
    if not rgb then return end
    local red = rgb[1] > .9 and rgb[2] < .3 and rgb[3] < .3
    if red or tooltipData.isGrey(color) then return rgb end
end

ns.replace(tooltipData, "Game/TooltipData.lua", { inactiveColor = inactiveColor })
