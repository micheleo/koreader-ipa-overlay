-- ipa-dict en_UK writes the stress mark after the first onset consonant (tˈiːtʃəz).
-- Moves it to the syllable start (ˈtiːtʃəz). Mirrors tools/build_ipadict_uk.py, the fixtures keep both in sync.
local UkStress = {}

local MULTI = {
    "tʃ", "dʒ", "aɪ", "aʊ", "ɔɪ", "eɪ", "əʊ", "ɪə", "eə", "ʊə",
    "iː", "uː", "ɔː", "ɑː", "ɜː", "aː", "oː",
}
local VOWEL_CHARS = {}
for char in ("aeiouɪʊəɐɒɔɑɜæʌɛɵ"):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    VOWEL_CHARS[char] = true
end
local MARKS = { ["ˈ"] = true, ["ˌ"] = true }
local STOPS_FRICATIVES = { p = true, b = true, t = true, d = true, k = true, ["ɡ"] = true, f = true, v = true }
local LIQUIDS_GLIDES = { l = true, ["ɹ"] = true, r = true, w = true, j = true }

local function tokenize(ipa)
    local tokens, index = {}, 1
    while index <= #ipa do
        local matched
        for _position, multi in ipairs(MULTI) do
            if ipa:sub(index, index + #multi - 1) == multi then
                matched = multi
                break
            end
        end
        if not matched then
            matched = ipa:match("^[%z\1-\127\194-\244][\128-\191]*", index)
        end
        tokens[#tokens + 1] = matched
        index = index + #matched
    end
    return tokens
end

local function isVowel(token)
    return VOWEL_CHARS[token:match("^[%z\1-\127\194-\244][\128-\191]*")] or false
end

local function canExtendOnset(previous, current)
    if previous == "s" then
        return current ~= "s"
    end
    return STOPS_FRICATIVES[previous] and LIQUIDS_GLIDES[current] or false
end

function UkStress.moveMarksToSyllableStart(ipa)
    local result = {}
    for _position, token in ipairs(tokenize(ipa:gsub("g", "ɡ"))) do
        if MARKS[token] then
            result[#result + 1] = token
        else
            if #result > 0 and MARKS[result[#result]] and isVowel(token) then
                local mark = table.remove(result)
                local start = #result + 1
                while start > 1 and not MARKS[result[start - 1]] and not isVowel(result[start - 1]) do
                    local first = result[start] or token
                    if start == #result + 1 or canExtendOnset(result[start - 1], first) then
                        start = start - 1
                    else
                        break
                    end
                end
                table.insert(result, start, mark)
            end
            result[#result + 1] = token
        end
    end
    return table.concat(result)
end

return UkStress
