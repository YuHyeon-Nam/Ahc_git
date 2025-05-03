`timescale 1ns/1ps
module tb_cpu;
reg clk,reset;

CPU CPU (clk, reset);

initial begin
    clk=0;
    forever #5 clk=~clk;
end

initial begin
    reset =1;
    #10;
    reset =0;

    #1000;
    $finish;
end

endmodule