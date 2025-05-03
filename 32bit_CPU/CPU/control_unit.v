module control_unit (
    input [5:0] opcode, funct,
    output reg [1:0] alu_op,
    output reg alu_src, mem_read, mem_write, reg_write, mem_to_reg
);
    always @(*) begin
        case (opcode)
            6'b000000: begin // R-type
                alu_op = 2'b10;
                alu_src = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                reg_write = 1'b1;
                mem_to_reg = 1'b0;
            end
            6'b100011: begin // lw (Load Word)
                alu_op = 2'b00;
                alu_src = 1'b1;
                mem_read = 1'b1;
                mem_write = 1'b0;
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
            end
            6'b101011: begin // sw (Store Word)
                alu_op = 2'b00;
                alu_src = 1'b1;
                mem_read = 1'b0;
                mem_write = 1'b1;
                reg_write = 1'b0;
                mem_to_reg = 1'b0;
            end
            6'b000100: begin // beq (Branch Equal)
                alu_op = 2'b01;
                alu_src = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                reg_write = 1'b0;
                mem_to_reg = 1'b0;
            end
            default: begin
                alu_op = 2'b00;
                alu_src = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                reg_write = 1'b0;
                mem_to_reg = 1'b0;
            end
        endcase
    end
endmodule