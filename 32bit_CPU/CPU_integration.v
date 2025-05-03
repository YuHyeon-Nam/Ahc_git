module CPU(
    input clk,reset
);

//IF
wire [31:0] pc,instr;
reg [31:0] pc_reg;
initial pc_reg=0;
always @(posedge clk or posedge reset) begin
    if(reset) pc_reg <=0;
    else pc_reg <= pc+4;
end
reg [31:0] instr_mem[0:255];
initial $readmemh("instructions.hex",instr_mem);
assign instr = instr_mem[pc[9:2]];

//IF/ID 파이프라인
wire [31:0] if_id_pc, if_id_instr;
ifid_pipeline if_id (
    clk,
    reset,
    pc,instr,
    if_id_pc,
    if_id_instr
);

//ID
wire [5:0] opcode,funct;
wire [4:0] rs,rt,rd,shamt;
wire [15:0] imm;
wire [31:0] reg_data1, reg_data2;
wire [31:0] imm_ext;

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
    .out(imm_ext)
);

wire [1:0] alu_op;
wire alu_src, mem_read, mem_write, reg_write, mem_to_reg;
control_unit cu (
    .opcode(opcode), .funct(funct),
    .alu_op(alu_op), .alu_src(alu_src),
    .mem_read(mem_read), .mem_write(mem_write),
    .reg_write(reg_write), .mem_to_reg(mem_to_reg)
);

// ID_EX
wire [31:0] id_ex_pc,id_ex_reg_data1_in, id_ex_reg_data2_in,imm_in;
wire [4:0] id_ex_rs, id_ex_rt, id_ex_rd;

wire [1:0] id_ex_alu_op;
wire id_ex_alu_src, id_ex_mem_read, id_ex_mem_write, id_ex_reg_write, id_ex_mem_to_reg;

id_ex_pipeline iep(
    clk,
    reset,
    if_id_pc,
    reg_data1,
    reg_data2,
    imm_ext,
    rs,
    rt,
    rd,
    id_ex_pc,
    id_ex_reg_data1,
    id_ex_reg_data2,
    id_ex_imm,
    id_ex_rs,
    id_ex_rt,
    id_ex_rd,
    id_ex_alu_op,
    id_ex_alu_src,
    id_ex_mem_read,
    id_ex_mem_write,
    id_ex_reg_write,
    id_ex_mem_to_reg
);

wire [31:0] ex_alu_result;

EX ex (
    id_ex_reg_data1,
    id_ex_reg_data2,
    id_ex_imm,
    alu_src,
    alu_op,
    funct,
    opcode,
    ex_alu_result
);

//EX, 모듈의 output을 받을때 wire 새로 선언(연결짓는느낌)
wire [31:0] ex_mem_alu_result,ex_mem_reg_data2;
wire [4:0] ex_mem_rd;
wire ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write, ex_mem_mem_to_reg;
ex_mem em (
    clk,
    reset,
    ex_alu_result,
    id_ex_reg_data2,
    id_ex_rd,
    id_ex_mem_read,
    id_ex_mem_write,
    id_ex_reg_write,
    id_ex_mem_to_reg,
    ex_mem_alu_result,
    ex_mem_reg_data2,
    ex_mem_rd,
    ex_mem_mem_read,
    ex_mem_mem_write,
    ex_mem_reg_write,
    ex_mem_mem_to_reg
);

//MEM
wire [31:0] mem_read_data;
mem m (
    clk,
    reset,
    ex_mem_mem_read,
    ex_mem_mem_write,
    ex_mem_alu_result,
    ex_mem_reg_data2,
    mem_read_data
);

//MEM_WB
wire mem_wb_reg_wirte,mem_wb_mem_to_reg;
wire [31:0] mem_wb_read_data,mem_wb_alu_result;
wire [4:0] mem_wb_write_reg;

mem_wb mw (
    clk,
    ex_mem_mem_reg_write,
    ex_mem_mem_to_reg,
    mem_read_data,
    ex_mem_alu_result,
    ex_mem_rd,

    mem_wb_reg_wirte,
    mem_wb_mem_to_reg,
    mem_wb_read_data,
    mem_wb_alu_result,
    mem_wb_write_reg
);

//WB
wire [4:0] wb_reg_write_addr;
wire [31:0] wb_reg_write_data;
wire wb_reg_wirte_enable;
WB w (
    mem_wb_reg_wirte,
    mem_wb_mem_to_reg,
    mem_wb_write_reg,

    wb_reg_write_addr,
    wb_reg_write_data,
    wb_reg_write_enable
);

endmodule