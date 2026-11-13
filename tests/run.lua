package.path = "ipaoverlay.koplugin/?.lua;" .. package.path

local Words = require("words")
local IpaEnglish = require("ipa_en")
local IpaItalian = require("ipa_it")

local failures = 0
local function check(name, actual, expected)
    if actual ~= expected then
        failures = failures + 1
        print(("FAIL %s\n  expected: %s\n  actual:   %s"):format(name, tostring(expected), tostring(actual)))
    end
end

-- Italian
local italianLookup = function(word) return IpaItalian.convert(word) end
local function joined(token) return Words.joinIpa(token, Words.lookup(token, italianLookup)) end
check("it casa", IpaItalian.convert("casa"), "ˈkaza")
check("it chiesa", IpaItalian.convert("chiesa"), "ˈkjeza")
check("it gnocchi", IpaItalian.convert("gnocchi"), "ˈɲokki")
check("it famiglia", IpaItalian.convert("famiglia"), "faˈmiʎʎa")
check("it città accent", IpaItalian.convert("città"), "tʃitˈta")
check("it scena", IpaItalian.convert("scena"), "ˈʃena")
check("it mamma", IpaItalian.convert("mamma"), "ˈmamma")
check("it cielo", IpaItalian.convert("cielo"), "ˈtʃelo")
check("it oggi", IpaItalian.convert("oggi"), "ˈoddʒi")
check("it ciao", IpaItalian.convert("ciao"), "ˈtʃao")
check("it pizza", IpaItalian.convert("pizza"), "ˈpittsa")
check("it stazione", IpaItalian.convert("stazione"), "statˈtsjone")
check("it ragazzo", IpaItalian.convert("ragazzo"), "raˈɡattso")
check("it ragazzi", IpaItalian.convert("ragazzi"), "raˈɡattsi")
check("it scuola", IpaItalian.convert("scuola"), "ˈskwola")
check("it schiena", IpaItalian.convert("schiena"), "ˈskjena")
check("it quando", IpaItalian.convert("quando"), "ˈkwando")
check("it perché", IpaItalian.convert("perché"), "perˈke")
check("it università", IpaItalian.convert("università"), "universiˈta")
check("it gatti", IpaItalian.convert("gatti"), "ˈɡatti")
check("it caffè", IpaItalian.convert("caffè"), "kafˈfɛ")
check("it che", IpaItalian.convert("che"), "ke")
check("it chi", IpaItalian.convert("chi"), "ki")
check("it ghiaccio", IpaItalian.convert("ghiaccio"), "ˈɡjattʃo")
check("it spaghetti", IpaItalian.convert("spaghetti"), "spaˈɡetti")
check("it giorno", IpaItalian.convert("giorno"), "ˈdʒorno")
check("it lunedì", IpaItalian.convert("lunedì"), "luneˈdi")
check("it sbaglio", IpaItalian.convert("sbaglio"), "ˈsbaʎʎo")
check("it uomo", IpaItalian.convert("uomo"), "ˈwomo")
check("it buono", IpaItalian.convert("buono"), "ˈbwono")
check("it guerra", IpaItalian.convert("guerra"), "ˈɡwerra")
check("it più", IpaItalian.convert("più"), "pju")
check("it bambini", IpaItalian.convert("bambini"), "bamˈbini")
check("it cuore", IpaItalian.convert("cuore"), "ˈkwore")
check("it fiore", IpaItalian.convert("fiore"), "ˈfjore")
check("it pesce", IpaItalian.convert("pesce"), "ˈpeʃʃe")
check("it anche", IpaItalian.convert("anche"), "ˈanke")

-- English (ARPAbet conversion)
check("en about", IpaEnglish.arpabetToIpa("AH0 B AW1 T"), "əˈbaʊt")
check("en street", IpaEnglish.arpabetToIpa("S T R IY1 T"), "stɹit")
check("en water", IpaEnglish.arpabetToIpa("W AO1 T ER0"), "ˈwɔtɚ")
check("en monosyllable has no mark", IpaEnglish.arpabetToIpa("DH AE1 T"), "ðæt")
check("en two syllables keep mark", IpaEnglish.arpabetToIpa("S L IY1 P IY0"), "ˈslipi")
check("it tavolo antepenultimate", IpaItalian.convert("tavolo"), "ˈtavolo")
check("it aquila antepenultimate", IpaItalian.convert("aquila"), "ˈakwila")
check("it subito antepenultimate", IpaItalian.convert("subito"), "ˈsubito")
check("it Tavolo capital", IpaItalian.convert("Tavolo"), "ˈtavolo")
check("it penultimate default", IpaItalian.convert("tavolino"), "tavoˈlino")

