#------------------------------------------------------------------------------
# Makefile for SCR1
#------------------------------------------------------------------------------


# ======================================================================
#   АВТОМАТИЧЕСКОЕ ОПРЕДЕЛЕНИЕ ПУТЕЙ
# ======================================================================
# Используем shell-команды для поиска путей. Работает в системах на базе Debian.
INCLUDE_PATH := $(shell dpkg -L picolibc-riscv64-unknown-elf 2>/dev/null | grep '/include/string.h$$' | head -n 1 | xargs -r dirname)
LIB_C_PATH   := $(shell dpkg -L picolibc-riscv64-unknown-elf 2>/dev/null | grep '/rv32imac/ilp32/libc.a$$' | head -n 1 | xargs -r dirname)
LIB_GCC_PATH := $(shell dpkg -L gcc-riscv64-unknown-elf 2>/dev/null | grep '/rv32imac/ilp32/libgcc.a$$' | head -n 1 | xargs -r dirname)

# Проверяем, что все пути были найдены. Если нет - останавливаемся с ошибкой.
ifeq ($(INCLUDE_PATH),)
  $(error "ERROR: Could not find picolibc include path. Please run: sudo apt install picolibc-riscv64-unknown-elf")
endif
ifeq ($(LIB_C_PATH),)
  $(error "ERROR: Could not find 32-bit picolibc library path. Please run: sudo apt install picolibc-riscv64-unknown-elf")
endif
ifeq ($(LIB_GCC_PATH),)
  $(error "ERROR: Could not find 32-bit gcc library path. Please run: sudo apt install gcc-riscv64-unknown-elf")
endif

# Экспортируем переменные, чтобы они были доступны в дочерних Make-файлах
export LIB_C_PATH
export LIB_GCC_PATH
# ======================================================================

# Detect WSL and set proper executables
ifeq ($(shell uname -r | grep -i microsoft),)
    # Regular Linux
    $(info Detected regular Linux environment, using non-.exe commands)
    VLIB     := vlib
    VMAP     := vmap
    VLOG     := vlog
    MODELSIM := vsim
else
    # WSL environment
    $(info Detected WSL environment, using .exe commands)
    VLIB     := vlib.exe
    VMAP     := vmap.exe
    VLOG     := vlog.exe
    MODELSIM := vsim.exe
endif

# Export these variables so they're available in sub-makes
export VLIB
export VMAP
export VLOG
export MODELSIM

GUI ?= 0

# --- [MIPS] ПАРАМЕТР ДЛЯ УПРАВЛЕНИЯ ТРАНСЛЯТОРОМ ---
MIPS ?= 0

# PARAMETERS
# CFG = <MAX, BASE, MIN, CUSTOM>
# BUS = <AHB, AXI>
export CFG      ?= MAX
export BUS      ?= AHB

ifeq ($(CFG), MAX)
# Predefined configuration SCR1_CFG_RV32IMC_MAX
    override ARCH         := IMC
    override VECT_IRQ     := 1
    override IPIC         := 1
    override TCM          := 1
    override SIM_CFG_DEF  := SCR1_CFG_RV32IMC_MAX
else ifeq ($(CFG), BASE)
    # Predefined configuration SCR1_CFG_RV32IC_BASE
        override ARCH         := IC
        override VECT_IRQ     := 1
        override IPIC         := 1
        override TCM          := 1
        override SIM_CFG_DEF  := SCR1_CFG_RV32IC_BASE
else ifeq ($(CFG), MIN)
    # Predefined configuration SCR1_CFG_RV32EC_MIN
        override ARCH         := EC
        override VECT_IRQ     := 0
        override IPIC         := 0
        override TCM          := 1
        override SIM_CFG_DEF  := SCR1_CFG_RV32EC_MIN
else
    # CUSTOM configuration. Parameters can be overwritten
    ARCH      ?= IMC
    VECT_IRQ  ?= 0
    IPIC      ?= 0
    TCM       ?= 0
    SIM_CFG_DEF  = SCR1_CFG_$(CFG)
endif

# export all overrided variables
export ARCH
export VECT_IRQ
export IPIC
export TCM
export SIM_CFG_DEF

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

TRACE ?= 0
ifeq ($(TRACE), 1)
    export SIM_TRACE_DEF = SCR1_TRACE_LOG_EN
else
    export SIM_TRACE_DEF = SCR1_TRACE_LOG_DIS
