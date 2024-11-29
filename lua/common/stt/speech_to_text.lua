--TODO : Place common logic of STT here instead of repeating it
-- STT Interface and engine
local STT = {
 -- Default params, set this on individiual init for any changes
 language='hi',
 audio = nil
}

function STT:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function STT:transcribe(audio)
    -- Vendor-specific code for STT goes here
    -- This is a placeholder implementation for now
    return "Transcribed text"
end

return STT
