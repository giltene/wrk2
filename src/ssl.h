#ifndef SSL_H
#define SSL_H

#include "net.h"

#ifdef KOAL_SSL_EXTENSION
SSL_CTX *ssl_init(char *, char *, char *, char*, char*);
#else /* KOAL_SSL_EXTENSION */
SSL_CTX *ssl_init(char *, char *, char*, char*);
#endif /* KOAL_SSL_EXTENSION */

status ssl_set_cipher_list(SSL_CTX *, char *);
status ssl_connect(connection *, char *);
status ssl_close(connection *);
status ssl_read(connection *, size_t *);
status ssl_write(connection *, char *, size_t, size_t *);
size_t ssl_readable(connection *);

#endif /* SSL_H */
