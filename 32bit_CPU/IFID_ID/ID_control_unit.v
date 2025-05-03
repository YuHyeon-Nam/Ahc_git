module control_unit (
    input [5:0] opcode,
    output reg reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write
);

always @(*) begin
    case (opcode)
    6'b000000: begin//R-typep
    reg_dst =1;
    alu_src =0;
    mem_to_reg =0;
    reg_write =1;
    mem_read =0;
    mem_write =0;
    end
    6'b001000: begin //ADDI
        reg_dst =0;
        alu_src =1;
    mem_to_reg =0;
    reg_write =1;
    mem_read =0;
    mem_write =0;
    end 
    6'b100011: begin //LW
        reg_dst =0;
        alu_src =1;
    mem_to_reg =1;
    reg_write =1;
    mem_read =1;
    mem_write =0;
    end 
    6'b101011: begin //SW
        reg_dst =0; //don't care
        alu_src =1;
    mem_to_reg =0; //don't care
    reg_write =0;
    mem_read =0;
    mem_write =1;
    end 
        default: begin
    reg_dst =0;
    alu_src =0;
    mem_to_reg =0;
    reg_write =0;
    mem_read =0;
    mem_write =0;
    end
    endcase
end

endmodule