-- Retail's player tooltips name the specialization with the class, as
-- "Restoration Shaman", on a line of its own or with the level and race. The
-- spec moves into the info line, in the client's words and order, and a line
-- saying nothing more goes. Retail/Tooltips/UnitExtension.lua reads it.
local _, ns = ...
local util = ns.util
local isSecret, trim = util.isSecret, util.trim
local unit = {}
ns.Retail.Unit = unit

local function escaped(text) return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- Sets model.spec, the spec's name, and model.specClass, the spec and class
-- as the client wrote them; game asks the client for the class's specs.
function unit.readSpec(model, game)
    if model.spec or type(model.className) ~= "string" then return end
    local specs = game.classSpecs and game.classSpecs(model.classID)
    if not specs then return end
    local function specIn(text)
        if isSecret(text) or type(text) ~= "string" then return end
        local plain = trim(util.plainText(text))
        for _, name in ipairs(specs) do
            for _, phrase in ipairs({ name .. " " .. model.className, model.className .. " " .. name }) do
                -- Whole words; %w knows only ASCII letters, so other scripts match as they are.
                local pattern = escaped(phrase)
                if not phrase:find("[\128-\255]") then pattern = "%f[%w]" .. pattern .. "%f[%W]" end
                local from, to = plain:find(pattern)
                if from then
                    local rest = plain:sub(1, from - 1) .. plain:sub(to + 1)
                    if model.race then rest = rest:gsub(escaped(model.race), "", 1) end
                    -- The level line can end in the unit's kind, "(Player)".
                    return name, phrase, trim((rest:gsub("%s*%b()%s*$", "")))
                end
            end
        end
    end
    if model.levelLine then model.spec, model.specClass = specIn(model.levelLine) end
    if model.spec then return end
    for index, row in ipairs(model.extras) do
        local name, phrase, rest = specIn(row.left)
        if name then
            model.spec, model.specClass = name, phrase
            if rest == "" and (row.right or "") == "" then table.remove(model.extras, index) end
            return
        end
    end
end
