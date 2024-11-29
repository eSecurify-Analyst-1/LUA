require "common_constants"
require "settings"
local json = require "JSON"
local url = require "socket.url"
local Logger = require "logger"
local DBH = require "dbhandler"
local Utility = require "utils"
local mime = require "mime"
local sqlite3 = require("lsqlite3")

local BASE_ENGINE_PATH = LUA_DIR .. '/common/integrations/providers/'
local STARTUP_TEXT = 'हेलो'
local Main = {
    callflow = nil
}
function Main:play_file(filetoplay)
    -- play the audiofile
    if filetoplay and string.len(filetoplay) > 1 then
        --self.logger:msg(LEVEL_DEBUG,"FlowFSM:play_file\tStarted streaming file : " .. filetoplay)
        session:streamFile(filetoplay)
        return true
    end
end

function Main:record_file(record_filepath, max_len_secs, silence_threshold, silence_secs)
    local record_secs = session:recordFile(record_filepath, max_len_secs, silence_threshold, silence_secs)
    return record_secs
end

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

function Main:get_cai_configuration(caller_id_number)
    local db = sqlite3.open("cai.db")

    local cai_conf_query = 'SELECT * FROM cai_configuration where ad_number="' .. caller_id_number .. '"'
    local stmt = db:prepare(cai_conf_query)
    local result = stmt:step()
    if result == sqlite3.ROW then
        stt_engine = stmt:get_value('stt_engine')
        nlu_engine = stmt:get_value('nlu_engine')
        nlu_uuid = stmt:get_value('nlu_uuid')
        tts_engine = stmt:get_value('tts_engine')
        parameters = stmt:get_value('parameters')
        recording_sec = stmt:get_value('recording_sec')
        silence_sec = stmt:get_value('silence_sec')
        report_email_ids = stmt:get_value('report_email_ids')
    end
end

function Main:get_gdf_media_path(session_id, filename)
    local d = os.date('*t');
    local year = d.year;
    local month = d.month;
    local day = d.day;

    if month < 10 then
        month = '0' .. month;
    end

    if day < 10 then
        day = '0' .. day;
    end

    local rootdir = 'ad_abcde' .. FS_RECORDING_MEDIA_DIR

    -- 2017/02/12/
    local subdir = year .. '/' .. month .. '/' .. day .. '/' .. session_id .. '/';

    -- create the folder path if it doesn't already exist
    if io.open(MEDIA_DIR .. rootdir .. subdir, "rb") == nil then
        os.execute("mkdir -p " .. MEDIA_DIR .. rootdir .. subdir)
        -- chmod from the rootdir on down
        os.execute("chmod -R 775 " .. MEDIA_DIR .. rootdir .. year)
    end
    outputFile = rootdir .. subdir .. filename .. RECORD_DEFAULT_RECORD_SOUND_EXT
    return outputFile
end

local SESSION_ID = generate_session_id(38)
local LANGUAGE = 'hi'
local GDFTEXTTOVOICE_PATH = LUA_DIR .. '/common/integrations/providers/google/gdf/text_to_voice.lua'
function Main:run()

    session:execute("ring_ready");

    -- getting the destination number and caller number from  passed params
    local destination_phone_number = session:getVariable("sip_to_user")
    if destination_phone_number == nil then
        -- PRI/E1
        destination_phone_number = session:getVariable("destination_number")
    end
    local caller_phone_number = session:getVariable("caller_id_number")

    -- Init the logger
    local fs_env = true
    local logger = Logger:new { fs_env = fs_env, callee_phone_number = caller_phone_number, script_name="cai_inbound_test.lua" , attempt_id=SESSION_ID}

    -- No attempt ID yet, so don't set it blank
    logger:msg(LEVEL_INFO, "Inbound Call:\tcaller="..destination_phone_number.. " destination="..caller_phone_number)

