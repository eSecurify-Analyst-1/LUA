--
-- Created by IntelliJ IDEA.
-- User: neil
-- Date: 11/9/16
-- Time: 12:38 PM
--

require "common_constants"

local DBH = {
    dbh = nil,
    logger = nil,
    dbname = nil,
    dbuser = nil,
    dbpass = nil,
    dbschema = nil,
    dbhost = nil,
    dbport = nil
}

function DBH:new(o)
    o = o or {} -- create object if user does not provide one

    -- Ref. task: https://app.asana.com/0/1201458447326024/1201145999348187/f
    -- The '__metatable' attribute is set to increase security against malacious modifications because modification of the contents of
    -- the metatable can break code outside the sandbox that relies on this string behavior unless objects are protected
    -- appropriately via __metatable.
    self.__metatable = "This metatable is locked"
    setmetatable(o, self)
    self.__index = self
    return o
end

function DBH:connect()
    -- connect to ODBC database
    self.dbh = freeswitch.Dbh("pgsql://host=".. self.dbhost .. " port=" .. self.dbport .. " dbname=" .. self.dbname .. " user=" .. self.dbuser .. " password=" .. self.dbpass)
    local connected = self.dbh:connected()
    return connected
end

function DBH:disconnect()
    -- self.dbh:release() -- optional
end

function DBH:get_active_schema()
    return self.dbschema
end

function DBH:get_list(sqlquery)
    self.logger:msg(LEVEL_DEBUG, "Load SQL : " .. sqlquery)
    local list = {}
    self.dbh:query(sqlquery, function(row)
        --Let's transform empty value to False
        --We do this to have similar behavior to luasql
        --luasql doesn't return the empty/null fields
        for k, v in pairs(row) do
            if v == '' then
                row[k] = false
            end
        end
        list[tonumber(row.id)] = row
    end)
    return list
end

--[[
-------------------------------------
-------------- get_object -----------
-------------------------------------

	Get Object and if not found then return nil
-------------------------------------
--]]
function DBH:get_object(sqlquery)
    self.logger:msg(LEVEL_DEBUG, "Load SQL : " .. sqlquery)
    local res_get_object = nil
    self.dbh:query(sqlquery, function(row)
        res_get_object = row
        for k, v in pairs(res_get_object) do
            if v == '' then
                res_get_object[k] = false
            end
        end
    end)
    return res_get_object
end

function DBH:execute(sqlquery)
    self.logger:msg(LEVEL_DEBUG, "Load SQL : " .. sqlquery)
    local res = self.dbh:query(sqlquery)
    return res
end

--[[
-------------------------------------
------- get_table_one_row -----------
-------------------------------------

	returns a table with one result row,
	or nil if no record found
-------------------------------------
--]]

function DBH:get_table_one_row(table, cond, fields)
    fields = fields or "*";
    local sql_statement = " SELECT " .. fields .. " FROM " .. self.dbschema .. "." .. table .. " WHERE " .. cond .. " LIMIT 1 OFFSET 0";
    return self:get_object(sql_statement)
end

--[[
-------------------------------------------
------- get_table_rows --------------------
-------------------------------------------

	returns list with resultset, indexed by obj id
-------------------------------------------
--]]

function DBH:get_table_rows(table, cond, fields)
    fields = fields or "*";
    local sql_statement = " SELECT " .. fields .. " FROM " .. self.dbschema .. "." .. table .. " WHERE " .. cond;
    return self:get_list(sql_statement)
end


--[[
-------------------------------------------
------- get_table_rows with join --------------------
-------------------------------------------

	returns list with resultset, indexed by obj id
-------------------------------------------
--]]

function DBH:get_table_rows_with_join(table, join_table, cond, fields)
    fields = fields or "*";
    local sql_statement = " SELECT " .. fields .. " FROM " .. self.dbschema .. "." .. table .. ", " .. self.dbschema .. "." .. join_table .. " WHERE " .. cond;
    return self:get_list(sql_statement)
end

--[[
-------------------------------------------
------- get_table_field -------------------
-------------------------------------------

	returns a single-value (i.e. not a table)
	from the db, or nil if no record found
-------------------------------------------
--]]

