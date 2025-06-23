# Makefile для сборки MIPS тестов
# Автономная версия с автоматическим определением системы.

# ---------------------------------------------------------------------------
#  Определение системы и тулчейна
# ---------------------------------------------------------------------------

# Проверяем, является ли система Arch-based (как Steam Deck)
# Это определит, какой префикс тулчейна использовать.
IS_ARCH_BASED := $(shell (grep -q -i -e "ID_LIKE=arch" -e "ID=arch" /etc/os-release 2>/dev/null || uname -n | grep -q -i 'steamdeck') && echo "yes")

# В зависимости от системы выбираем правильный префикс для MIPS тулчейна
ifeq ($(IS_ARCH_BASED), yes)
    # На Arch / Steam Deck мы установили тулчейн с префиксом 'mipsel-linux-'
    MIPS_CROSS_PREFIX ?= mipsel-linux-
else
    # На других системах (Debian/Ubuntu) предполагаем стандартный 'mips-linux-gnu-'
    MIPS_CROSS_PREFIX ?= mips-linux-gnu-
endif

# Определяем утилиты на основе выбранного префикса
AS      := $(MIPS_CROSS_PREFIX)as
LD      := $(MIPS_CROSS_PREFIX)ld
OBJCOPY := $(MIPS_CROSS_PREFIX)objcopy

# ---------------------------------------------------------------------------
#  Пути и флаги
# ---------------------------------------------------------------------------

# Пути. BUILD_DIR передается из главного Makefile.
SRC_DIR       := src
BUILD_DIR     ?= ../build  # Значение по умолчанию, если не передано
OBJ_DIR       := $(BUILD_DIR)/mips_obj
LINKER_SCRIPT := mips_link.ld

# Флаги
ASFLAGS := -mips1 -EL
LDFLAGS := -T $(LINKER_SCRIPT) -EL

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
$(BUILD_DIR)/%.hex: $(SRC_DIR)/%.s $(LINKER_SCRIPT) | $(BUILD_DIR) $(OBJ_DIR)
	@echo "--- Building MIPS test: $(notdir $<) using prefix '$(MIPS_CROSS_PREFIX)' ---"

	# 1. Компиляция (ассемблирование) .s -> .o
	$(AS) $(ASFLAGS) -o $(OBJ_DIR)/$(notdir $@).o $<

	# 2. Линковка (компоновка) .o -> .elf
	$(LD) $(LDFLAGS) -o $(OBJ_DIR)/$(notdir $@).elf $(OBJ_DIR)/$(notdir $@).o

	# 3. Конвертация .elf -> .hex (Verilog)
	@echo "Converting to Verilog HEX format..."
	$(OBJCOPY) -O verilog $(OBJ_DIR)/$(notdir $@).elf $@

	@echo "--- Finished MIPS test: $(notdir $@) ---"

# Правила для создания директорий
$(BUILD_DIR) $(OBJ_DIR):
	@mkdir -p $@

# Правило для очистки
clean:
	@echo "Cleaning MIPS test artifacts..."
	-$(RM) -rf $(OBJ_DIR)
	-$(RM) -f $(HEX_FILES)