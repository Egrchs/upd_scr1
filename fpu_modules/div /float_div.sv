module floating_point_divider (
    input  logic        clk,
    input  logic        rst,

    // Input A interface
    input  logic [31:0] input_a,
    input  logic        input_a_stb,
    output logic        input_a_ack,

    // Input B interface
    input  logic [31:0] input_b,
    input  logic        input_b_stb,
    output logic        input_b_ack,

    // Output Z interface
    output logic [31:0] output_z,
    output logic        output_z_stb,
    input  logic        output_z_ack
);

    typedef enum logic [3:0] {
        GET_A, GET_B, UNPACK, SPECIAL_CASES,
        NORMALISE_A, NORMALISE_B,
        DIVIDE_0, DIVIDE_1, DIVIDE_2, DIVIDE_3,
        NORMALISE_1, NORMALISE_2,
        ROUND, PACK, PUT_Z
    } state_t;

    state_t state;

    // Floating point components
    struct packed {
        logic        sign;
        logic [7:0]  exponent;
        logic [23:0] mantissa;  // Includes implicit bit
    } a, b, z;

    // Division components
    logic        guard, round_bit, sticky;
    logic [50:0] quotient, divisor, dividend, remainder;
    logic [5:0]  count;

    // Internal registered outputs
    logic        reg_output_z_stb;
    logic [31:0] reg_output_z;
    logic        reg_input_a_ack;
    logic        reg_input_b_ack;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= GET_A;
            reg_input_a_ack <= '0;
            reg_input_b_ack <= '0;
            reg_output_z_stb <= '0;
        end else begin
            case (state)
                GET_A: begin
                    reg_input_a_ack <= '1;
                    if (reg_input_a_ack && input_a_stb) begin
                        a.sign     <= input_a[31];
                        a.exponent <= input_a[30:23];
                        a.mantissa <= {1'b0, input_a[22:0]}; // Will be adjusted later
                        reg_input_a_ack <= '0;
                        state <= GET_B;
                    end
                end

                GET_B: begin
                    reg_input_b_ack <= '1;
                    if (reg_input_b_ack && input_b_stb) begin
                        b.sign     <= input_b[31];
                        b.exponent <= input_b[30:23];
                        b.mantissa <= {1'b0, input_b[22:0]}; // Will be adjusted later
                        reg_input_b_ack <= '0;
                        state <= UNPACK;
                    end
                end

                UNPACK: begin
                    // Adjust exponents (remove bias)
                    a.exponent <= a.exponent - 8'd127;
                    b.exponent <= b.exponent - 8'd127;
                    state <= SPECIAL_CASES;
                end

                SPECIAL_CASES: begin
                    // NaN cases
                    if ((a.exponent == 8'hFF && a.mantissa[22:0] != '0) ||
                        (b.exponent == 8'hFF && b.mantissa[22:0] != '0)) begin
                        z.sign     <= '1;
                        z.exponent <= 8'hFF;
                        z.mantissa <= {1'b1, 22'h0}; // NaN
                        state <= PUT_Z;
                    end
                    // Inf / Inf = NaN
                    else if ((a.exponent == 8'hFF) && (b.exponent == 8'hFF)) begin
                        z.sign     <= '1;
                        z.exponent <= 8'hFF;
                        z.mantissa <= {1'b1, 22'h0}; // NaN
                        state <= PUT_Z;
                    end
                    // a is Inf
                    else if (a.exponent == 8'hFF) begin
                        z.sign     <= a.sign ^ b.sign;
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                        state <= PUT_Z;
                        // Inf / 0 = NaN
                        if ((b.exponent == 8'h00) && (b.mantissa[22:0] == '0)) begin
                            z.sign     <= '1;
                            z.exponent <= 8'hFF;
                            z.mantissa <= {1'b1, 22'h0}; // NaN
                            state <= PUT_Z;
                        end
                    end
                    // b is Inf
                    else if (b.exponent == 8'hFF) begin
                        z.sign     <= a.sign ^ b.sign;
                        z.exponent <= 8'h00;
                        z.mantissa <= '0; // Zero
                        state <= PUT_Z;
                    end
                    // a is zero
                    else if ((a.exponent == 8'h00) && (a.mantissa[22:0] == '0)) begin
                        z.sign     <= a.sign ^ b.sign;
                        z.exponent <= 8'h00;
                        z.mantissa <= '0; // Zero
                        state <= PUT_Z;
                        // 0 / 0 = NaN
                        if ((b.exponent == 8'h00) && (b.mantissa[22:0] == '0)) begin
                            z.sign     <= '1;
                            z.exponent <= 8'hFF;
                            z.mantissa <= {1'b1, 22'h0}; // NaN
                            state <= PUT_Z;
                        end
                    end
                    // b is zero
                    else if ((b.exponent == 8'h00) && (b.mantissa[22:0] == '0)) begin
                        z.sign     <= a.sign ^ b.sign;
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                        state <= PUT_Z;
                    end
                    // Normal numbers
                    else begin
                        // Handle denormals
                        if (a.exponent == 8'h00) begin
                            a.exponent <= 8'd1; // -126 in biased form
                        end else begin
                            a.mantissa[23] <= 1'b1; // Add implicit leading 1
                        end

                        if (b.exponent == 8'h00) begin
                            b.exponent <= 8'd1; // -126 in biased form
                        end else begin
                            b.mantissa[23] <= 1'b1; // Add implicit leading 1
                        end

                        state <= NORMALISE_A;
                    end
                end

                NORMALISE_A: begin
                    if (a.mantissa[23]) begin
                        state <= NORMALISE_B;
                    end else begin
                        a.mantissa <= a.mantissa << 1;
                        a.exponent <= a.exponent - 8'd1;
                    end
                end

                NORMALISE_B: begin
                    if (b.mantissa[23]) begin
                        state <= DIVIDE_0;
                    end else begin
                        b.mantissa <= b.mantissa << 1;
                        b.exponent <= b.exponent - 8'd1;
                    end
                end

                DIVIDE_0: begin
                    z.sign     <= a.sign ^ b.sign;
                    z.exponent <= a.exponent - b.exponent + 8'd127; // Re-bias exponent
                    quotient   <= '0;
                    remainder  <= '0;
                    count      <= '0;
                    dividend   <= {a.mantissa, 27'h0};
                    divisor    <= b.mantissa;
                    state <= DIVIDE_1;
                end

                DIVIDE_1: begin
                    quotient  <= quotient << 1;
                    remainder <= remainder << 1;
                    remainder[0] <= dividend[50];
                    dividend  <= dividend << 1;
                    state <= DIVIDE_2;
                end

                DIVIDE_2: begin
                    if (remainder >= divisor) begin
                        quotient[0] <= 1'b1;
                        remainder <= remainder - divisor;
                    end

                    if (count == 6'd49) begin
                        state <= DIVIDE_3;
                    end else begin
                        count <= count + 1;
                        state <= DIVIDE_1;
                    end
                end

                DIVIDE_3: begin
                    z.mantissa <= quotient[26:3];
                    guard      <= quotient[2];
                    round_bit  <= quotient[1];
                    sticky     <= quotient[0] | (remainder != '0);
                    state <= NORMALISE_1;
                end

                NORMALISE_1: begin
                    if (!z.mantissa[23] && (z.exponent > 8'd1)) begin
                        z.exponent <= z.exponent - 8'd1;
                        z.mantissa <= z.mantissa << 1;
                        z.mantissa[0] <= guard;
                        guard <= round_bit;
                        round_bit <= 1'b0;
                    end else begin
                        state <= NORMALISE_2;
                    end
                end

                NORMALISE_2: begin
                    if (z.exponent < 8'd1) begin  // Underflow
                        z.exponent <= z.exponent + 8'd1;
                        z.mantissa <= z.mantissa >> 1;
                        guard <= z.mantissa[0];
                        round_bit <= guard;
                        sticky <= sticky | round_bit;
                    end else begin
                        state <= ROUND;
                    end
                end

                ROUND: begin
                    if (guard && (round_bit | sticky | z.mantissa[0])) begin
                        z.mantissa <= z.mantissa + 24'd1;
                        if (z.mantissa == 24'hFFFFFF) begin
                            z.exponent <= z.exponent + 8'd1;
                        end
                    end
                    state <= PACK;
                end

                PACK: begin
                    // Check for overflow
                    if (z.exponent > 8'hFE) begin
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                    end
                    // Check for underflow
                    else if (z.exponent < 8'd1) begin
                        z.exponent <= '0;
                        z.mantissa <= '0; // Zero
                    end
                    state <= PUT_Z;
                end

                PUT_Z: begin
                    reg_output_z_stb <= '1;
                    reg_output_z <= {z.sign, z.exponent, z.mantissa[22:0]};
                    if (reg_output_z_stb && output_z_ack) begin
                        reg_output_z_stb <= '0;
                        state <= GET_A;
                    end
                end
            endcase
        end
    end

    // Output assignments
    assign input_a_ack  = reg_input_a_ack;
    assign input_b_ack  = reg_input_b_ack;
    assign output_z_stb = reg_output_z_stb;
    assign output_z     = reg_output_z;

endmodule
