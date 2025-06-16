// File: sim/tests/common/syscalls.c
//
// Этот файл предоставляет "заглушки" для системных вызовов,
// которые требуются стандартной библиотеке C (newlib), но отсутствуют
// в bare-metal окружении (т.е. без операционной системы).

#include <sys/stat.h>
#include <errno.h>

#undef errno
extern int errno;

// Указатель на конец кучи. _end определяется в linker-скрипте.
extern char _end[];
static char *heap_end = _end;

/*
 * _sbrk - системный вызов для выделения памяти. Используется malloc.
 */
void * _sbrk(int incr) {
    char *prev_heap_end;
    // 'heap_end' должен быть инициализирован адресом _end из линкер-скрипта.
    // Если он еще не инициализирован, делаем это.
    if (heap_end == 0) {
        heap_end = _end;
    }
    prev_heap_end = heap_end;
    heap_end += incr;
    return (void *) prev_heap_end;
}

// ================ НАЧАЛО НОВОГО КОДА ================

/*
 * Простая реализация malloc, использующая _sbrk.
 * Не имеет free, так как в тестах память обычно не освобождается.
 */
void * malloc(size_t size) {
    // Выравниваем размер до ближайшего кратного 8 для лучшей производительности
    size_t aligned_size = (size + 7) & ~7;
    void* p = _sbrk(aligned_size);
    // В реальной системе нужно проверять на 'out of memory', но для тестов это избыточно.
    // if (p == (void*)-1) { return NULL; }
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

void * memset(void *s, int c, size_t n) {
    unsigned char *p = s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}

// ================= КОНЕЦ НОВОГО КОДА =================

// Остальные заглушки.
int _write(int file, char *ptr, int len) { return len; }
int _close(int file) { return -1; }
int _fstat(int file, struct stat *st) { st->st_mode = S_IFCHR; return 0; }
int _isatty(int file) { return 1; }
int _lseek(int file, int ptr, int dir) { return 0; }
int _read(int file, char *ptr, int len) { return 0; }

void _exit(int status) {
    while(1); // Бесконечный цикл, чтобы остановить симуляцию
}

void abort(void) {
    _exit(1);
}