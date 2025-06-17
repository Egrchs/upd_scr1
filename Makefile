#------------------------------------------------------------------------------
# Makefile for SCR1
# Универсальная версия, адаптированная для различных систем,
# включая Debian/Ubuntu, Arch Linux (Steam Deck) и WSL.
#------------------------------------------------------------------------------

# ======================================================================
#   ОПРЕДЕЛЕНИЕ СИСТЕМЫ И ПУТЕЙ
# ======================================================================

# --- 1. Определяем тип ОС ---
# IS_ARCH_BASED будет 'yes' для Arch Linux, Manjaro, SteamOS и т.д.
IS_ARCH_BASED := $(shell (grep -q -i -e "ID_LIKE=arch" -e "ID=arch" /etc/os-release 2>/dev/null || uname -n | grep -q -i 'steamdeck') && echo "yes")
export IS_ARCH_BASED

# --- 2. Автоматическое определение префикса кросс-компилятора ---
detected_gcc_cmd := $(firstword $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null) $(shell command -v riscv64-elf-gcc 2>/dev/null))
ifeq ($(detected_gcc_cmd),)
  $(error "ERROR: Could not find 'riscv64-unknown-elf-gcc' or 'riscv64-elf-gcc' in your PATH. Please ensure the RISC-V toolchain is installed.")
endif

export CROSS_PREFIX := $(patsubst %gcc,%,$(notdir $(detected_gcc_cmd)))
$(info [INFO] Detected toolchain prefix: '$(CROSS_PREFIX)')

# --- 3. Умный поиск путей к библиотекам и заголовкам ---
# Самый надежный способ: ищем сам файл stdio.h и берем его директорию.
# Это позволяет избежать путаницы с внутренними include-директориями GCC.
INCLUDE_PATH := $(shell find /usr/include /usr/lib -name stdio.h -path '*/riscv64*/*' 2>/dev/null | head -n 1 | xargs -r dirname)

# Ищем библиотеки, указывая конкретную архитектуру в пути для надежности.
LIB_C_PATH   := $(shell find /usr/lib -name libc.a -path '*/rv32imac/ilp32/*' 2>/dev/null | head -n 1 | xargs -r dirname)
LIB_GCC_PATH := $(shell find /usr/lib/gcc -name libgcc.a -path '*/rv32imac/ilp32/*' 2>/dev/null | head -n 1 | xargs -r dirname)


# --- 4. Проверка найденных путей ---
ifeq ($(INCLUDE_PATH),)
  $(error "ERROR: Could not find the RISC-V C library include path (where stdio.h lives). Please ensure the toolchain's C library (newlib/picolibc) is installed correctly.")
