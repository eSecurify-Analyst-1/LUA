--
-- Scheduling models including Attempt, Interaction, FlowNode, FlowNodeOption, FSM, etc
--

require "common_models"
require "scheduling_constants"
require "settings"
socket = require "socket"
local http = require("socket.http")
local ltn12 = require("ltn12")
local inspect = require "inspect"
local json = require("cjson")
-- can be used at anywhere below - serve as a static class
local Utility = require "utils"


--[[
-- File class For saving Interaction's response file,
-- First we create Content of response file and set content fk to Interaction response file
-- Actually response file is stored in File so create file object and assign contant fk
]] --
local File = BaseModel:new
    {
        content_id = nil,
        file = nil,
        type = FILE_TYPE_ORIGIAL,
        provider = nil,
        created = nil,
        modified = nil,
        state = STATE_ACTIVE,
        dbschema = nil
    }

function File:init()
end

--[[
-- Save object to database and returns the id of created object
]] --
function File:save()
    -- Create table to insert data in database
    data = { content_id = self.content_id, type = self.type, file = self.file, created = self.created, modified = self.modified, state = self.state }

    -- insert_into_table insert record in database and return ID of inserted record
    file = self.dbh:insert_into_table("content_file", data, false)

    self.logger:msg(LEVEL_DEBUG, "File:save\tcontent : " .. self.content_id .. ", file : " .. self.file)

    -- Return inserted record ID
    return file_id
end

--[[
-- Content class For saving Interaction's response file as a content
-- Actually file is Stored in File object and it's associated with content,
-- So we also need to create file and set content fk
]] --
local Content = BaseModel:new
    {
        name = nil,
        description = nil,
        type = CONTENT_TYPE_RESPONSE_FILE,
        text = nil,
        parent = nil,
        created = nil,
        modified = nil,
        state = STATE_ACTIVE,
        response_file = nil,
        dbschema = nil
    }

function Content:init()
end

--[[
-- Save content object, Then create file object and save to database
-- Return Content object id
]] --
function Content:save()
    -- Create table to insert data in database
    data = { name = self.name, type = self.type, created = self.created, modified = self.modified, state = self.state }

    -- insert_into_table insert record in database
    content = self.dbh:insert_into_table("content_content", data, true)

    -- get last last inserted row id
    content_id = self.dbh:get_table_field("content_content", "id", string.format("name = %s", self.name))

    -- Print statement
    self.logger:msg(LEVEL_DEBUG, "Content:save\tID : " .. content_id .. ", file : " .. self.response_file)

    -- Create file object and set content as a fk
    file = File:new({ content_id = content_id, file = self.response_file, logger = self.logger, dbh = self.dbh, created = 'now()', modified = 'now()', dbschema = self.dbschema })
    file:save()

    -- Return inserted record ID
    return content_id
end

--[[
-- Interaction class
--
-- For saving call interactions
]] --
-- prev_node_id is a temporary id which stores the previous FlowNode's id for Intent Classifier models.
-- prev_node_id will not be stored in the RDS when Interaction objects are saved.
local Interaction = BaseModel:new {
    attempt_id = nil,
    duration = nil,
    node_id = nil,
    type = nil,
    data=nil,
    response_value = nil,
    response_file_id = nil,
    prev_node_id = nil
}

--[[
--
-- Returns the node id
]] --
function Interaction:get_node()
    return self.node_id
end

--[[
--
-- Returns the type of interaction
]] --
function Interaction:get_type()
    return self.type
end

--[[
--
-- Sets the type of interaction
]] --
function Interaction:set_type(type)
    self.type = type
end

--[[
--
-- Sets the duration of interaction - shoud be in format of HH:MM:SS only
]] --
function Interaction:set_duration(duration)
    self.duration = duration
end

--[[
--
-- Sets the response value - only applicable when multi-digit input
]] --
function Interaction:set_response_value(response_value)
    self.response_value = response_value
end

--[[
--
-- sets the response file path - only applicable when record input
]] --
function Interaction:set_response_file_id(response_file_id)
    self.response_file_id = response_file_id
end



--[[
-- Attempt class
--
-- Combination of content sent to a Recipient
-- Define the content getter at the app level since it's app-specific

]] --
local Attempt = BaseModel:new
    {
        uuid = nil,
        recipient = nil,
        attempted_at = nil,
        success_index = nil,
        inbound = nil,
        delivery_status_code = nil,
        state = nil,
        completed = nill
    }

--[[
--
-- Init the attempt
]] --
function Attempt:init()
end

--[[
-- Query the data source for ID if it's not already loaded.
-- This is used particularly in inbound case where we created
-- the Attempt object locally
--]]
function Attempt:load_id()
    if not self.get_id() then
        -- load from db based on uuid
        if not self.uuid then
            self.logger:msg(LEVEL_ERROR, "Attempt:init\tNo id or uuid to load data")
            return false
        end

        -- assumes uuid is unique
        self.id = self.dbh:get_table_field("scheduling_attempt attempt", "id", string.format("uuid = %s", self.uuid))
        return true
    end
    return true
end



--[[
-- FlowNode class
--
-- A node representing content presented to user for interaction

]] --
local FlowNode = BaseModel:new
    {
        name = nil,
        type = nil,
        content = nil,
        retries = nil,
        timeout = nil,
        target_content_type_id = nil,
        target_object_id = nil,
        root_node = nil,
        advanced_options = nil,
        parsed_advanced_options = nil,
        -- internal clock per node to track duration, We store milliseconds in this
        start_time = nil,
        -- store the result of this node internally as well
        result = nil
    }

--[[
--
-- Returns the node type
]] --
function FlowNode:get_type()
    return tonumber(self.type)
end

--[[
--
-- Returns the node content
]] --
function FlowNode:get_content()
    return self.content
end

--[[
--
-- Returns the number of retries set on node
]] --
function FlowNode:get_retries()
    return tonumber(self.retries) or DEFAULT_RETRIES
end

--[[
--
-- Returns the timeout value set in seconds on node
]] --
function FlowNode:get_timeout()
    return tonumber(self.timeout) or DEFAULT_TIMEOUT_SECS
end

--[[
--
-- Returns the node's target content type id
]] --
function FlowNode:get_target_content_type()
    return self.target_content_type_id
end

--[[
--
-- Returns the node's target object id
]] --
function FlowNode:get_target_object_id()
    return self.target_object_id
end


--[[
-- Checks if the node is root node or not
-- Returns true if root not else false
]] --
function FlowNode:is_root_flow_node()
    return (self.root_node == 't')
end

--[[
--
-- Returns the advanced options available on node
-- Returns table: {adv_opt_1 : value, adv_opt_2 : value, ...}
]] --
function FlowNode:get_advanced_options()
    -- caching the advanced option table
    if self.parsed_advanced_options==nil then
        if self.advanced_options then
            self.parsed_advanced_options = {}
            for key, value in self.advanced_options:gmatch('"(.-)"%s*=>%s*"(.-)"') do
              self.parsed_advanced_options[key] = value
            end
        end
    end
    return self.parsed_advanced_options
end

