// Copyright (C) 2012 - Will Glozer.  All rights reserved.

#include <inttypes.h>
#include <stdlib.h>
#include <math.h>

#include "stats.h"
#include "zmalloc.h"

stats *stats_alloc(uint64_t samples) {
    stats *s = zcalloc(sizeof(stats) + sizeof(uint64_t) * samples);
    s->samples = samples;
    s->min     = UINT64_MAX;
    s->histogram = NULL;
    return s;
}

void stats_free(stats *stats) {
    zfree(stats);
}

void stats_reset(stats *stats) {
    stats->limit = 0;
    stats->index = 0;
    stats->min   = UINT64_MAX;
    stats->max   = 0;
}

void stats_rewind(stats *stats) {
    stats->limit = 0;
    stats->index = 0;
}

void stats_record(stats *stats, uint64_t x) {
    if (x < stats->min) stats->min = x;
    if (x > stats->max) stats->max = x;
    if (stats->histogram != NULL) {
        hdr_record_value(stats->histogram, x);
        return;
    }

    stats->data[stats->index++] = x;
    if (stats->limit < stats->samples)  stats->limit++;
    if (stats->index == stats->samples) stats->index = 0;
}

static int stats_compare(const void *a, const void *b) {
    uint64_t *x = (uint64_t *) a;
    uint64_t *y = (uint64_t *) b;
    return *x - *y;
}

long double stats_summarize(stats *stats) {
    qsort(stats->data, stats->limit, sizeof(uint64_t), &stats_compare);
    return stats_mean(stats);
}

long double stats_mean(stats *stats) {
    if (stats->histogram != NULL) {
        return hdr_mean(stats->histogram);
    }
    if (stats->limit == 0) return 0.0;

    uint64_t sum = 0;
    for (uint64_t i = 0; i < stats->limit; i++) {
        sum += stats->data[i];
    }
    return sum / (long double) stats->limit;
}

long double stats_stdev(stats *stats, long double mean) {
    if (stats->histogram != NULL) {
        return hdr_stddev(stats->histogram);
    }
    long double sum = 0.0;
    if (stats->limit < 2) return 0.0;
    for (uint64_t i = 0; i < stats->limit; i++) {
        sum += powl(stats->data[i] - mean, 2);
    }
    return sqrtl(sum / (stats->limit - 1));
}

long double stats_within_stdev(stats *stats, long double mean, long double stdev, uint64_t n) {
    long double upper = mean + (stdev * n);
    long double lower = mean - (stdev * n);
    if (stats->histogram != NULL) {
        int64_t total_count = stats->histogram->total_count;
        if (total_count == 0) {
            return 0.0;
        }
        int64_t upper_value = upper;
        int64_t lower_value = lower;
        struct hdr_iter iter;
        hdr_iter_init(&iter, stats->histogram);
        int64_t lower_count = 0;
        int64_t upper_count = 0;
        bool found_upper = false;
        while (hdr_iter_next(&iter)) {
            if (lower_value > iter.value_from_index) {
                lower_count = iter.count_to_index;
            }
            if (upper_value < iter.highest_equivalent_value) {
                upper_count = iter.count_to_index;
                found_upper = true;
                break;
            }
        }
        if (!found_upper) {
            upper_count = total_count;
        }
        return 100.0 * (upper_count - lower_count) / (double) total_count;
    }
    uint64_t sum = 0;

    for (uint64_t i = 0; i < stats->limit; i++) {
        uint64_t x = stats->data[i];
        if (x >= lower && x <= upper) sum++;
    }

    return (sum / (long double) stats->limit) * 100;
}

uint64_t stats_percentile(stats *stats, long double p) {
    if (stats->histogram != NULL) {
        double percentile = p;
        int64_t value = hdr_value_at_percentile(stats->histogram, percentile);
        return (value < 0) ? 0 : value;
    }
    uint64_t rank = round((p / 100.0) * stats->limit + 0.5);
    return stats->data[rank - 1];
}

void stats_sample(stats *dst, tinymt64_t *state, uint64_t count, stats *src) {
    for (uint64_t i = 0; i < count; i++) {
        uint64_t n = rand64(state, src->limit);
        stats_record(dst, src->data[n]);
    }
}

uint64_t rand64(tinymt64_t *state, uint64_t n) {
    uint64_t x, max = ~UINT64_C(0);
    max -= max % n;
    do {
        x = tinymt64_generate_uint64(state);
    } while (x >= max);
    return x % n;
}
