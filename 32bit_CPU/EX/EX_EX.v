module EX (
    input [31:0] reg_data1,reg_data2, imm_ext,
    input alu_src,
    input [1:0] alu_op,
    input [5:0] funct,opcode,
    output [31:0] alu_result
);

wire [3:0] alu_ctrl;
wire [31:0] operand_b;

alu_control ac (
    alu_op,
    funct,
    opcode,
    alu_ctrl
);

//operand : ALU의 두번째 입력을 어디서 가져올지? reg_data2(rt)이면 Rtype, imm_ext는 Itype
assign operand_b = (alu_src) ? imm_ext : reg_data2;

alu alu_inst (
    reg_data1,
    operand_b,
    alu_ctrl,
    alu_result
);

endmodule