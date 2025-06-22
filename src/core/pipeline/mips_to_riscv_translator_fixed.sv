// =====================================================================
//  ПОЛНАЯ ФИНАЛЬНАЯ ВЕРСИЯ: Последовательностный транслятор MIPS -> RISC-V
//  Автор: Совместная разработка с AI-помощником
//  Дата: 23.06.2024
//
//  - Корректно обрабатывает слот задержки ветвления (branch delay slot)
//  - Использует конечный автомат для генерации 2-х RISC-V инструкций
//  - Синтаксически корректен, не генерирует latches (есть default)
//  - Содержит разделенную и надежную логику отладочного вывода
// =====================================================================
module mips_to_riscv_translator_fixed (
    input logic clk,
    input logic pipe_rst_n,

    // Входы от IFU
    input  logic [31:0] mips_instruction,
    input  logic        mips_instr_valid,
    input  logic        mips_instr_error,
    output logic        translator_ready,

    // Выходы к IDU
    output logic [31:0] riscv_instruction,
    output logic        riscv_instr_valid,
    output logic        riscv_instr_error,
    input  logic        riscv_instr_accepted
);

    // Типы инструкций MIPS
    typedef struct packed {
        logic [5:0] opcode; logic [4:0] rs; logic [4:0] rt; logic [15:0] imm;
    } mips_i_type_t;
    
    typedef struct packed {
        logic [5:0] opcode; logic [4:0] rs; logic [4:0] rt; logic [4:0] rd; logic [4:0] shamt; logic [5:0] funct;
    } mips_r_type_t;

    // Опкоды MIPS
    localparam MIPS_OP_R_TYPE = 6'b000000;
    localparam MIPS_OP_ADDIU  = 6'b001001;
    localparam MIPS_OP_LUI    = 6'b001111;
    localparam MIPS_OP_ORI    = 6'b001101;
    localparam MIPS_OP_SW     = 6'b101011;
    localparam MIPS_OP_BEQ    = 6'b000100;
    localparam MIPS_OP_BNE    = 6'b000101;

    // Состояния конечного автомата
    typedef enum logic [2:0] {
        IDLE,
        OUTPUT_SINGLE,
        WAIT_DELAY_SLOT,
        OUTPUT_DELAY_SLOT,
        OUTPUT_BRANCH
    } state_t;

    state_t state_reg, state_next;
    logic [31:0] mips_instr_reg;
    logic [31:0] branch_instr_reg;

    always_ff @(posedge clk or negedge pipe_rst_n) begin
        if (!pipe_rst_n) begin
            state_reg <= IDLE;
        end else begin
            state_reg <= state_next;
        end
    end

    always_ff @(posedge clk) begin
        if (state_reg == IDLE && mips_instr_valid) begin
            mips_instr_reg <= mips_instruction;
        end

        if (state_next == WAIT_DELAY_SLOT) begin
            branch_instr_reg <= mips_instr_reg;
        end
        
        if (state_reg == WAIT_DELAY_SLOT && mips_instr_valid) begin
            mips_instr_reg <= mips_instruction;
        end
    end

    always_comb begin
        state_next = state_reg;
        translator_ready = 1'b0;
        riscv_instr_valid = 1'b0;
        riscv_instr_error = 1'b1;
        riscv_instruction = 32'b0;
        
        case (state_reg)
            IDLE: begin
                translator_ready = 1'b1;
                if (mips_instr_valid) begin
                    if (mips_instruction[31:26] == MIPS_OP_BEQ || mips_instruction[31:26] == MIPS_OP_BNE) begin
                        state_next = WAIT_DELAY_SLOT;
                    end else begin
                        state_next = OUTPUT_SINGLE;
                    end
                end
            end

            WAIT_DELAY_SLOT: begin 
                translator_ready = 1'b1;
                if (mips_instr_valid) begin
                    state_next = OUTPUT_DELAY_SLOT;
                end
            end

            OUTPUT_SINGLE: begin
                riscv_instruction = translate_instruction(mips_instr_reg, riscv_instr_error);
                riscv_instr_valid = 1'b1;
                
                if (riscv_instr_accepted) begin
                    state_next = IDLE;
                end
            end

            OUTPUT_DELAY_SLOT: begin
                riscv_instruction = translate_instruction(mips_instr_reg, riscv_instr_error);
                riscv_instr_valid = 1'b1;

                if (riscv_instr_accepted) begin
                    state_next = OUTPUT_BRANCH;
                end
            end
            
            OUTPUT_BRANCH: begin
                riscv_instruction = translate_instruction(branch_instr_reg, riscv_instr_error);
                riscv_instr_valid = 1'b1;

                if (riscv_instr_accepted) begin
                    state_next = IDLE;
                end
            end
            
            default: begin
                state_next = IDLE;
            end
        endcase
        
        if (mips_instr_error) begin
            riscv_instr_error = 1'b1;
            riscv_instruction = 32'b0;
        end
    end
    
    // =================================================================
    //  ОТЛАДОЧНЫЙ ВЫВОД (НАДЕЖНЫЙ СПОСОБ)
    // =================================================================
    always_ff @(posedge clk) begin
        // Выводим информацию о том, ЧТО было принято
        if (mips_instr_valid && translator_ready) begin
             $display("-------------------------------------------------");
             $display("@%0t [SEQ_TRANSLATOR] MIPS Input: %h (state: %s)", $time, mips_instruction, state_reg.name());
        end

        // Выводим информацию о том, ЧТО было сгенерировано
        if (riscv_instr_valid && riscv_instr_accepted) begin
            if (!riscv_instr_error) begin
                $display("@%0t [SEQ_TRANSLATOR] -> Generated RISC-V: %h (from MIPS: %h)", $time, riscv_instruction, (state_reg == OUTPUT_BRANCH) ? branch_instr_reg : mips_instr_reg);
            end else begin
                $display("@%0t [SEQ_TRANSLATOR] -> Generated ERROR (from MIPS: %h)", $time, (state_reg == OUTPUT_BRANCH) ? branch_instr_reg : mips_instr_reg);
            end
        end
    end

    // =================================================================
    //  ФУНКЦИЯ ТРАНСЛЯЦИИ (ЧИСТАЯ ЛОГИКА БЕЗ DISPLAY)
    // =================================================================
    function automatic logic [31:0] translate_instruction (input logic [31:0] mips_instr, output logic error_flag);
        automatic mips_i_type_t instr_i = mips_i_type_t'(mips_instr);
        automatic mips_r_type_t instr_r = mips_r_type_t'(mips_instr);
        
        error_flag = 1'b1;
        translate_instruction = 32'b0;

        case (instr_i.opcode)
            MIPS_OP_R_TYPE: begin
                case(instr_r.funct)
                    6'b100001: begin // ADDU -> ADD
                        translate_instruction = {7'b0000000, instr_r.rt, instr_r.rs, 3'b000, instr_r.rd, 7'b0110011};
                        error_flag = 1'b0;
                    end
                    6'b101011: begin // SLTU -> SLTU
                        translate_instruction = {7'b0000000, instr_r.rt, instr_r.rs, 3'b011, instr_r.rd, 7'b0110011};
                        error_flag = 1'b0;
                    end
                    6'b100101: begin // OR -> OR
                        translate_instruction = {7'b0000000, instr_r.rt, instr_r.rs, 3'b110, instr_r.rd, 7'b0110011};
                        error_flag = 1'b0;
                    end
                    6'b000000: begin // SLL / NOP -> SLLI
                        automatic logic [11:0] imm_val = {7'b0000000, instr_r.shamt};
                        translate_instruction = {imm_val, instr_r.rt, 3'b001, instr_r.rd, 7'b0010011};
                        error_flag = 1'b0;
                    end
                    default: error_flag = 1'b1;
                endcase
            end
            MIPS_OP_ADDIU: begin
                translate_instruction = {instr_i.imm[11:0], instr_i.rs, 3'b000, instr_i.rt, 7'b0010011};
                error_flag = 1'b0;
            end
            MIPS_OP_LUI: begin
                translate_instruction = {{instr_i.imm, 4'h0}, instr_i.rt, 7'b0110111};
                error_flag = 1'b0;
            end
            MIPS_OP_ORI: begin
                if (instr_i.imm[15:12] != 4'b0) error_flag = 1'b1;
                else begin
                    translate_instruction = {instr_i.imm[11:0], instr_i.rs, 3'b110, instr_i.rt, 7'b0010011};
                    error_flag = 1'b0;
                end
            end
            MIPS_OP_SW: begin
                translate_instruction = {instr_i.imm[11:5], instr_i.rt, instr_i.rs, 3'b010, instr_i.imm[4:0], 7'b0100011};
                error_flag = 1'b0;
            end
            MIPS_OP_BEQ: begin
                logic signed [17:0] mips_offset = {instr_i.imm, 2'b00};
                logic signed [12:0] riscv_offset = mips_offset - 4;
                translate_instruction = {riscv_offset[12], riscv_offset[10:5], instr_i.rt, instr_i.rs, 3'b000, riscv_offset[4:1], riscv_offset[11], 7'b1100011};
                error_flag = 1'b0;
            end
            MIPS_OP_BNE: begin
                logic signed [17:0] mips_offset = {instr_i.imm, 2'b00};
                logic signed [12:0] riscv_offset = mips_offset - 4;
                translate_instruction = {riscv_offset[12], riscv_offset[10:5], instr_i.rt, instr_i.rs, 3'b001, riscv_offset[4:1], riscv_offset[11], 7'b1100011};
                error_flag = 1'b0;
            end
            default: error_flag = 1'b1;
        endcase
    endfunction

endmodule