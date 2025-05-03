module idex (
    input clk,reset,
    input [31:0] pc_in,reg_data1_in,reg_data2_in,imm_in,
    input [4:0] rs_in,rt_in,rd_in,
    output reg [31:0] pc_out,reg_data1_out,reg_data2_out,imm_out,
    output reg [4:0] rs_out,rt_out,rd_out
);

always @(posedge clk or posedge reset) begin
    if(reset) begin
        pc_out<=0;
        reg_data1_out<=0;
        reg_data2_out<=0;
        imm_out<=0;
        rs_out<=0;
        rt_out<=0;
        rd_out<=0;
    end else begin
        pc_out<=pc_in;
        reg_data1_out<=reg_data1_in;
        reg_data2_out<=reg_data2_in;
        imm_out<=imm_in;
        rs_out<=rs_in;
        rt_out<=rt_in;
        rd_out<=rd_in;
    end

end
    
endmodule