-- Module instantiation
local cjson = require "cjson"
local cjson2 = cjson.new()
local cjson_safe = require "cjson.safe"

wrk.headers["Content-Type"] = "application/json"

srcid ="e0840c77-61b1-4c35-bc6b-c4f02e9e754d"

-- Load URL paths from the file
function load_request_objects_from_file(file)
  local data = {}
  local content
  local all = {}
  local lines = {}

  local f=io.open(file,"r")
  if not f then return nil end

  while true do
      line = f:read()
      if line == nil then break end
      data = cjson.decode(line)
      table.insert(all, data)
  end
  f:close()

  return all
end

-- print("multiplerequests: Found " .. #requests .. " requests")

function init(args)
  wrk.headers["Authorization"] = args[2]
  requests = load_request_objects_from_file(args[1])
  if #requests <= 0 then
    print("multiplerequests: No requests found.")
    os.exit()
  end
end

-- Initialize the requests array iterator
counter = 1

request = function()
  local request_object = requests[counter]
  counter = counter + 1

  if counter > #requests then
    counter = 1
  end

  -- print( 'Calling /v1/source/'..srcid..'/record/'..request_object.record_id)
  return wrk.format('GET', '/v1/source/'..srcid..'/record/'..request_object.record_id)
end

-- function response(status, headers, body)
--       if headers then
--          print(status.." with "..headers["x-amzn-RequestId"])
--       end
-- end