--[[
--
-- Returns true or false depending on whether the node
-- should play the confirmation dialog on a voice recording
-- ("if you are satisfied, press one..." or not (just accept the recording)
]] --
function FlowNode:is_confirm_recording()
    -- Currently just read a default value.
    -- TODO: this should read from an advanced option
    return RECORD_DEFAULT_CONFIRM_RECORDING_REQUIRED
end

--[[
-- FlowNodeOption class
--
-- An option directing a node to other nodes based on user interaction

]] --
local FlowNodeOption = BaseModel:new
    {
        owner_node_id = nil,
        option = nil,
        go_to_node_id = nil,
    }


--[[
-- Returns the owner node id
-- in case the data was stored directly from a database
-- row that did a join with flow table, try to find the
-- id at named table option
]] --
function FlowNodeOption:get_owner_node_id()
    return self.owner_node_id
end

--[[
--
-- Returns the go to node id
]] --
function FlowNodeOption:get_go_to_node_id()
    return self.go_to_node_id
end

--[[
--
-- Returns the option value
]] --
function FlowNodeOption:get_option()
    return self.option
end

--[[
-- Is the given (touchtone, voice response, etc) value no input or empty
-- for the purposes of comparing flow node options and flow node results?
--]]
function FlowNodeOption:is_empty_value(val)
    return val == nil or val == false or val == ''
end

--[[
--
-- Does the given result match this option as an empty result?
]] --
function FlowNodeOption:is_empty_match(result)
    return self:is_empty_value(result) and self:is_empty_value(self:get_option())
end

--[[
--
-- Does the given result match this option exactly?
]] --
function FlowNodeOption:is_exact_match(result)
    return tostring(result) == tostring(self:get_option())
end

--[[
-- Matches given result with option field value of flow node option. Option field value is storing
-- DIGIT_RANGE_DELIMITER (|) separated valid digits. E.g. 1-3|5|''.
-- This function would try to match the given result with the option field value and return true or false based on it.
]] --
function FlowNodeOption:is_match(result)
    local valid_digits = tostring(self:get_option())
    self.logger:msg(LEVEL_DEBUG, "FlowNodeOption:is_match\valid_digits : " .. valid_digits .. ", input : " .. tostring(result))
    -- validate the given result with valid_digits
    return Utility:validate_digits(valid_digits, result)
end

--[[
--
-- Does the given result match as a wildcard? This option has
-- to be a wildcard and the given result has to be non-empty
]] --
function FlowNodeOption:is_wildcard_match(result)
    return self:get_option() == ADV_OPT_PROMPT_WILDCARD_VALUE and not self:is_empty_value(result)
end


--[[
-- FSM class
--
-- Executes a flow, tracking interactions and saving them at end of call

]] --
-- Even though this isn't a DB model, inherit the BaseModel for its DB and logging support
local FlowFSM = BaseModel:new
    {
        attempt_id = nil,
        root_flow_node_id = nil,
        attempt = nil,
        root_flow_node = nil,
        current_flow_node = nil,
        target_content_type_id = nil,
        target_object_id = nil,
        all_nodes = {},
        all_options = {},
        ended = false,
        interactions = {}
    }


--[[
-- Init the FlowFSM
-- Run this before the call starts. Pre-load the Flow data
-- It does the various validation including db connection, target content type and object, root flow node, attempt, etc
-- Order of checks is important:
-- 1. Check for db connection and attempt id. This is the minimum required to load an attempt. We need
--      this so that based on rest of checks we can mark the attempt as successful or failed
-- 2. Once attempt is loaded successfully, proceed with rest of init
]] --
function FlowFSM:init()
    local init_error = false
    self.interactions = {}

    self.logger:msg(LEVEL_DEBUG, "FlowFSM:init")

    if not session:ready() then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\tSession not ready")
        init_error = true
    end

    if not self:db_connect() then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\tCould not connect to database")
        init_error = true
    end

    -- check for the attempt
    if self.attempt_id == nil then
        -- error
        self.logger.msg(LEVEL_ERROR, "FlowFSM:init\tNo attempt id specified")
        init_error = true
    end

    -- loading the attempt first so that we have something to mark
    -- failure if something subsequent in init fails
    self:load_attempt()
    if not self.attempt then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\tUnable to find attempt by given attempt id")
        init_error = true
    end

    -- check for target_content_type_id and target_object_id
    if self.target_content_type_id == nil then
        -- error
        self.logger.msg(LEVEL_ERROR, "FlowFSM:init\tNo target content_type id specified")
        init_error = true
    end

    if self.target_object_id == nil then
        -- error
        self.logger.msg(LEVEL_ERROR, "FlowFSM:init\tNo target object id specified")
        init_error = true
    end

    -- check for root flow node
    if self.root_flow_node_id == nil then
        -- error
        self.logger.msg(LEVEL_ERROR, "FlowFSM:init\tNo root flow node specified")
        init_error = true
    end

    -- loading all the flow nodes
    self:load_flow_nodes()

    if not self.root_flow_node then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\tUnable to find root flow node")
        init_error = true
    end

    -- loading all the options
    self:load_flow_node_options()
    -- checking for empty table (with non-numeric keys) is not so straightforward!
    -- https://stackoverflow.com/a/1252776/199754
    if next(self.all_options) == nil then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\tUnable to load any node options. There should be at least one")
        init_error = true
    end

    if init_error then
        -- if we found in initializtion error mark the attempt as failed
        -- and end the call
        -- NOTE that if the attempt_id itself is not valid or missing or no DB connection
        -- can be made, this function will itself fail
        self:mark_attempt_failed()
        return false
    end
    -- Why are we not marking attempt as success here?
    -- In the initial days of AD the pusher (FS update_attempts_local) was not reliably updating all attempts and hence
    -- attempt statuses were not updated on time or at all and thus scheduler couldn't send backup calls and reporting
    -- was less accurate. So we used to mark success here in the Lua app. However now we have a situation where pusher
    -- is reliable, and running frequently, so reporting and scheduling subcomponents can rely on it as the sole place
    -- to update attempt statuses.
    -- So to avoid any race condition mentioned here :
    -- https://chat.awaaz.de/awaazde/pl/jpf5tituqtbttfrq3yh4cg49ph
    -- http://bugs.awaaz.de/show_bug.cgi?id=1287
    -- it is better to mark competed true from update attempt based on CDR data.
    return true
end


--[[
-- Load the attempt object and update its state and completed flag
-- sets self.attempt: Attempt
-- Returns true
]] --
function FlowFSM:load_attempt()
    -- load the attempt into a table for given attempt id
    self.attempt = Attempt:new(self.dbh:get_table_one_row("scheduling_attempt attempt", "attempt.id = " .. self.attempt_id))
    return true
end

--[[
-- Mark the loaded attempt to failure and not complete since
-- the call failed to initialize due to an internal error
-- Returns true
]] --
function FlowFSM:mark_attempt_failed()
    local updated_attempt = {}
    updated_attempt['state'] = STATE_ATTEMPT_FAILURE
    updated_attempt['completed'] = false
    -- Bug 1183: in case there is no CDR generated for this call (for e.g. CDR database locked error),
    -- need to unmark updatable explicitly to keep
    -- data consistent (attempt pusher would normally do this,
    -- but only if there is a CDR associated)
    -- If CDR is actually generated, updatable would be marked False by attempt pusher, but since anyway
    -- there is nothing further to process for this attempt, regardless of whether there is a CDR,
    -- it's OK to marke it as updatable=False here
    -- NOTE we will need to do this as long as we are prematurely
    -- setting updatable=True in the first place (Bug 1198)
    -- UPDATE on Bug 1198: We could not find a reliable way to set updatable after CDR generation
    -- confirmed (we removed event listener entirely as we found it is not meant for CDR event handling),
    -- so updatable can only be set on EAL task. So line below is required and will remain
    updated_attempt['updatable'] = false
    updated_attempt['modified'] = 'now()'
    updated_attempt['success_index'] = nil
    self.dbh:update_table("scheduling_attempt", updated_attempt, 'id = ' .. tostring(self.attempt_id))

    return true
end

--[[
-- Load the root flow node
-- Returns self.root_node: FlowNode
]] --
function FlowFSM:load_root_flow()
    -- load the Flow Node into a table for given flow node id
    local root_node = FlowNode:new(self.dbh:get_table_one_row("scheduling_flownode flow", "flow.id = " .. self.root_flow_node_id))
    root_node.logger = self.logger
    self.root_flow_node = root_node

    -- initialize current node to the root
    if self.current_node == nil then
        self.current_node = self.root_flow_node
    end
    return true
end

--[[
-- Query data source and load flow nodes.
-- Returns self.all_nodes table: {flow_node_id : FlowNode, flow_node_id: FlowNode, ...}
-- Is also responsible for setting self.current_node
-- to the first node in the flow

]] --
function FlowFSM:load_flow_nodes()
    -- load all Flow Nodes into a table indexed by node id
    local nodes = self.dbh:get_table_rows("scheduling_flownode flow", "flow.target_content_type_id = " .. self.target_content_type_id .. " AND flow.target_object_id = " .. self.target_object_id)
    self.all_nodes = {}
    for node_id, node in pairs(nodes) do
        node.logger = self.logger
        local flow_node = FlowNode:new(node)
        if flow_node:is_root_flow_node() then
            self.root_flow_node = flow_node
        end
        self.all_nodes[flow_node:get_id()] = flow_node
    end

    -- initialize current node to the root
    if self.current_node == nil then
        self.current_node = self.root_flow_node
    end

    return true
end

--[[
-- Query data source and load flow node options
-- Returns self.all_options table returning list of options indexed by the
-- node that these options belong to:
-- {owner_flow_node_id : {option1, option2, ...}, owner_flow_node_id: {option1, option2, ...}, ...}

]] --
function FlowFSM:load_flow_node_options()
    -- load all Flow Node Options into a table indexed by node id
    local options = self.dbh:get_table_rows_with_join("scheduling_flownode flow", "scheduling_flownodeoption option", "flow.id = option.owner_node_id AND flow.state = 1 AND option.state = 1 AND flow.target_content_type_id = " .. self.target_content_type_id .. " AND flow.target_object_id = " .. self.target_object_id, "option.*")
    self.all_options = {}
    for option_id, option in pairs(options) do
        local owner_node_id = option["owner_node_id"]
        local flow_options = self.all_options[owner_node_id]
        option.logger = self.logger
        local flow_option = FlowNodeOption:new(option)
        self.logger:msg(LEVEL_DEBUG, "Options" .. owner_node_id)
        self.logger:msg(LEVEL_DEBUG, option)
        if flow_options then
            -- append to table
            table.insert(flow_options, flow_option)
        else
            -- create table
            self.all_options[owner_node_id] = { flow_option }
        end
    end

    return true
end

function FlowFSM:count_interactions_by_node_id(current_node_id, prev_node_id)
    -- This function returns the count of interaction objects
    -- based on the current flownode id and the previous flownode id.
    local count = 0
    for key, interaction in pairs(self.interactions) do
        if interaction.node_id == current_node_id and interaction.prev_node_id == prev_node_id then
            count = count + 1 -- Increment the count if current_node_id and prev_node_id matches
        end
    end
    return count
end

--[[
-----------------------------------------------------------------------------------------------------------------
------- execute_current_node ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
    perform the current node by doing the following:
    1. Check if the current node is being initilized properly
    2. Check for type of node in case of type FLOW_NODE_TYPE_END, ends the call and return
    3. Based on the node type, take specific action (including play, record, multi digit, play and multi digit,
       play & record, etc. Keep track of duration for each interaction
    4. After taking action, saves the interaction in memory and try to find the next node - based on the response
    5. If it's able to find next node, return to the start call, if no next node flow, ends the call and return
------------------------------------------------------------------------------------------------------------------
--]]
function FlowFSM:execute_current_node()
    local result = nil
    local interaction_type = nil
    local user_params = nil
    local unique_key = nil
    if not self.current_node then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:init\t there is no current node initilized yet")
        return false
    end

    self.logger:msg(LEVEL_DEBUG, "FlowFSM:execute_current_node\t current node id : " .. self.current_node:get_id())
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:execute_current_node\t current node type is : " .. self.current_node:get_type())

    -- socket.gettime() return time in below format
    -- 1510204568.5111 So we will multiply it with 1000 to get milliseconds
    -- This will be used to create the unique_key for storing interactions for the custom LM
    self.current_node.start_time = math.ceil(socket.gettime() * 1000)

    self.logger:msg(LEVEL_DEBUG, "Current node ID: ")
    self.logger:msg(LEVEL_DEBUG, self.current_node.root_node)
    current_node_type = self.current_node:get_type()
    if self.current_node.root_node == "t" and (current_node_type == FLOW_NODE_TYPE_PLAY_TTS or current_node_type == FLOW_NODE_TYPE_DETECT_SPEECH_STT or current_node_type == FLOW_NODE_TYPE_NLU) then
        --Here we set the session_params from root_node of custom LM flow globally--
        -- Creating call specific variables
        -- Used to store the session_params
        self.all_user_params = {}
        -- Used to store node specific params (input, output, latency etc. for stt, tts and nlu nodes for that particular user turn)
        self.node_params = {}
        self.user_turn = 0

        -- We use this to store the previous node into interaction for calculating max_retry
        self.prev_node = nil
        self.logger:msg(LEVEL_DEBUG, "Found root node.." .. self.current_node.root_node)
        session_params = self.current_node:get_advanced_options()[ADV_OPT_SESSION_PARAMS]
        session_params = session_params:gsub("'", '"')
        session_params = Utility:get_table_from_json(session_params)
         -- Append the current user_params to the global all_user_params if it exists
        self.logger:msg(LEVEL_DEBUG, "Fetching welcome node specific user params..")
        if session_params and type(session_params) == "table" then
        -- Update all_user_params with session_params
            for key, value in pairs(session_params) do
                self.all_user_params[key] = value  -- This will update or add keys from session_params to all_user_params
            end
        end
        -- Initialize the freeswitch api
        api = freeswitch.API()
    end
    -- check the node's type one by one and execute action accordingly
    if current_node_type == FLOW_NODE_TYPE_END then
        self:end_call()
        return true
    elseif current_node_type == FLOW_NODE_TYPE_PLAY then
        -- perform action - play
        self:play_file(self:get_audio_file_path(self.current_node:get_content()))
        self.current_node.result = ""

    elseif current_node_type == FLOW_NODE_TYPE_RECORD then
        -- perform action - record
        self.current_node.result = self:capture_record()

    elseif current_node_type == FLOW_NODE_TYPE_PLAY_RECORD then
        -- perform action - play and record response
        self.current_node.result = self:play_and_capture_record()

    elseif current_node_type == FLOW_NODE_TYPE_MULTI_DIGIT then
        -- perform action - get multiple digit input
        self.current_node.result = self:capture_digits()

    elseif current_node_type == FLOW_NODE_TYPE_PLAY_MULTI_DIGIT then
        -- perform action - play and ger multi digit input
        self.current_node.result = self:play_and_capture_digits()
    elseif current_node_type == FLOW_NODE_TYPE_CAI then
        -- Run CAI loop
        self:run_cai()
        self:end_call()
        return true

    elseif current_node_type == FLOW_NODE_TYPE_PLAY_TTS then
        self.logger:msg(LEVEL_DEBUG, "Executing tts_node..")
        self.current_node.result, params= self:execute_tts_node()
        self.logger:msg(LEVEL_DEBUG, "TTS Node execution completed.." .. tostring(params))
        interaction_type = INTERACTION_TYPE_LISTEN
        if session_params and type(params) == "table" then
            self:add_or_update_dictionary(params, self.node_params)
        end

    elseif current_node_type == FLOW_NODE_TYPE_NLU then
        self.logger:msg(LEVEL_DEBUG, "Executing nlu_node..")
        self.current_node.result, params = self:execute_nlu_node()
        self.logger:msg(LEVEL_DEBUG, "NLU Node execution completed.. ")
        self.logger:msg(LEVEL_DEBUG, "NLU option: " .. self.current_node.result)
        self.logger:msg(LEVEL_DEBUG, "NLU params: " .. tostring(params))
        interaction_type = INTERACTION_TYPE_LISTEN
        if session_params and type(params) == "table" then
            self:add_or_update_dictionary(params, self.node_params)
        end

    elseif current_node_type == FLOW_NODE_TYPE_DETECT_SPEECH_STT then
        self.unique_key = self.current_node.start_time + os.time()
        self.logger:msg(LEVEL_DEBUG, "Executing STT NODE..")
        self.current_node.result, self.current_node.user_input, params = self:execute_stt_node()
        self.logger:msg(LEVEL_DEBUG, "STT Node execution completed.." .. self.current_node.user_input)
        self.logger:msg(LEVEL_DEBUG, "STT Node params.." .. tostring(params))
        interaction_type = INTERACTION_TYPE_VOICE
        -- Assuming that every new interaction object we create, starts with the STT node, reset all the node_prams,
        -- except the STT specific ones.
        self.node_params = {}
        self.user_turn = self.user_turn + 1
        self.node_params["user_turn"] = self.user_turn
        if session_params and type(params) == "table" then
            self:add_or_update_dictionary(params, self.node_params)
        end

    end
    -- Saves individual nodes
    self:save_interaction_in_memory(self.current_node, interaction_type, nil, nil, self.prev_node)


    -- Bug 1595: If the node is of the type play_tts, nlu, or detect_speech_stt (Intent Classifier nodes),
    -- we want to store all the user_params and node specific params in the interaction objects.
    -- We are assuming that the conversation will start from STT node. So, the unique key for is created inside STT node
    -- and all the other nodes (NLU, TTS) for that user turn will have the same unique_key.
    -- This way only one interaction object is created for (STT, NLU, TTS) nodes, depicting a single user turn.
    if current_node_type == FLOW_NODE_TYPE_PLAY_TTS or current_node_type == FLOW_NODE_TYPE_DETECT_SPEECH_STT or current_node_type == FLOW_NODE_TYPE_NLU then
        -- Params to store in the interaction. We combine the all_user_params with node_params
        local combined_params = {}
        -- Add all_user_params to the new table
        if self.all_user_params then
            for key, value in pairs(self.all_user_params) do
                combined_params[key] = value
            end
        end

        -- Add user_params to the new table
        if self.node_params then
            for key, value in pairs(self.node_params) do
                combined_params[key] = value
            end
        end
        Utility:print_table(combined_params, self.logger)
        -- Save interaction in memory for all nodes, using the determined parameters

        -- Setting the unique key like this to separate the Custom LM calls from the other calls
        if self.unique_key then
            unique_key = self.unique_key
        end
        self.logger:msg(LEVEL_DEBUG, "Saving Interaction..")
        self.current_node.start_time = nil
        -- Saves the data of each turn
        self:save_interaction_in_memory(self.current_node, interaction_type, combined_params, unique_key)
    end

    -- For Intent Classifier models, we need to keep track of the previous node, to calculate NLU_MAX_RETRY
    -- so that we can disconnect the call if the user gets stuck in a loop.
    self.prev_node = self.current_node
    -- find and set next node
    self.current_node = self:get_next_node()
    if self.current_node == nil then
        self:end_call()
    end
end


--[[
-------------------------------------------------------------------------
------- play the given audio file ----------------------------------------------
-------------------------------------------------------------------------
    play given message/prompt file
    @param: filetoplay - file with full path - which needs to be play
    return true if file is successfully played else false
----------------------------------------------------------------------------------------------
--]]
function FlowFSM:play_file(filetoplay)
    -- play the audiofile
    if filetoplay and string.len(filetoplay) > 1 then
        self.logger:msg(LEVEL_INFO, "FlowFSM:play_file\tStarted streaming file : " .. filetoplay)
        self.session:streamFile(filetoplay)
        -- It's important we flush away (ignore) any digits that were pressed during playback
        -- to not affect the next interaction
        self.session:flushDigits()
        return true
    else
        self.logger:msg(LEVEL_ERROR, "FlowFSM:play_file\tThe given file is not valid")
        return false
    end
end


--[[
----------------------------------------------------------------------------------------------
------- validate multi digit response --------------------------------------------------------
----------------------------------------------------------------------------------------------
    Validate the captured digits again the current node's advanced options or default
    @param: digits - captured digits
    return true if it's valid else false
----------------------------------------------------------------------------------------------
--]]

function FlowFSM:validate_captured_digits(digits)
    -- valid_digits
    local valid_digits = self.current_node:get_advanced_options()[ADV_OPT_VALID_DIGITS] or MULTI_DIGIT_DEFAULT_VALID_DIGITS
    self.logger:msg(LEVEL_INFO, "FlowFSM:validate_captured_digits\tValidating the input : '" .. tostring(digits) .. "'")
    return Utility:validate_digits(valid_digits, digits)
end


--[[
-----------------------------------------------
------- capture digit response ----------------
-----------------------------------------------
    return response (digit) if any else false
-----------------------------------------------
--]]
function FlowFSM:capture_digits()
    -- max number of digits allowed as a response
    local max_digits = tonumber(self.current_node:get_advanced_options()[ADV_OPT_MAX_DIGIT]) or MULTI_DIGIT_DEFAULT_MAX_DIGITS

    -- in case of invalid response, this prompt would be played by fs
    local invalid_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_INVALID_INP]) or ""

    -- in case of no response, this prompt would be played by fs
    local no_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_NO_INPUT]) or ""

    -- timeout - fs will wait this this number of seconds
    local timeout = self.current_node:get_timeout()

    -- number of retries - system will retry for this number of times in case of no response or invalid response
    local retries = self.current_node:get_retries()

    -- storing the collected digit response
    local digits = ""

    -- for allowing to take one more digit as valid input from freeswitch in only case when the max digits needed to take more than 1
    if not max_digits == 1 then
        max_digits = max_digits + 1
    end

    self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_digits\tMax_digits : " .. max_digits)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_digits\tTimeout : " .. timeout)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_digits\tRetries : " .. retries)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_digits\tInvalid input file : " .. invalid_response_file)

    local i = 0
    --[[
        -- It's working as explained below:
        -- 1. Try to get the response from user till the attemt exceeds the number of retries
        -- 2. Validate the response based on min_num, max_num etc
        -- 3. If valid response if provided by user, exit the loop and return it
        -- 4. If no valid response is provided, return false
    --]]
    local attempts = 1 + retries
    while i < attempts and not self.ended do
        digits = ""
        i = i + 1
        self.logger:msg(LEVEL_INFO, "FlowFSM:capture_digits\tAttempt Counter : " .. i .. ", Max Attempts = " .. attempts)

        self.logger:msg(LEVEL_INFO, "FlowFSM:capture_digits\tCapturing digits")
        digits = self.session:getDigits(max_digits, MULTI_DIGIT_TERMINATOR, timeout * 1000)
        -- flushing the session to get fresh input
        self.session:flushDigits()

        -- if no error then only go for validation, or just exit from the loop
        local is_valid_response = self:validate_captured_digits(digits)
        if is_valid_response then
            -- break the loop and return the digits
            self.logger:msg(LEVEL_INFO, "FlowFSM:capture_digits\tValid inputs provided")
            break
        else
            self.logger:msg(LEVEL_INFO, "FlowFSM:capture_digits\tThe digits captured are out of valid_digits or not valid")
            -- playing the invalid input prompt
            -- only play if there was actual input. On no input, play file saying no response was captured
            if digits ~= "" then
                self:play_file(invalid_response_file)
            else
                self:play_file(no_response_file)
            end

            if i >= attempts then
                -- In the case when user has given invalid input in the last retry, we want to make sure that this
                -- invalid input is not stored to the Interaction object. Hence, making digits variable empty
                digits = ""
            end
        end
    end

    return digits
