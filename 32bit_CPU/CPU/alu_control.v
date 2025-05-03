module alu_control (
    input [1:0] alu_op,
    input [5:0] funct,
    input [5:0] opcode,
    output reg [3:0] alu_control
);
always @(*) begin
    case (alu_op)
    2'b00:
    begin
        case (opcode)
            6'b001000: alu_control=4'b0010;
            6'b001100: alu_control=4'b0000;
            6'b001101: alu_control=4'b0001;
            default:   alu_control=4'b1111;
        endcase
    end
    2'b01: alu_control=4'b0110;//beq -> subtract for comparision
    2'b10: begin // R- type
        case (funct)
        6'b100000: alu_control=4'b0010;
        6'b100010: alu_control=4'b0110;
        6'b100100: alu_control=4'b0000;
        6'b100101: alu_control=4'b0001;
        6'b101010: alu_control=4'b0111;
        default: alu_control=4'b1111;  
        endcase
    end
        default: alu_control =4'b1111;
    endcase
end
    
endmodule