`include"mips_to_riscv_translator.sv"
`timescale 1ns/1ps

module mips_to_riscv_translator_tb;

    // Сигналы тестбенча
    reg [31:0] mips_instruction;
    wire [31:0] riscv_instruction;
    wire translation_valid;
    
    // Экземпляр тестируемого модуля
    mips_to_riscv_translator dut (
        .mips_instruction(mips_instruction),
        .riscv_instruction(riscv_instruction),
        .translation_valid(translation_valid)
    );
    
    // Тестовые случаи
    task run_test;
        input [31:0] mips_instr;
        input [31:0] expected_riscv;
        input expected_valid;
        input [80:0] test_name;
        begin
            mips_instruction = mips_instr;
            #10;
            
            $display("[%0t] Test: %s", $time, test_name);
            $display("  MIPS:     %h", mips_instruction);
            $display("  RISC-V:   %h", riscv_instruction);
            $display("  Expected: %h", expected_riscv);
            $display("  Valid:    %b (expected %b)", 
                    translation_valid, expected_valid);
            
            if (riscv_instruction !== expected_riscv || 
                translation_valid !== expected_valid) begin
                $display("  ERROR: Mismatch detected!");
                $display("  TEST FAILED!");
            end else begin
                $display("  TEST PASSED!");
            end
            $display("");
        end
    endtask
    
    // Основной тестовый процесс
    initial begin
        $dumpfile("mips2riscv_tb.vcd");
        $dumpvars(0, mips_to_riscv_translator_tb);
        
        $display("=== Starting MIPS to RISC-V Translator Test ===");
        $display("=== Icarus Verilog Compatible Version ===");
        $display("");
        
        // R-тип инструкции
        run_test(32'h00430820, 32'h003100b3, 1'b1, "ADD $1, $2, $3 -> add x1, x2, x3");
        run_test(32'h00a62022, 32'h40628233, 1'b1, "SUB $4, $5, $6 -> sub x4, x5, x6");
        run_test(32'h01093824, 32'h009443b3, 1'b1, "AND $7, $8, $9 -> and x7, x8, x9");
        run_test(32'h016c6025, 32'h00c5e533, 1'b1, "OR $10, $11, $12 -> or x10, x11, x12");
        run_test(32'h01cf682a, 32'h00f74ab3, 1'b1, "SLT $13, $14, $15 -> slt x13, x14, x15");
        
        // I-тип инструкции
        run_test(32'h2230002a, 32'h02a88813, 1'b1, "ADDI $16, $17, 42 -> addi x16, x17, 42");
        run_test(32'h327200ff, 32'h0ff9c913, 1'b1, "ANDI $18, $19, 0xFF -> andi x18, x19, 0xFF");
        
        // Операции с памятью
        run_test(32'h8eb40064, 32'h064a2a03, 1'b1, "LW $20, 100($21) -> lw x20, 100(x21)");
        run_test(32'haf7600c8, 32'h016b1c37, 1'b1, "SW $22, 200($23) -> sw x22, 200(x23)");
        
        // Инструкции перехода
        run_test(32'h13190008, 32'h019c0063, 1'b1, "BEQ $24, $25, label -> beq x24, x25, label");
        run_test(32'h08010000, 32'h000010ef, 1'b1, "J 0x00400000 -> jal x0, 0x00400000");
        
        // Нераспознанная инструкция
        run_test(32'hffffffff, 32'h00000000, 1'b0, "INVALID instruction");
        
        $display("=== Test Complete ===");
        $finish;
    end
    
    // Таймаут на случай зависания
    initial begin
        #1000;
        $display("\nERROR: Test timeout reached!");
        $finish;
    end

endmodule