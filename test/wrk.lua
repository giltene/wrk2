-- load modules
local cjson = require "cjson"
local cjson2 = cjson.new()
local cjson_safe = require "cjson.safe"

-- global variables
local requests_json = "requests.json"
local addrs   = {}
local threads = {}	-- only for done() statistics
local counter = 0
local max_requests = 0
local request_data

-- functions
function init(args)
  requests  = 0	-- how many requests was issued within a thread
  responses = 0	-- how many responses was received within a thread

--  local msg = "thread %d init() addr: %s\n"
--  io.write(msg:format(id, wrk.thread.addr))
end

-- Load URL paths from the file
function load_request_objects_from_file(file)
  local data = {}
  local content

  -- Check if the file exists
  local f=io.open(file,"r")
  if f~=nil then
    content = f:read("*all")

    io.close(f)
  else
    -- Return the empty array
    return lines
  end

  -- Translate Lua value to/from JSON
  data = cjson.decode(content)

  return data
end

function setup(thread)
  local append = function(host, port)
    for i, addr in ipairs(wrk.lookup(host, port)) do
      if wrk.connect(addr) then
        addrs[#addrs+1] = addr
      end
    end
  end

  if #addrs == 0 then
    requests_data = load_request_objects_from_file(requests_json)

    -- Check if at least one request was found in the requests_json file
    if #requests_data <= 0 then
      io.write("multiplerequests: No requests found.\n")
      os.exit()
    end

--    local msg = "setup(): host=%s; port=%d; req_data=%d\n"
    for i, req in ipairs(requests_data) do
--      io.write(msg:format(req.host, req.port, #requests_data))
      append(req.host, req.port)
    end
  end

  local index = counter % #addrs + 1
  counter = counter + 1
  req = requests_data[index]
  thread:set("id", counter)
  thread:set("method", req.method)
  thread:set("host", req.host)
  thread:set("port", req.port)
  thread:set("path", req.path)
  thread:set("headers", req.headers)
  thread:set("body", req.body)

--  local msg = "setup(): host=%s; port=%d; index=%d; #addrs=%d\n"
--  io.write(msg:format(req.host, req.port, index, #addrs))

  thread.addr = addrs[index]
  table.insert(threads, thread)
end

-- Prints Latency based on Coordinated Omission (HdrHistogram)
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- function done(summary, latency, requests)
--   for i, thread in ipairs(threads) do
--     local id        = thread:get("id")
--     local requests  = thread:get("requests")
--     local responses = thread:get("responses")
--     local msg = "# %d,%d,%d,%d,%d,%d\n"
--     io.write(msg:format(
--              id, requests, responses,
--              latency:percentile(90), latency:percentile(95), latency:percentile(99)))
--   end
-- end

function request()
  requests = requests + 1
  start_us = wrk.time_us()

  return wrk.format(method, path, headers, body)
end

function response(status, headers, body)
  responses = responses + 1

  -- Stop after max_requests if max_requests is a positive number
  if (max_requests > 0) and (responses > max_requests) then
    wrk.thread:stop()
    return
  end

  local msg = "%d,%d,%d,%d,%s %s:%s%s,%d,%d\n"
  local time_us = wrk.time_us()
  local delay = time_us - start_us
  local cont_len = headers["Content-Length"]

--  io.write(msg:format(start_us,delay,id,responses,cont_len,wrk.thread.addr,port,path))
  io.write(msg:format(start_us,delay,status,cont_len,method,host,port,path,id,responses))
end
