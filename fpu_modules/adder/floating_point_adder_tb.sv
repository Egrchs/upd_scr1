`timescale 1ns/1ps

module simple_fp_adder_test();

    // Тактовый сигнал и сброс
    reg clk = 0;
    reg rst = 1;

    // Интерфейс модуля
    reg [31:0] input_a;
    reg        input_a_stb = 0;
    wire       input_a_ack;

    reg [31:0] input_b;
    reg        input_b_stb = 0;
    wire       input_b_ack;

    wire [31:0] output_z;
    wire        output_z_stb;
    reg         output_z_ack = 0;

    // Экземпляр тестируемого модуля
    floating_point_adder dut (
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

    // Генерация тактового сигнала (50 MHz)
    always #10 clk = ~clk;

    // Основной тест
    initial begin
        // Инициализация VCD-файла для просмотра в GTKWave
        $dumpfile("fp_adder_simple.vcd");
        $dumpvars(0, simple_fp_adder_test);

        // Сброс
        #20 rst = 0;

        // Тест 1: 1.0 + 2.0 = 3.0
        $display("\nТест 1: 1.0 + 2.0");
        input_a = 32'h3F800000; // 1.0
        input_b = 32'h40600000; // 2.0
        input_a_stb = 1;
        input_b_stb = 1;


        #500;
        $display("\nТестирование завершено");
        $finish;
    end

endmodule
