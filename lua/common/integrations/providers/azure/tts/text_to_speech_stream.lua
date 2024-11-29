local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local Logger = require "logger"

local TTS = require 'tts.text_to_speech'
require 'settings'

AZURE_TTS= {}

setmetatable(AZURE_TTS, {__index=TTS})
function AZURE_TTS:synthesize(text, audio_path, language, parameters, session)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id="123456" }
    -- If language is not passed, consider "hi" (Hindi) as default
    language = language or "hi"
    tts_engine = "microsoft"
    tts_voice = parameters['transcribe_parameters']['tts_voice']
    azure_ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='https://www.w3.org/2001/mstts' xml:lang='hi-IN'><voice name='hi-IN-AartiNeural'><prosody rate='1.1'><mstts:express-as style='emphatic' styledegree='5'>"..text.."</mstts:express-as></prosody></voice></speak>"
    text = "{language=hi,api_key=3e80d9264af149e2b4df72fdc8c2c6e1,region=centralindia,voice=hi-IN-AartiNeural}"..azure_ssml
    session:execute("speak", tts_engine .. "|" .. tts_voice .. "|" .. text)

    return audio_path
end

return AZURE_TTS
