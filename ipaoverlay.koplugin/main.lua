local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ConfirmBox = require("ui/widget/confirmbox")
local Downloader = require("downloader")
local Engines = require("engines")
local IpaEnglish = require("ipa_en")
local IpaOverlay = require("overlay")
local Words = require("words")

local IpaPlugin = WidgetContainer:extend{
    name = "ipaoverlay",
    is_doc_only = true,
}

local AUTO_LABEL = _("Automatic (book metadata, English = US)")

local SIZE_CHOICES = { 60, 70, 80, 90, 100 }
local SHADE_CHOICES = {
    { name = _("Black"), color = "#000000" },
    { name = _("Dark gray"), color = "#444444" },
    { name = _("Medium gray"), color = "#666666" },
    { name = _("Light gray"), color = "#888888" },
}
local DEFAULT_SIZE = 80
local DEFAULT_SHADE = "#666666"
local DEFAULT_LINE_SPACING = 100
local MAX_POPUP_WORDS = 12

function IpaPlugin:dataDirectory()
    return DataStorage:getDataDir() .. "/ipaoverlay"
end

function IpaPlugin:init()
    self.engineInstances = {}
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/ipa_overlay.lua")
    Dispatcher:registerAction("ipa_overlay_toggle", {
        category = "none", event = "ToggleIpaOverlay", title = _("Toggle IPA pronunciation"), reader = true,
    })
    self.ui.menu:registerToMainMenu(self)
    self:addPronunciationButton()
    self.overlay = IpaOverlay:new(self)
    self.ui.view:registerViewModule("ipa_overlay", self.overlay)
end

function IpaPlugin:notify(text)
    UIManager:show(InfoMessage:new{ text = text })
end

function IpaPlugin:isOverlayOn()
    return self.ui.doc_settings ~= nil and self.ui.doc_settings:isTrue("ipa_overlay")
end

function IpaPlugin:setLineSpacing(percent)
    if percent ~= self.ui.font.configurable.line_spacing then
        self.ui:handleEvent(Event:new("SetLineSpace", percent))
    end
end

function IpaPlugin:refreshOverlay()
    if self:isOverlayOn() then
        self:setLineSpacing(self.overlay:requiredLineSpacing())
    end
    UIManager:setDirty("all", "partial")
end

function IpaPlugin:toggleOverlay()
    if not self.ui.rolling then
        self:notify(_("IPA pronunciation works only with EPUB files."))
        return
    end
    if self:isOverlayOn() then
        self.ui.doc_settings:saveSetting("ipa_overlay", false)
        self:setLineSpacing(DEFAULT_LINE_SPACING)
    else
        self.ui.doc_settings:saveSetting("ipa_overlay", true)
        self:withEngine(self:resolveVariant(), function() end)
    end
    self:refreshOverlay()
end

function IpaPlugin:disableAfterError()
    self.ui.doc_settings:saveSetting("ipa_overlay", false)
    UIManager:nextTick(function()
        self:setLineSpacing(DEFAULT_LINE_SPACING)
        self:notify(_("IPA pronunciation hit an error and was turned off for this book. See crash.log."))
    end)
end

function IpaPlugin:onReaderReady()
    if self:isOverlayOn() then
        self:refreshOverlay()
    end
end

function IpaPlugin:onToggleIpaOverlay()
    self:toggleOverlay()
    return true
end

function IpaPlugin:addPronunciationButton()
    self.ui.highlight:addToHighlightDialog("12_ipa_overlay", function(this)
        return {
            text = _("Pronunciation"),
            callback = function()
                local selected = this.selected_text and this.selected_text.text or ""
                this:onClose()
                self:showPronunciation(selected)
            end,
        }
    end)
end