end


--[[
-----------------------------------------------
------- play and capture digit response ----------------
-----------------------------------------------
    return response (digit) if any else false
-----------------------------------------------
--]]
function FlowFSM:play_and_capture_digits()
    -- min number of digits allowed as a response
    local min_digits = MULTI_DIGIT_DEFAULT_MIN_DIGITS

    -- max number of digits allowed as a response
    local max_digits = tonumber(self.current_node:get_advanced_options()[ADV_OPT_MAX_DIGIT]) or MULTI_DIGIT_DEFAULT_MAX_DIGITS

    -- The number of times this function waits for digits and replays the prompt_audio_file when digits do not arrive
    local max_attempts = MULTI_DIGIT_DEFAULT_NUM_ATTEMPTS

    -- validating that the response is only containing numbers
    local digit_regex = MULTI_DIGIT_FS_VALIDATION_PATTERN

    -- in case of invalid response, this prompt would be played by fs
    local invalid_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_INVALID_INP]) or ""

    -- in case of no response, this prompt would be played by fs
    local no_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_NO_INPUT]) or ""

    -- timeout - fs will wait this this number of seconds
    local timeout = self.current_node:get_timeout()

    -- number of retries - system will retry for this number of times in case of no response or invalid response
    local retries = self.current_node:get_retries()

    -- storing the collected digit response
    local digits = ""

    -- for allowing to take one more digit as valid input from freeswitch in only case when the max digits needed to take more than 1
    if max_digits > 1 then
        max_digits = max_digits + 1
    end

    self.logger:msg(LEVEL_DEBUG, "FlowFSM:play_and_capture_digits\tMax_digits : " .. max_digits)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:play_and_capture_digits\tTimeout : " .. timeout)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:play_and_capture_digits\tRetries : " .. retries)
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:play_and_capture_digits\tInvalid input file : " .. invalid_response_file)

    local i = 0
    --[[
        -- It's working as explained below:
        -- 1. Try to get the response from user till the attemt exceeds the number of retries
        -- 2. Validate the response based on min_num, max_num etc
        -- 3. If valid response if provided by user, exit the loop and return it
        -- 4. If no valid response is provided, return false
    --]]
    local attempts = 1 + retries
    while i < attempts and not self.ended do

        digits = ""
        i = i + 1
        self.logger:msg(LEVEL_INFO, "FlowFSM:play_and_capture_digits\tAttempt Counter : " .. i .. ", Max Attempts = " .. attempts)

        local filetoplay = self:get_audio_file_path(self.current_node:get_content())
        if filetoplay and string.len(filetoplay) > 1 then
            self.logger:msg(LEVEL_INFO, "FlowFSM:play_and_capture_digits\tStarted streaming file : " .. filetoplay)
            -- we DO NOT play invalid_response_file from within here because we only want to play it on *certain* invalid inputs (see comments below)
            digits = self.session:playAndGetDigits(min_digits, max_digits, max_attempts, timeout * 1000, MULTI_DIGIT_TERMINATOR, filetoplay, "", digit_regex, "digits_received", MULTI_DIGIT_INPUT_THRESH)
            -- flushing the session to get fresh input
            self.session:flushDigits()
        else
            self.logger:msg(LEVEL_ERROR, "FlowFSM:play_and_capture_digits\tThere is no audio file present in node. Please check your flow node")
            return false
        end

        -- if no error then only go for validation, or just exit from the loop
        local is_valid_response = self:validate_captured_digits(digits)

        if is_valid_response then
            -- break the loop and return the digits
            self.logger:msg(LEVEL_INFO, "FlowFSM:play_and_capture_digits\tValid inputs provided")
            break
        else
            self.logger:msg(LEVEL_INFO, "FlowFSM:play_and_capture_digits\tThe digits captured are out of valid_digits or not valid")
            -- playing the invalid input prompt
            -- only play if there was actual input. On no input, play file saying no response was captured
            if digits ~= "" then
                self:play_file(invalid_response_file)
            else
                self:play_file(no_response_file)
            end
            -- default delay before playing message again
            Utility:sleep(DEFAULT_DELAY_SECS)
            if i >= attempts then
                -- In the case when user has given invalid input in the last retry, we want to make sure that this
                -- invalid input is not stored to the Interaction object. Hence, making digits variable empty
                digits = ""
            end
        end
    end

    return digits
