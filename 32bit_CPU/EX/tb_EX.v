`timescale 10ns/1ps
module tb_ex ;

reg [31:0] reg_data1,reg_data2, imm_ext;
reg alu_src;
reg [1:0] alu_op;
reg [5:0] funct,opcode;

wire [31:0] alu_result;

EX ex(
    reg_data1,
    reg_data2,
    imm_ext,
    alu_src,
    alu_op,
    funct,
    opcode,
    alu_result
);

initial begin
    reg_data1=32'd10;
    reg_data2=32'd20;
    imm_ext=32'd5;
    funct=6'b100000;
    opcode=6'b001000;

    alu_src=0;
    alu_op=2'b10;
    #10;

    funct = 6'b100010;
    #10;

    alu_src=1;
    alu_op = 2'b00;
    #10;

    opcode = 6'b001101;
    imm_ext = 32'd15;
    #10;

    alu_op=2'b10;
    alu_src=0;
    funct=6'b101010;
    #10;

    $finish;

end


endmodule