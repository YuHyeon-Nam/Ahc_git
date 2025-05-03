module ifid (
    input clk, reset, write,flush, //write : hazard 시 stall
    input [31:0] pc_in,instr_in,    // flush : branch 실패시 
    output reg [31:0] pc_out, instr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'b0;
            instr_out <=32'b0;
        end else if (flush) begin
            pc_out <= 32'b0;
            instr_out <= 32'b0;
        end else if (write) begin
            pc_out <= pc_in;
            instr_out <= instr_in;
        end
    end
endmodule