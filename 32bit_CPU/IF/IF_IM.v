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

/*addr은 32bit인데, 바이트 단위로 저장하는 메모리 위치를 가리킴.
즉, addr 하나 당 1바이트를 가리킴.
그런데, 명령어는 32비트고 4바이트고 한꺼번에 꺼내야함.
addr[9:2]로 블록(하나당 4바이트)를 고르고 [1:0]으로 0~3번째 바이트를 다시 고름.
하위 2비트를 이용해서 4바이트 단위로 움지이는 명령어를 고르는거임.

보통 명령어는 4바이트 단위로, 블록 통째로 움직이니까 addr[9:2]만을 사용하는거.*/