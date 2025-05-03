//dual port
//총 4개 port를 가지게 됨.

module tpsram
#(  parameter DEPTH = 8,
    parameter WIDTH = 32,
    parameter DEPTH_LOG=$clog2(DEPTH)
)
(
    input clk, //write clk

    input we1, cs1,
    input [DEPTH_LOG-1:0] wa1, //write addr
    input [WIDTH-1:0] wd1, //wdata

    input we2, cs2, 
    input [DEPTH_LOG-1:0] wa2, //write addr
    input [WIDTH-1:0] wd2, //wdata
    
    input [DEPTH_LOG-1:0] ra1, //read addr
    output reg [WIDTH-1:0] rd1, //rdata

    input [DEPTH_LOG-1:0] ra2, //read addr
    output reg [WIDTH-1:0] rd2 //rdata
);

reg [WIDTH-1:0] mem[DEPTH-1:0];
integer i;

initial begin
    for(i=0; i<DEPTH; i=i+1)
    mem[i]=0; //초기화 구문
end
always @(posedge clk)
    if(we1&cs1) mem[wa1] <= wd1;
    else if (cs1) rd1 <= mem[ra1];

always @(posedge clk)
    if(cs2&we2) mem[wa2]<=wd2;
    else if (cs2) rd2 <= mem[ra2];


endmodule