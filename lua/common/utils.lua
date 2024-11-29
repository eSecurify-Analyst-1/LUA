require "settings"
require "common_constants"
socket = require("socket")
local json = require("cjson")
local Utility = {-- util class
}

function Utility:sleep(sec)
    -- Why ??
    -- http://bugs.awaaz.de/show_bug.cgi?id=1298
    -- The original implementation of sleep with os.clock was busy-wait, i.e. even in sleep mode processes were still
    -- consuming the CPU resources. When there are large number of concurrent calls going on with each call waiting for
    -- user's input, then we experienced 100% CPU utilisation by freeswitch itself which was affecting call quality.
    -- Current socket.sleep implementation of sleep does not do busy waiting and thus it doesn't consume lot of CPU.
    -- references : http://lua-users.org/wiki/SleepFunction, https://stackoverflow.com/q/20512038/7832014
    -- For R&D and discussion : https://app.asana.com/0/79068549406354/1173440237883577
    socket.sleep(sec)
end

function Utility:tablelength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Copy-paste from http://lua-users.org/wiki/SimpleRound
function Utility:round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Copy-paste from https://gist.github.com/jesseadams/791673
-- They are converting seconds to clock, But we modify it little bit and convertung milliseconds to clock
-- We just change below counts
-- hours to second = 3600 we changed it to hours to milliseconds = 3600000
-- minutes to second = 60 we chanhed it to minutes to milliseconds = 60000
-- At last we need to convert milliseconds to second so we devide milliseconds by 1000 so we get seconds from milliseconds
function Utility:millisecondsToClock(milliseconds)
    local milliseconds = tonumber(milliseconds)

    if milliseconds <= 0 then
        return "00:00:00";
    else
        hours = string.format("%02.f", math.floor(milliseconds / 3600000));
        mins = string.format("%02.f", math.floor(milliseconds / 60000 - (hours * 60)));
        -- round the seconds to nearest second instead of flooring it to
        -- be consistent with reporting (which also rounds seconds)
        secs = string.format("%02.f", math.ceil((milliseconds - hours * 3600000 - mins * 60000) / 1000));
        return hours .. ":" .. mins .. ":" .. secs
    end
end


--[[
-- Validating the given digits againat the given valid set of digits
-- valid_digits could be list of DIGIT_RANGE_DELIMITER(|) separated digits and/or ranges e.g. 1-3|5
-- digits could be any input collected e.g. 3 or '' - means no input
-- Following is the simplified logic/steps:
--   a. split given valid_digits by DIGIT_RANGE_DELIMITER(|) in order to extract individual digit or range
--      (https://stackoverflow.com/questions/19262761/lua-need-to-split-at-comma/19262818#19262818)
--   b. If it's a range, match the given digits using min and max value from range
--   c. If it's not a range, check if it's digits, if yes try to match with it
--   d. If it's neither range or individual digits, check for empty response, if given valid_range allows it, return true
--]]
function Utility:validate_digits(valid_digits, digits)
    local to_compare = nil

    if digits ~= "" then
        to_compare = tonumber(digits)
    end

    for range in string.gmatch(valid_digits, '([^' .. DIGIT_RANGE_DELIMITER .. ']+)') do
        if string.match(range, '-') then
            local min, max = nil, nil
            -- adapted from https://www.lua.org/pil/20.3.html
            _, _, min, max = range:find("(%d+)%s*-%s*(%d+)")
            min = tonumber(min)
            max = tonumber(max)

            if to_compare and min <= to_compare and to_compare <= max then
                return true
            end
        elseif range == "''" and digits == "" then
            return true
        elseif range ~= "''" and to_compare and tonumber(range) == to_compare then
            return true
        end
    end
    return false
end

function Utility:send_http_request(method, request_body, request_url)
    local response = nil
    if method==HTTP_POST then
       local http = require "socket.http"
       local ltn12 = require"ltn12"
       local body = {}
       local res, code, headers, status = http.request {
           method = method,
           url = request_url,
           source = ltn12.source.string(request_body),
           headers = {
                ["Accept"] = "*/*",
                ["Accept-Encoding"] = "gzip, deflate",
                ["Accept-Language"] = "en-us",
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["content-length"] = tostring(#request_body)
           },
           --collect response body into specified body variable
           --reference:https://onelinerhub.com/lua/making-http-post-request
           sink = ltn12.sink.table(body)
       }
       response = table.concat(body)
    end
    return response
end

function Utility:get_table_from_json(json_string)
    if json_string~="" then
        return json.decode(json_string)
    else
        return {}
    end
end

function Utility:remove_unwanted_characters_from_string(value)
    value = value:gsub("['\n\r\"]", "")
    return value
end
return Utility


function Utility:replace_placeholders(text, dictionary)
    -- Use gsub to search for patterns enclosed in < > and replace them
    return text:gsub("<(.-)>", function(key)
        return dictionary[key] or "<" .. key .. ">"  -- If key not found, keep the placeholder
    end)
end


function Utility:print_table(t, logger, indent)
    indent = indent or ""  -- Default to an empty string if no indent is provided
    for key, value in pairs(t) do
        if type(value) == "table" then
            logger:msg(LEVEL_DEBUG, indent .. tostring(key) .. ":")
            print_table(value, indent .. "  ")  -- Recursive call for nested tables
        else
            logger:msg(LEVEL_DEBUG, indent .. tostring(key) .. ": " .. tostring(value))
        end
    end
end
