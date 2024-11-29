local NLU = require 'nlu.natural_language_understanding'
local base64 = require("base64")
require 'settings'

ADEngine =
{
    accesstoken = nil,
    agent_id=nil,
    session_id=nil,
    user_params=nil,
    sys_params=nil,
    end_session=false
}
setmetatable(ADEngine, { __index = NLU })

function ADEngine:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function ADEngine:init()
    return True
end

function ADEngine:feedHistoricalData(data)
 -- Pass parameters to GDF
end

function ADEngine:get_url()
    -- TODO remove the condition once we fully move to the agents api instead of collections api
    if self.agent_id == "test_agent" then
        url = 'https://cai.awaaz.de/collections/llm/session/' .. self.session_id .. '/message'
    else
        url = 'https://cai.awaaz.de/agents/1/session/' .. self.session_id .. '/message'
    end

    return url
end


function ADEngine:saveAudio(audioResponse, audio_path)

    local timestamp = os.date("%Y-%m-%d_%H_%M_%S")
    -- building the filefor recorded file for given node
    file_name = 'gdf_response_' .. os.time()
    full_path = MEDIA_DIR .. audio_path
    outputFileHandle = assert(io.open(full_path, "wb"))
    outputFileHandle:write(base64.decode(audioResponse))
    outputFileHandle:close()
end

function ADEngine:checkEndInteraction(responseMessages)
    print("In interaction", responseMessages)
    if responseMessages and responseMessages.endInteraction ~= nil then
        return responseMessages.endInteraction
    else
        print("endInteraction key not found in responseMessages")
        return false -- Or return a default value if needed
    end

end

function ADEngine:get_headers()
     headers = {
          ["Content-Type"] = "application/json",
        }
     return headers
end

function ADEngine:set_parameters(result)
    self.user_params={}
    -- Below will remove parameters passed from flownode and add parameters set on agent
    res_params = result.parameters
    for k,v in pairs(res_params) do
         if type(v)~='table' and (self.sys_params[k]==nil or self.sys_params[k]~=v ) then
           self.user_params[k]=v
         end
    end
end

function ADEngine:process(input)
    -- Placeholder implementation for GDF Engine base class
    -- Implement logic for the 4 scenarios (input as text/output as text, input as text/output as voice, input as voice/output as text, input as voice/output as voice)
    return "AD Engine result"
end

return ADEngine
--
-- local gdf_engine = GDFEngine:new()
-- print(gdf_engine:process("input text", "output text"))  -- Placeholder implementation for GDF Engine base class
