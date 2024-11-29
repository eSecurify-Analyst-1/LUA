--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/10/16
-- Time: 3:35 PM
-- To change this template use File | Settings | File Templates.
--

require "common_constants"
require "settings"

local logging_file_lib = require "logging.file"
local logging = require "logging"

local logging_file = logging_file_lib(LOG_DIR .. "awaazde_%s.log", "%Y-%m-%d")

--
-- Set Logging Level
-- logging.DEBUG
-- The DEBUG level designates fine-grained informational events that are most useful to debug an application.
-- logging.INFO
-- The INFO level designates informational messages that highlight the progress of the application at coarse-grained level.
-- logging.WARN
-- The WARN level designates potentially harmful situations.
-- logging.ERROR
-- The ERROR level designates error events that might still allow the application to continue running.
-- logging.FATAL
-- The FATAL level designates very severe error events that would presumably lead the application to abort.
--
logging_file:setLevel(logging.DEBUG)


local Logger = {
    -- default field values
    fs_env = false,
    callee_phone_number = '',
    script_name = '',
    schema_name = '',
    attempt_id = '',
}

function Logger:new (o)
    o = o or {}   -- create object if user does not provide one

    -- Ref. task: https://app.asana.com/0/1201458447326024/1201145999348187/f
    -- The '__metatable' attribute is set to increase security against malacious modifications because modification of the contents of 
    -- the metatable can break code outside the sandbox that relies on this string behavior unless objects are protected 
    -- appropriately via __metatable. 
    self.__metatable = "This metatable is locked"
    setmetatable(o, self)
    self.__index = self
    return o
end

function Logger:set_attempt_id(script_name, attempt_id)
    --Set property attempt_id
    attempt_id = attempt_id or ''
    self.attempt_id = tostring(attempt_id)
end

function Logger:set_schema_name(schema_name)
    --Set property attempt_id
    schema_name = schema_name or ''
    self.schema_name = tostring(schema_name)
end

function Logger:msg_inspect(level, message)
    --inspect the message prior calling the Logger
    local inspect = require "inspect"
    self:msg(level, inspect(message))
end

function Logger:getfs_level(level)
    --get freeswitch log level
    if level == LEVEL_DEBUG then
        return 'debug'
    elseif level == LEVEL_WARN then
        return 'warning'
    elseif level == LEVEL_ERROR then
        return 'err'
    elseif level == LEVEL_INFO then
        return 'info'
    else
        return 'info'  -- default value info
    end
end

function Logger:msg(level, message)
    --Print out or logger message according to the verbosity
    local msg = self.script_name..'\t'..self.schema_name..'\t'..self.attempt_id..'\t'..self.callee_phone_number..'\t'..tostring(message)
    -- level : DEBUG, INFO, WARN, ERROR
    if not self.fs_env then
        print(msg)
    else
        freeswitch.consoleLog(self:getfs_level(level), msg.."\n")
    end
    -- note we could just use logging.<level> outside and just run
    -- logging_file:log(<level>, msg) but saving the need to import
    -- logging lib everywhere in the code. Instead just import common constants
    if level == LEVEL_DEBUG then
        logging_file:debug(msg)
    elseif level == LEVEL_WARN then
        logging_file:warn(msg)
    elseif level == LEVEL_ERROR then
        logging_file:error(msg)
    elseif level == LEVEL_INFO then
        logging_file:info(msg)
    else
        logging_file:info(msg)  -- default info
    end

end

return Logger
