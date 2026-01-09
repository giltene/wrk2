CFLAGS  := -std=c99 -Wall -O2 -D_REENTRANT
LIBS    := -lpthread -lm -lcrypto -lssl

TARGET  := $(shell uname -s | tr '[A-Z]' '[a-z]' 2>/dev/null || echo unknown)

ifeq ($(TARGET), sunos)
	CFLAGS += -D_PTHREADS -D_POSIX_C_SOURCE=200112L
	LIBS   += -lsocket
else ifeq ($(TARGET), darwin)
	# Per https://luajit.org/install.html: If MACOSX_DEPLOYMENT_TARGET
	# is not set then it's forced to 10.4, which breaks compile on Mojave.
	export MACOSX_DEPLOYMENT_TARGET = $(shell sw_vers -productVersion)
	LDFLAGS += -pagezero_size 10000 -image_base 100000000
	# OpenSSL: try pkg-config, fall back to user-specified OPENSSL_INC/OPENSSL_LIB
	OPENSSL_CFLAGS := $(or $(shell pkg-config --cflags openssl 2>/dev/null), -I$(OPENSSL_INC))
	OPENSSL_LIBS   := $(or $(shell pkg-config --libs openssl 2>/dev/null), -L$(OPENSSL_LIB) -lcrypto -lssl)
	CFLAGS += $(OPENSSL_CFLAGS)
	LIBS   += $(OPENSSL_LIBS)
else ifeq ($(TARGET), linux)
        CFLAGS  += -D_POSIX_C_SOURCE=200809L -D_BSD_SOURCE
	LIBS    += -ldl
	LDFLAGS += -Wl,-E
else ifeq ($(TARGET), freebsd)
	CFLAGS  += -D_DECLARE_C99_LDBL_MATH
	LDFLAGS += -Wl,-E
endif

SRC  := wrk.c net.c ssl.c aprintf.c stats.c script.c units.c \
		ae.c zmalloc.c http_parser.c tinymt64.c hdr_histogram.c
BIN  := wrk

ODIR := obj
OBJ  := $(patsubst %.c,$(ODIR)/%.o,$(SRC)) $(ODIR)/bytecode.o

# LuaJIT configuration
# Use system LuaJIT instead of bundled: make USE_SYSTEM_LUAJIT=1
# With pkg-config (auto-detects paths): make USE_SYSTEM_LUAJIT=1
# With manual paths: make USE_SYSTEM_LUAJIT=1 LUAJIT_INC=/path/to/include LUAJIT_LIB=/path/to/lib
ifdef USE_SYSTEM_LUAJIT
    # Try pkg-config first, fall back to user-specified paths
    LUAJIT_CFLAGS := $(or $(shell pkg-config --cflags luajit 2>/dev/null), -I$(LUAJIT_INC))
    LUAJIT_LIBS   := $(or $(shell pkg-config --libs luajit 2>/dev/null), -L$(LUAJIT_LIB) -lluajit-5.1)
    LUAJIT_BIN    ?= luajit
    CFLAGS  += $(LUAJIT_CFLAGS)
    LIBS    := $(LUAJIT_LIBS) $(LIBS)
else
    LDIR     = deps/luajit/src
    LIBS    := -lluajit $(LIBS)
    CFLAGS  += -I$(LDIR)
    LDFLAGS += -L$(LDIR)
endif

all: $(BIN)

clean:
	$(RM) $(BIN) obj/*
ifndef USE_SYSTEM_LUAJIT
	@$(MAKE) -C deps/luajit clean
endif

$(BIN): $(OBJ)
	@echo LINK $(BIN)
	@$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

ifdef USE_SYSTEM_LUAJIT
$(OBJ): config.h Makefile | $(ODIR)
else
$(OBJ): config.h Makefile $(LDIR)/libluajit.a | $(ODIR)
endif

$(ODIR):
	@mkdir -p $@

$(ODIR)/bytecode.o: src/wrk.lua
	@echo LUAJIT $<
ifdef USE_SYSTEM_LUAJIT
	@$(LUAJIT_BIN) -b $< $@
else
	@$(SHELL) -c 'cd $(LDIR) && ./luajit -b $(CURDIR)/$< $(CURDIR)/$@'
endif

$(ODIR)/%.o : %.c
	@echo CC $<
	@$(CC) $(CFLAGS) -c -o $@ $<

ifndef USE_SYSTEM_LUAJIT
$(LDIR)/libluajit.a:
	@echo Building LuaJIT...
	@$(MAKE) -C $(LDIR) BUILDMODE=static
endif

.PHONY: all clean
.SUFFIXES:
.SUFFIXES: .c .o .lua

vpath %.c   src
vpath %.h   src
vpath %.lua scripts