end



--[[
-------------------------------------------------------------------------------------
------- confirm captured voice response  --------------------------------------------
-------------------------------------------------------------------------------------
    Validate the captured digits again the current node's advanced options or default
    @param: record_filepath - path to recorded file
    return 1 if user confirms else false
-------------------------------------------------------------------------------------
--]]
function FlowFSM:confirm_captured_record(record_filepath)
    -- getting advanced options
    local confirmrecording = self.current_node:is_confirm_recording()
    local here_recorded_prompt_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_HERE_RECORDED]) or ""
    local not_satisfied_prompt_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_NOT_SATISFIED]) or ""
    local invalid_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_INVALID_INP]) or ""
    local no_response_file = self:get_audio_file_path(self.current_node:get_advanced_options()[ADV_OPT_PROMPT_NO_INPUT]) or ""

    if confirmrecording == true then
        local d = ""

        -- for validation
        local digit_regex = MULTI_DIGIT_FS_VALIDATION_PATTERN

        local review_cnt = 0

        --[[
            -- It's working as explained below:
            -- 1. Prompt user to either confirm that the recording is ok, if ok, press 1 (RECORD_DEFAULT_CONFIRM_OPTION),
            --    prompt user to re-record it by pressing 2 (RECORD_DEFAULT_RERECORD_RECORDING_PROMPT),
            --    prompt user to cancel the recording and move ahead by pressing 3 (RECORD_DEFAULT_CANCEL_OPTION)
            -- 2. If user decides to confirm it or cancel it, exit from loop and return
            -- 3. If user pressed 3, it cancels recording, delete the file and return
            -- 4. If user pressed no digit, play no_response_file and retry for RECORD_DEFAULT_NUM_REPEATS to get the user's choice
            -- 5. If user pressed invalid digit (i.e. input except 1,2,3), play invalid_response_file and retry for RECORD_DEFAULT_NUM_REPEATS to get the user's choice
        --]]
        while not self.ended do
            -- playing the here recorded prompt
            self:play_file(here_recorded_prompt_file)
            Utility:sleep(DEFAULT_DELAY_SECS)

            -- playing actual recorded message
            self:play_file(record_filepath)
            Utility:sleep(DEFAULT_DELAY_SECS)

            -- taking input from caller
            -- Note that we arent giving invalid prompt in this method as we want to handle different scenarios for
            -- -- invalid input i.e. invalid input and no input. Hence we handle it ourselves.
            self.session:flushDigits()
            d = self.session:playAndGetDigits(1, 1, 1, DEFAULT_TIMEOUT_SECS * 1000, DEFAULT_TERMINATOR, not_satisfied_prompt_file, "", digit_regex, "digits_received", MULTI_DIGIT_INPUT_THRESH)

            -- Increment the count of retries
            review_cnt = review_cnt + 1
            if (d == RECORD_DEFAULT_CONFIRM_OPTION or d == RECORD_DEFAULT_RERECORD_OPTION or d == RECORD_DEFAULT_CANCEL_OPTION) then
                self.logger:msg(LEVEL_INFO, "FlowFSM:confirm_captured_record\tThe digits captured are valid")
                break
            else
                -- On no input, play file saying no response was captured
                if d ~= "" then
                    -- playing the invalid input prompt for invalid response.
                    self.logger:msg(LEVEL_INFO, "FlowFSM:confirm_captured_record\tThe digits captured are out of valid_digits or not valid")
                    self:play_file(invalid_response_file)
                else
                    self.logger:msg(LEVEL_INFO, "FlowFSM:confirm_captured_record\tNo digits captured.")
                    self:play_file(no_response_file)
                end

                -- Exit in case the retries count exceed the RECORD_DEFAULT_NUM_REPEATS. We dont want to play invalid_prompt or no_repsponse prompt if max retries is reached
                if (review_cnt >= RECORD_DEFAULT_NUM_REPEATS) then
                    self.logger:msg(LEVEL_INFO, "FlowFSM:confirm_captured_record\tRecording attempts exceed threshold, exiting now...")
                    return false
                end
            end

        end

        if (d ~= RECORD_DEFAULT_CONFIRM_OPTION and d ~= RECORD_DEFAULT_RERECORD_OPTION) then
            -- caller decided to either not confirming the recording or cancel and so deleting record file
            os.remove(record_filepath)
            return false
        end
        return d
    else
        return RECORD_DEFAULT_CONFIRM_OPTION
    end
