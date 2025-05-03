`timescale 10ns/1ps
module tb_alu_control;

reg clk;
reg [1:0] alu_op;
reg [5:0] funct;
reg [5:0] opcode;
wire [3:0] alu_control;

alu_control ac
    (   .alu_op(alu_op),
        .funct(funct),
        .opcode(opcode),
        .alu_control(alu_control)
);

always #5 clk = ~clk;

initial begin
    clk=0; alu_op=2'd0; funct=6'd0; opcode=6'd0;
    #10;
    alu_op=2'b00;
    #10;
    opcode = 6'b001000;
    #10;
    opcode = 6'b001100;
    #10;
    opcode = 6'b001101;
    #10;
    opcode = 6'd0;
    #10;
    alu_op=2'b01;
    #10;
    alu_op=2'b10;
    #10;
    funct = 6'b100000;
    #10;
    funct = 6'b100010;
    #10;
    funct = 6'b100100;
    #10;
    funct = 6'b100101;
    #10;
    funct = 6'b101010;
    #10;
    funct = 6'd0;
end

endmodule