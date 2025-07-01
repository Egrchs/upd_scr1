`timescale 1ns/1ps

module tb_floating_point_divider();

    // Тактовый сигнал и сброс
    logic clk = 0;
    logic rst = 1;

    // Интерфейс модуля
    logic [31:0] input_a;
    logic        input_a_stb = 0;
    logic        input_a_ack;

    logic [31:0] input_b;
    logic        input_b_stb = 0;
    logic        input_b_ack;

    logic [31:0] output_z;
    logic        output_z_stb;
    logic        output_z_ack = 0;

    // Переменные для тестирования
    int test_num = 0;
    int error_count = 0;
    int total_tests = 0;

    // Экземпляр тестируемого модуля
    floating_point_divider dut (
        .clk(clk),
        .rst(rst),
        .input_a(input_a),
        .input_a_stb(input_a_stb),
        .input_a_ack(input_a_ack),
        .input_b(input_b),
        .input_b_stb(input_b_stb),
        .input_b_ack(input_b_ack),
        .output_z(output_z),
        .output_z_stb(output_z_stb),
        .output_z_ack(output_z_ack)
    );

    // Генерация тактового сигнала
    always #5 clk = ~clk;

    // Функция для сравнения результатов с учетом NaN
    function automatic logic compare_results(
        input logic [31:0] expected,
        input logic [31:0] actual,
        input string test_name
    );
        // Особый случай для NaN (может быть любое представление)
        if ((expected[30:23] == 8'hFF) && (expected[22:0] != 0)) begin
            if ((actual[30:23] == 8'hFF) && (actual[22:0] != 0)) begin
                $display("[%0t] Test '%s': PASS (NaN comparison)", $time, test_name);
                return 1;
            end else begin
                $display("[%0t] Test '%s': FAIL (expected NaN, got 0x%08h)",
                         $time, test_name, actual);
                return 0;
            end
        end
        // Обычное сравнение
        else if (actual === expected) begin
            $display("[%0t] Test '%s': PASS", $time, test_name);
            return 1;
        end
        else begin
            $display("[%0t] Test '%s': FAIL (expected 0x%08h, got 0x%08h)",
                     $time, test_name, expected, actual);
            return 0;
        end
    endfunction

    // Функция для выполнения теста
    task automatic run_test(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] expected,
        input string test_name
    );
        $display("\n[%0t] Starting test %0d: %s", $time, test_num++, test_name);
        $display("  a = %f (0x%08h)", $bitstoreal(a), a);
        $display("  b = %f (0x%08h)", $bitstoreal(b), b);

        // Подаем входные данные
        input_a = a;
        input_b = b;
        input_a_stb = 1;
        input_b_stb = 1;

        // Ждем подтверждения
        wait(input_a_ack && input_b_ack);
        @(posedge clk);
        input_a_stb = 0;
        input_b_stb = 0;

        // Ждем результата
        wait(output_z_stb);
        output_z_ack = 1;

        // Проверяем результат
        if (!compare_results(expected, output_z, test_name)) begin
            error_count++;
        end
        total_tests++;

        @(posedge clk);
        output_z_ack = 0;
    endtask

    // Основная последовательность тестирования
    initial begin
        // Инициализация
        $display("[%0t] Starting simulation", $time);
        #10 rst = 0;

        // Тест 1: Простое деление
        run_test(32'h40800000, 32'h41080000, 32'h40000000, "4.0 / 2.0 = 2.0");

        // Тест 2: Деление на 1.0
        run_test(32'h40A00000, 32'h3F800000, 32'h40A00000, "5.0 / 1.0 = 5.0");

        // Тест 3: Деление с результатом < 1.0
        run_test(32'h3F800000, 32'h40000000, 32'h3F000000, "1.0 / 2.0 = 0.5");

        // Тест 4: Деление на ноль
        run_test(32'h40800000, 32'h00000000, 32'h7F800000, "4.0 / 0.0 = Inf");

        // Тест 5: Ноль делить на число
        run_test(32'h00000000, 32'h40800000, 32'h00000000, "0.0 / 4.0 = 0.0");

        // Тест 6: Ноль делить на ноль
        run_test(32'h00000000, 32'h00000000, 32'hFFC00000, "0.0 / 0.0 = NaN");

        // Тест 7: Бесконечность делить на число
        run_test(32'h7F800000, 32'h40800000, 32'h7F800000, "Inf / 4.0 = Inf");

        // Тест 8: Число делить на бесконечность
        run_test(32'h40800000, 32'h7F800000, 32'h00000000, "4.0 / Inf = 0.0");

        // Тест 9: Бесконечность делить на бесконечность
        run_test(32'h7F800000, 32'h7F800000, 32'hFFC00000, "Inf / Inf = NaN");

        // Тест 10: Денормализованные числа
        run_test(32'h00000001, 32'h3F800000, 32'h00000000, "Denorm / 1.0 = 0.0");

        // Завершение тестирования
        #100;
        $display("\n[%0t] Simulation complete", $time);
        $display("  Tests run:    %0d", total_tests);
        $display("  Errors:       %0d", error_count);
        $display("  Success rate: %0.1f%%", (100.0 * (total_tests - error_count)) / total_tests);

        if (error_count == 0) begin
            $display("All tests PASSED");
        end else begin
            $display("Some tests FAILED");
        end

        $finish;
    end

    // Логирование всех выходных данных
    initial begin
        forever begin
            @(posedge clk);
            if (output_z_stb) begin
                $display("[%0t] Output: %f (0x%08h)", $time, $bitstoreal(output_z), output_z);
            end
        end
    end

endmodule
