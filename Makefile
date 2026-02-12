# B2M - Bytes to MIDI Converter Makefile
# Targets: all, arm64, arm32, debug, clean, install, uninstall, test

CC = gcc
PREFIX ?= /data/data/com.termux/files/usr
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
SRCDIR = src
OBJDIR = obj
BINARY = b2m

# Source files
SRCS = $(SRCDIR)/bytes_to_midi.c $(SRCDIR)/main.c
OBJS = $(OBJDIR)/bytes_to_midi.o $(OBJDIR)/main.o

# Common flags
COMMON_CFLAGS = -Wall -Wextra -Wpedantic -pthread -D_POSIX_C_SOURCE=200809L
COMMON_LDFLAGS = -lpthread -lm

# Default build - auto-detect architecture
all: CFLAGS = $(COMMON_CFLAGS) -O3 -flto -fomit-frame-pointer -fPIE -DNDEBUG
all: LDFLAGS = $(COMMON_LDFLAGS) -flto -pie
all: check_arch $(OBJDIR) $(BINARY)

# ARM64 optimized build
arm64: CFLAGS = $(COMMON_CFLAGS) -O3 -march=armv8-a -mtune=cortex-a53 -flto \
                -fomit-frame-pointer -fPIE -DNDEBUG -D__ARM_NEON
arm64: LDFLAGS = $(COMMON_LDFLAGS) -flto -pie
arm64: $(OBJDIR) $(BINARY)

# ARM32 NEON build
arm32: CFLAGS = $(COMMON_CFLAGS) -O3 -march=armv7-a -mfpu=neon -mtune=cortex-a7 \
                -flto -fomit-frame-pointer -fPIE -DNDEBUG -D__ARM_NEON
arm32: LDFLAGS = $(COMMON_LDFLAGS) -flto -pie
arm32: $(OBJDIR) $(BINARY)

# x86_64 build (generic)
x86_64: CFLAGS = $(COMMON_CFLAGS) -O3 -march=x86-64 -mtune=generic \
                 -flto -fomit-frame-pointer -fPIE -DNDEBUG
x86_64: LDFLAGS = $(COMMON_LDFLAGS) -flto -pie
x86_64: $(OBJDIR) $(BINARY)

# Debug build
debug: CFLAGS = $(COMMON_CFLAGS) -O0 -g -DDEBUG
debug: LDFLAGS = $(COMMON_LDFLAGS)
debug: $(OBJDIR) $(BINARY)

# Static build (no runtime dependencies)
static: CFLAGS = $(COMMON_CFLAGS) -O3 -static -DNDEBUG
static: LDFLAGS = $(COMMON_LDFLAGS) -static
static: $(OBJDIR) $(BINARY)

# Architecture detection
check_arch:
	@echo "Detecting architecture..."
	@if [ "$(shell uname -m)" = "aarch64" ] || [ "$(shell uname -m)" = "arm64" ]; then \
		echo "ARM64 detected, using optimized flags"; \
		$(MAKE) arm64 --no-print-directory; \
		exit 0; \
	elif [ "$(shell uname -m)" = "armv7l" ] || [ "$(shell uname -m)" = "armhf" ]; then \
		echo "ARM32 detected, using NEON flags"; \
		$(MAKE) arm32 --no-print-directory; \
		exit 0; \
	else \
		echo "$(shell uname -m) detected, using generic flags"; \
		$(MAKE) x86_64 --no-print-directory; \
		exit 0; \
	fi

$(OBJDIR):
	@mkdir -p $(OBJDIR)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@echo " CC $<"
	@$(CC) $(CFLAGS) -c $< -o $@

$(BINARY): $(OBJS)
	@echo " LD $@"
	@$(CC) $(OBJS) $(LDFLAGS) -o $@
	@echo " ✓ Build complete: $(BINARY)"
	@echo "   Size: $$(wc -c < $(BINARY) | numfmt --to=iec) bytes"

install: $(BINARY)
	@echo "Installing to $(BINDIR)/$(BINARY)..."
	@mkdir -p $(BINDIR)
	@cp $(BINARY) $(BINDIR)/$(BINARY)
	@chmod 755 $(BINDIR)/$(BINARY)
	@echo " ✓ Installed: $(BINDIR)/$(BINARY)"
	@echo "   Size: $$(wc -c < $(BINDIR)/$(BINARY) | numfmt --to=iec) bytes"
	@[ ! -d "$(MANDIR)" ] || cp docs/b2m.1 $(MANDIR)/ 2>/dev/null || true

uninstall:
	@echo "Removing $(BINDIR)/$(BINARY)..."
	@rm -f $(BINDIR)/$(BINARY)
	@echo " ✓ Uninstalled"

clean:
	@echo "Cleaning..."
	@rm -rf $(OBJDIR) $(BINARY) $(BINARY)-stripped
	@echo " ✓ Clean"

distclean: clean
	@rm -f *.o *.d *.mid test.bin
	@echo " ✓ Full clean"

strip: $(BINARY)
	@echo "Stripping symbols..."
	@cp $(BINARY) $(BINARY)-stripped
	@strip $(BINARY)-stripped
	@echo " ✓ Stripped: $(BINARY)-stripped"
	@echo "   Original: $$(wc -c < $(BINARY) | numfmt --to=iec)"
	@echo "   Stripped: $$(wc -c < $(BINARY)-stripped | numfmt --to=iec)"

test: $(BINARY)
	@echo "Running tests..."
	@cd tests && ./test.sh
	@echo " ✓ Tests complete"

help:
	@echo "B2M Makefile targets:"
	@echo "  all        - Auto-detect architecture and build (default)"
	@echo "  arm64      - Build for ARM64 with Cortex-A53 optimizations"
	@echo "  arm32      - Build for ARM32 with NEON optimizations"
	@echo "  x86_64     - Build for x86_64 (generic)"
	@echo "  debug      - Build with debug symbols (-O0 -g)"
	@echo "  static     - Build static binary (no runtime dependencies)"
	@echo "  install    - Install binary to $(BINDIR)"
	@echo "  uninstall  - Remove binary from $(BINDIR)"
	@echo "  clean      - Remove object files and binary"
	@echo "  strip      - Create stripped binary"
	@echo "  test       - Run test suite"
	@echo "  help       - Show this help"

.PHONY: all arm64 arm32 x86_64 debug static install uninstall clean distclean \
        strip test help check_arch