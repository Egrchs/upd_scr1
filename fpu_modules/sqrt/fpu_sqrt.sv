`timescale 1ns / 1ps

/**
 * @file fpu_sqrt.sv
 * @brief Модуль для вычисления квадратного корня из числа FP32 (IEEE 754).
 * @details
 *  - Формат: одинарная точность (FP32).
 *  - Алгоритм: Многотактовый бесстадийный алгоритм извлечения корня (Non-restoring).
 *  - Интерфейс: start/done, подходит для интеграции в FPU.
 *  - Задержка (Latency): ~28-30 тактов для обычных чисел, ~3-5 тактов для спец. значений.
 *  - Обрабатывает специальные значения: 0, +/-Inf, NaN.
 *  - Корень из отрицательного числа возвращает qNaN (тихий NaN).
 *  - ВНИМАНИЕ: Результат вычисляется с помощью усечения (truncation), а не округления.
 *             Это является допустимым упрощением для встраиваемых FPU.
 */
module fpu_sqrt (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [31:0]  data_in,
    output logic         busy,
    output logic         done,
    output logic [31:0]  data_out
);

    typedef enum logic [2:0] {
        IDLE,
        PREPARE,
        CALCULATE,
        FINISH,
        DONE_STATE
    } state_e;

    state_e state_reg, state_next;

    parameter ITERATIONS = 25; // 1 целый бит + 24 дробных для достаточной точности

    // Регистры состояния и данных
    logic [31:0] data_in_reg;
    logic [4:0]  iter_count_reg, iter_count_next;

    // Регистры для итеративного алгоритма
    logic [(ITERATIONS*2)-1:0] radicand_reg, radicand_next; // Подкоренное выражение
    logic [ITERATIONS:0]     remainder_reg, remainder_next; // Остаток
    logic [ITERATIONS-1:0]   result_q_reg,  result_q_next;  // Результат (корень)

    // Регистры управления и результата
    logic [31:0] result_reg, result_next;
    logic        busy_reg, busy_next;

    always_comb begin
        // ИСПРАВЛЕНО: Все локальные переменные объявлены в самом начале блока
        // для соответствия стандарту и совместимости с Xcelium.
        logic sign_in_r;
        logic [7:0] exp_in_r;
        logic [22:0] mant_in_r;
        logic is_zero_r, is_inf_r, is_nan_r, is_neg_r;

        // Значения по умолчанию для избежания 'latches'
        state_next      = state_reg;
        iter_count_next = iter_count_reg;
        radicand_next   = radicand_reg;
        remainder_next  = remainder_reg;
        result_q_next   = result_q_reg;
        result_next     = result_reg;
        busy_next       = busy_reg;
        done            = 1'b0;

        // Присваиваем значения локальным переменным из захваченных регистров
        sign_in_r = data_in_reg[31];
        exp_in_r  = data_in_reg[30:23];
        mant_in_r = data_in_reg[22:0];

        is_zero_r = (exp_in_r == 8'h00) && (mant_in_r == 23'h000000);
        is_inf_r  = (exp_in_r == 8'hFF) && (mant_in_r == 23'h000000);
        is_nan_r  = (exp_in_r == 8'hFF) && (mant_in_r != 23'h000000);
        is_neg_r  = (sign_in_r == 1'b1) && !is_zero_r;

        // Конечный автомат
        case (state_reg)
            IDLE: begin
                if (start) begin
                    busy_next  = 1'b1;
                    state_next = PREPARE;
                end else begin
                    busy_next  = 1'b0;
                end
            end

            PREPARE: begin
                // Объявления локальных переменных в начале блока
                logic [8:0] E_unbiased;
                logic [7:0] E_new_biased;
                logic       exp_is_odd;
                logic [24:0] mant_with_implicit_one;

                if (is_neg_r || is_nan_r) begin
                    result_next = 32'h7FC00000; state_next = FINISH;
                end else if (is_zero_r) begin
                    result_next = 32'h0; state_next = FINISH;
                end else if (is_inf_r) begin
                    result_next = 32'h7F800000; state_next = FINISH;
                end else begin // Нормализованное число
                    E_unbiased = {1'b0, exp_in_r} - 9'd127;
                    exp_is_odd = E_unbiased[0];
                    E_new_biased = ((E_unbiased - {7'b0, exp_is_odd}) >> 1) + 8'd127;
                    result_next = {1'b0, E_new_biased, 23'b0};

                    mant_with_implicit_one = {1'b1, mant_in_r, 1'b0};
                    radicand_next = { (exp_is_odd ? mant_with_implicit_one : {1'b0, mant_with_implicit_one[24:1]}), {(ITERATIONS*2)-25{1'b0}} };

                    iter_count_next = 0; remainder_next = 0; result_q_next = 0;
                    state_next = CALCULATE;
                end
            end

            CALCULATE: begin
                logic [ITERATIONS:0] trial_remainder;
                logic trial_q_bit;

                trial_remainder = {remainder_reg[ITERATIONS-2:0], radicand_reg[(ITERATIONS*2)-1:(ITERATIONS*2)-2]};
                radicand_next = radicand_reg << 2;

                if (remainder_reg[ITERATIONS]) begin // Остаток отрицательный
                    trial_remainder = trial_remainder + {result_q_reg, 2'b11};
                end else begin // Остаток положительный
                    trial_remainder = trial_remainder - {result_q_reg, 2'b01};
                end

                trial_q_bit = ~trial_remainder[ITERATIONS];
                remainder_next = trial_remainder;
                result_q_next  = {result_q_reg[ITERATIONS-2:0], trial_q_bit};

                if (iter_count_reg == ITERATIONS-1) begin
                    state_next = FINISH;
                end else begin
                    iter_count_next = iter_count_reg + 1;
                end
            end

            FINISH: begin
                // Формируем финальный результат только если это был путь вычислений.
                // Для спец. случаев результат уже записан в result_reg.
                if (!is_zero_r && !is_inf_r && !is_nan_r && !is_neg_r) begin
                    logic [22:0] final_mantissa;
                    // ИСПРАВЛЕНО: Используем 'result_q_reg' (зарегистрированное значение),
                    // а не 'result_q_next' (значение для следующего такта).
                    final_mantissa = result_q_reg[ITERATIONS-2:ITERATIONS-24];
                    result_next = {result_reg[31:23], final_mantissa};
                end
                state_next = DONE_STATE;
            end

            DONE_STATE: begin
                busy_next = 1'b0;
                done      = 1'b1;
                state_next = IDLE;
            end
        endcase
    end

    // Последовательная логика (регистровый блок)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE; busy_reg <= 1'b0; iter_count_reg <= 0;
            radicand_reg <= 0; remainder_reg <= 0; result_q_reg <= 0;
            result_reg <= 0; data_in_reg <= 0;
        end else begin
            state_reg <= state_next; busy_reg <= busy_next; result_reg <= result_next;

            if (start) begin data_in_reg <= data_in; end

            if (state_reg == PREPARE || state_reg == CALCULATE) begin
                iter_count_reg <= iter_count_next; radicand_reg <= radicand_next;
                remainder_reg <= remainder_next; result_q_reg <= result_q_next;
            end
        end
    end

    assign data_out = result_reg;
    assign busy     = busy_reg;

endmodule
