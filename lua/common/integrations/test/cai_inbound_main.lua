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
    logger:msg(LEVEL_INFO, "Inbound Call:\tcaller="..caller_phone_number.. " destination="..destination_phone_number)
    local api = freeswitch.API()
    local originate_str = "originate {ignore_early_media=true,caller_id_number="..destination_phone_number.. ",destination_number=" ..caller_phone_number.. "origination_caller_id_number=" .. destination_phone_number .. ",origination_caller_id_name=" .. destination_phone_number .. ",sip_from_uri=" .. caller_phone_number .. "@182.76.167.99}sofia/gateway/voxbeam/" .. caller_phone_number .. "'&lua(/home/awaazde/www/awaazde/backend/awaazde/ivr/freeswitch/lua/common/integrations/test/cai_inbound_test.lua)'"
    local reply = api:executeString("bgapi " .. originate_str)
    session:hangup()
end

Main:run()
