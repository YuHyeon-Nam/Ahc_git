module WB (
    input reg_write,mem_to_reg,
    input [31:0] read_data,alu_result,
    input [4:0] write_reg,
    output [4:0] reg_write_addr,
    output [31:0] reg_write_data,
    output reg_write_enable
);
    //선택 신호에 따라 write data 결정
    assign reg_write_data = mem_to_reg ? read_data : alu_result;

    //목적지 레지스터 주소 전달
    assign reg_write_addr = write_reg;

    //실제 write enable 신호
    assign reg_write_enable = reg_write;

endmodule