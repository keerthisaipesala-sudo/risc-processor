`timescale 1ns / 1ps
// ============================================================================
// Module: riscv_top_fpga (Top-Level FPGA Wrapper for Basys-3 / Artix-7)
// Provides clock scaling, LED indicators, and 7-segment display multiplexer
// Fits within FPGA pin constraints (avoids pin overflow)
// ============================================================================
module riscv_top_fpga (
    input  wire        clk_100mhz,
    input  wire        btn_reset,      // Active-high reset pushbutton
    input  wire [3:0]  sw_display_sel, // Switch selector for 7-segment display
    output reg  [15:0] led_out,        // Status LEDs
    output reg  [6:0]  seg,            // 7-segment cathodes (active-low)
    output reg  [3:0]  an              // 7-segment anodes (active-low)
);
    // Clock divider: scale 100MHz down to 25MHz core clock and 1kHz display clock
    reg [1:0]  clk_div = 2'd0;
    reg [17:0] disp_div = 18'd0;

    always @(posedge clk_100mhz) begin
        clk_div  <= clk_div + 2'd1;
        disp_div <= disp_div + 18'd1;
    end

          wire core_clk;
   BUFG core_clk_buf (.I(clk_div[1]), .O(core_clk)); // 25 MHz on global clock network
    wire disp_clk = disp_div[17]; // ~380 Hz refresh

    // Core debug wires
    wire [31:0] dbg_pc;
    wire [31:0] dbg_instr;
    wire [31:0] dbg_alu_result;
    wire [31:0] dbg_mem_data;
    wire [31:0] dbg_wb_data;
    wire [31:0] dbg_x1, dbg_x2, dbg_x3, dbg_x4, dbg_x5, dbg_x6, dbg_x7;
    wire [31:0] dbg_x8, dbg_x9, dbg_x10, dbg_x11;

    // Instantiate 5-stage core
    risc core_inst (
        .clk                  (core_clk),
        .reset                (btn_reset),
        .debug_pc             (dbg_pc),
        .debug_instruction    (dbg_instr),
        .debug_alu_a          (),
        .debug_alu_b          (),
        .debug_alu_ctrl       (),
        .debug_alu_result     (dbg_alu_result),
        .debug_mem_write_data (),
        .debug_mem_read_data  (dbg_mem_data),
        .debug_wb_reg_write   (),
        .debug_wb_rd          (),
        .debug_wb_data        (dbg_wb_data),
        .debug_x1             (dbg_x1),
        .debug_x2             (dbg_x2),
        .debug_x3             (dbg_x3),
        .debug_x4             (dbg_x4),
        .debug_x5             (dbg_x5),
        .debug_x6             (dbg_x6),
        .debug_x7             (dbg_x7),
        .debug_x8             (dbg_x8),
        .debug_x9             (dbg_x9),
        .debug_x10            (dbg_x10),
        .debug_x11            (dbg_x11)
    );

    // Multiplex 16-bit word to display based on switches
    reg [15:0] disp_word;
    always @(*) begin
        case (sw_display_sel)
            4'h0: disp_word = dbg_pc[15:0];
            4'h1: disp_word = dbg_alu_result[15:0];
            4'h2: disp_word = dbg_x1[15:0];
            4'h3: disp_word = dbg_x2[15:0];
            4'h4: disp_word = dbg_x3[15:0];
            4'h5: disp_word = dbg_x4[15:0];
            4'h6: disp_word = dbg_x5[15:0];
            4'h7: disp_word = dbg_x6[15:0];
            4'h8: disp_word = dbg_x7[15:0];
            4'h9: disp_word = dbg_x8[15:0];
            4'hA: disp_word = dbg_x9[15:0];
            4'hB: disp_word = dbg_x10[15:0];
            4'hC: disp_word = dbg_x11[15:0];
            default: disp_word = dbg_wb_data[15:0];
        endcase
        led_out = {dbg_pc[7:0], dbg_wb_data[7:0]};
    end

    // 4-Digit 7-Segment Multiplexing
    reg [1:0] digit_sel = 2'd0;
    always @(posedge disp_clk) digit_sel <= digit_sel + 2'd1;

    reg [3:0] hex_nibble;
    always @(*) begin
        case (digit_sel)
            2'b00: begin an = 4'b1110; hex_nibble = disp_word[3:0]; end
            2'b01: begin an = 4'b1101; hex_nibble = disp_word[7:4]; end
            2'b10: begin an = 4'b1011; hex_nibble = disp_word[11:8]; end
            2'b11: begin an = 4'b0111; hex_nibble = disp_word[15:12]; end
        endcase
    end

    // Hex to 7-segment decoder
    always @(*) begin
        case (hex_nibble)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end
endmodule
