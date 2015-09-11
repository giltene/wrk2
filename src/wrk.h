#ifndef WRK_H
#define WRK_H

#include "config.h"
#include <pthread.h>
#include <inttypes.h>
#include <sys/types.h>
#include <netdb.h>
#include <sys/socket.h>

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <lua.h>

#include "stats.h"
#include "ae.h"
#include "http_parser.h"
#include "hdr_histogram.h"

#define VERSION  "3.1.1"
#define RECVBUF  8192
#define SAMPLES  100000000

#define SOCKET_TIMEOUT_MS   2000
#define CALIBRATE_DELAY_MS  10000
#define TIMEOUT_INTERVAL_MS 2000

typedef struct {
    pthread_t thread;
    aeEventLoop *loop;
    struct addrinfo *addr;
    uint64_t connections;
    int interval;
    uint64_t stop_at;
    uint64_t complete;
    uint64_t requests;
    uint64_t bytes;
    uint64_t start;
    double throughput;
    uint64_t mean;
    struct hdr_histogram *latency_histogram;
    struct hdr_histogram *u_latency_histogram;
    tinymt64_t rand;
    lua_State *L;
    errors errors;
    struct connection *cs;
} thread;

typedef struct {
    char  *buffer;
    size_t length;
    char  *cursor;
} buffer;

typedef struct connection {
    thread *thread;
    http_parser parser;
    enum {
        FIELD, VALUE
    } state;
    int fd;
    SSL *ssl;
    double throughput;
    double catch_up_throughput;
    uint64_t complete;
    uint64_t complete_at_last_batch_start;
    uint64_t catch_up_start_time;
    uint64_t complete_at_catch_up_start;
    uint64_t thread_start;
    uint64_t start;
    char *request;
    size_t length;
    size_t written;
    uint64_t pending;
    buffer headers;
    buffer body;
    char buf[RECVBUF];
    uint64_t actual_latency_start;
    bool has_pending;
    bool caught_up;
    // Internal tracking numbers (used purely for debugging):
    uint64_t latest_should_send_time;
    uint64_t latest_expected_start;
    uint64_t latest_connect;
    uint64_t latest_write;
} connection;

#endif /* WRK_H */
