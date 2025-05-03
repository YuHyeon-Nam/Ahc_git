module decoder (
    input [31:0] instr,
    output [5:0] opcode,
    output [4:0] rs,rt,rd,shamt,
    output [5:0] funct,
    output [15:0] imm
);
    assign opcode = instr[31:26];
    assign rs     = instr[25:21];
    assign rt     = instr[20:16];
    assign rd     = instr[15:11];
    assign shamt  = instr[10:6];
    assign funct  = instr[5:0];
    assign imm    = instr[15:0];

endmodule