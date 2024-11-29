local https = require("ssl.https")
local jwt = require "luajwtjitsi"
local cjson = require "dkjson"
local ltn12 = require("ltn12")

local function GetJwtToken(serviceAccount)
    local saDecode, err = cjson.decode(serviceAccount)

    if type(saDecode) ~= "table" then
        print("[accesstoken] Invalid GCP_SERVICE_ACCOUNT, expect JSON: ", tostring(err))
        error("Invalid format for GCP Service Account")
        return
    end
    local timeNow = os.time()
    if (not (saDecode.client_email and saDecode.private_key and saDecode.private_key_id)) then
        print("[accesstoken] Invalid GCP_SERVICE_ACCOUNT, missing required field")
        error("Invalid GCP Service Account")
        return
    end
    local payload = {
        iss = saDecode.client_email,
        sub = saDecode.client_email,
        aud = "https://oauth2.googleapis.com/token",
        iat = timeNow,
        exp = timeNow + 3600,
        scope = "https://www.googleapis.com/auth/dialogflow"
    }
    local payloadJson = cjson.encode(payload)
    local alg = "RS256"
    local jwt_token = jwt.encode(payload, saDecode.private_key, alg)
    return jwt_token
end

local function GetAccessTokenByJwt(jwtToken)
    local body = {
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion = jwtToken
    }
    local response_body = {}
    local res, code, response_headers = https.request {
        url = "https://oauth2.googleapis.com/token",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #cjson.encode(body)
        },
        -- data = cjson.encode(body),
        source = ltn12.source.string(cjson.encode(body)),
        sink = ltn12.sink.table(response_body)
    }
    if not res then
        print("[accesstoken] Unable to get access token")
        error("Unable to get access token")
        return
    end
    local accessToken = cjson.decode(table.concat(response_body))
    return accessToken
end

local function GetAccessTokenBySA(serviceAccount)
    print("[accesstoken] Using Environment Service Account to get Access Token")

    if not serviceAccount then
        print("[accesstoken] Couldn't find GCP_SERVICE_ACCOUNT env variable")
        error("Couldn't find GCP_SERVICE_ACCOUNT env variable")
        return
    end
    local jwtToken = GetJwtToken(serviceAccount)
    local res = assert(GetAccessTokenByJwt(jwtToken))
    if res.error then
        print("[accesstoken] Unable to get access token: ", res.error_description)
        return
    end
    return res, "SA"
end

local function GetAccessTokenByWI()
    return nil
end

local AccessToken = {}
AccessToken.__index = AccessToken
function AccessToken:new(gcpServiceAccount)
    local self = {}
    setmetatable(self, AccessToken)

    gcpServiceAccount = gcpServiceAccount or os.getenv("GCP_SERVICE_ACCOUNT")
    local file = io.open(gcpServiceAccount, "r") -- Open the file in read mode
    local content = file:read("*a") -- Read the entire content of the file
    file:close() -- Close the file

    accessToken, authMethod = GetAccessTokenBySA(content)

    if (accessToken) then
        self.token = accessToken.access_token
        self.expireTime = os.time() + accessToken.expires_in
        self.authMethod = authMethod
    else
        print("[accesstoken] Unable to get accesstoken")
        error("Failed to authenticate")
        return nil
    end
    return self
end

function AccessToken:needsRefresh()
    return self.expireTime < os.time()
end

function AccessToken:refresh()
    local accessToken
    if (self.authMethod == "SA") then
        local gcpServiceAccount = os.getenv("GCP_SERVICE_ACCOUNT")
        accessToken = GetAccessTokenBySA(gcpServiceAccount)
    elseif (self.authMethod == "WI") then
        accessToken = GetAccessTokenByWI()
    end
    if (accessToken) then
        self.token = accessToken.access_token
        self.expireTime = now() + accessToken.expires_in
        return true
    end
    return false
end

return setmetatable(
    AccessToken,
    {
        __call = function(self, ...)
            return self:new(...)
        end
    }
)
