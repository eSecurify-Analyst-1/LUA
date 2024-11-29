local Logger = require "logger"
local Main = {
    callflow = nil
}

function Main:run()

    -- getting the destination number and caller number from  passed params
    local destination_phone_number = session:getVariable("sip_to_user")
    if destination_phone_number == nil then
        -- PRI/E1
        destination_phone_number = session:getVariable("destination_number")
    end
    local caller_phone_number = session:getVariable("caller_id_number")
    local fs_env = true
    local logger = Logger:new { fs_env = fs_env, callee_phone_number = caller_phone_number, script_name="test/cai_inbound.lua" }
    logger:msg(LEVEL_INFO,"Before")
    session:execute("ring_ready");
    session:sleep(10000);
    session:hangup("ORIGINATOR_CANCEL");
    logger:msg(LEVEL_INFO,"After")
    logger:msg(LEVEL_INFO, "Inbound Call:tcaller="..caller_phone_number.. " destination="..destination_phone_number)
    local api = freeswitch.API()
    logger:msg(LEVEL_ERROR,"ORIGINAL")
    logger:msg(LEVEL_ERROR,caller_phone_number)
    logger:msg(LEVEL_ERROR,destination_phone_number)
    local caller_phone_number_formatted = 0
    local length = string.len(caller_phone_number)
    logger:msg(LEVEL_ERROR,length)
    local caller_number_raw = string.sub(caller_phone_number, length-9)
    caller_phone_number_formatted = "0" .. caller_number_raw
    local phone_number_raw = string.sub(destination_phone_number, 3)
    logger:msg(LEVEL_ERROR,phone_number_raw)
    logger:msg(LEVEL_ERROR,caller_number_raw)
    local originate_str = "originate {ignore_early_media=true,caller_id_number=" ..destination_phone_number.. ",destination_number=" ..caller_phone_number_formatted.. ",sip_from_uri=" ..destination_phone_number.. "@10.0.70.190,sip_h_P-Preferred-Identity=sip:67771500@10.0.70.190,origination_caller_id_number=" ..destination_phone_number.. ",origination_caller_id_name=" ..destination_phone_number.. "}sofia/gateway/tata-profile/" ..caller_phone_number_formatted.. " '&lua(/home/awaazde/www/awaazde.awaazde2/backend/awaazde/ivr/freeswitch/lua/common/integrations/test/cai_test_outbound.lua)'"
    logger:msg(LEVEL_INFO,originate_str)
    local reply = api:executeString("bgapi " .. originate_str)
    logger:msg(LEVEL_INFO,reply)
end

Main:run()