end

--[[
-----------------------------------------------
------- recording_termination  ---------------------------
-----------------------------------------------
-- Call back function to take dtmf on record.
-- Terminate the recording on the terminators
-- Otherwise keep recording on any other input
-----------------------------------------------
--]]
function recording_termination(s, type, obj, arg)
    if (type == "dtmf") then
        freeswitch.consoleLog("info", "[CB] recording_termination\tdtmf digit: " .. obj['digit'] .. ", duration: " .. obj['duration'] .. "\n")
        local digit = obj['digit']
        if RECORD_DEFAULT_TERMINATORS:match(digit) then
            return 0
        end
    end
end

--[[
-----------------------------------------------------------
------- record_file  ---------------------------
-----------------------------------------------------------
    Perform the actual recording of a file
-----------------------------------------------------------
--]]
function FlowFSM:record_file(record_filepath, max_len_secs, silence_threshold, silence_secs)
    -- temporarily activate input callback
    self.session:setInputCallback("recording_termination", "")

    -- do the recording
    local record_secs = self.session:recordFile(record_filepath, max_len_secs, silence_threshold, silence_secs)

    -- set the callback
    self.session:unsetInputCallback()

    return record_secs
end

function FlowFSM:get_gdf_media_path(session_id, filename)
    local d = os.date('*t');
    local year = d.year;
    local month = d.month;
    local day = d.day;

    if month < 10 then
        month = '0' .. month;
    end

    if day < 10 then
        day = '0' .. day;
    end

    -- <schema_name>/Freeswitch/
    local rootdir = self.dbh:get_active_schema() .. FS_RECORDING_MEDIA_DIR
--     local rootdir = 'ad_abcde' .. FS_RECORDING_MEDIA_DIR

    -- 2017/02/12/
    local subdir = year .. '/' .. month .. '/' .. day .. '/' .. session_id .. '/';

    -- create the folder path if it doesn't already exist
    if io.open(MEDIA_DIR .. rootdir .. subdir, "rb") == nil then
        os.execute("mkdir -p " .. MEDIA_DIR .. rootdir .. subdir);
        -- chmod from the rootdir on down
        os.execute("chmod -R 775 " .. MEDIA_DIR .. rootdir .. subdir);
    end

    outputFile = rootdir .. subdir .. filename .. RECORD_DEFAULT_RECORD_SOUND_EXT
    return outputFile
end

function FlowFSM:update_permissions(session_id)
    local d = os.date('*t');
    local year = d.year;
    local month = d.month;
    local day = d.day;

    if month < 10 then
        month = '0' .. month;
    end

    if day < 10 then
        day = '0' .. day;
    end

    local rootdir = self.dbh:get_active_schema() .. FS_RECORDING_MEDIA_DIR

    local subdir = year .. '/' .. month .. '/' .. day .. '/' .. session_id .. '/';
    os.execute("chmod -R 775 " .. MEDIA_DIR .. rootdir .. subdir);
end

function FlowFSM:execute_stt_node()
    -- This function calls the STT engine and returns user_input
    params = {}
    local stt_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_STT_ENGINE]

    max_slient_seconds = tonumber(self.current_node:get_advanced_options()[ADV_OPT_SLT_SECS])
    self.logger:msg(LEVEL_DEBUG, "STT PATH: " .. stt_path)

    stt_params = self.current_node:get_advanced_options()[ADV_OPT_STT_PARAMS]
    stt_params = stt_params:gsub("'", '"')
    stt_params = Utility:get_table_from_json(stt_params)
    STT = dofile(stt_path)
    stt = STT:new()
    uuid = session:getVariable("uuid")
    filename = 'user_response_' .. tostring(self.attempt:get_id()) .. '_' .. os.time()
    record_filepath = self:get_gdf_media_path(uuid , filename)
    language = self.current_node:get_advanced_options()[ADV_OPT_NLU_LN]

    language = 'hi'
    self.logger:msg(LEVEL_DEBUG, "STT Started: " .. uuid)
    self.logger:msg(LEVEL_DEBUG, "Language: " .. language)
    self.logger:msg(LEVEL_DEBUG, "File: " ..  MEDIA_DIR .. record_filepath)

    start_time = socket.gettime()
    local input_text,stt_intermediate_text = stt:transcribe(uuid,language,self.session,stt_params, record_filepath)
    end_time = socket.gettime()
    stt_latency = (end_time - start_time)*1000
    self.logger:msg(LEVEL_DEBUG, "STT Ended: " .. input_text)

    params['stt_file'] = record_filepath
    params['stt_latency'] = stt_latency
    params['stt_output']= input_text:gsub("\n", "")
    params['stt_intermediate_text']= stt_intermediate_text:gsub("\n", "")
    return "", input_text, params
end

function FlowFSM:add_or_update_dictionary(from_dict, to_dict)
    for key, value in pairs(from_dict) do
        to_dict[key] = value  -- This will update or add keys from from_dict to to_dict
    end
end

function FlowFSM:execute_tts_node()
    params = {}
    params['tts_input'] = ""
    params['tts_latency'] = ""
    params['tts_file'] = ""
    local tts_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_TTS_ENGINE]
    self.logger:msg(LEVEL_DEBUG, "TTS Path: " .. tts_path)
    session_params = self.current_node:get_advanced_options()[ADV_OPT_SESSION_PARAMS]
    session_params = session_params:gsub("'", '"')
    session_params = Utility:get_table_from_json(session_params)
     -- Append the current user_params to the global all_user_params if it exists
    self.logger:msg(LEVEL_DEBUG, "Fetching node specific user params..")
    if session_params and type(session_params) == "table" then
        -- Update all_user_params with session_params
        self:add_or_update_dictionary(session_params, self.all_user_params)
    end
    self.logger:msg(LEVEL_DEBUG, "All params: ")
    Utility:print_table(self.all_user_params, self.logger)
    tts_params = self.current_node:get_advanced_options()[ADV_OPT_TTS_PARAMS]
    tts_params = tts_params:gsub("'", '"')
    tts_params = Utility:get_table_from_json(tts_params)
    TTS = dofile(tts_path)
    tts = TTS:new()
    content = self.current_node:get_content()
    if content then
        -- Replace the dynamic/session_params value in the content string.
        updated_content = Utility:replace_placeholders(content, self.all_user_params)
    else
        return "", params
    end
    uuid = session:getVariable("uuid")
    filename = 'ad_response_' .. tostring(self.attempt:get_id()) .. '_' .. os.time()
    audio_path = self:get_gdf_media_path(uuid , filename)
    language = self.current_node:get_advanced_options()[ADV_OPT_NLU_LN]

    self.logger:msg(LEVEL_DEBUG,'TTS STARTED')
    start_time = socket.gettime()
    local tts_output = tts:synthesize(updated_content,audio_path,language,tts_params,self.session)
    end_time = socket.gettime()
    self.logger:msg(LEVEL_DEBUG,'TTS ENDED with output..' ..  tts_output)
    tts_latency = (end_time - start_time)*1000

    if tts_output~=nil then
        params['tts_input'] = updated_content:gsub("\n", "")
        params['tts_latency'] = tts_latency
        params['tts_file'] = tts_output
    end
    return "", params
end

