module ifid_pipeline (
    input clk,reset,
    input [31:0] pc_in,instr_in,
    output reg [31:0] pc_out,instr_out
);
wire [31:0] pc,instr;

    //IF/ID Pipeline
always @(posedge clk or posedge reset) begin
    if(reset) begin
        pc_out <=0;
        instr_out<=0;
    end else begin
        pc_out <= pc;
        instr_out <= instr;
    end
end

endmodule