local json = require("cjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local inspect = require("inspect")
local ADEngine = require "integrations.providers.awaazde.ADEngine"
local Logger = require "logger"
ADTextToTextEngine = ADEngine:new
    {
        language='hi'
    }

function ADTextToTextEngine:init()
end

function ADTextToTextEngine:process(text)
    self.logger = Logger:new { fs_env = true,callee_phone_number = 'ADLMEngine',script_name="loop.lua",schema_name = 'schema',attempt_id=self.session_id }
    self.logger:msg(LEVEL_DEBUG, "IN AD ENGINE TEXT TO TEXT: " .. text)
    print("input text")
    print(text)
    print(inspect(ADEngine))
    url= self:get_url()

    print("URL:", url)
    self.logger:msg(LEVEL_DEBUG, "URL: " .. url .. self.language)
    local data = { text = text, language=self.language, session_params=self.sys_params, nlu_uuid=self.agent_id}
    local json_data = json.encode(data)
    self.logger:msg(LEVEL_DEBUG, "Data: " .. json_data)
    response_body = {}
    -- Make the HTTP POST request
    local res, code, response_headers = http.request{
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_data)
        },
        source = ltn12.source.string(json_data),
        sink = ltn12.sink.table(response_body)
    }

    local response_json = table.concat(response_body)
    self.logger:msg(LEVEL_DEBUG,"Response: " .. tostring(response_json))
    local output = {}
    if response_json and response_json ~= "" then
       -- output = json.decode(response_json)
       local success, result = pcall(function()
            return json.decode(response_json)
       end)
       if success then
           output = result
       else
            -- Handle the error if JSON decoding failed
           self.logger:msg(LEVEL_DEBUG, "Error decoding JSON: " .. tostring(result))
           output.text=""
       end
    else
        self.logger:msg(LEVEL_DEBUG, "Warning: response_json is nil")
        output.text = ""  -- Set output as an empty string if response_json is nil
    end

    self.logger:msg(LEVEL_DEBUG,"AD ENGINE OUTPUT: " .. output.text)

    if self:checkEndInteraction(output) then
        print("End check")
        self.end_session = true
    end
    self.logger:msg(LEVEL_DEBUG, "Setting parameter")
    if output and output.parameters ~= nil then
        self:set_parameters(output)
    end
    self.logger:msg(LEVEL_DEBUG, "REACHED end of text to text")
    -- self.logger:msg(LEVEL_DEBUG, 'CONVERTED TEXT')
    -- self.logger:msg(LEVEL_DEBUG, textResponse)
    -- textResponse = 'abc'
    textResponse = output.text
    return textResponse
end

function ADTextToTextEngine:feedHistoricalData(data)
    -- send parameters to GDF
end


return ADTextToTextEngine
