local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local Logger = require "logger"

local TTS = require 'tts.text_to_speech'
require 'settings'

GOOGLE_TTS= {}

setmetatable(GOOGLE_TTS, {__index=TTS})
function GOOGLE_TTS:synthesize(text, audio_path, language, parameters, session)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id="123456" }
    -- If language is not passed, consider "hi" (Hindi) as default
    language = language or "hi"
    tts_engine = "google_tts"
    tts_voice = parameters['transcribe_parameters']['tts_voice']
    file_path = MEDIA_DIR .. audio_path
    -- Bug 1615: To record TTS audio, we need to pass audio path to underlying Freeswitch TTS module along with text
    text = "{file_path="..file_path.."}"..text
    session:execute("speak", tts_engine .. "|" .. tts_voice .. "|" .. text)

    return audio_path
end

return GOOGLE_TTS
