// File: sim/tests/common/syscalls.c
// Универсальная версия, не зависящая от системных newlib/picolibc.

// Определяем базовые типы, чтобы не зависеть от <sys/types.h>
typedef long int ptrdiff_t;
typedef long unsigned int size_t;
typedef int pid_t;

// Определяем структуру stat, чтобы не зависеть от <sys/stat.h>
struct stat {
  unsigned long long  st_dev;
  unsigned long long  st_ino;
  unsigned int        st_mode;
  unsigned int        st_nlink;
  unsigned int        st_uid;
  unsigned int        st_gid;
  unsigned long long  st_rdev;
  unsigned long long  __pad1;
  long long           st_size;
  int                 st_blksize;
  int                 __pad2;
  long long           st_blocks;
  long long           st_atime;
  long long           st_atime_nsec;
  long long           st_mtime;
  long long           st_mtime_nsec;
  long long           st_ctime;
  long long           st_ctime_nsec;
  unsigned int        __unused4;
  unsigned int        __unused5;
};
#define S_IFCHR 0020000

// Указатель на конец кучи. _end определяется в linker-скрипте.
// Мы объявляем его как weak, чтобы не конфликтовать, если он уже где-то есть.
__attribute__((weak)) char _end = 0;
static char *heap_end = &_end;

/*
 * _sbrk - системный вызов для выделения памяти. Используется malloc.
 */
void * _sbrk(int incr) {
    char *prev_heap_end;
    if (heap_end == &_end) { // Проверяем, что _end не 0
        prev_heap_end = heap_end;
        heap_end += incr;
    } else {
        // Если _end не определен, возвращаем ошибку
        return (void *) -1;
    }
    return (void *) prev_heap_end;
}

/*
 * Простая реализация malloc, использующая _sbrk.
 */
void * malloc(size_t size) {
    if (size == 0) {
        return (void*)heap_end;
    }
    size_t aligned_size = (size + 7) & ~7;
    void* p = _sbrk(aligned_size);
    if (p == (void*)-1) {
        return (void*)0; // NULL
    }
    return p;
}

/*
 * Простая реализация memcpy.
 */
void * memcpy(void *dest, const void *src, size_t n) {
    char *d = dest;
    const char *s = src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

/*
 * Простая реализация memset.
 */
void * memset(void *s, int c, size_t n) {
    unsigned char *p = s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}


// ----- Остальные заглушки -----

int _write(int file, char *ptr, int len) { return len; }
int _close(int file) { return -1; }
int _fstat(int file, struct stat *st) { st->st_mode = S_IFCHR; return 0; }
int _isatty(int file) { return 1; }
int _lseek(int file, int ptr, int dir) { return 0; }
int _read(int file, char *ptr, int len) { return 0; }

// Объявляем _exit и abort, чтобы компилятор не жаловался.
void _exit(int status);
void abort(void);

void _exit(int status) {
    while(1); // Бесконечный цикл, чтобы остановить симуляцию
}

void abort(void) {
    _exit(1);
}

// Заглушка для kill
int _kill(pid_t pid, int sig) {
    return -1;
}

// Заглушка для getpid
pid_t _getpid(void) {
    return 1;
}

// Заглушка для errno (не используем extern, чтобы избежать конфликтов)
int errno = 0;