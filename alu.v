`timescale 1ns / 1ps
// ============================================================================
// Module: alu (Arithmetic Logic Unit - Complete RV32I Operations)
// ============================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a & b;                                      // AND
            4'b0001: result = a | b;                                      // OR
            4'b0010: result = a + b;                                      // ADD
            4'b0011: result = a << b[4:0];                                // SLL
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;                    // SLTU (unsigned)
            4'b0101: result = a >> b[4:0];                                // SRL
            4'b0110: result = a - b;                                      // SUB
            4'b0111: result = ((a) < (b)) ? 32'd1 : 32'd0;  // SLT (signed)
            4'b1000: result = (a) >>> b[4:0];                      // SRA
            4'b1101: result = a ^ b;                                      // XOR
            4'b1111: result = b;                                          // PASS_B (LUI)
            default: result = 32'h00000000;
        endcase
    end

    assign zero = (result == 32'h00000000);
endmodule
