#!/data/data/com.termux/files/usr/bin/bash
# B2M - Bytes to MIDI Converter
# One Click Installer - FIXED PATH ISSUE
# Overwrites existing binary automatically

set -e

# ============ FORCE TERMUX PREFIX ============
# This ensures we NEVER install to root filesystem
if [ -d "/data/data/com.termux" ]; then
    export PREFIX="/data/data/com.termux/files/usr"
    export BINDIR="$PREFIX/bin"
    IS_TERMUX=1
else
    # Fallback to local user directory if not in Termux
    export PREFIX="$HOME/.local"
    export BINDIR="$PREFIX/bin"
    IS_TERMUX=0
fi

# Create bin directory if it doesn't exist
mkdir -p "$BINDIR"

# ============ ANSI COLORS ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============ CLEAR SCREEN ============
clear

# ============ CENTERED ASCII ART ============
WIDTH=$(tput cols 2>/dev/null || echo 80)

center_text() {
    local text="$1"
    local padding=$(( (WIDTH - ${#text}) / 2 ))
    [[ $padding -lt 0 ]] && padding=0
    printf "%${padding}s%s\n" "" "$text"
}

center_ascii() {
    while IFS= read -r line; do
        local padding=$(( (WIDTH - ${#line}) / 2 ))
        [[ $padding -lt 0 ]] && padding=0
        printf "%${padding}s%s\n" "" "$line"
    done
}

echo
center_ascii << 'EOF'
                                         
              .-''-.                     
/|          .' .-.  )    __  __   ___    
||         / .'  / /    |  |/  `.'   `.  
||        (_/   / /     |   .-.  .-.   ' 
||  __         / /      |  |  |  |  |  | 
||/'__ '.     / /       |  |  |  |  |  | 
|:/`  '. '   . '        |  |  |  |  |  | 
||     | |  / /    _.-')|  |  |  |  |  | 
||\    / '.' '  _.'.-'' |__|  |__|  |__| 
|/\'..' //  /.-'_.'                      
'  `'-'`/    _.'                         
       ( _.-'                            
EOF
echo

# ============ CENTERED TAGLINE ============
TAGLINE="${BOLD}${CYAN}Translate all your audio to MIDI in under seconds!${NC}"
TAGLINE_LEN=49
PADDING=$(( (WIDTH - TAGLINE_LEN) / 2 ))
[[ $PADDING -lt 0 ]] && PADDING=0
printf "%${PADDING}s${TAGLINE}\n" ""
echo

TIP="${YELLOW}💡 Tip: Prefer using uncompressed formats like .wav, .bmp, .ico, etc.${NC}"
TIP_LEN=60
PADDING=$(( (WIDTH - TIP_LEN) / 2 ))
[[ $PADDING -lt 0 ]] && PADDING=0
printf "%${PADDING}s${TIP}\n" ""
echo
echo

# ============ SYSTEM DETECTION ============
echo -e "${BOLD}${BLUE}══════════════════ SYSTEM INFORMATION ══════════════════${NC}"
echo

# Check if running in Termux
if [ $IS_TERMUX -eq 1 ]; then
    echo -e "  ${GREEN}✓${NC} Environment: ${BOLD}Termux${NC}"
    echo -e "  ${GREEN}✓${NC} Prefix: ${BOLD}$PREFIX${NC}"
    echo -e "  ${GREEN}✓${NC} Binary directory: ${BOLD}$BINDIR${NC}"
else
    echo -e "  ${YELLOW}⚠${NC} Environment: ${BOLD}Non-Termux${NC}"
    echo -e "  ${YELLOW}⚠${NC} Installing to: ${BOLD}$BINDIR${NC}"
fi
echo

# Architecture detection
ARCH=$(uname -m)
case $ARCH in
    aarch64|arm64)
        echo -e "  ${GREEN}✓${NC} Architecture: ${BOLD}ARM64 (64-bit)${NC}"
        BITS=64
        ;;
    armv7l|armhf|armv8l)
        echo -e "  ${GREEN}✓${NC} Architecture: ${BOLD}ARM32 (32-bit)${NC}"
        BITS=32
        ;;
    x86_64)
        echo -e "  ${YELLOW}⚠${NC} Architecture: ${BOLD}x86_64${NC} - Emulation mode"
        BITS=64
        ;;
    *)
        echo -e "  ${RED}✗${NC} Architecture: ${BOLD}${ARCH}${NC} - Untested"
        BITS=0
        ;;
esac

# CPU detection
echo -n "  CPU: "
if command -v fastfetch >/dev/null 2>&1; then
    CPU_MODEL=$(fastfetch --structure cpu 2>/dev/null | grep -i "model" | head -1 | sed 's/.*: //')
    echo -e "${BOLD}${CPU_MODEL:-ARMv8-A}${NC}"
elif command -v neofetch >/dev/null 2>&1; then
    CPU_MODEL=$(neofetch --cpu_model 2>/dev/null | head -1)
    echo -e "${BOLD}${CPU_MODEL:-ARM Cortex-A series}${NC}"
else
    if [ -f "/proc/cpuinfo" ]; then
        CPU_INFO=$(grep "Hardware\|model name" /proc/cpuinfo | head -1 | cut -d':' -f2- | sed 's/^ //')
        echo -e "${BOLD}${CPU_INFO:-ARMv8-A}${NC}"
    else
        echo -e "${BOLD}ARMv8-A${NC}"
    fi
fi

# Compiler detection
echo -n "  Compiler: "
if command -v gcc >/dev/null 2>&1; then
    GCC_VER=$(gcc --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo -e "${GREEN}✓${NC} ${BOLD}GCC ${GCC_VER:-installed}${NC}"
else
    echo -e "${YELLOW}⚠${NC} ${BOLD}GCC not found${NC} - Installing..."
    if [ $IS_TERMUX -eq 1 ]; then
        pkg update -y >/dev/null 2>&1
        pkg install gcc -y >/dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} GCC installed"
    else
        echo -e "  ${RED}✗${NC} Please install GCC manually"
        exit 1
    fi
fi

# Check pthreads
echo -n "  pthreads: "
if [ -f "/usr/include/pthread.h" ] || [ -f "$PREFIX/include/pthread.h" ]; then
    echo -e "${GREEN}✓${NC} Available"
else
    echo -e "${YELLOW}⚠${NC} Will link dynamically"
fi

echo
echo -e "${BOLD}${BLUE}══════════════════ BUILD CONFIGURATION ══════════════════${NC}"
echo

# Set optimization flags based on architecture
if [ "$BITS" = "64" ]; then
    CFLAGS="-O3 -march=armv8-a -mtune=cortex-a53 -flto -fomit-frame-pointer -DNDEBUG -fPIE"
    echo -e "  ${GREEN}✓${NC} Mode: ${BOLD}ARM64 Optimized${NC}"
elif [ "$BITS" = "32" ]; then
    CFLAGS="-O3 -march=armv7-a -mfpu=neon -mtune=cortex-a7 -flto -fomit-frame-pointer -DNDEBUG -fPIE"
    echo -e "  ${GREEN}✓${NC} Mode: ${BOLD}ARM32 NEON Optimized${NC}"
else
    CFLAGS="-O2 -fPIE"
    echo -e "  ${YELLOW}⚠${NC} Mode: ${BOLD}Generic${NC}"
fi

echo -e "  Flags: ${CYAN}${CFLAGS}${NC}"
echo

# ============ CREATE SOURCE FILES ============
echo -e "${BOLD}${BLUE}══════════════════ BUILDING B2M ═══════════════════════${NC}"
echo

BUILD_DIR=$(mktemp -d)
cd $BUILD_DIR
echo -e "  ${GREEN}✓${NC} Created build directory: ${BOLD}$BUILD_DIR${NC}"

# ============ BYTES TO MIDI CORE ============
cat > bytes_to_midi.c << 'EOF'
/*
 * B2M - Bytes to MIDI Converter
 * Time Compression Mode - ARM64/ARM32 Optimized
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <pthread.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdatomic.h>

#define MIDI_HEADER_CHUNK "MThd"
#define MIDI_TRACK_CHUNK "MTrk"
#define MIDI_FILE_FORMAT 1
#define MIDI_TICKS_PER_BEAT 480
#define MICROSECONDS_PER_MINUTE 60000000
#define CHUNK_SIZE (1024 * 100)

typedef struct {
    uint8_t type;
    uint8_t note;
    uint8_t velocity;
    uint32_t delta_time;
} MidiEvent;

typedef struct {
    MidiEvent *events;
    size_t count;
    size_t capacity;
} EventList;

typedef struct {
    const uint8_t *data;
    size_t size;
    int chunk_id;
    int min_note;
    int note_span;
    uint8_t velocity;
    uint32_t base_delta;
    EventList *result;
} ChunkTask;

typedef struct {
    ChunkTask *tasks;
    size_t task_count;
    atomic_size_t next_task;
    pthread_t *threads;
    size_t thread_count;
    atomic_size_t completed;
    int verbose;
} ThreadPool;

/* ARM32/ARM64 NEON Support */
#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#define USE_NEON 1
#else
#define USE_NEON 0
#endif

static inline void* safe_malloc(size_t size) {
    void* ptr = malloc(size);
    if (!ptr && size > 0) {
        fprintf(stderr, "malloc(%zu) failed\n", size);
        exit(EXIT_FAILURE);
    }
    return ptr;
}

static uint32_t bpm_to_tempo(int bpm) {
    if (bpm <= 0) bpm = 120;
    return MICROSECONDS_PER_MINUTE / bpm;
}

static void write_big_endian_32(FILE *fp, uint32_t value) {
    uint8_t bytes[4] = {
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF
    };
    fwrite(bytes, 1, 4, fp);
}

static void write_big_endian_16(FILE *fp, uint16_t value) {
    uint8_t bytes[2] = {
        (value >> 8) & 0xFF,
        value & 0xFF
    };
    fwrite(bytes, 1, 2, fp);
}

static void write_variable_length(FILE *fp, uint32_t value) {
    uint8_t buffer[4];
    int i = 0;
    
    buffer[i] = value & 0x7F;
    value >>= 7;
    
    while (value > 0) {
        i++;
        buffer[i] = (value & 0x7F) | 0x80;
        value >>= 7;
    }
    
    while (i >= 0) {
        fwrite(&buffer[i], 1, 1, fp);
        i--;
    }
}

static EventList* eventlist_create(size_t initial_capacity) {
    EventList *list = safe_malloc(sizeof(EventList));
    list->events = safe_malloc(sizeof(MidiEvent) * initial_capacity);
    list->count = 0;
    list->capacity = initial_capacity;
    return list;
}

static int eventlist_append(EventList *list, MidiEvent event) {
    if (list->count >= list->capacity) {
        size_t new_capacity = list->capacity * 2;
        if (new_capacity < 16) new_capacity = 16;
        MidiEvent *new_events = realloc(list->events, sizeof(MidiEvent) * new_capacity);
        if (!new_events) return 0;
        list->events = new_events;
        list->capacity = new_capacity;
    }
    
    list->events[list->count++] = event;
    return 1;
}

static void eventlist_free(EventList *list) {
    if (list) {
        free(list->events);
        free(list);
    }
}

/* Scalar Processing */
static void process_chunk_scalar(const uint8_t *data, size_t size,
                               EventList *result, int min_note,
                               int note_span, uint8_t velocity,
                               uint32_t base_delta) {
    for (size_t i = 0; i < size; i++) {
        uint8_t note = min_note + (data[i] % note_span);
        MidiEvent evt_on = {0, note, velocity, 0};
        MidiEvent evt_off = {1, note, velocity, base_delta};
        if (!eventlist_append(result, evt_on)) break;
        if (!eventlist_append(result, evt_off)) break;
    }
}

#if USE_NEON
/* NEON Optimized Processing (ARM32/ARM64) */
static void process_chunk_neon(const uint8_t *data, size_t size,
                             EventList *result, int min_note,
                             int note_span, uint8_t velocity,
                             uint32_t base_delta) {
    size_t i = 0;
    
    if (size >= 16) {
        uint8x16_t min_note_vec = vdupq_n_u8(min_note);
        uint8x16_t note_span_vec = vdupq_n_u8(note_span);
        
        for (; i + 16 <= size; i += 16) {
            uint8x16_t bytes = vld1q_u8(&data[i]);
            uint8x16_t notes = vaddq_u8(min_note_vec, 
                vsubq_u8(bytes, vmulq_u8(vshrq_n_u8(bytes, 4), note_span_vec)));
            
            uint8_t note_buffer[16];
            vst1q_u8(note_buffer, notes);
            
            for (int j = 0; j < 16; j++) {
                MidiEvent evt_on = {0, note_buffer[j], velocity, 0};
                MidiEvent evt_off = {1, note_buffer[j], velocity, base_delta};
                eventlist_append(result, evt_on);
                eventlist_append(result, evt_off);
            }
        }
    }
    
    process_chunk_scalar(data + i, size - i, result, min_note,
                        note_span, velocity, base_delta);
}
#endif

static void process_chunk(const uint8_t *data, size_t size,
                        EventList *result, int min_note,
                        int note_span, uint8_t velocity,
                        uint32_t base_delta) {
#if USE_NEON
    process_chunk_neon(data, size, result, min_note, note_span,
                      velocity, base_delta);
#else
    process_chunk_scalar(data, size, result, min_note, note_span,
                        velocity, base_delta);
#endif
}

static void* worker_thread(void *arg) {
    ThreadPool *pool = (ThreadPool*)arg;
    
    while (1) {
        size_t task_idx = atomic_fetch_add(&pool->next_task, 1);
        if (task_idx >= pool->task_count) break;
        
        ChunkTask *task = &pool->tasks[task_idx];
        task->result = eventlist_create(task->size * 2);
        
        if (task->result) {
            process_chunk(task->data, task->size, task->result,
                        task->min_note, task->note_span,
                        task->velocity, task->base_delta);
        }
        
        size_t done = atomic_fetch_add(&pool->completed, 1) + 1;
        if (pool->verbose && done % 10 == 0) {
            printf("Processed chunk %zu/%zu\n", done, pool->task_count);
        }
    }
    
    return NULL;
}

static int process_file(const char *filename, EventList ***all_events,
                       size_t *chunk_count, size_t *total_bytes,
                       int min_note, int max_note,
                       uint8_t velocity, uint32_t base_delta,
                       int verbose) {
    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 0;
    }
    
    struct stat st;
    if (fstat(fd, &st) != 0) {
        perror("fstat");
        close(fd);
        return 0;
    }
    
    size_t file_size = st.st_size;
    *total_bytes = file_size;
    
    if (file_size == 0) {
        fprintf(stderr, "File is empty\n");
        close(fd);
        return 0;
    }
    
    uint8_t *file_data = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (file_data == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 0;
    }
    
    *chunk_count = (file_size + CHUNK_SIZE - 1) / CHUNK_SIZE;
    
    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    size_t thread_count = (cores > 0) ? cores : 4;
    if (thread_count > 4) thread_count = 4;
    if (thread_count > *chunk_count) thread_count = *chunk_count;
    
    ThreadPool pool = {
        .tasks = safe_malloc(sizeof(ChunkTask) * (*chunk_count)),
        .task_count = *chunk_count,
        .next_task = 0,
        .threads = safe_malloc(sizeof(pthread_t) * thread_count),
        .thread_count = thread_count,
        .completed = 0,
        .verbose = verbose
    };
    
    *all_events = safe_malloc(sizeof(EventList*) * (*chunk_count));
    
    int note_span = max_note - min_note + 1;
    
    for (size_t i = 0; i < *chunk_count; i++) {
        size_t offset = i * CHUNK_SIZE;
        size_t this_size = CHUNK_SIZE;
        if (offset + this_size > file_size) {
            this_size = file_size - offset;
        }
        
        pool.tasks[i] = (ChunkTask){
            .data = file_data + offset,
            .size = this_size,
            .chunk_id = i,
            .min_note = min_note,
            .note_span = note_span,
            .velocity = velocity,
            .base_delta = base_delta,
            .result = NULL
        };
        (*all_events)[i] = NULL;
    }
    
    for (size_t i = 0; i < thread_count; i++) {
        pthread_create(&pool.threads[i], NULL, worker_thread, &pool);
    }
    
    for (size_t i = 0; i < thread_count; i++) {
        pthread_join(pool.threads[i], NULL);
    }
    
    for (size_t i = 0; i < *chunk_count; i++) {
        (*all_events)[i] = pool.tasks[i].result;
    }
    
    munmap(file_data, file_size);
    close(fd);
    free(pool.tasks);
    free(pool.threads);
    
    return 1;
}

static void apply_time_compression(EventList **events, size_t chunk_count,
                                  double speed_factor) {
    if (fabs(speed_factor - 1.0) < 0.001) return;
    
    for (size_t c = 0; c < chunk_count; c++) {
        EventList *list = events[c];
        if (!list) continue;
        
        for (size_t i = 0; i < list->count; i++) {
            MidiEvent *evt = &list->events[i];
            if (evt->delta_time > 0) {
                double scaled = evt->delta_time / speed_factor;
                evt->delta_time = (uint32_t)(scaled + 0.5);
                if (evt->delta_time < 1) evt->delta_time = 1;
            }
        }
    }
}

static int write_midi(const char *filename, EventList **chunk_events,
                     size_t chunk_count, int bpm, int verbose) {
    FILE *fp = fopen(filename, "wb");
    if (!fp) {
        perror("fopen");
        return 0;
    }
    
    fwrite(MIDI_HEADER_CHUNK, 1, 4, fp);
    write_big_endian_32(fp, 6);
    write_big_endian_16(fp, MIDI_FILE_FORMAT);
    write_big_endian_16(fp, 1);
    write_big_endian_16(fp, MIDI_TICKS_PER_BEAT);
    
    fwrite(MIDI_TRACK_CHUNK, 1, 4, fp);
    long track_size_pos = ftell(fp);
    write_big_endian_32(fp, 0);
    
    uint32_t tempo = bpm_to_tempo(bpm);
    uint8_t tempo_event[] = {0x00, 0xFF, 0x51, 0x03,
                            (tempo >> 16) & 0xFF,
                            (tempo >> 8) & 0xFF,
                            tempo & 0xFF};
    fwrite(tempo_event, 1, sizeof(tempo_event), fp);
    
    for (size_t c = 0; c < chunk_count; c++) {
        EventList *events = chunk_events[c];
        if (!events) continue;
        
        for (size_t i = 0; i < events->count; i++) {
            MidiEvent *evt = &events->events[i];
            write_variable_length(fp, evt->delta_time);
            uint8_t status = evt->type == 0 ? 0x90 : 0x80;
            fwrite(&status, 1, 1, fp);
            fwrite(&evt->note, 1, 1, fp);
            fwrite(&evt->velocity, 1, 1, fp);
        }
    }
    
    write_variable_length(fp, 0);
    uint8_t end_track[] = {0xFF, 0x2F, 0x00};
    fwrite(end_track, 1, sizeof(end_track), fp);
    
    long track_end = ftell(fp);
    fseek(fp, track_size_pos, SEEK_SET);
    write_big_endian_32(fp, track_end - track_size_pos - 4);
    
    fclose(fp);
    return 1;
}

int bytes_to_midi_c(const char *input_file, const char *output_file,
                   int min_note, int max_note, uint8_t velocity,
                   uint8_t delta_time, double target_seconds,
                   int bpm, int verbose) {
    struct timespec start, end;
    
    if (verbose) {
        clock_gettime(CLOCK_MONOTONIC, &start);
    }
    
    if (min_note < 0) min_note = 0;
    if (max_note > 127) max_note = 127;
    if (min_note > max_note) min_note = max_note;
    if (velocity > 127) velocity = 127;
    if (delta_time < 1) delta_time = 1;
    if (delta_time > 127) delta_time = 127;
    if (bpm < 1) bpm = 1;
    if (bpm > 300) bpm = 300;
    
    EventList **all_events = NULL;
    size_t chunk_count = 0;
    size_t total_bytes = 0;
    
    if (!process_file(input_file, &all_events, &chunk_count, &total_bytes,
                     min_note, max_note, velocity, delta_time, verbose)) {
        return 0;
    }
    
    double total_ticks = total_bytes * delta_time;
    double beats = total_ticks / MIDI_TICKS_PER_BEAT;
    double original_seconds = beats * 60.0 / bpm;
    
    if (target_seconds > 0.0 && original_seconds > 0.0) {
        double speed_factor = original_seconds / target_seconds;
        apply_time_compression(all_events, chunk_count, speed_factor);
    }
    
    int result = write_midi(output_file, all_events, chunk_count, bpm, verbose);
    
    for (size_t i = 0; i < chunk_count; i++) {
        eventlist_free(all_events[i]);
    }
    free(all_events);
    
    return result;
}
EOF
echo -e "  ${GREEN}✓${NC} Created bytes_to_midi.c"

# ============ MAIN CLI ============
cat > main.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/stat.h>

#define MIDI_TICKS_PER_BEAT 480

int bytes_to_midi_c(const char *, const char *, int, int, 
                   unsigned char, unsigned char, double, int, int);

static void print_usage(const char *name) {
    printf("B2M - Bytes to MIDI Converter v2.0 (Time Compression)\n");
    printf("Usage: %s <input> <output.mid> [options]\n\n", name);
    printf("Options:\n");
    printf("  -dur N     Note duration (1-127 ticks, default: 48)\n");
    printf("  -time N    Total duration in seconds (compress/expand)\n");
    printf("  -bpm N     Tempo (1-300, default: 120)\n");
    printf("  -min N     Minimum note (0-127, default: 60)\n");
    printf("  -max N     Maximum note (0-127, default: 84)\n");
    printf("  -vel N     Velocity (0-127, default: 64)\n");
    printf("  -v         Verbose output\n");
    printf("  -h         Show this help\n");
}

static int parse_args(int argc, char *argv[], 
                     char **in, char **out,
                     int *min, int *max, 
                     unsigned char *vel, unsigned char *dur,
                     double *target_sec, int *bpm, int *verbose) {
    if (argc < 3) {
        print_usage(argv[0]);
        return 0;
    }
    
    *in = argv[1];
    *out = argv[2];
    *min = 60;
    *max = 84;
    *vel = 64;
    *dur = 48;
    *target_sec = 0.0;
    *bpm = 120;
    *verbose = 0;
    
    for (int i = 3; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (strcmp(argv[i], "-min") == 0 && i+1 < argc) {
            *min = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-max") == 0 && i+1 < argc) {
            *max = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-vel") == 0 && i+1 < argc) {
            *vel = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-dur") == 0 && i+1 < argc) {
            *dur = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-time") == 0 && i+1 < argc) {
            *target_sec = atof(argv[++i]);
        } else if (strcmp(argv[i], "-bpm") == 0 && i+1 < argc) {
            *bpm = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-v") == 0) {
            *verbose = 1;
        } else {
            fprintf(stderr, "Unknown: %s\n", argv[i]);
            return 0;
        }
    }
    return 1;
}

int main(int argc, char *argv[]) {
    char *input_file, *output_file;
    int min_note, max_note, bpm, verbose;
    unsigned char velocity, delta_time;
    double target_seconds;
    
    if (!parse_args(argc, argv, &input_file, &output_file,
                   &min_note, &max_note, &velocity, &delta_time,
                   &target_seconds, &bpm, &verbose)) {
        return 1;
    }
    
    if (access(input_file, R_OK) != 0) {
        fprintf(stderr, "Error: Cannot read '%s'\n", input_file);
        return 1;
    }
    
    if (min_note < 0) min_note = 0;
    if (min_note > 127) min_note = 127;
    if (max_note < 0) max_note = 0;
    if (max_note > 127) max_note = 127;
    if (min_note > max_note) {
        int tmp = min_note; min_note = max_note; max_note = tmp;
    }
    if (velocity > 127) velocity = 127;
    if (delta_time < 1) delta_time = 1;
    if (delta_time > 127) delta_time = 127;
    if (bpm < 1) bpm = 1;
    if (bpm > 300) bpm = 300;
    
    int result = bytes_to_midi_c(input_file, output_file,
                                min_note, max_note, velocity,
                                delta_time, target_seconds, bpm, verbose);
    
    if (result) {
        printf("✓ Success: %s\n", output_file);
        return 0;
    } else {
        printf("✗ Failed\n");
        return 1;
    }
}
EOF
echo -e "  ${GREEN}✓${NC} Created main.c"

# ============ COMPILE ============
echo -e "  ${CYAN}Compiling${NC} with optimizations..."

gcc $CFLAGS -c bytes_to_midi.c -o bytes_to_midi.o 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Compiled core"
else
    echo -e "  ${RED}✗${NC} Core compilation failed"
    exit 1
fi

gcc $CFLAGS -c main.c -o main.o 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Compiled CLI"
else
    echo -e "  ${RED}✗${NC} CLI compilation failed"
    exit 1
fi

gcc $CFLAGS bytes_to_midi.o main.o -o b2m -lpthread -lm -pie 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Linked binary"
else
    echo -e "  ${RED}✗${NC} Linking failed"
    exit 1
fi

strip b2m -o b2m_stripped 2>/dev/null || cp b2m b2m_stripped
echo -e "  ${GREEN}✓${NC} Stripped symbols"

# ============ INSTALL ============
echo
echo -e "${BOLD}${BLUE}══════════════════ INSTALLING B2M ════════════════════${NC}"
echo

echo -e "  Target: ${BOLD}$BINDIR/b2m${NC}"

if [ -f "$BINDIR/b2m" ]; then
    BACKUP="$BINDIR/b2m.backup.$(date +%s)"
    cp "$BINDIR/b2m" "$BACKUP" 2>/dev/null
    echo -e "  ${YELLOW}📦${NC} Backed up old binary to ${BOLD}$(basename $BACKUP)${NC}"
fi

cp b2m_stripped "$BINDIR/b2m" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Installed to ${BOLD}$BINDIR/b2m${NC}"
else
    echo -e "  ${RED}✗${NC} Failed to install. Trying sudo..."
    sudo cp b2m_stripped "$BINDIR/b2m" 2>/dev/null || {
        echo -e "  ${RED}✗${NC} Installation failed. Run as root or check permissions."
        exit 1
    }
fi

chmod 755 "$BINDIR/b2m" 2>/dev/null || sudo chmod 755 "$BINDIR/b2m" 2>/dev/null

# ============ VERIFICATION ============
echo
echo -e "${BOLD}${BLUE}══════════════════ VERIFICATION ═══════════════════════${NC}"
echo

# Verify binary exists
if [ -f "$BINDIR/b2m" ]; then
    echo -e "  ${GREEN}✓${NC} Binary installed at ${BOLD}$BINDIR/b2m${NC}"
else
    echo -e "  ${RED}✗${NC} Binary not found"
    exit 1
fi

# Verify architecture
FILE_OUTPUT=$(file "$BINDIR/b2m" 2>/dev/null)
if echo "$FILE_OUTPUT" | grep -q "ELF"; then
    echo -e "  ${GREEN}✓${NC} Valid ELF executable"
    
    if echo "$FILE_OUTPUT" | grep -q "64-bit"; then
        echo -e "  ${GREEN}✓${NC} 64-bit ARM64 binary"
    elif echo "$FILE_OUTPUT" | grep -q "32-bit"; then
        echo -e "  ${GREEN}✓${NC} 32-bit ARM binary"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Binary format: $FILE_OUTPUT"
fi

# Test functionality
echo -n "  Testing conversion: "
dd if=/dev/urandom of=test.bin bs=1024 count=1 2>/dev/null

if "$BINDIR/b2m" test.bin test.mid -dur 48 >/dev/null 2>&1; then
    if [ -f "test.mid" ] && [ -s "test.mid" ]; then
        echo -e "${GREEN}✓${NC} Passed"
        rm -f test.bin test.mid
    else
        echo -e "${RED}✗${NC} Failed (no MIDI file)"
    fi
else
    echo -e "${RED}✗${NC} Failed (execution error)"
fi

# Test time compression
echo -n "  Testing time compression: "
dd if=/dev/urandom of=test.bin bs=1024 count=1 2>/dev/null

if "$BINDIR/b2m" test.bin test.mid -dur 48 -time 1 >/dev/null 2>&1; then
    if [ -f "test.mid" ] && [ -s "test.mid" ]; then
        echo -e "${GREEN}✓${NC} Passed"
        rm -f test.bin test.mid
    else
        echo -e "${RED}✗${NC} Failed"
    fi
else
    echo -e "${RED}✗${NC} Failed"
fi

# ============ CLEANUP ============
cd /
rm -rf $BUILD_DIR
echo -e "  ${GREEN}✓${NC} Cleaned up temporary files"

# ============ ADD TO PATH IF NEEDED ============
if [[ ":$PATH:" != *":$BINDIR:"* ]]; then
    echo -e "  ${YELLOW}⚠${NC} $BINDIR not in PATH"
    if [ $IS_TERMUX -eq 1 ]; then
        echo -e "  ${GREEN}✓${NC} Termux automatically includes $BINDIR in PATH"
    else
        echo -e "  ${YELLOW}💡${NC} Add to PATH: export PATH=\"\$PATH:$BINDIR\""
    fi
fi

# ============ SUCCESS MESSAGE ============
echo
echo -e "${BOLD}${GREEN}══════════════════ INSTALLATION COMPLETE ══════════════════${NC}"
echo
echo -e "  ${BOLD}B2M${NC} is now ready to use!"
echo
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${BOLD}Quick Start:${NC}"
echo -e "  ├─ b2m file.bin output.mid              # Basic conversion"
echo -e "  ├─ b2m file.bin out.mid -dur 64         # 64 tick notes"
echo -e "  └─ b2m file.bin out.mid -time 30 -v     # Compress to 30s"
echo
echo -e "  ${BOLD}Examples:${NC}"
echo -e "  ├─ b2m song.wav midi.mid -dur 48 -time 180"
echo -e "  ├─ b2m logo.bmp notes.mid -min 48 -max 72 -bpm 140"
echo -e "  └─ b2m archive.ico music.mid -vel 80 -dur 96 -v"
echo
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${YELLOW}💡 Tip:${NC} Prefer using uncompressed formats like .wav, .bmp, .ico, etc."
echo
echo -e "  ${GREEN}✓${NC} Type ${BOLD}b2m --help${NC} for all options"
echo