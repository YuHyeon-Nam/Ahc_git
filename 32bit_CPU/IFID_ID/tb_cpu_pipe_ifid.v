`timescale 10ns/1ps
module cpu_tb;
reg clk, reset;
cpu_pipeline cp (
    .clk(clk),
    .reset(reset)
);

always #5 clk = ~clk;
initial begin

    clk=0;
    reset =1;
    #10;
    reset=0;

    #100;
    $finish;
end
    
endmodule