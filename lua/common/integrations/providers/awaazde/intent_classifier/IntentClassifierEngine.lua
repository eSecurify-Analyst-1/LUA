local NLU = require 'nlu.natural_language_understanding'
local base64 = require("base64")
require 'settings'

IntentClassifierEngine =
{
    accesstoken = nil,
    agent_id=nil,
    session_id=nil,
    user_params=nil,
    sys_params=nil,
    end_session=false
}
setmetatable(IntentClassifierEngine, { __index = NLU })

function IntentClassifierEngine:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function IntentClassifierEngine:init()
    return True
end

function IntentClassifierEngine:feedHistoricalData(data)
 -- Pass parameters to GDF
end

function IntentClassifierEngine:get_url()
    url = 'https://cai.awaaz.de/intclass/classification'
    return url
end

function IntentClassifierEngine:checkEndInteraction(responseMessages)
    print("In interaction", responseMessages)
    return responseMessages.endInteraction
end

function IntentClassifierEngine:get_headers()
     headers = {
          ["Content-Type"] = "application/json",
        }
     return headers
end

function IntentClassifierEngine:set_parameters(result)
    self.user_params={}
    -- Below will remove parameters passed from flownode and add parameters set on agent
    res_params = result.parameters
    for k,v in pairs(res_params) do
         if type(v)~='table' and (self.sys_params[k]==nil or self.sys_params[k]~=v ) then
           self.user_params[k]=v
         end
    end
end

function IntentClassifierEngine:process(intents, input)
    -- Placeholder implementation for GDF Engine base class
    -- Implement logic for the 4 scenarios (input as text/output as text, input as text/output as voice, input as voice/output as text, input as voice/output as voice)
    return "IntentClassifierEngine result"
end

return IntentClassifierEngine
--
-- local gdf_engine = GDFEngine:new()
-- print(gdf_engine:process("input text", "output text"))  -- Placeholder implementation for GDF Engine base class
