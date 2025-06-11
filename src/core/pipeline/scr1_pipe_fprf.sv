/// Copyright (c) 2024.
/// @file       <scr1_pipe_fprf.sv>
/// @brief      Floating-Point Register File (FPRF) for SCR1

`include "scr1_arch_description.svh"

module scr1_pipe_fprf (
    input  logic                          clk,

    // Порт чтения RS1
    input  logic [4:0]                    rs1_addr_i,
    output logic [`SCR1_XLEN-1:0]         rs1_data_o,

    // Порт чтения RS2
    input  logic [4:0]                    rs2_addr_i,
    output logic [`SCR1_XLEN-1:0]         rs2_data_o,

    // Порт чтения RS3 (для FMA инструкций)
    input  logic [4:0]                    rs3_addr_i,
    output logic [`SCR1_XLEN-1:0]         rs3_data_o,

    // Порт записи RD
    input  logic                          w_req_i,
    input  logic [4:0]                    rd_addr_i,
    input  logic [`SCR1_XLEN-1:0]         rd_data_i
);

    // 32 регистра по 32 бита для FP. f0 не является константой!
    logic [`SCR1_XLEN-1:0] fprf_array [0:31];

    // Асинхронное чтение
    assign rs1_data_o = fprf_array[rs1_addr_i];
    assign rs2_data_o = fprf_array[rs2_addr_i];
    assign rs3_data_o = fprf_array[rs3_addr_i];

    // Синхронная запись
    always_ff @(posedge clk) begin
        if (w_req_i) begin
            fprf_array[rd_addr_i] <= rd_data_i;
        end
    end

endmodule
