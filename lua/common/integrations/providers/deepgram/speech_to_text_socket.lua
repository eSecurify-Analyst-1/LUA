local STT = require 'stt.speech_to_text'
require 'settings'
local Logger = require "logger"
local json = require("cjson")
DEEPGRAM_STT= {
}

setmetatable(DEEPGRAM_STT, {__index=STT})

function DEEPGRAM_STT:transcribe(uuid,language,session,parameters,record_file_path)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id=self.session_id }
    session:execute("set","DEEPGRAM_API_KEY=" .. DEEPGRAM_API_KEY)
    session:execute("export","DEEPGRAM_API_KEY=" .. DEEPGRAM_API_KEY)

    enable_utterance_end_detection = parameters['transcribe_parameters']['enable_utterance_end_detection']
    if enable_utterance_end_detection == "true" then
        enable_utterance_end_detection = true
    else
        enable_utterance_end_detection = false
    end

    for key, value in pairs(parameters['general_parameters']) do
        param_str = key .. "=" .. value
        session:execute("set",param_str)
        session:execute("export",param_str)
    end

    chn = "mono"
    api:executeString("uuid_record " .. uuid .. " start " .. MEDIA_DIR .. record_file_path)
    api:execute("uuid_deepgram_transcribe", uuid.." start "..language.." interim "..chn)
    con = freeswitch.EventConsumer("CUSTOM","deepgram_transcribe::transcription")

    loop_counter = 0
    received_intermediate_event = false
    buffer_time_added = false
    final_speech_text = ""
    intermediate_speech_text = ""
    break_outer_loop = false
    while loop_counter < 50 do
        loop_counter = loop_counter + 1
        session:sleep(120)

        if loop_counter == 50 and received_intermediate_event==false and buffer_time_added==false then
            buffer_time_added = true
            loop_counter = 30
        end

        for e in (function() return con:pop(1,10) end) do
            unique_id = e:getHeader("Unique-ID")
            if unique_id == uuid then
                data = e:getBody()
                self.logger:msg(LEVEL_DEBUG,data)
                data_json = json.decode(data)
                if enable_utterance_end_detection and data_json and data_json["type"] == 'UtteranceEnd' then
                    self.logger:msg(LEVEL_DEBUG, "Utterance End found ----------")
                    break_outer_loop = true
                    break
                end

                if data_json['type'] == 'Results' then
                    channel = data_json["channel"]
                    if channel~=nil then
                        alternatives = channel["alternatives"]
                        if alternatives[1]~=nil then
                            speech_text = alternatives[1]["transcript"]
                            intermediate_speech_text = intermediate_speech_text .. ", " .. speech_text
                            if speech_text == nil or speech_text == "" then
                                ::continue::
                            else
                                loop_counter = 0
                                received_intermediate_event = true
                                self.logger:msg(LEVEL_DEBUG,"Speech Text:" .. speech_text)
                                self.logger:msg(LEVEL_DEBUG,"Final Text:" .. final_speech_text)
                                if data_json['is_final'] == true then
                                    if enable_utterance_end_detection == false then
                                        final_speech_text = speech_text
                                        break_outer_loop = true
                                        break
                                    else
                                        final_speech_text = final_speech_text .. ' ' .. speech_text
                                    end
                                else
                                    final_speech_text = final_speech_text .. ' ' .. speech_text
                                end
                            end
                        end
                    end
                end
            end
        end
        if break_outer_loop == true then
            break
        end
    end
    api:execute("uuid_deepgram_transcribe", uuid.." stop")
    api:executeString("uuid_record " .. uuid .. " stop " .. MEDIA_DIR .. record_file_path)
    return final_speech_text, intermediate_speech_text
end

return DEEPGRAM_STT
