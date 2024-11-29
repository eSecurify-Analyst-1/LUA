local AccessToken = require "integrations.providers.google.gdf.accesstoken"
local NLU = require 'nlu.natural_language_understanding'
require 'settings'
local base64 = require("base64")
local Utility = require "utils"
GDFEngine =
{
    service_account_json_path = GDF_ACCOUNT_PATH,
    accesstoken = nil,
    agent_id=nil,
    environment_id=nil,
    session_id=nil,
    project_id=GDF_PROJECT,
    user_params=nil,
    sys_params=nil,
    end_session=false
}
setmetatable(GDFEngine, { __index = NLU })

function GDFEngine:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function GDFEngine:init()
    return True
end

function GDFEngine:feedHistoricalData(data)
 -- Pass parameters to GDF
end

function GDFEngine:get_token()
    if not self.accesstoken then
        self.accesstoken = AccessToken(self.service_account_json_path)
    end
    return self.accesstoken.token
end

function GDFEngine:get_url()
    url = 'https://global-dialogflow.googleapis.com/v3/projects/' .. self.project_id .. '/locations/global/agents/' .. self.agent_id .. '/environments/' .. self.environment_id ..  '/sessions/'.. self.session_id ..':detectIntent'
    return url
end


function GDFEngine:saveAudio(audioResponse, audio_path)

    local timestamp = os.date("%Y-%m-%d_%H_%M_%S")
    -- building the filefor recorded file for given node
    file_name = 'gdf_response_' .. os.time()
    full_path = MEDIA_DIR .. audio_path
    outputFileHandle = assert(io.open(full_path, "wb"))
    outputFileHandle:write(base64.decode(audioResponse))
    outputFileHandle:close()
end

function GDFEngine:checkEndInteraction(responseMessages)
    for _, message in pairs(responseMessages) do
        if message["endInteraction"] then
            return true
        end
    end
    return false
end

function GDFEngine:get_headers()
     headers = {
          ["Content-Type"] = "application/json",
          ["x-goog-user-project"] = self.project_id,
          ["Authorization"] = "Bearer " .. self:get_token()
        }
     return headers
end

function GDFEngine:set_parameters(result)
    self.user_params={}
    -- Below will remove parameters passed from flownode and add parameters set on agent
    res_params = result.parameters
    for k,v in pairs(res_params) do
         if type(v)~='table' then
            if type(v)=="string" then
               self.user_params[k]=Utility:remove_unwanted_characters_from_string(v)
            else
               self.user_params[k]=v
            end
         elseif type(v)=='table' and v.name then
                self.user_params[k] = v.name
         end
    end

    if result["match"]["intent"] then
       self.user_params.intent = result["match"]["intent"]["displayName"]
    else
        self.user_params.intent = result["match"]["event"]
    end

    -- This will add custom parameters detected on intent with original values passed by user
    -- and deteched
    if result.diagnosticInfo and result.diagnosticInfo["Alternative Matched Intents"] then
        local intents = result.diagnosticInfo["Alternative Matched Intents"]
        for _, intent in ipairs(intents) do
            if intent.Parameters and intent.Score > 0.6 then
                for paramName, paramValue in pairs(intent.Parameters) do
                    if type(paramValue.resolved)=='string' then
                        self.user_params[paramName] = Utility:remove_unwanted_characters_from_string(paramValue.resolved)
                    end
                end
            end
        end
    end

end

function GDFEngine:process(input)
    -- Placeholder implementation for GDF Engine base class
    -- Implement logic for the 4 scenarios (input as text/output as text, input as text/output as voice, input as voice/output as text, input as voice/output as voice)
    return "GDF Engine result"
end

return GDFEngine
--
-- local gdf_engine = GDFEngine:new()
-- print(gdf_engine:process("input text", "output text"))  -- Placeholder implementation for GDF Engine base class
