`include "INSTR_SEQUENCE.sv"
`include "CPU.sv"
`include "DATA_PATH.sv"
`include "MEM.sv"
interface instr_mem_if;
  logic reset, clk;
  logic [31:0]instr;
  logic taken;
endinterface: instr_mem_if

interface trick_box_if;
  logic [31:0] data_addr;
  logic [31:0] data;
endinterface: trick_box_if

class instr_monitor extends uvm_monitor;
  `uvm_component_utils(instr_monitor)
  virtual instr_mem_if vif;
  virtual trick_box_if tif;
  instruction tr;
  trick_box tbox;
  uvm_analysis_port #(instruction) ap;
  uvm_analysis_port #(trick_box) ap2;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);    
  endfunction

  function void build_phase(uvm_phase phase);
    void'(uvm_resource_db#(virtual instr_mem_if)::read_by_name
			(.scope("ifs"), .name("instr_mem_if"), .val(vif)));
    void'(uvm_resource_db#(virtual trick_box_if)::read_by_name
			(.scope("ifs"), .name("trick_box_if"), .val(tif)));
    ap=new("ap",this);
    ap2=new("ap2",this);
  endfunction

  task run_phase(uvm_phase phase);
    @(negedge vif.reset);
    //wait for reset
    $display("start transaction");
    forever begin
      //@(posedge vif.clk);
      tr = new();
      tbox =new();
      @(negedge vif.clk);
      $display("received tr:%b", vif.instr);
      tr.opcode=vif.instr[31:26];
      tr.funct=vif.instr[5:0];
      tr.reg_a=vif.instr[20:16];
      tr.reg_b=vif.instr[15:11];
      tr.reg_c=vif.instr[25:21];
      tr.immed=vif.instr[15:0];
      tr.taken=vif.taken;
      tbox.data_addr=tif.data_addr;
      tbox.data=tif.data;
      ap.write(tr);
      ap2.write(tbox);
    end
  endtask
endclass


class instr_coverage extends uvm_subscriber #(instruction);
  `uvm_component_utils(instr_coverage)
  //instruction tr;
  uvm_analysis_imp #(instruction, instr_coverage) imp;
  instruction tr; 
  instruction mem [$];
  int gap;
  bit taken, not_taken;
  int q_addr[$], q_R_b[$], q_R_c[$],q_lw_b[$],q_lw_c[$];
  covergroup instr_fields_cg;
    coverpoint tr.funct {
      bins ADD = {6'b100000} iff (tr.opcode==6'b000000);
      bins AND = {6'b100100} iff (tr.opcode==6'b000000);      
    }
    coverpoint tr.opcode {
      bins R = {6'b000000};
      bins LW = {6'b100011};
      bins BEQ = {6'b000100};
      bins SW = {6'b101011};
    }
    //coverpoint tr.reg_c {1}
  endgroup: instr_fields_cg

  covergroup R_cg;
    coverpoint tr.reg_b{
      bins R={[1:4]}iff(q_R_b.size()>0);
      bins lw={[1:4]}iff(q_lw_b.size()>0);
    }
    coverpoint tr.reg_c{
      bins R={[1:4]}iff(q_R_c.size()>0);
      bins lw={[1:4]}iff(q_lw_c.size()>0);
    }
    coverpoint gap{
      bins b={[1:3]};
    }
  endgroup
  covergroup sw_cg;
    coverpoint tr.reg_b{
      bins R={[1:4]}iff(q_R_b.size()>0);
      bins lw={[1:4]}iff(q_lw_b.size()>0);
    }
    coverpoint tr.immed{
     bins lw_addr = {[1:4]} iff (q_addr.size()>0);
    }
    coverpoint gap{
	bins b={[1:3]};
    }
  endgroup
  covergroup lw_cg;
    coverpoint tr.immed{
     bins lw_addr = {[1:4]} iff (q_addr.size()>0);
    }
  endgroup
  covergroup beq_cg;  
    coverpoint taken;
    coverpoint gap{
      bins b={[1:3]};
    } 
  endgroup
  function new(string name, uvm_component parent);
    super.new(name, parent);
    instr_fields_cg = new;
    R_cg=new;
    lw_cg=new;
    sw_cg=new;
    beq_cg=new;
  endfunction

  function void build_phase(uvm_phase phase);
    imp=new("imp",this);
  endfunction

  function void write(instruction t);
    //Create a queue
    //Call sample of various cgs
    tr=t;    
    instr_fields_cg.sample();    
    q_addr=mem.find_index with(item.opcode inside {6'b100011,6'b101011} & item.immed==tr.immed);
    q_R_b=mem.find_index with(item.opcode==6'b000000 &(item.reg_a==tr.reg_b));
    q_R_c=mem.find_index with(item.opcode==6'b000000 &(item.reg_a==tr.reg_c));
    q_lw_b=mem.find_index with(item.opcode==6'b100011 &(item.reg_b==tr.reg_b));  
    q_lw_c=mem.find_index with(item.opcode==6'b100011 &(item.reg_b==tr.reg_c)); 
    gap=(q_R_b.size()>0)?q_R_b[0]:4;
    gap=(q_R_c.size()>0)?((gap>q_R_c[0])?q_R_c[0]:gap):4;
    gap=(q_lw_b.size()>0)?((gap>q_lw_b[0])?q_lw_b[0]:gap):4;
    gap=(q_lw_c.size()>0)?((gap>q_lw_c[0])?q_lw_c[0]:gap):4;
    $display("gap:%d",gap);
    case(tr.opcode)
      6'b0: begin         
	R_cg.sample();
        //$display("mem:%p");
	$display("reg_b:%d",tr.reg_b);
	$display("reg_b:%d",tr.reg_c);
      end
      6'b101011:begin
	sw_cg.sample();
      end
      6'b100011:begin
	lw_cg.sample();
      end
      6'b000100:begin
        taken=tr.taken;
        beq_cg.sample();
      end
    endcase
    //$display("coverage:%f",beq_cg.taken.get_coverage());
    mem.push_front(t);
  endfunction
endclass

class trick_box_read extends uvm_subscriber#(trick_box);
   `uvm_component_utils(trick_box_read);
   uvm_analysis_imp #(trick_box, trick_box_read) imp;

   function new(string name, uvm_component parent);
    super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
    imp=new("imp",this);
   endfunction

   function void write(trick_box t);
    if(t.data_addr==5)$display("print:%d",t.data);
   endfunction
endclass

class instr_env extends uvm_env;
  `uvm_component_utils(instr_env)

  instr_monitor mon;
  instr_coverage cov;
  trick_box_read tbox;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon	= instr_monitor::type_id::create(.name("instr_monitor"), .parent(this));
    cov = instr_coverage::type_id::create(.name("instr_covereage"), .parent(this));
    tbox = trick_box_read::type_id::create(.name("trick_box_read"), .parent(this));
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    mon.ap.connect(cov.imp);
    mon.ap2.connect(tbox.imp);
  endfunction
endclass

class my_test extends uvm_test;

    instr_env env;

    `uvm_component_utils(my_test)

    function new (string name = "my_test", uvm_component parent = null);
      super.new (name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
         super.build_phase (phase);
         env  = instr_env::type_id::create ("my_env", this);
      endfunction
    task run_phase(uvm_phase phase);
	//serialalu_sequence sa_seq;
	phase.raise_objection(.obj(this));
          env.cov.instr_fields_cg.start();
	  #200;
          env.cov.instr_fields_cg.stop();
	phase.drop_objection(.obj(this));
    endtask: run_phase
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  logic [31:0]imem[20];
  logic [31:0] instr, pc, readdata, writedata, dataddr;
  bit clk, reset, memwrite;
  //DUT instance
  CPU_fw mips (.clk(clk), .reset(reset), .instr(instr), .ReadDataM(readdata), .PCF(pc), .MemWriteM(memwrite), .ALUoutM(dataddr), .WriteDataM(writedata));
  //imem imem (pc[7:2], instr);
  dmem dmem (clk, memwrite, dataddr, writedata, readdata);
  //Interface
  instr_mem_if imem_if();
  trick_box_if tbox_if();
  assign imem_if.clk=clk;
  assign imem_if.reset=reset;
  assign instr=imem[pc[7:2]];
  assign imem_if.instr=instr;
  assign imem_if.taken=mips.pcsrc;
  
  assign tbox_if.data=readdata;
  assign tbox_if.data_addr=dataddr;
  //Resource db population
  initial begin
   clk=0;
   forever begin
     #(5);
     clk=~clk;
   end
  end  
 
  instruction_generator gen;
  initial begin
   reset=1'b1;
   @(negedge clk);
   @(negedge clk);
   reset=1'b0;
  end

  initial begin
   $fsdbDumpvars;
  end

  initial begin
    //Code from the instr generator part:
    uvm_resource_db#(virtual instr_mem_if)::set
			(.scope("ifs"), .name("instr_mem_if"), .val(imem_if));
    uvm_resource_db#(virtual trick_box_if)::set
			(.scope("ifs"), .name("trick_box_if"), .val(tbox_if));
    gen = new();
    gen.generate_sequence;
    gen.generate_machine_code();
    gen.display_all();
    //Note you will merge the codes from the instr generator and the coverage collector properly. I'm just showing something basic.
   // uvm_resource_db#(virtual instr_mem_if)::set		(.scope("ifs"), .name("instr_imem_if"), .val(imem_if));
    $readmemh("instrMem.dat",imem);
    
  
    //Copy memory from gen to the instr mem
    //OR: Call $readmemh on that file you wrote using $writememh
    //Deassert reset
    //reset=1'b0;
    $display("mem:%p",imem);
    run_test("my_test");
  end
endmodule
