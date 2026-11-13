local _ = require("gettext")
local IpaEnglish = require("ipa_en")
local IpaItalian = require("ipa_it")

-- Pinned upstream commits, the files are downloaded as published and converted on the device.
local SOURCES = {
    [IpaEnglish.CMUDICT_FILE] = {
        url = "https://raw.githubusercontent.com/cmusphinx/cmudict/74790861f652b15e4ac49015a90074ad62a27690/cmudict.dict",
        minimumBytes = 3000000,
        expectedBytes = 3600000,
        sha256 = "81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22",
    },
    [IpaEnglish.IPADICT_UK_FILE] = {
        url = "https://raw.githubusercontent.com/open-dict-data/ipa-dict/972cd67dd5f96bc5660e28070cde26e3928abcd7/data/en_UK.txt",
        minimumBytes = 1000000,
        expectedBytes = 1600000,
        sha256 = "221394caef0cf723b4f2df81a98ac33191293257b88aed5b1fb89466d3a0dc77",
    },
}

-- To add a language: append an entry. `files` lists the dictionary files it needs (keys of SOURCES, empty for rule
-- based engines), `languages` the ISO 639-1 codes that select it automatically, `create(dataDirectory)` returns an
-- object with lookup(word) or nil when files are missing.
local ENGINES = {
    {
        id = "en_us",
        label = _("English (US)"),
        languages = { "en" },
        files = { IpaEnglish.CMUDICT_FILE },
        options = { keepApostrophe = true },
        create = function(dataDirectory)
            return IpaEnglish.new("us", dataDirectory)
        end,
    },
    {
        id = "en_uk",
        label = _("English (UK)"),
        languages = {},
        files = { IpaEnglish.CMUDICT_FILE, IpaEnglish.IPADICT_UK_FILE },
        options = { keepApostrophe = true },
        create = function(dataDirectory)
            return IpaEnglish.new("uk", dataDirectory)
        end,
    },
    {
        id = "it",
        label = _("Italian"),
        languages = { "it" },
        files = {},
        options = {},
        create = function()
            return IpaItalian
        end,
    },
}

local Engines = { SOURCES = SOURCES }

function Engines.list()
    return ENGINES
end

function Engines.byId(id)
    for _position, engine in ipairs(ENGINES) do
        if engine.id == id then
            return engine
        end
    end
end

function Engines.forLanguage(code)
    for _position, engine in ipairs(ENGINES) do
        for _index, language in ipairs(engine.languages) do
            if language == code then
                return engine
            end
        end
    end
end

function Engines.missingFiles(engine, dataDirectory)
    local missing = {}
    for _position, name in ipairs(engine.files) do
        local file = io.open(dataDirectory .. "/" .. name, "r")
        if file then
            file:close()
        else
            missing[#missing + 1] = name
        end
    end
    return missing
end

return Engines
