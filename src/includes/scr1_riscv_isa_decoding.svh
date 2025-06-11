/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_riscv_isa_decoding.svh>
/// @brief      RISC-V ISA definitions file
///

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
    SCR1_OPCODE_MISC_MEM    = 5'b00011,
    SCR1_OPCODE_OP_IMM      = 5'b00100,
    SCR1_OPCODE_AUIPC       = 5'b00101,
    SCR1_OPCODE_STORE       = 5'b01000,
    SCR1_OPCODE_OP          = 5'b01100,
    SCR1_OPCODE_LUI         = 5'b01101,
    SCR1_OPCODE_BRANCH      = 5'b11000,
    SCR1_OPCODE_JALR        = 5'b11001,
    SCR1_OPCODE_JAL         = 5'b11011,
    SCR1_OPCODE_SYSTEM      = 5'b11100,
    SCR1_OPCODE_FP          = 5'b10100
} type_scr1_rvi_opcode_e;


//-------------------------------------------------------------------------------
// IALU main operands
//-------------------------------------------------------------------------------
localparam SCR1_IALU_OP_ALL_NUM_E = 2;
localparam SCR1_IALU_OP_WIDTH_E   = $clog2(SCR1_IALU_OP_ALL_NUM_E);
typedef enum logic [SCR1_IALU_OP_WIDTH_E-1:0] {
    SCR1_IALU_OP_REG_IMM,          // op1 = rs1; op2 = imm
    SCR1_IALU_OP_REG_REG           // op1 = rs1; op2 = rs2
} type_scr1_ialu_op_sel_e;

//-------------------------------------------------------------------------------
// IALU main commands
//-------------------------------------------------------------------------------
`ifdef SCR1_RVM_EXT
localparam SCR1_IALU_CMD_ALL_NUM_E    = 23;
`else // ~SCR1_RVM_EXT
localparam SCR1_IALU_CMD_ALL_NUM_E    = 15;
`endif // ~SCR1_RVM_EXT
localparam SCR1_IALU_CMD_WIDTH_E      = $clog2(SCR1_IALU_CMD_ALL_NUM_E+16);
typedef enum logic [SCR1_IALU_CMD_WIDTH_E-1:0] {
    SCR1_IALU_CMD_NONE  = '0,   // IALU disable
    SCR1_IALU_CMD_AND,          // op1 & op2
    SCR1_IALU_CMD_OR,           // op1 | op2
    SCR1_IALU_CMD_XOR,          // op1 ^ op2
    SCR1_IALU_CMD_ADD,          // op1 + op2
    SCR1_IALU_CMD_SUB,          // op1 - op2
    SCR1_IALU_CMD_SUB_LT,       // op1 < op2
    SCR1_IALU_CMD_SUB_LTU,      // op1 u< op2
    SCR1_IALU_CMD_SUB_EQ,       // op1 = op2
    SCR1_IALU_CMD_SUB_NE,       // op1 != op2
    SCR1_IALU_CMD_SUB_GE,       // op1 >= op2
    SCR1_IALU_CMD_SUB_GEU,      // op1 u>= op2
    SCR1_IALU_CMD_SLL,          // op1 << op2
    SCR1_IALU_CMD_SRL,          // op1 >> op2
    SCR1_IALU_CMD_SRA          // op1 >>> op2
`ifdef SCR1_RVM_EXT
    ,
    SCR1_IALU_CMD_MUL,          // low(unsig(op1) * unsig(op2))
    SCR1_IALU_CMD_MULHU,        // high(unsig(op1) * unsig(op2))
    SCR1_IALU_CMD_MULHSU,       // high(op1 * unsig(op2))
    SCR1_IALU_CMD_MULH,         // high(op1 * op2)
    SCR1_IALU_CMD_DIV,          // op1 / op2
    SCR1_IALU_CMD_DIVU,         // op1 u/ op2
    SCR1_IALU_CMD_REM,          // op1 % op2
    SCR1_IALU_CMD_REMU          // op1 u% op2
