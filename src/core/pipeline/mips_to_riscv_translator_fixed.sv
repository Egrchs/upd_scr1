// =====================================================================
//  ЭКСПЕРТНАЯ ВЕРСИЯ: Транслятор с Peephole-оптимизацией LUI+ORI
// =====================================================================
// - Распознает и оптимизирует последовательность MIPS LUI+ORI в RISC-V LUI+ADDI.
// - Конечный автомат расширен для условной генерации инструкций.
// =====================================================================
module mips_to_riscv_translator_fixed (
    input  logic        clk,
    input  logic        pipe_rst_n,
    input  logic [31:0] mips_instruction,
    input  logic        mips_instr_valid,
    input  logic        mips_instr_error,
    output logic        translator_ready,
    output logic [31:0] riscv_instruction,
    output logic        riscv_instr_valid,
    output logic        riscv_instr_error,
    input  logic        riscv_instr_accepted
);

  // ----- Типы и константы -----
  typedef struct packed {
    logic [5:0]  opcode;
    logic [4:0]  rs;
    logic [4:0]  rt;
    logic [15:0] imm;
  } mips_i_type_t;
  typedef struct packed {
    logic [5:0] opcode;
    logic [4:0] rs;
    logic [4:0] rt;
    logic [4:0] rd;
    logic [4:0] shamt;
    logic [5:0] funct;
  } mips_r_type_t;

  localparam MIPS_OP_R_TYPE = 6'b000000;
  localparam MIPS_OP_ADDIU = 6'b001001;
  localparam MIPS_OP_BEQ = 6'b000100;
  localparam MIPS_OP_BNE = 6'b000101;
  localparam MIPS_OP_LUI = 6'b001111;
  localparam MIPS_OP_ORI = 6'b001101;
  localparam MIPS_OP_SW = 6'b101011;
  localparam MIPS_FNC_JR = 6'b001000;

  typedef enum logic [3:0] {
    IDLE,
    OUTPUT_SINGLE,
    WAIT_DELAY_SLOT,
    OUTPUT_SLOT,
    OUTPUT_BRANCH,
    AWAIT_ORI,
    OUTPUT_STASHED_LUI,
    OUTPUT_OPT_LUI,
    OUTPUT_OPT_ADDI
  } state_t;

  state_t state_reg, state_next;
  logic [31:0] mips_instr_reg, stashed_instr_reg;
  logic [31:0] opt_lui_instr_reg, opt_addi_instr_reg;

  // ----- Логика состояний и регистров -----
  always_ff @(posedge clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) state_reg <= IDLE;
    else state_reg <= state_next;
  end

  always_ff @(posedge clk) begin
    if (state_reg == IDLE && mips_instr_valid) begin
      stashed_instr_reg <= mips_instruction;
    end
    if ((state_reg == WAIT_DELAY_SLOT || state_reg == AWAIT_ORI || state_reg == OUTPUT_STASHED_LUI) && mips_instr_valid) begin
      mips_instr_reg <= mips_instruction;
    end
  end

  // ----- Главный конечный автомат -----
  always_comb begin
    state_next = state_reg;
    translator_ready = 1'b0;
    riscv_instr_valid = 1'b0;
    riscv_instr_error = 1'b0;
    riscv_instruction = 32'h00000013;  // NOP

    unique case (state_reg)
      IDLE: begin
        translator_ready = 1'b1;
        if (mips_instr_valid) begin
          automatic mips_r_type_t temp_r = mips_r_type_t'(mips_instruction);
          if (mips_instruction[31:26] == MIPS_OP_BEQ || mips_instruction[31:26] == MIPS_OP_BNE || (mips_instruction[31:26] == MIPS_OP_R_TYPE && temp_r.funct == MIPS_FNC_JR))
            state_next = WAIT_DELAY_SLOT;
          else if (mips_instruction[31:26] == MIPS_OP_LUI) state_next = AWAIT_ORI;
          else state_next = OUTPUT_SINGLE;
        end
      end
      AWAIT_ORI: begin
        translator_ready = 1'b1;
        if (mips_instr_valid) begin
          automatic mips_i_type_t stashed_lui = mips_i_type_t'(stashed_instr_reg);
          automatic mips_i_type_t current_ori = mips_i_type_t'(mips_instruction);
          if (current_ori.opcode == MIPS_OP_ORI && current_ori.rs == stashed_lui.rt && current_ori.rt == stashed_lui.rt)
            state_next = OUTPUT_OPT_LUI;
          else state_next = OUTPUT_STASHED_LUI;
        end
      end
      OUTPUT_STASHED_LUI: begin
        riscv_instruction = translate_instruction(stashed_instr_reg, riscv_instr_error);
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = OUTPUT_SINGLE;
      end
      OUTPUT_OPT_LUI: begin
        {opt_lui_instr_reg, opt_addi_instr_reg} =
            translate_lui_ori_pair(stashed_instr_reg, mips_instr_reg);
        riscv_instruction = opt_lui_instr_reg;
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = OUTPUT_OPT_ADDI;
      end
      OUTPUT_OPT_ADDI: begin
        riscv_instruction = opt_addi_instr_reg;
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = IDLE;
      end
      WAIT_DELAY_SLOT: begin
        translator_ready = 1'b1;
        if (mips_instr_valid) state_next = OUTPUT_SLOT;
      end
      OUTPUT_SLOT: begin
        riscv_instruction = translate_instruction(mips_instr_reg, riscv_instr_error);
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = OUTPUT_BRANCH;
      end
      OUTPUT_BRANCH: begin
        riscv_instruction = translate_instruction(stashed_instr_reg, riscv_instr_error);
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = IDLE;
      end
      OUTPUT_SINGLE: begin
        riscv_instruction = translate_instruction(stashed_instr_reg, riscv_instr_error);
        riscv_instr_valid = 1'b1;
        if (riscv_instr_accepted) state_next = IDLE;
      end
    endcase

    if (mips_instr_error) begin
      riscv_instr_error = 1'b1;
      riscv_instruction = 32'b0;
    end
  end

  // =================================================================
  //  ПРОДВИНУТЫЙ ОТЛАДОЧНЫЙ ВЫВОД
  // =================================================================
  // Этот блок корректно работает со сложным конечным автоматом
  // и правильно определяет исходную MIPS инструкцию для каждого
  // сгенерированного RISC-V кода.
  // =================================================================
  always_ff @(posedge clk) begin
    // --- 1. Логгирование ПРИНЯТОЙ MIPS инструкции ---
    if (mips_instr_valid && translator_ready) begin
      $display("-------------------------------------------------");
      $display("@%0t [OPT_TRANSLATOR] MIPS Input: %h (state: %s)", $time, mips_instruction,
               state_reg.name());
    end

    // --- 2. Логгирование СГЕНЕРИРОВАННОЙ RISC-V инструкции ---
    if (riscv_instr_valid && riscv_instr_accepted) begin
      logic [31:0] source_mips_instr;

      // Определяем, какая MIPS инструкция была источником, исходя из текущего состояния
      unique case (state_reg)
        // Для этих состояний источником является "отложенная" инструкция
        OUTPUT_SINGLE, OUTPUT_STASHED_LUI, OUTPUT_BRANCH: source_mips_instr = stashed_instr_reg;

        // Для этих состояний источником является "текущая" инструкция
        OUTPUT_SLOT: source_mips_instr = mips_instr_reg;

        // Для оптимизированной пары источником является сохраненная LUI
        OUTPUT_OPT_LUI, OUTPUT_OPT_ADDI: source_mips_instr = stashed_instr_reg;

        default: source_mips_instr = 32'hdeadbeef;  // Не должно произойти
      endcase

      // Формируем и выводим сообщение
      if (!riscv_instr_error) begin
        $display("@%0t [OPT_TRANSLATOR] -> Generated RISC-V: %h (from MIPS: %h, state: %s)", $time,
                 riscv_instruction, source_mips_instr, state_reg.name());
      end else begin
        $display("@%0t [OPT_TRANSLATOR] -> Generated ERROR (from MIPS: %h, state: %s)", $time,
                 source_mips_instr, state_reg.name());
      end
    end
  end

  // ----- Функции-трансляторы -----

  function automatic logic [63:0] translate_lui_ori_pair(input logic [31:0] mips_lui,
                                                         input logic [31:0] mips_ori);
    automatic mips_i_type_t lui_i = mips_i_type_t'(mips_lui);
    automatic mips_i_type_t ori_i = mips_i_type_t'(mips_ori);
    logic [31:0] full_const = {lui_i.imm, ori_i.imm};
    logic [19:0] imm_lui = full_const[31:12] + (full_const[11] ? 1 : 0);
    logic signed [11:0] imm_addi = full_const[11:0];
    logic [31:0] riscv_lui = {imm_lui, lui_i.rt, 7'b0110111};
    logic [31:0] riscv_addi = {imm_addi, lui_i.rt, 3'b000, lui_i.rt, 7'b0010011};
    return {riscv_lui, riscv_addi};
  endfunction

  function automatic logic [31:0] translate_instruction(input logic [31:0] mips_instr,
                                                        output logic error_flag);
    automatic mips_i_type_t instr_i = mips_i_type_t'(mips_instr);
    automatic mips_r_type_t instr_r = mips_r_type_t'(mips_instr);
    error_flag = 1'b1;
    translate_instruction = 32'b0;
    unique case (instr_i.opcode)
      MIPS_OP_R_TYPE:
      unique case (instr_r.funct)
        6'b100001: begin
          translate_instruction = {7'b0, instr_r.rt, instr_r.rs, 3'b000, instr_r.rd, 7'b0110011};
          error_flag = 1'b0;
        end  // ADDU
        6'b101011: begin
          translate_instruction = {7'b0, instr_r.rt, instr_r.rs, 3'b011, instr_r.rd, 7'b0110011};
          error_flag = 1'b0;
        end  // SLTU
        6'b100101: begin
          translate_instruction = {7'b0, instr_r.rt, instr_r.rs, 3'b110, instr_r.rd, 7'b0110011};
          error_flag = 1'b0;
        end  // OR
        6'b000000: begin
          automatic logic [11:0] imm_val = {7'b0, instr_r.shamt};
          translate_instruction = {imm_val, instr_r.rt, 3'b001, instr_r.rd, 7'b0010011};
          error_flag = 1'b0;
        end  // SLL/NOP
        MIPS_FNC_JR: begin
          translate_instruction = {12'b0, instr_r.rs, 3'b000, 5'b0, 7'b1100111};
          error_flag = 1'b0;
        end  // JR
        default: error_flag = 1'b1;
      endcase
      MIPS_OP_ADDIU: begin
        translate_instruction = {instr_i.imm[11:0], instr_i.rs, 3'b000, instr_i.rt, 7'b0010011};
        error_flag = 1'b0;
      end
      MIPS_OP_LUI: begin
        translate_instruction = {{instr_i.imm, 16'h0}, instr_i.rt, 7'b0110111};
        error_flag = 1'b0;
      end
      MIPS_OP_ORI: begin
        if (instr_i.imm[15:12] != 0) error_flag = 1'b1;
        else begin
          translate_instruction = {instr_i.imm[11:0], instr_i.rs, 3'b110, instr_i.rt, 7'b0010011};
          error_flag = 1'b0;
        end
      end
      MIPS_OP_SW: begin
        translate_instruction = {
          instr_i.imm[11:5], instr_i.rt, instr_i.rs, 3'b010, instr_i.imm[4:0], 7'b0100011
        };
        error_flag = 1'b0;
      end
      MIPS_OP_BEQ: begin
        logic signed [17:0] m_off = {instr_i.imm, 2'b0};
        logic signed [12:0] r_off = m_off - 4;
        translate_instruction = {
          r_off[12], r_off[10:5], instr_i.rt, instr_i.rs, 3'b000, r_off[4:1], r_off[11], 7'b1100011
        };
        error_flag = 1'b0;
      end
      MIPS_OP_BNE: begin
        logic signed [17:0] m_off = {instr_i.imm, 2'b0};
        logic signed [12:0] r_off = m_off - 4;
        translate_instruction = {
          r_off[12], r_off[10:5], instr_i.rt, instr_i.rs, 3'b001, r_off[4:1], r_off[11], 7'b1100011
        };
        error_flag = 1'b0;
      end
      default: error_flag = 1'b1;
    endcase
  endfunction
endmodule
