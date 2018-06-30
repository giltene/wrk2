# wrk2
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/giltene/wrk2?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

  **a HTTP benchmarking tool based mostly on wrk**

  wrk2 is wrk modifed to produce a constant throughput load, and
  accurate latency details to the high 9s (i.e. can produce
  accurate 99.9999%'ile when run long enough). In addition to
  wrk's arguments, wrk2 takes a throughput argument (in total requests
  per second) via either the --rate or -R parameters (default
  is 1000).

  It is important to note that in wrk2's current constant-throughput
  implementation, measured latencies are [only] accurate to a +/- ~1 msec
  granularity, due to OS sleep time behavior.

  wrk2 (as is wrk) is a modern HTTP benchmarking tool capable of generating
  significant load when run on a single multi-core CPU. It combines a
  multithreaded design with scalable event notification systems such as
  epoll and kqueue.

  An optional LuaJIT script can perform HTTP request generation, response
  processing, and custom reporting. Several example scripts are located in
  scripts/

## Basic Usage @ Radius

   To run on mac you'll need Lua 5.1. To install

   ```
   brew install lua@5.1
   sudo luarocks-5.1 install lua-cjson
   ```

   wrk -t2 -c10 -d30s -L -s scripts/GET_Persist.lua https://api.radius.com requests.json letmeintoradius:1234

  This runs a benchmark for 30 seconds, using 2 threads, keeping
  10 HTTP connections open, and a constant throughput of 10 requests
  per second (total, across all connections combined) 
  reading input in from a JSON file called requests.json and calling 
  https://api.radius.com with Authorization token of "letmeintoradius:1234"

  [It's important to note that wrk2 extends the initial calibration
   period to 10 seconds (from wrk's 0.5 second), so runs shorter than
   10-20 seconds may not present useful information]

  Output:

  Running 5s test @ https://api.radius.com
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   162.29ms   97.79ms 371.71ms   80.00%
    Req/Sec        nan       nan   0.00      0.00%
  Latency Distribution (HdrHistogram - Recorded Latency)
 50.000%  116.74ms
 75.000%  168.83ms
 90.000%  361.73ms
 99.000%  371.97ms
 99.900%  371.97ms
 99.990%  371.97ms
 99.999%  371.97ms
100.000%  371.97ms

  Detailed Percentile spectrum:
       Value   Percentile   TotalCount 1/(1-Percentile)

      87.487     0.000000            2         1.00
      87.487     0.100000            2         1.11
      89.663     0.200000            3         1.25
      91.583     0.300000            5         1.43
      94.143     0.400000            6         1.67
     116.735     0.500000            8         2.00
     117.183     0.550000            9         2.22
     117.183     0.600000            9         2.50
     168.575     0.650000           10         2.86
     168.831     0.700000           11         3.33
     193.919     0.750000           12         4.00
     193.919     0.775000           12         4.44
     193.919     0.800000           12         5.00
     299.775     0.825000           13         5.71
     299.775     0.850000           13         6.67
     361.727     0.875000           14         8.00
     361.727     0.887500           14         8.89
     361.727     0.900000           14        10.00
     361.727     0.912500           14        11.43
     361.727     0.925000           14        13.33
     371.967     0.937500           15        16.00
     371.967     1.000000           15          inf
#[Mean    =      162.289, StdDeviation   =       97.788]
#[Max     =      371.712, Total count    =           15]
#[Buckets =           27, SubBuckets     =         2048]
----------------------------------------------------------
  17 requests in 5.18s, 12.56KB read
Requests/sec:      3.28
Transfer/sec:      2.43KB

## Scripting

  wrk's public Lua API is:

    init     = function(args)
    request  = function()
    response = function(status, headers, body)
    done     = function(summary, latency, requests)

    wrk = {
      scheme  = "http",
      host    = "localhost",
      port    = nil,
      method  = "GET",
      path    = "/",
      headers = {},
      body    = nil
    }

    function wrk.format(method, path, headers, body)

      wrk.format returns a HTTP request string containing the passed
      parameters merged with values from the wrk table.

    global init     -- function called when the thread is initialized
    global request  -- function returning the HTTP message for each request
    global response -- optional function called with HTTP response data
    global done     -- optional function called with results of run

  The init() function receives any extra command line arguments for the
  script. Script arguments must be separated from wrk arguments with "--"
  and scripts that override init() but not request() must call wrk.init()

  The done() function receives a table containing result data, and two
  statistics objects representing the sampled per-request latency and
  per-thread request rate. Duration and latency are microsecond values
  and rate is measured in requests per second.

    latency.min              -- minimum value seen
    latency.max              -- maximum value seen
    latency.mean             -- average value seen
    latency.stdev            -- standard deviation
    latency:percentile(99.0) -- 99th percentile value
    latency[i]               -- raw sample value

    summary = {
      duration = N,  -- run duration in microseconds
      requests = N,  -- total completed requests
      bytes    = N,  -- total bytes received
      errors   = {
        connect = N, -- total socket connection errors
        read    = N, -- total socket read errors
        write   = N, -- total socket write errors
        status  = N, -- total HTTP status codes > 399
        timeout = N  -- total request timeouts
      }
    }

## Benchmarking Tips

  The machine running wrk must have a sufficient number of ephemeral ports
  available and closed sockets should be recycled quickly. To handle the
  initial connection burst the server's listen(2) backlog should be greater
  than the number of concurrent connections being tested.

  A user script that only changes the HTTP method, path, adds headers or
  a body, will have no performance impact. If multiple HTTP requests are
  necessary they should be pre-generated and returned via a quick lookup in
  the request() call. Per-request actions, particularly building a new HTTP
  request, and use of response() will necessarily reduce the amount of load
  that can be generated.

## Acknowledgements

  wrk2 is obviously based on wrk, and credit goes to wrk's authors for
  pretty much everything.

  wrk2 uses my (Gil Tene's) HdrHistogram. Specifically, the C port written
  by Mike Barker. Details can be found at http://hdrhistogram.org . Mike
  also started the work on this wrk modification, but as he was stuck
  on a plane ride to New Zealand, I picked it up and ran it to completion.

  wrk contains code from a number of open source projects including the
  'ae' event loop from redis, the nginx/joyent/node.js 'http-parser',
  Mike Pall's LuaJIT, and the Tiny Mersenne Twister PRNG. Please consult
  the NOTICE file for licensing details.

************************************************************************

A note about wrk2's latency measurement technique:

  One of wrk2's main modification to wrk's current (Nov. 2014) measurement
  model has to do with how request latency is computed and recorded.

  wrk's model, which is similar to the model found in many current load
  generators, computes the latency for a given request as the time from
  the sending of the first byte of the request to the time the complete
  response was received.

  While this model correctly measures the actual completion time of
  individual requests, it exhibits a strong Coordinated Omission effect,
  through which most of the high latency artifacts exhibited by the
  measured server will be ignored. Since each connection will only
  begin to send a request after receiving a response, high latency
  responses result in the load generator coordinating with the server
  to avoid measurement during high latency periods.

  There are various mechanisms by which Coordinated Omission can be
  corrected or compensated for. For example, HdrHistogram includes
  a simple way to compensate for Coordinated Omission when a known
  expected interval between measurements exists. Alternatively, some
  completely asynchronous load generators can avoid Coordinated
  Omission by sending requests without waiting for previous responses
  to arrive. However, this (asynchronous) technique is normally only
  effective with non-blocking protocols or single-request-per-connection
  workloads. When the application being measured may involve mutiple
  serial request/response interactions within each connection, or a
  blocking protocol (as is the case with most TCP and HTTP workloads),
  this completely asynchronous behavior is usually not a viable option.

  The model I chose for avoiding Coordinated Omission in wrk2 combines
  the use of constant throughput load generation with latency
  measurement that takes the intended constant throughput into account.
  Rather than measure response latency from the time that the actual
  transmission of a request occurred, wrk2 measures response latency
  from the time the transmission *should* have occurred according to the
  constant throughput configured for the run. When responses take longer
  than normal (arriving later than the next request should have been sent),
  the true latency of the subsequent requests will be appropriately
  reflected in the recorded latency stats.

  Note: This technique can be applied to variable throughput loaders.
        It requires a "model" or "plan" that can provide the intended
        start time if each request. Constant throughput load generators
        Make this trivial to model. More complicated schemes (such as
        varying throughput or stochastic arrival models) would likely
        require a detailed model and some memory to provide this
        information.

  In order to demonstrate the significant difference between the two
  latency recording techniques, wrk2 also tracks an internal "uncorrected
  latency histogram" that can be reported on using the --u_latency flag.
  The following chart depicts the differences between the correct and
  the "uncorrected" percentile distributions measured during wrk2 runs.
  (The "uncorrected" distributions are labeled with "CO", for Coordinated
  Omission)
  
  ![CO example]
  
  These differences can be seen in detail in the output provided when 
  the --u_latency flag is used. For example, the output below demonstrates
  the difference in recorded latency distribution for two runs:

  The first ["Example 1" below] is a relatively "quiet" run with no large
  outliers (the worst case seen was 11msec), and even wit the 99'%ile exhibit
  a ~2x ratio between wrk2's latency measurement and that of an uncorrected
  latency scheme.

  The second run ["Example 2" below] includes a single small (1.4sec)
  disruption (introduced using ^Z on the apache process for simple effect).
  As can be seen in the output, there is a dramatic difference between the
  reported percentiles in the two measurement techniques, with wrk2's latency
  report [correctly] reporting a 99%'ile that is 200x (!!!) larger than that
  of the traditional measurement technique that was susceptible to Coordinated
  Omission.

************************************************************************
************************************************************************
