# wrk2
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/giltene/wrk2?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

  **a HTTP benchmarking tool based mostly on wrk**

  wrk2 is wrk modifed to produce a constant throughput load, and
  accurate latency details to the high 9s (i.e. can produce
  accurate 99.9999%'ile when run long enough). In addition to
  wrk's arguments, wrk2 takes a throughput argument (in total requests
  per second) via either the --rate or -R parameters (default
  is 1000).

  CRITICAL NOTE: Before going farther, I'd like to make it clear that
  this work is in no way intended to be an attack on or a disparagement
  of the great work that Will Glozer has done with wrk. I enjoyed working
  with his code, and I sincerely hope that some of the changes I had made
  might be considered for inclusion back into wrk. As those of you who may
  be familiar with my latency related talks and rants, the latency
  measurement issues that I focused on fixing with wrk2 are extremely
  common in load generators and in monitoring code. I do not
  ascribe any lack of skill or intelligence to people who's creations
  repeat them. I was once (as recently as 2-3 years ago) just as
  oblivious to the effects of Coordinated Omission as the rest of
  the world still is.

  wrk2 replaces wrk's individual request sample buffers with
  HdrHistograms. wrk2 maintains wrk's Lua API, including it's
  presentation of the stats objects (latency and requests). The stats
  objects are "emulated" using HdrHistograms. E.g. a request for a
  raw sample value at index i (see latency[i] below) will return
  the value at the associated percentile (100.0 * i / __len).

  As a result of using HdrHistograms for full (lossless) recording,
  constant throughput load generation, and accurate tracking of
  response latency (from the point in time where a request was supposed
  to be sent per the "plan" to the time that it actually arrived), wrk2's
  latency reporting is significantly more accurate (as in "correct") than
  that of wrk's current (Nov. 2014) execution model.

  It is important to note that in wrk2's current constant-throughput
  implementation, measured latencies are [only] accurate to a +/- ~1 msec
  granularity, due to OS sleep time behavior.

  wrk2 is currently in experimental/development mode, and may well be
  merged into wrk in the future if others see fit to adopt it's changes.

  The remaining part of the README is wrk's, with minor changes to
  reflect additional parameter and output. There is an important and
  detailed note at the end about about wrk2's latency measurement
  technique, including a discussion of Coordinated Omission, how
  wrk2 avoids it, and detailed output that demonstrates it.

  wrk2 (as is wrk) is a modern HTTP benchmarking tool capable of generating
  significant load when run on a single multi-core CPU. It combines a
  multithreaded design with scalable event notification systems such as
  epoll and kqueue.

  An optional LuaJIT script can perform HTTP request generation, response
  processing, and custom reporting. Several example scripts are located in
  scripts/

