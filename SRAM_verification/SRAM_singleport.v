module sram_single_port // single port
#(  parameter BW  = 32,
    parameter ADR = 8,
    parameter AMAX = 256
)
(
    input clk,CSn,WEn,
    input [BW-1:0] BWEn,
    //Byte Write Enable, 부분적으로 쓰기 허용 스위치
//BWEn의 각 비트는 wdata의 해당 비트가 메모리에 실제로 쓰일지 결정합니다:
//BWEn[i] = 0: 해당 비트(wdata[i])는 쓰기 허용.
//BWEn[i] = 1: 해당 비트는 쓰기 차단.
//BWEn은 비트별 마스크 역할을 합니다.

//조건문으로 처리하려면 각 비트를 개별적으로 확인하는 복잡한 로직이 필요합니다
//wdata = 32'hFFFF_FFFF, BWEn = 32'hFFFF_0000라면:
//~BWEn = 32'h0000_FFFF
//wdata & ~BWEn = 32'h0000_FFFF → 하위 16비트만 쓰기 허용 -> 이대로 memory에 쓰여짐

    input [ADR-1:0] addr,
    input [BW-1:0] wdata,

    output [BW-1:0] rdata
);

reg [BW-1:0] r_inner_mem[0:AMAX];
reg [ADR-1:0] r_addr;

    always @(posedge clk) begin
        if(!CSn) begin
            if(!WEn) begin
                r_inner_mem[addr] <= #1 wdata & ~BWEn;
            end // 위에 구조는 [0:AMAX]크기에서 addr 만큼 사용하고, 맨 처음 채워진게 가장 맨 위로 가서, 그 뒤론 그 밑으로 채워짐.
                // 즉, 0~addr 크기? 주소?는 그대로. 존재.
            r_addr <= #1 addr;
        end
    end

assign rdata = r_inner_mem[r_addr];

endmodule