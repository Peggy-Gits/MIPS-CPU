//dataMem

module dmem (
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);
    reg [31:0] RAM[63:0];

    assign rd = RAM[a[31:2]]; // word aligned
    initial begin
      for(int i=0;i<4;i++)RAM[i]=1;
      RAM[3]=2;
    end
    always @ (posedge clk)
        if (we)
            RAM[a[31:2]] <= wd;
endmodule

//instrMem

module imem (
    input [5:0] a,
    output [31:0] rd
);
    reg [31:0] RAM[63:0];
    
    initial begin
        $readmemh("memfile2.dat",RAM);
    end
    assign rd = RAM[a]; // word aligned
endmodule

//regFile
module regfile (
    input clk,
    input we3,
    input [4:0] ra1, ra2, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);
    
    reg [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always @ (posedge clk) begin
        if (we3) begin
	  rf[wa3] <= wd3;
	  $display("write %d, to address %d", wd3, wa3);
	end
    end
    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

module regfile2 (
    input clk,
    input we3,
    input [4:0] ra1, ra2, ra3, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2, rd3
);
    
    reg [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally
    // write third port on rising edge of clock
    // register 0 hardwired to 0
    always_ff @ (posedge clk)begin
        if (we3) begin
	  rf[wa3] <= wd3;
	  $display("write %d, to address %d", wd3, wa3);
	end
    end
    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
    assign rd3 = (ra3 != 0) ? rf[ra3] : 0;
endmodule
