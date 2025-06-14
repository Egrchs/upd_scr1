/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_pipe_fprf.sv>
/// @brief      Floating-Point Register File (FPRF)
///

`include "scr1_arch_description.svh"
`include "scr1_arch_types.svh"

module scr1_pipe_fprf (
    // Common
`ifdef SCR1_MPRF_RST_EN
    input   logic                               rst_n,                      // FPRF reset
`endif // SCR1_FPRF_RST_EN
    input   logic                               clk,                        // FPRF clock

    // EXU <-> FPRF interface
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       exu2fprf_frs1_addr_i,       // FPRF frs1 read address
    output  logic [`SCR1_XLEN-1:0]              fprf2exu_frs1_data_o,       // FPRF frs1 read data
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       exu2fprf_frs2_addr_i,       // FPRF frs2 read address
    output  logic [`SCR1_XLEN-1:0]              fprf2exu_frs2_data_o,       // FPRF frs2 read data
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       exu2fprf_frs3_addr_i,       // FPRF frs3 read address
    output  logic [`SCR1_XLEN-1:0]              fprf2exu_frs3_data_o,       // FPRF frs3 read data
    input   logic                               exu2fprf_w_req_i,           // FPRF write request
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       exu2fprf_frd_addr_i,        // FPRF frd write address
    input   logic [`SCR1_XLEN-1:0]              exu2fprf_frd_data_i         // FPRF frd write data
);

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------

logic                        wr_req_vd;

logic                        frs1_addr_vd;
logic                        frs2_addr_vd;
logic                        frs3_addr_vd;

`ifdef  SCR1_FPRF_RAM
logic                        frs1_addr_vd_ff;
logic                        frs2_addr_vd_ff;
logic                        frs3_addr_vd_ff;

logic                        frs1_new_data_req;
logic                        frs2_new_data_req;
logic                        frs3_new_data_req;
logic                        frs1_new_data_req_ff;
logic                        frs2_new_data_req_ff;
logic                        frs3_new_data_req_ff;
logic                        read_new_data_req;

logic    [`SCR1_XLEN-1:0]    rd_data_ff;

