local TTS = require 'tts.text_to_speech'
require 'settings'
-- When we don't want to use TTS engine, we'll use below class NO_TTS
local NO_TTS =
{}

setmetatable(NO_TTS, { __index = TTS })

function NO_TTS:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end


function NO_TTS:init()
    return True
end

function NO_TTS:synthesize(text,audio_path,language,parameter,session)
    session:streamFile(MEDIA_DIR .. audio_path)
    return nil
end

return NO_TTS

-- tts = NO_TTS:new()
-- local text = "Hello, World!"
-- print(tts:synthesize(text))
