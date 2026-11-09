`timescale 1ns / 1ps
// ============================================================================
// Module: risc (Top-Level 5-Stage RV32I Pipelined Core)
// Incorporates:
// - Power Optimization via ALU Operand Isolation
// - Accurate Hazard Detection & Data Forwarding
// - EX-Stage Branch Evaluation (2-cycle branch resolution, clean flush)
// - Complete RV32I Branch Handling (BEQ, BNE, BLT, BGE, BLTU, BGEU)
// - Support for LUI, AUIPC, JAL, JALR
// - Low-Power Register File
// ============================================================================
module risc (
    input  wire        clk,
    input  wire        reset,

    // Waveform Debug Monitor Ports
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire [31:0] debug_alu_a,
    output wire [31:0] debug_alu_b,
    output wire [3:0]  debug_alu_ctrl,
    output wire [31:0] debug_alu_result,
    output wire [31:0] debug_mem_write_data,
    output wire [31:0] debug_mem_read_data,
    output wire        debug_wb_reg_write,
    output wire [4:0]  debug_wb_rd,
    output wire [31:0] debug_wb_data,

    // Key Register File Value Debug Ports
    output wire [31:0] debug_x1,
    output wire [31:0] debug_x2,
    output wire [31:0] debug_x3,
    output wire [31:0] debug_x4,
    output wire [31:0] debug_x5,
    output wire [31:0] debug_x6,
    output wire [31:0] debug_x7,
    output wire [31:0] debug_x8,
    output wire [31:0] debug_x9,
    output wire [31:0] debug_x10,
        output wire [31:0] debug_x11
);
           parameter OPT_ISO = 1;
       parameter OPT_RF  = 1;
    // DEBUG_RF=1 : x1..x11 read directly from the register array (simulation / display, forces FFs)
    // DEBUG_RF=0 : debug_x* tied to 0 so the register file can map to LUT-RAM (much smaller, less clock load)
    parameter DEBUG_RF = 1;

    // =========================================================================
    // 1. IF Stage (Instruction Fetch)
    // =========================================================================
    wire [31:0] pc_out;
    wire [31:0] pc_next;
    wire [31:0] if_instr;

    wire        branch_taken;
    wire [31:0] branch_jump_target;
    wire        pc_write;
    wire        ifid_write;
    wire        ifid_flush;
    wire        idex_flush;

    assign pc_next = (branch_taken) ? branch_jump_target : (pc_out + 32'd4);

    pc pc_inst (
        .clk      (clk),
        .reset    (reset),
        .pc_write (pc_write),
        .pc_in    (pc_next),
        .pc_out   (pc_out)
    );

    instruction_memory imem_inst (
        .addr        (pc_out),
        .instruction (if_instr)
    );

    // IF/ID Pipeline Register
    wire [31:0] id_pc;
    wire [31:0] id_instr;

    ifid ifid_inst (
        .clk        (clk),
        .reset      (reset),
        .ifid_write (ifid_write),
        .ifid_flush (ifid_flush),
        .if_pc      (pc_out),
        .if_instr   (if_instr),
        .id_pc      (id_pc),
        .id_instr   (id_instr)
    );

    // =========================================================================
    // 2. ID Stage (Instruction Decode)
    // =========================================================================
    wire [6:0] id_opcode   = id_instr[6:0];
    wire [4:0] id_rd       = id_instr[11:7];
    wire [2:0] id_funct3   = id_instr[14:12];
    wire [4:0] id_rs1      = id_instr[19:15];
    wire [4:0] id_rs2      = id_instr[24:20];
    wire       id_funct7_5 = id_instr[30];

    // Control Unit Output Signals
    wire       id_reg_write;
    wire       id_mem_to_reg;
    wire       id_mem_read;
    wire       id_mem_write;
    wire       id_alu_src;
    wire [1:0] id_alu_op;
    wire       id_branch;
    wire       id_jump;
    wire       id_jalr;
    wire       id_lui;
    wire       id_uses_rs1;
    wire       id_uses_rs2;

    control_unit cu_inst (
        .opcode     (id_opcode),
        .reg_write  (id_reg_write),
        .mem_to_reg (id_mem_to_reg),
        .mem_read   (id_mem_read),
        .mem_write  (id_mem_write),
        .alu_src    (id_alu_src),
        .alu_op     (id_alu_op),
        .branch     (id_branch),
        .jump       (id_jump),
        .jalr       (id_jalr),
        .lui        (id_lui),
        .uses_rs1   (id_uses_rs1),
        .uses_rs2   (id_uses_rs2)
    );

    // WB Stage Signals (declared for register file write-back)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_write_data;   // mem_to_reg mux now sits before the MEM/WB register (32 fewer FFs)

    // Register File instantiation
    wire [31:0] id_rdata1;
    wire [31:0] id_rdata2;

          register_file rf_inst (
           .clk        (clk),
           .reset      (reset),
           .reg_write  (wb_reg_write),
           .read_reg1  ((OPT_RF && !id_uses_rs1) ? 5'd0 : id_rs1),
           .read_reg2  ((OPT_RF && !id_uses_rs2) ? 5'd0 : id_rs2),
           .write_reg  (wb_rd),
           .write_data (wb_write_data),
           .read_data1 (id_rdata1),
           .read_data2 (id_rdata2)
       );

    // Immediate Generator Logic
    reg [31:0] id_imm;
    always @(*) begin
        case (id_opcode)
            7'b0010011, 7'b0000011, 7'b1100111: // I-type, Load, JALR
                id_imm = {{20{id_instr[31]}}, id_instr[31:20]};
            7'b0100011: // S-type (Store)
                id_imm = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
            7'b1100011: // B-type (Branch)
                id_imm = {{19{id_instr[31]}}, id_instr[31], id_instr[7], id_instr[30:25], id_instr[11:8], 1'b0};
            7'b0110111, 7'b0010111: // U-type (LUI, AUIPC)
                id_imm = {id_instr[31:12], 12'b0};
            7'b1101111: // J-type (JAL)
                id_imm = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};
            default:
                id_imm = 32'h00000000;
        endcase
    end

    // ID/EX Pipeline Register
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire        ex_alu_src;
    wire [1:0]  ex_alu_op;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_jalr;
    wire        ex_lui;
    wire [31:0] ex_pc;
    wire [31:0] ex_rdata1;
    wire [31:0] ex_rdata2;
    wire [31:0] ex_imm;
    wire [2:0]  ex_funct3;
    wire        ex_funct7_5;
    wire [4:0]  ex_rs1;
    wire [4:0]  ex_rs2;
    wire [4:0]  ex_rd;

    idex idex_inst (
        .clk           (clk),
        .reset         (reset),
        .idex_flush    (idex_flush),
        .id_reg_write  (id_reg_write),
        .id_mem_to_reg (id_mem_to_reg),
        .id_mem_read   (id_mem_read),
        .id_mem_write  (id_mem_write),
        .id_alu_src    (id_alu_src),
        .id_alu_op     (id_alu_op),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jalr       (id_jalr),
        .id_lui        (id_lui),
        .id_pc         (id_pc),
        .id_rdata1     (id_rdata1),
        .id_rdata2     (id_rdata2),
        .id_imm        (id_imm),
        .id_funct3     (id_funct3),
        .id_funct7_5   (id_funct7_5),
        .id_rs1        (id_rs1),
        .id_rs2        (id_rs2),
        .id_rd         (id_rd),
        .ex_reg_write  (ex_reg_write),
        .ex_mem_to_reg (ex_mem_to_reg),
        .ex_mem_read   (ex_mem_read),
        .ex_mem_write  (ex_mem_write),
        .ex_alu_src    (ex_alu_src),
        .ex_alu_op     (ex_alu_op),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_jalr       (ex_jalr),
        .ex_lui        (ex_lui),
        .ex_pc         (ex_pc),
        .ex_rdata1     (ex_rdata1),
        .ex_rdata2     (ex_rdata2),
        .ex_imm        (ex_imm),
        .ex_funct3     (ex_funct3),
        .ex_funct7_5   (ex_funct7_5),
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .ex_rd         (ex_rd)
    );

    // =========================================================================
    // 3. EX Stage (Execute & Forwarding Muxes)
    // =========================================================================
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire [31:0] mem_alu_result;
    wire [4:0]  mem_rd;
    wire        mem_reg_write;

    forwarding_unit fu_inst (
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .mem_rd        (mem_rd),
        .mem_reg_write (mem_reg_write),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );

    // Forwarding Mux A
    reg [31:0] ex_alu_a;
    always @(*) begin
        case (forward_a)
            2'b00: ex_alu_a = ex_rdata1;
            2'b10: ex_alu_a = mem_alu_result;
            2'b01: ex_alu_a = wb_write_data;
            default: ex_alu_a = ex_rdata1;
        endcase
    end

    // Forwarding Mux B
    reg [31:0] ex_rdata2_fwd;
    always @(*) begin
        case (forward_b)
            2'b00: ex_rdata2_fwd = ex_rdata2;
            2'b10: ex_rdata2_fwd = mem_alu_result;
            2'b01: ex_rdata2_fwd = wb_write_data;
            default: ex_rdata2_fwd = ex_rdata2;
        endcase
    end

    wire [3:0]  ex_alu_ctrl;
    wire [31:0] ex_alu_b = (ex_alu_src) ? ex_imm : ex_rdata2_fwd;
    wire [31:0] ex_alu_result;
    wire        ex_zero;

    alu_control alu_ctrl_inst (
        .alu_op   (ex_alu_op),
        .funct3   (ex_funct3),
        .funct7_5 (ex_funct7_5),
        .alu_ctrl (ex_alu_ctrl)
    );

    // -------------------------------------------------------------------------
    // Power Optimization: ALU Operand Isolation
    // -------------------------------------------------------------------------
    // JAL/JALR do not use the ALU result (target has its own adder, link value is PC+4), so they are excluded
    wire alu_active = OPT_ISO ? ((ex_reg_write & ~ex_jump) | ex_mem_read | ex_mem_write | ex_branch) : 1'b1;
    wire [31:0] isolated_a = alu_active ? (ex_lui ? 32'h00000000 : ex_alu_a) : 32'h00000000;
    wire [31:0] isolated_b = alu_active ? (ex_lui ? ex_imm : ex_alu_b) : 32'h00000000;
    wire [3:0]  active_ctrl = alu_active ? (ex_lui ? 4'b1111 : ex_alu_ctrl) : 4'b0000;

    alu alu_inst (
        .a        (isolated_a),
        .b        (isolated_b),
        .alu_ctrl (active_ctrl),
        .result   (ex_alu_result),
        .zero     (ex_zero)
    );

    // -------------------------------------------------------------------------
    // Branch Evaluation in EX Stage: Immediate Target & Condition Check
    // -------------------------------------------------------------------------
    reg ex_branch_condition;
    always @(*) begin
        case (ex_funct3)
            3'b000: ex_branch_condition = ex_zero;              // BEQ
            3'b001: ex_branch_condition = !ex_zero;             // BNE
            3'b100: ex_branch_condition = ex_alu_result[0];     // BLT (SLT)
            3'b101: ex_branch_condition = !ex_alu_result[0];    // BGE
            3'b110: ex_branch_condition = ex_alu_result[0];     // BLTU (SLTU)
            3'b111: ex_branch_condition = !ex_alu_result[0];    // BGEU
            default: ex_branch_condition = 1'b0;
        endcase
    end

    assign branch_taken = (ex_branch & ex_branch_condition) | ex_jump;
    // One shared adder for branch/JAL (PC+imm) and JALR (rs1+imm)
    wire [31:0] tgt_base = ex_jalr ? ex_alu_a : ex_pc;
    wire [31:0] tgt_sum  = tgt_base + ex_imm;
    assign branch_jump_target = ex_jalr ? (tgt_sum & ~32'd1) : tgt_sum;

    // Hazard Detection Unit with qualified register checks
    hazard_unit hu_inst (
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .id_uses_rs1 (id_uses_rs1),
        .id_uses_rs2 (id_uses_rs2),
        .ex_rd       (ex_rd),
        .ex_mem_read (ex_mem_read),
        .branch_taken(branch_taken),
        .pc_write    (pc_write),
        .ifid_write  (ifid_write),
        .ifid_flush  (ifid_flush),
        .idex_flush  (idex_flush)
    );

    // EX/MEM Pipeline Register
    wire        mem_mem_to_reg;
    wire        mem_mem_read;
    wire        mem_mem_write;
    wire [31:0] mem_rdata2;

    // For JAL/JALR, ALU result written back is PC+4
    wire [31:0] ex_result_to_mem = (ex_jump) ? (ex_pc + 32'd4) : ex_alu_result;

    exmem exmem_inst (
        .clk               (clk),
        .reset             (reset),
        .ex_reg_write      (ex_reg_write),
        .ex_mem_to_reg     (ex_mem_to_reg),
        .ex_mem_read       (ex_mem_read),
        .ex_mem_write      (ex_mem_write),
        .ex_branch         (1'b0), // Branch already resolved in EX
        .ex_jump           (1'b0),
        .ex_branch_target  (32'd0),
        .ex_zero           (ex_zero),
        .ex_alu_result     (ex_result_to_mem),
        .ex_rdata2         (ex_rdata2_fwd),
        .ex_rd             (ex_rd),
        .ex_funct3         (ex_funct3),
        .mem_reg_write     (mem_reg_write),
        .mem_mem_to_reg    (mem_mem_to_reg),
        .mem_mem_read      (mem_mem_read),
        .mem_mem_write     (mem_mem_write),
        .mem_branch        (),
        .mem_jump          (),
        .mem_branch_target (),
        .mem_zero          (),
        .mem_alu_result    (mem_alu_result),
        .mem_rdata2        (mem_rdata2),
        .mem_rd            (mem_rd),
        .mem_funct3        ()
    );

    // =========================================================================
    // 4. MEM Stage (Memory Access)
    // =========================================================================
    wire [31:0] mem_read_data;

    data_memory dmem_inst (
        .clk        (clk),
        .mem_read   (mem_mem_read),
        .mem_write  (mem_mem_write),
        .addr       (mem_alu_result),
        .write_data (mem_rdata2),
        .read_data  (mem_read_data)
    );

    // MEM/WB Pipeline Register
    memwb memwb_inst (
        .clk           (clk),
        .reset         (reset),
        .mem_reg_write (mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .mem_read_data (mem_read_data),
        .mem_alu_result(mem_alu_result),
        .mem_rd        (mem_rd),
        .wb_reg_write  (wb_reg_write),
        .wb_write_data (wb_write_data),
        .wb_rd         (wb_rd)
    );

    // =========================================================================
    // 5. Waveform Debug Signal Assignments
    // =========================================================================
    assign debug_pc             = pc_out;
    assign debug_instruction    = if_instr;
    assign debug_alu_a          = isolated_a;
    assign debug_alu_b          = isolated_b;
    assign debug_alu_ctrl       = active_ctrl;
    assign debug_alu_result     = ex_alu_result;
    assign debug_mem_write_data = mem_rdata2;
    assign debug_mem_read_data  = mem_read_data;
    assign debug_wb_reg_write   = wb_reg_write;
    assign debug_wb_rd          = wb_rd;
    assign debug_wb_data        = wb_write_data;

    generate
      if (DEBUG_RF) begin : g_dbg_rf
        assign debug_x1 = rf_inst.registers[1];
        assign debug_x2 = rf_inst.registers[2];
        assign debug_x3 = rf_inst.registers[3];
        assign debug_x4 = rf_inst.registers[4];
        assign debug_x5 = rf_inst.registers[5];
        assign debug_x6 = rf_inst.registers[6];
        assign debug_x7 = rf_inst.registers[7];
        assign debug_x8 = rf_inst.registers[8];
        assign debug_x9 = rf_inst.registers[9];
        assign debug_x10 = rf_inst.registers[10];
        assign debug_x11 = rf_inst.registers[11];
      end else begin : g_no_dbg_rf
        assign debug_x1 = 32'h00000000;
        assign debug_x2 = 32'h00000000;
        assign debug_x3 = 32'h00000000;
        assign debug_x4 = 32'h00000000;
        assign debug_x5 = 32'h00000000;
        assign debug_x6 = 32'h00000000;
        assign debug_x7 = 32'h00000000;
        assign debug_x8 = 32'h00000000;
        assign debug_x9 = 32'h00000000;
        assign debug_x10 = 32'h00000000;
        assign debug_x11 = 32'h00000000;
      end
    endgenerate

endmodule
