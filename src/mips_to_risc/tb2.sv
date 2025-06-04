`include"mips_to_riscv_translator2.sv"
`timescale 1ns/1ps

module mips_to_riscv_translator_tb;

    // Parameters
    parameter CLK_PERIOD = 10;  // 10 ns = 100 MHz clock

    // Signals
    reg clk;
    reg reset;
    reg [31:0] mips_instr;
    wire [31:0] riscv_instr;
    wire trans_valid;
    wire instr_ready;
    
    // Instantiate the DUT
    mips_to_riscv_translator dut (
        .clk(clk),
        .reset(reset),
        .mips_instruction(mips_instr),
        .riscv_instruction(riscv_instr),
        .translation_valid(trans_valid),
        .instruction_ready(instr_ready)
    );

    // Clock generator
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test procedure
    initial begin
        // Initialize
        reset = 1'b1;
        mips_instr = 32'b0;
        
        // Reset the DUT
        #20;
        reset = 1'b0;
        #10;
        
        // Test 1: ADD instruction (R-type, no splitting needed)
        $display("=== Test 1: ADD instruction ===");
        mips_instr = 32'b000000_00001_00010_00011_00000_100000; // add $3, $1, $2
        wait_for_ready();
        print_results();
        
        // Test 2: ADDI with small immediate (no splitting)
        $display("\n=== Test 2: ADDI with small immediate ===");
        mips_instr = 32'b001000_00001_00010_0000000000001010; // addi $2, $1, 10
        wait_for_ready();
        print_results();
        
        // Test 3: ADDI with large immediate (needs splitting)
        $display("\n=== Test 3: ADDI with large immediate ===");
        mips_instr = 32'b001000_00001_00010_1000000000001010; // addi $2, $1, -32758 (sign-extended)
        wait_for_ready();
        print_results();
        wait_for_ready(); // Wait for second cycle
        
        // Test 4: LW with large offset (needs splitting)
        $display("\n=== Test 4: LW with large offset ===");
        mips_instr = 32'b100011_00001_00010_1000000000001010; // lw $2, -32758($1)
        wait_for_ready();
        print_results();
        wait_for_ready(); // Wait for second cycle
        
        // Test 5: J instruction
        $display("\n=== Test 5: J instruction ===");
        mips_instr = 32'b000010_00000000000000000000011001; // j 0x19
        wait_for_ready();
        print_results();
        
        // Test 6: Floating-point ADD
        $display("\n=== Test 6: FADD.S instruction ===");
        mips_instr = 32'b010001_00000_00001_00010_00000_010000; // fadd.s $f2, $f1, $f0
        wait_for_ready();
        print_results();
        
        // Test 7: Invalid instruction
        $display("\n=== Test 7: Invalid instruction ===");
        mips_instr = 32'b111111_00000_00000_00000_00000_000000; // invalid opcode
        wait_for_ready();
        print_results();
        
        // Finish simulation
        #20;
        $display("\nAll tests completed!");
        $finish;
    end

    // Helper task to wait for instruction ready
    task wait_for_ready;
        begin
            while (!instr_ready) begin
                #(CLK_PERIOD);
            end
            #1; // Small delay after ready
        end
    endtask

    // Helper task to print results
    task print_results;
        begin
            $display("MIPS:  %h", mips_instr);
            $display("RISC-V: %h (valid: %b)", riscv_instr, trans_valid);
            $display("State: %d, Ready: %b", dut.current_state, instr_ready);
            #(CLK_PERIOD);
        end
    endtask

    // VCD dump for waveform viewing
    initial begin
        $dumpfile("mips_to_riscv.vcd");
        $dumpvars(0, mips_to_riscv_translator_tb);
    end

endmodule