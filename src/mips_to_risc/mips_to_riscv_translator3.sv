module mips_to_riscv_translator (
    input logic clk,
    input logic reset,
    input logic [31:0] mips_instruction,
    output logic [31:0] riscv_instruction,
    output logic translation_valid,
    output logic instruction_ready
);
    // Состояния автомата
    typedef enum logic [1:0] {
        IDLE,
        FIRST_CYCLE,
        SECOND_CYCLE,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Поля инструкции MIPS
    typedef struct packed {
        logic [5:0] opcode;
        logic [4:0] rs;
        logic [4:0] rt;
        logic [4:0] rd;
        logic [4:0] shamt;
        logic [5:0] funct;
        logic [15:0] imm;
        logic [25:0] target;
    } mips_instr_t;
    
    mips_instr_t mips;
    assign mips.opcode = mips_instruction[31:26];
    assign mips.rs = mips_instruction[25:21];
    assign mips.rt = mips_instruction[20:16];
    assign mips.rd = mips_instruction[15:11];
    assign mips.shamt = mips_instruction[10:6];
    assign mips.funct = mips_instruction[5:0];
    assign mips.imm = mips_instruction[15:0];
    assign mips.target = mips_instruction[25:0];
    
    // Внутренние регистры
    logic [31:0] imm_upper;
    logic [4:0] temp_reg;
    logic needs_split;
    logic [31:0] saved_instruction;
    logic is_load_store;
    logic is_fp;
    
    // Логика следующего состояния
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Логика перехода состояний
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: if (translation_valid) next_state = FIRST_CYCLE;
            FIRST_CYCLE: next_state = needs_split ? SECOND_CYCLE : DONE;
            SECOND_CYCLE: next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end
    
    // Определение необходимости разбиения
    always_comb begin
        needs_split = 1'b0;
        is_load_store = 1'b0;
        is_fp = 1'b0;
        
        casez ({mips.opcode, mips.funct})
            // I-type instructions that might need splitting
            {6'b001000, 6'b??????},  // ADDI
            {6'b001100, 6'b??????},  // ANDI
            {6'b001101, 6'b??????},  // ORI
            {6'b001110, 6'b??????},  // XORI
            {6'b001010, 6'b??????},  // SLTI
            {6'b001011, 6'b??????}:  // SLTIU
                if (mips.imm[15:12] != 4'b0000 && mips.imm[15:12] != 4'b1111)
                    needs_split = 1'b1;
            
            // Load/Store instructions
            {6'b100011, 6'b??????},  // LW
            {6'b100000, 6'b??????},  // LB
            {6'b100100, 6'b??????},  // LBU
            {6'b101011, 6'b??????},  // SW
            {6'b101000, 6'b??????}: begin // SB
                if (mips.imm[15:12] != 4'b0000 && mips.imm[15:12] != 4'b1111) begin
                    needs_split = 1'b1;
                    is_load_store = 1'b1;
                end
            end
            
            // Floating-point instructions
            {6'b010001, 6'b110000},  // LWC1
            {6'b010001, 6'b111000}: begin // SWC1
                if (mips.imm[15:12] != 4'b0000 && mips.imm[15:12] != 4'b1111) begin
                    needs_split = 1'b1;
                    is_load_store = 1'b1;
                    is_fp = 1'b1;
                end
            end
            
            default: needs_split = 1'b0;
        endcase
    end
    
    // Основная логика перевода
    always_comb begin
        // Значения по умолчанию
        riscv_instruction = '0;
        translation_valid = 1'b1;
        instruction_ready = 1'b0;
        imm_upper = '0;
        temp_reg = '0;
        
        case (current_state)
            IDLE: begin
                instruction_ready = 1'b0;
                // Сохраняем временный регистр назначения
                temp_reg = (mips.opcode inside {6'b100011, 6'b100000, 6'b100100, 6'b001???, 
                                              6'b010001}) ? mips.rt : mips.rd;
            end
            
            FIRST_CYCLE: begin
                if (needs_split) begin
                    // Первая инструкция - загрузка верхних битов
                    riscv_instruction = {
                        {20{mips.imm[15]}},  // sign-extend
                        mips.imm[15:12],    // upper 4 bits
                        12'b0,               // zero lower 12 bits
                        5'b0,               // rd = x0 (will be overwritten)
                        7'b0110111          // LUI
                    };
                    instruction_ready = 1'b1;
                end else begin
                    // Инструкция не требует разбиения
                    casez ({mips.opcode, mips.funct})
                        // R-type instructions
                        {6'b000000, 6'b100000}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b000, mips.rd, 7'b0110011}; // ADD
                        {6'b000000, 6'b100010}: riscv_instruction = {7'b0100000, mips.rt, mips.rs, 3'b000, mips.rd, 7'b0110011}; // SUB
                        {6'b000000, 6'b100100}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b111, mips.rd, 7'b0110011}; // AND
                        {6'b000000, 6'b100101}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b110, mips.rd, 7'b0110011}; // OR
                        {6'b000000, 6'b100110}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b100, mips.rd, 7'b0110011}; // XOR
                        {6'b000000, 6'b100111}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b110, mips.rd, 7'b0110011}; // NOR
                        {6'b000000, 6'b101010}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b010, mips.rd, 7'b0110011}; // SLT
                        {6'b000000, 6'b101011}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b011, mips.rd, 7'b0110011}; // SLTU
                        {6'b000000, 6'b000000}: riscv_instruction = {7'b0000000, mips.shamt, mips.rs, 3'b001, mips.rd, 7'b0110011}; // SLL
                        {6'b000000, 6'b000010}: riscv_instruction = {7'b0000000, mips.shamt, mips.rs, 3'b101, mips.rd, 7'b0110011}; // SRL
                        {6'b000000, 6'b000011}: riscv_instruction = {7'b0100000, mips.shamt, mips.rs, 3'b101, mips.rd, 7'b0110011}; // SRA
                        
                        // I-type instructions (small immediates)
                        {6'b001000, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b000, mips.rt, 7'b0010011}; // ADDI
                        {6'b001100, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b111, mips.rt, 7'b0010011}; // ANDI
                        {6'b001101, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b110, mips.rt, 7'b0010011}; // ORI
                        {6'b001110, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b100, mips.rt, 7'b0010011}; // XORI
                        {6'b001010, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b010, mips.rt, 7'b0010011}; // SLTI
                        {6'b001011, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b011, mips.rt, 7'b0010011}; // SLTIU
                        
                        // Branch instructions
                        {6'b000100, 6'b??????}: riscv_instruction = {mips.imm[15], mips.imm[14:1], 1'b0, mips.rt, mips.rs, 3'b000, mips.imm[4:1], mips.imm[11], 7'b1100011}; // BEQ
                        {6'b000101, 6'b??????}: riscv_instruction = {mips.imm[15], mips.imm[14:1], 1'b0, mips.rt, mips.rs, 3'b001, mips.imm[4:1], mips.imm[11], 7'b1100011}; // BNE
                        
                        // Load/Store instructions (small immediates)
                        {6'b100011, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b010, mips.rt, 7'b0000011}; // LW
                        {6'b100000, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b000, mips.rt, 7'b0000011}; // LB
                        {6'b100100, 6'b??????}: riscv_instruction = {mips.imm, mips.rs, 3'b100, mips.rt, 7'b0000011}; // LBU
                        {6'b101011, 6'b??????}: riscv_instruction = {mips.imm[11:5], mips.rt, mips.rs, 3'b010, mips.imm[4:0], 7'b0100011}; // SW
                        {6'b101000, 6'b??????}: riscv_instruction = {mips.imm[11:5], mips.rt, mips.rs, 3'b000, mips.imm[4:0], 7'b0100011}; // SB
                        
                        // Jump instructions
                        {6'b000010, 6'b??????}: riscv_instruction = {mips.target[25], mips.target[24:5], 1'b0, 5'b00000, 7'b1101111}; // J
                        {6'b000011, 6'b??????}: riscv_instruction = {mips.target[25], mips.target[24:5], 1'b0, 5'b00001, 7'b1101111}; // JAL
                        {6'b000000, 6'b001000}: riscv_instruction = {12'b0, mips.rs, 3'b000, 5'b00000, 7'b1100111}; // JR
                        {6'b000000, 6'b001001}: riscv_instruction = {12'b0, mips.rs, 3'b000, 5'b00001, 7'b1100111}; // JALR
                        
                        // Floating-point instructions
                        {6'b010001, 6'b000000}: riscv_instruction = {12'b0, mips.rt, 3'b000, mips.rd, 7'b0001011}; // MFC1
                        {6'b010001, 6'b000100}: riscv_instruction = {12'b0, mips.rt, 3'b000, mips.rd, 7'b0001011}; // MTC1
                        {6'b010001, 6'b010000}: riscv_instruction = {7'b0000000, mips.rt, mips.rs, 3'b000, mips.rd, 7'b1010011}; // FADD.S
                        {6'b010001, 6'b010001}: riscv_instruction = {7'b0000100, mips.rt, mips.rs, 3'b000, mips.rd, 7'b1010011}; // FSUB.S
                        {6'b010001, 6'b010010}: riscv_instruction = {7'b0001000, mips.rt, mips.rs, 3'b000, mips.rd, 7'b1010011}; // FMUL.S
                        {6'b010001, 6'b010011}: riscv_instruction = {7'b0001100, mips.rt, mips.rs, 3'b000, mips.rd, 7'b1010011}; // FDIV.S
                        {6'b010001, 6'b110000}: riscv_instruction = {mips.imm, mips.rs, 3'b010, mips.rt, 7'b0000111}; // LWC1
                        {6'b010001, 6'b111000}: riscv_instruction = {mips.imm[11:5], mips.rt, mips.rs, 3'b010, mips.imm[4:0], 7'b0100111}; // SWC1
                        
                        // System instructions
                        {6'b000000, 6'b001100}: riscv_instruction = {12'b0, 5'b00000, 3'b000, 5'b00000, 7'b1110011}; // SYSCALL
                        {6'b000000, 6'b001101}: riscv_instruction = {12'b1, 5'b00000, 3'b000, 5'b00000, 7'b1110011}; // BREAK
                        
                        default: begin
                            riscv_instruction = '0;
                            translation_valid = 1'b0;
                        end
                    endcase
                    instruction_ready = 1'b1;
                end
            end
            
            SECOND_CYCLE: begin
                instruction_ready = 1'b1;
                casez ({saved_instruction[31:26], saved_instruction[5:0]})
                    // I-type instructions second part
                    {6'b001000, 6'b??????}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b000, temp_reg, 7'b0010011}; // ADDI
                    {6'b001100, 6'b??????}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b111, temp_reg, 7'b0010011}; // ANDI
                    {6'b001101, 6'b??????}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b110, temp_reg, 7'b0010011}; // ORI
                    {6'b001110, 6'b??????}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b100, temp_reg, 7'b0010011}; // XORI
                    
                    // Load/Store second part
                    {6'b100011, 6'b??????}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b010, temp_reg, 7'b0000011}; // LW
                    {6'b101011, 6'b??????}: riscv_instruction = {saved_instruction[15:11], saved_instruction[20:16], saved_instruction[25:21], 3'b010, saved_instruction[10:6], 7'b0100011}; // SW
                    
                    // Floating-point load/store second part
                    {6'b010001, 6'b110000}: riscv_instruction = {saved_instruction[15:0], saved_instruction[25:21], 3'b010, temp_reg, 7'b0000111}; // LWC1
                    {6'b010001, 6'b111000}: riscv_instruction = {saved_instruction[15:11], saved_instruction[20:16], saved_instruction[25:21], 3'b010, saved_instruction[10:6], 7'b0100111}; // SWC1
                    
                    default: riscv_instruction = '0;
                endcase
            end
            
            DONE: begin
                instruction_ready = 1'b0;
            end
        endcase
    end
    
    // Сохранение инструкции для второго цикла
    always_ff @(posedge clk) begin
        if (current_state == IDLE) begin
            saved_instruction <= mips_instruction;
        end
    end
endmodule