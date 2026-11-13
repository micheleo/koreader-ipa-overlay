local Phonology = {}

local STOPS_FRICATIVES = { p = true, b = true, t = true, d = true, k = true, ["ɡ"] = true, f = true, v = true, ts = true }
local LIQUIDS_GLIDES = { l = true, ["ɹ"] = true, r = true, w = true, j = true }

local function canExtendOnset(previous, current)
    if previous == "s" then
        return current ~= "s"
    end
    return STOPS_FRICATIVES[previous] and LIQUIDS_GLIDES[current] or false
end

local function onsetStart(units, vowelIndex)
    local start = vowelIndex
    while start > 1 and not units[start - 1].vowel do
        local previous = units[start - 1]
        local first = units[start]
        if start == vowelIndex or canExtendOnset(previous.ipa, first.ipa) then
            start = start - 1
        else
            break
        end
    end
    return start
end

-- units: array of { ipa = string, vowel = bool, stress = 0|1|2 }
function Phonology.render(units)
    local marks = {}
    for index, unit in ipairs(units) do
        if unit.vowel and unit.stress and unit.stress > 0 then
            local start = onsetStart(units, index)
            marks[start] = unit.stress == 1 and "ˈ" or "ˌ"
        end
    end
    local parts = {}
    for index, unit in ipairs(units) do
        if marks[index] then
            parts[#parts + 1] = marks[index]
        end
        parts[#parts + 1] = unit.ipa
    end
    return table.concat(parts)
end

return Phonology
