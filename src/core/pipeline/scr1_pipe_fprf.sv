/// @file       fprf.sv
/// @brief      Floating-Point Register File (FPRF)
///

`include "scr1_arch_description.svh"
`include "scr1_arch_types.svh"

module fprf (
    // Common
`ifdef SCR1_FPRF_RST_EN
    input   logic                               rst_n,                      // FPRF reset
`endif // SCR1_FPRF_RST_EN
    input   logic                               clk,                        // FPRF clock

    // FPU <-> FPRF interface
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       fpu2fprf_rs1_addr_i,        // FPRF rs1 read address
    output  logic [`SCR1_FLEN-1:0]              fprf2fpu_rs1_data_o,        // FPRF rs1 read data
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       fpu2fprf_rs2_addr_i,        // FPRF rs2 read address
    output  logic [`SCR1_FLEN-1:0]              fprf2fpu_rs2_data_o,        // FPRF rs2 read data
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       fpu2fprf_rs3_addr_i,        // FPRF rs3 read address (for ternary operations)
    output  logic [`SCR1_FLEN-1:0]              fprf2fpu_rs3_data_o,        // FPRF rs3 read data
    input   logic                               fpu2fprf_w_req_i,           // FPRF write request
    input   logic [`SCR1_MPRF_AWIDTH-1:0]       fpu2fprf_rd_addr_i,         // FPRF rd write address
    input   logic [`SCR1_FLEN-1:0]              fpu2fprf_rd_data_i          // FPRF rd write data
);

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------

logic                        wr_req_vd;

logic                        rs1_addr_vd;
logic                        rs2_addr_vd;
logic                        rs3_addr_vd;

`ifdef  SCR1_FPRF_RAM
logic                        rs1_addr_vd_ff;
logic                        rs2_addr_vd_ff;
logic                        rs3_addr_vd_ff;

logic                        rs1_new_data_req;
logic                        rs2_new_data_req;
logic                        rs3_new_data_req;
logic                        rs1_new_data_req_ff;
logic                        rs2_new_data_req_ff;
logic                        rs3_new_data_req_ff;
logic                        read_new_data_req;

logic    [`SCR1_FLEN-1:0]    rd_data_ff;

logic    [`SCR1_FLEN-1:0]    rs1_data_ff;
logic    [`SCR1_FLEN-1:0]    rs2_data_ff;
logic    [`SCR1_FLEN-1:0]    rs3_data_ff;

// when using RAM, 3 memories are needed because 4 simultaneous independent
// write/read operations can occur (3 reads + 1 write)
 `ifdef SCR1_TRGT_FPGA_INTEL_MAX10
(* ramstyle = "M9K" *)      logic   [`SCR1_FLEN-1:0]    fprf_int   [1:`SCR1_MPRF_SIZE-1];
(* ramstyle = "M9K" *)      logic   [`SCR1_FLEN-1:0]    fprf_int2  [1:`SCR1_MPRF_SIZE-1];
(* ramstyle = "M9K" *)      logic   [`SCR1_FLEN-1:0]    fprf_int3  [1:`SCR1_MPRF_SIZE-1];
 `elsif SCR1_TRGT_FPGA_INTEL_ARRIAV
(* ramstyle = "M10K" *)     logic   [`SCR1_FLEN-1:0]    fprf_int   [1:`SCR1_MPRF_SIZE-1];
(* ramstyle = "M10K" *)     logic   [`SCR1_FLEN-1:0]    fprf_int2  [1:`SCR1_MPRF_SIZE-1];
(* ramstyle = "M10K" *)     logic   [`SCR1_FLEN-1:0]    fprf_int3  [1:`SCR1_MPRF_SIZE-1];
 `else
logic   [`SCR1_FLEN-1:0]    fprf_int   [1:`SCR1_MPRF_SIZE-1];
logic   [`SCR1_FLEN-1:0]    fprf_int2  [1:`SCR1_MPRF_SIZE-1];
logic   [`SCR1_FLEN-1:0]    fprf_int3  [1:`SCR1_MPRF_SIZE-1];
 `endif
`else  // distributed logic implementation
type_scr1_fprf_v [1:`SCR1_MPRF_SIZE-1]                  fprf_int;
`endif

//------------------------------------------------------------------------------
// FPRF control logic
//------------------------------------------------------------------------------

// control signals common for distributed logic and RAM implementations
assign  rs1_addr_vd  =   |fpu2fprf_rs1_addr_i;
assign  rs2_addr_vd  =   |fpu2fprf_rs2_addr_i;
assign  rs3_addr_vd  =   |fpu2fprf_rs3_addr_i;

assign  wr_req_vd  =   fpu2fprf_w_req_i & |fpu2fprf_rd_addr_i;

// RAM implementation specific control signals
`ifdef SCR1_FPRF_RAM
assign  rs1_new_data_req    =   wr_req_vd & ( fpu2fprf_rs1_addr_i == fpu2fprf_rd_addr_i );
assign  rs2_new_data_req    =   wr_req_vd & ( fpu2fprf_rs2_addr_i == fpu2fprf_rd_addr_i );
assign  rs3_new_data_req    =   wr_req_vd & ( fpu2fprf_rs3_addr_i == fpu2fprf_rd_addr_i );
assign  read_new_data_req   =   rs1_new_data_req | rs2_new_data_req | rs3_new_data_req;

always_ff @( posedge clk ) begin
    rs1_addr_vd_ff          <=  rs1_addr_vd;
    rs2_addr_vd_ff          <=  rs2_addr_vd;
    rs3_addr_vd_ff          <=  rs3_addr_vd;
    rs1_new_data_req_ff     <=  rs1_new_data_req;
    rs2_new_data_req_ff     <=  rs2_new_data_req;
    rs3_new_data_req_ff     <=  rs3_new_data_req;
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
assign  fprf2fpu_rs1_data_o   =   ( rs1_new_data_req_ff ) ? rd_data_ff
                                : (( rs1_addr_vd_ff )   ? rs1_data_ff
                                                        : '0 );

assign  fprf2fpu_rs2_data_o   =   ( rs2_new_data_req_ff ) ? rd_data_ff
                                : (( rs2_addr_vd_ff )   ? rs2_data_ff
                                                        : '0 );

assign  fprf2fpu_rs3_data_o   =   ( rs3_new_data_req_ff ) ? rd_data_ff
                                : (( rs3_addr_vd_ff )   ? rs3_data_ff
                                                        : '0 );

always_ff @( posedge clk ) begin
    if ( read_new_data_req ) begin
        rd_data_ff     <=  fpu2fprf_rd_data_i;
    end
end

// synchronous read operation
always_ff @( posedge clk ) begin
    rs1_data_ff   <=   fprf_int[fpu2fprf_rs1_addr_i];
    rs2_data_ff   <=   fprf_int2[fpu2fprf_rs2_addr_i];
    rs3_data_ff   <=   fprf_int3[fpu2fprf_rs3_addr_i];
end

// write operation
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        fprf_int[fpu2fprf_rd_addr_i]  <= fpu2fprf_rd_data_i;
        fprf_int2[fpu2fprf_rd_addr_i] <= fpu2fprf_rd_data_i;
        fprf_int3[fpu2fprf_rd_addr_i] <= fpu2fprf_rd_data_i;
    end
end
`else   // distributed logic implementation
//------------------------------------------------------------------------------
// distributed logic implementation
//------------------------------------------------------------------------------

// asynchronous read operation
assign  fprf2fpu_rs1_data_o = ( rs1_addr_vd ) ? fprf_int[fpu2fprf_rs1_addr_i] : '0;
assign  fprf2fpu_rs2_data_o = ( rs2_addr_vd ) ? fprf_int[fpu2fprf_rs2_addr_i] : '0;
assign  fprf2fpu_rs3_data_o = ( rs3_addr_vd ) ? fprf_int[fpu2fprf_rs3_addr_i] : '0;

// write operation
 `ifdef SCR1_FPRF_RST_EN
always_ff @( posedge clk, negedge rst_n ) begin
    if ( ~rst_n ) begin
        fprf_int <= '{default: '0};
    end else if ( wr_req_vd ) begin
        fprf_int[fpu2fprf_rd_addr_i] <= fpu2fprf_rd_data_i;
    end
end
 `else // ~SCR1_FPRF_RST_EN
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        fprf_int[fpu2fprf_rd_addr_i] <= fpu2fprf_rd_data_i;
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
    fpu2fprf_w_req_i |-> !$isunknown({fpu2fprf_rd_addr_i, (|fpu2fprf_rd_addr_i ? fpu2fprf_rd_data_i : `SCR1_FLEN'd0)})
    ) else $error("FPRF error: unknown values");
`endif // SCR1_FPRF_RST_EN

`endif // SCR1_TRGT_SIMULATION

endmodule : fprf
