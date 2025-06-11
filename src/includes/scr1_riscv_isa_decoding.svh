/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_riscv_isa_decoding.svh>
/// @brief      RISC-V ISA definitions file

`ifndef SCR1_RISCV_ISA_DECODING_SVH
`define SCR1_RISCV_ISA_DECODING_SVH

`include "scr1_arch_description.svh"
`include "scr1_arch_types.svh"

//-------------------------------------------------------------------------------
// Instruction types
//-------------------------------------------------------------------------------
typedef enum logic [1:0] {
    SCR1_INSTR_RVC0     = 2'b00,
    SCR1_INSTR_RVC1     = 2'b01,
    SCR1_INSTR_RVC2     = 2'b10,
    SCR1_INSTR_RVI      = 2'b11
} type_scr1_instr_type_e;

//-------------------------------------------------------------------------------
// RV32I opcodes (bits 6:2)
//-------------------------------------------------------------------------------
typedef enum logic [6:2] {
    SCR1_OPCODE_LOAD        = 5'b00000,
    SCR1_OPCODE_LOAD_FP     = 5'b00001, // [MODIFIED]
    SCR1_OPCODE_MISC_MEM    = 5'b00011,
    SCR1_OPCODE_OP_IMM      = 5'b00100,
    SCR1_OPCODE_AUIPC       = 5'b00101,
    SCR1_OPCODE_STORE       = 5'b01000,
    SCR1_OPCODE_STORE_FP    = 5'b01001, // [MODIFIED]
    SCR1_OPCODE_OP          = 5'b01100,
    SCR1_OPCODE_LUI         = 5'b01101,
    SCR1_OPCODE_OP_FP       = 5'b10100, // [MODIFIED]
    SCR1_OPCODE_BRANCH      = 5'b11000,
    SCR1_OPCODE_JALR        = 5'b11001,
    SCR1_OPCODE_JAL         = 5'b11011,
    SCR1_OPCODE_SYSTEM      = 5'b11100
} type_scr1_rvi_opcode_e;


//-------------------------------------------------------------------------------
// IALU main operands
//-------------------------------------------------------------------------------
localparam SCR1_IALU_OP_ALL_NUM_E = 2;
localparam SCR1_IALU_OP_WIDTH_E   = $clog2(SCR1_IALU_OP_ALL_NUM_E);
typedef enum logic [SCR1_IALU_OP_WIDTH_E-1:0] {
    SCR1_IALU_OP_REG_IMM,
    SCR1_IALU_OP_REG_REG
} type_scr1_ialu_op_sel_e;

//-------------------------------------------------------------------------------
// IALU main commands
//-------------------------------------------------------------------------------
`ifdef SCR1_RVM_EXT
localparam SCR1_IALU_CMD_ALL_NUM_E    = 23;
`else
localparam SCR1_IALU_CMD_ALL_NUM_E    = 15;
`endif
localparam SCR1_IALU_CMD_WIDTH_E      = $clog2(SCR1_IALU_CMD_ALL_NUM_E);
typedef enum logic [SCR1_IALU_CMD_WIDTH_E-1:0] {
    SCR1_IALU_CMD_NONE  = '0, SCR1_IALU_CMD_AND, SCR1_IALU_CMD_OR, SCR1_IALU_CMD_XOR,
    SCR1_IALU_CMD_ADD, SCR1_IALU_CMD_SUB, SCR1_IALU_CMD_SUB_LT, SCR1_IALU_CMD_SUB_LTU,
    SCR1_IALU_CMD_SUB_EQ, SCR1_IALU_CMD_SUB_NE, SCR1_IALU_CMD_SUB_GE, SCR1_IALU_CMD_SUB_GEU,
    SCR1_IALU_CMD_SLL, SCR1_IALU_CMD_SRL, SCR1_IALU_CMD_SRA
`ifdef SCR1_RVM_EXT
    , SCR1_IALU_CMD_MUL, SCR1_IALU_CMD_MULHU, SCR1_IALU_CMD_MULHSU, SCR1_IALU_CMD_MULH,
    SCR1_IALU_CMD_DIV, SCR1_IALU_CMD_DIVU, SCR1_IALU_CMD_REM, SCR1_IALU_CMD_REMU
`endif
} type_scr1_ialu_cmd_sel_e;

//-------------------------------------------------------------------------------
// IALU SUM2 operands
//-------------------------------------------------------------------------------
localparam SCR1_SUM2_OP_ALL_NUM_E    = 2;
localparam SCR1_SUM2_OP_WIDTH_E      = $clog2(SCR1_SUM2_OP_ALL_NUM_E);
typedef enum logic [SCR1_SUM2_OP_WIDTH_E-1:0] {
    SCR1_SUM2_OP_PC_IMM,
    SCR1_SUM2_OP_REG_IMM
} type_scr1_ialu_sum2_op_sel_e;

//-------------------------------------------------------------------------------
// LSU commands
//-------------------------------------------------------------------------------
`ifdef SCR1_RVF_EXT
    localparam SCR1_LSU_CMD_ALL_NUM_E   = 11;