function FlowFSM:get_possible_intents()
    function _table_contains(table, value)
        for _, v in ipairs(table) do
            if v == value then
                return true
            end
        end
        return false
    end
    local options = self.all_options[self.current_node:get_id()]
    intents = {}
    -- Get all the possible intents in comma separated format from the node's options
    if options then
        for _, opt in ipairs(options) do
            local opt_value = opt:get_option()  -- Get the option value
            -- Check if the option value contains a "#", and extract the part before it
            local intent = opt_value:match("([^#]+)")
            -- Only insert the intent if it is not already in the intents table
            if not _table_contains(intents, intent) then
                self.logger:msg(LEVEL_DEBUG, "Inserting intent for this node: ", intent)
                table.insert(intents, intent)
            else
                self.logger:msg(LEVEL_DEBUG, "Intent already present: ", intent)
            end
        end
        -- Join the opt_value items into a comma-separated string
        intents = table.concat(intents, ",")
    end
    return intents
end

function FlowFSM:execute_nlu_node()
    params = {}
    if not self.current_node.user_input then
        self.logger:msg(LEVEL_ERROR, "No input text found.")
        return "sys.no-match-default", params
    end
    local language = self.current_node:get_advanced_options()[ADV_OPT_NLU_LN]
    local nlu_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_NLU_ENGINE]
    NLUEngine = dofile(nlu_path)
    nlu = NLUEngine:new({language=language})
    intents = self:get_possible_intents()

    self.logger:msg(LEVEL_DEBUG, "Final intents: ".. intents)
    if intents == "" then
        self.logger:msg(LEVEL_ERROR, "No possible intents found for this node.")
        return "sys.no-match-default", params
    end
    start_time = socket.gettime()
    local intent_info = nlu:process(intents, self.current_node.user_input)
    end_time = socket.gettime()
    nlu_latency = (end_time - start_time)*1000
    self.logger:msg(LEVEL_DEBUG, string.format("FlowFSM:execute_nlu_node\tReceived intent"))
    params['nlu_input'] = self.current_node.user_input:gsub("\n", "")
    params['nlu_latency'] = nlu_latency
    local matched_intent = nil
    local entity = nil
    if intent_info then
        matched_intent =  intent_info.intent
        entity = intent_info.entity
    else
        self.logger:msg(LEVEL_ERROR, "Failed to retrieve intent information.")
    end
    -- If entity is present, we need to map it to the entity_list of the node.
    self.logger:msg(LEVEL_DEBUG, string.format("Extracted Intent: %s, Entity: %s", matched_intent, entity))
    if entity and entity ~= json.null then
        self.logger:msg(LEVEL_DEBUG, "Inside entity check")
        -- Fetch the entity_list as a string
        local entity_list_str = self.current_node:get_advanced_options()[ADV_OPT_ENTITY_LIST]
        self.logger:msg(LEVEL_DEBUG, "entity_list_str: " .. entity_list_str)
        local entity_list = entity_list_str:match("%['(.-)'%]")
        -- Check if the entity_list is valid and contains elements
        if entity_list then
            self.logger:msg(LEVEL_DEBUG, "ENTITY FOUND: " .. entity_list)
            self.logger:msg(LEVEL_DEBUG, "ENTITY: " .. entity)
            -- Add the entity to all_user_params using the first entry in entity_list as the key
            self.all_user_params[entity_list] = entity  -- Use 1 for the first element
        else
            self.logger:msg(LEVEL_WARNING, "Entity list is empty or not valid.")
        end
    end

    local options = self.all_options[self.current_node:get_id()]
    local final_intent = nil

     -- Here we loop the options to check if there are intents with condition
    if matched_intent then
        for idx, opt in ipairs(options) do
            local opt_value = opt:get_option()
            -- Check if opt_value contains matched_intent
            -- The matched_intent could either be exact match or substring
            if string.find(opt_value, matched_intent) then
                -- Check if the option contains a condition (Hashtag) (Eg: call_purpose#benefits=0)

                -- If the intent matches exactly with the option, then dont check further, just return the intent.
                if opt_value == matched_intent then
                    final_intent = matched_intent
                    break
                elseif string.find(opt_value, "#") then
                    -- If the matched_intent is a substring,
                    -- Split the value using the #
                    local possible_intent, condition_key_value = opt_value:match("^(.-)#(.*)$")  -- Get the condition part

                    -- Making sure the intent in the "options" after splitting using hashtag, matches with the matched_intent
                    -- If not, we skip this option.
                    -- This is to avoid a scenario like option="customer.available#benefit=1", matched_intent="customer.avail"
                    -- Here, matched_intent would be a substring of the option but is not really the intent we want.
                    if possible_intent == matched_intent then
                        -- Split the condition_key_value (Eg: benefits=0) using " = "
                        local condition_key = condition_key_value:match("^(.*)=(.*)$")  -- Extract the condition key
                        -- Get the session condition value
                        local session_condition_value = self.all_user_params[condition_key] or ""
                        -- Update the intent

                        -- session_condition_value is nil/empty when the key in condition (Eg. benefit=1) is not present in all_user_params
                        -- So we ignore the option value and check next.
                        if session_condition_value then
                            final_intent = string.format("%s#%s=%s", matched_intent, condition_key, session_condition_value)
                            break
                        end
                    end
                end
            end
        end
    end

    -- If the final_intent is nil, it means there was no matching intent option, so we return sys.no-match-default
    if not final_intent then
        final_intent = "sys.no-match-default"
    end
    -- Return the original intent if no conditions were found
    self.logger:msg(LEVEL_DEBUG, string.format("Final Intent: %s", tostring(final_intent)))
    params['nlu_output'] = final_intent
    return final_intent, params
end

function FlowFSM:run_cai()

    local stt_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_STT_ENGINE]
    local tts_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_TTS_ENGINE]
    local nlu_path = LUA_DIR .. self.current_node:get_advanced_options()[ADV_OPT_NLU_ENGINE]
    local agent_id = self.current_node:get_advanced_options()[ADV_OPT_NLU_AGENT]
    local environment_id = self.current_node:get_advanced_options()[ADV_OPT_NLU_ENVIRONMENT_ID]
    --  If NLU is text to voice then pass text, if it's voice to voice then pass hello audio path.
    STARTUP_TEXT = 'hello'
    language = self.current_node:get_advanced_options()[ADV_OPT_NLU_LN]
    session_params = self.current_node:get_advanced_options()[ADV_OPT_SESSION_PARAMS]
    max_recording_length = tonumber(self.current_node:get_advanced_options()[ADV_OPT_MAX_REC])
    max_slient_threshold = tonumber(self.current_node:get_advanced_options()[ADV_OPT_SLT_THRE])
    -- it tolerates this much before ending call
    max_slient_seconds = tonumber(self.current_node:get_advanced_options()[ADV_OPT_SLT_SECS])
    stt_params = self.current_node:get_advanced_options()[ADV_OPT_STT_PARAMS]
    stt_params = stt_params:gsub("'", '"')
    stt_params = Utility:get_table_from_json(stt_params)

    tts_params = self.current_node:get_advanced_options()[ADV_OPT_TTS_PARAMS]
    tts_params = tts_params:gsub("'", '"')
    tts_params = Utility:get_table_from_json(tts_params)

    STT = dofile(stt_path)
    TTS = dofile(tts_path)
    NLUEngine = dofile(nlu_path)

    uuid = session:getVariable("uuid")
    input_string = session_params:gsub("'", '"')
    session_param_table = Utility:get_table_from_json(input_string)

    stt = STT:new()
    nlu = NLUEngine:new({agent_id=agent_id, session_id=uuid,environment_id=environment_id, language=language, sys_params=session_param_table})
    tts = TTS:new()


    -- Starting gdf audio directly which requires to send start_up text
    filename = 'gdf_response_' .. tostring(self.attempt:get_id()) .. '_' .. os.time()
    audio_path = self:get_gdf_media_path(uuid, filename)

    api = freeswitch.API()
    channel_state = "Ring"
    state_counter = 0
    while state_counter < 300 and channel_state ~= "'ACTIVE'" do
        state_counter = state_counter + 1
        session:execute("sleep", "100")
        channel_state = api:executeString('eval uuid:' .. uuid .. " '${Channel-Call-State}'")
    end
    if channel_state~="'ACTIVE'" then
        session:hangup()
    else
        session:execute("sleep","1000")
        user_filepath = self:get_gdf_media_path(uuid, "user_recording")
        session:execute("record_session", MEDIA_DIR .. user_filepath)
        local output_gdf = nlu:process(STARTUP_TEXT, audio_path)
        -- We use current_node.start_time + os.time() to create a unique key for storing interactions
        self:save_interaction_in_memory(self.current_node , INTERACTION_TYPE_VOICE, nil, self.current_node.start_time+os.time())
        local tts_output = tts:synthesize(output_gdf,audio_path,language,tts_params,session)

        turn_count=0
        allowed=50
        while turn_count < allowed and not nlu.end_session and not self.ended do
            filename = 'user_recorded_' .. tostring(self.attempt:get_id()) .. '_' .. os.time()
            record_filepath = self:get_gdf_media_path(uuid, filename)
            self:save_interaction_in_memory(self.current_node , INTERACTION_TYPE_VOICE, nil, self.current_node.start_time+os.time())

            nlu.user_params['stt_file'] = ''
            nlu.user_params['stt_latency'] = ''
            nlu.user_params['stt_output']= ''
            nlu.user_params['stt_intermediate_text']= ''
            nlu.user_params['nlu_input'] = ''
            nlu.user_params['nlu_latency'] = ''
            nlu.user_params['nlu_output'] = ''
            nlu.user_params['intent'] = ''
            nlu.user_params['tts_input'] = ''
            nlu.user_params['tts_latency'] = ''
            nlu.user_params['tts_file'] = ''

            key = self.current_node.start_time+os.time()+1
            self:save_interaction_in_memory(self.current_node, INTERACTION_TYPE_LISTEN, nlu.user_params, key)

            self.logger:msg(LEVEL_DEBUG, 'STT STARTED')
            start_time = socket.gettime()
            local input_gdf,stt_intermediate_text = stt:transcribe(uuid,language,session,stt_params,record_filepath)
            end_time = socket.gettime()
            self.logger:msg(LEVEL_DEBUG, 'STT ENDED ' .. input_gdf)
            stt_latency = (end_time - start_time)*1000

            -- Need to remove new line character for reporting json parsing issue
            nlu.user_params['stt_file'] = record_filepath
            nlu.user_params['stt_latency'] = stt_latency
            nlu.user_params['stt_output']= Utility:remove_unwanted_characters_from_string(input_gdf)
            nlu.user_params['stt_intermediate_text']= Utility:remove_unwanted_characters_from_string(stt_intermediate_text)

            self:save_interaction_in_memory(self.current_node, INTERACTION_TYPE_LISTEN, nlu.user_params, key)

            self.logger:msg(LEVEL_DEBUG,'GDF PROCESS STARTED')
            filename = 'gdf_response_' .. tostring(self.attempt:get_id()) .. '_' .. os.time()
            audio_path = self:get_gdf_media_path(uuid , filename)
            start_time = socket.gettime()
            local output_gdf = nlu:process(input_gdf, audio_path)
            end_time = socket.gettime()
            self.logger:msg(LEVEL_DEBUG,'GDF PROCESS ENDED ' .. output_gdf)
            nlu_latency = (end_time - start_time)*1000

            -- Need to remove new line character for reporting json parsing issue
            nlu.user_params['stt_file'] = record_filepath
            nlu.user_params['stt_latency'] = stt_latency
            nlu.user_params['stt_output']= Utility:remove_unwanted_characters_from_string(input_gdf)
            nlu.user_params['stt_intermediate_text']= Utility:remove_unwanted_characters_from_string(stt_intermediate_text)

            nlu.user_params['nlu_input'] = Utility:remove_unwanted_characters_from_string(input_gdf)
            nlu.user_params['nlu_latency'] = nlu_latency
            nlu.user_params['nlu_output'] = Utility:remove_unwanted_characters_from_string(output_gdf)

            self:save_interaction_in_memory(self.current_node, INTERACTION_TYPE_LISTEN, nlu.user_params, key)

            self.logger:msg(LEVEL_DEBUG,'TTS STARTED')
            start_time = socket.gettime()
            local tts_output = tts:synthesize(output_gdf,audio_path,language,tts_params,session)
            end_time = socket.gettime()
            self.logger:msg(LEVEL_DEBUG,'TTS ENDED')
            tts_latency = (end_time - start_time)*1000

            if tts_output~=nil then
                nlu.user_params['tts_input'] = Utility:remove_unwanted_characters_from_string(output_gdf)
                nlu.user_params['tts_latency'] = tts_latency
                nlu.user_params['tts_file'] = tts_output
            end

            self:save_interaction_in_memory(self.current_node, INTERACTION_TYPE_LISTEN, nlu.user_params, key)

            turn_count = turn_count+1
            if nlu.end_session then
                self:end_call()
                break
            end
        end
    end
    self:update_permissions(uuid)
    self:end_call()

