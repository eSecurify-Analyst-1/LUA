local GDFEngine = require "integrations.providers.google.gdf.GDFEngine"
local json = require("cjson")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local base64 = require("base64")
require 'settings'
require 'common_constants'

GDFVoiceToVoiceEngine = GDFEngine:new
{}

function GDFVoiceToVoiceEngine:init()
end

function GDFVoiceToVoiceEngine:feedHistoricalData(data)
    -- send parameters to GDF
end


function GDFVoiceToVoiceEngine:process(audioFile, audio_path)
    -- Additional implementation specific to GDF input as voice and output as voice
    local audioContent = assert(io.open(audioFile, "rb")):read("*all")
    local audioContentBase64 = base64.encode(audioContent)
    local body = {
      queryInput = {
        audio = {
          config = {
            audioEncoding = "AUDIO_ENCODING_UNSPECIFIED"
          },
          audio = audioContentBase64
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


return GDFVoiceToVoiceEngine

-- local gdf_voice_to_voice = GDFVoiceToVoiceEngine:new({agent_id='20b79d43-8685-4f1d-9d3f-84673b269c45', session_id='dd9ac301-97f5-4cc4-a80f-ad5751ff20fc', language='en'})
-- local audioFile = "/home/awaazde/Downloads/hello.wav"
--
-- print(gdf_voice_to_voice:process(audioFile))

