-- This script extends wrk2 to handle multiple server addresses, and multiple
-- paths on each server.

local threads = {}
local counter = 1

-- Global context

function setup(thread)
    table.insert(threads, thread)
    thread:set("id",counter)
    counter = counter +1
    math.randomseed(os.time())
    math.random(); math.random(); math.random()
end

-- Thread context

function thread_next_server()
    idx = math.random(#reqs)
    local next_addr = string.format("%s", addrs[idx])
    if curr_addr ~= "" and next_addr ~= curr_addr then
        wrk.thread.addr = addrs[idx]
    end
    curr_addr = next_addr
end


function init(args)
    urls = ""
    counts = ""
    reqs  = {""}
    c_resps = 0
    c_requs = 0
    addrs = {}
    curr_addr = ""
    idx = 0

    if 2 > #args then
        --print("Usage: wrk <URL> <pattern> <count>")
        os.exit(1)
    end

    -- the dash ("-") is magic in lua, so we need to escape it.
    local match = string.gsub(args[1], '-', '%%%-')
    local count = tonumber(args[2],10)
    local p = wrk.port
    if not p then p="" else p=":" .. p end

    local paths={}
    for i=3, #args, 1 do
        if "/" == args[i]:sub(1,1) then
            paths[i-2] = args[i]
        else
            paths[i-2] = "/" .. args[i]
        end
    end
    if 0 == #paths then
        paths[1] = "/"
    end

    for i=1, count, 1 do
        local repl = string.gsub(match, "-[0-9]+$", string.format("-%d",i))
        local host = string.gsub(wrk.host, match, repl)
        for j=1, #paths, 1 do
            local idx = (i-1) * #paths  + j
            for k, v in ipairs(wrk.lookup(host, wrk.port or "http")) do
                addrs[idx] = v; break
            end
            reqs[idx] = string.format(
                    "GET %s HTTP/1.1\r\n"
                    .. "Host:%s%s\r\n\r\n",
                        paths[j], host, p)
            urls = string.format("%s,(%s) %s://%s%s%s",
                        urls, addrs[idx], wrk.scheme, host, p, paths[j])
        end
    end

    urls = urls .. ","
    thread_next_server()
end


function request()
    local ret = reqs[idx]

    if counts == "" then
        counts = tostring(idx)
    else
        counts = string.format("%s,%s", counts, tostring(idx))
    end

    c_requs = c_requs + 1
    return ret
end


function response(status, headers, body)
    c_resps = c_resps + 1
    thread_next_server()
end

-- Global context

function done(summary, latency, requests)
    print(string.format("Total Requests: %d", summary.requests))
    print(string.format("HTTP errors: %d", summary.errors.status))
    print(string.format("Requests timed out: %d", summary.errors.timeout)) 
    print(string.format("Bytes received: %d", summary.bytes))
    print(string.format("Socket connect errors: %d", summary.errors.connect))
    print(string.format("Socket read errors: %d", summary.errors.read))
    print(string.format("Socket write errors: %d", summary.errors.write))

    -- generate table of URLs from first thread's string (all threads use same list)
    local urls = {}
    local c_requs = 0
    local c_resps = 0
    t = unpack(threads,1,2)
    t:get("urls"):gsub("([^,]+),", function(u) table.insert(urls, u) end)

    local counts = {}
    for i=1, #urls, 1 do
        counts[i] = 0
    end

    -- fetch url call counts of individual threads
    local c = t:get("counts")
    c = c .. ","
    for i, t in ipairs(threads) do
        c:gsub("([0-9]+),", function(s)
                                i = tonumber(s)
                                counts[i] = counts[i] + 1
                             end)
        c_requs = c_requs + t:get("c_requs")
        c_resps = c_resps + t:get("c_resps")
    end

    print(string.format("total requests issued:%d, responses received within runtime:%d", c_requs, c_resps))

    print("\nURL call count")
    for i=1, #urls, 1 do
        print(string.format("%s %d", urls[i], counts[i]))
    end

end