function IpaPlugin:showPronunciation(text)
    self:withEngine(self:resolveVariant(), function(engine, options)
        local words = Words.lookup(text, function(word)
            return engine:lookup(word)
        end, options)
        if #words == 0 then
            return
        end
        local lines = {}
        for position, entry in ipairs(words) do
            if position > MAX_POPUP_WORDS then
                lines[#lines + 1] = "…"
                break
            end
            lines[#lines + 1] = entry.word .. "   " .. (entry.ipa and ("/" .. entry.ipa .. "/") or _("(no entry)"))
        end
        self:notify(table.concat(lines, "\n"))
    end)
end

-- Returns an engine id or nil. Automatic detection reads the book language, English means US.
function IpaPlugin:resolveVariant()
    local chosen = self.settings:readSetting("language", "auto")
    if chosen == "en" then
        chosen = "en_us"
    end
    if chosen ~= "auto" then
        return chosen
    end
    local language = self.ui.document:getProps().language
    local engine = language and Engines.forLanguage(language:sub(1, 2):lower())
    return engine and engine.id
end

-- Returns the ready engine and its lookup options, or nil when unknown or when its dictionary files are missing.
function IpaPlugin:engineFor(variant)
    local engine = variant and Engines.byId(variant)
    if not engine then
        return nil
    end
    if not self.engineInstances[variant] then
        self.engineInstances[variant] = engine.create(self:dataDirectory())
    end
    return self.engineInstances[variant], engine.options
end

-- Loads the dictionary files into memory behind a visible message, then calls callback(instance, options).
function IpaPlugin:loadEngine(engine, callback)
    local loading
    if #engine.files > 0 then
        loading = InfoMessage:new{ text = _("Loading dictionary…") }
        UIManager:show(loading)
        UIManager:forceRePaint()
    end
    self.engineInstances[engine.id] = nil
    local instance, options = self:engineFor(engine.id)
    if loading then
        UIManager:close(loading)
    end
    if instance then
        callback(instance, options)
        self:refreshOverlay()
    else
        self:notify(_("Could not load the pronunciation dictionary."))
    end
end

-- Calls callback(instance, options) once the engine is usable, offering the dictionary download when needed.
function IpaPlugin:withEngine(variant, callback)
    local engine = variant and Engines.byId(variant)
    if not engine then
        self:notify(_("Language not supported. Choose a language in the IPA pronunciation menu."))
        return
    end
    if self.engineInstances[variant] then
        callback(self.engineInstances[variant], engine.options)
    elseif #Engines.missingFiles(engine, self:dataDirectory()) == 0 then
        self:loadEngine(engine, callback)
    else
        UIManager:show(ConfirmBox:new{
            text = _("The pronunciation dictionary is not on this device yet. Download it now (about 5 MB)?"),
            ok_text = _("Download"),
            ok_callback = function()
                Downloader.run(engine, self:dataDirectory(), function(success)
                    if success then
                        self:loadEngine(engine, callback)
                    end
                end)
            end,
        })
    end
end

function IpaPlugin:deleteDictionaries()
    for _position, engine in ipairs(Engines.list()) do
        for _index, name in ipairs(engine.files) do
            os.remove(self:dataDirectory() .. "/" .. name)
        end
    end
    self.engineInstances = {}
    IpaEnglish.clearCache()
    self:refreshOverlay()
    self:notify(_("Downloaded dictionaries deleted. They are downloaded again when needed."))
end

function IpaPlugin:radioItems(choices, key, default, label)
    local items = {}
    for _index, choice in ipairs(choices) do
        local value = type(choice) == "table" and choice.color or choice
        items[#items + 1] = {
            text = label(choice),
            radio = true,
            checked_func = function()
                return self.settings:readSetting(key, default) == value
            end,
            callback = function()
                self.settings:saveSetting(key, value):flush()
                self:refreshOverlay()
            end,
        }
    end
    return items
end

function IpaPlugin:addToMainMenu(menu_items)
    local languageItems = {}
    local choices = { { id = "auto", label = AUTO_LABEL } }
    for _position, engine in ipairs(Engines.list()) do
        choices[#choices + 1] = engine
    end
    for _index, choice in ipairs(choices) do
        local code = choice.id
        languageItems[#languageItems + 1] = {
            text = choice.label,
            radio = true,
            checked_func = function()
                return self.settings:readSetting("language", "auto") == code
            end,
            callback = function()
                self.settings:saveSetting("language", code):flush()
                if self:isOverlayOn() then
                    self:withEngine(self:resolveVariant(), function()
                        self:refreshOverlay()
                    end)
                end
                self:refreshOverlay()
            end,
        }
    end
    menu_items.ipa_overlay = {
        text = _("IPA pronunciation"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Show pronunciation above words"),
                checked_func = function()
                    return self:isOverlayOn()
                end,
                callback = function()
                    self:toggleOverlay()
                end,
            },
            {
                text = _("Pronunciation size"),
                sub_item_table = self:radioItems(SIZE_CHOICES, "size", DEFAULT_SIZE, function(size)
                    return size .. "%"
                end),
            },
            {
                text = _("Pronunciation color"),
                sub_item_table = self:radioItems(SHADE_CHOICES, "shade", DEFAULT_SHADE, function(choice)
                    return choice.name
                end),
            },
            { text = _("Language"), sub_item_table = languageItems },
            {
                text = _("Delete downloaded dictionaries"),
                callback = function()
                    UIManager:show(ConfirmBox:new{
                        text = _("Delete the downloaded pronunciation dictionaries (about 5 MB)?"),
                        ok_text = _("Delete"),
                        ok_callback = function()
                            self:deleteDictionaries()
                        end,
                    })
                end,
            },
        },
    }
end

return IpaPlugin
