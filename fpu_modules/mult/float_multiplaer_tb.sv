`timescale 1ns / 1ps

module float_multiplier_tb;

    // Параметры теста
    parameter NUM_RANDOM_TESTS = 100;  // Количество случайных тестов
    parameter SEED = 12345;           // Seed для генерации случайных чисел

    // Сигналы для подключения к модулю
    logic [31:0] a, b;
    logic [31:0] result;
    logic        invalid;

    // Экземпляр тестируемого модуля
    float_multiplier uut (
        .a(a),
        .b(b),
        .result(result),
        .invalid(invalid)
    );

    // Генерация случайных float-чисел
    function logic [31:0] gen_random_float();
        logic [31:0] rand_val;
        rand_val = $urandom(SEED);
        return rand_val;
    endfunction

    // Вывод float в виде числа (для отладки)
    function string float_to_string(input logic [31:0] f);
        real r;
        r = $bitstoreal(f);
        return $sformatf("%f", r);
    endfunction

    // Основной блок тестирования
    initial begin
        $display("=== Starting float_multiplier testbench ===");

        // Тест 1: Умножение на 0
        a = 32'h40000000;  // 2.0
        b = 32'h00000000;  // 0.0
        #10;
        $display("Test 1: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 2: Умножение Inf на число
        a = 32'h7F800000;  // +Inf
        b = 32'h40800000;  // 4.0
        #10;
        $display("Test 2: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 3: NaN * число
        a = 32'h7FC00000;  // NaN
        b = 32'h3F800000;  // 1.0
        #10;
        $display("Test 3: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 4: Обычные числа (2.5 * 4.0 = 10.0)
        a = 32'h40200000;  // 2.5
        b = 32'h40800000;  // 4.0
        #10;
        $display("Test 4: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 5: Отрицательное число (-3.0 * 2.0 = -6.0)
        a = 32'hC0400000;  // -3.0
        b = 32'h40000000;  // 2.0
        #10;
        $display("Test 5: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 6: Денормализованные числа (очень маленькие)
        a = 32'h00000001;  // ~1.4e-45 (денормализованное)
        b = 32'h3F800000;  // 1.0
        #10;
        $display("Test 6: %s * %s = %s (invalid: %b)",
            float_to_string(a), float_to_string(b), float_to_string(result), invalid);

        // Тест 7: Случайные числа
        $display("=== Random tests ===");
        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            a = gen_random_float();
            b = gen_random_float();
            #10;
            $display("Test %0d: %s * %s = %s (invalid: %b)",
                i+7, float_to_string(a), float_to_string(b), float_to_string(result), invalid);
        end

        $display("=== Testbench finished ===");
        $finish;
    end

endmodule
