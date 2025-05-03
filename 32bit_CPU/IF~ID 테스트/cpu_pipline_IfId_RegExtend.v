`timescale 10ns/1ps
module cpu_pipeline(
    input clk,reset
) ;
//IF stage
reg [31:0] pc;
wire [31:0] instr;

//Instruction Memory
reg[31:0] instr_mem[0:255];
initial $readmemh("instructions.hex",instr_mem);
assign instr = instr_mem[pc[9:2]]; // word address able

//IF/ID Pipeline
reg [31:0] if_id_pc, if_id_instr;
always @(posedge clk or posedge reset) begin
    if(reset) begin
        if_id_pc <=0;
        if_id_instr<=0;
    end else begin
        if_id_pc <= pc;
        if_id_instr <= instr;
    end
end
//ID stage
wire [5:0] opcode;
wire [4:0] rs,rt,rd,shamt;
wire [5:0] funct;
wire [15:0] imm;

decoder dec (
    .instr(if_id_instr),
    .opcode(opcode),
    .rs(rs),
    .rt(rt),
    .rd(rd),
    .shamt(shamt),
    .funct(funct),
    .imm(imm)
);

wire [31:0] reg_data1, reg_data2;
wire [31:0] sign_ext_imm;

regster rf (
    .clk(clk),
    .reg_write(1'b0), //쓰기 아직 하지 않음
    .rs(rs),
    .rt(rt),
    .rd(5'b0),
    .write_data(32'b0),
    .read_data1(reg_data1),
    .read_data2(reg_data2)
);

sign_extend se (
    .in(imm),
    .out(sign_ext_imm)
);

always @(posedge clk or posedge reset) begin
    if (reset)
        pc<=0;
    else
        pc<=pc+4;
    end


endmodule