local json = require("cjson")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local Logger = require "logger"
local GDFEngine = require "integrations.providers.google.gdf.GDFEngine"

GDFTextToTextEngine = GDFEngine:new
    {
        language='hi'
    }

function GDFTextToTextEngine:init()
end

function GDFTextToTextEngine:process(text)
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id=self.session_id }
    print("input text")
    print(text)
    self.logger:msg(LEVEL_DEBUG, text)
    local body = {
      queryInput = {
         text = {
           text = text
            },
        languageCode = self.language
      },
      queryParams = {
        parameters= self.sys_params,
        timeZone = "America/Los_Angeles"
      }
    }
    self.logger:msg(LEVEL_DEBUG, "Body")
    headers= self:get_headers()
    headers["Content-Length"] = #json.encode(body)
    url= self:get_url()

    print(url)
    local response_body = {}
    local _, response_code, response_headers= https.request {
      url = url,
      method = "POST",
      headers = headers,
      source = ltn12.source.string(json.encode(body)),
      sink = ltn12.sink.table(response_body)
    }

    local response_json = table.concat(response_body)
    local output = json.decode(response_json)
    self.logger:msg(LEVEL_DEBUG, 'MATCH_TYPE: ' .. output["queryResult"]["match"]["matchType"])
    self.logger:msg(LEVEL_DEBUG, 'CONFIDENCE: ' .. output["queryResult"]["match"]["confidence"])
    if output["queryResult"]["match"]["event"] then
        self.logger:msg(LEVEL_DEBUG, 'EVENT: ' .. output["queryResult"]["match"]["event"])
    elseif output["queryResult"]["match"]["intent"] then
        self.logger:msg(LEVEL_DEBUG, 'DISPLAY_NAME: ' .. output["queryResult"]["match"]["intent"]["displayName"])
        if output["queryResult"]["match"]["intent"]["description"] then
            self.logger:msg(LEVEL_DEBUG, 'DESCRIPTION: ' .. output["queryResult"]["match"]["intent"]["description"])
        end
    end

    print(response_json)

    -- Assuming output.queryResult.responseMessages is an array of response message tables
    local responseMessages = output.queryResult.responseMessages

    -- Initialize an empty table to collect all the text pieces
    local textPieces = {}

    -- Loop through each response message
    for i, message in ipairs(responseMessages) do
        -- Check if text and text[1] are present
        if message.text and message.text.text and message.text.text[1] then
            table.insert(textPieces, message.text.text[1])
        end
    end

    -- Join all the collected text pieces with a space (or any other delimiter you prefer)
    local textResponse = table.concat(textPieces, " ")


    if self:checkEndInteraction(output.queryResult.responseMessages) then
       self.end_session = true
    end
    if output.queryResult then
        self:set_parameters(output.queryResult)
    end
    self.logger:msg(LEVEL_DEBUG, 'CONVERTED TEXT')
    self.logger:msg(LEVEL_DEBUG, textResponse)
    return textResponse
end

function GDFTextToTextEngine:feedHistoricalData(data)
    -- send parameters to GDF
end

return GDFTextToTextEngine
