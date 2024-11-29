local STT = require 'stt.speech_to_text'

-- When we don't want to use STT engine, we'll use below class NO_STT
local NO_STT =
{}

setmetatable(NO_STT, { __index = STT })

function NO_STT:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end


function NO_STT:init()
    return True
end

function NO_STT:transcribe(text)
    return text
end
return NO_STT
-- stt = NO_STT:new()
-- local text = "Hello, World!"
-- print(stt:transcribe(text))