-- English UK rules
check("uk water", IpaEnglish.arpabetToIpa("W AO1 T ER0", "uk"), "ˈwɔːtə")
check("uk car drops r", IpaEnglish.arpabetToIpa("K AA1 R", "uk"), "kɑː")
check("uk art drops r before consonant", IpaEnglish.arpabetToIpa("AA1 R T", "uk"), "ɑːt")
check("uk keeps r before vowel", IpaEnglish.arpabetToIpa("R EH1 D", "uk"), "ɹɛd")
check("uk hello", IpaEnglish.arpabetToIpa("HH AH0 L OW1", "uk"), "həˈləʊ")
check("uk bird", IpaEnglish.arpabetToIpa("B ER1 D", "uk"), "bɜːd")

-- UK stress mark parity with tools/build_ipadict_uk.py
local UkStress = require("uk_stress")
for _position, pair in ipairs(dofile("tests/uk_stress_fixtures.lua")) do
    check("uk stress " .. pair[1], UkStress.moveMarksToSyllableStart(pair[1]), pair[2])
end

-- Engines reading raw upstream dictionary files
local directory = os.tmpname()
os.remove(directory)
os.execute("mkdir -p " .. directory)
local function writeFile(name, content)
    local file = assert(io.open(directory .. "/" .. name, "w"))
    file:write(content)
    file:close()
end
check("en missing files", IpaEnglish.new("us", directory .. "/nope"), nil)
writeFile("cmudict.dict", "'bout B AW1 T\nhello HH AH0 L OW1 # comment\nhello(2) HH EH0 L OW1\nwater W AO1 T ER0\n"
    .. "alice AE1 L AH0 S\ncat K AE1 T\ndog D AO1 G\n")
writeFile("en_UK.txt", "that\t/ðˈæt/\nhello\t/həlˈəʊ/, /hɛlˈəʊ/\nteachers\t/tˈiːtʃəz/\n")
local us = IpaEnglish.new("us", directory)
check("us dict first variant", us:lookup("Hello"), "həˈloʊ")
check("us dict apostrophe word", us:lookup("'bout"), "baʊt")
check("us dict unknown", us:lookup("zzz"), nil)
check("us possessive after sibilant", us:lookup("Alice's"), "ˈæləsɪz")
check("us possessive after voiceless", us:lookup("cat's"), "kæts")
check("us possessive after voiced", us:lookup("dog's"), "dɔɡz")
check("us possessive of unknown word", us:lookup("zzz's"), nil)
local uk = IpaEnglish.new("uk", directory)
check("uk dict stress moved", uk:lookup("teachers"), "ˈtiːtʃəz")
check("uk dict monosyllable", uk:lookup("that"), "ðæt")
check("uk monosyllable keeps length mark", UkStress.convert("nˈjuː"), "njuː")
check("uk monosyllable keeps length mark 2", UkStress.convert("jˈɔː"), "jɔː")
check("uk monosyllable keeps secondary", UkStress.convert("ˌkˈɑːt"), "kɑːt")
check("uk dict first pronunciation", uk:lookup("hello"), "həˈləʊ")
check("uk dict falls back to cmudict", uk:lookup("water"), "ˈwɔːtə")
os.execute("rm -rf " .. directory)

-- Word lookup
local known = { hello = "həˈloʊ", world = "wɝld", ["don't"] = "doʊnt", amico = "aˈmiko" }
local lookup = function(word) return known[word:lower()] end

