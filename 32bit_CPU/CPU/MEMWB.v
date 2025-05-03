module mem_wb (
    input clk,
    input ex_mem_reg_write, ex_mem_mem_to_reg,
    input [31:0] read_data,alu_result,
    input [4:0] write_reg,

    output reg reg_write_out,
    output reg mem_to_reg_out,
    output reg [31:0] read_data_out,alu_result_out,
    output reg [4:0] write_reg_out
);

always @(posedge clk) begin
    reg_write_out <= ex_mem_reg_write;    // MEM 단계에서 WB로 전달
        mem_to_reg_out <= ex_mem_mem_to_reg;
    read_data_out <= read_data;
    alu_result_out <= alu_result;
    write_reg_out <= write_reg;
end
    
endmodule