/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_pipe_lsu.sv>
/// @brief      Load/Store Unit (LSU)
/// @note       Modified to support Floating-Point loads/stores.

`include "scr1_arch_description.svh"
`include "scr1_arch_types.svh"
`include "scr1_memif.svh"
`include "scr1_riscv_isa_decoding.svh"
`ifdef SCR1_TDU_EN
`include "scr1_tdu.svh"
`endif // SCR1_TDU_EN

module scr1_pipe_lsu (
    // Common
    input   logic                               rst_n,
    input   logic                               clk,

    // LSU <-> EXU interface
    input   logic                               exu2lsu_req_i,
    input   type_scr1_lsu_cmd_sel_e             exu2lsu_cmd_i,
    input   logic [`SCR1_XLEN-1:0]              exu2lsu_addr_i,
    input   logic [`SCR1_XLEN-1:0]              exu2lsu_sdata_i,
    output  logic                               lsu2exu_rdy_o,
    output  logic [`SCR1_XLEN-1:0]              lsu2exu_ldata_o,
    output  logic                               lsu2exu_exc_o,
    output  type_scr1_exc_code_e                lsu2exu_exc_code_o,

`ifdef SCR1_TDU_EN
    // LSU <-> TDU interface
    output  type_scr1_brkm_lsu_mon_s            lsu2tdu_dmon_o,
    input   logic                               tdu2lsu_ibrkpt_exc_req_i,
    input   logic                               tdu2lsu_dbrkpt_exc_req_i,
`endif // SCR1_TDU_EN

    // LSU <-> DMEM interface
    output  logic                               lsu2dmem_req_o,
    output  type_scr1_mem_cmd_e                 lsu2dmem_cmd_o,
    output  type_scr1_mem_width_e               lsu2dmem_width_o,
    output  logic [`SCR1_DMEM_AWIDTH-1:0]       lsu2dmem_addr_o,
    output  logic [`SCR1_DMEM_DWIDTH-1:0]       lsu2dmem_wdata_o,
    input   logic                               dmem2lsu_req_ack_i,
    input   logic [`SCR1_DMEM_DWIDTH-1:0]       dmem2lsu_rdata_i,
    input   type_scr1_mem_resp_e                dmem2lsu_resp_i
);

//------------------------------------------------------------------------------
// Local types declaration
//------------------------------------------------------------------------------
typedef enum logic {
    SCR1_LSU_FSM_IDLE,
    SCR1_LSU_FSM_BUSY
} type_scr1_lsu_fsm_e;

//------------------------------------------------------------------------------
// Local signals declaration
//------------------------------------------------------------------------------
type_scr1_lsu_fsm_e         lsu_fsm_curr;
type_scr1_lsu_fsm_e         lsu_fsm_next;
logic                       lsu_fsm_idle;

logic                       lsu_cmd_upd;
type_scr1_lsu_cmd_sel_e     lsu_cmd_ff;
logic                       lsu_cmd_ff_load;
logic                       lsu_cmd_ff_store;

logic                       dmem_cmd_load;
logic                       dmem_cmd_store;
logic                       dmem_wdth_word;
logic                       dmem_wdth_hword;
logic                       dmem_wdth_byte;

logic                       dmem_resp_ok;
logic                       dmem_resp_er;
logic                       dmem_resp_received;
logic                       dmem_req_vd;

logic                       lsu_exc_req;
logic                       dmem_addr_mslgn;
logic                       dmem_addr_mslgn_l;
logic                       dmem_addr_mslgn_s;
`ifdef SCR1_TDU_EN
logic                       lsu_exc_hwbrk;
`endif

//------------------------------------------------------------------------------
// Control logic
//------------------------------------------------------------------------------
assign dmem_resp_ok       = (dmem2lsu_resp_i == SCR1_MEM_RESP_RDY_OK);
assign dmem_resp_er       = (dmem2lsu_resp_i == SCR1_MEM_RESP_RDY_ER);
assign dmem_resp_received = dmem_resp_ok | dmem_resp_er;
assign dmem_req_vd        = exu2lsu_req_i & dmem2lsu_req_ack_i & ~lsu_exc_req;

// --- [ИЗМЕНЕНИЕ] Расширены флаги команд для включения FLW/FSW ---
assign dmem_cmd_load  = (exu2lsu_cmd_i == SCR1_LSU_CMD_LB )
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_LBU)
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_LH )
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_LHU)
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_LW )
                      `ifdef SCR1_RVF_EXT
                      | (exu2lsu_cmd_i == LSU_CMD_FLW)
                      `endif
                      ;
assign dmem_cmd_store = (exu2lsu_cmd_i == SCR1_LSU_CMD_SB )
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_SH )
                      | (exu2lsu_cmd_i == SCR1_LSU_CMD_SW )
                      `ifdef SCR1_RVF_EXT
                      | (exu2lsu_cmd_i == LSU_CMD_FSW)
                      `endif
                      ;

assign dmem_wdth_word  = (exu2lsu_cmd_i == SCR1_LSU_CMD_LW )
                       | (exu2lsu_cmd_i == SCR1_LSU_CMD_SW )
                       `ifdef SCR1_RVF_EXT
                       | (exu2lsu_cmd_i == LSU_CMD_FLW)
                       | (exu2lsu_cmd_i == LSU_CMD_FSW)
                       `endif
                       ;
assign dmem_wdth_hword = (exu2lsu_cmd_i == SCR1_LSU_CMD_LH )
                       | (exu2lsu_cmd_i == SCR1_LSU_CMD_LHU)
                       | (exu2lsu_cmd_i == SCR1_LSU_CMD_SH );
assign dmem_wdth_byte  = (exu2lsu_cmd_i == SCR1_LSU_CMD_LB )
                       | (exu2lsu_cmd_i == SCR1_LSU_CMD_LBU)
                       | (exu2lsu_cmd_i == SCR1_LSU_CMD_SB );
// --- КОНЕЦ ИЗМЕНЕНИЙ ---

assign lsu_cmd_upd = lsu_fsm_idle & dmem_req_vd;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        lsu_cmd_ff <= SCR1_LSU_CMD_NONE;
    end else if (lsu_cmd_upd) begin
        lsu_cmd_ff <= exu2lsu_cmd_i;
    end
end

assign lsu_cmd_ff_load  = (lsu_cmd_ff == SCR1_LSU_CMD_LB )
                        | (lsu_cmd_ff == SCR1_LSU_CMD_LBU)
                        | (lsu_cmd_ff == SCR1_LSU_CMD_LH )
                        | (lsu_cmd_ff == SCR1_LSU_CMD_LHU)
                        | (lsu_cmd_ff == SCR1_LSU_CMD_LW )
                        `ifdef SCR1_RVF_EXT
                        | (lsu_cmd_ff == LSU_CMD_FLW)
                        `endif
                        ;
assign lsu_cmd_ff_store = (lsu_cmd_ff == SCR1_LSU_CMD_SB )
                        | (lsu_cmd_ff == SCR1_LSU_CMD_SH )
                        | (lsu_cmd_ff == SCR1_LSU_CMD_SW )
                        `ifdef SCR1_RVF_EXT
                        | (lsu_cmd_ff == LSU_CMD_FSW)
                        `endif
                        ;

//------------------------------------------------------------------------------
// LSU FSM
//------------------------------------------------------------------------------
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        lsu_fsm_curr <= SCR1_LSU_FSM_IDLE;
    end else begin
        lsu_fsm_curr <= lsu_fsm_next;
    end
end

always_comb begin
    case (lsu_fsm_curr)
        SCR1_LSU_FSM_IDLE: lsu_fsm_next = dmem_req_vd ? SCR1_LSU_FSM_BUSY : SCR1_LSU_FSM_IDLE;
        SCR1_LSU_FSM_BUSY: lsu_fsm_next = dmem_resp_received ? SCR1_LSU_FSM_IDLE : SCR1_LSU_FSM_BUSY;
    endcase
end

assign lsu_fsm_idle = (lsu_fsm_curr == SCR1_LSU_FSM_IDLE);

//------------------------------------------------------------------------------
// Exceptions logic
//------------------------------------------------------------------------------
assign dmem_addr_mslgn   = exu2lsu_req_i & ( (dmem_wdth_hword & exu2lsu_addr_i[0])
                                           | (dmem_wdth_word  & |exu2lsu_addr_i[1:0]));
assign dmem_addr_mslgn_l = dmem_addr_mslgn & dmem_cmd_load;
assign dmem_addr_mslgn_s = dmem_addr_mslgn & dmem_cmd_store;

always_comb begin
    case (1'b1)
        dmem_resp_er     : lsu2exu_exc_code_o = lsu_cmd_ff_load  ? SCR1_EXC_CODE_LD_ACCESS_FAULT
                                              : lsu_cmd_ff_store ? SCR1_EXC_CODE_ST_ACCESS_FAULT
                                                                 : SCR1_EXC_CODE_INSTR_MISALIGN;
`ifdef SCR1_TDU_EN
        lsu_exc_hwbrk    : lsu2exu_exc_code_o = SCR1_EXC_CODE_BREAKPOINT;
`endif
        dmem_addr_mslgn_l: lsu2exu_exc_code_o = SCR1_EXC_CODE_LD_ADDR_MISALIGN;
        dmem_addr_mslgn_s: lsu2exu_exc_code_o = SCR1_EXC_CODE_ST_ADDR_MISALIGN;
        default          : lsu2exu_exc_code_o = SCR1_EXC_CODE_INSTR_MISALIGN;
    endcase
end

assign lsu_exc_req = dmem_addr_mslgn_l | dmem_addr_mslgn_s
`ifdef SCR1_TDU_EN
                   | lsu_exc_hwbrk
`endif
;

//------------------------------------------------------------------------------
// LSU <-> EXU interface
//------------------------------------------------------------------------------
assign lsu2exu_rdy_o = dmem_resp_received;
assign lsu2exu_exc_o = dmem_resp_er | lsu_exc_req;

always_comb begin
    case (lsu_cmd_ff)
        SCR1_LSU_CMD_LH : lsu2exu_ldata_o = {{16{dmem2lsu_rdata_i[15]}}, dmem2lsu_rdata_i[15:0]};
        SCR1_LSU_CMD_LHU: lsu2exu_ldata_o = { 16'b0,                     dmem2lsu_rdata_i[15:0]};
        SCR1_LSU_CMD_LB : lsu2exu_ldata_o = {{24{dmem2lsu_rdata_i[7]}},  dmem2lsu_rdata_i[7:0]};
        SCR1_LSU_CMD_LBU: lsu2exu_ldata_o = { 24'b0,                     dmem2lsu_rdata_i[7:0]};
        // --- [ИЗМЕНЕНИЕ] FLW просто пробрасывает данные, без расширения ---
        `ifdef SCR1_RVF_EXT
        LSU_CMD_FLW:      lsu2exu_ldata_o = dmem2lsu_rdata_i;
        `endif
        // --- КОНЕЦ ИЗМЕНЕНИЙ ---
        default         : lsu2exu_ldata_o = dmem2lsu_rdata_i;
    endcase
end

//------------------------------------------------------------------------------
// LSU <-> DMEM interface
//------------------------------------------------------------------------------
assign lsu2dmem_req_o   = exu2lsu_req_i & ~lsu_exc_req & lsu_fsm_idle;
assign lsu2dmem_addr_o  = exu2lsu_addr_i;
assign lsu2dmem_wdata_o = exu2lsu_sdata_i;
assign lsu2dmem_cmd_o   = dmem_cmd_store  ? SCR1_MEM_CMD_WR : SCR1_MEM_CMD_RD;
assign lsu2dmem_width_o = dmem_wdth_byte  ? SCR1_MEM_WIDTH_BYTE
                        : dmem_wdth_hword ? SCR1_MEM_WIDTH_HWORD
                                          : SCR1_MEM_WIDTH_WORD;

`ifdef SCR1_TDU_EN
//------------------------------------------------------------------------------
// LSU <-> TDU interface
//------------------------------------------------------------------------------
assign lsu2tdu_dmon_o.vd    = exu2lsu_req_i & lsu_fsm_idle & ~tdu2lsu_ibrkpt_exc_req_i;
assign lsu2tdu_dmon_o.addr  = exu2lsu_addr_i;
assign lsu2tdu_dmon_o.load  = dmem_cmd_load;
assign lsu2tdu_dmon_o.store = dmem_cmd_store;

assign lsu_exc_hwbrk = (exu2lsu_req_i & tdu2lsu_ibrkpt_exc_req_i)
                     | tdu2lsu_dbrkpt_exc_req_i;
`endif



`ifdef SCR1_TRGT_SIMULATION
//------------------------------------------------------------------------------
// Assertions
//------------------------------------------------------------------------------

// X checks

SCR1_SVA_LSU_XCHECK_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({exu2lsu_req_i, lsu_fsm_curr
`ifdef SCR1_TDU_EN
        , tdu2lsu_ibrkpt_exc_req_i, tdu2lsu_dbrkpt_exc_req_i
`endif // SCR1_TDU_EN
    })
    ) else $error("LSU Error: unknown control value");

