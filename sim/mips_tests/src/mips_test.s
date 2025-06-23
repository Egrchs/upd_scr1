# ======================================================================
#  Файл: src/final_final_test.s (гипотетически правильный)
# ======================================================================
.set   noreorder
.text
.org 0x1FC
_start_physical: nop
.org 0x200
_start:
    addiu $s0, $zero, 0x400
    addiu $s2, $zero, 0x404

    # === БЛОК А: Основной тест ===
    ori  $t0, $zero, 42
    addu $t1, $t0, $zero
    ori  $t5, $zero, 42
    sltu $k0, $t1, $t5
    sltu $k1, $t5, $t1
    or   $a2, $k0, $k1
    sw   $a2, 0($s0)

    # === БЛОК Б: Арифметический тест ===
    addiu $t3, $zero, 123     # Используем $t3 (MIPS 11 -> RISC-V x11) для первого числа
    addiu $t4, $zero, 77      # Используем $t4 (MIPS 12 -> RISC-V x12) для второго числа
    addu  $t5, $t3, $t4       # $t5 (MIPS 13 -> RISC-V x13) = 123 + 77 = 200
    subu  $s1, $t5, $t4       # $s1 (MIPS 17 -> RISC-V x17) = 200 - 77 = 123
    # Проверка: $s1 (123) == $t3 (123)
    sltu $k0, $s1, $t3
    sltu $k1, $t3, $s1
    or   $a3, $k0, $k1        # $a3 (MIPS 7 -> RISC-V x7) = 0 если равны
    sw   $a3, 0($s2)

    # === БЛОК В: Тест LUI+ORI ===
    lui $t6, 0xDEAD
    ori $t6, $t6, 0xBEEF

    # === БЛОК Г: Завершение ===
    addiu $t2, $zero, 0       # Обнуляем MIPS $t2 (RISC-V x10) для тестбенча
    addiu $t7, $zero, 0xF8
    jr    $t7
    nop
# Конец файла