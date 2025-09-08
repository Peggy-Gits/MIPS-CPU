module aludec (
    input [5:0] funct,
    input [1:0] aluop,
    output reg [2:0] alucontrol
);
    always_comb begin
        case (aluop)
            2'b00: alucontrol <= 3'b010; // add
            2'b01: alucontrol <= 3'b110; // sub
            default: case(funct) // RTYPE
                6'b100000: alucontrol <= 3'b010; // ADD
                6'b100010: alucontrol <= 3'b110; // SUB
                6'b100100: alucontrol <= 3'b000; // AND
                6'b100101: alucontrol <= 3'b001; // OR
                6'b101010: alucontrol <= 3'b111; // SLT
		6'b100001: alucontrol <= 3'b101; //MULADD
                default: alucontrol <= 3'bxxx; // ???
            endcase
        endcase
    end
endmodule

//decoder for MULADD and perform

module aludec2 (
    input flag,
    input [5:0] funct,
    input [1:0] aluop,
    output reg [2:0] alucontrol
);
    always_comb begin
        case (aluop)
            2'b00: alucontrol <= 3'b010; // add
            2'b01: alucontrol <= 3'b110; // sub
            default: case(funct) // RTYPE
                6'b100000: alucontrol <= 3'b010; // ADD
                6'b100010: alucontrol <= 3'b110; // SUB
                6'b100100: alucontrol <= 3'b000; // AND
                6'b100101: alucontrol <= 3'b001; // OR
                6'b101010: alucontrol <= 3'b111; // SLT
		6'b100011: alucontrol <= 3'b101; //MULADD
		6'b100111: begin		 //perform
		   if(flag==1'b1) alucontrol <= 3'b100;
 		   else alucontrol <= 3'b011;
		end
                default: alucontrol <= 3'bxxx; // ???
            endcase
        endcase
    end
endmodule
//ALU
module ALU(
    input [31:0] a,          // First operand
    input [31:0] b,          // Second operand
    input [2:0] control,     // ALU control signal
    output reg [31:0] result, // ALU result
    output zero              // Zero flag
);

    // Define ALU operations based on control signal
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    
    // Calculate result based on control input
    always @(*) begin
        case(control)
            ALU_AND: result = a & b;                     // AND
            ALU_OR:  result = a | b;                     // OR
            ALU_ADD: result = a + b;                     // ADD
            ALU_SUB: result = a - b;                     // SUB
            ALU_SLT: result = ($signed(a) < $signed(b)); // Set Less Than (signed)
            default: result = 32'bx;                     // Undefined operation
        endcase
    end
    
    // Set zero flag when result is 0
    assign zero = (result == 32'b0);
    
endmodule

//ALU supporting MULADD and performance

module ALU2#(parameter WIDTH = 32)(
    input logic clk, reset, stall,
    input logic[31:0] a,          // First operand
    input logic[31:0] b,          // Second operand
    input logic[31:0] c,	  // Third operand for MULLADD
    input logic[2:0] control,     // ALU control signal
    output logic [31:0] result, // ALU result
    output logic zero              // Zero flag
);
    logic [WIDTH - 1:0] instr_cnt, clk_cnt;
    // Define ALU operations based on control signal
    localparam ALU_AND = 3'b000;
    localparam ALU_OR  = 3'b001;
    localparam ALU_ADD = 3'b010;
    localparam ALU_SUB = 3'b110;
    localparam ALU_SLT = 3'b111;
    localparam ALU_MULADD = 3'b101;
    //performance measure
    localparam CLK = 3'b011;
    localparam INSTR = 3'b100;     

    // Calculate result based on control input
    always @(*) begin
        case(control)
            ALU_AND: result = a & b;                     // AND
            ALU_OR:  result = a | b;                     // OR
            ALU_ADD: result = a + b;                     // ADD
            ALU_SUB: result = a - b;                     // SUB
            ALU_SLT: result = ($signed(a) < $signed(b)); // Set Less Than (signed)
	    ALU_MULADD: begin 
		result = b * c + a;	
		$display("MULLADD: b(%d) * c(%d) + a(%d)", b,c,a);	
	    end // MULADD
	    CLK: begin
		result = clk_cnt;
		$display("clk_cnt: %d", clk_cnt);
	    end
	    INSTR: begin 
		result = instr_cnt;
	        $display("instr_cnt: %d", instr_cnt);
	    end 
            default: result = 32'bx;                     // Undefined operation
        endcase
    end
    
    // Set zero flag when result is 0
    assign zero = (result == 32'b0);
    perform #(WIDTH) perform_cnt(.clk(clk), .reset(reset),.stall(stall),
    .instr_cnt(instr_cnt), .clk_cnt(clk_cnt));
endmodule
//ADDER
module adder (
    input [31:0] a, b,
    output [31:0] y
);
    assign y = a + b;
endmodule

//Decoder

module maindec(
    input [5:0] op,
    output memtoreg, memwrite,
    output branch, alusrc,
    output regdst, regwrite,
    output jump,
    output [1:0] aluop
);

    reg [8:0] controls;
    
    assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop} = controls;

    always_comb begin
        case(op)
            6'b000000: controls <= 9'b110000010; //Rtyp, perform and MULADD are Rtype.
            6'b100011: controls <= 9'b101001000; //LW
            6'b101011: controls <= 9'b001010000; //SW
            6'b000100: controls <= 9'b000100001; //BEQ
            6'b001000: controls <= 9'b101000000; //ADDI
            6'b000010: controls <= 9'b000000100; //J
            default: controls <= 9'bxxxxxxxxx; //???
        endcase
    end
