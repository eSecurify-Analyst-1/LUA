local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local inspect = require("inspect")
local IntentClassifierEngine = require "integrations.providers.awaazde.intent_classifier.IntentClassifierEngine"
local Logger = require "logger"
IntentClassifierTextToTextEngine = IntentClassifierEngine:new
    {
        language='hi'
    }

function IntentClassifierTextToTextEngine:init()
end

function IntentClassifierTextToTextEngine:process(intents, user_input)
    self.logger = Logger:new { fs_env = true,callee_phone_number = 'IntentClassifierTextToTextEngine',script_name="intent_classifier.text_to_text.lua",schema_name = 'schema',attempt_id=self.session_id }
    self.logger:msg(LEVEL_DEBUG, "Calling LM API for getting intent of text: " .. user_input)


    -- Prepare the payload
    local payload = {
        intents = intents,
        utterance = user_input
    }

    -- Convert the payload to JSON
    local payload_json = json.encode(payload)

    -- Prepare response holder
    local response_body = {}

    -- Make the HTTP POST request
    local result, status, headers = http.request {
        url = self.get_url(),
        method = "POST",
        headers = self.get_headers(),
        source = ltn12.source.string(payload_json),
        sink = ltn12.sink.table(response_body)
    }

    -- Check if the request was successful
    if status == 200 then
        -- Decode the JSON response
        local response_json = table.concat(response_body)
        local response = json.decode(response_json)

        -- Log the received response
        self.logger:msg(LEVEL_DEBUG, string.format("FlowFSM:call_nlu_api\tReceived NLU API response: %s", response_json))

        -- Extract the intent from the response
        if response then
            return response
        else
            self.logger:msg(LEVEL_ERROR, "FlowFSM:call_nlu_api\tNo intent found in NLU API response")
            return nil
        end
    else
        -- Log the error
        self.logger:msg(LEVEL_ERROR, string.format("FlowFSM:call_nlu_api\tFailed to reach NLU API. Status: %d", status))
        return nil
    end
end

function IntentClassifierTextToTextEngine:feedHistoricalData(data)
    -- send parameters to GDF
end


return IntentClassifierTextToTextEngine
