--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/9/16
-- Time: 12:33 PM
-- To change this template use File | Settings | File Templates.
--

--[[
--
--  LOGGING CONSTANTS
--
]] --

LEVEL_DEBUG = 1
LEVEL_ERROR = 2
LEVEL_WARN = 3
LEVEL_INFO = 4


--[[
--
--  STATES CONSTANTS
--
]] --

STATE_ACTIVE = 1
STATE_DELETED = 2


--[[
--
--  MEDIA CONSTANTS
--
]] --
RECORDING_MAX_LENGTH = 120

--[[
--
--  OTHER/COMMON CONSTANTS
--
]] --
DEFAULT_DELAY_SECS = 2
DEFAULT_RECORD_CONFIRM_DELAY = 5
DEFAULT_TERMINATOR = "#"
DEFAULT_RETRIES = 0
-- in seconds
DEFAULT_TIMEOUT_SECS = 4

--[[
--
--  RECORD RESPONSE CONSTANTS
--
]] --
RECORD_DEFAULT_NUM_REPEATS = 3
RECORD_DEFAULT_CONFIRM_RECORDING_REQUIRED = true
RECORD_DEFAULT_SILENCE_SECS = 5
RECORD_DEFAULT_RECORD_SOUND_EXT = '.wav'
RECORD_DEFAULT_SILENCE_THRESHOLD = 30
RECORD_DEFAULT_TERMINATORS = "1#"
RECORD_DEFAULT_CONFIRM_OPTION = "1"
RECORD_DEFAULT_RERECORD_OPTION = "2"
RECORD_DEFAULT_CANCEL_OPTION = "3"

--[[
--
--  MULTI DIGIT RESPONSE CONSTANTS
--
]] --
MULTI_DIGIT_TERMINATOR = "#"
MULTI_DIGIT_INPUT_THRESH = 4000
MULTI_DIGIT_DEFAULT_MIN_DIGITS = 1
MULTI_DIGIT_DEFAULT_MAX_DIGITS = 1
MULTI_DIGIT_DEFAULT_VALID_DIGITS = "0-9"
DIGIT_RANGE_DELIMITER = "|"
-- The number of times this function waits for digits and replays the prompt_audio_file when digits do not arrive
MULTI_DIGIT_DEFAULT_NUM_ATTEMPTS = 1
-- for validation on fs side
MULTI_DIGIT_FS_VALIDATION_PATTERN = "\\d+"
-- for validation - manual validation
MULTI_DIGIT_VALIDATION_PATTERN = "%d+"

--[[
--
--  Inbound Calling Consants
--
]] --
-- Should match param names in the inbound web service
DESTINATION_NUMBER = 'destination_number='
CALLER_NUMBER = 'caller_number='

-- For how much time we need to wait for response after request, If response not come in below timelimit then it gives
-- Request timeout error
REQUEST_TIMEOUT = 60

--[[
--
-- Response file create content constant
 ]] --
STATE_ACTIVE = 1
CONTENT_TYPE_RESPONSE_FILE = 7
FILE_TYPE_ORIGIAL = 1

-- Ref Bug-1321
-- should match param names in webhook web service
POST_WEBHOOK_PARAMS = 'post_webhook_params='

-- HTTP requests
HTTP_POST = "POST"


-- NLU MAX RETRY
NLU_MAX_RETRY = 2