endmodule

//FLOP
module flopr # (parameter WIDTH = 8)(
    input en, clk, reset,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @ (posedge clk, posedge reset)
        if (reset) q <= 0;
        else if(en) $display("Stall Fetch");
	else q <= d;
endmodule

//HAZARD

module hazard_ctrl 
(input logic RegWriteW, RegWriteM, RegWriteE, 
 input logic MemtoRegE, MemtoRegM, BranchD,
 input logic [4:0]WriteRegM, WriteRegE, WriteRegW,
 input logic [4:0]RsD, RtD,
 input logic [4:0]RsE, RdE, RtE,
 output logic forwardAD, forwardBD, forwardAD2, forwardBD2,
 output logic [1:0]forwardAE, forwardBE,
 output logic StallD,StallF, FlushE
 );

 logic lwstall;
 logic branchstall, DEstall, DMstall;

 always_comb begin
// Data Hazard (RAW)
    if ((RsE!='0) & (RsE==WriteRegM) & RegWriteM)
	forwardAE = 2'b10;
    else if ((RsE!='0) & (RsE==WriteRegW) & RegWriteW)
	forwardAE = 2'b01;
    else forwardAE = 2'b00;
    if ((RtE!='0) & (RtE==WriteRegM) & RegWriteM)
	forwardBE = 2'b10;
    else if ((RtE!='0) & (RtE==WriteRegW) & RegWriteW)
	forwardBE = 2'b01;
    else forwardBE = 2'b00;
    lwstall = ((RsD==RtE)|(RtD==RtE)) & MemtoRegE;
// Branch Related Data Hazard    
    forwardAD2= (RsD!=0) & (RsD==WriteRegW) & RegWriteW;
    forwardBD2= (RtD!=0) & (RtD==WriteRegW) & RegWriteW;

    forwardAD = (RsD!=0) & (RsD==WriteRegM) & RegWriteM;
    forwardBD = (RtD!=0) & (RtD==WriteRegM) & RegWriteM;
//Control Hazard
    DEstall = RegWriteE & (WriteRegE == RsD | WriteRegE == RtD);
    DMstall = MemtoRegM & (WriteRegM == RsD | WriteRegM == RtD);
    branchstall = BranchD & (DEstall | DMstall);
    StallD = lwstall | branchstall;
    StallF = StallD;
    FlushE = StallD;
 end
endmodule

//mux
module mux2 # (parameter WIDTH = 8) (
    input logic [WIDTH-1:0] d0, d1,
    input logic s,
    output logic [WIDTH-1:0] y
);
    assign y = s ? d1 : d0;
endmodule

module mux3 # (parameter WIDTH =8) (
   input logic [WIDTH-1:0] d0, d1,d2,
   input logic [1:0] s,
   output logic [WIDTH-1:0] y
);
   always_comb begin
	case(s)
	   2'b00: y=d0;
	   2'b01: y=d1;
	   2'b10: y=d2;
	   default: y=d0;
	endcase
   end
endmodule

//SHIFT
module sl2 (
    input [31:0] a,
    output [31:0] y
);
    // shift left by 2
    assign y = {a[29:0], 2'b00};
endmodule

//signNext
module signext (
    input [15:0] a,
    output [31:0] y
);
    assign y = {{16{a[15]}}, a};
endmodule

//performance

module perform #(parameter WIDTH = 8)
(input logic clk, reset,stall,
 output logic [WIDTH-1:0]instr_cnt, clk_cnt);
  always_ff @(posedge clk) begin
     if(reset==1'b1) begin
	instr_cnt<='0;
  	clk_cnt<='0;
     end
     else begin
	clk_cnt<=clk_cnt+1;
	if (stall==1'b0) begin
	   instr_cnt<=instr_cnt+1;
	   $display("instruction count: %d", instr_cnt);
	end
     end
  end
endmodule
