// File: sim/tests/common/syscalls.c
// Универсальная версия для newlib и picolibc

#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

// Для picolibc, errno объявлен как thread_local.
// Чтобы избежать конфликтов, мы проверяем, не определен ли он уже.
// Если он не определен (как в старой newlib), мы его объявляем.
#ifndef errno
extern int errno;
#endif

// Указатель на конец кучи. _end определяется в linker-скрипте.
extern char _end[];
static char *heap_end = _end;

/*
 * _sbrk - системный вызов для выделения памяти. Используется malloc.
 */
void * _sbrk(int incr) {
    char *prev_heap_end;
    if (heap_end == 0) {
        heap_end = _end;
    }
    prev_heap_end = heap_end;
    heap_end += incr;
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

void _exit(int status);
void abort(void);

void _exit(int status) {
    while(1);
}

void abort(void) {
    _exit(1);
}

int _kill(pid_t pid, int sig) {
    errno = EINVAL;
    return -1;
}

pid_t _getpid(void) {
    return 1;
}