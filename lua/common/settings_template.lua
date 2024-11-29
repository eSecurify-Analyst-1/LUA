--
-- Database connection settings
--
DBHOST = '127.0.0.1'
DBNAME = 'awaazde'
DBUSER = 'fs'
DBPASS = 'fs123'
DBPORT = 2210

--
-- Logging settings
--
LOG_DIR = '/home/awaazde/log/lua/'

--
-- Media settings
--
ROOT_DIR = '/home/awaazde/www/awaazde/'
MEDIA_DIR = ROOT_DIR ..  "media/"
LUA_DIR = ROOT_DIR .. "backend/awaazde/ivr/freeswitch/lua/"


FS_RECORDING_MEDIA_DIR = '/freeswitch/'

--
-- Web Services
--
HOST = "http://api.awaaz.de/"
INBOUND_FLOW_URL = HOST .. "integrations/freeswitch/inbound/"

POST_WEBHOOK_URL = HOST .. "integrations/freeswitch/postwebhook/"
API_USERNAME='lua_app_user'
API_PASSWORD='Lu@g1vevo1ce'

--
-- GDF
--
GDF_ACCOUNT_PATH=''
GDF_PROJECT=''
VIRTUAL_ENV=''
NAVANA_TOKEN=''
DEEPGRAM_TOKEN=''

DEEPGRAM_API_KEY=''
BODHI_API_KEY=''
BODHI_CUSTOMER_ID=''
