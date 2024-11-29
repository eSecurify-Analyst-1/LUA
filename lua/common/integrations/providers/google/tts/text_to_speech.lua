local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local Logger = require "logger"

local TTS = require 'tts.text_to_speech'
require 'settings'

GOOGLE_TTS= {}

setmetatable(GOOGLE_TTS, {__index=TTS})

function decode_base64(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i - 1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0) end
        return string.char(c)
    end))
end

function synthesizeTextToSpeech(text, audio_file_path, language)
    -- Function makes API call to Google TTS and writes the content to audio_file_path
    logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id="123456" }
    -- Google TTS API KEY
    local API_KEY = 'AIzaSyBTzR4UPpoMuzCefb01vRT1MYolaDk3eBU'

    -- URL for the Text-to-Speech API
    local url = string.format("https://texttospeech.googleapis.com/v1/text:synthesize?key=%s", API_KEY)
    -- Determine languageCode and name based on language parameter
    local languageCode
    local name
    if language == "hi" then
        languageCode = "hi-IN"
        name = "hi-IN-Standard-A"
    elseif language == "kn" then
        languageCode = "kn-IN"
        name = "kn-IN-Standard-A"
    elseif language == "mr" then
        languageCode = "mr-IN"
        name = "mr-IN-Standard-A"
    elseif language == "gu" then
        languageCode = "gu-IN"
        name = "gu-IN-Standard-A"
    end

    -- JSON body
    local body = {
        audioConfig = {
            audioEncoding = "LINEAR16"
        },
        input = {
            text = text
        },
        voice = {
            languageCode = languageCode,
            name = name
        }
    }
    logger:msg(LEVEL_DEBUG, "Calling Google TTS API.. ")
    local body_json = json.encode(body)
    -- Headers
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#body_json)
    }
    -- Making the POST request
    local response_body = {}
    local res, code, response_headers, status = http.request {
        url = url,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(body_json),
        sink = ltn12.sink.table(response_body)
    }

    -- Checking the response
    if code == 200 then
        logger:msg(LEVEL_DEBUG, "Request was successful!")
        local response_data = json.decode(table.concat(response_body))
        -- The synthesized audio content is in the response's 'audioContent' field
        local audio_content = response_data.audioContent
        -- Decode the base64-encoded audio content
        local decoded_audio_content = decode_base64(audio_content)
        -- Save the audio content to a file
        local file = io.open(audio_file_path, 'wb')
        file:write(decoded_audio_content)
        file:close()
        logger:msg(LEVEL_DEBUG, "Audio content saved to " .. audio_file_path)
    else
        logger:msg(LEVEL_DEBUG, "Request failed with status code")
    end
end


function GOOGLE_TTS:synthesize(text, audio_path, language, parameters,session)
    -- If language is not passed, consider "hi" (Hindi) as default
    language = language or "hi"
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id="123456" }
    self.logger:msg(LEVEL_DEBUG, "Text to send to Google TTS")
    self.logger:msg(LEVEL_DEBUG, text)
    audio_file_path = MEDIA_DIR .. audio_path
    self.logger:msg(LEVEL_DEBUG, audio_file_path)

    synthesizeTextToSpeech(text, audio_file_path, language)
    session:streamFile(audio_file_path)
    return audio_path
end

return GOOGLE_TTS
