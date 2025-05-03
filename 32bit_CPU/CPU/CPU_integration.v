module cpu_pipeline (
    input wire clk,
    input wire reset
);

    // ---------- IF Stage ----------
    reg [31:0] pc;
    wire [31:0] instr;

    // PC update logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 0;
        else
            pc <= pc + 4;
    end

    // Instruction Memory (dummy ROM for simulation)
    reg [31:0] instr_mem [0:255];
    initial $readmemh("instructions.hex", instr_mem);
    assign instr = instr_mem[pc[9:2]];

    // IF/ID Pipeline Register
    reg [31:0] if_id_pc, if_id_instr;
    always @(posedge clk) begin
        if_id_pc <= pc;
        if_id_instr <= instr;
    end

    // ---------- ID Stage ----------
    wire [5:0] opcode = if_id_instr[31:26];
    wire [4:0] rs = if_id_instr[25:21];
    wire [4:0] rt = if_id_instr[20:16];
    wire [4:0] rd = if_id_instr[15:11];
    wire [5:0] funct = if_id_instr[5:0];
    wire [15:0] imm = if_id_instr[15:0];

    wire [31:0] reg_data1, reg_data2;
    wire [31:0] imm_ext = {{16{imm[15]}}, imm};
    wire [1:0] alu_op;
    wire alu_src, reg_dst, reg_write, mem_to_reg, mem_write;

    assign reg_dst = (opcode == 6'b000000);
    assign alu_src = (opcode != 6'b000000);
    assign mem_to_reg = (opcode == 6'b100011);
    assign reg_write = (opcode != 6'b101011);
    assign mem_write = (opcode == 6'b101011);
    assign alu_op = (opcode == 6'b000000) ? 2'b10 : (opcode == 6'b000100) ? 2'b01 : 2'b00;

    reg [31:0] reg_file [0:31];
    assign reg_data1 = reg_file[rs];
    assign reg_data2 = reg_file[rt];

    // ID/EX Pipeline Register
    reg [1:0] id_ex_alu_op;
    reg id_ex_alu_src, id_ex_reg_dst, id_ex_reg_write, id_ex_mem_to_reg, id_ex_mem_write;
    reg [31:0] id_ex_pc, id_ex_reg_data1, id_ex_reg_data2, id_ex_imm_ext;
    reg [4:0] id_ex_rs, id_ex_rt, id_ex_rd;
    always @(posedge clk) begin
        id_ex_alu_op <= alu_op;
        id_ex_alu_src <= alu_src;
        id_ex_reg_dst <= reg_dst;
        id_ex_reg_write <= reg_write;
        id_ex_mem_to_reg <= mem_to_reg;
        id_ex_mem_write <= mem_write;
        id_ex_pc <= if_id_pc;
        id_ex_reg_data1 <= reg_data1;
        id_ex_reg_data2 <= reg_data2;
        id_ex_imm_ext <= imm_ext;
        id_ex_rs <= rs;
        id_ex_rt <= rt;
        id_ex_rd <= rd;
    end

    // ---------- EX Stage ----------
    wire [3:0] alu_control;
    assign alu_control = (id_ex_alu_op == 2'b00) ? 4'b0010 : // ADD for lw/sw
                         (id_ex_alu_op == 2'b01) ? 4'b0110 : // SUB for beq
                         (id_ex_imm_ext[5:0] == 6'b100000) ? 4'b0010 : // ADD
                         (id_ex_imm_ext[5:0] == 6'b100010) ? 4'b0110 : // SUB
                         (id_ex_imm_ext[5:0] == 6'b100100) ? 4'b0000 : // AND
                         (id_ex_imm_ext[5:0] == 6'b100101) ? 4'b0001 : // OR
                         (id_ex_imm_ext[5:0] == 6'b101010) ? 4'b0111 : // SLT
                         4'b1111; // Default

    wire [31:0] alu_src2 = id_ex_alu_src ? id_ex_imm_ext : id_ex_reg_data2;
    wire [31:0] alu_result = (alu_control == 4'b0010) ? (id_ex_reg_data1 + alu_src2) :
                             (alu_control == 4'b0110) ? (id_ex_reg_data1 - alu_src2) :
                             (alu_control == 4'b0000) ? (id_ex_reg_data1 & alu_src2) :
                             (alu_control == 4'b0001) ? (id_ex_reg_data1 | alu_src2) :
                             (alu_control == 4'b0111) ? (id_ex_reg_data1 < alu_src2 ? 1 : 0) :
                             32'hDEADBEEF; // Invalid op

    wire [4:0] write_reg_ex = id_ex_reg_dst ? id_ex_rd : id_ex_rt;

    // EX/MEM Pipeline Register
    reg [31:0] ex_mem_alu_result, ex_mem_reg_data2;
    reg [4:0] ex_mem_write_reg;
    reg ex_mem_reg_write, ex_mem_mem_to_reg, ex_mem_mem_write;
    always @(posedge clk) begin
        ex_mem_alu_result <= alu_result;
        ex_mem_reg_data2 <= id_ex_reg_data2;
        ex_mem_write_reg <= write_reg_ex;
        ex_mem_reg_write <= id_ex_reg_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_mem_write <= id_ex_mem_write;
    end

    // ---------- MEM Stage ----------
    reg [31:0] data_mem [0:255];
    wire [31:0] mem_read_data;
    assign mem_read_data = data_mem[ex_mem_alu_result[7:0]];

    always @(posedge clk) begin
        if (ex_mem_mem_write) begin
            data_mem[ex_mem_alu_result[7:0]] <= ex_mem_reg_data2;
        end
    end

    // MEM/WB Pipeline Register
    reg [31:0] mem_wb_alu_result, mem_wb_read_data;
    reg [4:0] mem_wb_write_reg;
    reg mem_wb_reg_write, mem_wb_mem_to_reg;
    always @(posedge clk) begin
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_read_data <= mem_read_data;
        mem_wb_write_reg <= ex_mem_write_reg;
        mem_wb_reg_write <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
    end

    // ---------- WB Stage ----------
    wire [31:0] write_data_wb = mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;
    wire [4:0] write_reg_wb = mem_wb_write_reg;
    wire reg_write_wb = mem_wb_reg_write;

    always @(posedge clk) begin
        if (reg_write_wb) begin
            reg_file[write_reg_wb] <= write_data_wb;
        end
    end

endmodule
