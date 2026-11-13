local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local RenderText = require("ui/rendertext")
local logger = require("logger")
local Words = require("words")

-- Draws the IPA above each word of the current page at paint time. The book is not modified,
-- so selection, highlights, dictionary and translation keep working on the original text.
local IpaOverlay = { name = "ipa_overlay", cache = { key = nil, words = {} } }
IpaOverlay.__index = IpaOverlay

function IpaOverlay:new(plugin)
    return setmetatable({ plugin = plugin, cache = { key = nil, words = {} } }, self)
end

function IpaOverlay:isActive()
    return self.ui ~= nil and self.ui.document ~= nil and self.ui.rolling ~= nil
        and self.ui.view ~= nil and self.ui.view.view_mode == "page"
        and self.ui.doc_settings ~= nil and self.ui.doc_settings:isTrue("ipa_overlay")
end

local MAX_WORDS_PER_PAGE = 600
local NATURAL_LINE_HEIGHT_PER_FONT_SIZE = 1.3
-- crengine centers the text vertically inside each line box. Distances from that center, per unit of font size.
local ASCENT_ABOVE_CENTER = 0.5
local DESCENT_BELOW_CENTER = 0.3
local GAP_ABOVE_WORD = 6
local LINE_SPACING_SAFETY = 1.1
local MIN_GAP_BETWEEN_IPA = 6
local SCREEN_EDGE_MARGIN = 6
local MAX_EMPTY_BOXES_IN_A_ROW = 3

function IpaOverlay:ipaForToken(token, engine, options)
    local parts = {}
    for _index, entry in ipairs(Words.lookup(token, function(word)
        return engine:lookup(word)
    end, options)) do
        if entry.ipa then
            parts[#parts + 1] = entry.ipa
        end
    end
    return #parts > 0 and table.concat(parts, " ") or nil
end

-- crengine only returns one box per line for a range, so every word is queried on its own.
function IpaOverlay:computePageWords(pageStart)
    local document = self.ui.document
    local engine, options = self.plugin:engineFor(self.plugin:resolveVariant())
    if not engine then
        return {}
    end
    local startedAt = os.clock()
    local words = {}
    local cursor = pageStart
    local emptyInARow = 0
    for _count = 1, MAX_WORDS_PER_PAGE do
        local wordEnd = document:getNextVisibleWordEnd(cursor)
        if not wordEnd or wordEnd == cursor then
            break
        end
        local wordStart = document:getPrevVisibleWordStart(wordEnd)
        local boxes = wordStart and document:getScreenBoxesFromPositions(wordStart, wordEnd, true) or {}
        if #boxes == 0 then
            emptyInARow = emptyInARow + 1
            if emptyInARow >= MAX_EMPTY_BOXES_IN_A_ROW and #words > 0 then
                break
            end
        else
            emptyInARow = 0
            local range = document:getTextFromXPointers(wordStart, wordEnd, false)
            local text = type(range) == "table" and range.text or range
            local ipa = text and self:ipaForToken(text, engine, options)
            if ipa then
                -- A hyphenated word is drawn on its last line fragment, which starts at the free left margin
                words[#words + 1] = { box = boxes[#boxes], ipa = ipa, splitAcrossLines = #boxes > 1 }
            end
        end
        cursor = wordEnd
    end
    logger.info("ipa_overlay overlay: page scanned", #words, "words in", os.clock() - startedAt, "s")
    return words
end

function IpaOverlay:pageWords()
    local document = self.ui.document
    local page = document:getCurrentPage()
    local pageStart = document:getPageXPointer(page)
    if not pageStart then
        return {}
    end
    if not self.plugin:engineFor(self.plugin:resolveVariant()) then
        return {}
    end
    local key = table.concat({
        pageStart, self.plugin:resolveVariant() or "", document:getFontSize(), self.ui.font.configurable.line_spacing,
    }, "|")
    if self.cache.key ~= key then
        self.cache = { key = key, words = self:computePageWords(pageStart) }
    end
    return self.cache.words
end

function IpaOverlay:face()
    local settings = self.plugin.settings
    local pointSize = self.ui.document.configurable.font_size or 22
    local percent = settings:readSetting("size", 80)
    return Font:getFace("infofont", math.max(6, math.floor(pointSize * percent / 100)))
end

function IpaOverlay:color()
    local hex = self.plugin.settings:readSetting("shade", "#666666")
    return Blitbuffer.Color8(tonumber(hex:sub(2, 3), 16) or 0x66)
end

-- Line spacing (percent, KOReader allows 50 to 200) that leaves room for one row of IPA above each line.
function IpaOverlay:requiredLineSpacing()
    local fontSize = self.ui.document:getFontSize()
    local ipaHeight = self:face().ftsize:getHeightAndAscender()
    local neededLinePitch = (ASCENT_ABOVE_CENTER + DESCENT_BELOW_CENTER) * fontSize + ipaHeight + GAP_ABOVE_WORD
    local naturalLinePitch = fontSize * NATURAL_LINE_HEIGHT_PER_FONT_SIZE
    local percent = math.ceil(100 * neededLinePitch / naturalLinePitch * LINE_SPACING_SAFETY)
    return math.max(100, math.min(200, percent))
end

function IpaOverlay:paintTo(bb, x, y)
    if not self:isActive() then
        return
    end
    local ok, err = pcall(self.paintWords, self, bb, x, y)
    if not ok then
        logger.err("ipaoverlay: paint failed, overlay disabled:", err)
        self.plugin:disableAfterError()
    end
end

function IpaOverlay:paintWords(bb, x, y)
    local face = self:face()
    local color = self:color()
    local screenWidth = bb:getWidth()
    local liftFromLineCenter = math.floor(ASCENT_ABOVE_CENTER * self.ui.document:getFontSize()) + GAP_ABOVE_WORD
    local rowY, previousRight = nil, 0
    for _index, word in ipairs(self:pageWords()) do
        local width = RenderText:sizeUtf8Text(0, screenWidth, face, word.ipa, true, false).x
        local left = x + word.box.x
        if not word.splitAcrossLines then
            left = left + math.floor((word.box.w - width) / 2)
        end
        if rowY ~= word.box.y then
            rowY, previousRight = word.box.y, 0
        end
        left = math.max(left, previousRight + MIN_GAP_BETWEEN_IPA)
        left = math.min(left, screenWidth - SCREEN_EDGE_MARGIN - width)
        local baseline = y + word.box.y + math.floor(word.box.h / 2) - liftFromLineCenter
        RenderText:renderUtf8Text(bb, left, baseline, face, word.ipa, true, false, color)
        previousRight = left + width
    end
end

return IpaOverlay
