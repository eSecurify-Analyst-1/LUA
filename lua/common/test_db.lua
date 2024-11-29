-- connect to ODBC database

local dbh = freeswitch.Dbh("pgsql://host=localhost dbname=awaazde user=fs password=fs123")

local row = {}
my_query = "SELECT * FROM awaazde.scheduling_flownode flow WHERE flow.id = 2 LIMIT 1 OFFSET 0"
assert(dbh:query(my_query, function(qrow)
    for key, val in pairs(qrow) do
        freeswitch.consoleLog("debug", key)
        freeswitch.consoleLog("debug", val)
        row[key] = val
    end
end))