`timescale 1ns / 1ps
// ============================================================================
// Module: pc (Program Counter with Write Enable)
// ============================================================================
module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_write,       // Enable PC write (0 = stall for Load-Use)
    input  wire [31:0] pc_in,
    output reg  [31:0] pc_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'h00000000;
        end else if (pc_write) begin
            pc_out <= pc_in;
        end
    end
endmodule
