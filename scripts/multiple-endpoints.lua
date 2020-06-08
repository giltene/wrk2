-- This script extends wrk2 to handle multiple server addresses
-- as well as multiple paths (endpoints) per server

-----------------
-- main() context

-- main() globals
local threads = {}
local counter = 1

function setup(thread)
    -- Fill global threads table with thread handles so done()
    -- can process per-thread data
    table.insert(threads, thread)
    thread:set("id",counter)
    counter = counter +1
    math.randomseed(os.time())
end

-----------------
-- Thread context

function xtract(str, match, default, err_msg)
    local ret, count = string.gsub(str, match, "%1", 1)
    if count == 0 then
        if not default then
            print(string.format("Error parsing URL '%s': %s",str,err_msg))
            os.exit(1)
        end
        ret = default
    end
    return ret
end

function init(args)
    -- Thread globals used by done()
    called_idxs = ""
    urls = ""
    -- Thread globals used by request(), response()
    addrs = {}
    idx = 0

    -- table of lists; per entry:
    --   proto, host, hostaddr, port, path + params
    endpoints={}
    -- tablre of prepared HTTP requests for endpoints above
    reqs={}

    -- parse command line URLs and prepare requests
    for i=0, #args, 1 do
        -- note that URL parsing does not support user/pass as 
        -- wrk2 does not support auth
        local proto = xtract(args[i],
                "^(http[s]?)://.*", nil, "missing or unsupported  protocol")
        local host  = xtract(
                args[i], "^http[s]?://([^/:]+)[:/]?.*", nil, "missing host")
        local port  = xtract(args[i], "^http[s]?://[^/:]+:(%d+).*", 80)
        local path  = xtract(args[i], "^http[s]?://[^/]+(/.*)","/")

        -- get IP addr(s) from hostname, validate by connecting
        local addr = nil
        for k, v in ipairs(wrk.lookup(host, port)) do
            if wrk.connect(v) then
                addr = v
                break
            end
        end
        if not addr then
            print(string.format(
                "Error: Unable to connect to %s port %s.", host, port))
            os.exit(2)
        end

        -- store the endpoint
        endpoints[i] = {}
        endpoints[i][0] = proto
        endpoints[i][1] = host
        endpoints[i][2] = addr
        endpoints[i][3] = port
        endpoints[i][4] = path
        endpoints[i][5] = string.format(
                    "GET %s HTTP/1.1\r\nHost:%s:%s\r\n\r\n", path, host, port)
        if urls == "" then
            urls = args[i]
        else
            urls = string.format("%s,%s",urls,args[i])
        end
    end

    urls = urls .. ","
    -- initialize idx, assign req and addr
    idx = math.random(0, #endpoints)
    wrk.thread.addr = endpoints[idx][2]
end

function request()
    local ret = endpoints[idx][5]
    return ret
end


function response(status, headers, body)
    -- add current index to string of endpointsi calle 
    local c = ","
    if called_idxs == "" then c="" end
    called_idxs = string.format("%s%s%s",called_idxs,c,idx)

    -- Pick a new random endpoint for the next request
    -- Also, update the thread's remote server addr if endpoint
    -- is on a different server.
    local prev_srv = endpoints[idx][2]
    idx = math.random(0, #endpoints)
    if prev_srv ~= endpoints[idx][2] then
        -- Re-setting the thread's server address forces a reconnect
        wrk.thread.addr = endpoints[idx][2]
    end
end

-----------------
-- main() context

function done(summary, latency, requests)
    print(string.format("Total Requests: %d", summary.requests))
    print(string.format("HTTP errors: %d", summary.errors.status))
    print(string.format("Requests timed out: %d", summary.errors.timeout)) 
    print(string.format("Bytes received: %d", summary.bytes))
    print(string.format("Socket connect errors: %d", summary.errors.connect))
    print(string.format("Socket read errors: %d", summary.errors.read))
    print(string.format("Socket write errors: %d", summary.errors.write))

    -- generate table of URL strings from first thread's endpoints table
    -- (all threads generate the same table in init())
    local urls = {}
    local counts = {}
    local i = 0
    t = unpack(threads,1,2)
    t:get("urls"):gsub("([^,]+),",
            function(u)
                urls[i]=u
                counts[i] = 0
                i = i+1
            end)

    -- fetch url call counts of individual threads
    local c = t:get("called_idxs")
    c = c .. ","
    for i, t in ipairs(threads) do
        c:gsub("([0-9]+),", function(s)
                                i = tonumber(s)
                                counts[i] = counts[i] + 1
                             end)
    end

    print("\nURL call count")
    for i=0, #urls, 1 do
        print(string.format("%s : %d", urls[i], counts[i]))
    end
end
