module id_ex_pipeline (
    input clk,reset,
    input [31:0] pc_in,reg_data1_in,reg_data2_in,imm_in,
    input [4:0] rs_in,rt_in,rd_in,
    
    input [1:0] alu_op_in,
    input alu_src_in, mem_read_in, mem_write_in, reg_write_in, mem_to_reg_in,
    
    output reg [31:0] pc_out, reg_data1_out, reg_data2_out,imm_out,
    output reg [4:0] rs_out,rt_out,rd_out,
    
    output reg [1:0] alu_op_out,
    output reg alu_src_out, mem_read_out, mem_write_out, reg_write_out, mem_to_reg_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <=0;
            reg_data1_out <=0;
            reg_data2_out <=0;
            imm_out <=0;
            rs_out <=0;
            rt_out <=0;
            rd_out <=0;
            alu_op_out <= 0;
            alu_src_out <= 0;
            mem_read_out <= 0;
            mem_write_out <= 0;
            reg_write_out <= 0;
            mem_to_reg_out <= 0;

        end else begin
            pc_out<=pc_in;
            reg_data1_out <=reg_data1_in;
            reg_data2_out <=reg_data2_in;
            imm_out <=imm_in;
            rs_out <=rs_in;
            rt_out <=rt_in;
            rd_out <=rd_in;
            alu_op_out <= alu_op_in;
            alu_src_out <= alu_src_in;
            mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in;
            reg_write_out <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule