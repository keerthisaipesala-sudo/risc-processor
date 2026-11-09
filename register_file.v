`timescale 1ns / 1ps
// ============================================================================
// Module: register_file (Power-Optimized 32x32 Register File)
// Synthesizable to Vivado RAM32M (Distributed LUTRAM) or Register array
// Features write-to-read internal forwarding and x0 hardwired to zero
// ============================================================================
module register_file (
    input  wire        clk,
    input  wire        reset,
    input  wire        reg_write,
    input  wire [4:0]  read_reg1,
    input  wire [4:0]  read_reg2,
    input  wire [4:0]  write_reg,
    input  wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);
    reg [31:0] registers [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'h00000000;
    end

    always @(posedge clk) begin
        if (reg_write && (write_reg != 5'd0)) begin
            registers[write_reg] <= write_data;
        end
    end

    // Asynchronous read with internal WB->ID forwarding
    assign read_data1 = (read_reg1 == 5'd0) ? 32'h00000000 :
                        (reg_write && (write_reg == read_reg1)) ? write_data :
                        registers[read_reg1];

    assign read_data2 = (read_reg2 == 5'd0) ? 32'h00000000 :
                        (reg_write && (write_reg == read_reg2)) ? write_data :
                        registers[read_reg2];

endmodule