end

--[[
-----------------------------------------------------------
------- capture voice response  ---------------------------
-----------------------------------------------------------
    return partial path of recorded file if any else false
-----------------------------------------------------------
--]]
function FlowFSM:capture_record(filetoplay)
    -- max number of secs allowed as a recording
    local max_len_secs = tonumber(self.current_node:get_advanced_options()[ADV_OPT_MAX_REC]) or RECORDING_MAX_LENGTH

    -- silence threshold
    local silence_threshold = RECORD_DEFAULT_SILENCE_THRESHOLD

    -- is the amount of silence to tolerate before ending the recording
    local silence_secs = RECORD_DEFAULT_SILENCE_SECS

    -- get path with unique name for recorded file, the path would be like e.g. tenant_schema/freeswitch/date and time-node_id.wav
    local record_filepath_partial = self:get_node_recordfile()
    local record_filepath = MEDIA_DIR .. record_filepath_partial

    local confirm_recording = self.current_node:is_confirm_recording()
    local confirm_result = nil

    repeat
        if filetoplay then
            self:play_file(filetoplay)
        end


        -- playing beep
        self.session:execute("playback", "tone_stream://%(500, 0, 620)");

        if not confirm_recording then
            -- save the recorded file as a result in case the caller
            -- hangs up after finishing recording. We should save the recording
            -- if this node doesn't ask for confirmation
            self.current_node.result = record_filepath_partial
            self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_record\tSet current_node result : " .. self.current_node.result)
        end

        local record_secs = self:record_file(record_filepath, max_len_secs, silence_threshold, silence_secs)

        confirm_result = self:confirm_captured_record(record_filepath)

        self.logger:msg(LEVEL_DEBUG, "FlowFSM:capture_record\tCaller confirm result : " .. tostring(confirm_result))

        if confirm_result == false then
            return false
        end
    until (confirm_result == RECORD_DEFAULT_CONFIRM_OPTION)

    self.logger:msg(LEVEL_INFO, "FlowFSM:capture_record\tRecorded file on path : " .. record_filepath)
    return record_filepath_partial
end


--[[
-----------------------------------------------------------------------------------
------- play prompt/message and capture voice response  ---------------------------
-----------------------------------------------------------------------------------
    Play the given message and capture the voice response
    return partial path of recorded file if any else false
-----------------------------------------------------------------------------------
--]]
function FlowFSM:play_and_capture_record()
    local filetoplay = nil
    -- getting the file from node
    local filetoplay = self:get_audio_file_path(self.current_node:get_content())
    if not (filetoplay and string.len(filetoplay) > 1) then
        self.logger:msg(LEVEL_ERROR, "FlowFSM:play_and_capture_record\tThere is no audio file present in node. Please check your node conversion")
        return false
    end
    return self:capture_record(filetoplay)
end


--[[
------------------------------------------------------------------------
------- gets the full path for given partial path  ---------------------
------------------------------------------------------------------------
    Construct the full path for given partial path
    return full path of if partial path is not empty else false
------------------------------------------------------------------------
--]]
function FlowFSM:get_audio_file_path(partial_path)
    -- building the full path for given partial path
    if partial_path then
        return MEDIA_DIR .. partial_path
    end
    return false
end


--[[
------------------------------------------------------------------------
--------------------- get_node_recordfile ------------------------------
------------------------------------------------------------------------
    Construct the filename with path relative to MEDIA_ROOT for this recorded file
    e.g. <schema_name>/Freeswitch/2017/02/12/12322232332_223.wav
------------------------------------------------------------------------
--]]
function FlowFSM:get_node_recordfile(node)
    -- building the filefor recorded file for given node
    local d = os.date('*t');
    local year = d.year;
    local month = d.month;
    local day = d.day;

    if month < 10 then
        month = '0' .. month;
    end

    if day < 10 then
        day = '0' .. day;
    end

    -- <schema_name>/Freeswitch/
    local rootdir = self.dbh:get_active_schema() .. FS_RECORDING_MEDIA_DIR
    -- 2017/02/12/
    local subdir = year .. '/' .. month .. '/' .. day .. '/';

    -- create the folder path if it doesn't already exist
    if io.open(MEDIA_DIR .. rootdir .. subdir, "rb") == nil then
        os.execute("mkdir -p " .. MEDIA_DIR .. rootdir .. subdir);
        -- chmod from the rootdir on down
        os.execute("chmod -R 775 " .. MEDIA_DIR .. rootdir .. year);
    end

    local result = rootdir .. subdir .. os.time() .. "_" .. self.attempt:get_id() .. RECORD_DEFAULT_RECORD_SOUND_EXT
    self.logger:msg(LEVEL_DEBUG, "FlowFSM:get_node_recordfile\tpath : " .. result)
    return result
end


