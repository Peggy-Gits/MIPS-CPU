module CPU_fw
 (input           clk, reset,
  input   [31:0]  instr, ReadDataM,
  output  [31:0]  PCF,
  output          MemWriteM,
  output  [31:0]  ALUoutM, WriteDataM);
 
 logic forwardAD,forwardBD, forwardAD2, forwardBD2;
 logic [1:0] forwardAE, forwardBE;
 logic StallF, StallD, flushD,flushE; 
 logic RegWriteD, RegWriteE, RegWriteM, RegWriteW; 
 logic pcsrc, BranchD, BranchE, BranchM;
 logic MemtoRegD, MemtoRegE, MemtoRegM, MemtoRegW;
 logic MemWriteD;
 logic ALU_srcD, ALU_srcE;
 logic RegDstD, RegDstE;
 logic zero, zeroM, flag;
 logic [1:0] ALUop;
 logic [2:0] ALU_ctrlD, ALU_ctrlE;
 logic [31:0]PC_val, nextPC, nextPCD, /*nextPCE,*/ PCBranchD; //PCBranchE,PCBranchM;
 logic [4:0]WriteRegM, WriteRegE, WriteRegW; 
 logic [4:0]RsD,RsE,RdD,RdE, RtD, RtE;
 logic [5:0]op, funct;
 logic [31:0] instrD, signImmD, signImmE,signImmsh;
 logic [31:0] WriteDataD, WriteDataD2, WriteDataE,WriteDataE2;
 logic [31:0] srcAD, srcAD2, srcAE, srcAE2, srcCD, srcCE, srcBE;
 logic [31:0] compAD, compBD;
 logic [31:0] ALUoutE, ALUoutW;
 logic [31:0] ResultW, ReadDataW;

   always_ff @(instr) $display("pcsrc=%h", pcsrc);
   always_ff @(nextPC) $display("pcnext: %h", PC_val);
   always_ff @(PCF) $display("current pc: %h", PCF);
  //Fetch
  flopr #(32) pcreg(.en(StallF), .clk(clk), .reset(reset), .d(PC_val), .q(PCF));
  adder       pcadd1(.a(PCF), .b(32'b100), .y(nextPC));
  mux2 #(32) pcmux(.d0(nextPC), .d1(PCBranchD), .s(pcsrc), .y(PC_val));
  
  IF_ID2 if_id(.clk(clk), .reset(flushD), .en(StallD), .instr(instr), .nextPC(PC_val), 
  	.instrD(instrD), .nextPCD(nextPCD));
  //Decode 
  maindec ctrl(.op(op), .regwrite(RegWriteD), .memtoreg(MemtoRegD), .memwrite(MemWriteD), .branch(BranchD),
             .alusrc(ALUsrcD), .regdst(RegDstD), .jump(JumpD), .aluop(ALUop));
  aludec2  adec(.flag(flag),.funct(funct), .aluop(ALUop), .alucontrol(ALU_ctrlD));  
  assign RsD[4:0]=instrD[25:21];
  assign RtD[4:0]=instrD[20:16];
  assign RdD[4:0]=instrD[15:11];
  assign op[5:0] = instrD[31:26];
  assign funct[5:0] = instrD[5:0];
  assign flag = instrD[6]; 
  signext  sign_next(.a(instrD[15:0]), .y(signImmD));
  regfile2  reg_file(.clk(clk),.we3(RegWriteW),.ra1(RsD), .ra2(instrD[20:16]), .ra3(instrD[15:11]), .wa3(WriteRegW), .wd3(ResultW),
  	.rd1(srcAD), .rd2(WriteDataD), .rd3(srcCD)); 
  mux2 #(32) fwmuxD1(.d0(srcAD),.d1(ALUoutM),.s(forwardAD),.y(compAD));
  mux2 #(32) fwmuxD2(.d0(WriteDataD), .d1(ALUoutM), .s(forwardBD), .y(compBD));
  //extra forward for WB stage
  mux2 #(32) fwmuxD3(.d0(srcAD),.d1(ResultW),.s(forwardAD2),.y(srcAD2)); 
  mux2 #(32) fwmuxD4(.d0(WriteDataD),.d1(ResultW),.s(forwardBD2),.y(WriteDataD2));
  //
  sl2  immsh(.a(signImmD), .y(signImmsh));
  adder  pcadd2(.a(nextPCD), .b(signImmsh), .y(PCBranchD));
  assign pcsrc = BranchD & (compAD==compBD);
  assign flushD=reset|pcsrc;
  ID_EX2 id_ex(.clk(clk), .reset(reset),.flushE(flushE), .RegWriteD(RegWriteD), .MemtoRegD(MemtoRegD), .MemWriteD(MemWriteD), 
  	/*.BranchD(BranchD),*/.ALUsrcD(ALUsrcD), .RegDstD(RegDstD),.ALU_ctrlD(ALU_ctrlD),.RtD(RtD), .RsD(RsD), .RdD(RdD),
	.srcAD(srcAD2), .srcCD(srcCD),.signImmD(signImmD), .WriteDataD(WriteDataD2),
	.RegWriteE(RegWriteE), .MemtoRegE(MemtoRegE), .MemWriteE(MemWriteE), /*.BranchE(BranchE),*/ .ALUsrcE(ALUsrcE), .RegDstE(RegDstE),
  	.ALU_ctrlE(ALU_ctrlE), .RtE(RtE), .RdE(RdE), .RsE(RsE), .signImmE(signImmE), .srcAE(srcAE),.srcCE(srcCE), .WriteDataE(WriteDataE));
  //Execute
  mux2 #(32)  ALUsrcmux(.d0(WriteDataE2), .d1(signImmE), .s(ALUsrcE), .y(srcBE));		
  ALU2  alu(.clk(clk), .reset(reset), .stall(StallF), .a(srcAE2), .b(srcBE), .c(srcCE), .control(ALU_ctrlE), .result(ALUoutE), .zero(zero));
  
  mux3 #(32) fwmuxE1(.d0(srcAE), .d1(ResultW), .d2(ALUoutM), .s(forwardAE), .y(srcAE2));
  mux3 #(32) fwmuxE2(.d0(WriteDataE), .d1(ResultW), .d2(ALUoutM), .s(forwardBE), .y(WriteDataE2));
  
  mux2 #(5)   regmux(.d0(RtE), .d1(RdE), .s(RegDstE), .y(WriteRegE)); 

  EX_MEM2 ex_mem (.clk(clk),.reset(reset), .RegWriteE(RegWriteE), .MemtoRegE(MemtoRegE), .MemWriteE(MemWriteE), /*.BranchE(BranchE),*/
  .zero(zero), .ALUoutE(ALUoutE), .WriteDataE(WriteDataE2), .WriteRegE(WriteRegE),
  .RegWriteM(RegWriteM), .MemtoRegM(MemtoRegM), .MemWriteM(MemWriteM), /*.BranchM(BranchM),*/.zeroM(zeroM), 
  .ALUoutM(ALUoutM), .WriteDataM(WriteDataM), .WriteRegM(WriteRegM));
  //Memory
  

  MEM_WB2 mem_wb(.clk(clk), .reset(reset),.RegWriteM(RegWriteM), .MemtoRegM(MemtoRegM),.ALUoutM(ALUoutM), .ReadDataM(ReadDataM),
  .WriteRegM(WriteRegM), .RegWriteW(RegWriteW), .MemtoRegW(MemtoRegW), .ALUoutW(ALUoutW), .ReadDataW(ReadDataW),
  .WriteRegW(WriteRegW));
  //WriteBack	
  mux2 #(32)  resmux(.d0(ALUoutW), .d1(ReadDataW), .s(MemtoRegW), .y(ResultW));
   
  hazard_ctrl hazard(.RegWriteW(RegWriteW), .RegWriteM(RegWriteM), .RegWriteE(RegWriteE), 
   .MemtoRegE(MemtoRegE), .MemtoRegM(MemtoRegM), .BranchD(BranchD), .WriteRegM(WriteRegM), 
   .WriteRegE(WriteRegE), .WriteRegW(WriteRegW), .RsD(RsD), .RtD(RtD), .RsE(RsE), .RdE(RdE), 
   .RtE(RtE), .forwardAD(forwardAD), .forwardBD(forwardBD), .forwardAD2(forwardAD2), .forwardBD2(forwardBD2), .forwardAE(forwardAE), .forwardBE(forwardBE), .StallD(StallD),
   .StallF(StallF), .FlushE(flushE));

endmodule

module IF_ID2
 (input logic clk, reset, en,
  input logic [31:0] instr, nextPC,
  output logic [31:0] instrD, nextPCD 
 );
 always_ff @(posedge clk) begin
     if(reset==1'b1)begin
	instrD <= '0;
        nextPCD <= '0; 
     end
     else begin
	if(en==1'b1)begin
          $display ("StallD");
        end
	else begin
	  instrD <= instr;
          nextPCD <= nextPC; 
        end
     end
 end
endmodule

module ID_EX2
 (input logic clk, reset,
  input logic flushE, RegWriteD, MemtoRegD, MemWriteD, /*BranchD,*/ALUsrcD, RegDstD,
  input logic [2:0] ALU_ctrlD,
  input logic [4:0] RtD, RsD, RdD,
  input logic [31:0] srcAD, srcCD, signImmD, WriteDataD,
  output logic RegWriteE, MemtoRegE, MemWriteE, /*BranchE,*/ ALUsrcE, RegDstE,
  output logic [2:0] ALU_ctrlE,
  output logic [4:0] RtE, RdE, RsE,
  output logic [31:0] signImmE, srcAE, srcCE, WriteDataE
 );
 always_ff @(posedge clk) begin
    if(flushE==1'b1|reset==1'b1)begin
	{RegWriteE, MemtoRegE, MemWriteE,/*BranchE,*/ALU_ctrlE} <= '0;
	{ALUsrcE, RegDstE, srcAE, WriteDataE, RsE, RtE, RdE} <= '0;
	{signImmE/*, nextPCE*/, srcCE}<= '0;
    end
    else begin
	RegWriteE <= RegWriteD;
	MemtoRegE <= MemtoRegD;
	MemWriteE <= MemWriteD;
	//BranchE <= BranchE;
	ALU_ctrlE <= ALU_ctrlD;
	ALUsrcE <= ALUsrcD;
	RegDstE <= RegDstD;
	srcAE<= srcAD;
	srcCE<= srcCD;
	WriteDataE <= WriteDataD;
	RsE<= RsD;
	RtE <= RtD;
	RdE <= RdD;
	signImmE <= signImmD;
	/*nextPCE <= nextPCD;*/
    end
 end
endmodule

module EX_MEM2
 (input logic clk, reset,
  input logic RegWriteE, MemtoRegE, MemWriteE, //BranchE,
  input logic zero, 
  input logic [31:0] ALUoutE, WriteDataE, 
  input logic [4:0] WriteRegE, 
  output logic RegWriteM, MemtoRegM, MemWriteM, //BranchM,
  output logic zeroM, 
  output logic [31:0] ALUoutM, WriteDataM, 
  output logic [4:0] WriteRegM);
  always_ff @(posedge clk) begin
 	if(reset==1'b1)begin
	RegWriteM<='0;
	MemtoRegM<='0;
	MemWriteM<='0;
	//BranchM<='0;
	zeroM<='0;
	ALUoutM<='0;
	WriteDataM<='0;
	WriteRegM<='0;
	end
	else begin
	RegWriteM<=RegWriteE;
	MemtoRegM<=MemtoRegE;
	MemWriteM<=MemWriteE;
	//BranchM<=BranchE;
	zeroM<=zero;
	ALUoutM<=ALUoutE;
	WriteDataM<=WriteDataE;
	WriteRegM<=WriteRegE;
   	end
      end
endmodule

module MEM_WB2
 (input logic clk, reset,
  input logic RegWriteM,
  input logic MemtoRegM,
  input logic [31:0] ALUoutM, ReadDataM,
  input logic [4:0] WriteRegM,
  output logic RegWriteW,
  output logic MemtoRegW,
  output logic [31:0] ALUoutW, ReadDataW,
  output logic [4:0] WriteRegW);
 always_ff @(posedge clk)
	begin
	  if(reset==1'b1)begin
	   RegWriteW<='0;
	   MemtoRegW<='0;
	   ALUoutW<='0;
	   ReadDataW<='0;
	   WriteRegW<='0;
	  end
	  else begin
           RegWriteW<=RegWriteM;
	   MemtoRegW<=MemtoRegM;
	   ALUoutW<=ALUoutM;
	   ReadDataW<=ReadDataM;
	   WriteRegW<=WriteRegM;
	  end
	end
endmodule





