local STT = require 'stt.speech_to_text'
require 'settings'

DEEPGRAM_STT= {
  access_token = DEEPGRAM_TOKEN
}

setmetatable(DEEPGRAM_STT, {__index=STT})

function DEEPGRAM_STT:transcribe(audio)
    -- TODO change path on server
    file_path = "/home/awaazde/" .. PATH .. "/backend/awaazde/ivr/freeswitch/lua/common/integrations/providers/deepgram/awaazde-deepgram.py"
    local command = string.format("bash -c 'source \"%s\" && python \"%s\" \"%s\"'", VIRTUAL_ENV, file_path, audio)
    handle = io.popen(command)  -- Add a space before audio
    output = handle:read("*a")
    handle:close()
    return output
end

return DEEPGRAM_STT
