`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_riscv_core (Automated Self-Checking Verification Environment)
// Verifies instruction execution, forwarding, hazard stall, and branch flushing
// Generates VCD waveform and SAIF activity file for Vivado power estimation
// ============================================================================
module tb_riscv_core;

    reg clk;
    reg reset;

    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;
    wire [31:0] debug_alu_a;
    wire [31:0] debug_alu_b;
    wire [3:0]  debug_alu_ctrl;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_mem_write_data;
    wire [31:0] debug_mem_read_data;
    wire        debug_wb_reg_write;
    wire [4:0]  debug_wb_rd;
    wire [31:0] debug_wb_data;

    wire [31:0] debug_x1, debug_x2, debug_x3, debug_x4, debug_x5, debug_x6, debug_x7;
    wire [31:0] debug_x8, debug_x9, debug_x10, debug_x11;

    // Instantiate Unit Under Test (UUT)
    risc uut (
        .clk                  (clk),
        .reset                (reset),
        .debug_pc             (debug_pc),
        .debug_instruction    (debug_instruction),
        .debug_alu_a          (debug_alu_a),
        .debug_alu_b          (debug_alu_b),
        .debug_alu_ctrl       (debug_alu_ctrl),
        .debug_alu_result     (debug_alu_result),
        .debug_mem_write_data (debug_mem_write_data),
        .debug_mem_read_data  (debug_mem_read_data),
        .debug_wb_reg_write   (debug_wb_reg_write),
        .debug_wb_rd          (debug_wb_rd),
        .debug_wb_data        (debug_wb_data),
        .debug_x1             (debug_x1),
        .debug_x2             (debug_x2),
        .debug_x3             (debug_x3),
        .debug_x4             (debug_x4),
        .debug_x5             (debug_x5),
        .debug_x6             (debug_x6),
        .debug_x7             (debug_x7),
        .debug_x8             (debug_x8),
        .debug_x9             (debug_x9),
        .debug_x10            (debug_x10),
        .debug_x11            (debug_x11)
    );

    // 100 MHz Clock generation (10ns period)
    always #5 clk = ~clk;

    integer cycle;
    integer pass_count;
    integer fail_count;

    initial begin
        $display("=================================================================");
        $display("   STARTING 32-BIT RISC-V 5-STAGE PIPELINED CORE VERIFICATION   ");
        $display("=================================================================");
        clk = 0;
        reset = 1;
        cycle = 0;
        pass_count = 0;
        fail_count = 0;

        // Waveform generation
        $dumpfile("riscv_sim.vcd");
        $dumpvars(0, tb_riscv_core);

        // Reset sequence (asserted for 3 cycles)
        #25;
        reset = 0;
        $display("[Time %0t ns] Reset released. Core executing instructions...", $time);

        // Monitor pipeline progression for 35 cycles
        for (cycle = 1; cycle <= 35; cycle = cycle + 1) begin
            @(posedge clk);
            #1; // Sample shortly after clock edge
            $display("[Cycle %2d | Time %4t ns] PC: 0x%08h | Instr: 0x%08h | ALU_Out: 0x%08h", 
                     cycle, $time, debug_pc, debug_instruction, debug_alu_result);
            if (debug_wb_reg_write && debug_wb_rd != 0) begin
                $display("       -> WB Stage: Register x%0d <= 0x%08h (%0d)", 
                         debug_wb_rd, debug_wb_data, debug_wb_data);
            end
        end

        $display("");
        $display("=================================================================");
        $display("           FINAL REGISTER AUDIT & SELF-CHECKING VERIFICATION     ");
        $display("=================================================================");

        // Test 1: x1 = 10 (ADDI)
        if (debug_x1 == 32'd10) begin
            $display("[PASS] Test 1: x1 == 10 (ADDI x1, x0, 10)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 1: Expected x1=10, Got x1=%0d", debug_x1);
            fail_count = fail_count + 1;
        end

        // Test 2: x2 = 20 (ADDI)
        if (debug_x2 == 32'd20) begin
            $display("[PASS] Test 2: x2 == 20 (ADDI x2, x0, 20)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 2: Expected x2=20, Got x2=%0d", debug_x2);
            fail_count = fail_count + 1;
        end

        // Test 3: x3 = 30 (ADD with EX->EX Forwarding)
        if (debug_x3 == 32'd30) begin
            $display("[PASS] Test 3: x3 == 30 (ADD x3, x1, x2 with Forwarding)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 3: Expected x3=30, Got x3=%0d", debug_x3);
            fail_count = fail_count + 1;
        end

        // Test 4: x4 = 20 (SUB with EX->EX Forwarding)
        if (debug_x4 == 32'd20) begin
            $display("[PASS] Test 4: x4 == 20 (SUB x4, x3, x1 with Forwarding)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 4: Expected x4=20, Got x4=%0d", debug_x4);
            fail_count = fail_count + 1;
        end

        // Test 5: x5 = 20 (SW followed by LW)
        if (debug_x5 == 32'd20) begin
            $display("[PASS] Test 5: x5 == 20 (SW x4, 0(x0) and LW x5, 0(x0))");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 5: Expected x5=20, Got x5=%0d", debug_x5);
            fail_count = fail_count + 1;
        end

        // Test 6: x6 = 40 (Load-Use Stall + ADD)
        if (debug_x6 == 32'd40) begin
            $display("[PASS] Test 6: x6 == 40 (Load-Use Stall correctly resolved)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 6: Expected x6=40, Got x6=%0d", debug_x6);
            fail_count = fail_count + 1;
        end

        // Test 7: Branch resolution and pipeline flush
        if (debug_x7 == 32'd100) begin
            $display("[PASS] Test 7: x7 == 100 (BEQ Taken & Branch Flush Verified!)");
            pass_count = pass_count + 1;
        end else if (debug_x7 == 32'd99) begin
            $display("[FAIL] Test 7: x7 == 99 (Branch Flush Failed - speculatively executed)");
            fail_count = fail_count + 1;
        end else begin
            $display("[FAIL] Test 7: Expected x7=100, Got x7=%0d", debug_x7);
            fail_count = fail_count + 1;
        end

        // Test 8: x8 = 40 (SLLI)
        if (debug_x8 == 32'd40) begin
            $display("[PASS] Test 8: x8 == 40 (SLLI x8, x1, 2)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 8: Expected x8=40, Got x8=%0d", debug_x8);
            fail_count = fail_count + 1;
        end

        // Test 9: x9 = 8 (AND)
        if (debug_x9 == 32'd8) begin
            $display("[PASS] Test 9: x9 == 8 (AND x9, x3, x6)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 9: Expected x9=8, Got x9=%0d", debug_x9);
            fail_count = fail_count + 1;
        end

        // Test 10: x10 = 62 (OR)
        if (debug_x10 == 32'd62) begin
            $display("[PASS] Test 10: x10 == 62 (OR x10, x3, x6)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 10: Expected x10=62, Got x10=%0d", debug_x10);
            fail_count = fail_count + 1;
        end

        // Test 11: x11 = 30 (XOR)
        if (debug_x11 == 32'd30) begin
            $display("[PASS] Test 11: x11 == 30 (XOR x11, x1, x2)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test 11: Expected x11=30, Got x11=%0d", debug_x11);
            fail_count = fail_count + 1;
        end

        $display("=================================================================");
        $display("   TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=================================================================");
        if (fail_count == 0) begin
            $display(">>> ALL INSTRUCTION EXECUTION & HAZARD TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
            $display(">>> ERRORS DETECTED DURING SIMULATION! <<<");
        end
        $finish;
    end

endmodule
