--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/8/16
-- Time: 12:18 PM
--

require "common_constants"
require "settings"

local FlowFSM = require "scheduling_models"
local Logger = require "logger"
local DBH = require "dbhandler"
local Utility = require "utils"
--[[
    * Will have to set attempt_id as a session variable so we can associate CDR data to the right attempt
    when calls complete. Should be doable as
--]]

local Main = {
    callflow = nil
}

function Main:run()
    --[[
    -- Params: attempt_id, root_flow_node_id, schema_name info
    -- Output: Call the recipient, update Attempt state, play the Flow. Save call info on hangup
    --
    -- Steps:
    -- 1. Load the Flow into FSM
    -- 2. Execute the flow till end
    -- 3. End call and save Interaction results
    --
    ]] --


    -- getting the passed params
    local attempt_id = session:getVariable("attempt_id")
    local root_flow_node_id = session:getVariable("root_flow_node_id")
    local schema_name = session:getVariable("schema_name")
    local root_flow_node_target_content_type_id = session:getVariable("root_flow_node_target_content_type_id")
    local root_flow_node_target_object_id = session:getVariable("root_flow_node_target_object_id")

    -- get the called phone number
    local callee_phone_number = session:getVariable("caller_id_number")

    --Init debug and fs_env
    local fs_env = true

    local logger = Logger:new { fs_env = fs_env,
                                callee_phone_number = callee_phone_number,
                                script_name="core/outbound_main.lua",
                                schema_name = schema_name }
    logger:set_attempt_id(attempt_id)

    -- Init database connection
    local dbh = DBH:new {
        logger = logger,
        dbname = DBNAME,
        dbuser = DBUSER,
        dbpass = DBPASS,
        dbhost = DBHOST,
        dbport = DBPORT,
        dbschema = schema_name
    }

    -- init the call flow (FlowFSM)
    self.callflow = FlowFSM:new {
        session = session,
        logger = logger,
        attempt_id = attempt_id,
        root_flow_node_id = root_flow_node_id,
        target_content_type_id = root_flow_node_target_content_type_id,
        target_object_id = root_flow_node_target_object_id,
        dbh = dbh
    }

    local res = self.callflow:init()
    if res then
        -- can only set this after flow has been initialized
        -- since this confirms there's a live DB connection
        session:setHangupHook("hangupHook")

        --Answer the call - TODO - check if it's really needed since the script will only be invoke if call is pickup
        session:answer()

        --Start the FSM
        self.callflow:execute_call()
    end
end

function Main:get_active_call_flow()
    return self.callflow
end

function Main:execute_webhook(webhook_params)
   local url = require "socket.url"
   local encoded_post_webhook_params = url.escape(webhook_params)
   local request_body = POST_WEBHOOK_PARAMS .. encoded_post_webhook_params
   -- Bug 1449: To fix performance issue caused by lua-http package, we have implemented custom http module.
   local response = Utility:send_http_request(HTTP_POST,request_body,POST_WEBHOOK_URL)
end


function hangupHook(s, status, arg)
    local active_flow = Main:get_active_call_flow()
   -- if while loading the flow if somehow it gets failed then the self.callflow:init() will return false and attempt
   -- will be marked as failed. So for them active_flow can be null/ empty and we dont want to execute webhook for them
    if active_flow then
        -- Blast have usecase where there are no advanced_options then to prevent indexing nil value, we had added if condition
        if active_flow.root_flow_node:get_advanced_options() then
            local post_webhook_params = active_flow.root_flow_node:get_advanced_options()[ADV_OPT_POST_WEBHOOK_PARAMS]
            if post_webhook_params~=nil then
                Main:execute_webhook(post_webhook_params)
             end
        end
        active_flow:end_call()
    end
end


Main:run()
