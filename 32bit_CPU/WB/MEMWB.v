module mem_wb (
    input clk,reg_write,mem_to_reg,
    input [31:0] read_data,alu_result,
    input [4:0] write_reg,

    output reg reg_write_out,
    output reg mem_to_reg_out,
    output reg [31:0] read_data_out,alu_result_out,
    output reg [4:0] write_reg_out
);

always @(posedge clk) begin
    reg_write_out<=reg_write;
    mem_to_reg_out <= mem_to_reg;
    read_data_out <= read_data;
    alu_result_out <= alu_result;
    write_reg_out <= write_reg;
end
    
endmodule