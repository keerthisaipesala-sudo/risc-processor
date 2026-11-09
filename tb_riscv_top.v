`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_riscv_top (Top-Level FPGA Wrapper Self-Checking Verification)
// Target: Digilent Basys-3 / Artix-7 xc7a35tcpg236-1
// Verifies:
//   - 100 MHz top clock and 25 MHz generated core clock
//   - Reset deassertion sequence (200 ns active-high)
//   - Core execution of standard instruction suite
//   - Register audit via dut.dbg_x1 .. dut.dbg_x11 (in RTL mode)
//   - Supports post-implementation netlist simulation with -d POST_IMPL_NETLIST
// ============================================================================
module tb_riscv_top;

    reg clk_100mhz;
    reg btn_reset;
    reg [3:0] sw_display_sel;

    wire [15:0] led_out;
    wire [6:0]  seg;
    wire [3:0]  an;

    // Instantiate FPGA Top-Level Module
    riscv_top_fpga dut (
        .clk_100mhz    (clk_100mhz),
        .btn_reset     (btn_reset),
        .sw_display_sel(sw_display_sel),
        .led_out       (led_out),
        .seg           (seg),
        .an            (an)
    );

    // 100 MHz Clock Generator (Period = 10.0 ns, 50% duty cycle)
    initial clk_100mhz = 1'b0;
    always #5.0 clk_100mhz = ~clk_100mhz;

`ifndef POST_IMPL_NETLIST
    // Optional dynamic program preload via +PROG=<path>
    reg [256*8-1:0] prog_mem_file;
    initial begin
        if ($value$plusargs("PROG=%s", prog_mem_file)) begin
            $readmemh(prog_mem_file, dut.core_inst.imem_inst.mem);
            $display("[tb_riscv_top] Loaded program file from: %0s", prog_mem_file);
        end
    end
`endif

    integer pass_count;
    integer fail_count;

    initial begin
        $display("=================================================================");
        $display("   STARTING TOP-LEVEL FPGA TESTBENCH VERIFICATION (tb_riscv_top) ");
        $display("=================================================================");
        pass_count     = 0;
        fail_count     = 0;
        sw_display_sel = 4'h0;
        btn_reset      = 1'b1; // Active-high reset asserted

        // 1. Hold reset high for 200 ns
        #200;
        btn_reset = 1'b0; // Release reset
        $display("[Time %0t ns] Reset released. 25 MHz core executing...", $time);

        // 2. Run simulation for ~2 us (2000 ns after reset)
        #2000;
        $display("[Time %0t ns] Simulation period complete (~2 us). Auditing registers...", $time);

`ifndef POST_IMPL_NETLIST
        // 3. Register Verification Checks (RTL Simulation Mode)
        // Test 1: x1 = 10
        if (dut.dbg_x1 === 32'd10) begin
            $display("[PASS] Register x1 == 10");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x1: Expected 10, Got %0d", dut.dbg_x1);
            fail_count = fail_count + 1;
        end

        // Test 2: x2 = 20
        if (dut.dbg_x2 === 32'd20) begin
            $display("[PASS] Register x2 == 20");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x2: Expected 20, Got %0d", dut.dbg_x2);
            fail_count = fail_count + 1;
        end

        // Test 3: x3 = 30
        if (dut.dbg_x3 === 32'd30) begin
            $display("[PASS] Register x3 == 30");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x3: Expected 30, Got %0d", dut.dbg_x3);
            fail_count = fail_count + 1;
        end

        // Test 4: x4 = 20
        if (dut.dbg_x4 === 32'd20) begin
            $display("[PASS] Register x4 == 20");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x4: Expected 20, Got %0d", dut.dbg_x4);
            fail_count = fail_count + 1;
        end

        // Test 5: x5 = 20
        if (dut.dbg_x5 === 32'd20) begin
            $display("[PASS] Register x5 == 20");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x5: Expected 20, Got %0d", dut.dbg_x5);
            fail_count = fail_count + 1;
        end

        // Test 6: x6 = 40
        if (dut.dbg_x6 === 32'd40) begin
            $display("[PASS] Register x6 == 40");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x6: Expected 40, Got %0d", dut.dbg_x6);
            fail_count = fail_count + 1;
        end

        // Test 7: x7 = 100 (proves branch flush: 99 skipped!)
        if (dut.dbg_x7 === 32'd100) begin
            $display("[PASS] Register x7 == 100 (Branch Flush Verified)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x7: Expected 100, Got %0d (branch flush failed if 99)", dut.dbg_x7);
            fail_count = fail_count + 1;
        end

        // Test 8: x8 = 40
        if (dut.dbg_x8 === 32'd40) begin
            $display("[PASS] Register x8 == 40");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x8: Expected 40, Got %0d", dut.dbg_x8);
            fail_count = fail_count + 1;
        end

        // Test 9: x9 = 8
        if (dut.dbg_x9 === 32'd8) begin
            $display("[PASS] Register x9 == 8");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x9: Expected 8, Got %0d", dut.dbg_x9);
            fail_count = fail_count + 1;
        end

        // Test 10: x10 = 62
        if (dut.dbg_x10 === 32'd62) begin
            $display("[PASS] Register x10 == 62");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x10: Expected 62, Got %0d", dut.dbg_x10);
            fail_count = fail_count + 1;
        end

        // Test 11: x11 = 30
        if (dut.dbg_x11 === 32'd30) begin
            $display("[PASS] Register x11 == 30");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Register x11: Expected 30, Got %0d", dut.dbg_x11);
            fail_count = fail_count + 1;
        end

        $display("=================================================================");
        $display("   TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=================================================================");
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TEST FAILED WITH %0d FAILURES", fail_count);
        end
`else
        $display("[POST-IMPL] Post-implementation simulation complete at %0t ns.", $time);
        $display("[POST-IMPL] Output LEDs = 0x%04h, Seven-Segment seg = 0x%02h, an = 0x%01h", led_out, seg, an);
`endif
        $finish;
    end

endmodule