SCR1_SVA_LSU_XCHECK_CMD : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2lsu_req_i |-> !$isunknown({exu2lsu_cmd_i, exu2lsu_addr_i})
    ) else $error("LSU Error: undefined CMD or address");

SCR1_SVA_LSU_XCHECK_SDATA : assert property (
    @(negedge clk) disable iff (~rst_n)
    (exu2lsu_req_i & (lsu2dmem_cmd_o == SCR1_MEM_CMD_WR)) |-> !$isunknown({exu2lsu_sdata_i})
    ) else $error("LSU Error: undefined store data");

SCR1_SVA_LSU_XCHECK_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2exu_exc_o |-> !$isunknown(lsu2exu_exc_code_o)
    ) else $error("LSU Error: exception code undefined");

SCR1_SVA_LSU_IMEM_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o |-> !$isunknown({lsu2dmem_cmd_o, lsu2dmem_width_o, lsu2dmem_addr_o})
    ) else $error("LSU Error: undefined dmem control");

SCR1_SVA_LSU_IMEM_ACK : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o |-> !$isunknown(dmem2lsu_req_ack_i)
    ) else $error("LSU Error: undefined dmem ack");

SCR1_SVA_LSU_IMEM_WDATA : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o & (lsu2dmem_cmd_o == SCR1_MEM_CMD_WR)
    |-> !$isunknown(lsu2dmem_wdata_o[8:0])
    ) else $error("LSU Error: undefined dmem wdata");

// Behavior checks

SCR1_SVA_LSU_EXC_ONEHOT : assert property (
    @(negedge clk) disable iff (~rst_n)
    $onehot0({dmem_resp_er, dmem_addr_mslgn_l, dmem_addr_mslgn_s})
    ) else $error("LSU Error: more than one exception at a time");

SCR1_SVA_LSU_UNEXPECTED_DMEM_RESP : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu_fsm_idle |-> ~dmem_resp_received
    ) else $error("LSU Error: not expecting memory response");

SCR1_SVA_LSU_REQ_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2exu_exc_o |-> exu2lsu_req_i
    ) else $error("LSU Error: impossible exception");

`ifdef SCR1_TDU_EN

SCR1_COV_LSU_MISALIGN_BRKPT : cover property (
    @(negedge clk) disable iff (~rst_n)
    (dmem_addr_mslgn_l | dmem_addr_mslgn_s) & lsu_exc_hwbrk
);
`endif // SCR1_TDU_EN

`endif // SCR1_TRGT_SIMULATION

endmodule : scr1_pipe_lsu
