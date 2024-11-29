--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/8/16
-- Time: 12:19 PM
-- To change this template use File | Settings | File Templates.
--

require "common_constants"
require "settings"
local request = require "http.request"
local json = require "JSON"
local url = require "socket.url"
local FlowFSM = require "scheduling_models"
local Logger = require "logger"
local DBH = require "dbhandler"
local Utility = require "utils"
local mime = require "mime"
--[[
    * Will have to set attempt_id as a session variable so we can associate CDR data to the right attempt
    when calls complete. Should be doable as
--]]

local Main = {
    callflow = nil
}

function Main:run()
    --[[
    --
    -- All inbound calls hit this script. Call a web service to get a call flow to execute, or just cut
    -- the call if nothing is return (missed call)
    --
    -- Steps:
    -- 1. Set call to Ringing
    -- 2. Call the web service, passing destination and caller
    -- 3. If web service returns a flow, execute it. If not, cut the call.
    --
    ]]--

    session:execute("ring_ready");

    -- getting the destination number and caller number from  passed params
    local destination_phone_number = session:getVariable("sip_to_user")
    if destination_phone_number == nil then
        -- PRI/E1
        destination_phone_number = session:getVariable("destination_number")
    end
    local caller_phone_number = session:getVariable("caller_id_number")
    destination_phone_number = '+91'.. destination_phone_number:sub(-10)
    -- Init the logger
    local fs_env = true
    local logger = Logger:new { fs_env = fs_env, callee_phone_number = caller_phone_number, script_name="core/inbound_main.lua" }

    -- No attempt ID yet, so don't set it blank
    logger:msg(LEVEL_INFO, "Inbound Call:\tcaller="..caller_phone_number.. " destination="..destination_phone_number)

    -- Create request body using caller number, destination number and secret token
    local encoded_caller_number = url.escape(caller_phone_number)
    local encoded_destination_number = url.escape(destination_phone_number)
    local request_body = DESTINATION_NUMBER .. encoded_destination_number .. '&' .. CALLER_NUMBER .. encoded_caller_number

    -- Create new request from URL
    local request = request.new_from_uri(INBOUND_FLOW_URL)

    -- Setup headers
    request.headers:upsert("authorization", "Basic " .. (mime.b64(API_USERNAME ..":" .. API_PASSWORD)) )
    request.headers:upsert(":method", "POST")
    request.headers:upsert("content-length", tostring(#request_body))
    request.headers:upsert("content-type", "application/x-www-form-urlencoded")

    -- Set request body
	request:set_body(request_body)

    -- POST to the web service URL to get Flow info
    local headers, stream = request:go(REQUEST_TIMEOUT)
    local body, err = stream:get_body_as_string()

    -- Parse response as a json
    local ok, flow_params = pcall(json.decode, json, body)

    if (ok and flow_params and flow_params.attempt_id ~= nil) then
        logger:set_schema_name(flow_params.schema_name)
        logger:set_attempt_id(flow_params.attempt_id)

        -- setting this as session variable so it gets write into cdr
        session:setVariable("attempt_id", flow_params.attempt_id)
        session:setVariable("root_flow_node_id", flow_params.root_flow_node_id)
        session:setVariable("schema_name", flow_params.schema_name)
        session:setVariable("root_flow_node_target_content_type_id", flow_params.root_flow_node_target_content_type_id)
        session:setVariable("root_flow_node_target_object_id", flow_params.root_flow_node_target_object_id)
        session:setVariable("success_index", flow_params.success_index)

        -- Init database connection
        local dbh = DBH:new {
            logger = logger,
            dbname = DBNAME,
            dbuser = DBUSER,
            dbpass = DBPASS,
            dbhost = DBHOST,
            dbport = DBPORT,
            dbschema = flow_params.schema_name
        }

        -- init the call flow (FlowFSM)
        self.callflow = FlowFSM:new {
            session = session,
            logger = logger,
            attempt_id = flow_params.attempt_id,
            root_flow_node_id = flow_params.root_flow_node_id,
            target_content_type_id = flow_params.root_flow_node_target_content_type_id,
            target_object_id = flow_params.root_flow_node_target_object_id,
            dbh = dbh
        }

        local res = self.callflow:init()
        if res then
            session:setHangupHook("hangupHook")

            --Answer the call
            session:answer()

            --Start the FSM
            self.callflow:execute_call()
        end

    end
    -- 5 second ring play, User can terminate call or system terminate call after 5 second
    session:sleep(3000);
    -- otherwise hangup
    -- When call normal hangup, In all operator call cut as expected but in BSNL there is some issue
    -- Call was not cut automatically but it plays "Number not available", So we set hangup cause to
    -- "ORIGINATOR_CANCEL" So that it cut normally
    session:hangup("ORIGINATOR_CANCEL");
    logger:msg(LEVEL_INFO, "Inbound Call:\tNo Attempt, hanging up")

end

function Main:get_active_call_flow()
    return self.callflow
end


function hangupHook(s, status, arg)
    local active_flow = Main:get_active_call_flow()

    if active_flow then
        active_flow:end_call()
    end
end


Main:run()
