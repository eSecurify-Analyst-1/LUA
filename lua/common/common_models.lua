--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/9/16
-- Time: 12:38 PM
-- To change this template use File | Settings | File Templates.
--

require "common_constants"

-- Mode to flush the insert for the survey results. Set it to false for better performance,
-- set it to true if you need realtime results pushed to your database
local FAST_FLUSH_INSERT = false

--[[
-- BaseModel class
--
-- Provides basic constructors and DB connectivity
-- All models common or app-specific should inherit from this

]]--
BaseModel = {
    -- default field values
    dbh = nil,
    logger = nil,
    is_connected = false,
    session = nil,
    id = nil,
}

function BaseModel:new (o)
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

function BaseModel:init()
    -- leave blank, meant to be overridden by classes if required
    return true
end

function BaseModel:db_connect()
    if not self.is_connected then
        self.is_connected = true
        return self.dbh:connect()
    end
end

function BaseModel:db_disconnect()
    if self.is_connected then
        self.is_connected = false
        self.dbh:disconnect()
    end
end

function BaseModel:db_logger(level, msg)
    if self.logger then
        self.logger:msg(level, msg)
    end
end

function BaseModel:db_logger_inspect(level, msg)
    if self.logger then
        self.logger:msg_inspect(level, msg)
    end
end

function BaseModel:get_id()
    return self.id
end
