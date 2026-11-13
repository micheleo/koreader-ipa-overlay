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

return Words
