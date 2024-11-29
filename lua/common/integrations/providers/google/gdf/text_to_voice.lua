local GDFEngine = require "integrations.providers.google.gdf.GDFEngine"
local json = require("cjson")
local https = require("ssl.https")
local ltn12 = require("ltn12")
require 'settings'
require 'common_constants'
local Logger = require "logger"

GDFTextToVoiceEngine = GDFEngine:new
{}

function GDFTextToVoiceEngine:init()
end


function GDFTextToVoiceEngine:feedHistoricalData(data)
    -- send parameters to GDF
end

function GDFTextToVoiceEngine:process(text, audio_path)
    -- Additional implementation specific to GDF input as text and output as voice
    self.logger = Logger:new { fs_env = true,callee_phone_number = '123445',script_name="loop.lua",schema_name = 'schema',attempt_id=self.session_id }
    print("input text")
    print(text)
    local body = {
      queryInput = {
         text = {
           text = text
            },
        languageCode = self.language
      },
      outputAudioConfig = {
        audioEncoding = "OUTPUT_AUDIO_ENCODING_LINEAR_16",
        sampleRateHertz = 8000,
        audioChannelCount = 1
      },
      queryParams = {
        parameters= self.sys_params,
        timeZone = "America/Los_Angeles"
      }
    }

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
    audioResponse = output.outputAudio
    if self:checkEndInteraction(output.queryResult.responseMessages) then
       self.end_session = true
    end
    if output.queryResult then
        self:set_parameters(output.queryResult)
    end
    self:saveAudio(audioResponse, audio_path)
    return audio_path
end


return GDFTextToVoiceEngine
