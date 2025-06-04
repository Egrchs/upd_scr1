module mips_to_riscv_translator (
    input clk,
    input reset,
    input [31:0] mips_instruction,
    output reg [31:0] riscv_instruction,
    output reg translation_valid,
    output reg instruction_ready
);

    // Состояния автомата
    parameter IDLE = 2'b00;
    parameter FIRST_CYCLE = 2'b01;
    parameter SECOND_CYCLE = 2'b10;
    parameter DONE = 2'b11;
    
    reg [1:0] current_state, next_state;
    
    // Внутренние регистры
    reg [31:0] imm_upper;
    reg [4:0] temp_reg;
    reg needs_split;
    reg [31:0] saved_instruction;
    reg is_load_store;
    reg is_fp;
    
    // Поля инструкции MIPS
    wire [5:0] mips_opcode = mips_instruction[31:26];
    wire [4:0] mips_rs = mips_instruction[25:21];
    wire [4:0] mips_rt = mips_instruction[20:16];
    wire [4:0] mips_rd = mips_instruction[15:11];
    wire [4:0] mips_shamt = mips_instruction[10:6];
    wire [5:0] mips_funct = mips_instruction[5:0];
    wire [15:0] mips_imm = mips_instruction[15:0];
    wire [25:0] mips_target = mips_instruction[25:0];
    
    // Логика следующего состояния
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Логика перехода состояний
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (translation_valid) next_state = FIRST_CYCLE;
            FIRST_CYCLE: next_state = needs_split ? SECOND_CYCLE : DONE;
            SECOND_CYCLE: next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end
    
    // Определение необходимости разбиения
    always @(*) begin
        needs_split = 1'b0;
        is_load_store = 1'b0;
        is_fp = 1'b0;
        
        casez ({mips_opcode, mips_funct})
            // I-type instructions
            12'b001000??????,  // ADDI
            12'b001100??????,  // ANDI
            12'b001101??????,  // ORI
            12'b001110??????,  // XORI
            12'b001010??????,  // SLTI
            12'b001011??????:  // SLTIU
                if (mips_imm[15:12] != 4'b0000 && mips_imm[15:12] != 4'b1111)
                    needs_split = 1'b1;
            
            // Load/Store instructions
            12'b100011??????,  // LW
            12'b100000??????,  // LB
            12'b100100??????,  // LBU
            12'b101011??????,  // SW
            12'b101000??????: begin // SB
                if (mips_imm[15:12] != 4'b0000 && mips_imm[15:12] != 4'b1111) begin
                    needs_split = 1'b1;
                    is_load_store = 1'b1;
                end
            end
            
            // Floating-point
            12'b010001110000,  // LWC1
            12'b010001111000: begin // SWC1
                if (mips_imm[15:12] != 4'b0000 && mips_imm[15:12] != 4'b1111) begin
                    needs_split = 1'b1;
                    is_load_store = 1'b1;
                    is_fp = 1'b1;
                end
            end
            
            default: needs_split = 1'b0;
        endcase
    end
    
    // Основная логика перевода
    always @(*) begin
        // Значения по умолчанию
        riscv_instruction = 32'b0;
        translation_valid = 1'b1;
        instruction_ready = 1'b0;
        imm_upper = 32'b0;
        temp_reg = 5'b0;
        
        case (current_state)
            IDLE: begin
                instruction_ready = 1'b0;
                // Определяем временный регистр назначения
                if (mips_opcode == 6'b100011 || mips_opcode == 6'b100000 || 
                    mips_opcode == 6'b100100 || (mips_opcode[5:3] == 3'b001) ||
                    mips_opcode == 6'b010001) begin
                    temp_reg = mips_rt;
                end else begin
                    temp_reg = mips_rd;
                end
            end
            
            FIRST_CYCLE: begin
                if (needs_split) begin
                    // Первая инструкция - LUI
                    riscv_instruction = {
                        {20{mips_imm[15]}},  // sign-extend
                        mips_imm[15:12],    // upper 4 bits
                        12'b0,               // zero lower 12 bits
                        5'b0,               // rd = x0
                        7'b0110111          // LUI
                    };
                    instruction_ready = 1'b1;
                end else begin
                    // Инструкции без разбиения
                    casez ({mips_opcode, mips_funct})
                        // R-type
                        12'b000000100000: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b000, mips_rd, 7'b0110011}; // ADD
                        12'b000000100010: riscv_instruction = {7'b0100000, mips_rt, mips_rs, 3'b000, mips_rd, 7'b0110011}; // SUB
                        12'b000000100100: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b111, mips_rd, 7'b0110011}; // AND
                        12'b000000100101: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b110, mips_rd, 7'b0110011}; // OR
                        12'b000000100110: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b100, mips_rd, 7'b0110011}; // XOR
                        12'b000000100111: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b110, mips_rd, 7'b0110011}; // NOR
                        12'b000000101010: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b010, mips_rd, 7'b0110011}; // SLT
                        12'b000000101011: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b011, mips_rd, 7'b0110011}; // SLTU
                        12'b000000000000: riscv_instruction = {7'b0000000, mips_shamt, mips_rs, 3'b001, mips_rd, 7'b0110011}; // SLL
                        12'b000000000010: riscv_instruction = {7'b0000000, mips_shamt, mips_rs, 3'b101, mips_rd, 7'b0110011}; // SRL
                        12'b000000000011: riscv_instruction = {7'b0100000, mips_shamt, mips_rs, 3'b101, mips_rd, 7'b0110011}; // SRA
                        
                        // I-type (small immediates)
                        12'b001000??????: riscv_instruction = {mips_imm, mips_rs, 3'b000, mips_rt, 7'b0010011}; // ADDI
                        12'b001100??????: riscv_instruction = {mips_imm, mips_rs, 3'b111, mips_rt, 7'b0010011}; // ANDI
                        12'b001101??????: riscv_instruction = {mips_imm, mips_rs, 3'b110, mips_rt, 7'b0010011}; // ORI
                        12'b001110??????: riscv_instruction = {mips_imm, mips_rs, 3'b100, mips_rt, 7'b0010011}; // XORI
                        12'b001010??????: riscv_instruction = {mips_imm, mips_rs, 3'b010, mips_rt, 7'b0010011}; // SLTI
                        12'b001011??????: riscv_instruction = {mips_imm, mips_rs, 3'b011, mips_rt, 7'b0010011}; // SLTIU
                        
                        // Branches
                        12'b000100??????: riscv_instruction = {mips_imm[15], mips_imm[14:1], 1'b0, mips_rt, mips_rs, 3'b000, mips_imm[4:1], mips_imm[11], 7'b1100011}; // BEQ
                        12'b000101??????: riscv_instruction = {mips_imm[15], mips_imm[14:1], 1'b0, mips_rt, mips_rs, 3'b001, mips_imm[4:1], mips_imm[11], 7'b1100011}; // BNE
                        
                        // Load/Store (small immediates)
                        12'b100011??????: riscv_instruction = {mips_imm, mips_rs, 3'b010, mips_rt, 7'b0000011}; // LW
                        12'b100000??????: riscv_instruction = {mips_imm, mips_rs, 3'b000, mips_rt, 7'b0000011}; // LB
                        12'b100100??????: riscv_instruction = {mips_imm, mips_rs, 3'b100, mips_rt, 7'b0000011}; // LBU
                        12'b101011??????: riscv_instruction = {mips_imm[11:5], mips_rt, mips_rs, 3'b010, mips_imm[4:0], 7'b0100011}; // SW
                        12'b101000??????: riscv_instruction = {mips_imm[11:5], mips_rt, mips_rs, 3'b000, mips_imm[4:0], 7'b0100011}; // SB
                        
                        // Jumps
                        12'b000010??????: riscv_instruction = {mips_target[25], mips_target[24:5], 1'b0, 5'b00000, 7'b1101111}; // J
                        12'b000011??????: riscv_instruction = {mips_target[25], mips_target[24:5], 1'b0, 5'b00001, 7'b1101111}; // JAL
                        12'b000000001000: riscv_instruction = {12'b0, mips_rs, 3'b000, 5'b00000, 7'b1100111}; // JR
                        12'b000000001001: riscv_instruction = {12'b0, mips_rs, 3'b000, 5'b00001, 7'b1100111}; // JALR
                        
                        // Floating-point
                        12'b010001000000: riscv_instruction = {12'b0, mips_rt, 3'b000, mips_rd, 7'b0001011}; // MFC1
                        12'b010001000100: riscv_instruction = {12'b0, mips_rt, 3'b000, mips_rd, 7'b0001011}; // MTC1
                        12'b010001010000: riscv_instruction = {7'b0000000, mips_rt, mips_rs, 3'b000, mips_rd, 7'b1010011}; // FADD.S
                        12'b010001010001: riscv_instruction = {7'b0000100, mips_rt, mips_rs, 3'b000, mips_rd, 7'b1010011}; // FSUB.S
                        12'b010001010010: riscv_instruction = {7'b0001000, mips_rt, mips_rs, 3'b000, mips_rd, 7'b1010011}; // FMUL.S
                        12'b010001010011: riscv_instruction = {7'b0001100, mips_rt, mips_rs, 3'b000, mips_rd, 7'b1010011}; // FDIV.S
                        12'b010001110000: riscv_instruction = {mips_imm, mips_rs, 3'b010, mips_rt, 7'b0000111}; // LWC1
                        12'b010001111000: riscv_instruction = {mips_imm[11:5], mips_rt, mips_rs, 3'b010, mips_imm[4:0], 7'b0100111}; // SWC1
                        
                        // System
                        12'b000000001100: riscv_instruction = {12'b0, 5'b00000, 3'b000, 5'b00000, 7'b1110011}; // SYSCALL
                        12'b000000001101: riscv_instruction = {12'b1, 5'b00000, 3'b000, 5'b00000, 7'b1110011}; // BREAK
                        
                        default: begin
                            riscv_instruction = 32'b0;
                            translation_valid = 1'b0;
                        end
                    endcase
                    instruction_ready = 1'b1;
                end
            end
            
            SECOND_CYCLE: begin
                instruction_ready = 1'b1;
                casez ({saved_instruction[31:26], saved_instruction[5:0]})
                    // I-type second part
                    12'b001000??????: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b000, temp_reg, 7'b0010011}; // ADDI
                    12'b001100??????: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b111, temp_reg, 7'b0010011}; // ANDI
                    
                    // Load/Store second part
                    12'b100011??????: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b010, temp_reg, 7'b0000011}; // LW
                    12'b101011??????: riscv_instruction = {saved_instruction[15:11], saved_instruction[20:16], saved_instruction[25:21], 3'b010, saved_instruction[10:6], 7'b0100011}; // SW
                    
                    // FP second part
                    12'b010001110000: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b010, temp_reg, 7'b0000111}; // LWC1
                    12'b010001111000: riscv_instruction = {saved_instruction[15:11], saved_instruction[20:16], saved_instruction[25:21], 3'b010, saved_instruction[10:6], 7'b0100111}; // SWC1
                    
                    default: riscv_instruction = 32'b0;
                endcase
            end
            
            DONE: begin
                instruction_ready = 1'b0;
            end
        endcase
    end
    
    // Сохранение инструкции
    always @(posedge clk) begin
        if (current_state == IDLE) begin
            saved_instruction <= mips_instruction;
        end
    end
endmodule