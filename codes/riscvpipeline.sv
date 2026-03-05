module riscvpipeline(input  logic        clk, reset, 
                     output logic [31:0] WriteData, DataAdr, 
                     output logic        MemWrite);
  
  // pipeline registers and signals
  typedef struct packed {
      logic [31:0] Instr;
      logic [31:0] PC;
      logic [31:0] PCPlus4;
  } IF_ID_reg;

  IF_ID_reg IF_ID, IF_ID_next;

  typedef struct packed {
      logic        RegWrite;
      logic [1:0]  ResultSrc;
      logic        MemWrite;
      logic        Jump;
      logic        Branch;
      logic [3:0]  ALUControl;
      logic        ALUSrc;
      logic [31:0] Rs1;
      logic [31:0] Rs2;
      logic [31:0] RD1;
      logic [31:0] RD2;
      logic [31:0] PC;
      logic [4:0]  Rd;
      logic [31:0] ImmExt;
      logic [31:0] PCPlus4;
      logic [6:0]  op;
      logic [2:0]  funct3;
  } ID_EX_reg;

  ID_EX_reg ID_EX, ID_EX_next;

  typedef struct packed {
      logic        RegWrite;
      logic [1:0]  ResultSrc;
      logic        MemWrite;
      logic [31:0] ALUResult;
      logic [31:0] WriteData;
      logic [4:0]  Rd;
      logic [31:0] PCPlus4;
      logic [6:0]  op;
      logic [2:0]  funct3;
      logic [31:0] ImmExt;
      logic [31:0] PCTarget;
  } EX_MEM_reg;

  EX_MEM_reg EX_MEM, EX_MEM_next;

  typedef struct packed {
      logic        RegWrite;
      logic [1:0]  ResultSrc;
      logic [31:0] ALUResult;
      logic [31:0] ReadData;
      logic [4:0]  Rd;
      logic [31:0] PCPlus4;
      logic [31:0] ImmExt;
      logic [31:0] PCTarget;
  } MEM_WB_reg;

  MEM_WB_reg MEM_WB, MEM_WB_next;


  /* ---------------------------------------------------------------------------- */

  // pipeline registers update logic
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        IF_ID <= '0;
        ID_EX <= '0;
        EX_MEM <= '0;
        MEM_WB <= '0;
    end 
    else if (StallD) begin
        IF_ID <= IF_ID;      // hold IF_ID on stall
        ID_EX <= ID_EX_next;
        EX_MEM <= EX_MEM_next;
        MEM_WB <= MEM_WB_next;
    end
    else begin
        IF_ID <= IF_ID_next;
        ID_EX <= ID_EX_next;
        EX_MEM <= EX_MEM_next;
        MEM_WB <= MEM_WB_next;
    end
    
    if (FlushD) begin
        IF_ID <= '0; // reset IF_ID on flush
    end 
    if (FlushE) begin
        ID_EX <= '0; // reset ID_EX on flush
    end 
  end


  /* ---------------------------------------------------------------------------- */

  // modules istances
  logic [31:0] PCCurrent;
  logic [31:0] InstrImem;
  imem imem_unit (PCCurrent, InstrImem);

  logic [31:0] dmem_rd; // output from dmem
  logic        dmem_we;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wd;
  logic [3:0]  dmem_byte_enabler;
  dmem dmem_unit (clk, dmem_we, dmem_addr, dmem_wd, dmem_byte_enabler, dmem_rd);

  logic        rf_we;
  logic [4:0]  rf_read_addr1, rf_read_addr2, rf_write_addr;
  logic [31:0] rf_write_data, rf_read_data1, rf_read_data2;
  regfile regfile_unit (clk, rf_we, rf_read_addr1, rf_read_addr2, rf_write_addr, 
                        rf_write_data, rf_read_data1, rf_read_data2);

  logic [6:0]  op;
  logic [2:0]  immsrc, funct3;
  logic        memwrite, branch, alusrc, regwrite, jump, funct7b5;
  logic [1:0]  resultsrc, aluop;
  logic [3:0]  alucontrol;
  maindec maindec_unit (op, resultsrc, memwrite, branch, alusrc, regwrite, jump, immsrc, aluop);
  aludec aludec_unit (op, funct3, funct7b5, aluop, alucontrol);

  logic [31:0] imm_src, imm_extended;
  extend extend_unit (imm_src, immsrc, imm_extended);

  logic [31:0] alu_src_a, alu_src_b, alu_result;
  logic [3:0]  alu_alucontrol;
  logic        alu_zero, alu_sign, alu_overflow, alu_carry;
  logic        alu_itype;
  alu alu_unit (alu_src_a, alu_src_b, alu_alucontrol, alu_itype, 
                alu_result, alu_zero, alu_sign, alu_overflow, alu_carry);

  logic  [31:0] adder_src_a, adder_src_b, adder_output;
  adder add_unit (adder_src_a, adder_src_b, adder_output);

  logic [4:0] hazard_Rs1D, hazard_Rs2D, hazard_Rs1E, hazard_Rs2E, hazard_RdE, hazard_RdM, hazard_RdW;
  logic [1:0] hazard_PcSrc;
  logic [1:0] hazard_ResultSrcE;
  logic       hazard_RegWriteM, hazard_RegWriteW;
  logic [1:0] hazard_ForwardAE, hazard_ForwardBE;
  logic       hazard_StallF, hazard_StallD, hazard_FlushD, hazard_FlushE;
  assign hazard_Rs1D = IF_ID.Instr[19:15]; // rs1 in ID stage
  assign hazard_Rs2D = IF_ID.Instr[24:20]; // rs2 in ID stage
  assign hazard_Rs1E = ID_EX.Rs1;          // rs1 in EX stage
  assign hazard_Rs2E = ID_EX.Rs2;          // rs2 in EX stage
  assign hazard_RdE = ID_EX.Rd;            // rd in EX stage
  assign hazard_RdM = EX_MEM.Rd;           // rd in MEM stage
  assign hazard_RdW = MEM_WB.Rd;           // rd in WB stage
  assign hazard_PcSrc = PCSrcE;
  assign hazard_ResultSrcE = ID_EX.ResultSrc;
  assign hazard_RegWriteM = EX_MEM.RegWrite;
  assign hazard_RegWriteW = MEM_WB.RegWrite;
  hazard_unit hazard (hazard_Rs1D, hazard_Rs2D, hazard_Rs1E, hazard_Rs2E, 
                      hazard_RdE, hazard_RdM, hazard_RdW,
                      hazard_PcSrc, hazard_ResultSrcE, 
                      hazard_RegWriteM, hazard_RegWriteW,
                      hazard_ForwardAE, hazard_ForwardBE,
                      hazard_StallF, hazard_StallD, 
                      hazard_FlushD, hazard_FlushE);
  logic [1:0] ForwardAE, ForwardBE; // forwarding signals for Rs1 and Rs2
  assign ForwardAE = hazard_ForwardAE; assign ForwardBE = hazard_ForwardBE;
  logic StallF, StallD, FlushD, FlushE; // stall and flush signals
  assign StallF = hazard_StallF; assign StallD = hazard_StallD;
  assign FlushD = hazard_FlushD; assign FlushE = hazard_FlushE;
  assign PCJalr = {alu_result[31:1], 1'b0};


/* ---------------------------------------------------------------------------- */

  // global signals
  logic [1:0] PCSrcE;     // PCSrc for IF/EX stage
  logic [31:0] PCTargetE; // target address for branch/jump instructions
  logic [31:0] ResultW;   // result to write back to register file or to jump to
  logic [31:0] PCJalr;    // JALR target address


/* ---------------------------------------------------------------------------- */

  // local signals for IF logic
  logic [31:0] PCNext;

  // IF logic
  always_ff @(posedge clk, posedge reset) begin
    if(reset)
      PCCurrent <= 32'b0;  // reset PC to 0 on reset
    else
      PCCurrent <= PCNext; // update PC with next value
  end

  always_comb begin
    if (StallF) begin
      PCNext = PCCurrent;  // hold PC on stall
    end
    else begin
      case(PCSrcE)
        2'b00:   PCNext = PCCurrent + 4; // next instruction
        2'b01:   PCNext = PCTargetE;     // branch or jump target
        2'b10:   PCNext = alu_result;    // JALR target address
        default: PCNext = PCCurrent + 4; // default to next instruction
      endcase
    end
  end

  assign IF_ID_next.PC = PCCurrent;
  assign IF_ID_next.Instr = InstrImem;
  assign IF_ID_next.PCPlus4 = PCCurrent + 4;


/* ---------------------------------------------------------------------------- */

  // local signals for ID logic 
  logic [4:0] rd_d;
  logic [31:0] PC_localID;
  logic [31:0] PCPlus4_localID;
  logic [31:0] ReadData1_localID, ReadData2_localID;

  assign rd_d = IF_ID.Instr[11:7];  // rd
  assign op = IF_ID.Instr[6:0];
  assign funct3 = IF_ID.Instr[14:12];
  assign funct7b5 = IF_ID.Instr[30];
  assign imm_src = IF_ID.Instr;

  assign rf_we = MEM_WB.RegWrite;
  assign rf_read_addr1 = IF_ID.Instr[19:15]; // rs1
  assign rf_read_addr2 = IF_ID.Instr[24:20]; // rs2
  assign rf_write_addr = MEM_WB.Rd;
  assign rf_write_data = ResultW;
  assign PC_localID = IF_ID.PC;
  assign PCPlus4_localID = IF_ID.PCPlus4;
  assign ReadData1_localID = (MEM_WB.Rd == rf_read_addr1 & MEM_WB.RegWrite & rf_read_addr1 != 0) ? ResultW :
                             rf_read_data1; // Forwarding from WB stage
  assign ReadData2_localID = (MEM_WB.Rd == rf_read_addr2 & MEM_WB.RegWrite & rf_read_addr2 != 0) ? ResultW :
                             rf_read_data2; // Forwarding from WB stage

  // ID-EX logic
  always_comb begin
    ID_EX_next.ResultSrc = resultsrc;
    ID_EX_next.MemWrite = memwrite;
    ID_EX_next.Branch = branch;
    ID_EX_next.ALUSrc = alusrc;
    ID_EX_next.RegWrite = regwrite;
    ID_EX_next.Jump = jump;
    ID_EX_next.ALUControl = alucontrol;
    ID_EX_next.ImmExt = imm_extended;
    ID_EX_next.Rs1 = rf_read_addr1;
    ID_EX_next.Rs2 = rf_read_addr2;
    ID_EX_next.RD1 = ReadData1_localID;
    ID_EX_next.RD2 = ReadData2_localID;
    ID_EX_next.Rd = rd_d;
    ID_EX_next.PC = PC_localID; 
    ID_EX_next.PCPlus4 = PCPlus4_localID;
    ID_EX_next.op = op;
    ID_EX_next.funct3 = funct3;
  end


/* ---------------------------------------------------------------------------- */

  // forwarding logic
  logic [31:0] ForwardedA, ForwardedB, SrcB, StoreData;
  assign ForwardedA = ForwardAE[1] ? ResultW :
                      ForwardAE[0] ? EX_MEM.ALUResult :
                      ID_EX.RD1;
  assign ForwardedB = ForwardBE[1] ? ResultW :
                      ForwardBE[0] ? EX_MEM.ALUResult :
                      ID_EX.RD2;

  assign SrcB = ID_EX.ALUSrc ? ID_EX.ImmExt : ForwardedB; //ALU SrcB
  assign alu_src_a = ForwardedA;
  assign alu_src_b = SrcB;
  assign alu_itype = (ID_EX.op == 7'b0010011);  // 1 if I-type instruction
  assign alu_alucontrol = ID_EX.ALUControl;

  assign adder_src_a = ID_EX.PC;
  assign adder_src_b = ID_EX.ImmExt;
  assign PCTargetE = adder_output;

  // next PC (PCSrc) logic
  assign PCSrcE = (ID_EX.op == 7'b1100111) ? 2'b10 : // jalr
                  (ID_EX.Branch)           ? {1'b0, ( // branches
                                                      ((ID_EX.funct3 == 3'b000) && alu_zero) |                    //beq
                                                      ((ID_EX.funct3 == 3'b001) && !alu_zero) |                   //bne
                                                      ((ID_EX.funct3 == 3'b100) && (alu_sign ^ alu_overflow)) |   //blt
                                                      ((ID_EX.funct3 == 3'b101) && !(alu_sign ^ alu_overflow)) |  //bge
                                                      ((ID_EX.funct3 == 3'b110) && !alu_carry) |                  //bltu
                                                      ((ID_EX.funct3 == 3'b111) && alu_carry)                     //bgeu
                                                    )} :
                  (ID_EX.Jump)             ? 2'b01 :                                                              // jal
                                             2'b00;                                                               // next instruction

  // memory store logic
  assign StoreData = (ID_EX.funct3 == 3'b000) ? {24'b0, ForwardedB[7:0]} :    // sb
                     (ID_EX.funct3 == 3'b001) ? {16'b0, ForwardedB[15:0]} :   // sh
                                                ForwardedB;                   // sw

  // local signals for EX logic 
  logic RegWrite_localEX;
  logic [1:0] ResultSrc_localEX;
  logic MemWrite_localEX;
  logic [31:0] ALUResult_localEX;
  logic [31:0] PCPlus4_localEX;
  logic [2:0] funct3_localEX;
  logic [31:0] ImmExt_localEX;
  logic [6:0] op_localEX;
  logic [4:0] Rd_localEX;

  assign RegWrite_localEX = ID_EX.RegWrite;
  assign ResultSrc_localEX = ID_EX.ResultSrc;
  assign MemWrite_localEX = ID_EX.MemWrite;
  assign ALUResult_localEX = (ID_EX.op == 7'b0110111) ? ImmExt_localEX : // lui
                             (ID_EX.op == 7'b0010111) ? PCTargetE :      // auipc
                             (ID_EX.op == 7'b1101111) ? PCTargetE :      // jal
                             (ID_EX.op == 7'b1100111) ? PCJalr :         // jalr
                             alu_result;                                 // alu_result for all other instructions
  assign Rd_localEX = ID_EX.Rd;
  assign PCPlus4_localEX = ID_EX.PCPlus4;
  assign op_localEX = ID_EX.op;
  assign funct3_localEX = ID_EX.funct3;
  assign ImmExt_localEX = ID_EX.ImmExt;

  // EX-ID logic
  always_comb begin
    EX_MEM_next.RegWrite = RegWrite_localEX;  
    EX_MEM_next.ResultSrc = ResultSrc_localEX ; 
    EX_MEM_next.MemWrite = MemWrite_localEX;   
    EX_MEM_next.ALUResult = ALUResult_localEX;
    EX_MEM_next.WriteData = StoreData;
    EX_MEM_next.Rd = Rd_localEX;  
    EX_MEM_next.PCPlus4 = PCPlus4_localEX;    
    EX_MEM_next.op = op_localEX;  
    EX_MEM_next.funct3 = funct3_localEX;  
    EX_MEM_next.ImmExt = ImmExt_localEX;  
    EX_MEM_next.PCTarget = PCTargetE;
  end


/* ---------------------------------------------------------------------------- */

  // store logic (Byte Enabler)
  logic [3:0]  ByteEnabler;
  assign ByteEnabler = (EX_MEM.MemWrite) ?
                       ((EX_MEM.funct3 == 3'b010) ? 4'b1111 : // sw
                       (EX_MEM.funct3 == 3'b001 && EX_MEM.ALUResult[0] == 1'b0) ? (4'b0011 << (EX_MEM.ALUResult[1] * 2)) : // sh
                       (EX_MEM.funct3 == 3'b000) ? (4'b0001 << EX_MEM.ALUResult[1:0]) : // sb
                       4'b0000):
                       4'bxxxx;

  // load logic
  logic [7:0]  ByteFromMem;
  assign ByteFromMem = (EX_MEM.ALUResult[1:0] == 2'b00) ? dmem_rd[7:0] :
                       (EX_MEM.ALUResult[1:0] == 2'b01) ? dmem_rd[15:8] :
                       (EX_MEM.ALUResult[1:0] == 2'b10) ? dmem_rd[23:16] :
                       dmem_rd[31:24];

  logic [15:0] HalfwordFromMem;
  assign HalfwordFromMem = (EX_MEM.ALUResult[1:0] == 2'b00) ? dmem_rd[15:0]  :
                           (EX_MEM.ALUResult[1:0] == 2'b10) ? dmem_rd[31:16] :
                           15'bx;

  logic [31:0] LoadData;
  assign LoadData = (EX_MEM.funct3 == 3'b010) ? dmem_rd :                                       // lw
                    (EX_MEM.funct3 == 3'b000) ? {{24{ByteFromMem[7]}}, ByteFromMem} :           // lb
                    (EX_MEM.funct3 == 3'b001) ? {{16{HalfwordFromMem[15]}}, HalfwordFromMem} :  // lh
                    (EX_MEM.funct3 == 3'b100) ? {{24{1'b0}}, ByteFromMem} :                     // lbu
                    (EX_MEM.funct3 == 3'b101) ? {{16{1'b0}}, HalfwordFromMem} :                 // lhu
                    dmem_rd;

  // MEM-WB logic
  logic        RegWrite_localMEM;
  logic [1:0]  ResultSrc_localMEM;
  logic [31:0] ALUResult_localMEM;
  logic [4:0]  Rd_localMEM;
  logic [31:0] PCPlus4_localMEM;
  logic [31:0] ImmExt_localMEM;
  logic [31:0] PCTarget_localMEM;

  assign RegWrite_localMEM = EX_MEM.RegWrite;
  assign ResultSrc_localMEM = EX_MEM.ResultSrc;
  assign ALUResult_localMEM = EX_MEM.ALUResult;
  assign Rd_localMEM = EX_MEM.Rd;
  assign PCPlus4_localMEM = EX_MEM.PCPlus4;
  assign ImmExt_localMEM = EX_MEM.ImmExt;
  assign PCTarget_localMEM = EX_MEM.PCTarget;

  assign dmem_we = EX_MEM.MemWrite;
  assign dmem_addr = EX_MEM.ALUResult;
  assign dmem_wd = EX_MEM.WriteData;
  assign dmem_byte_enabler = ByteEnabler;

  always_comb begin
      MEM_WB_next.RegWrite = RegWrite_localMEM;
      MEM_WB_next.ResultSrc = ResultSrc_localMEM;
      MEM_WB_next.ALUResult = ALUResult_localMEM;
      MEM_WB_next.ReadData = LoadData;
      MEM_WB_next.Rd = Rd_localMEM;
      MEM_WB_next.PCPlus4 = PCPlus4_localMEM;
      MEM_WB_next.ImmExt = ImmExt_localMEM;
      MEM_WB_next.PCTarget = PCTarget_localMEM;
  end


/* ---------------------------------------------------------------------------- */

  // WB logic
  assign ResultW = (MEM_WB.ResultSrc == 3'b00) ? MEM_WB.ALUResult :
                   (MEM_WB.ResultSrc == 3'b01) ? MEM_WB.ReadData :
                   (MEM_WB.ResultSrc == 3'b10) ? MEM_WB.PCPlus4 :
                   32'bx;

endmodule


/* ---------------------------------------------------------------------------- */
// modules

module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic       MemWrite,
               output logic       Branch, ALUSrc,
               output logic       RegWrite, Jump,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

  logic [11:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump} = controls;

  always_comb
    case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
      7'b0000011: controls = 12'b1_000_1_0_01_0_00_0; // lw
      7'b0100011: controls = 12'b0_001_1_1_00_0_00_0; // sw
      7'b0110011: controls = 12'b1_xxx_0_0_00_0_10_0; // R-type 
      7'b1100011: controls = 12'b0_010_0_0_00_1_01_0; // branches
      7'b0010011: controls = 12'b1_000_1_0_00_0_10_0; // I-type ALU
      7'b1101111: controls = 12'b1_011_0_0_10_0_00_1; // jal
      7'b0110111: controls = 12'b1_100_1_0_00_0_10_0; // lui
      7'b0010111: controls = 12'b1_100_1_0_00_0_10_0; // auipc
      7'b1100111: controls = 12'b1_000_1_0_00_0_10_1; // jalr
      7'b0000000: controls = 12'b0_000_0_0_00_0_00_0; // jalr
      default:    controls = 12'bx_xx_x_x_xx_x_xx_x;  // non-implemented instruction
    endcase
endmodule

module aludec(input  logic [6:0] op,
              input  logic [2:0] funct3,
              input  logic       funct7b5, 
              input  logic [1:0] ALUOp,
              output logic [3:0] ALUControl);

  logic  RtypeSub;
  assign RtypeSub = funct7b5 & op[5] ;  // true for R-type subtract instruction

  always_comb
    case(ALUOp)
      2'b00:                ALUControl = 4'b0000; // addition
      2'b01:                ALUControl = 4'b0001; // subtraction
      default: case(funct3) // R-type or I-type ALU
                 3'b000:  if (RtypeSub) 
                            ALUControl = 4'b0001;    // sub
                          else          
                            ALUControl = 4'b0000;    // add, addi
                 3'b001:    ALUControl = 4'b0110;    // sll, slli
                 3'b010:    ALUControl = 4'b0101;    // slt, slti
                 3'b011:    ALUControl = 4'b1000;    // sltu, sltiu
                 3'b100:    ALUControl = 4'b0100;    // xor, xori
                 3'b101:    if (funct7b5)
                              ALUControl = 4'b1001;  // sra, srai
                            else
                               ALUControl = 4'b0111; // srl, srli,
                 3'b110:    ALUControl = 4'b0011;    // or, ori
                 3'b111:    ALUControl = 4'b0010;    // and, andi
                 default:   ALUControl = 4'bxxxx;    // undefined
               endcase
    endcase
endmodule

module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [4:0]  a1, a2, a3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[31:0];

  always_ff @(negedge clk)
    if (we3 && a3 != 5'b0) rf[a3] <= wd3;	

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule

module adder(input  [31:0] a, b,
             output [31:0] y);

  assign y = a + b;
endmodule

module extend(input  logic [31:0] instr,
              input  logic [2:0]  immsrc,
              output logic [31:0] immext);

  logic        sign_bit;
    logic [11:0] i_imm;
    logic [6:0]  s_imm_1;
    logic [4:0]  s_imm_0;
    logic        b_imm_12;
    logic        b_imm_11;
    logic [5:0]  b_imm_10_5;
    logic [3:0]  b_imm_4_1;
    logic        j_imm_20;
    logic [7:0]  j_imm_19_12;
    logic        j_imm_11;
    logic [9:0]  j_imm_10_1;
    logic [19:0] u_imm;

    assign sign_bit    = instr[31];
    assign i_imm       = instr[31:20];
    assign s_imm_1     = instr[31:25];
    assign s_imm_0     = instr[11:7];
    assign b_imm_12    = instr[31];
    assign b_imm_11    = instr[7];
    assign b_imm_10_5  = instr[30:25];
    assign b_imm_4_1   = instr[11:8];
    assign j_imm_20    = instr[31];
    assign j_imm_19_12 = instr[19:12];
    assign j_imm_11    = instr[20];
    assign j_imm_10_1  = instr[30:21];
    assign u_imm       = instr[31:12];

    always_comb begin
        case(immsrc)
                // I-type
            3'b000: immext = {{20{sign_bit}}, i_imm};
                // S-type (stores)
            3'b001: immext = {{20{sign_bit}}, s_imm_1, s_imm_0};
                // B-type (branches)
            3'b010: immext = {{20{sign_bit}}, b_imm_12, b_imm_11, b_imm_10_5, b_imm_4_1, 1'b0};
                // J-type (jal)
            3'b011: immext = {{12{sign_bit}}, j_imm_20, j_imm_19_12, j_imm_11, j_imm_10_1, 1'b0};
                // U-type (lui)
            3'b100: immext = {u_imm, 12'b0};
            default: immext = 32'bx; // undefined
        endcase
    end

endmodule

module imem(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[127:0];

  initial
      $readmemh("machinecode.txt", RAM);

  assign rd = RAM[a[31:2]]; // word aligned
endmodule

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            input  logic [3:0]  bwe,        //byte write enable
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  always_ff @(posedge clk)
    if (we) begin
      if (bwe[0]) RAM[a[31:2]][7:0]   <= wd[7:0];   // byte 0
      if (bwe[1]) RAM[a[31:2]][15:8]  <= wd[15:8];  // byte 1
      if (bwe[2]) RAM[a[31:2]][23:16] <= wd[23:16]; // byte 2
      if (bwe[3]) RAM[a[31:2]][31:24] <= wd[31:24]; // byte 3
    end 
    
  assign rd = RAM[a[31:2]]; // word aligned
endmodule

module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           input  logic        iType,
           output logic [31:0] result,
           output logic        zero,
           output logic        sign,
           output logic        oveflow,
           output logic        carry);

  logic [31:0] condinvb, sum;
  logic        isAddSub;
  logic        sign_sum;
  logic [4:0]  left_shift_amount; 
  logic [4:0]  right_shift_amount;

  assign condinvb = alucontrol[0] ? ~b : b;
  assign sum = a + condinvb + alucontrol[0];
  assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
                    ~alucontrol[1] & alucontrol[0];
  assign sign_sum = sum[31];
  assign left_shift_amount = b[4:0];
  assign right_shift_amount = b[4:0];


  always_comb
    case (alucontrol)
      4'b0000:
        if(iType) 
          result = a + b;                                   // addi
        else
          result = sum;                                     // add
      4'b0001:  result = sum;                               // subtract
      4'b0010:  result = a & b;                             // and
      4'b0011:  result = a | b;                             // or
      4'b0100:  result = a ^ b;                             // xor
      4'b0101:  result = sign_sum ^ oveflow;                // slt
      4'b0110:  result = a << left_shift_amount;            // sll
      4'b0111:  result = a >> right_shift_amount;           // srl
      4'b1000:  result = {{31{1'b0}}, (a < b)};             // sltu
      4'b1001:  result = $signed(a) >>> right_shift_amount; // sra
      default: result = 32'bx;
    endcase

  assign zero = (result == 32'b0);
  assign sign = result[31];
  assign oveflow = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
  logic [32:0] extended_sum;
  assign extended_sum = {1'b0, a} + {1'b0, condinvb} + alucontrol[0];
  assign carry = extended_sum[32] & isAddSub;
endmodule

module hazard_unit (input [4:0]  Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,    
                    input [1:0]  PcSrc,
                    input [1:0]  ResultSrcE,
                    input        RegWriteM, RegWriteW,
                    output logic [1:0] ForwardAE, ForwardBE,
                    output logic       StallF, StallD, FlushD, FlushE);

  always_comb begin
    // forwarding logic for Rs1E
    if ((Rs1E == RdM) & RegWriteM & (Rs1E != 0))
      ForwardAE = 2'b01;
    else if ((Rs1E == RdW) & RegWriteW & (Rs1E != 0))
      ForwardAE = 2'b10;
    else
      ForwardAE = 2'b00;

    // forwarding logic for Rs2E
    if ((Rs2E == RdM) & RegWriteM & (Rs2E != 0))
      ForwardBE = 2'b01;
    else if ((Rs2E == RdW) & RegWriteW & (Rs2E != 0))
      ForwardBE = 2'b10;
    else
      ForwardBE = 2'b00;

    // stall and flush logic
    StallF = ((Rs1D == RdE) | (Rs2D == RdE)) & (ResultSrcE == 2'b01); // lw hazard
    StallD = StallF;

    FlushE = StallF |  (PcSrc != 2'b00);
    FlushD = (PcSrc != 2'b00);
  end

endmodule