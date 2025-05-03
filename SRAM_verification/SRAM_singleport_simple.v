//하드웨어에 이게 더 가까움 - single port

module sram_single_port
#(  parameter DEPTH = 8,
    parameter WIDTH = 32,
    parameter DEPTH_LOG=$clog2(DEPTH)
)
(
    input clk,
    input cs,we,

    input [DEPTH_LOG-1:0] addr,
    input [WIDTH-1:0] datain, //wdata와 같은듯?
    output reg [WIDTH-1:0] dataout

);

reg [WIDTH-1:0] mem[DEPTH-1:0];
integer i;
initial begin
    for(i=0; i<DEPTH; i=i+1)
    mem[i]=0; //초기화 구문
end
always @(posedge clk) begin
    if(cs && we) mem[addr] <=datain;
    else if(cs) dataout <=mem[addr];
end

endmodule