local STT = require 'stt.speech_to_text'
require 'settings'
local Logger = require "logger"
local json = require("cjson")
NAVANA_STT= {
}

setmetatable(NAVANA_STT, {__index=STT})

function NAVANA_STT:transcribe(uuid,language,session,parameters,record_file_path)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id=self.session_id }

    enable_utterance_end_detection=parameters['transcribe_parameters']['enable_utterance_end_detection']
    session:execute("set","BODHI_API_KEY=" .. BODHI_API_KEY)
    session:execute("export","BODHI_API_KEY=" .. BODHI_API_KEY)
    session:execute("set","BODHI_CUSTOMER_ID=" .. BODHI_CUSTOMER_ID)
    session:execute("export","BODHI_CUSTOMER_ID=" .. BODHI_CUSTOMER_ID)
    for key, value in pairs(parameters['general_parameters']) do
        param_str = key .. "=" .. value
        session:execute("set",param_str)
        session:execute("export",param_str)
    end

    models = {kn = 'kn-banking-v2-8khz',ta='ta-banking-v2-8khz',mr='mr-banking-v2-8khz',gu='gu-banking-v2-8khz'}
    api:executeString("uuid_record " .. uuid .. " start " .. MEDIA_DIR .. record_file_path)
    api:execute("uuid_bodhi_transcribe" , uuid .. " start " .. models[language])
    con = freeswitch.EventConsumer("CUSTOM","bodhi_transcribe::transcription")

    loop_counter = 0
    received_intermediate_event = false
    intermediate_speech_text = ""
    buffer_time_added = false
    final_speech_text = ""
    break_outer_loop =  false
    while loop_counter < 50 do
        loop_counter = loop_counter + 1
        session:sleep(120)
        if loop_counter == 50 and received_intermediate_event==false and buffer_time_added==false then
            --consoleLog("ERR", "No intermediate transcription event received, giving extra buffer time to receive transcription")
            buffer_time_added = true
            loop_counter = 30
        end

        for e in (function() return con:pop(1,10) end) do
            unique_id = e:getHeader("Unique-ID")
            if unique_id == uuid then
                data = e:getBody()
                self.logger:msg(LEVEL_DEBUG,data)
                data_json = json.decode(data)
                speech_text = data_json['text']
                if speech_text == nil or speech_text == "" then
                    ::continue::
                else
                    loop_counter = 0
                    received_intermediate_event = true
                    intermediate_speech_text = intermediate_speech_text .. ", " .. speech_text
                    self.logger:msg(LEVEL_DEBUG,"Speech text:" .. speech_text)
                    final_speech_text = speech_text
                    if data_json['type'] == 'complete' then
                        break_outer_loop = true
                        break
                    end
                end
            end
        end
        if break_outer_loop == true then
            break
        end
    end
    api:execute("uuid_bodhi_transcribe ", uuid.." stop")
    api:executeString("uuid_record ".. uuid .. " stop " .. MEDIA_DIR .. record_file_path)
    return final_speech_text, intermediate_speech_text
end

return NAVANA_STT