endif

SIM_BUILD_OPTS ?=
ifneq ($(shell uname -r | grep -i microsoft),)
	ifeq ($(findstring modelsim,$(MAKECMDGOALS)),modelsim)
		SIM_BUILD_OPTS += +define+USE_WSL_WRAPPER
    endif
endif

# --- [MIPS] ДОБАВЛЕНИЕ ДЕФАЙНА USE_TRANSLATOR ---
ifeq ($(MIPS), 1)
    SIM_BUILD_OPTS += +define+USE_TRANSLATOR=1
endif

export XLEN  ?= 32
export ABI   ?= ilp32
imem_pattern ?= FFFFFFFF
dmem_pattern ?= FFFFFFFF
VCS_OPTS       ?=
MODELSIM_OPTS  ?=
NCSIM_OPTS     ?=
VERILATOR_OPTS ?=

# --- ЛОГИКА ОПРЕДЕЛЕНИЯ ПУТИ СБОРКИ ---
PRIMARY_GOALS := run_vcs run_modelsim run_ncsim run_verilator run_verilator_wf \
                 run_vcs_compile run_modelsim_compile run_ncsim_compile \
                 run_verilator_compile run_verilator_wf_compile
current_primary_goal := $(firstword $(filter-out compile, $(filter $(PRIMARY_GOALS), $(MAKECMDGOALS))))
ifeq ($(current_primary_goal),)
    current_primary_goal := run_verilator
endif
current_goal := $(current_primary_goal:run_%=%)

# Paths
export root_dir := $(shell pwd)
export tst_dir  := $(root_dir)/sim/tests
# --- [MIPS] НОВЫЙ ПУТЬ К MIPS ТЕСТАМ ---
export mips_tst_dir := $(root_dir)/mips_tests
export inc_dir  := $(tst_dir)/common
# --- [MIPS] ПУТЬ СБОРКИ ТЕПЕРЬ ЗАВИСИТ ОТ MIPS ---
export bld_dir  := $(root_dir)/build/$(current_goal)_$(BUS)_$(CFG)_$(ARCH)_IPIC_$(IPIC)_TCM_$(TCM)_VIRQ_$(VECT_IRQ)_TRACE_$(TRACE)_MIPS_$(MIPS)

test_results := $(bld_dir)/test_results.txt
test_info    := $(bld_dir)/test_info
sim_results  := $(bld_dir)/sim_results.txt
todo_list    := $(bld_dir)/todo.txt

# Environment
export CROSS_PREFIX  ?= riscv64-unknown-elf-
export RISCV_GCC     := $(CROSS_PREFIX)gcc -I$(INCLUDE_PATH)
export RISCV_OBJDUMP ?= $(CROSS_PREFIX)objdump -D
export RISCV_OBJCOPY ?= $(CROSS_PREFIX)objcopy -O verilog
export RISCV_READELF ?= $(CROSS_PREFIX)readelf -s

ifneq (,$(findstring axi,$(BUS_lowercase)))
export rtl_top_files := axi_top.files
export rtl_tb_files  := axi_tb.files
export top_module    := scr1_top_tb_axi
else
export rtl_top_files := ahb_top.files
export rtl_tb_files  := ahb_tb.files
export top_module    := scr1_top_tb_ahb
endif

# --- [MIPS] ЛОГИКА ВЫБОРА ТЕСТОВ ---
ifeq ($(MIPS), 1)
    # Если включен режим MIPS, запускаем только MIPS тесты
    TARGETS ?= mips_tests
else
    # Оригинальная логика выбора RISC-V тестов
    TARGETS ?= riscv_isa riscv_compliance riscv_arch isr_sample coremark dhrystone21 hello
endif
export TARGETS

# When RVE extension is on, we want to exclude some tests, even if they are given from the command line
ifneq ($(MIPS), 1)
    ifneq (,$(findstring e,$(ARCH_lowercase)))
        excluded := riscv_isa riscv_compliance
        excluded := $(filter $(excluded), $(TARGETS))
        $(foreach test,$(excluded),$(warning Warning! $(test) test is not intended to run on an RVE extension, skipping it))
        override TARGETS := $(filter-out $(excluded), $(TARGETS))
    endif
endif

ifeq (,$(strip $(TARGETS)))
    $(error Error! No tests included, aborting)
endif

