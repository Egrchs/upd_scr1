module float_multiplier (
    input  logic [31:0] a,      // Первое число (IEEE 754 float)
    input  logic [31:0] b,      // Второе число (IEEE 754 float)
    output logic [31:0] result, // Результат умножения
    output logic        invalid  // Флаг недопустимой операции (NaN, Inf)
);

    // Разбиение чисел на знак, экспоненту и мантиссу
    logic        sign_a, sign_b;
    logic [7:0]  exponent_a, exponent_b;
    logic [23:0] mantissa_a, mantissa_b;  // Включая неявную ведущую 1

    logic        sign_res;
    logic [7:0]  exponent_res;
    logic [47:0] mantissa_product;  // Произведение мантисс (24x24 бит)
    logic [22:0] mantissa_res;      // Нормализованная мантисса (без ведущей 1)

    // Проверка на особые случаи (NaN, Inf, денормализованные числа)
    logic a_is_nan, b_is_nan, a_is_inf, b_is_inf, a_is_zero, b_is_zero;

    assign a_is_nan   = &exponent_a && (|mantissa_a[22:0]);
    assign b_is_nan   = &exponent_b && (|mantissa_b[22:0]);
    assign a_is_inf   = &exponent_a && !(|mantissa_a[22:0]);
    assign b_is_inf   = &exponent_b && !(|mantissa_b[22:0]);
    assign a_is_zero  = ~(|exponent_a) && ~(|mantissa_a[22:0]);
    assign b_is_zero  = ~(|exponent_b) && ~(|mantissa_b[22:0]);

    // Извлечение знака, экспоненты и мантиссы
    assign sign_a     = a[31];
    assign sign_b     = b[31];
    assign exponent_a = a[30:23];
    assign exponent_b = b[30:23];
    assign mantissa_a = (|exponent_a) ? {1'b1, a[22:0]} : {1'b0, a[22:0]}; // Денормализованные числа
    assign mantissa_b = (|exponent_b) ? {1'b1, b[22:0]} : {1'b0, b[22:0]};

    // Вычисление знака результата
    assign sign_res = sign_a ^ sign_b;

    // Обработка особых случаев
    always_comb begin
        if (a_is_nan || b_is_nan) begin
            result = 32'h7FC0_0000;  // Возвращаем qNaN
            invalid = 1'b1;
        end
        else if ((a_is_zero && b_is_inf) || (a_is_inf && b_is_zero)) begin
            result = 32'h7FC0_0000;  // 0 * Inf = NaN
            invalid = 1'b1;
        end
        else if (a_is_inf || b_is_inf) begin
            result = {sign_res, 8'hFF, 23'h0};  // Inf * число = Inf
            invalid = 1'b0;
        end
        else if (a_is_zero || b_is_zero) begin
            result = {sign_res, 31'h0};  // 0 * число = 0
            invalid = 1'b0;
        end
        else begin
            // Нормальный случай: умножение мантисс и сложение экспонент
            mantissa_product = mantissa_a * mantissa_b;

            // Нормализация мантиссы (сдвигаем, если старший бит = 1)
            if (mantissa_product[47]) begin
                mantissa_res = mantissa_product[46:24];  // Сдвиг вправо на 1
                exponent_res = exponent_a + exponent_b - 127 + 1;  // Коррекция экспоненты
            end
            else begin
                mantissa_res = mantissa_product[45:23];  // Без сдвига
                exponent_res = exponent_a + exponent_b - 127;
            end

            // Проверка на переполнение/антипереполнение экспоненты
            if (exponent_res >= 8'hFF) begin  // Переполнение -> Inf
                result = {sign_res, 8'hFF, 23'h0};
                invalid = 1'b1;
            end
            else if (exponent_res <= 8'h00) begin  // Антипереполнение -> 0 (денормализованное)
                result = {sign_res, 31'h0};
                invalid = 1'b1;
            end
            else begin  // Нормальный результат
                result = {sign_res, exponent_res, mantissa_res};
                invalid = 1'b0;
            end
        end
    end

endmodule
