local Phonology = require("phonology")

local IpaItalian = {}

local UPPER_ACCENTS = { ["À"] = "à", ["È"] = "è", ["É"] = "é", ["Ì"] = "ì", ["Ò"] = "ò", ["Ó"] = "ó", ["Ù"] = "ù" }

local ACCENTED = {
    ["à"] = { "a", true }, ["è"] = { "ɛ", true }, ["é"] = { "e", true },
    ["ì"] = { "i", true }, ["ò"] = { "ɔ", true }, ["ó"] = { "o", true }, ["ù"] = { "u", true },
}

local PLAIN_VOWELS = { a = "a", e = "e", i = "i", o = "o", u = "u" }
local FRONT = { e = true, i = true, ["è"] = true, ["é"] = true, ["ì"] = true }

-- Splits a lowercase UTF-8 word into letters (accented letters stay one element).
local function letters(word)
    local list = {}
    local index = 1
    while index <= #word do
        local byte = word:byte(index)
        local length = byte == 195 and 2 or 1
        list[#list + 1] = word:sub(index, index + length - 1)
        index = index + length
    end
    return list
end

local function isVowelLetter(letter)
    return letter ~= nil and (PLAIN_VOWELS[letter] ~= nil or ACCENTED[letter] ~= nil)
end

local function normalize(word)
    word = word:lower()
    for upper, lower in pairs(UPPER_ACCENTS) do
        word = word:gsub(upper, lower)
    end
    return word
end

-- Written without accent, stressed on the third to last syllable (sdrucciole). Not derivable from the spelling.
local ANTEPENULTIMATE = {}
for word in ([[
    tavolo tavola aquila albero anima camera macchina medico musica numero ordine pagina simpatico telefono
    difficile facile giovane lettera libero subito nuvola ultimo ultima unico unica possibile impossibile
    terribile amabile utile inutile debole nobile povero povera povere poveri tavoli tavole alberi anime camere
    macchine medici numeri pagine lettere nuvole camera piccolo piccola piccoli piccole simile simili spirito
    esercito semplice semplici facili difficili giovani
]]):gmatch("%S+") do
    ANTEPENULTIMATE[word] = true
end

function IpaItalian.convert(rawWord)
    local list = letters(normalize(rawWord))
    local units = {}
    local accentedIndex

    local function push(ipa, vowel, stress)
        units[#units + 1] = { ipa = ipa, vowel = vowel, stress = stress or 0 }
    end

    -- gn, gli and sc are always long between vowels, written once at word start
    local function pushLong(ipa)
        push(ipa, false)
        if #units > 1 then
            push(ipa, false)
        end
    end

    local index = 1
    while index <= #list do
        local letter = list[index]
        local following = list[index + 1]
        local afterFollowing = list[index + 2]

        if PLAIN_VOWELS[letter] or ACCENTED[letter] then
            local ipa, stressed
            if ACCENTED[letter] then
                ipa, stressed = ACCENTED[letter][1], true
            else
                ipa = PLAIN_VOWELS[letter]
            end
            local previousIsConsonant = index == 1 or not isVowelLetter(list[index - 1])
            local asGlide = (letter == "i" or letter == "u") and previousIsConsonant and isVowelLetter(following)
            if asGlide then
                push(letter == "i" and "j" or "w", false)
            else
                push(ipa, true, stressed and 1 or 0)
                if stressed then
                    accentedIndex = #units
                end
            end
        elseif letter == "c" then
            if following == "h" then
                push("k", false)
                index = index + 1
            elseif following == "i" and isVowelLetter(afterFollowing) then
                push("tʃ", false)
                index = index + 1
            elseif FRONT[following] then
                push("tʃ", false)
            elseif following == "c" then
                local soft = FRONT[afterFollowing]
                push(soft and "t" or "k", false)
                push(soft and "tʃ" or "k", false)
                index = index + 1
                if afterFollowing == "i" and isVowelLetter(list[index + 2]) then
                    index = index + 1
                end
            else
                push("k", false)
            end
        elseif letter == "g" then
            if following == "h" then
                push("ɡ", false)
                index = index + 1
            elseif following == "n" then
                pushLong("ɲ")
                index = index + 1
            elseif following == "l" and afterFollowing == "i" then
                pushLong("ʎ")
                index = index + 2
                if not isVowelLetter(list[index + 1]) then
                    push("i", true)
                end
            elseif following == "i" and isVowelLetter(afterFollowing) then
                push("dʒ", false)
                index = index + 1
            elseif FRONT[following] then
                push("dʒ", false)
            elseif following == "g" then
                local soft = FRONT[afterFollowing]
                push("d", false)
                push(soft and "dʒ" or "ɡ", false)
                index = index + 1
                if afterFollowing == "i" and isVowelLetter(list[index + 2]) then
                    index = index + 1
                end
            else
                push("ɡ", false)
            end
        elseif letter == "s" then
            if following == "c" and FRONT[afterFollowing] then
                pushLong("ʃ")
                index = index + 1
                if afterFollowing == "i" and isVowelLetter(list[index + 2]) then
                    index = index + 1
                end
            else
                local between = index > 1 and isVowelLetter(list[index - 1]) and isVowelLetter(following)
                push(between and "z" or "s", false)
            end
        elseif letter == "q" then
            push("k", false)
            if following == "u" then
                push("w", false)
                index = index + 1
            end
        elseif letter == "z" then
            -- zz and a z between vowels before i + vowel (stazione, grazie) are long: t + ts
            local betweenVowels = index > 1 and isVowelLetter(list[index - 1])
            local beforeIVowel = following == "i" and isVowelLetter(afterFollowing)
            if following == "z" then
                push("t", false)
                push("ts", false)
                index = index + 1
            elseif betweenVowels and beforeIVowel then
                push("t", false)
                push("ts", false)
            else
                push("ts", false)
            end
        elseif letter == "h" then
            -- silent
        elseif letter == following and letter:match("^%a$") then
            push(letter, false)
            push(letter, false)
            index = index + 1
        else
            push(letter, false)
        end
        index = index + 1
    end

    if not accentedIndex then
        local nuclei = {}
        for position, unit in ipairs(units) do
            if unit.vowel then
                nuclei[#nuclei + 1] = position
            end
        end
        if #nuclei >= 3 and ANTEPENULTIMATE[normalize(rawWord)] then
            units[nuclei[#nuclei - 2]].stress = 1
        elseif #nuclei >= 2 then
            units[nuclei[#nuclei - 1]].stress = 1
        end
    end
    return Phonology.render(units)
end

function IpaItalian:lookup(word)
    return IpaItalian.convert(word)
end

return IpaItalian
