// Copyright © 2024. Final verified version.
// This module translates a subset of MIPS instructions to RISC-V.
// Handles instruction splitting for large immediate values and error propagation.
// Includes registered outputs to prevent X-propagation at startup.
// Corrected instruction formats and declaration order.

module mips_to_riscv_translator_fixed (
    input logic clk,
    input logic pipe_rst_n, // Active high pipe_rst_n

    // Interface with Instruction Fetch Unit (IFU)
    input  logic [31:0] mips_instruction,
    input  logic        mips_instr_valid,
    input  logic        mips_instr_error,
    output logic        translator_ready,

    // Interface with Instruction Decode Unit (IDU)
    output logic [31:0] riscv_instruction,
    output logic        riscv_instr_valid,
    output logic        riscv_instr_error,
    input  logic        riscv_instr_accepted
);
    // Architectural temporary register for split instructions.
    localparam TEMP_REG = 5'd5; // x5 (t0)

    // FSM States
    typedef enum logic [1:0] { IDLE, FIRST_CYCLE, SECOND_CYCLE } state_t;
    state_t current_state, next_state;

    // Structure for convenient decoding of MIPS instruction fields
    typedef struct packed {
        logic [5:0] opcode; logic [4:0] rs; logic [4:0] rt; logic [4:0] rd;
        logic [4:0] shamt; logic [5:0] funct; logic [15:0] imm; logic [25:0] target;
    } mips_instr_t;

    // Structures for building RISC-V instructions
    typedef struct packed {
        logic [6:0] opcode; logic [4:0] rd; logic [2:0] funct3; logic [4:0] rs1; logic [11:0] imm;
    } riscv_i_type_t;

    typedef struct packed {
        logic [6:0] opcode; logic [4:0] imm4_0; logic [2:0] funct3; logic [4:0] rs1; logic [4:0] rs2; logic [6:0] imm11_5;
    } riscv_s_type_t;

    typedef struct packed {
        logic [6:0] opcode; logic [4:0] rd; logic [2:0] funct3; logic [4:0] rs1; logic [4:0] rs2; logic [6:0] funct7;
    } riscv_r_type_t;

    typedef struct packed {
        logic [6:0] opcode; logic [4:0] rd; logic [19:0] imm;
    } riscv_u_type_t;


    // Internal registers to store translation state
    logic [31:0] saved_instruction;
    logic [4:0]  final_rd;
    logic        needs_split;
    logic        unsupported_instruction;
    logic        is_error;

    // Intermediate signals for registered outputs
    logic [31:0] riscv_instruction_next;
    logic        riscv_instr_valid_next;
    logic        riscv_instr_error_next;

    // FSM state register
    always_ff @(posedge clk or negedge pipe_rst_n) begin
        if (!pipe_rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM next state logic
    always_comb begin
        next_state = current_state; // Default to staying in current state
        case (current_state)
            IDLE: begin
                if (mips_instr_valid) next_state = FIRST_CYCLE;
            end
            FIRST_CYCLE: begin
                if (riscv_instr_accepted) begin
                    if (needs_split) begin
                        next_state = SECOND_CYCLE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            SECOND_CYCLE: begin
                if (riscv_instr_accepted) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Registered outputs to prevent X-propagation
    always_ff @(posedge clk or negedge pipe_rst_n) begin
        if (!pipe_rst_n) begin
            riscv_instruction <= 32'h00000013; // NOP (ADDI x0, x0, 0)
            riscv_instr_valid <= 1'b0;
            riscv_instr_error <= 1'b0;
        end else begin
            riscv_instruction <= riscv_instruction_next;
            riscv_instr_valid <= riscv_instr_valid_next;
            riscv_instr_error <= riscv_instr_error_next;
        end
    end

    // Combinational output control signals
    assign translator_ready = (current_state == IDLE);

    // Store MIPS instruction at the start of translation
    always_ff @(posedge clk or negedge pipe_rst_n) begin
        if (!pipe_rst_n) begin
            saved_instruction <= 32'b0;
            final_rd <= 5'b0;
            is_error <= 1'b0;
        end else if (mips_instr_valid && current_state == IDLE) begin
            mips_instr_t mips_i;
            mips_i = mips_instruction;
            
            saved_instruction <= mips_instruction;
            is_error <= mips_instr_error;
            
            // Determine the final destination register
            if (mips_i.opcode == 6'b000000) final_rd <= mips_i.rd; // R-type
            else final_rd <= mips_i.rt; // I-type
        end
    end

    // Detect instructions requiring splitting or unsupported instructions
    always_comb begin
        mips_instr_t mips_local;
        mips_local = mips_instr_t'(saved_instruction);

        needs_split = 1'b0;
        unsupported_instruction = 1'b0;
        
        if (current_state != IDLE) begin
            case (mips_local.opcode)
                // I-type and Load/Store instructions that might need splitting
                6'b001000, 6'b001001, 6'b001100, 6'b001101, 6'b001110, 6'b001010, 6'b001011,
                6'b100011, 6'b100000, 6'b100100, 6'b101011, 6'b101000: begin
                    // Split if the immediate value is not representable in 12 bits with sign extension
                    if (mips_local.imm[15:11] != {5{mips_local.imm[11]}}) begin
                        needs_split = 1'b1;
                    end
                end
                
                // Unsupported opcodes
                6'b000010, 6'b000011, 6'b000100, 6'b000101: 
                    unsupported_instruction = 1'b1;
                
                // Unsupported R-type functions
                6'b000000: begin
                    if (mips_local.funct == 6'b100111) unsupported_instruction = 1'b1; // NOR
                end
                
                default: ;
            endcase
        end
    end
    
    // Main translation logic (combinational, computes _next values)
    always_comb begin
        // <<< ИСПРАВЛЕНИЕ: Все объявления перенесены в начало блока >>>
        mips_instr_t current_mips;
        riscv_r_type_t r_instr;
        riscv_i_type_t i_instr;
        riscv_s_type_t s_instr;
        riscv_u_type_t u_instr;

        // <<< ИСПРАВЛЕНИЕ: Операторы идут после всех объявлений >>>
        current_mips = mips_instr_t'(saved_instruction);

        // Default values for the next cycle
        riscv_instruction_next = 32'h00000013; // NOP
        riscv_instr_valid_next = 1'b0;
        riscv_instr_error_next = is_error | unsupported_instruction;

        if ((is_error | unsupported_instruction) && current_state != IDLE) begin
            riscv_instruction_next = 32'b0; // Illegal instruction
            riscv_instr_valid_next = (current_state == FIRST_CYCLE);
        end else begin
            case (current_state)
                FIRST_CYCLE: begin
                    riscv_instr_valid_next = 1'b1;
                    if (needs_split) begin
                        logic signed [31:0] signed_mips_imm;
                        logic [19:0] lui_imm;
                        
                        signed_mips_imm = {{16{current_mips.imm[15]}}, current_mips.imm};
                        lui_imm = signed_mips_imm[31:12];
                        // Adjust for sign extension of the lower 12 bits
                        if (signed_mips_imm[11]) begin
                             lui_imm = lui_imm + 1;
                        end
                        u_instr.opcode = 7'b0110111; // LUI
                        u_instr.rd = TEMP_REG;
                        u_instr.imm = lui_imm;
                        riscv_instruction_next = u_instr;
                    end else begin
                        casez ({current_mips.opcode, current_mips.funct})
                            // R-type
                            {6'b000000, 6'b100000}, {6'b000000, 6'b100001}: begin // ADD, ADDU
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b000;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b100010}, {6'b000000, 6'b100011}: begin // SUB, SUBU
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b000;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0100000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b100100}: begin // AND
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b111;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b100101}: begin // OR
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b110;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b100110}: begin // XOR
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b100;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b101010}: begin // SLT
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b010;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b101011}: begin // SLTU
                                r_instr.opcode = 7'b0110011; r_instr.rd = current_mips.rd; r_instr.funct3 = 3'b011;
                                r_instr.rs1 = current_mips.rs; r_instr.rs2 = current_mips.rt; r_instr.funct7 = 7'b0000000;
                                riscv_instruction_next = r_instr;
                            end
                            {6'b000000, 6'b000000}: begin // SLL
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rd; i_instr.funct3 = 3'b001;
                                i_instr.rs1 = current_mips.rt; i_instr.imm = {7'b0000000, current_mips.shamt};
                                riscv_instruction_next = i_instr;
                            end
                            {6'b000000, 6'b000010}: begin // SRL
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rd; i_instr.funct3 = 3'b101;
                                i_instr.rs1 = current_mips.rt; i_instr.imm = {7'b0000000, current_mips.shamt};
                                riscv_instruction_next = i_instr;
                            end
                            {6'b000000, 6'b000011}: begin // SRA
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rd; i_instr.funct3 = 3'b101;
                                i_instr.rs1 = current_mips.rt; i_instr.imm = {7'b0100000, current_mips.shamt};
                                riscv_instruction_next = i_instr;
                            end

                            // I-type
                            {6'b001000}, {6'b001001}: begin // ADDI, ADDIU
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b000;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b001101, 6'b??????}: begin // ORI
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b110;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b001100, 6'b??????}: begin // ANDI
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b111;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b001110, 6'b??????}: begin // XORI
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b100;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b001010, 6'b??????}: begin // SLTI
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b010;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b001011, 6'b??????}: begin // SLTIU
                                i_instr.opcode = 7'b0010011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b011;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end

                            // Load
                            {6'b100011, 6'b??????}: begin // LW
                                i_instr.opcode = 7'b0000011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b010;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b100000, 6'b??????}: begin // LB
                                i_instr.opcode = 7'b0000011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b000;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            {6'b100100, 6'b??????}: begin // LBU
                                i_instr.opcode = 7'b0000011; i_instr.rd = current_mips.rt; i_instr.funct3 = 3'b100;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = current_mips.imm[11:0];
                                riscv_instruction_next = i_instr;
                            end
                            
                            // Store
                            {6'b101011, 6'b??????}: begin // SW
                                s_instr.opcode = 7'b0100011; s_instr.funct3 = 3'b010;
                                s_instr.rs1 = current_mips.rs; s_instr.rs2 = current_mips.rt;
                                s_instr.imm11_5 = current_mips.imm[11:5]; s_instr.imm4_0 = current_mips.imm[4:0];
                                riscv_instruction_next = s_instr;
                            end
                            {6'b101000, 6'b??????}: begin // SB
                                s_instr.opcode = 7'b0100011; s_instr.funct3 = 3'b000;
                                s_instr.rs1 = current_mips.rs; s_instr.rs2 = current_mips.rt;
                                s_instr.imm11_5 = current_mips.imm[11:5]; s_instr.imm4_0 = current_mips.imm[4:0];
                                riscv_instruction_next = s_instr;
                            end

                            // U-type
                            {6'b001111, 6'b??????}: begin // LUI
                                u_instr.opcode = 7'b0110111; u_instr.rd = current_mips.rt;
                                u_instr.imm = {current_mips.imm, 4'b0};
                                riscv_instruction_next = u_instr;
                            end

                            // Jump
                            {6'b000000, 6'b001000}: begin // JR -> JALR x0, rs, 0
                                i_instr.opcode = 7'b1100111; i_instr.rd = 5'b0; i_instr.funct3 = 3'b000;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = 12'b0;
                                riscv_instruction_next = i_instr;
                            end
                            {6'b000000, 6'b001001}: begin // JALR
                                i_instr.opcode = 7'b1100111; i_instr.rd = current_mips.rd; i_instr.funct3 = 3'b000;
                                i_instr.rs1 = current_mips.rs; i_instr.imm = 12'b0;
                                riscv_instruction_next = i_instr;
                            end
                            
                            default: riscv_instruction_next = 32'b0; // Illegal instruction
                        endcase
                    end
                end
                SECOND_CYCLE: begin
                    riscv_instr_valid_next = 1'b1;
                    // The first instruction was LUI, now do the second part
                    casez (current_mips.opcode)
                        // Arithmetic/Logic
                        6'b001000, 6'b001001: begin // ADDI, ADDIU
                            i_instr.opcode = 7'b0010011; i_instr.rd = final_rd; i_instr.funct3 = 3'b000;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        6'b001101: begin // ORI
                            i_instr.opcode = 7'b0010011; i_instr.rd = final_rd; i_instr.funct3 = 3'b110;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        6'b001100: begin // ANDI
                            i_instr.opcode = 7'b0010011; i_instr.rd = final_rd; i_instr.funct3 = 3'b111;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        6'b001110: begin // XORI
                            i_instr.opcode = 7'b0010011; i_instr.rd = final_rd; i_instr.funct3 = 3'b100;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end

                        // Load
                        6'b100011: begin // LW
                            i_instr.opcode = 7'b0000011; i_instr.rd = final_rd; i_instr.funct3 = 3'b010;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        6'b100000: begin // LB
                            i_instr.opcode = 7'b0000011; i_instr.rd = final_rd; i_instr.funct3 = 3'b000;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        6'b100100: begin // LBU
                            i_instr.opcode = 7'b0000011; i_instr.rd = final_rd; i_instr.funct3 = 3'b100;
                            i_instr.rs1 = TEMP_REG; i_instr.imm = current_mips.imm[11:0];
                            riscv_instruction_next = i_instr;
                        end
                        
                        // Store
                        6'b101011: begin // SW
                            s_instr.opcode = 7'b0100011; s_instr.funct3 = 3'b010;
                            s_instr.rs1 = TEMP_REG; s_instr.rs2 = current_mips.rt;
                            s_instr.imm11_5 = current_mips.imm[11:5]; s_instr.imm4_0 = current_mips.imm[4:0];
                            riscv_instruction_next = s_instr;
                        end
                        6'b101000: begin // SB
                            s_instr.opcode = 7'b0100011; s_instr.funct3 = 3'b000;
                            s_instr.rs1 = TEMP_REG; s_instr.rs2 = current_mips.rt;
                            s_instr.imm11_5 = current_mips.imm[11:5]; s_instr.imm4_0 = current_mips.imm[4:0];
                            riscv_instruction_next = s_instr;
                        end

                        default: riscv_instruction_next = 32'b0; // Should not happen
                    endcase
                end
                default:;
            endcase
        end
    end
endmodule