//two port

module twoport_sram
#(  parameter DEPTH = 8,
    parameter WIDTH = 32,
    parameter DEPTH_LOG=$clog2(DEPTH)
)
(
    input clk, //write clk
    input we, //write enable - cs 비활성화

    input [DEPTH_LOG-1:0] wa, //write addr
    input [WIDTH-1:0] wd, //wdata
    
    input re,
    input [DEPTH_LOG-1:0] ra, //read addr
    output reg [WIDTH-1:0] rd //rdata
);

reg [WIDTH-1:0] mem[DEPTH-1:0];
integer i;

initial begin
    for(i=0; i<DEPTH; i=i+1)
    mem[i]=0; //초기화 구문
end
always @(posedge clk)
    if(we) mem[wa] <=wd;

always @(posedge clk)
    if(re) rd <=mem[ra];


endmodule