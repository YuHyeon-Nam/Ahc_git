`timescale 1ns/1ps
module tb_SRAM;

parameter BW = 32; //16진수로 20
parameter ADR = 8;
parameter AMAX = 256; //16진수로 100

reg clk,CSn,WEn;
reg [BW-1:0] BWEn;
reg [ADR-1:0] addr;
reg [BW-1:0] wdata;
wire [BW-1:0] rdata;

sram_single_port #( // parameter 부분에선 따로 이름 작성 x
    BW,
    ADR,
    AMAX
) dut ( //변수 선언에서 이름 작성
    clk, // design under testbench
    CSn,
    WEn,
    BWEn,
    addr,
    wdata,
    rdata
);

initial begin
    clk=0;
    forever #5 clk=~clk;
end

initial begin
    CSn=1;
    WEn=1;
    BWEn=0;
    addr=0;
    wdata=0;

    #20;

    CSn=0;
    WEn=0;
    BWEn = 32'h00000000;
    addr = 8'h00;
    wdata = 32'hDEADBEEF;
    
    #10;

    addr=8'h01; //이렇게 addr를 옮겨주면서 메모리를 채움.
    wdata = 32'hCAFEBABE;
    
    #10;

    WEn=1;

    #10;

    addr = 8'h00;

    #10;

    addr = 8'h01;

    WEn=0;
    addr=8'h02;
    BWEn = 32'hFFFF0000;
    wdata = 32'h12345678;
    #10;

    WEn=1;

    #10;

    $finish;
end

endmodule