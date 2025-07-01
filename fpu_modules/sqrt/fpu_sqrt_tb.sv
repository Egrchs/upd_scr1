`timescale 1ns / 1ps

module fpu_sqrt_tb;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [31:0] data_in;
    logic        busy;
    logic        done;
    logic [31:0] data_out;

    // Создаем экземпляр тестируемого модуля (DUT)
    fpu_sqrt uut (.*);

    // Генератор тактового сигнала
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // Вспомогательная задача для одного теста
    task run_test(input logic[31:0] test_vector, input logic[31:0] expected_vector, input string test_name);
        logic is_expected_nan;
        logic is_output_nan;

        $display("-----------------------------------------------------");
        $display("[%0t ns] Starting test: %s", $time, test_name);
        $display("  Input:  0x%h (%f)", test_vector, $bitstoshortreal(test_vector));
        $display("  Expect: 0x%h (%f)", expected_vector, $bitstoshortreal(expected_vector));

        wait (busy == 1'b0);

        // ИСПРАВЛЕНО: Безопасная последовательность запуска для избежания гонок
        @(posedge clk);
        start   <= 1'b1;
        data_in <= test_vector;

        @(posedge clk);
        start   <= 1'b0;
        data_in <= 32'hxxxxxxxx;

        // Ожидание завершения с таймаутом для надежности
        fork
            begin
                wait (done == 1'b1);
            end
            begin
                #2000; // Таймаут 200 тактов
                $error("!!! TEST FAILED - TIMEOUT !!! For test: %s", test_name);
                $finish;
            end
        join_any
        disable fork;

        @(posedge clk);

        $display("[%0t ns] Done.   Result: 0x%h (%f)", $time, data_out, $bitstoshortreal(data_out));

        // Проверка результата
        is_expected_nan = (expected_vector[30:23] == 8'hFF && expected_vector[22:0] != 0);
        is_output_nan   = (data_out[30:23] == 8'hFF && data_out[22:0] != 0);

        if (is_expected_nan && is_output_nan) begin
             $display(">>> TEST PASSED (NaN match) <<<");
        end else if (data_out === expected_vector) begin
            $display(">>> TEST PASSED <<<");
        end else begin
            $error("!!! TEST FAILED !!!");
        end
    endtask

    // Основной блок стимулов
    initial begin
        rst_n <= 1'b0; start <= 1'b0; data_in <= 32'bx;
        #20; rst_n <= 1'b1;
        @(posedge clk);

        // --- Набор тестов ---
        run_test(32'h40800000, 32'h40000000, "sqrt(4.0) -> 2.0");
        run_test(32'h41100000, 32'h40400000, "sqrt(9.0) -> 3.0");
        run_test(32'h42C80000, 32'h41200000, "sqrt(100.0) -> 10.0");
        run_test(32'h3E800000, 32'h3F000000, "sqrt(0.25) -> 0.5");
        //run_test(32'h3F800000, 32'h3F800000, "sqrt(1.0) -> 1.0");
      //  run_test(32'h40000000, 32'h3FB504F3, "sqrt(2.0) -> ~1.414");
        //run_test(32'h00000000, 32'h00000000, "sqrt(+0.0) -> +0.0");
        //run_test(32'h80000000, 32'h00000000, "sqrt(-0.0) -> +0.0");
        //run_test(32'h7F800000, 32'h7F800000, "sqrt(+Infinity) -> +Infinity");
        //run_test(32'hBF800000, 32'h7FC00000, "sqrt(-1.0) -> qNaN");
        //run_test(32'hFF800000, 32'h7FC00000, "sqrt(-Infinity) -> qNaN");
        //run_test(32'h7FC00001, 32'h7FC00000, "sqrt(qNaN input) -> qNaN");
        //run_test(32'h7FA00000, 32'h7FC00000, "sqrt(sNaN input) -> qNaN");

        $display("-----------------------------------------------------");
        $display("All tests completed.");
        $finish;
    end

endmodule
