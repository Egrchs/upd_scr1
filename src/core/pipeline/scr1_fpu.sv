/// Copyright by Syntacore LLC © 2023. See LICENSE for details
/// @file       <scr1_pipe_fpu.sv>
/// @brief      Floating-Point Unit (FPU) - Interface-only module
/// @note       Internal logic not implemented

`include "scr1_riscv_isa_fpu.svh"

module scr1_pipe_fpu (
    // Clock and reset
    input   logic                           clk,                // Clock
    input   logic                           rst_n,              // Async reset (active-low)

    // Control signals
    input   logic                           fpu_req_i,          // FPU operation request
    output  logic                           fpu_rdy_o,          // FPU ready for new operation
    input   type_scr1_fpu_cmd_e             fpu_cmd_i,          // FPU operation command
    input   type_scr1_fpu_round_mode_e      fpu_rm_i,           // Rounding mode

    // Operand interface
    input   logic [`SCR1_XLEN-1:0]          fpu_op1_i,          // Operand 1 (rs1)
    input   logic [`SCR1_XLEN-1:0]          fpu_op2_i,          // Operand 2 (rs2)
    input   logic [`SCR1_XLEN-1:0]          fpu_op3_i,          // Operand 3 (rs3 - for FMADD etc.)

    // Result interface
    output  logic [`SCR1_XLEN-1:0]          fpu_res_o,          // FPU result
    output  logic                           fpu_res_val_o,      // Result valid

    // Exception interface
    output  logic                           fpu_exc_o,          // FPU exception occurred
    output  type_scr1_fpu_exc_code_e        fpu_exc_code_o,     // FPU exception code

    // Status flags
    output  logic                           fpu_busy_o          // FPU busy (multi-cycle ops)
);

//-------------------------------------------------------------------------------
// Internal logic would be implemented here
//-------------------------------------------------------------------------------

// Temporary assignments (remove in actual implementation)
assign fpu_rdy_o      = 1'b1;
assign fpu_res_o      = '0;
assign fpu_res_val_o  = 1'b0;
assign fpu_exc_o      = 1'b0;
assign fpu_exc_code_o = SCR1_FPU_EXC_NONE;
assign fpu_busy_o     = 1'b0;

endmodule : scr1_pipe_fpu
