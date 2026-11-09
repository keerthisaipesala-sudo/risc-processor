`timescale 1ns / 1ps
// ============================================================================
// Module: data_memory (Power-Optimized 4KB Data Memory)
// Implements read gating to minimize bus switching activity on inactive cycles
// ============================================================================
module data_memory (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);
    reg [31:0] mem [0:1023]; // 1024 words (4KB)
    integer i;

    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
    end

    always @(posedge clk) begin
        if (mem_write) begin
            mem[addr[11:2]] <= write_data;
        end
    end

    // Power Optimization: Only drive read data bus when active read requested
    assign read_data = (mem_read) ? mem[addr[11:2]] : 32'h00000000;
endmodule
