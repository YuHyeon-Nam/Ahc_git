`timescale 1ns / 1ps

module tb_cpu;
    // 입력 신호
    reg clk;
    reg rstn;

    // CPU 인스턴스
    cpu uut (
        .clk(clk),
        .rstn(rstn)
    );

    // 클럭 생성
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns 주기 (100MHz)
    end

    // 초기화 및 테스트
    initial begin
        // 초기화
        rstn = 0;
        #20;
        rstn = 1;

        // 1000ns 동안 시뮬레이션
        #1000;
        $finish;
    end
    endmodule