--[[
-----------------------------------------------------------------------
------------ get_next_node  -------------------------------------------
-----------------------------------------------------------------------
-- Finds the next node for current node and return it
-- return node id if finds any else nil
------------------------------------------------------------------------
--]]
function FlowFSM:get_next_node()
    local result = self.current_node.result
    self.logger:msg(LEVEL_DEBUG, string.format("FlowFSM:get_next_node\tPassed result = %s", tostring(result)))

    local options = self.all_options[self.current_node:get_id()]

    local node_type = self.current_node:get_type()
    local next_node_id = nil

    -- Finds the next node based on following logic:
    -- 1. Try to find the node having the option value exactly matching with given result (empty or nonempty option value),
    -- if it finds it, return the go to node id
    -- 2. If not found, try to find the node based on valid digits match. if finds it, return the go to node id from this option
    -- 3. If not found, try to find the node based on wild card character, if finds it, return the go to node id from this option
    -- 4. If not found, logs the error and returns nil

    if options then
        local wildcard_option = nil
        local is_match_found = false

        for idx, opt in ipairs(options) do
            local opt_value = opt:get_option()

            -- trying to find the wild card option
            if opt_value == ADV_OPT_PROMPT_WILDCARD_VALUE then
                wildcard_option = opt
            end

            -- if any of these conditions hit, in this order, set the node
            if opt:is_empty_match(result) or opt:is_exact_match(result) or opt:is_match(result) then
                next_node_id = opt:get_go_to_node_id()
                is_match_found = true
                break
            end
        end

        -- If all options considered and no match found then try to match on wild card option.
        -- Only match wildcard against a non-empty result
        if not is_match_found and wildcard_option and wildcard_option:is_wildcard_match(result) then
            next_node_id = wildcard_option:get_go_to_node_id()
        end
    end

    self.logger:msg(LEVEL_DEBUG, string.format("FlowFSM:get_next_node\tFound next node = %s", tostring(next_node_id)))

    if next_node_id and self.all_nodes[next_node_id] then
        result = self.all_nodes[next_node_id]
        -- Store the input from STT Node to the NLU node
        if result:get_type() == FLOW_NODE_TYPE_NLU then
            -- Here we get the count of interactions where user has gone from the current node to the next NLU node.
            -- If the count is more than the NLU_MAX_RETRY value then we disconnect the call
            if self:count_interactions_by_node_id(self.current_node:get_id(), result:get_id()) > NLU_MAX_RETRY then
                self.logger:msg(LEVEL_ERROR, "Max retry exceeded. Exiting call.. ")
                return nil
            end
            result.user_input = self.current_node.user_input

        end
        return result
    else
        self.logger:msg(LEVEL_ERROR, string.format("FlowFSM:get_next_node\tNo go to node matching result found for %s, next_node_id = %s", tostring(result), tostring(next_node_id)))
        return nil
    end
end


--[[
-----------------------------------------------
-- Saves an interaction in memory for the given node
-- Takes node to save as argument. Usually it's the
-- current_node but it could be any
-- Will not add duplicate interaction objects
-- (uniqueness check is based on node start time)
-----------------------------------------------
--]]
function FlowFSM:save_interaction_in_memory(node, type, data, unique_key, prev_node)

    if node then
        -- converting the duration from millisecond to clock format e.g. hh:mm:ss
        local end_time = math.ceil(socket.gettime() * 1000)
        -- A sudden hangup on the final node may result in no start time being set
        -- Handle this case by not assuming start_time is set
        local duration_in_millisecond = 0
        if node.start_time then
            duration_in_millisecond = end_time - node.start_time
        end
        local formatted_duration = "'" .. Utility:millisecondsToClock(duration_in_millisecond) .. "'"

        -- creates new interaction object in memory
        local interaction = Interaction:new {
            attempt_id = self.attempt_id,
            duration = formatted_duration,
            node_id = node:get_id(),
            created = 'now()',
            modified = 'now()',
            state = 1
        }

        local result = node.result
        -- based on the node type sets either response_value or response_file
        local node_type = node:get_type()
        if node_type == FLOW_NODE_TYPE_MULTI_DIGIT or node_type == FLOW_NODE_TYPE_PLAY_MULTI_DIGIT then
            interaction.type = INTERACTION_TYPE_KEY_PRESS
            -- if no result making it empty string
            if result == false or result == "" or result == nil then
                result = "''"
            end
            interaction.response_value = result
            interaction.response_file_id = nil
        elseif node_type == FLOW_NODE_TYPE_RECORD or node_type == FLOW_NODE_TYPE_PLAY_RECORD then
            interaction.type = INTERACTION_TYPE_VOICE
            if result then
                result = "'" .. result .. "'"
            else
                result = nil
            end
            interaction.response_file_id = result
            interaction.response_value = "''"
         elseif node_type == FLOW_NODE_TYPE_CAI or node_type == FLOW_NODE_TYPE_PLAY_TTS or node_type == FLOW_NODE_TYPE_DETECT_SPEECH_STT or node_type == FLOW_NODE_TYPE_NLU then
            interaction.type = type
            self.logger:msg(LEVEL_DEBUG, "SAVING NODE OF TYPE" .. node_type)
            if result then
                result = "'" .. result .. "'"
            else
                result = nil
            end
            interaction.response_file_id = result
            if node_type ~= FLOW_NODE_TYPE_CAI then
               interaction.response_file_id = nil
            end
            interaction.response_value = "''"
            interaction.data = "''"
            if prev_node then
                interaction.prev_node_id = prev_node:get_id()
            end
            -- Convert the Lua table to an hstore string
            local hstore_data = ""
            if data then
             for key, value in pairs(data) do
                 if value then
                     value = string.gsub(value, "'", "''")
                 end
                 self.logger:msg(LEVEL_DEBUG, "HSTORE DATA KEY- VALUE " .. key .. value)
                 hstore_data = hstore_data .. '"' .. key .. '"=>' .. '"' .. value .. '",'
             end
             hstore_data = hstore_data:sub(1, -2)
             hstore_data = "'" .. hstore_data .. "'"
             interaction.data = hstore_data

            end
        else
            interaction.type = INTERACTION_TYPE_LISTEN
            interaction.response_file_id = nil
            interaction.response_value = "''"
        end

        -- To prevent duplicate records being added for
        -- the same actual interaction with a node (e.g. on hangup),
        -- index this table by the start time, which uniquely identifies
        -- an actual interaction of a given node. NOTE that
        -- node_id is not sufficiently unique because there may
        -- be calls where you repeatedly go to the same node over
        -- and over again; for this a unique interaction record
        -- should be recorded each time.
        -- On hangup (end_call()), we try to save the last node.
        -- We are not sure where the code execution has gotten... maybe
        -- it is saved and maybe not. So try to save blindly and if already
        -- saved it will just overwrite the previous object
        local key = unique_key or node.start_time or end_time
        self.logger:msg(LEVEL_DEBUG, "FlowFSM:save_interaction_in_memory\tsaving node : " .. tostring(node.id) .. ", key : " .. tostring(key) .. ", result : " .. tostring(result))
        self.interactions[key] = interaction
        return interaction
    else
        return nil
    end
end


--[[
-----------------------------------------------
-- Saves the interactions in database
-----------------------------------------------
--]]
function FlowFSM:save_interactions()
    local field_n = { "attempt_id", "duration", "node_id", "type","data", "response_value", "response_file_id", "created", "modified", "state" }
    -- saving the interactions in bulk, But it contain response file's fk so we first need to create response file's content and then bulk insert it
    -- In Interaction if response is voice file then on interaction model response_file is content object so we need to create content object
    for unique_time, interaction in pairs(self.interactions) do
        local response_file = interaction['response_file_id']
        if response_file ~= "''" and response_file ~= nil and response_file ~= '' then
            -- Create content object and get ID for setting it on Interaction reponse file
            -- Response file is full path of file, So we find file name from it
            response_file_name = "'" .. response_file:match("^.+/(.+)$")
            content = Content:new({ name = response_file_name, response_file = response_file, logger = self.logger, dbh = self.dbh, created = 'now()', modified = 'now()', dbschema = self.dbschema })
            content_id = content:save()

            -- Now actual response file is not file but fk of content, So change it to content_id
            self.interactions[unique_time]["response_file_id"] = content_id
        end
    end
    self.dbh:bulk_insert_into_table("scheduling_interaction", field_n, self.interactions)
    return true
end


--[[
-----------------------------------------------
-- Executes the call
-- 1. Execute the nodes until either end is reached or no next node found
-----------------------------------------------
--]]
function FlowFSM:execute_call()
    local loop = 0 -- to avoid infinit loop - to be on safe side :)
    while self.session:ready() and not self.ended and loop < 10000 do
        loop = loop + 1
        -- Loop on the State Machine to find the next node to proceed
        self:execute_current_node(all_user_params)
    end
    -- End call
    self:end_call()
end

--[[
-----------------------------------------------
-- Ends calls by performing following actions:
-- 1. Hangup the call
-- 2. Saves the interactions into database
-- 3. Disconnect the database
-----------------------------------------------
--]]
function FlowFSM:end_call()
    if self.ended then
        return true
    end
    self.ended = true

    self.logger:msg(LEVEL_INFO, "FlowFSM:end_call")

    --[[
    ---------------------------------------------------------------------------
    -- Need to explicitly hangup the call in case we are calling this
    -- method manually from the middle of the script. If we get here
    -- by hangup hook, presumably the session is already hung up but we
    -- will only get here once since we test and set self.ended above
    --
    -- can do this first as the stuff below doesn't require the cal
    -- to be live. Save airtime by cutting right away
    --]]
    self:hangup()
    -- ------------------------------------------------------------------------

    if self.current_node and self.current_node:get_type() ~= FLOW_NODE_TYPE_CAI then
      -- Save the current (last) interaction
      self:save_interaction_in_memory(self.current_node)
    end

    -- Save all the interactions to the database
    self:save_interactions()

    self:db_disconnect()

    -- don't need to save duration, that will be done asynchronously on CDR processing
end

--[[
-----------------------------------------------
-- hangup the call
-----------------------------------------------
--]]
function FlowFSM:hangup()
    -- This will interrupt lua script
    self.logger:msg(LEVEL_INFO, "FlowFSM:hangup_call")
    -- session should always be set, this is
    -- a just in case check
    if self.session then
        self.session:hangup()
    end
end


return FlowFSM
