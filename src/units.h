#ifndef UNITS_H
#define UNITS_H

#include <sys/queue.h>
#include <sched.h>

char *format_binary(long double);
char *format_metric(long double);
char *format_time_us(long double);
char *format_time_s(long double);

int scan_metric(char *, uint64_t *);
int scan_time(char *, uint64_t *);

struct aff_set {
    cpu_set_t set;
    STAILQ_ENTRY(aff_set) items;
};

STAILQ_HEAD(aff_set_head, aff_set);

int scan_affinity(char *, struct aff_set_head **);

#endif /* UNITS_H */
