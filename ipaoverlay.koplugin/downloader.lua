local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local socket = require("socket")
local http = require("socket.http")
local socketutil = require("socketutil")
local _ = require("gettext")

local Engines = require("engines")

local Downloader = {}

local currentMessage
local function showStatus(text)
    if currentMessage then
        UIManager:close(currentMessage)
    end
    currentMessage = InfoMessage:new{ text = text }
    UIManager:show(currentMessage)
    UIManager:forceRePaint()
end

local function closeStatus()
    if currentMessage then
        UIManager:close(currentMessage)
        currentMessage = nil
    end
end

-- Sink that writes to file and reports the percentage every 10% so the screen keeps updating.
local function progressSink(file, expectedBytes, label)
    local received, lastReported = 0, -1
    local fileSink = socketutil.file_sink(file)
    return function(chunk, err)
        if chunk then
            received = received + #chunk
            local percent = math.min(99, math.floor(100 * received / expectedBytes / 10) * 10)
            if percent ~= lastReported then
                lastReported = percent
                showStatus(label .. " " .. percent .. "%")
            end
        end
        return fileSink(chunk, err)
    end
end

local function fetch(source, targetPath, label)
    local partialPath = targetPath .. ".part"
    local file = io.open(partialPath, "wb")
    if not file then
        return false, "cannot write " .. partialPath
    end
    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
    local code = socket.skip(1, http.request({
        url = source.url,
        method = "GET",
        sink = progressSink(file, source.expectedBytes, label),
    }))
    socketutil:reset_timeout()
    if code ~= 200 then
        os.remove(partialPath)
        return false, "HTTP " .. tostring(code)
    end
    return os.rename(partialPath, targetPath)
end

local function fileSize(path)
    local file = io.open(path, "rb")
    if not file then
        return 0
    end
    local size = file:seek("end")
    file:close()
    return size
end

-- Downloads the missing files of `engine` into dataDirectory, then calls onDone(success).
function Downloader.run(engine, dataDirectory, onDone)
    local missing = Engines.missingFiles(engine, dataDirectory)
    if #missing == 0 then
        onDone(true)
        return
    end
    NetworkMgr:runWhenOnline(function()
        showStatus(_("Starting download…"))
        UIManager:nextTick(function()
            local lfs = require("libs/libkoreader-lfs")
            lfs.mkdir(dataDirectory)
            local success, reason = true, nil
            for position, name in ipairs(missing) do
                local source = Engines.SOURCES[name]
                local target = dataDirectory .. "/" .. name
                local label = _("Downloading dictionary") .. " " .. position .. "/" .. #missing
                showStatus(label)
                success, reason = fetch(source, target, label)
                if success and fileSize(target) < source.minimumBytes then
                    os.remove(target)
                    success, reason = false, "file too small"
                end
                if not success then
                    break
                end
            end
            closeStatus()
            if not success then
                UIManager:show(InfoMessage:new{ text = _("Dictionary download failed:") .. " " .. tostring(reason) })
            end
            onDone(success)
        end)
    end)
end

return Downloader
