local STT = require 'stt.speech_to_text'
require 'settings'

NAVANA_STT= {
  access_token = NAVANA_TOKEN
}

setmetatable(NAVANA_STT, {__index=STT})

function NAVANA_STT:transcribe(audio)
    -- TODO change path on server
    file_path = "/home/awaazde/" .. PATH .. "/backend/awaazde/ivr/freeswitch/lua/common/integrations/providers/navana/awaazde-navana.py"
    local command = string.format("bash -c 'source \"%s\" && python \"%s\" \"%s\"'", VIRTUAL_ENV, file_path, audio)
    handle = io.popen(command)  -- Add a space before audio
    output = handle:read("*a")
    handle:close()
    return output
end

return NAVANA_STT