`endif  // SCR1_RVM_EXT
} type_scr1_ialu_cmd_sel_e;

//-------------------------------------------------------------------------------
// IALU SUM2 operands (result is JUMP/BRANCH target, LOAD/STORE address)
//-------------------------------------------------------------------------------
localparam SCR1_SUM2_OP_ALL_NUM_E    = 2;
localparam SCR1_SUM2_OP_WIDTH_E      = $clog2(SCR1_SUM2_OP_ALL_NUM_E);
typedef enum logic [SCR1_SUM2_OP_WIDTH_E-1:0] {
    SCR1_SUM2_OP_PC_IMM,        // op1 = curr_pc; op2 = imm (AUIPC, target new_pc for JAL and branches)
    SCR1_SUM2_OP_REG_IMM        // op1 = rs1; op2 = imm (target new_pc for JALR, LOAD/STORE address)
`ifdef SCR1_XPROP_EN
    ,
    SCR1_SUM2_OP_ERROR = 'x
`endif // SCR1_XPROP_EN
} type_scr1_ialu_sum2_op_sel_e;


//-------------------------------------------------------------------------------
// FPU main operands
//-------------------------------------------------------------------------------
typedef enum logic {
    SCR1_FPU_OP_REG_REG,  // FP operation between two registers (e.g., FADD.S)
    SCR1_FPU_OP_REG_IMM   // FP operation with immediate (rare, but possible for some extensions)
} type_scr1_fpu_op_e;

// Floating-Point Opcodes
localparam SCR1_OPCODE_FLOAD     = 5'b00001;  // FLW
localparam SCR1_OPCODE_FSTORE    = 5'b01001;  // FSW
localparam SCR1_OPCODE_FMADD     = 5'b10000;  // FMADD.S
localparam SCR1_OPCODE_FMSUB     = 5'b10001;  // FMSUB.S
localparam SCR1_OPCODE_FNMSUB    = 5'b10010;  // FNMSUB.S
localparam SCR1_OPCODE_FNMADD    = 5'b10011;  // FNMADD.S
localparam SCR1_OPCODE_FP_OP     = 5'b10100;  // FP arithmetic (FADD.S, FSUB.S, FMUL.S, FDIV.S, e

// FPU Commands
typedef enum logic [3:0] {
    SCR1_FPU_CMD_NONE      = 4'h0,  // No operation
    SCR1_FPU_CMD_FADD      = 4'h1,  // FP Add
    SCR1_FPU_CMD_FSUB      = 4'h2,  // FP Subtract
    SCR1_FPU_CMD_FMUL      = 4'h3,  // FP Multiply
    SCR1_FPU_CMD_FDIV      = 4'h4,  // FP Divide
    SCR1_FPU_CMD_FSQRT     = 4'h5,  // FP Square Root
    SCR1_FPU_CMD_FSGNJ     = 4'h6,  // FP Sign Injection
    SCR1_FPU_CMD_FMIN_MAX  = 4'h7,  // FP Min/Max
    SCR1_FPU_CMD_FCMP      = 4'h8,  // FP Compare
    SCR1_FPU_CMD_FCVT_W_S  = 4'h9,  // FP Convert from Word to Single
    SCR1_FPU_CMD_FCVT_S_W  = 4'hA,  // FP Convert from Single to Word
    SCR1_FPU_CMD_FMADD     = 4'hB,  // FP Fused Multiply-Add
    SCR1_FPU_CMD_FMSUB     = 4'hC,  // FP Fused Multiply-Sub
    SCR1_FPU_CMD_FNMSUB    = 4'hD,  // FP Fused Negated Multiply-Sub
    SCR1_FPU_CMD_FNMADD    = 4'hE   // FP Fused Negated Multiply-Add
} type_scr1_fpu_cmd_e;

// FP Rounding Modes (funct3 for FP instructions)
localparam SCR1_FRM_RNE    = 3'b000;  // Round to Nearest, ties to Even
localparam SCR1_FRM_RTZ    = 3'b001;  // Round towards Zero
localparam SCR1_FRM_RDN    = 3'b010;  // Round Down (towards -inf)
localparam SCR1_FRM_RUP    = 3'b011;  // Round Up (towards +inf)
localparam SCR1_FRM_RMM    = 3'b100;  // Round to Nearest, ties to Max Magnitude
localparam SCR1_FRM_DYN    = 3'b111;  // Dynamic Rounding Mode (from CSR)

//-------------------------------------------------------------------------------
// LSU commands
//-------------------------------------------------------------------------------
localparam SCR1_LSU_CMD_ALL_NUM_E   = 11;
localparam SCR1_LSU_CMD_WIDTH_E     = $clog2(SCR1_LSU_CMD_ALL_NUM_E);
typedef enum logic [SCR1_LSU_CMD_WIDTH_E-1:0] {
    SCR1_LSU_CMD_NONE = '0,
    SCR1_LSU_CMD_LB,
    SCR1_LSU_CMD_LH,
    SCR1_LSU_CMD_LW,
    SCR1_LSU_CMD_LBU,
    SCR1_LSU_CMD_LHU,
    SCR1_LSU_CMD_SB,
    SCR1_LSU_CMD_SH,
    SCR1_LSU_CMD_SW,
    SCR1_LSU_CMD_FLW,   // Load float (32-bit FP)
    SCR1_LSU_CMD_FSW    // Store float (32-bit FP)
} type_scr1_lsu_cmd_sel_e;

//-------------------------------------------------------------------------------
// CSR operands
//-------------------------------------------------------------------------------
localparam SCR1_CSR_OP_ALL_NUM_E   = 2;
localparam SCR1_CSR_OP_WIDTH_E     = $clog2(SCR1_CSR_OP_ALL_NUM_E);
typedef enum logic [SCR1_CSR_OP_WIDTH_E-1:0] {
    SCR1_CSR_OP_IMM,
    SCR1_CSR_OP_REG
} type_scr1_csr_op_sel_e;

//-------------------------------------------------------------------------------
// CSR commands
//-------------------------------------------------------------------------------
localparam SCR1_CSR_CMD_ALL_NUM_E   = 4;
localparam SCR1_CSR_CMD_WIDTH_E     = $clog2(SCR1_CSR_CMD_ALL_NUM_E);
typedef enum logic [SCR1_CSR_CMD_WIDTH_E-1:0] {
    SCR1_CSR_CMD_NONE = '0,
    SCR1_CSR_CMD_WRITE,
    SCR1_CSR_CMD_SET,
    SCR1_CSR_CMD_CLEAR
} type_scr1_csr_cmd_sel_e;

//-------------------------------------------------------------------------------
// MPRF rd writeback source
//-------------------------------------------------------------------------------
localparam SCR1_RD_WB_ALL_NUM_E = 8;
localparam SCR1_RD_WB_WIDTH_E   = $clog2(SCR1_RD_WB_ALL_NUM_E);
typedef enum logic [SCR1_RD_WB_WIDTH_E-1:0] {
    SCR1_RD_WB_NONE = '0,
    SCR1_RD_WB_IALU,            // IALU main result
    SCR1_RD_WB_SUM2,            // IALU SUM2 result (AUIPC)
    SCR1_RD_WB_IMM,             // LUI
    SCR1_RD_WB_INC_PC,          // JAL(R)
    SCR1_RD_WB_LSU,             // Load from DMEM
    SCR1_RD_WB_CSR,              // Read CSR
    SCR1_RD_WB_FPU
} type_scr1_rd_wb_sel_e;

//-------------------------------------------------------------------------------
// IDU to EXU full command structure
//-------------------------------------------------------------------------------
localparam SCR1_GPR_FIELD_WIDTH = 5;

typedef struct packed {
    logic                               instr_rvc;      // used with a different meaning for IFU access fault exception
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
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rs1_addr;       // also used as zimm for CSRRxI instructions
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rs2_addr;
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    rd_addr;
    logic [`SCR1_XLEN-1:0]              imm;            // used as {funct3, CSR address} for CSR instructions
                                                        // used as instruction field for illegal instruction exception
    logic                               exc_req;
    type_scr1_exc_code_e                exc_code;
    logic [2:0]                         fpu_rm;         // FP rounding mode
    type_scr1_fpu_op_e                  fpu_op;         // ??? ???????? FPU (???????-??????? ??? ???????-????????)
    type_scr1_fpu_cmd_e                 fpu_cmd;        // ??????? FPU (ADD, SUB, MUL, etc.)
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    frs1_addr;      // ????? ????????? 1 FPU
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    frs2_addr;      // ????? ????????? 2 FPU
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    frs3_addr;      // ????? ????????? 3 FPU (??? FMA)
    logic [SCR1_GPR_FIELD_WIDTH-1:0]    frd_addr;       // ????? ?????????? FPU
} type_scr1_exu_cmd_s;

`endif // SCR1_RISCV_ISA_DECODING_SVH

