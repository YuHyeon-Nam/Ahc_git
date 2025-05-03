module IM (
    input [31:0] addr,         // pc 주소 입력
    output [31:0] instruction // 출력
);
reg [31:0] memory [0:225];
initial begin
    $readmemh("instructions.hex",memory);
end
assign instruction = memory[addr[9:2]];
endmodule