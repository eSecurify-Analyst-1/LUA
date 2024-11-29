--test
require 'settings'
local Logger = require "logger"

---------------- PARAMS NEEDED FROM FlowNode --------------------
local NOSTT_PATH = LUA_DIR .. '/common/integrations/providers/noprovider/no_stt.lua'
local NOTTS_PATH = LUA_DIR .. '/common/integrations/providers/noprovider/no_tts.lua'
local GDFVOICETOVOICE_PATH = LUA_DIR .. 'common/integrations/providers/google/gdf/voice_to_voice.lua'

local NAVANA_PATH = LUA_DIR .. '/common/integrations/providers/navana/speech_to_text.lua'
local GDFTEXTTOVOICE_PATH = LUA_DIR .. '/common/integrations/providers/google/gdf/text_to_voice.lua'

local AGENT_ID = '27169eb8-5501-4345-8451-ea6e8a8711f9'
function generate_session_id(length)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-=_"
    local session_id = ""

    for _ = 1, length do
        local random_index = math.random(1, #chars)
        local random_char = chars:sub(random_index, random_index)
        session_id = session_id .. random_char
    end

    return session_id
end
local SESSION_ID = generate_session_id(38)
local LANGUAGE = 'hi'
DYNAMIC_VALUES = {
   client_name = "ख़ुशी बैंक",
   current_loan_amount = "हजार",
   future_loan_amount='पैंतीस हजार'
}
ADV_OPT_MAX_REC = 7  -- Default constant RECORDING_MAX_LENGTH
ADV_OPT_SLT_THRE = 500
-- it tolerates this much before ending call
RECORD_DEFAULT_SILENCE_SECS = 2
-- If NLU is text to voice then pass text, if it's voice to voice then pass hello audio path(/home/awaazde/www/awaazde/media/hello-test.wav).
STARTUP_TEXT = 'हेलो'
--------------------------------------------------------------

local Main = {
 callflow=nil
}
-- #####  CHANGE BELOW MODULEs to load as per requirement
STT = dofile(NAVANA_PATH)
TTS = dofile(NOTTS_PATH)
NLUEngine = dofile(GDFTEXTTOVOICE_PATH)

function Main:play_file(filetoplay)
    -- play the audiofile
    if filetoplay and string.len(filetoplay) > 1 then
        --self.logger:msg(LEVEL_DEBUG,"FlowFSM:play_file\tStarted streaming file : " .. filetoplay)
        self.session:streamFile(filetoplay)
        return true
    end
end

function Main:record_file(record_filepath, max_len_secs, silence_threshold, silence_secs)
    local record_secs = self.session:recordFile(record_filepath, max_len_secs, silence_threshold, silence_secs)
    return record_secs
end


function Main:run()
    self.session = session
    self.session:execute("ring_ready");

    local fs_env = true
    self.logger = Logger:new { fs_env = true,
                                callee_phone_number = '123445',
                                script_name="loop.lua",
                                schema_name = 'schema',
                                attempt_id=1234 }

    stt = STT:new()
    nlu = NLUEngine:new({agent_id=AGENT_ID, session_id=SESSION_ID, language=LANGUAGE, sys_params=DYNAMIC_VALUES})
    tts = TTS:new()

    i=0
    allowed=50
    -- Calling first sentence from nlu
    local output_gdf = nlu:process(STARTUP_TEXT)
    Main:play_file(output_gdf)


    while i < allowed and not  nlu.end_session do
        filename = 'user_recorded_' ..os.time()
        record_file = nlu:get_media_path(filename)
        self.logger:msg(LEVEL_DEBUG, 'File Recording STARTED')

        recorded_sec = Main:record_file(record_file, ADV_OPT_MAX_REC, ADV_OPT_SLT_THRE, RECORD_DEFAULT_SILENCE_SECS)
        self.logger:msg(LEVEL_DEBUG, 'File Recording ENDED- ' .. recorded_sec .. record_file)
        if recorded_sec>0 then
            self.logger:msg(LEVEL_DEBUG, 'STT STARTED')
            local input_gdf = stt:transcribe(record_file)
            self.logger:msg(LEVEL_DEBUG, 'STT ENDED ' .. input_gdf)
            self.logger:msg(LEVEL_DEBUG,'GDF PROCESS STARTED')

            local output_gdf = nlu:process(input_gdf)
            self.logger:msg(LEVEL_DEBUG,'GDF PROCESS ENDED ' .. output_gdf)

            local final = tts:synthesize(output_gdf)
            Main:play_file(final)
        end
        i=i+1
        if nlu.end_session then
            self.session:hangup()
            break
        end
    end
    self.session:hangup()
end

Main:run()