local found = Words.lookup("Hello, zzz world", lookup)
check("words count", #found, 3)
check("words ipa", found[1].ipa, "həˈloʊ")
check("words unknown", found[2].ipa, nil)
check("words keeps apostrophe", Words.lookup("don't", lookup, { keepApostrophe = true })[1].ipa, "doʊnt")
check("words curly apostrophe", Words.lookup("don’t", lookup, { keepApostrophe = true })[1].ipa, "doʊnt")
check("words italian elision skips lone letter", Words.lookup("l'amico", lookup)[1].ipa, nil)
check("words italian elision finds noun", Words.lookup("l'amico", lookup)[2].ipa, "aˈmiko")
check("words ignore entities and numbers", #Words.lookup("3 o'clock — 42", lookup), 2)

check("it c'e", joined("c'è"), "tʃɛ")
check("it c'era", joined("c'era"), "ˈtʃera")
check("it amichevole suffix", IpaItalian.convert("amichevole"), "amiˈkevole")
check("it amabile suffix", IpaItalian.convert("amabile"), "aˈmabile")
check("it possibile suffix", IpaItalian.convert("possibile"), "posˈsibile")
check("it penultimate noun", IpaItalian.convert("romano"), "roˈmano")

-- Elision is glued into one word
check("join l'aquila", joined("l'aquila"), "ˈlakwila")
check("join l'amico", joined("l'amico"), "laˈmiko")
check("join un'altra", joined("un'altra"), "unˈaltra")
check("join curly apostrophe", joined("l’amico"), "laˈmiko")
check("join without apostrophe keeps spaces", Words.joinIpa("casa tavolo", Words.lookup("casa tavolo", italianLookup)), "ˈkaza ˈtavolo")

-- Page scan with a fake document: apostrophe fragments are merged
package.preload["ffi/blitbuffer"] = function() return {} end
package.preload["ui/font"] = function() return {} end
package.preload["ui/rendertext"] = function() return {} end
package.preload["logger"] = function() return { info = function() end, err = function() end } end
local IpaOverlay = require("overlay")

-- Each entry: text, gap before it, boxes. Positions are plain numbers: word i starts at 10 * i and ends at 10 * i + 4.
local function fakeDocument(entries)
    local document = {}
    function document:getNextVisibleWordEnd(cursor)
        for index = 1, #entries do
            if 10 * index + 4 > cursor then
                return 10 * index + 4
            end
        end
    end
    function document:getPrevVisibleWordStart(wordEnd)
        return wordEnd - 4
    end
    function document:getScreenBoxesFromPositions(startPosition)
        return entries[math.floor(startPosition / 10)].boxes
    end
    function document:getTextFromXPointers(first, second)
        local index = math.floor(first / 10)
        if second == first + 4 then
            return entries[index].text
        end
        return entries[index + 1].gapBefore
    end
    return document
end

local function scan(entries, pronunciations, options)
    local overlay = IpaOverlay:new({
        engineFor = function() return { lookup = function(_, word) return pronunciations[word:lower()] end }, options end,
        resolveVariant = function() return "x" end,
    })
    overlay.ui = { document = fakeDocument(entries) }
    return IpaOverlay.computePageWords(overlay, 0)
end
local function box(x, y, w) return { { x = x, y = y, w = w, h = 40 } } end

local merged = scan({
    { text = "he", gapBefore = " ", boxes = box(0, 100, 20) },
    { text = "didn", gapBefore = " ", boxes = box(30, 100, 60) },
    { text = "t", gapBefore = "’", boxes = box(90, 100, 10) },
}, { he = "hi", ["didn't"] = "ˈdɪdənt" }, { keepApostrophe = true })
check("scan merges didn + t", #merged, 2)
check("scan merged ipa", merged[2].ipa, "ˈdɪdənt")
check("scan merged box starts at first fragment", merged[2].box.x, 30)
check("scan merged box covers both fragments", merged[2].box.w, 70)

local possessive = scan({
    { text = "Alice", gapBefore = " ", boxes = box(0, 100, 50) },
    { text = "s", gapBefore = "'", boxes = box(55, 100, 10) },
}, { alice = "ˈæləs" }, { keepApostrophe = true })
check("scan unknown merged word keeps the base ipa", #possessive, 1)
check("scan unknown merged word ipa", possessive[1].ipa, "ˈæləs")

local lineBreak = scan({
    { text = "l", gapBefore = " ", boxes = box(500, 100, 10) },
    { text = "aquila", gapBefore = "'", boxes = box(0, 140, 80) },
}, { aquila = "ˈakwila" }, {})
check("scan apostrophe at line end gives one entry", #lineBreak, 1)
check("scan apostrophe at line end uses the second line", lineBreak[1].box.y, 140)

local plain = scan({
    { text = "a", gapBefore = " ", boxes = box(0, 100, 10) },
    { text = "b", gapBefore = " ", boxes = box(20, 100, 10) },
}, { a = "x", b = "y" }, {})
check("scan plain words stay separate", #plain, 2)

if failures == 0 then
    print("ALL PASS")
else
    print(failures .. " FAILED")
end
os.exit(failures == 0 and 0 or 1)
