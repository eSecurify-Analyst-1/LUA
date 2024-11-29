local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local Logger = require "logger"

local TTS = require 'tts.text_to_speech'
require 'settings'

ELEVENLABS_TTS= {}

setmetatable(ELEVENLABS_TTS, {__index=TTS})
function ELEVENLABS_TTS:synthesize(text, audio_path, language, parameters, session)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="ADLMEngine",schema_name = 'schema',attempt_id="123456" }
    -- If language is not passed, consider "hi" (Hindi) as default
    self.logger:msg(LEVEL_ERROR, "Inside ELEVENLABS tts streaming")
    self.logger:msg(LEVEL_ERROR, parameters['transcribe_parameters']['tts_voice'])
    language = language or "hi"
    tts_voice = parameters['transcribe_parameters']['tts_voice']

    if language == "hi" then
        speech_text = "{api_key=sk_37f8d2e76d47f4eadedd2a0962ad7a1a152075375aea17eb,voice=mActWQg9kibLro6Z2ouY,model_id=eleven_turbo_v2_5}"..text
        session:set_tts_params("elevenlabs","50YSQEDPA2vlOxhCseP4")
    else
        speech_text = "{api_key=sk_37f8d2e76d47f4eadedd2a0962ad7a1a152075375aea17eb,voice=vghiSqG5ezdhd8F3tKAD,model_id=eleven_turbo_v2_5}"..text
        session:set_tts_params("elevenlabs","vghiSqG5ezdhd8F3tKAD")
    end
    session:speak(speech_text)

    return audio_path
end

return ELEVENLABS_TTS
