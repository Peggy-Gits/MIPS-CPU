`define SET_SIZE 4
import uvm_pkg::*;
`include "uvm_macros.svh"

class trick_box extends uvm_transaction;
  bit [31:0]data_addr;
  bit [31:0]data;
endclass

class instruction extends uvm_transaction;
  rand bit [4:0] reg_a, reg_b, reg_c;
  rand bit [5:0] opcode, funct;
  rand bit [15:0] immed;
  bit taken;
  //int reg_array =[1:4];

  
  `uvm_object_utils(instruction)
  //    `uvm_field_int(immed, UVM_ALL_ON)
  //`uvm_object_utils_end
  
  function new(string name = "instr");
		super.new(name);
  endfunction: new

  constraint unique_regs {
   unique {reg_a, reg_b, reg_c};
   if(opcode==6'b100011|opcode==6'b101011) reg_a==1;
   else reg_a inside {[1:4]};
   reg_b inside {[1:4]};
   reg_c inside {[1:4]};
  }

  constraint valid_opcode{
   opcode inside {6'b000000,6'b100011, 6'b101011, 6'b000100};
  }

  constraint valid_funct {
   funct inside {6'b100000,6'b100100,6'b100101};
  }
 
  constraint valid_immed {
   if (opcode==6'b000100) immed ==1;
   else immed inside {[1:4]};
  }

  /*constraint illegal_opcode {
  }

  function void print_me();
  endfunction*/
endclass:instruction

class instruction_generator;
  instruction instr_list[];
  bit [31:0] machine_code_list[];

  function void generate_individual();
      int size=instr_list.size();
      instruction instr;        
      instr=new();
      assert(instr.randomize());
      instr_list=new[size+1](instr_list);
      instr_list[size]=instr;  
  endfunction
  function void instr_trick_box();
      instruction instr;
      instr=new();
      instr.unique_regs.constraint_mode(0);
      instr.valid_immed.constraint_mode(0);
      instr.randomize() with{
	  reg_a=='0;
          reg_b inside{[1:4]};
          opcode==6'b101011;
          immed==5;
       };
      instr_list=new[instr_list.size()+1](instr_list);   
      instr_list[instr_list.size()-1]=instr;
  endfunction
  function void generate_eq();
      instruction beq;
      beq=new();
      beq.unique_regs.constraint_mode(0);
      beq.randomize() with {
	reg_a==1; 
        reg_b==1;
        opcode==6'b000100;
      };
      instr_list=new[instr_list.size()+1](instr_list);   
      instr_list[instr_list.size()-1]=beq;
  endfunction

  function void initial_config();
     instruction instr;
     for (int i=0;i<4;i++)begin
	instr=new();
        instr.unique_regs.constraint_mode(0);
        instr.randomize() with{
	  reg_a=='0;
          reg_b== i+1;
          opcode==6'b100011;
          //immed==i+1;
        };
	instr_list=new[instr_list.size()+1](instr_list);   
        instr_list[instr_list.size()-1]=instr;
     end
     for (int i=0;i<2;i++)begin
	instr=new();
        instr.unique_regs.constraint_mode(0);
        instr.randomize() with{
	  reg_a== i+1;
          reg_b== i+1;
	  reg_c== 0;
          opcode==6'b000000;
        };
	instr_list=new[instr_list.size()+1](instr_list);   
        instr_list[instr_list.size()-1]=instr;
     end
  endfunction

  function void generate_pairs();
    instruction instr1,instr2;
    instr1=new();
    instr2=new();
    instr1.randomize() with { 
	opcode== 6'b0;
	reg_a == 1; };
    instr2.randomize() with { 
	opcode== 6'b0;	
	reg_a == 1; };
    instr_list=new[instr_list.size()+1](instr_list);   
    instr_list[instr_list.size()-1]=instr1;    
    insert_gaps();
    instr_list=new[instr_list.size()+1](instr_list);   
    instr_list[instr_list.size()-1]=instr2;
    //$display("instr size=%d",instr_list.size());
  endfunction

  function void insert_gaps();
    int gap;
    std::randomize(gap) with {gap inside {[1:4]};};
    $display("gap= %d", gap);
    for (int i=0;i<gap;i++)begin 
         generate_individual();
    end
  endfunction

  function void generate_sequence();
    initial_config();
    $display("start program");
    for(int i=0;i<`SET_SIZE;i++)begin
	instr_trick_box();
	generate_pairs();
    end
  endfunction

  function void generate_machine_code();
      for(int i=0;i<instr_list.size();i++)begin
         //$display("size: ", instr_list.size());
         bit [31:0] code;
         instruction instr;
	 instr=instr_list[i];
         case (instr.opcode)
	    6'b000000: begin 
		code={6'b0,instr.reg_a,instr.reg_b,instr.reg_c,5'b0, instr.funct}; //Rtyp
 	        $display("R, rega=,%d,regb=%d,regc=%d",instr.reg_a,instr.reg_b,instr.reg_c);
	    end
            6'b100011: begin
		code={instr.opcode,instr.reg_a,instr.reg_b,instr.immed};//LW
	        $display("LW, rega=,%d,regb=%d,immed=%d",instr.reg_a,instr.reg_b,instr.immed);
	    end
            6'b101011: begin 
		code={instr.opcode,instr.reg_a,instr.reg_b,instr.immed};//SW
		$display("SW, rega=,%d,regb=%d,immed=%d",instr.reg_a,instr.reg_b,instr.immed);
	    end
            6'b000100: begin
	        code={instr.opcode,instr.reg_a,instr.reg_b,instr.immed};//BEQ
		$display("BEQ, rega=,%d,regb=%d,immed=%d",instr.reg_a,instr.reg_b,instr.immed);
	    end
            default : code='0;
     	 endcase
	  machine_code_list=new [machine_code_list.size()+1](machine_code_list);
	  machine_code_list[machine_code_list.size()-1]=code;
      end
   $writememh ("instrMem.dat",machine_code_list);
  endfunction

  function void display_all();
    for(int i=0;i<machine_code_list.size();i++)begin
        bit [31:0]code;
        code=machine_code_list[i];
	$display("%h",code);
    end
    //$display("instr_list= %p",machine_code_list);
  endfunction
endclass

/*module testbench;
  instruction_generator gen;

  initial begin
    gen = new();
    $display("gen created");
    gen.generate_sequence();
    gen.generate_machine_code();
    $display("instruction generated");
    gen.display_all();
    
    //Copy memory from gen to the instr mem
    //OR: Call $readmemh on that file you wrote using $writememh
    //Deassert reset
  end
endmodule*/
