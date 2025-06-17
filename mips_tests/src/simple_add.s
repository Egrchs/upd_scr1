# simple_add_fixed.s
# Версия, использующая только поддерживаемые инструкции

.section .text.init
.globl _start
.equ SIM_EXIT_ADDR, 0x000000F8

_start:
    # Используем addi вместо ori, так как addi у вас точно есть
    addi $t0, $zero, 5
    addi $t1, $zero, 10
    
    # Используем add вместо addu (требует добавления funct 100000)
    add $s0, $t0, $t1

    # Используем sub вместо subu (требует добавления funct 100010)
    addi $t3, $zero, 15
    sub $t2, $s0, $t3

exit_test:
    # Загружаем адрес выхода одной инструкцией
    ori $at, $zero, SIM_EXIT_ADDR
    jr $at
    nop