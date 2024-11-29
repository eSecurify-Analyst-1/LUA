--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/17/16
-- Time: 11:34 AM
--

--[[
--
--  These constants must mirror corresponding ones in scheduling/models.py
--
]] --


FLOW_NODE_TYPE_PLAY = 1
FLOW_NODE_TYPE_RECORD = 2
FLOW_NODE_TYPE_MULTI_DIGIT = 7
FLOW_NODE_TYPE_PLAY_MULTI_DIGIT = 8
FLOW_NODE_TYPE_PLAY_RECORD = 9
FLOW_NODE_TYPE_END = 11
FLOW_NODE_TYPE_CAI = 12
FLOW_NODE_TYPE_PLAY_TTS = 13
FLOW_NODE_TYPE_NLU = 14
FLOW_NODE_TYPE_DETECT_SPEECH_STT = 15

ADV_OPT_VALID_DIGITS = "valid_digits"
ADV_OPT_MAX_DIGIT = "max_digits"
ADV_OPT_DIGIT_MASK = "digit_mask"
ADV_OPT_MAX_REC = "max_rec"
ADV_OPT_SLT_THRE = "max_silent_threshold"
ADV_OPT_SLT_SECS = "max_silent_seconds"
ADV_OPT_NLU_ENGINE = 'nlu_engine'
ADV_OPT_STT_ENGINE = 'stt_engine'
ADV_OPT_TTS_ENGINE = 'tts_engine'
ADV_OPT_NLU_LN = 'language'
ADV_OPT_SESSION_PARAMS = 'session_parameters'
ADV_OPT_STT_PARAMS = 'stt_params'
ADV_OPT_TTS_PARAMS = 'tts_params'
ADV_OPT_NLU_AGENT = 'nlu_uuid'
ADV_OPT_NLU_ENVIRONMENT_ID='nlu_environment_id'
ADV_OPT_PROMPT_INVALID_INP = "invalid_response"
ADV_OPT_PROMPT_NO_INPUT = "no_response"
ADV_OPT_PROMPT_HERE_RECORDED = "here_recorded"
ADV_OPT_PROMPT_NOT_SATISFIED = "not_satisfied"
ADV_OPT_PROMPT_VOICE_RECORDED = "voice_response"
ADV_OPT_PROMPT_WILDCARD_VALUE = "*"
ADV_OPT_POST_WEBHOOK_PARAMS = "post_webhook_params"
ADV_OPT_ENTITY_LIST = "entity_list"

INTERACTION_TYPE_VOICE = 1
INTERACTION_TYPE_KEY_PRESS = 2
INTERACTION_TYPE_TEXT = 3
INTERACTION_TYPE_RICH_TEXT = 4
INTERACTION_TYPE_LISTEN = 5

STATE_ATTEMPT_PENDING = 3
STATE_ATTEMPT_IN_PROGRESS = 4
STATE_ATTEMPT_SUCCESS = 5
STATE_ATTEMPT_FAILURE = 6
STATE_ATTEMPT_ABORTED = 7

-- CAI constant for stt class to play the first audio file.
INITIAL_GDF_PATH = "common/integrations/providers/google/gdf/text_to_voice.lua"
