`timescale 10ns/1ps
module tb_ifid;

reg clk, reset, pc_write, if_id_write, flush;
wire [31:0] pc_out, instruction, if_pc, if_instr;

wire [31:0] next_pc = pc_out +4;

pc pc(clk, reset, pc_write,next_pc,pc_out);

IM IM(.addr(pc_out), .instruction(instruction));

ifid fd (clk,reset,if_id_write,flush,pc_out,instruction,if_pc,if_instr);

initial begin
    clk=0;
    forever #5 clk =~clk;
end

initial begin
    reset = 1;
    pc_write =0;
    if_id_write=0;
    flush=0;
    #10;

    reset =0;
    pc_write=1;
    if_id_write=1;
    flush=0;

    repeat (10) begin
        #10;
        $display("PC: %h, Instruction: %h", pc_out, instruction);
    end
    $finish;
end
    
endmodule