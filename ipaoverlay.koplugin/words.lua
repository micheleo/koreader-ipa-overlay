local Words = {}

local function isAsciiLetter(byte)
    return byte ~= nil and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122))
end

local function letterLength(text, index)
    local byte = text:byte(index)
    if isAsciiLetter(byte) then
        return 1
    end
    local second = text:byte(index + 1)
    if byte == 195 and second and second >= 128 and second <= 191 and second ~= 151 and second ~= 183 then
        return 2
    end
    return 0
end

local function apostropheLength(text, index)
    if text:sub(index, index) == "'" then
        return 1
    end
    if text:sub(index, index + 2) == "’" then
        return 3
    end
    return 0
end

local function wordEnd(text, start, keepApostrophe)
    local index = start
    while true do
        local length = letterLength(text, index)
        if length > 0 then
            index = index + length
        else
            local apostrophe = keepApostrophe and apostropheLength(text, index) or 0
            if apostrophe > 0 and letterLength(text, index + apostrophe) > 0 then
                index = index + apostrophe
            else
                return index - 1
            end
        end
    end
end

-- Returns { { word = ..., ipa = ... or nil }, ... } for every word found in plain text.
-- options.keepApostrophe keeps "don't" as one word. Italian elision ("l'amico") splits at the apostrophe.
function Words.lookup(text, lookup, options)
    local keepApostrophe = options and options.keepApostrophe
    local found = {}
    local index = 1
    while index <= #text do
        if letterLength(text, index) > 0 then
            local last = wordEnd(text, index, keepApostrophe)
            local word = text:sub(index, last)
            local isElidedArticle = not keepApostrophe and #word == 1 and apostropheLength(text, last + 1) > 0
            found[#found + 1] = {
                word = word,
                ipa = not isElidedArticle and lookup((word:gsub("’", "'"))) or nil,
            }
            index = last + 1
        else
            index = index + 1
        end
    end
    return found
end

-- Single letters that Italian elides before a vowel (l'aquila, d'amore) and how they sound. c' is ci before e (c'è).
local ELIDED_LETTERS = { l = "l", d = "d", s = "s", m = "m", n = "n", t = "t", v = "v", c = "tʃ" }

-- Joins the IPA of the entries of one crengine word into one string. An elided word is one unit of speech
-- (l'aquila is ˈlakwila, not l + ˈakwila), so with an apostrophe the parts are glued and a lone elided letter
-- goes inside the stress mark of the next part.
function Words.joinIpa(token, entries)
    local glued = token:find("'", 1, true) or token:find("’", 1, true)
    local parts, pendingLetter = {}, nil
    for _position, entry in ipairs(entries) do
        local lowered = entry.word:lower()
        if entry.ipa then
            local ipa = entry.ipa
            if pendingLetter then
                local mark = ipa:match("^ˈ")
                ipa = mark and (mark .. pendingLetter .. ipa:sub(#mark + 1)) or (pendingLetter .. ipa)
                pendingLetter = nil
            end
            parts[#parts + 1] = ipa
        elseif glued and ELIDED_LETTERS[lowered] then
            pendingLetter = ELIDED_LETTERS[lowered]
        end
    end
    return #parts > 0 and table.concat(parts, glued and "" or " ") or nil
end

return Words
