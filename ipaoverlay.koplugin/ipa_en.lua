local Phonology = require("phonology")
local UkStress = require("uk_stress")

local ARPABET_TO_IPA = {
    AA = "ɑ", AE = "æ", AH = "ʌ", AO = "ɔ", AW = "aʊ", AY = "aɪ", EH = "ɛ", ER = "ɝ",
    EY = "eɪ", IH = "ɪ", IY = "i", OW = "oʊ", OY = "ɔɪ", UH = "ʊ", UW = "u",
    B = "b", CH = "tʃ", D = "d", DH = "ð", F = "f", G = "ɡ", HH = "h", JH = "dʒ", K = "k",
    L = "l", M = "m", N = "n", NG = "ŋ", P = "p", R = "ɹ", S = "s", SH = "ʃ", T = "t",
    TH = "θ", V = "v", W = "w", Y = "j", Z = "z", ZH = "ʒ",
}

local UNSTRESSED_VOWEL = { AH = "ə", ER = "ɚ" }

-- Received Pronunciation: only the vowels that differ from the General American table above.
local BRITISH_VOWEL = { AA = "ɑː", AO = "ɔː", ER = "ɜː", IY = "iː", OW = "əʊ", UW = "uː" }
local BRITISH_UNSTRESSED_VOWEL = { AH = "ə", ER = "ə" }

local IpaEnglish = {}
IpaEnglish.__index = IpaEnglish

local function parsePhones(phones)
    local parsed = {}
    for phone in phones:gmatch("%S+") do
        local symbol, stress = phone:match("^(%a+)(%d?)$")
        if not symbol or not ARPABET_TO_IPA[symbol] then
            return nil
        end
        parsed[#parsed + 1] = { symbol = symbol, isVowel = stress ~= "", level = tonumber(stress) or 0 }
    end
    return parsed
end

local function vowelIpa(phone, british)
    if british then
        if phone.level == 0 and BRITISH_UNSTRESSED_VOWEL[phone.symbol] then
            return BRITISH_UNSTRESSED_VOWEL[phone.symbol]
        end
        if BRITISH_VOWEL[phone.symbol] then
            return BRITISH_VOWEL[phone.symbol]
        end
    elseif phone.level == 0 and UNSTRESSED_VOWEL[phone.symbol] then
        return UNSTRESSED_VOWEL[phone.symbol]
    end
    return ARPABET_TO_IPA[phone.symbol]
end

-- British English drops "r" unless a vowel follows it.
local function isSilentBritishR(parsed, index)
    local following = parsed[index + 1]
    return parsed[index].symbol == "R" and not (following and following.isVowel)
end

local function arpabetToIpa(phones, accent)
    local parsed = parsePhones(phones)
    if not parsed then
        return nil
    end
    local british = accent == "uk"
    local units = {}
    for index, phone in ipairs(parsed) do
        if not (british and isSilentBritishR(parsed, index)) then
            local ipa = phone.isVowel and vowelIpa(phone, british) or ARPABET_TO_IPA[phone.symbol]
            units[#units + 1] = { ipa = ipa, vowel = phone.isVowel, stress = phone.level }
        end
    end
    return Phonology.render(units)
end

IpaEnglish.arpabetToIpa = arpabetToIpa

local function readLines(path, handleLine)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    for line in file:lines() do
        handleLine(line)
    end
    file:close()
    return true
end

-- Upstream cmudict.dict: "word PHONES", variants "word(2)", comments after "#". First variant wins.
local function parseCmudictLine(line, target)
    local word, phones = line:gsub("%s*#.*$", ""):match("^([a-z']+)%s+(.+)$")
    if word and not target[word] then
        target[word] = phones
    end
end

-- Upstream ipa-dict en_UK.txt: "word<TAB>/ipa/, /ipa2/". Only the first pronunciation is kept.
local function parseIpaDictLine(line, target)
    local word, ipa = line:match("^([a-z']+)\t/?([^/,]+)")
    if word and not target[word] then
        target[word] = ipa
    end
end

local sharedTables = {}
local function loadShared(path, parseLine)
    if not sharedTables[path] then
        local entries = {}
        if not readLines(path, function(line) parseLine(line, entries) end) then
            return nil
        end
        sharedTables[path] = entries
    end
    return sharedTables[path]
end

IpaEnglish.CMUDICT_FILE = "cmudict.dict"
IpaEnglish.IPADICT_UK_FILE = "en_UK.txt"
IpaEnglish.arpabetToIpa = arpabetToIpa

-- accent is "us" or "uk". Returns nil when the dictionary files are missing in dataDirectory.
function IpaEnglish.new(accent, dataDirectory)
    local cmudict = loadShared(dataDirectory .. "/" .. IpaEnglish.CMUDICT_FILE, parseCmudictLine)
    if not cmudict then
        return nil
    end
    local british = accent == "uk" and loadShared(dataDirectory .. "/" .. IpaEnglish.IPADICT_UK_FILE, parseIpaDictLine)
    if accent == "uk" and not british then
        return nil
    end
    return setmetatable({ accent = accent, cmudict = cmudict, british = british or {}, converted = {} }, IpaEnglish)
end

local SIBILANT_ENDINGS = { "s", "z", "ʃ", "ʒ", "tʃ", "dʒ" }
local VOICELESS_ENDINGS = { "p", "t", "k", "f", "θ" }

local function endsWithAny(ipa, endings)
    for _position, ending in ipairs(endings) do
        if ipa:sub(-#ending) == ending then
            return true
        end
    end
    return false
end

-- "Alice's" is not in the dictionaries: the base word plus the possessive sound that follows its last sound.
local function addPossessive(baseIpa)
    if endsWithAny(baseIpa, SIBILANT_ENDINGS) then
        return baseIpa .. "ɪz"
    end
    return baseIpa .. (endsWithAny(baseIpa, VOICELESS_ENDINGS) and "s" or "z")
end

function IpaEnglish:lookup(word)
    local lowered = word:lower()
    local raw = self.british[lowered]
    if raw then
        self.converted[lowered] = self.converted[lowered] or UkStress.convert(raw)
        return self.converted[lowered]
    end
    local phones = self.cmudict[lowered]
    if phones then
        return arpabetToIpa(phones, self.accent)
    end
    local base = lowered:match("^(.+)'s$")
    local baseIpa = base and self:lookup(base)
    return baseIpa and addPossessive(baseIpa) or nil
end

return IpaEnglish
