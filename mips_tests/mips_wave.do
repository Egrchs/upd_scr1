# =====================================================================
# ModelSim/QuestaSim .do файл для отладки MIPS-to-RISC-V
# транслятора и ядра SCR1 (Версия 7 - исправлен синтаксис add wave)
# =====================================================================

onerror {resume}
configure wave -signalnamewidth 1

if {[file exists "wave.wlf"]} {
    echo "Deleting existing wave.wlf"
    file delete -force "wave.wlf"
}
echo "Starting WLF logging to wave.wlf"
log /scr1_top_tb_axi/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/u_mips_translator/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_ifu/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_idu/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_exu/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_exu/i_ialu/*
log -r /scr1_top_tb_axi/i_top/i_core_top/i_pipe_top/i_pipe_mprf/*

delete wave *

# --- Пути к основным модулям ---
set tb_path          /scr1_top_tb_axi
set core_path        $tb_path/i_top/i_core_top
set pipe_top_path    $core_path/i_pipe_top
set translator_path  $pipe_top_path/u_mips_translator
set ifu_path         $pipe_top_path/i_pipe_ifu
set idu_path         $pipe_top_path/i_pipe_idu
set exu_path         $pipe_top_path/i_pipe_exu
set ialu_path        $exu_path/i_ialu
set mprf_path        $pipe_top_path/i_pipe_mprf

# -----------------------------------------
# Группа: TB Control & Status
# -----------------------------------------
add wave -group "TB Control & Status" $tb_path/clk
add wave -group "TB Control & Status" $tb_path/rst_n
add wave -group "TB Control & Status" $tb_path/test_file
add wave -group "TB Control & Status" $tb_path/test_running
add wave -group "TB Control & Status" $tb_path/tests_passed
add wave -group "TB Control & Status" $tb_path/tests_total
add wave -group "TB Control & Status" $pipe_top_path/curr_pc

# -----------------------------------------
# Группа: MIPS Input (IFU Out to Translator)
# -----------------------------------------
add wave -group "MIPS Input (IFU Out to Translator)" $pipe_top_path/ifu2idu_vd
add wave -group "MIPS Input (IFU Out to Translator)" $pipe_top_path/ifu2idu_instr
add wave -group "MIPS Input (IFU Out to Translator)" $pipe_top_path/ifu2idu_imem_err
add wave -group "MIPS Input (IFU Out to Translator)" $pipe_top_path/ifu2idu_err_rvi_hi
add wave -group "MIPS Input (IFU Out to Translator)" $pipe_top_path/idu2ifu_rdy

# -----------------------------------------
# Группа: Translator (MIPS -> RISC-V)
# -----------------------------------------
add wave -group "Translator - IO" $translator_path/mips_instruction
add wave -group "Translator - IO" $translator_path/mips_instr_valid
add wave -group "Translator - IO" $translator_path/mips_instr_error
add wave -group "Translator - IO" $translator_path/translator_ready
add wave -group "Translator - IO" $translator_path/riscv_instruction
add wave -group "Translator - IO" $translator_path/riscv_instr_valid
add wave -group "Translator - IO" $translator_path/riscv_instr_error
add wave -group "Translator - IO" $translator_path/riscv_instr_accepted
add wave -group "Translator - State" -radix symbolic $translator_path/state_reg
add wave -group "Translator - State" -radix symbolic $translator_path/state_next
add wave -group "Translator - Internal Data" -radix hex $translator_path/stashed_instr_reg
add wave -group "Translator - Internal Data" -radix hex $translator_path/mips_instr_reg
add wave -group "Translator - Internal Data" -radix hex $translator_path/opt_lui_instr_reg
add wave -group "Translator - Internal Data" -radix hex $translator_path/opt_addi_instr_reg

# -----------------------------------------
# Группа: RISC-V to IDU (Translator Out)
# -----------------------------------------
add wave -group "RISC-V to IDU (Translator Out)" $pipe_top_path/translator2idu_vd
add wave -group "RISC-V to IDU (Translator Out)" $pipe_top_path/translator2idu_instr
add wave -group "RISC-V to IDU (Translator Out)" $pipe_top_path/translator2idu_imem_err

# -----------------------------------------
# Группа: IDU (Decode Stage)
# -----------------------------------------
add wave -group "IDU - Input from Translator" $idu_path/ifu2idu_vd_i
add wave -group "IDU - Input from Translator" $idu_path/ifu2idu_instr_i
add wave -group "IDU - Input from Translator" $idu_path/ifu2idu_imem_err_i
add wave -group "IDU - Output Command to EXU (Structure)" $idu_path/idu2exu_cmd_o
add wave -group "IDU - Control to EXU" $idu_path/idu2exu_req_o
add wave -group "IDU - Control to EXU" $idu_path/idu2exu_use_rs1_o
add wave -group "IDU - Control to EXU" $idu_path/idu2exu_use_rs2_o
add wave -group "IDU - Control to EXU" $idu_path/exu2idu_rdy_i

# -----------------------------------------
# Группа: EXU (Execute Stage)
# -----------------------------------------
add wave -group "EXU - PC Control" -radix hex $pipe_top_path/curr_pc
add wave -group "EXU - PC Control" -radix hex $pipe_top_path/next_pc
add wave -group "EXU - PC Control" -radix hex $pipe_top_path/new_pc
add wave -group "EXU - PC Control" $pipe_top_path/new_pc_req
add wave -group "EXU - Input Command from IDU (Structure)" $exu_path/idu2exu_req_i
add wave -group "EXU - Input Command from IDU (Structure)" $exu_path/idu2exu_cmd_i
add wave -group "EXU - Control Signals" $exu_path/exu2idu_rdy_o
add wave -group "EXU - Control Signals" $exu_path/exu_queue_vd
# --- EXU Data fed to IALU ---
add wave -group "EXU - Data fed to IALU (Operands)" -radix hex $exu_path/ialu_main_op1
add wave -group "EXU - Data fed to IALU (Operands)" -radix hex $exu_path/ialu_main_op2
# Добавляем структуру exu_queue, чтобы потом в GUI найти поле .ialu_cmd
add wave -group "EXU - EXU Queue Structure (for IALU cmd)" $exu_path/exu_queue
# --- EXU Data for MPRF/DMEM Write & Exceptions ---
add wave -group "EXU - Data for MPRF Write" -radix dec $exu_path/exu2mprf_rd_addr_o
add wave -group "EXU - Data for MPRF Write" -radix hex $exu_path/exu2mprf_rd_data_o
add wave -group "EXU - Data for DMEM Write" -radix hex $exu_path/exu2dmem_addr_o
add wave -group "EXU - Data for DMEM Write" -radix hex $exu_path/exu2dmem_wdata_o
add wave -group "EXU - Exceptions" $exu_path/exu_exc_req
add wave -group "EXU - Exceptions" $exu_path/exu2csr_exc_code_o

# -----------------------------------------
# Группа: IALU (Integer ALU - внутри EXU/i_ialu)
# -----------------------------------------
add wave -group "IALU - Inputs" -radix hex $ialu_path/exu2ialu_main_op1_i
add wave -group "IALU - Inputs" -radix hex $ialu_path/exu2ialu_main_op2_i
add wave -group "IALU - Command" -radix symbolic $ialu_path/exu2ialu_cmd_i
add wave -group "IALU - Results" -radix hex $ialu_path/ialu2exu_main_res_o
add wave -group "IALU - Results" -radix hex $ialu_path/ialu2exu_addr_res_o
add wave -group "IALU - Results" $ialu_path/ialu2exu_cmp_res_o
# Сигналы RVM (Mul/Div)
add wave -group "IALU - RVM (Mul/Div)" $ialu_path/exu2ialu_rvm_cmd_vd_i
add wave -group "IALU - RVM (Mul/Div)" $ialu_path/ialu2exu_rvm_res_rdy_o
add wave -group "IALU - RVM (Mul/Div)" -radix symbolic $ialu_path/mdu_fsm_ff

# -----------------------------------------
# Группа: MPRF (Register File)
# -----------------------------------------
add wave -group "MPRF - Write Port" $mprf_path/exu2mprf_w_req_i
add wave -group "MPRF - Write Port" -radix dec $mprf_path/exu2mprf_rd_addr_i
add wave -group "MPRF - Write Port" -radix hex $mprf_path/exu2mprf_rd_data_i
add wave -group "MPRF - Read Port 1" -radix dec $mprf_path/exu2mprf_rs1_addr_i
add wave -group "MPRF - Read Port 1" -radix hex $mprf_path/mprf2exu_rs1_data_o
add wave -group "MPRF - Read Port 2" -radix dec $mprf_path/exu2mprf_rs2_addr_i
add wave -group "MPRF - Read Port 2" -radix hex $mprf_path/mprf2exu_rs2_data_o
add wave -group "MPRF - Internal Registers Array" -radix hex $mprf_path/mprf_int

# -----------------------------------------
# Группа: DMEM Interface (Memory Operations)
# -----------------------------------------
add wave -group "DMEM - Request" $pipe_top_path/pipe2dmem_req_o
add wave -group "DMEM - Request" $pipe_top_path/pipe2dmem_cmd_o
add wave -group "DMEM - Request" $pipe_top_path/pipe2dmem_width_o
add wave -group "DMEM - Request" -radix hex $pipe_top_path/pipe2dmem_addr_o
add wave -group "DMEM - Request" -radix hex $pipe_top_path/pipe2dmem_wdata_o
add wave -group "DMEM - Response" $pipe_top_path/dmem2pipe_req_ack_i
add wave -group "DMEM - Response" -radix hex $pipe_top_path/dmem2pipe_rdata_i
add wave -group "DMEM - Response" $pipe_top_path/dmem2pipe_resp_i

echo "To run simulation, type: run -all (or specific time, e.g., run 1us)"
echo "Then, to update waveform, type: wave zoom full"