module floating_point_adder (
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
        ALIGN, ADD_0, ADD_1,
        NORMALISE_1, NORMALISE_2,
        ROUND, PACK, PUT_Z
    } state_t;

    state_t state;

    // Floating point components
    struct packed {
        logic        sign;
        logic [7:0]  exponent;
        logic [26:0] mantissa;  // Includes guard bits
    } a, b, z;

    // Addition components
    logic        guard, round_bit, sticky;
    logic [27:0] sum;  // 28-bit sum for proper carry handling

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
                        a.mantissa <= {1'b0, input_a[22:0], 3'b0}; // Add guard bits
                        reg_input_a_ack <= '0;
                        state <= GET_B;
                    end
                end

                GET_B: begin
                    reg_input_b_ack <= '1;
                    if (reg_input_b_ack && input_b_stb) begin
                        b.sign     <= input_b[31];
                        b.exponent <= input_b[30:23];
                        b.mantissa <= {1'b0, input_b[22:0], 3'b0}; // Add guard bits
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
                    if ((a.exponent == 8'hFF && a.mantissa[25:0] != '0) ||
                        (b.exponent == 8'hFF && b.mantissa[25:0] != '0)) begin
                        z.sign     <= '1;
                        z.exponent <= 8'hFF;
                        z.mantissa <= {1'b1, 26'h0}; // NaN
                        state <= PUT_Z;
                    end
                    // a is Inf
                    else if (a.exponent == 8'hFF) begin
                        z.sign     <= a.sign;
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                        // Inf - Inf = NaN
                        if ((b.exponent == 8'hFF) && (a.sign != b.sign)) begin
                            z.sign     <= '1;
                            z.exponent <= 8'hFF;
                            z.mantissa <= {1'b1, 26'h0}; // NaN
                        end
                        state <= PUT_Z;
                    end
                    // b is Inf
                    else if (b.exponent == 8'hFF) begin
                        z.sign     <= b.sign;
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                        state <= PUT_Z;
                    end
                    // Both zeros
                    else if ((a.exponent == 8'h00) && (a.mantissa == '0) &&
                             (b.exponent == 8'h00) && (b.mantissa == '0)) begin
                        z.sign     <= a.sign & b.sign; // Standard mandates +0 when adding +0 and -0
                        z.exponent <= 8'h00;
                        z.mantissa <= '0;
                        state <= PUT_Z;
                    end
                    // a is zero
                    else if ((a.exponent == 8'h00) && (a.mantissa == '0)) begin
                        z.sign     <= b.sign;
                        z.exponent <= b.exponent + 8'd127; // Re-bias
                        z.mantissa <= b.mantissa;
                        state <= PUT_Z;
                    end
                    // b is zero
                    else if ((b.exponent == 8'h00) && (b.mantissa == '0)) begin
                        z.sign     <= a.sign;
                        z.exponent <= a.exponent + 8'd127; // Re-bias
                        z.mantissa <= a.mantissa;
                        state <= PUT_Z;
                    end
                    // Normal numbers
                    else begin
                        // Handle denormals
                        if (a.exponent == 8'h00) begin
                            a.exponent <= 8'd1; // -126 in biased form
                        end else begin
                            a.mantissa[26] <= 1'b1; // Add implicit leading 1
                        end

                        if (b.exponent == 8'h00) begin
                            b.exponent <= 8'd1; // -126 in biased form
                        end else begin
                            b.mantissa[26] <= 1'b1; // Add implicit leading 1
                        end

                        state <= ALIGN;
                    end
                end

                ALIGN: begin
                    if ($signed(a.exponent) > $signed(b.exponent)) begin
                        b.exponent <= b.exponent + 8'd1;
                        b.mantissa <= {1'b0, b.mantissa[26:1]}; // Right shift
                        b.mantissa[0] <= b.mantissa[0] | b.mantissa[1]; // Sticky bit
                    end else if ($signed(a.exponent) < $signed(b.exponent)) begin
                        a.exponent <= a.exponent + 8'd1;
                        a.mantissa <= {1'b0, a.mantissa[26:1]}; // Right shift
                        a.mantissa[0] <= a.mantissa[0] | a.mantissa[1]; // Sticky bit
                    end else begin
                        state <= ADD_0;
                    end
                end

                ADD_0: begin
                    z.exponent <= a.exponent;
                    if (a.sign == b.sign) begin
                        sum <= {1'b0, a.mantissa} + {1'b0, b.mantissa};
                        z.sign <= a.sign;
                    end else begin
                        if (a.mantissa >= b.mantissa) begin
                            sum <= {1'b0, a.mantissa} - {1'b0, b.mantissa};
                            z.sign <= a.sign;
                        end else begin
                            sum <= {1'b0, b.mantissa} - {1'b0, a.mantissa};
                            z.sign <= b.sign;
                        end
                    end
                    state <= ADD_1;
                end

                ADD_1: begin
                    if (sum[27]) begin
                        z.mantissa <= sum[27:4]; // Keep 24 bits (1 implicit + 23 explicit)
                        guard      <= sum[3];
                        round_bit  <= sum[2];
                        sticky     <= sum[1] | sum[0];
                        z.exponent <= z.exponent + 8'd1;
                    end else begin
                        z.mantissa <= sum[26:3]; // Normal case
                        guard      <= sum[2];
                        round_bit  <= sum[1];
                        sticky     <= sum[0];
                    end
                    state <= NORMALISE_1;
                end

                NORMALISE_1: begin
                    if (!z.mantissa[23] && ($signed(z.exponent) > -126)) begin
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
                    if ($signed(z.exponent) < -126) begin // Underflow
                        z.exponent <= z.exponent + 8'd1;
                        z.mantissa <= {1'b0, z.mantissa[23:1]};
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
                    // Handle zero result properly (fixes -a + a = +0)
                    if (($signed(z.exponent) == -126) && (z.mantissa == '0)) begin
                        z.sign <= 1'b0; // Always +0 for x - x
                    end
                    // Check for overflow
                    if ($signed(z.exponent) > 127) begin
                        z.exponent <= 8'hFF;
                        z.mantissa <= '0; // Infinity
                    end
                    state <= PUT_Z;
                end

                PUT_Z: begin
                    reg_output_z_stb <= '1;
                    reg_output_z <= {z.sign, z.exponent + 8'd127, z.mantissa[22:0]};
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
