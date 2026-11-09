`timescale 1ns / 1ps
// ============================================================================
// Module: control_unit (Main Decoder with Accurate Register Use Tracking)
// ============================================================================
module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,
    output reg  [1:0] alu_op,
    output reg        branch,
    output reg        jump,
    output reg        jalr,
    output reg        lui,
    output reg        uses_rs1,
    output reg        uses_rs2
);
    always @(*) begin
        reg_write  = 1'b0;
        mem_to_reg = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        uses_rs1   = 1'b0;
        uses_rs2   = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write  = 1'b1;
                alu_src    = 1'b0;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b10;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b1;
            end
            7'b0010011: begin // I-type ALU
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b11;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b0; // Does not use rs2!
            end
            7'b0000011: begin // Load (LW)
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                mem_read   = 1'b1;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b00;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b0; // Does not use rs2!
            end
            7'b0100011: begin // Store (SW)
                reg_write  = 1'b0;
                alu_src    = 1'b1;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b1;
                branch     = 1'b0;
                alu_op     = 2'b00;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b1;
            end
            7'b1100011: begin // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
                reg_write  = 1'b0;
                alu_src    = 1'b0;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b1;
                alu_op     = 2'b01;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b1;
            end
            7'b1101111: begin // JAL
                reg_write  = 1'b1;
                alu_src    = 1'b0;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                jump       = 1'b1;
                jalr       = 1'b0;
                alu_op     = 2'b00;
                uses_rs1   = 1'b0;
                uses_rs2   = 1'b0;
            end
            7'b1100111: begin // JALR
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                jump       = 1'b1;
                jalr       = 1'b1;
                alu_op     = 2'b00;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b0;
            end
            7'b0110111: begin // LUI
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                lui        = 1'b1;
                alu_op     = 2'b00;
                uses_rs1   = 1'b0;
                uses_rs2   = 1'b0;
            end
            default: begin
                reg_write  = 1'b0;
                mem_to_reg = 1'b0;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                alu_src    = 1'b0;
                alu_op     = 2'b00;
                branch     = 1'b0;
                jump       = 1'b0;
                jalr       = 1'b0;
                lui        = 1'b0;
                uses_rs1   = 1'b0;
                uses_rs2   = 1'b0;
            end
        endcase
    end
endmodule
