`timescale 1ns/1ps
module tb_wb;

reg reg_write,mem_to_reg;
reg [31:0] read_data,alu_result;
reg [4:0] write_reg;

wire [4:0] reg_write_addr;
wire [31:0] reg_write_data;
wire reg_write_enable;

WB wb (
    reg_write,
    mem_to_reg,
    read_data,
    alu_result,
    write_reg,
    reg_write_addr,
    reg_write_data,
    reg_write_enable
    );
    
initial begin
    reg_write = 1;
    mem_to_reg = 0;
alu_result = 32'h12345678;
read_data = 32'h87654321;
write_reg = 5'd10;
#10;
mem_to_reg = 1;
#10;
reg_write = 0;
#10;
$finish;

end

endmodule