## Basic Usage

    wrk -t2 -c100 -d30s -R2000 http://127.0.0.1:8080/index.html

  This runs a benchmark for 30 seconds, using 2 threads, keeping
  100 HTTP connections open, and a constant throughput of 2000 requests
  per second (total, across all connections combined).

  [It's important to note that wrk2 extends the initial calibration
   period to 10 seconds (from wrk's 0.5 second), so runs shorter than
   10-20 seconds may not present useful information]

  Output:

    Running 30s test @ http://127.0.0.1:80/index.html
      2 threads and 100 connections
      Thread calibration: mean lat.: 9747 usec, rate sampling interval: 21 msec
      Thread calibration: mean lat.: 9631 usec, rate sampling interval: 21 msec
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency     6.46ms    1.93ms  12.34ms   67.66%
        Req/Sec     1.05k     1.12k    2.50k    64.84%
      60017 requests in 30.01s, 19.81MB read
    Requests/sec:   2000.15
    Transfer/sec:    676.14KB

  However, wrk2 will usually be run with the --latency flag, which provides
  detailed latency percentile information (in a format that can be easily
  imported to spreadsheets or gnuplot scripts and plotted per examples
  provided at http://hdrhistogram.org):

    wrk -t2 -c100 -d30s -R2000 --latency http://127.0.0.1:80/index.html

  Output:

    Running 30s test @ http://127.0.0.1:80/index.html
      2 threads and 100 connections
      Thread calibration: mean lat.: 10087 usec, rate sampling interval: 22 msec
      Thread calibration: mean lat.: 10139 usec, rate sampling interval: 21 msec
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency     6.60ms    1.92ms  12.50ms   68.46%
        Req/Sec     1.04k     1.08k    2.50k    72.79%
      Latency Distribution (HdrHistogram - Recorded Latency)
     50.000%    6.67ms
     75.000%    7.78ms
     90.000%    9.14ms
     99.000%   11.18ms
     99.900%   12.30ms
     99.990%   12.45ms
     99.999%   12.50ms
    100.000%   12.50ms
  
    Detailed Percentile spectrum:
         Value   Percentile   TotalCount 1/(1-Percentile)
         
         0.921     0.000000            1         1.00 
         4.053     0.100000         3951         1.11
         4.935     0.200000         7921         1.25
         5.627     0.300000        11858         1.43
         6.179     0.400000        15803         1.67
         6.671     0.500000        19783         2.00
         6.867     0.550000        21737         2.22
         7.079     0.600000        23733         2.50
         7.287     0.650000        25698         2.86
         7.519     0.700000        27659         3.33
         7.783     0.750000        29644         4.00
         7.939     0.775000        30615         4.44
         8.103     0.800000        31604         5.00
         8.271     0.825000        32597         5.71
         8.503     0.850000        33596         6.67
         8.839     0.875000        34571         8.00
         9.015     0.887500        35070         8.89
         9.143     0.900000        35570        10.00
         9.335     0.912500        36046        11.43
         9.575     0.925000        36545        13.33
         9.791     0.937500        37032        16.00
         9.903     0.943750        37280        17.78
        10.015     0.950000        37543        20.00
        10.087     0.956250        37795        22.86
        10.167     0.962500        38034        26.67
        10.279     0.968750        38268        32.00
        10.343     0.971875        38390        35.56
        10.439     0.975000        38516        40.00
        10.535     0.978125        38636        45.71
        10.647     0.981250        38763        53.33
        10.775     0.984375        38884        64.00
        10.887     0.985938        38951        71.11
        11.007     0.987500        39007        80.00
        11.135     0.989062        39070        91.43
        11.207     0.990625        39135       106.67
        11.263     0.992188        39193       128.00
        11.303     0.992969        39226       142.22
        11.335     0.993750        39255       160.00
        11.367     0.994531        39285       182.86
        11.399     0.995313        39319       213.33
        11.431     0.996094        39346       256.00
        11.455     0.996484        39365       284.44
        11.471     0.996875        39379       320.00
        11.495     0.997266        39395       365.71
        11.535     0.997656        39408       426.67
        11.663     0.998047        39423       512.00
        11.703     0.998242        39431       568.89
        11.743     0.998437        39439       640.00
        11.807     0.998633        39447       731.43
        12.271     0.998828        39454       853.33
        12.311     0.999023        39463      1024.00
        12.327     0.999121        39467      1137.78
        12.343     0.999219        39470      1280.00
        12.359     0.999316        39473      1462.86
        12.375     0.999414        39478      1706.67
        12.391     0.999512        39482      2048.00
        12.399     0.999561        39484      2275.56
        12.407     0.999609        39486      2560.00
        12.415     0.999658        39489      2925.71
        12.415     0.999707        39489      3413.33
        12.423     0.999756        39491      4096.00
        12.431     0.999780        39493      4551.11
        12.431     0.999805        39493      5120.00
        12.439     0.999829        39495      5851.43
        12.439     0.999854        39495      6826.67
        12.447     0.999878        39496      8192.00
        12.447     0.999890        39496      9102.22
        12.455     0.999902        39497     10240.00
        12.455     0.999915        39497     11702.86
        12.463     0.999927        39498     13653.33
        12.463     0.999939        39498     16384.00
        12.463     0.999945        39498     18204.44
        12.479     0.999951        39499     20480.00
        12.479     0.999957        39499     23405.71
        12.479     0.999963        39499     27306.67
        12.479     0.999969        39499     32768.00
        12.479     0.999973        39499     36408.89
        12.503     0.999976        39500     40960.00
        12.503     1.000000        39500          inf
    #[Mean    =        6.602, StdDeviation   =        1.919]
    #[Max     =       12.496, Total count    =        39500]
    #[Buckets =           27, SubBuckets     =         2048]
    ----------------------------------------------------------
    60018 requests in 30.00s, 19.81MB read
    Requests/sec:   2000.28
    Transfer/sec:    676.18KB


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

Example 1: [short, non-noisy run (~11msec worst observed latency)]:

    wrk -t2 -c100 -d30s -R2000 --u_latency http://127.0.0.1:80/index.html
 
    Running 30s test @ http://127.0.0.1:80/index.html
      2 threads and 100 connections
      Thread calibration: mean lat.: 9319 usec, rate sampling interval: 21 msec
      Thread calibration: mean lat.: 9332 usec, rate sampling interval: 21 msec
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency     6.18ms    1.84ms  11.31ms   69.23%
        Req/Sec     1.05k     1.11k    2.50k    64.57%
      Latency Distribution (HdrHistogram - Recorded Latency)
     50.000%    6.21ms
     75.000%    7.37ms
     90.000%    8.46ms
     99.000%   10.52ms
     99.900%   11.19ms
     99.990%   11.29ms
     99.999%   11.32ms
    100.000%   11.32ms
   
      Detailed Percentile spectrum:
           Value   Percentile   TotalCount 1/(1-Percentile)
 
           0.677     0.000000            1         1.00
           3.783     0.100000         3952         1.11
           4.643     0.200000         7924         1.25
           5.263     0.300000        11866         1.43
           5.815     0.400000        15834         1.67
           6.207     0.500000        19783         2.00
           6.399     0.550000        21728         2.22
           6.639     0.600000        23702         2.50
           6.867     0.650000        25694         2.86
           7.095     0.700000        27664         3.33
           7.367     0.750000        29629         4.00
           7.499     0.775000        30615         4.44
           7.623     0.800000        31605         5.00
           7.763     0.825000        32599         5.71
           7.943     0.850000        33578         6.67
           8.183     0.875000        34570         8.00
           8.303     0.887500        35084         8.89
           8.463     0.900000        35566        10.00
           8.647     0.912500        36050        11.43
           8.911     0.925000        36559        13.33
           9.119     0.937500        37038        16.00
           9.279     0.943750        37289        17.78
           9.415     0.950000        37530        20.00
           9.559     0.956250        37776        22.86
           9.719     0.962500        38025        26.67
           9.919     0.968750        38267        32.00
          10.015     0.971875        38390        35.56
          10.103     0.975000        38514        40.00
          10.175     0.978125        38645        45.71
          10.239     0.981250        38772        53.33
          10.319     0.984375        38889        64.00
          10.375     0.985938        38953        71.11
          10.423     0.987500        39014        80.00
          10.479     0.989062        39070        91.43
          10.535     0.990625        39131       106.67
          10.591     0.992188        39199       128.00
          10.615     0.992969        39235       142.22
          10.631     0.993750        39255       160.00
          10.663     0.994531        39284       182.86
          10.703     0.995313        39318       213.33
          10.759     0.996094        39346       256.00
          10.823     0.996484        39363       284.44
          10.863     0.996875        39378       320.00
          10.919     0.997266        39392       365.71
          11.015     0.997656        39409       426.67
          11.079     0.998047        39423       512.00
          11.111     0.998242        39433       568.89
          11.127     0.998437        39439       640.00
          11.159     0.998633        39449       731.43
          11.167     0.998828        39454       853.33
          11.191     0.999023        39463      1024.00
          11.207     0.999121        39468      1137.78
          11.215     0.999219        39471      1280.00
          11.223     0.999316        39473      1462.86
          11.231     0.999414        39479      1706.67
          11.239     0.999512        39481      2048.00
          11.247     0.999561        39483      2275.56
          11.255     0.999609        39487      2560.00
          11.255     0.999658        39487      2925.71
          11.263     0.999707        39489      3413.33
          11.271     0.999756        39492      4096.00
          11.271     0.999780        39492      4551.11
          11.279     0.999805        39495      5120.00
          11.279     0.999829        39495      5851.43
          11.279     0.999854        39495      6826.67
          11.287     0.999878        39497      8192.00
          11.287     0.999890        39497      9102.22
          11.287     0.999902        39497     10240.00
          11.287     0.999915        39497     11702.86
          11.295     0.999927        39499     13653.33
          11.295     0.999939        39499     16384.00
          11.295     0.999945        39499     18204.44
          11.295     0.999951        39499     20480.00
          11.295     0.999957        39499     23405.71
          11.295     0.999963        39499     27306.67
          11.295     0.999969        39499     32768.00
          11.295     0.999973        39499     36408.89
          11.319     0.999976        39500     40960.00
          11.319     1.000000        39500          inf
    #[Mean    =        6.178, StdDeviation   =        1.836]
    #[Max     =       11.312, Total count    =        39500]
    #[Buckets =           27, SubBuckets     =         2048]
    ----------------------------------------------------------
 
      Latency Distribution (HdrHistogram - Uncorrected Latency (measured without taking delayed starts into account))
     50.000%    2.68ms 
     75.000%    3.71ms
     90.000%    4.47ms
     99.000%    5.43ms
     99.900%    6.69ms
     99.990%    6.99ms
     99.999%    7.01ms
    100.000%    7.01ms
 
      Detailed Percentile spectrum:
           Value   Percentile   TotalCount 1/(1-Percentile)
 
           0.264     0.000000            1         1.00
           1.111     0.100000         3954         1.11
           1.589     0.200000         7909         1.25
           1.970     0.300000        11852         1.43
           2.327     0.400000        15801         1.67
           2.679     0.500000        19751         2.00
           2.847     0.550000        21749         2.22
           3.003     0.600000        23703         2.50
           3.207     0.650000        25684         2.86
           3.483     0.700000        27664         3.33
           3.709     0.750000        29645         4.00
           3.813     0.775000        30623         4.44
           3.915     0.800000        31600         5.00
           4.035     0.825000        32591         5.71
           4.183     0.850000        33597         6.67
           4.319     0.875000        34580         8.00
           4.391     0.887500        35067         8.89
           4.471     0.900000        35561        10.00
           4.575     0.912500        36051        11.43
           4.683     0.925000        36545        13.33
           4.827     0.937500        37040        16.00
           4.903     0.943750        37296        17.78
           4.975     0.950000        37535        20.00
           5.035     0.956250        37779        22.86
           5.091     0.962500        38023        26.67
           5.159     0.968750        38281        32.00
           5.195     0.971875        38394        35.56
           5.231     0.975000        38520        40.00
           5.267     0.978125        38638        45.71
           5.311     0.981250        38767        53.33
           5.351     0.984375        38889        64.00
           5.375     0.985938        38957        71.11
           5.391     0.987500        39011        80.00
           5.415     0.989062        39076        91.43
           5.443     0.990625        39133       106.67
           5.519     0.992188        39193       128.00
           5.571     0.992969        39224       142.22
           5.671     0.993750        39254       160.00
           5.843     0.994531        39284       182.86
           5.915     0.995313        39315       213.33
           6.019     0.996094        39346       256.00
           6.087     0.996484        39362       284.44
           6.135     0.996875        39377       320.00
           6.323     0.997266        39392       365.71
           6.423     0.997656        39408       426.67
           6.471     0.998047        39423       512.00
           6.507     0.998242        39431       568.89
           6.535     0.998437        39439       640.00
           6.587     0.998633        39448       731.43
           6.643     0.998828        39454       853.33
           6.699     0.999023        39463      1024.00
           6.847     0.999121        39466      1137.78
           6.883     0.999219        39471      1280.00
           6.891     0.999316        39475      1462.86
           6.899     0.999414        39479      1706.67
           6.911     0.999512        39482      2048.00
           6.927     0.999561        39483      2275.56
           6.935     0.999609        39486      2560.00
           6.947     0.999658        39488      2925.71
           6.951     0.999707        39489      3413.33
           6.979     0.999756        39491      4096.00
           6.983     0.999780        39494      4551.11
           6.983     0.999805        39494      5120.00  
           6.983     0.999829        39494      5851.43
           6.987     0.999854        39496      6826.67
           6.987     0.999878        39496      8192.00
           6.987     0.999890        39496      9102.22
           6.995     0.999902        39497     10240.00
           6.995     0.999915        39497     11702.86
           7.007     0.999927        39499     13653.33
           7.007     0.999939        39499     16384.00
           7.007     0.999945        39499     18204.44
           7.007     0.999951        39499     20480.00
           7.007     0.999957        39499     23405.71
           7.007     0.999963        39499     27306.67
           7.007     0.999969        39499     32768.00
           7.007     0.999973        39499     36408.89
           7.015     0.999976        39500     40960.00
           7.015     1.000000        39500          inf
    #[Mean    =        2.757, StdDeviation   =        1.254]
    #[Max     =        7.012, Total count    =        39500]
    #[Buckets =           27, SubBuckets     =         2048]
    ----------------------------------------------------------
      60031 requests in 30.01s, 19.82MB read
    Requests/sec:   2000.67
    Transfer/sec:    676.32KB


************************************************************************
************************************************************************

Example 2: [1.4 second ^Z artifact introduced on the httpd server]:
 
    wrk -t2 -c100 -d30s -R2000 --u_latency http://127.0.0.1:80/index.html
 
    Running 30s test @ http://127.0.0.1:80/index.html
      2 threads and 100 connections
      Thread calibration: mean lat.: 108237 usec, rate sampling interval: 1021 msec
      Thread calibration: mean lat.: 108178 usec, rate sampling interval: 1021 msec
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency    63.66ms  223.37ms   1.42s    93.67%
        Req/Sec     1.00k   231.13     1.71k    89.47%
      Latency Distribution (HdrHistogram - Recorded Latency)
     50.000%    8.61ms
     75.000%   10.47ms
     90.000%   11.77ms
     99.000%    1.27s
     99.900%    1.42s
     99.990%    1.42s
     99.999%    1.42s
    100.000%    1.42s
 
      Detailed Percentile spectrum:
           Value   Percentile   TotalCount 1/(1-Percentile)
 
           1.317     0.000000            1         1.00
           5.011     0.100000         3954         1.11
           6.215     0.200000         7903         1.25
           7.091     0.300000        11866         1.43
           7.827     0.400000        15810         1.67
           8.615     0.500000        19758         2.00
           8.991     0.550000        21734         2.22
           9.407     0.600000        23715         2.50
           9.871     0.650000        25713         2.86
          10.183     0.700000        27704         3.33
          10.471     0.750000        29648         4.00
          10.687     0.775000        30627         4.44
          10.903     0.800000        31604         5.00
          11.103     0.825000        32622         5.71
          11.295     0.850000        33583         6.67
          11.495     0.875000        34570         8.00
          11.615     0.887500        35067         8.89
          11.775     0.900000        35552        10.00
          12.047     0.912500        36048        11.43
          62.079     0.925000        36540        13.33
         294.399     0.937500        37054        16.00
         390.655     0.943750        37286        17.78
         524.799     0.950000        37525        20.00
         621.567     0.956250        37782        22.86
         760.831     0.962500        38062        26.67
         857.087     0.968750        38300        32.00
         903.679     0.971875        38399        35.56
         993.279     0.975000        38528        40.00
        1042.943     0.978125        38658        45.71
        1089.535     0.981250        38765        53.33
        1136.639     0.984375        38886        64.00
        1182.719     0.985938        38961        71.11
        1228.799     0.987500        39033        80.00
        1231.871     0.989062        39100        91.43
        1276.927     0.990625        39141       106.67
        1278.975     0.992188        39200       128.00
        1325.055     0.992969        39300       142.22
        1325.055     0.993750        39300       160.00
        1325.055     0.994531        39300       182.86
        1371.135     0.995313        39323       213.33
        1372.159     0.996094        39400       256.00
        1372.159     0.996484        39400       284.44
        1372.159     0.996875        39400       320.00
        1372.159     0.997266        39400       365.71
        1417.215     0.997656        39500       426.67
        1417.215     1.000000        39500          inf
    #[Mean    =       63.660, StdDeviation   =      223.370]
    #[Max     =     1416.192, Total count    =        39500]
    #[Buckets =           27, SubBuckets     =         2048]
    ----------------------------------------------------------

      Latency Distribution (HdrHistogram - Uncorrected Latency (measured without taking delayed starts into account))
     50.000%    3.02ms
     75.000%    3.91ms
     90.000%    4.87ms
     99.000%    6.04ms
     99.900%    1.41s
     99.990%    1.41s
     99.999%    1.41s
    100.000%    1.41s

      Detailed Percentile spectrum:
           Value   Percentile   TotalCount 1/(1-Percentile)

           0.325     0.000000            1         1.00
           1.210     0.100000         3950         1.11
           1.819     0.200000         7905         1.25
           2.343     0.300000        11851         1.43
           2.737     0.400000        15809         1.67
           3.015     0.500000        19760         2.00
           3.153     0.550000        21738         2.22
           3.289     0.600000        23722         2.50
           3.459     0.650000        25698         2.86
           3.691     0.700000        27650         3.33
           3.915     0.750000        29630         4.00
           4.053     0.775000        30621         4.44
           4.175     0.800000        31624         5.00
           4.299     0.825000        32612         5.71
           4.423     0.850000        33599         6.67
           4.587     0.875000        34564         8.00
           4.735     0.887500        35057         8.89
           4.871     0.900000        35560        10.00 
           4.975     0.912500        36051        11.43
           5.063     0.925000        36543        13.33 
           5.143     0.937500        37039        16.00
           5.187     0.943750        37282        17.78
           5.239     0.950000        37533        20.00
           5.291     0.956250        37782        22.86
           5.347     0.962500        38024        26.67
           5.435     0.968750        38278        32.00
           5.487     0.971875        38392        35.56
           5.555     0.975000        38514        40.00
           5.635     0.978125        38642        45.71
           5.735     0.981250        38760        53.33
           5.863     0.984375        38885        64.00
           5.899     0.985938        38946        71.11
           5.955     0.987500        39007        80.00
           6.019     0.989062        39071        91.43
           6.067     0.990625        39133       106.67
           6.127     0.992188        39194       128.00
           6.187     0.992969        39223       142.22
           6.287     0.993750        39255       160.00
           6.347     0.994531        39284       182.86
           6.411     0.995313        39315       213.33
           6.487     0.996094        39346       256.00
           6.539     0.996484        39362       284.44
           6.591     0.996875        39379       320.00
           6.711     0.997266        39392       365.71
        1413.119     0.997656        39411       426.67
        1414.143     0.998047        39500       512.00
        1414.143     1.000000        39500          inf
    #[Mean    =        6.588, StdDeviation   =       70.891]
    #[Max     =     1413.120, Total count    =        39500]
    #[Buckets =           27, SubBuckets     =         2048]
    ----------------------------------------------------------
      60055 requests in 30.01s, 19.83MB read
    Requests/sec:   2001.42
    Transfer/sec:    676.57KB

[CO example]:https://raw.github.com/giltene/wrk2/master/CoordinatedOmission/wrk2_CleanVsCO.png "Coordinated Omission example"