# Targets
.PHONY: tests compile \
        run_vcs run_modelsim run_ncsim run_verilator run_verilator_wf \
        run_vcs_compile run_modelsim_compile run_ncsim_compile \
        run_verilator_compile run_verilator_wf_compile \
        mips_tests # --- [MIPS] Добавляем цель в .PHONY

default: clean_test_list run_verilator

clean_test_list:
	rm -f $(test_info)

echo_out: tests
	@echo "                          Test               | build | simulation " ;
	@echo "$$(cat $(test_results))"

tests: $(TARGETS)

$(test_info): clean_test_list clean_hex tests
	cd $(bld_dir)

isr_sample: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/isr_sample ARCH=$(ARCH) IPIC=$(IPIC) VECT_IRQ=$(VECT_IRQ) ABI=$(ABI)

dhrystone21: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/benchmarks/dhrystone21 EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI)

coremark: | $(bld_dir)
	-$(MAKE) -C $(tst_dir)/benchmarks/coremark EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI)

riscv_isa: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_isa ARCH=$(ARCH) ABI=$(ABI)

riscv_compliance: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_compliance ARCH=$(ARCH) ABI=$(ABI)

riscv_arch: | $(bld_dir)
	$(MAKE) -C $(tst_dir)/riscv_arch ARCH=$(ARCH) ABI=$(ABI)

hello: | $(bld_dir)
	-$(MAKE) -C $(tst_dir)/hello EXT_CFLAGS="$(EXT_CFLAGS)" ARCH=$(ARCH) ABI=$(ABI)

clean_hex: | $(bld_dir)
	$(RM) $(bld_dir)/*.hex

# --- [MIPS] НОВАЯ ЦЕЛЬ ДЛЯ СБОРКИ MIPS-ТЕСТОВ ---
mips_tests: | $(bld_dir)
	@echo ">>> Building MIPS tests..."
	$(MAKE) -C $(mips_tst_dir) BUILD_DIR=$(bld_dir)
	@ls -1 $(bld_dir)/*.hex | xargs -n 1 basename > $(test_info)
	@echo ">>> MIPS test list created in $(test_info)"

$(bld_dir):
	mkdir -p $(bld_dir)

#==============================================================================
# Meta-Targets (NEW SECTION)
#==============================================================================
# ... (Блок Meta-Targets без изменений) ...
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

#==============================================================================
# Run Targets (Compile + Simulate)
#==============================================================================
# ... (Блоки run_vcs, run_modelsim и т.д. без изменений) ...
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

#==============================================================================
# Compile-Only Targets
#==============================================================================
# ... (Блок Compile-Only Targets без изменений) ...
run_vcs_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for VCS..."
	$(MAKE) -C $(root_dir)/sim build_vcs SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: VCS compilation check finished successfully."
	@echo "INFO: Compiled artifacts can be found in $(bld_dir)"

run_modelsim_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for ModelSim..."
	$(MAKE) -C $(root_dir)/sim build_modelsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: ModelSim compilation check finished successfully."
	@echo "INFO: Compiled library can be found in $(bld_dir)"

run_ncsim_compile: | $(bld_dir)
	@echo "INFO: Compiling the project for NCSim (irun)..."
	$(MAKE) -C $(root_dir)/sim build_ncsim SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: NCSim compilation check finished successfully."
	@echo "INFO: Compiled artifacts can be found in $(bld_dir)"

run_verilator_compile: | $(bld_dir)
	@echo "INFO: Compiling the project with Verilator..."
	$(MAKE) -C $(root_dir)/sim build_verilator SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: Verilator compilation check finished successfully."
	@echo "INFO: Compiled executable can be found in $(bld_dir)/verilator/"

run_verilator_wf_compile: | $(bld_dir)
	@echo "INFO: Compiling the project with Verilator (waveform enabled)..."
	$(MAKE) -C $(root_dir)/sim build_verilator_wf SIM_CFG_DEF=$(SIM_CFG_DEF) SIM_TRACE_DEF=$(SIM_TRACE_DEF) SIM_BUILD_OPTS="$(SIM_BUILD_OPTS)"
	@echo "INFO: Verilator (waveform) compilation check finished successfully."
	@echo "INFO: Compiled executable can be found in $(bld_dir)/verilator/"

#==============================================================================

clean:
	$(RM) -R $(root_dir)/build/*
	# --- [MIPS] Добавлена очистка MIPS тестов ---
	-$(MAKE) -C $(mips_tst_dir) clean 2>/dev/null || true