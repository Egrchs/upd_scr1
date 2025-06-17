ADD_ASM_MACRO ?= -D__ASSEMBLY__=1

# --- Выбираем флаги оптимизации в зависимости от системы ---
ifeq ($(IS_ARCH_BASED), yes)
    # Безопасные флаги для нового GCC на Arch/Steam Deck
    $(info [INFO] Arch-based system detected. Using GCC flags: -O2 -fno-lto)
    FLAGS = -O2 -fno-lto $(ADD_FLAGS)
else
    # Старые, агрессивные флаги для Debian/WSL
    FLAGS = -O3 -funroll-loops -fpeel-loops -fgcse-sm -fgcse-las $(ADD_FLAGS)
endif
# --- Конец блока ---

FLAGS_STR = "$(FLAGS)"

CFLAGS_COMMON = -static -std=gnu99 -fno-common -fno-builtin-printf -DTCM=$(TCM)
CFLAGS_ARCH = -Wa,-march=rv32$(ARCH)_zicsr_zifencei -march=rv32$(ARCH)_zicsr_zifencei -mabi=$(ABI)

CFLAGS := $(FLAGS) $(EXT_CFLAGS) \
$(CFLAGS_COMMON) \
$(CFLAGS_ARCH) \
-DFLAGS_STR=\"$(FLAGS_STR)\" \
$(ADD_CFLAGS)

LDFLAGS   = -L$(LIB_C_PATH) -L$(LIB_GCC_PATH) -nostartfiles -nostdlib -lc -lgcc -march=rv32$(ARCH)_zicsr_zifencei -mabi=$(ABI)

ifeq (,$(findstring 0,$(TCM)))
ld_script ?= $(inc_dir)/link_tcm.ld
asm_src   ?= crt_tcm.S
else
ld_script ?= $(inc_dir)/link.ld
asm_src   ?= crt.S
endif

# --- УСЛОВНОЕ ПОДКЛЮЧЕНИЕ SYSCALLS ДЛЯ ARCH-СИСТЕМ ---
# Проверяем переменную IS_ARCH_BASED, установленную в главном Makefile.
# Добавляем файл только если в тесте уже есть C-код.
ifeq ($(IS_ARCH_BASED), yes)
    ifneq ($(strip $(c_src)),)
        $(info [INFO] Attaching baremetal syscalls for Arch-based system.)
        c_src += syscalls_baremetal.c
    endif
endif
# --- Конец блока ---

#this is optional assembly files from project
asm_src += $(asm_src_in_project)

VPATH += $(src_dir) $(inc_dir) $(ADD_VPATH)
incs  += -I$(src_dir) -I$(inc_dir) $(ADD_incs)

c_objs   := $(addprefix $(bld_dir)/,$(patsubst %.c, %.o, $(c_src)))
asm_objs := $(addprefix $(bld_dir)/,$(patsubst %.S, %.o, $(asm_src)))

$(bld_dir)/%.o: %.S
	$(RISCV_GCC) $(CFLAGS) $(ADD_ASM_MACRO) -c $(incs) $< -o $@

$(bld_dir)/%.o: %.c
	$(RISCV_GCC) $(CFLAGS) -c $(incs) $< -o $@

$(bld_dir)/%.elf: $(ld_script) $(c_objs) $(asm_objs)
	$(RISCV_GCC) -v -o $@ -T $^ $(LDFLAGS)

$(bld_dir)/%.hex: $(bld_dir)/%.elf
	$(RISCV_OBJCOPY) $^ $@

$(bld_dir)/%.dump: $(bld_dir)/%.elf
	$(RISCV_OBJDUMP) -D -w -x -S $^ > $@