endif
ifeq ($(LIB_C_PATH),)
  $(error "ERROR: Could not find 32-bit libc.a library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif
ifeq ($(LIB_GCC_PATH),)
  $(error "ERROR: Could not find 32-bit gcc library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif

$(info [INFO] Found include path: $(INCLUDE_PATH))
$(info [INFO] Found libc path:    $(LIB_C_PATH))
$(info [INFO] Found libgcc path:  $(LIB_GCC_PATH))

# --- 5. Экспорт переменных тулчейна ---
export RISCV_GCC     := $(CROSS_PREFIX)gcc -I$(INCLUDE_PATH)
export RISCV_OBJDUMP ?= $(CROSS_PREFIX)objdump -D
export RISCV_OBJCOPY ?= $(CROSS_PREFIX)objcopy -O verilog
export RISCV_READELF ?= $(CROSS_PREFIX)readelf -s
export LIB_C_PATH
export LIB_GCC_PATH

# --- 4. Проверка найденных путей ---
ifeq ($(INCLUDE_PATH),)
  $(error "ERROR: Could not find riscv64 include path. Please ensure toolchain is installed.")
endif
ifeq ($(LIB_C_PATH),)
  $(error "ERROR: Could not find 32-bit libc.a library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif
ifeq ($(LIB_GCC_PATH),)
  $(error "ERROR: Could not find 32-bit gcc library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif

$(info [INFO] Found include path: $(INCLUDE_PATH))
$(info [INFO] Found libc path:    $(LIB_C_PATH))
$(info [INFO] Found libgcc path:  $(LIB_GCC_PATH))

# --- 5. Экспорт переменных тулчейна ---
export RISCV_GCC     := $(CROSS_PREFIX)gcc -I$(INCLUDE_PATH)
export RISCV_OBJDUMP ?= $(CROSS_PREFIX)objdump -D
export RISCV_OBJCOPY ?= $(CROSS_PREFIX)objcopy -O verilog
export RISCV_READELF ?= $(CROSS_PREFIX)readelf -s
export LIB_C_PATH
export LIB_GCC_PATH

# --- 3. Проверка найденных путей ---
ifeq ($(INCLUDE_PATH),)
  $(error "ERROR: Could not find riscv64 include path. Please ensure toolchain is installed.")
endif
ifeq ($(LIB_C_PATH),)
  $(error "ERROR: Could not find 32-bit libc.a library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif
ifeq ($(LIB_GCC_PATH),)
  $(error "ERROR: Could not find 32-bit gcc library path (rv32imac/ilp32). Please ensure toolchain is installed.")
endif

$(info [INFO] Found include path: $(INCLUDE_PATH))
$(info [INFO] Found libc path:    $(LIB_C_PATH))
$(info [INFO] Found libgcc path:  $(LIB_GCC_PATH))

# --- 4. Экспорт переменных тулчейна ---
export RISCV_GCC     := $(CROSS_PREFIX)gcc -I$(INCLUDE_PATH)
export RISCV_OBJDUMP ?= $(CROSS_PREFIX)objdump -D
export RISCV_OBJCOPY ?= $(CROSS_PREFIX)objcopy -O verilog
export RISCV_READELF ?= $(CROSS_PREFIX)readelf -s
export LIB_C_PATH
export LIB_GCC_PATH

# ======================================================================
#   ОПРЕДЕЛЕНИЕ СРЕДЫ И СИМУЛЯТОРОВ
# ======================================================================

ifeq ($(shell uname -r | grep -i microsoft),)
    $(info Detected regular Linux environment, using non-.exe commands)
    VLIB     := vlib
    VMAP     := vmap
    VLOG     := vlog
    MODELSIM := vsim
else
    $(info Detected WSL environment, using .exe commands)
    VLIB     := vlib.exe
    VMAP     := vmap.exe
    VLOG     := vlog.exe
    MODELSIM := vsim.exe
endif
export VLIB VMAP VLOG MODELSIM

# Опции для симуляторов. Этот блок чистый, без хаков для Verilator.
SIM_BUILD_OPTS ?=
ifneq ($(shell uname -r | grep -i microsoft),)
	ifeq ($(findstring modelsim,$(MAKECMDGOALS)),modelsim)
		SIM_BUILD_OPTS += +define+USE_WSL_WRAPPER
    endif
endif

# ======================================================================
#   ПАРАМЕТРЫ СБОРКИ
# ======================================================================

GUI ?= 0
export CFG      ?= MAX
export BUS      ?= AHB
TRACE ?= 0

ifeq ($(CFG), MAX)
    override ARCH         := IMC
    override VECT_IRQ     := 1
    override IPIC         := 1
    override TCM          := 1
    override SIM_CFG_DEF  := SCR1_CFG_RV32IMC_MAX
else ifeq ($(CFG), BASE)
    override ARCH         := IC
    override VECT_IRQ     := 1
    override IPIC         := 1
    override TCM          := 1
    override SIM_CFG_DEF  := SCR1_CFG_RV32IC_BASE
else ifeq ($(CFG), MIN)
    override ARCH         := EC
    override VECT_IRQ     := 0
    override IPIC         := 0
    override TCM          := 1
    override SIM_CFG_DEF  := SCR1_CFG_RV32EC_MIN
else
    ARCH      ?= IMC
    VECT_IRQ  ?= 0
    IPIC      ?= 0
    TCM       ?= 0
    SIM_CFG_DEF  = SCR1_CFG_$(CFG)
endif
export ARCH VECT_IRQ IPIC TCM SIM_CFG_DEF

ARCH_lowercase = $(shell echo $(ARCH) | tr A-Z a-z)
BUS_lowercase  = $(shell echo $(BUS)  | tr A-Z a-z)
ifeq ($(ARCH_lowercase),)
    ARCH_tmp = imc
else
    ARCH_tmp :=
    ifneq (,$(findstring e,$(ARCH_lowercase)))
        ARCH_tmp   := e
        EXT_CFLAGS += -D__RVE_EXT
    else
        ARCH_tmp   := i
    endif
    ifneq (,$(findstring m,$(ARCH_lowercase)))
        ARCH_tmp   := $(ARCH_tmp)m
    endif
    ifneq (,$(findstring f,$(ARCH_lowercase)))
        ARCH_tmp   := $(ARCH_tmp)f
    endif
    ifneq (,$(findstring c,$(ARCH_lowercase)))
        ARCH_tmp   := $(ARCH_tmp)c
        EXT_CFLAGS += -D__RVC_EXT
    endif
    ifneq (,$(findstring b,$(ARCH_lowercase)))
        ARCH_tmp   := $(ARCH_tmp)b
    endif
endif
override ARCH=$(ARCH_tmp)

ifeq ($(TRACE), 1)
    export SIM_TRACE_DEF = SCR1_TRACE_LOG_EN
else
    export SIM_TRACE_DEF = SCR1_TRACE_LOG_DIS
endif

export XLEN  ?= 32
export ABI   ?= ilp32
imem_pattern ?= FFFFFFFF
dmem_pattern ?= FFFFFFFF
VCS_OPTS       ?=
MODELSIM_OPTS  ?=
NCSIM_OPTS     ?=
VERILATOR_OPTS ?=

GCCVERSIONGT7 := $(shell expr `$(detected_gcc_cmd) -dumpfullversion | cut -f1 -d'.'` \> 7)
ifeq "$(GCCVERSIONGT7)" "1"
    ifneq (,$(findstring f,$(ARCH_lowercase)))
        override ABI := ilp32f
    else ifneq (,$(findstring e,$(ARCH_lowercase)))
        override ABI := ilp32e
    endif
endif

# ======================================================================
#   ОПРЕДЕЛЕНИЕ ЦЕЛЕЙ СБОРКИ
# ======================================================================

# Если current_goal не передан извне, вычисляем его сами
ifeq ($(current_goal),)
    PRIMARY_GOALS := run_vcs run_modelsim run_ncsim run_verilator run_verilator_wf \
                     run_vcs_compile run_modelsim_compile run_ncsim_compile \
                     run_verilator_compile run_verilator_wf_compile
    current_primary_goal := $(firstword $(filter-out compile, $(filter $(PRIMARY_GOALS), $(MAKECMDGOALS))))
    ifeq ($(current_primary_goal),)
        current_primary_goal := run_verilator
    endif
    current_goal := $(current_primary_goal:run_%=%)
endif

export root_dir := $(shell pwd)
export tst_dir  := $(root_dir)/sim/tests
export inc_dir  := $(tst_dir)/common
export bld_dir  := $(root_dir)/build/$(current_goal)_$(BUS)_$(CFG)_$(ARCH)_IPIC_$(IPIC)_TCM_$(TCM)_VIRQ_$(VECT_IRQ)_TRACE_$(TRACE)

test_results := $(bld_dir)/test_results.txt
test_info    := $(bld_dir)/test_info
sim_results  := $(bld_dir)/sim_results.txt

ifneq (,$(findstring axi,$(BUS_lowercase)))
    export rtl_top_files := axi_top.files
    export rtl_tb_files  := axi_tb.files
    export top_module    := scr1_top_tb_axi
else
    export rtl_top_files := ahb_top.files
    export rtl_tb_files  := ahb_tb.files
    export top_module    := scr1_top_tb_ahb
endif

# --- Умное формирование списка тестов ---
ALL_TARGETS := riscv_arch isr_sample coremark dhrystone21 hello
ifeq (,$(findstring e,$(ARCH_lowercase)))
    ALL_TARGETS += riscv_isa riscv_compliance
endif
TARGETS ?= $(ALL_TARGETS)
export TARGETS
# --- Конец блока ---

ifneq (,$(findstring e,$(ARCH_lowercase)))
    excluded := riscv_isa riscv_compliance
    excluded := $(filter $(excluded), $(TARGETS))
    $(foreach test,$(excluded),$(warning Warning! $(test) test is not intended to run on an RVE extension, skipping it))
    override TARGETS := $(filter-out $(excluded), $(TARGETS))
endif
ifeq (,$(strip $(TARGETS)))
    $(error Error! No tests included, aborting)
endif

.PHONY: all tests compile clean default \
        run_vcs run_modelsim run_ncsim run_verilator run_verilator_wf \
        run_vcs_compile run_modelsim_compile run_ncsim_compile \
        run_verilator_compile run_verilator_wf_compile

default: clean_test_list run_verilator

all: tests

clean_test_list:
	$(RM) -f $(test_info)

tests: $(TARGETS)

$(test_info): clean_test_list clean_hex tests
	cd $(bld_dir)

# ======================================================================
#   ЦЕЛИ ДЛЯ СБОРКИ ТЕСТОВ
# ======================================================================

isr_sample: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/isr_sample ARCH=$(ARCH) IPIC=$(IPIC) VECT_IRQ=$(VECT_IRQ) ABI=$(ABI) current_goal=$(current_goal)

dhrystone21: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/benchmarks/dhrystone21 EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

coremark: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/benchmarks/coremark EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

riscv_isa: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_isa ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

riscv_compliance: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_compliance ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

riscv_arch: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_arch ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

hello: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/hello EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI) current_goal=$(current_goal)

clean_hex: | $(bld_dir)
	$(RM) $(bld_dir)/*.hex

mips_custom_tests: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/mips_custom_tests

$(bld_dir):
	mkdir -p $(bld_dir)

# ======================================================================
#   ЦЕЛИ ДЛЯ ЗАПУСКА СИМУЛЯЦИИ И КОМПИЛЯЦИИ
# ======================================================================

COMPILE_TOOLS := vcs modelsim ncsim verilator verilator_wf

compile:
	@$(RM) -r $(root_dir)/build/compile_status
	@mkdir -p $(root_dir)/build/compile_status
	@echo "--- Starting full compilation check for all simulators ---"
	@passed_count=0; \
	failed_count=0; \
	for tool in $(COMPILE_TOOLS); do \
		echo ""; \
		echo "=========================================================="; \
		echo "INFO: Checking compilation for: $$tool"; \
		echo "=========================================================="; \
		if $(MAKE) run_$${tool}_compile; then \
			echo "SUCCESS" > $(root_dir)/build/compile_status/$${tool}.status; \
			echo "INFO: $$tool compilation SUCCEEDED."; \
			passed_count=$$((passed_count + 1)); \
		else \
			echo "FAILURE" > $(root_dir)/build/compile_status/$${tool}.status; \
			echo "ERROR: $$tool compilation FAILED."; \
			failed_count=$$((failed_count + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "=========================================================="; \
	echo "               Compilation Summary"; \
	echo "=========================================================="; \
	printf "%-25s | %s\n" "Simulator" "Status"; \
	echo "--------------------------+-----------"; \
	for tool in $(COMPILE_TOOLS); do \
		status=$$(cat $(root_dir)/build/compile_status/$${tool}.status); \
		printf "%-25s | %s\n" "run_$${tool}_compile" "$$status"; \
	done; \
	echo "--------------------------+-----------"; \
	echo "Total Passed: $$passed_count, Total Failed: $$failed_count"; \
	echo "=========================================================="; \
	if [ $$failed_count -ne 0 ]; then \
		echo "ERROR: Some compilations failed."; \
		exit 1; \
	fi

run_vcs: $(test_info)
	$(MAKE) -C $(root_dir)/sim build_vcs SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)";
	printf "" > $(test_results);
	cd $(bld_dir); \
	$(bld_dir)/simv  -V \
	+test_info=$(test_info) \
	+test_results=$(test_results) \
	+imem_pattern=$(imem_pattern) \
	+dmem_pattern=$(dmem_pattern) \
	$(VCS_OPTS) | tee $(sim_results)  ;\
	printf "                          Test               | build | simulation \n" ; \
	printf "$$(cat $(test_results)) \n"

run_modelsim: $(test_info)
	$(MAKE) -C $(root_dir)/sim build_modelsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "Preparing simulation in $(bld_dir)..."
	@printf "" > $(test_results)
	@cd $(bld_dir) && \
	if [ "$(GUI)" = "1" ]; then \
		echo "Starting ModelSim in GUI mode..."; \
		$(MODELSIM) -gui -voptargs="+acc" -do "log -r /*; run -all; " +nowarn3691 \
			+test_info=$(test_info) \
			+test_results=$(test_results) \
			+imem_pattern=$(imem_pattern) \
			+dmem_pattern=$(dmem_pattern) \
			+bld_dir=$(bld_dir) \
			work.$(top_module) \
			$(MODELSIM_OPTS); \
	else \
		echo "Starting ModelSim in batch mode..."; \
		$(MODELSIM) -c -do "run -all; quit -f" +nowarn3691 \
			+test_info=$(test_info) \
			+test_results=$(test_results) \
			+imem_pattern=$(imem_pattern) \
			+dmem_pattern=$(dmem_pattern) \
			+bld_dir=$(bld_dir) \
			work.$(top_module) \
			$(MODELSIM_OPTS) 2>&1 | tee $(sim_results); \
		echo "\nSimulation performed on $$($(MODELSIM) -version)"; \
		echo "--------------------------------------------------"; \
		echo "Test                      | Status  | Time"; \
		echo "--------------------------------------------------"; \
		cat $(test_results) | sed 's/^/| /'; \
		echo "--------------------------------------------------"; \
	fi

run_ncsim: $(test_info)
	$(MAKE) -C $(root_dir)/sim build_ncsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)";
	printf "" > $(test_results);
	cd $(bld_dir); \
	irun \
	-R \
	-64bit \
	+test_info=$(test_info) \
	+test_results=$(test_results) \
	+imem_pattern=$(imem_pattern) \
	+dmem_pattern=$(dmem_pattern) \
	$(NCSIM_OPTS) | tee $(sim_results)  ;\
	printf "Simulation performed on $$(irun -version) \n" ;\
	printf "                          Test               | build | simulation \n" ; \
	printf "$$(cat $(test_results)) \n"

run_verilator: $(test_info)
	$(MAKE) -C $(root_dir)/sim build_verilator SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)";
	printf "" > $(test_results);
	cd $(bld_dir); \
	echo $(top_module) | tee $(sim_results); \
	$(bld_dir)/verilator/V$(top_module) \
	+test_info=$(test_info) \
	+test_results=$(test_results) \
	+imem_pattern=$(imem_pattern) \
	+dmem_pattern=$(dmem_pattern) \
	$(VERILATOR_OPTS) | tee -a $(sim_results) ;\
	printf "Simulation performed on $$(verilator -version) \n" ;\
	printf "                          Test               | build | simulation \n" ; \
	printf "$$(cat $(test_results)) \n"

run_verilator_wf: $(test_info)
	$(MAKE) -C $(root_dir)/sim build_verilator_wf SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)";
	printf "" > $(test_results);
	cd $(bld_dir); \
	echo $(top_module) | tee $(sim_results); \
	$(bld_dir)/verilator/V$(top_module) \
	+test_info=$(test_info) \
	+test_results=$(test_results) \
	+imem_pattern=$(imem_pattern) \
	+dmem_pattern=$(dmem_pattern) \
	$(VERILATOR_OPTS) | tee -a $(sim_results)  ;\
	printf "Simulation performed on $$(verilator -version) \n" ;\
	printf "                          Test               | build | simulation \n" ; \
	printf "$$(cat $(test_results)) \n"

run_vcs_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for VCS..."
	$(MAKE) -C $(root_dir)/sim build_vcs SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: VCS compilation check finished successfully."

run_modelsim_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for ModelSim..."
	$(MAKE) -C $(root_dir)/sim build_modelsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: ModelSim compilation check finished successfully."

run_ncsim_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for NCSim (irun)..."
	$(MAKE) -C $(root_dir)/sim build_ncsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: NCSim compilation check finished successfully."

run_verilator_compile: | $(bld_dir)
	@echo "INFO: Compiling the project with Verilator..."
	$(MAKE) -C $(root_dir)/sim build_verilator SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: Verilator compilation check finished successfully."

run_verilator_wf_compile: | $(bld_dir)
	@echo "INFO: Compiling the project with Verilator (waveform enabled)..."
	$(MAKE) -C $(root_dir)/sim build_verilator_wf SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: Verilator (waveform) compilation check finished successfully."

clean:
	$(RM) -R $(root_dir)/build/*