--     Main:get_cai_configuration(destination_phone_number)
    call_start_time=os.time()
    local db = sqlite3.open(LUA_DIR .. "/common/integrations/test/cai.db")

    local cai_conf_query = 'SELECT * FROM cai_configuration where ad_number="' .. caller_phone_number .. '"'
    local stmt = db:prepare(cai_conf_query)
    local result = stmt:step()
    if result == sqlite3.ROW then
        stt_engine = stmt:get_value(1)
        nlu_engine = stmt:get_value(2)
        nlu_uuid = stmt:get_value(3)
        tts_engine = stmt:get_value(4)
        parameters = stmt:get_value(5)
        recording_sec = stmt:get_value(6)
        silence_sec = stmt:get_value(7)
        silence_threshold = stmt:get_value(8)
        report_email_ids = stmt:get_value(9)
    end
    stmt:finalize()
    DYNAMIC_VALUES = json:decode(parameters)
    STT = dofile(BASE_ENGINE_PATH .. stt_engine)
    TTS = dofile(BASE_ENGINE_PATH .. tts_engine)
    NLUEngine = dofile(BASE_ENGINE_PATH .. nlu_engine)

    stt = STT:new()
    nlu = NLUEngine:new({agent_id=nlu_uuid, session_id=SESSION_ID, language=LANGUAGE, sys_params=DYNAMIC_VALUES})
    tts = TTS:new()

    i=0
    allowed=50
    filename = 'gdf_response_' ..os.time()
    filepath = Main:get_gdf_media_path(SESSION_ID, filename,logger)
    NLUEngine1 = dofile(GDFTEXTTOVOICE_PATH)
    nlu1 = NLUEngine1:new({agent_id=nlu_uuid, session_id=SESSION_ID, language=LANGUAGE, sys_params=DYNAMIC_VALUES})
    for key, value in pairs(nlu.sys_params) do
        logger:msg(LEVEL_DEBUG, "SYSTEM PARAMS " .. tostring(key) .. " - " .. tostring(value))
    end
    logger:msg(LEVEL_INFO,STARTUP_TEXT)
    logger:msg(LEVEL_INFO,filepath)
    local output_gdf = nlu1:process(STARTUP_TEXT, filepath)
    Main:play_file(MEDIA_DIR .. output_gdf)

    while i < allowed and not  nlu.end_session do
        filename = 'user_recorded_' ..os.time()
        record_file = Main:get_gdf_media_path(SESSION_ID, filename)
        logger:msg(LEVEL_DEBUG, 'File Recording STARTED')
        starttime=os.time()
        recorded_sec = Main:record_file(MEDIA_DIR .. record_file, recording_sec, silence_threshold, silence_sec)
        endtime=os.time()
        gp = endtime-starttime

        if recorded_sec>0 then
            logger:msg(LEVEL_DEBUG, 'File Recording ENDED - ' .. record_file)
            logger:msg(LEVEL_DEBUG, 'File Recording TIME TAKEN - ' ..gp)
            starttime=os.time()
            logger:msg(LEVEL_DEBUG, 'STT STARTED')
            local input_gdf = stt:transcribe(MEDIA_DIR ..record_file)
            endtime=os.time()
            logger:msg(LEVEL_DEBUG, 'STT ENDED ' .. input_gdf)
            gp = endtime-starttime
            logger:msg(LEVEL_DEBUG, 'STT TIME TAKEN(seconds) ' .. gp)

            logger:msg(LEVEL_DEBUG,'GDF PROCESS STARTED')
            filename = 'gdf_response_' .. os.time()
            audio_path = Main:get_gdf_media_path(SESSION_ID, filename)
            starttime=os.time()
            local output_gdf = nlu:process(input_gdf, audio_path)
            endtime=os.time()
            logger:msg(LEVEL_DEBUG,'GDF PROCESS ENDED ' .. output_gdf)
            gp = endtime-starttime
            logger:msg(LEVEL_DEBUG, 'GDF API TIME TAKEN(seconds) ' .. gp)

            local final = tts:synthesize(output_gdf)
            for key, value in pairs(nlu.user_params) do
                logger:msg(LEVEL_DEBUG, "USER PARAMS " .. tostring(key) .. " - " .. tostring(value))
            end
            Main:play_file(MEDIA_DIR .. final)
        else
            session:hangup()
            break
        end
        i=i+1
        if nlu.end_session then
            session:hangup()
            break
        end
    end
    logger:msg(LEVEL_DEBUG, 'CONTROL VARIABLES')
    logger:msg(LEVEL_DEBUG, 'AGENT_ID: ' .. nlu_uuid)
    logger:msg(LEVEL_DEBUG, 'MAX_RECORDING: ' .. recording_sec)
    logger:msg(LEVEL_DEBUG, 'SILENCE_SECS: ' .. silence_sec)
    logger:msg(LEVEL_DEBUG, 'SILENCE_THRESHOLD: ' .. silence_threshold)
    session:hangup()
    call_end_time = os.time()

    duration = call_end_time - call_start_time
    if nlu.user_params == nil then
        user_params = "{}"
    else
        user_params = json:encode(nlu.user_params)
    end
    local formattedTime = os.date("%Y-%m-%d %H:%M:%S", call_start_time)
    call_records_query = "INSERT INTO cai_call_records VALUES ('" .. SESSION_ID .. "','" .. destination_phone_number .. "','" .. caller_phone_number .. "','" .. formattedTime .. "','" .. duration .. "','" .. json:encode(DYNAMIC_VALUES) .. "','" .. user_params .. "');"
    logger:msg(LEVEL_INFO,call_records_query)
    db:exec(call_records_query)
    db:close()

    tts_bool="True"
    stt_bool="True"
    if string.find(tts_engine,"no_tts")~=nil then
        tts_bool="False"
    end

    if string.find(stt_engine,"no_stt")~= nil then
        stt_bool="False"
    end
    local call_date = os.date("%Y-%m-%d")
    local log_script = string.format('/home/awaazde/.virtualenvs/awaazde/bin/python3 ' .. LUA_DIR .. 'common/integrations/test/cai_log_generation_script.py --tts="%s" --stt="%s" --date="%s" --search="%s" --email="%s"', tts_bool, stt_bool, call_date, SESSION_ID,report_email_ids)
    os.execute(log_script)
end


Main:run()