`else
    localparam SCR1_LSU_CMD_ALL_NUM_E   = 9;
`endif
localparam SCR1_LSU_CMD_WIDTH_E     = $clog2(SCR1_LSU_CMD_ALL_NUM_E);
typedef enum logic [SCR1_LSU_CMD_WIDTH_E-1:0] {
    SCR1_LSU_CMD_NONE, SCR1_LSU_CMD_LB, SCR1_LSU_CMD_LH, SCR1_LSU_CMD_LW,
    SCR1_LSU_CMD_LBU, SCR1_LSU_CMD_LHU, SCR1_LSU_CMD_SB, SCR1_LSU_CMD_SH, SCR1_LSU_CMD_SW
    `ifdef SCR1_RVF_EXT
    , LSU_CMD_FLW, LSU_CMD_FSW
    `endif
} type_scr1_lsu_cmd_sel_e;

//-------------------------------------------------------------------------------
// CSR operands and commands
//-------------------------------------------------------------------------------
typedef enum logic { SCR1_CSR_OP_IMM, SCR1_CSR_OP_REG } type_scr1_csr_op_sel_e;
typedef enum logic [1:0] { SCR1_CSR_CMD_NONE, SCR1_CSR_CMD_WRITE, SCR1_CSR_CMD_SET, SCR1_CSR_CMD_CLEAR } type_scr1_csr_cmd_sel_e;

//-------------------------------------------------------------------------------
// MPRF/FPRF rd writeback source
//-------------------------------------------------------------------------------
`ifdef SCR1_RVF_EXT
    localparam SCR1_RD_WB_ALL_NUM_E = 8;
`else
    localparam SCR1_RD_WB_ALL_NUM_E = 7;
`endif
localparam SCR1_RD_WB_WIDTH_E   = $clog2(SCR1_RD_WB_ALL_NUM_E);
typedef enum logic [SCR1_RD_WB_WIDTH_E-1:0] {
    SCR1_RD_WB_NONE, SCR1_RD_WB_IALU, SCR1_RD_WB_SUM2, SCR1_RD_WB_IMM,
    SCR1_RD_WB_INC_PC, SCR1_RD_WB_LSU, SCR1_RD_WB_CSR
    `ifdef SCR1_RVF_EXT
    , SCR1_RD_WB_FPU
    `endif
} type_scr1_rd_wb_sel_e;

`ifdef SCR1_RVF_EXT
// FPU commands
typedef enum logic [3:0] {
    FPU_CMD_NONE, FPU_CMD_ADD, FPU_CMD_SUB, FPU_CMD_MUL, FPU_CMD_DIV, FPU_CMD_SQRT,
    FPU_CMD_SGNJ, FPU_CMD_MINMAX, FPU_CMD_CVT_F_I, FPU_CMD_CVT_I_F, FPU_CMD_CMP,
    FPU_CMD_CLASS, FPU_CMD_MV_X_F, FPU_CMD_MV_F_X
} type_scr1_fpu_cmd_e;
`endif

//-------------------------------------------------------------------------------
// IDU to EXU full command structure
//-------------------------------------------------------------------------------
localparam SCR1_GPR_FIELD_WIDTH = 5;

typedef struct packed {
    logic                               instr_rvc;
    type_scr1_ialu_op_sel_e             ialu_op;
    type_scr1_ialu_cmd_sel_e            ialu_cmd;
    type_scr1_ialu_sum2_op_sel_e        sum2_op;
    type_scr1_lsu_cmd_sel_e             lsu_cmd;
    type_scr1_csr_op_sel_e              csr_op;
    type_scr1_csr_cmd_sel_e             csr_cmd;
    type_scr1_rd_wb_sel_e               rd_wb_sel;
    logic                               jump_req;
    logic                               branch_req;
    logic                               mret_req;
    logic                               fencei_req;
    logic                               wfi_req;
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rs1_addr;
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rs2_addr;
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rd_addr;
    logic [`SCR1_XLEN-1:0]              imm;
    logic                               exc_req;
    type_scr1_exc_code_e                exc_code;

    `ifdef SCR1_RVF_EXT
    logic                               is_fp_op;
    type_scr1_fpu_cmd_e                 fpu_cmd;
    logic [2:0]                         fpu_rm;
    logic [4:0]                         rs3_addr;
    `endif
} type_scr1_exu_cmd_s;

`endif // SCR1_RISCV_ISA_DECODING_SVH