logic    [`SCR1_XLEN-1:0]    frs1_data_ff;
logic    [`SCR1_XLEN-1:0]    frs2_data_ff;
logic    [`SCR1_XLEN-1:0]    frs3_data_ff;

// When using RAM, 3 memories are needed because 4 simultaneous independent
// write/read operations can occur (3 reads + 1 write)
 `ifdef SCR1_TRGT_FPGA_INTEL_MAX10
(* ramstyle = "M9K" *)      logic   [`SCR1_XLEN-1:0]    fprf_int   [1:`SCR1_FPRF_SIZE-1];
(* ramstyle = "M9K" *)      logic   [`SCR1_XLEN-1:0]    fprf_int2  [1:`SCR1_FPRF_SIZE-1];
(* ramstyle = "M9K" *)      logic   [`SCR1_XLEN-1:0]    fprf_int3  [1:`SCR1_FPRF_SIZE-1];
 `elsif SCR1_TRGT_FPGA_INTEL_ARRIAV
(* ramstyle = "M10K" *)     logic   [`SCR1_XLEN-1:0]    fprf_int   [1:`SCR1_FPRF_SIZE-1];
(* ramstyle = "M10K" *)     logic   [`SCR1_XLEN-1:0]    fprf_int2  [1:`SCR1_FPRF_SIZE-1];
(* ramstyle = "M10K" *)     logic   [`SCR1_XLEN-1:0]    fprf_int3  [1:`SCR1_FPRF_SIZE-1];
 `else
logic   [`SCR1_XLEN-1:0]    fprf_int   [1:`SCR1_FPRF_SIZE-1];
logic   [`SCR1_XLEN-1:0]    fprf_int2  [1:`SCR1_FPRF_SIZE-1];
logic   [`SCR1_XLEN-1:0]    fprf_int3  [1:`SCR1_FPRF_SIZE-1];
 `endif
`else  // distributed logic implementation
type_scr1_fprf_v [1:`SCR1_MPRF_SIZE-1]                  fprf_int;
`endif

//------------------------------------------------------------------------------
// FPRF control logic
//------------------------------------------------------------------------------

// control signals common for distributed logic and RAM implementations
assign  frs1_addr_vd  =   |exu2fprf_frs1_addr_i;
assign  frs2_addr_vd  =   |exu2fprf_frs2_addr_i;
assign  frs3_addr_vd  =   |exu2fprf_frs3_addr_i;

assign  wr_req_vd  =   exu2fprf_w_req_i & |exu2fprf_frd_addr_i;

// RAM implementation specific control signals
`ifdef SCR1_FPRF_RAM
assign  frs1_new_data_req    =   wr_req_vd & ( exu2fprf_frs1_addr_i == exu2fprf_frd_addr_i );
assign  frs2_new_data_req    =   wr_req_vd & ( exu2fprf_frs2_addr_i == exu2fprf_frd_addr_i );
assign  frs3_new_data_req    =   wr_req_vd & ( exu2fprf_frs3_addr_i == exu2fprf_frd_addr_i );
assign  read_new_data_req   =   frs1_new_data_req | frs2_new_data_req | frs3_new_data_req;

always_ff @( posedge clk ) begin
    frs1_addr_vd_ff          <=  frs1_addr_vd;
    frs2_addr_vd_ff          <=  frs2_addr_vd;
    frs3_addr_vd_ff          <=  frs3_addr_vd;
    frs1_new_data_req_ff     <=  frs1_new_data_req;
    frs2_new_data_req_ff     <=  frs2_new_data_req;
    frs3_new_data_req_ff     <=  frs3_new_data_req;
end
`endif // SCR1_FPRF_RAM

`ifdef  SCR1_FPRF_RAM
//-------------------------------------------------------------------------------
// RAM implementation
//-------------------------------------------------------------------------------

// RAM is implemented with 3 simple dual-port memories with sync read operation;
// logic for "write-first" RDW behavior is implemented externally to the embedded
// memory blocks

// bypass new wr_data to the read output if write/read collision occurs
assign  fprf2exu_frs1_data_o   =   ( frs1_new_data_req_ff ) ? rd_data_ff
                                : (( frs1_addr_vd_ff )   ? frs1_data_ff
                                                        : '0 );

assign  fprf2exu_frs2_data_o   =   ( frs2_new_data_req_ff ) ? rd_data_ff
                                : (( frs2_addr_vd_ff )   ? frs2_data_ff
                                                        : '0 );

assign  fprf2exu_frs3_data_o   =   ( frs3_new_data_req_ff ) ? rd_data_ff
                                : (( frs3_addr_vd_ff )   ? frs3_data_ff
                                                        : '0 );

always_ff @( posedge clk ) begin
    if ( read_new_data_req ) begin
        rd_data_ff     <=  exu2fprf_frd_data_i;
    end
end

// synchronous read operation
always_ff @( posedge clk ) begin
    frs1_data_ff   <=   fprf_int[exu2fprf_frs1_addr_i];
    frs2_data_ff   <=   fprf_int2[exu2fprf_frs2_addr_i];
    frs3_data_ff   <=   fprf_int3[exu2fprf_frs3_addr_i];
end

// write operation
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        fprf_int[exu2fprf_frd_addr_i]  <= exu2fprf_frd_data_i;
        fprf_int2[exu2fprf_frd_addr_i] <= exu2fprf_frd_data_i;
        fprf_int3[exu2fprf_frd_addr_i] <= exu2fprf_frd_data_i;
    end
end
`else   // distributed logic implementation
//------------------------------------------------------------------------------
// distributed logic implementation
//------------------------------------------------------------------------------

// asynchronous read operation
assign  fprf2exu_frs1_data_o = ( frs1_addr_vd ) ? fprf_int[exu2fprf_frs1_addr_i] : '0;
assign  fprf2exu_frs2_data_o = ( frs2_addr_vd ) ? fprf_int[exu2fprf_frs2_addr_i] : '0;
assign  fprf2exu_frs3_data_o = ( frs3_addr_vd ) ? fprf_int[exu2fprf_frs3_addr_i] : '0;

// write operation
 `ifdef SCR1_MPRF_RST_EN
always_ff @( posedge clk, negedge rst_n ) begin
    if ( ~rst_n ) begin
        fprf_int <= '{default: '0};
    end else if ( wr_req_vd ) begin
        fprf_int[exu2fprf_frd_addr_i] <= exu2fprf_frd_data_i;
    end
end
 `else // ~SCR1_FPRF_RST_EN
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        fprf_int[exu2fprf_frd_addr_i] <= exu2fprf_frd_data_i;
    end
end
 `endif // ~SCR1_FPRF_RST_EN
`endif

`ifdef SCR1_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------
`ifdef SCR1_FPRF_RST_EN
SCR1_SVA_FPRF_WRITEX : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2fprf_w_req_i |-> !$isunknown({exu2fprf_frd_addr_i, (|exu2fprf_frd_addr_i ? exu2fprf_frd_data_i : `SCR1_XLEN'd0)})
    ) else $error("FPRF error: unknown values");
`endif // SCR1_FPRF_RST_EN

`endif // SCR1_TRGT_SIMULATION

endmodule : scr1_pipe_fprf