function DBH:get_table_field(table, fieldname, cond)
    local sql_statement = " SELECT " .. fieldname .. " FROM " .. self.dbschema .. "." .. table .. " WHERE " .. cond .. " LIMIT 1 OFFSET 0";
    local obj = self:get_object(sql_statement)
    if obj == nil then
        return obj
    else
        return obj[fieldname]
    end
end


--[[
-------------------------------------------
------- insert_into_table -----------------
-------------------------------------------

	inserts the name_value table into
	the given table
	return true if inserted successfully else return false
-------------------------------------------
--]]

function DBH:insert_into_table(table, name_vals)
    local sql_statement = " INSERT INTO " .. self.dbschema .. "." .. table .. " ( ";

    for name, val in pairs(name_vals) do
        sql_statement = sql_statement .. name .. ", ";
    end
    -- remove trailing space and comma
    sql_statement = sql_statement:sub(1, -3);
    sql_statement = sql_statement .. ") VALUES ( ";

    for name, val in pairs(name_vals) do
        sql_statement = sql_statement .. tostring(val) .. ", ";
    end
    -- remove trailing space and comma
    sql_statement = sql_statement:sub(1, -3);
    sql_statement = sql_statement .. " ) ";

    local res = self:execute(sql_statement)
    -- Now we fire another query to get id of inserted record but ideallt it shoud be done here in one single query of insert
    -- TODO: We need to change it, Postgres supported to insert one row and return inserted row's id
    -- Check optio:3 of first Answer (https://stackoverflow.com/questions/2944297/postgresql-function-for-last-inserted-id)
    return res
end


--[[
-------------------------------------------
------- bulk_insert_into_table -----------------
-------------------------------------------

	inserts the name_value table into
	the given table
	return inserted id
-------------------------------------------
--]]

function DBH:bulk_insert_into_table(table_name, fields, values)
    local sql_result = ""
    local count = 0
    local sql_statement = ""

    keys={}
    for k in pairs(values) do
        table.insert(keys,k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        v = values[k]
        count = count + 1
        if count > 1 then
            sql_result = sql_result .. ","
        end
        sql_result = sql_result .. "("

        for _, field in pairs(fields) do
            f_value = "null"
            if v[field] then
                f_value = tostring(v[field])
            end
            sql_result = sql_result .. f_value .. ", "
        end
        sql_result = sql_result:sub(1, -3)
        sql_result = sql_result .. ")"
    end

    if count > 0 then
        local sql_statement = " INSERT INTO " .. self.dbschema .. "." .. table_name .. " ( "

        for _, field in pairs(fields) do
            sql_statement = sql_statement .. field .. ", "
        end
        -- remove trailing space and comma
        sql_statement = sql_statement:sub(1, -3);
        sql_statement = sql_statement .. ") VALUES " .. sql_result

        local res = self:execute(sql_statement)
        return true
    else
        return false
    end
end

--[[
-------------------------------------------
------- update_table ----------------------
-------------------------------------------

	updates the table with the given data
	for the given condition

	returns nothing
-------------------------------------------
--]]

function DBH:update_table(table, name_vals, cond)
    local sql_statement = " UPDATE " .. self.dbschema .. "." .. table .. " SET ";

    for name, val in pairs(name_vals) do
        sql_statement = sql_statement .. name .. " = " .. tostring(val) .. ", ";
    end
    -- remove trailing space and comma
    sql_statement = sql_statement:sub(1, -3);
    if (cond ~= nil) then
        sql_statement = sql_statement .. " WHERE " .. cond;
    end

    res = self:execute(sql_statement);
    return res
end

--[[
-------------------------------------------
------- delete_table ----------------------
-------------------------------------------

	deletes from the given table
	for records with the given condition

	returns nothing
-------------------------------------------
--]]

function DBH:delete_from_table(table, cond)
    local sql_statement = " DELETE FROM " .. self.dbschema .. "." .. table;

    if (cond ~= nil) then
        sql_statement = sql_statement .. " WHERE " .. cond;
    end

    res = self:execute(sql_statement);
    return res
end

return DBH
