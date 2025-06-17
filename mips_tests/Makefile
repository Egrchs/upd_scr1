# Makefile для сборки MIPS тестов

# ---------------------------------------------------------------------------
#  Инструменты и переменные
# ---------------------------------------------------------------------------

# Префикс для MIPS тулчейна.
CROSS_PREFIX_MIPS ?= mips-linux-gnu-

# Определяем утилиты
AS      := $(CROSS_PREFIX_MIPS)as
LD      := $(CROSS_PREFIX_MIPS)ld
OBJCOPY := $(CROSS_PREFIX_MIPS)objcopy

# Пути. BUILD_DIR передается из главного Makefile.
SRC_DIR       := src
BUILD_DIR     ?= ../build
OBJ_DIR       := $(BUILD_DIR)/mips_obj
LINKER_SCRIPT := mips_link.ld

# Флаги
ASFLAGS := -mips1
LDFLAGS := -T $(LINKER_SCRIPT)

# ---------------------------------------------------------------------------
#  Определение целей сборки
# ---------------------------------------------------------------------------

# Находим все исходные ассемблерные файлы в директории src
SOURCES := $(wildcard $(SRC_DIR)/*.s)

# Генерируем имена целевых .hex файлов на основе исходников
HEX_FILES := $(patsubst $(SRC_DIR)/%.s, $(BUILD_DIR)/%.hex, $(SOURCES))

# ---------------------------------------------------------------------------
#  Правила сборки
# ---------------------------------------------------------------------------

# Цель по умолчанию - собрать все .hex файлы
.PHONY: all clean
all: $(HEX_FILES)

# Основное правило: как создать .hex файл из .s файла
# Оно будет выполняться для каждого теста.
$(BUILD_DIR)/%.hex: $(SRC_DIR)/%.s $(LINKER_SCRIPT)
	@echo "--- Building MIPS test: $(notdir $<) ---"
	@mkdir -p $(OBJ_DIR)

	# 1. Компиляция (ассемблирование) .s -> .o
	$(AS) $(ASFLAGS) -o $(OBJ_DIR)/$(notdir $@).o $<

	# 2. Линковка (компоновка) .o -> .elf
	$(LD) $(LDFLAGS) -o $(OBJ_DIR)/$(notdir $@).elf $(OBJ_DIR)/$(notdir $@).o

	# 3. Конвертация .elf -> .hex (Verilog)
	#    Используем objcopy вместо srec_cat. Это надежнее.
	@echo "Converting to Verilog HEX format..."
	$(OBJCOPY) -O verilog $(OBJ_DIR)/$(notdir $@).elf $@

	@echo "--- Finished MIPS test: $(notdir $@) ---"


# Правило для очистки
clean:
	@echo "Cleaning MIPS test artifacts..."
	-$(RM) -rf $(OBJ_DIR)
	-$(RM) -f $(HEX_FILES)