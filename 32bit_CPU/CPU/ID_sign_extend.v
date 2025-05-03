module sign_extend (
    input [15:0] in,
    output [31:0] out
);

    assign out = {{16{in[15]}}, in}; //in[15]이 1이면 앞에 1을 16개 붙이기 (음수 유지) 0이면 0을 16개 (양수 유지)
//cpu에서 명령어는 32bit인데, ADDI 같은 명령어는 16bit짜리 immediate를 포함해야함
//따라서, 32bit로 크기 맞춰야함.
//ADDI, LW, SW 등에서 16bit immediate 값을 ALU에 입력
//프로그램 카운터 이동 시 BEQ, BNE 등의 offset 연산에서 사용
endmodule