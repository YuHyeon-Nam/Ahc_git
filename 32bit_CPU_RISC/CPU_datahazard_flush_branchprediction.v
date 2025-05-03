module cpu (
    input clk,rstn
    );

    wire [31:0] addr;
    wire [31:0] instruction;
    
    wire [31:0] fixednextpc; //최종 주소
    wire pc_write; //pc write 제어
    wire stall;
    
    wire flush;

    assign pc_write = ~stall; // stall시 pc 정지

    //IF
    pcmodule pm     (
                    clk,
                    rstn,
                    fixednextpc,
                    addr
                    );

    InstMemory IM   (
                    addr,
                    instruction
                    );
    //여기서 instruction을 분해해서 opcode나 그런걸로 구분해서 넣는게 낫지 않나?
    wire [31:0] nextpc;
    pcadder pa      (
                    clk, rstn,
                    addr,
                    nextpc
                    );


//IFID
    wire [31:0] ifid_pc, ifid_nextpc;
    reg [31:0] ifid_instruction;

    IFIDreg   ifid  (
                    clk, 
                    rstn,

                    addr,
                    instruction, 
                    nextpc,

                    stall,
                    flush,

                    ifid_pc,
                    ifid_instruction,
                    ifid_nextpc
                    );

    /* IFID 모듈에서 한꺼번에 처리
    // IFID flush 처리 - stall 반영 버전
    always @(posedge clk or negedge rstn) begin
    if (!rstn)
        ifid_instruction <= 32'b0;
    else if (exmem_Branch_taken && !stall)  // 브랜치가 실제로 수행될 경우
        ifid_instruction <= 32'b0; // flush: NOP으로 대체
    else if (!stall)
        ifid_instruction <= instruction; // 정상 동작
    end
    */

//ID

    wire [5:0] opcode = ifid_instruction[31:26];
    wire [4:0] rs = ifid_instruction[25:21];
    wire [4:0] rt = ifid_instruction[20:16];
    wire [4:0] rd = ifid_instruction[15:11];
    wire [15:0] imm = ifid_instruction[15:0];
    wire [5:0] funct = ifid_instruction[5:0];

    wire [1:0] ALUop;
    wire RegDst,ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch;

    wire [31:0] branchaddr;

    control cont    (
                    opcode,
                    ALUop,
                    RegDst,
                    ALUSrc,
                    MemtoReg,
                    RegWrite,
                    MemRead,
                    MemWrite,
                    Branch
                    );
    
    wire [31:0] writedata; //input인데 미리 선언?으로 들어감
    wire [31:0] readdata1,readdata2;
    registers regs  (clk,
                    rstn,
                    memwb_RegWrite, //이거 사용
                    rs, //id 단계 사용
                    rt, //id 단계 사용
                    memwb_rd_final,
                    memwb_writedata,
                    readdata1,
                    readdata2
                    );
    
    wire[31:0] extended_imm;
    signextension # (.MSB(32))
                    set(
                    imm,
                    extended_imm
                    );

    //muxforpc
    assign fixednextpc = exmem_Branch_taken ? branchaddr : nextpc;

    // Forwarding 결과 (제어 신호)
    wire [1:0] forwardA, forwardB;  // 2비트씩 보통 사용
    wire [4:0] idex_rs;
    wire [4:0] idex_rt ;

    forwarding_unit fwd_unit (
    .idex_rs(idex_rs),
    .idex_rt(idex_rt),
    .exmem_rd(exmem_rd_final),
    .memwb_rd(memwb_rd_final),
    .exmem_regwrite(exmem_RegWrite),
    .memwb_regwrite(memwb_RegWrite),
    .forwardA(forwardA), // 00: 그대로, 10: EX/MEM, 01: MEM/WB
    .forwardB(forwardB)
    );

    // -------------------- Stall Unit 연결 --------------------
    wire idexMemRead;

    stall_unit hazard_unit (
        .idex_MemRead(idexMemRead),
        .idex_rt(idex_rt),
        .ifid_rs(rs),
        .ifid_rt(rt),
        .stall(stall)
    );

    // stall이 걸릴 경우:
    // - PC write disable
    // - IFID write disable
    // - ID/EX control 신호를 0으로 대체 (NOP)
    // 위 제어는 PC module, IFID 레지스터, control unit 등에서 처리 필요


//IDEX

    wire idexRegDst, idexALUSrc, idexMemtoReg, idexRegWrite, idexMemWrite;
    
    //wire idexBranch는 id/if에서 브랜치 관련 제어 신호로 미리 선언
    
    wire [1:0] idexALUop;
    wire [31:0] idexwritedata, idexextendedimm, idexreaddata1, idexreaddata2;
    wire [31:0] idex_pc,idex_instruction,idex_nextpc;

    wire [5:0] idex_opcode ;
    //wire [4:0] idex_rs;
    //wire [4:0] idex_rt ;
    wire [4:0] idex_rd,idex_rd_final ;
    wire [15:0] idex_imm ;
    wire [5:0] idex_funct;

    IDEXreg idexreg (
                    clk,rstn,

                    ifid_pc,ifid_instruction,ifid_nextpc,
                    opcode,rs,rt,rd,imm,funct,

                    stall,flush,

                    ALUop, extended_imm, readdata1, readdata2, RegDst,
                    ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,

                    idex_pc,idex_instruction,idex_nextpc,
                    idex_opcode,idex_rs, idex_rt, idex_rd_final,

                    idex_imm,idex_funct,
                    idexALUop, idexextendedimm,idexreaddata1,idexreaddata2,
                    idexRegDst,idexALUSrc,idexMemtoReg,idexRegWrite,
                    idexMemRead,idexMemWrite,idexBranch
                    );

//EX 
    //branch_taken
    wire zero;
    wire branch_taken = idexBranch & zero; //branch 제어 신호 - ex 계산 후 ex/mem에 저장

    assign flush = branch_taken;

    // 모듈 출력 신호 선언
    wire [31:0] idex_mux_readdata2;
    wire [3:0] ALUCtrl;

    wire [31:0] ALU_Result;
    
    wire [31:0] zero_alu_input1, zero_alu_input2;
    wire [31:0] shiftimm;
    //wire [31:0] branchaddr;
    
    // EXMEM 출력 신호
    wire [31:0] exmem_mux_readdata2,exmem_ALU_Result;
    wire [3:0] exmem_ALUCtrl;
    wire exmem_zero;
    wire [31:0] exmem_readdata2;
    
    // 모듈 호출
    mux #()    muxforzeroALU_src
                    (idexreaddata2,
                    idexextendedimm,
                    idexALUSrc, //en
                    idex_mux_readdata2 //32bit
                    );


    ALU_control AC (idex_opcode,
                    idex_funct,
                    idexALUop,
                    ALUCtrl //4bit
                    );
    
    muxforhazard #() mfh
                    (
                        idexreaddata1,idexreaddata2,
                        exmem_ALU_Result,memwb_writedata,
                        forwardA,forwardB,
                        zero_alu_input1,zero_alu_input2
                    );

    ALU ALUzero     (
                    .src1(zero_alu_input1),
                    .src2(zero_alu_input2),
                    .ALUCtrl(ALUCtrl),
                    .ALUresult(ALU_Result), //4bit
                    .zero(zero)
                    );


    shiftmodule sm  (
                    idexextendedimm,
                    shiftimm
                    );

    ALU pc_aluformux
                    (
                    .src1(idex_nextpc),
                    .src2(shiftimm),
                    .ALUCtrl(4'b0010),
                    .ALUresult(branchaddr),
                    .zero()
                    //output
                    );

//EXMEM

    EXMEMreg emr    (
                    clk,
                    rstn,

                    zero_alu_input2,
                    ALU_Result,
                    zero,
                    idex_rd,
                    idex_rd_final,

                    idexMemtoReg,
                    idexRegWrite,
                    idexMemRead,
                    idexMemWrite,
                    branch_taken,

                    exmem_readdata2,
                    exmem_ALU_Result,
                    exmem_zero,
                    exmem_rd_final,
                    
                    exmem_MemtoReg,
                    exmem_RegWrite,
                    exmem_MemRead,
                    exmem_MemWrite,
                    exmem_Branch_taken
                    );
//MEM
    wire [31:0] readdata;
    datamemory DM   (
                    .clk(clk),
                    .rstn(rstn),
                    .address(exmem_ALU_Result),
                    .writedata(exmem_readdata2),
                    .MemWrite(exmem_MemWrite),
                    .MemRead(exmem_MemRead),
                    .readdata(readdata)
                    );

//MEMWB
    
    wire [31:0] memwb_readdata;
    wire [31:0] memwb_ALU_Result;
    MEMWBreg MWr    (
                    clk,
                    rstn,

                    readdata,
                    exmem_ALU_Result,

                    exmem_rd,
                    exmem_rd_final,
                    exmem_MemtoReg,
                    exmem_RegWrite,
                    
                    memwb_readdata,
                    memwb_ALU_Result,

                    memwb_rd_final,                                        
                    memwb_MemtoReg,                     
                    memwb_RegWrite
                    );

//WB
    mux muxforwirtedata
                    (
                    memwb_ALU_Result,
                    memwb_readdata,
                    memwb_MemtoReg,
                    memwb_writedata
                    );
    

    endmodule

//IF
module pcmodule (
    input clk, rstn,
    input [31:0] fixednextpc,
    output reg [31:0] addr
    );
    always @(posedge clk or negedge rstn) begin
        if(!rstn) addr <= 0;
        else addr <= fixednextpc;
    end
    endmodule
/*
module InstMemory (
    input [31:0] addr,
    output [31:0] inst
    );
    reg [31:0] memory[0:255];
    initial begin
        $readmemh("instructions.hex",memory);
    end
    assign inst = memory[addr[9:2]];
    endmodule
*/
module InstMemory (
    input [31:0] addr,
    output [31:0] inst
    );
    reg [31:0] memory[0:255];
    initial begin
        memory[0] = 32'h20020005;  // addi $2, $0, 5
        memory[1] = 32'h2003000c;  // addi $3, $0, 12
        memory[2] = 32'h00622020;  // add $4, $3, $2
        memory[3] = 32'hac620000;  // sw $2, 0($3)
        memory[4] = 32'h8c640000;  // lw $4, 0($3)
        memory[5] = 32'h10630001;  // beq $3, $3, 1
    end
    assign inst = memory[addr[9:2]];
    endmodule
    //메모리 값 직접 설정 ver

/*module pcadder (
    input [31:0] a,b,
    input cin,
    output [31:0] sum,
    output [31:0] cout
    );
    fulladd fa0 (sum[0], cout[0], a[0], b[0], cin);
    fulladd fa1 (sum[1], cout[1], a[1], b[1], cout[0]);
    fulladd fa2 (sum[2], cout[2], a[2], b[2], cout[1]);
    fulladd fa3 (sum[3], cout[3], a[3], b[3], cout[2]);
    fulladd fa4 (sum[4], cout[4], a[4], b[4], cout[3]);
    fulladd fa5 (sum[5], cout[5], a[5], b[5], cout[4]);
    fulladd fa6 (sum[6], cout[6], a[6], b[6], cout[5]);
    fulladd fa7 (sum[7], cout[7], a[7], b[7], cout[6]);
    fulladd fa8 (sum[8], cout[8], a[8], b[8], cout[7]);
    fulladd fa9 (sum[9], cout[9], a[9], b[9], cout[8]);

    fulladd fa10 (sum[10], cout[10], a[10], b[10], cout[9]);
    fulladd fa11 (sum[11], cout[11], a[11], b[11], cout[10]);
    fulladd fa12 (sum[12], cout[12], a[12], b[12], cout[11]);
    fulladd fa13 (sum[13], cout[13], a[13], b[13], cout[12]);
    fulladd fa14 (sum[14], cout[14], a[14], b[14], cout[13]);
    fulladd fa15 (sum[15], cout[15], a[15], b[15], cout[14]);
    fulladd fa16 (sum[16], cout[16], a[16], b[16], cout[15]);
    fulladd fa17 (sum[17], cout[17], a[17], b[17], cout[16]);
    fulladd fa18 (sum[18], cout[18], a[18], b[18], cout[17]);
    fulladd fa19 (sum[19], cout[19], a[19], b[19], cout[18]);

    fulladd fa20 (sum[20], cout[20], a[20], b[20], cout[19]);
    fulladd fa21 (sum[21], cout[21], a[21], b[21], cout[20]);
    fulladd fa22 (sum[22], cout[22], a[22], b[22], cout[21]);
    fulladd fa23 (sum[23], cout[23], a[23], b[23], cout[22]);
    fulladd fa24 (sum[24], cout[24], a[24], b[24], cout[23]);
    fulladd fa25 (sum[25], cout[25], a[25], b[25], cout[24]);
    fulladd fa26 (sum[26], cout[26], a[26], b[26], cout[25]);
    fulladd fa27 (sum[27], cout[27], a[27], b[27], cout[26]);
    fulladd fa28 (sum[28], cout[28], a[28], b[28], cout[27]);
    fulladd fa29 (sum[29], cout[29], a[29], b[29], cout[28]);

    fulladd fa30 (sum[30], cout[30], a[30], b[30], cout[29]);
    fulladd fa31 (sum[31], cout[31], a[31], b[31], cout[30]);

        
    endmodule*/

module pcadder (
    input clk, rstn,
    input [31:0] addr,
    output reg [31:0] pc
    );

    always @(posedge clk or negedge rstn)begin
        if(!rstn)
            pc <= 0;
        else
            pc <= addr+4;
    end
        
    endmodule

//IF/ID
module IFIDreg (
    input clk, rstn,
    input [31:0] pcin, instructionin, nextpcin,
    input stall,
    input flush,

    output [31:0] pcout, instructionout, nextpcout
    );

    wire control_write = ~stall|flush;
    wire [31:0] instruction_input = flush ? 32'b0 : instructionin;
    //브랜치의 경우 0으로 만듬. 브랜치 안하는 경우 그대로! (값의 이동을 나타내는거지)
    //이거 flush 구현한거 같은데, flush 신호 만들어서 하는게 더 직관적일듯.

    dff #(.WIDTH(32)) dffpc (clk, rstn, ifid_stall , pcin , pcout);
    dff #(.WIDTH(32)) dffint (clk,rstn, ifid_stall , instruction_input, instructionout);   
    dff #(.WIDTH(32)) dffnextpc (clk,rstn, ifid_stall , nextpcin ,nextpcout); 
    

    endmodule

//ID
module control (
    input [5:0] opcode,
    output reg [1:0] ALUop,
    output reg RegDst, ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch
    );

    wire [8:0] control_output_reg;

    // Opcode 상수 정의 - integer는 기본 32bit라 비추.
    parameter Rtype  = 6'h00;
    parameter lw     = 6'h23;
    parameter sw     = 6'h2b;
    parameter beq    = 6'h04;
    parameter addi   = 6'h08;
    parameter andi   = 6'h0c;

    always @(*) begin
        ALUop = 2'b00;
        RegDst = 1'b0;
        ALUSrc = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 1'b0;

        case (opcode)
        Rtype:begin
            ALUop=2'b10;
            RegDst=1'b1;
            RegWrite =1'b1;
        end
        lw:begin
            ALUop=2'b00;
            RegWrite=1'b1;
            ALUSrc=1'b1;
            MemtoReg=1'b1;
            MemRead=1'b1;
        end
        sw:begin
            ALUop=2'b00;
            RegWrite=1'b0;
            ALUSrc=1'b1;
            MemWrite=1'b1;
        end
        beq:begin
            ALUop=2'b01;
            Branch=1'b1;
        end
        addi:begin
            ALUop=2'b11;
            RegWrite=1'b1;
            ALUSrc=1'b1;
        end
        
        andi:begin
            ALUop=2'b11;
            RegWrite=1'b1;
            ALUSrc=1'b1;
        end

        endcase
    end
    endmodule

module registers (
    input clk,rstn,
    input RegWrite, //reg에 write하는지 신호 주는듯?
    input [4:0] rs, rt,
    input [4:0] memwb_rd, //regdst로 결정된 rd와 rt값의 mux 결과
    input [31:0] writedata,
    output [31:0] readdata1,readdata2
    );

        reg [31:0] array [0:31];

        integer i;
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                for(i=0;i<32;i=i+1)begin
                    array[i]<=0;
                end
            end else if (RegWrite && memwb_rd!=0) begin
                array[memwb_rd]<=writedata;
            end        
        end
        assign readdata1 = array[rs];
        assign readdata2 = array[rt];
    endmodule

module signextension #(
        parameter MSB=32
        )
        (
        input [15:0] imm,
        output reg [MSB-1:0] extended_imm
        );
        //이것도 imm값 변할때마다 뱉어주면 되지 않을까?
        always @(*) begin
            case (imm[15])
                1'b0: extended_imm = {16'h0000,imm};
                1'b1: extended_imm = {16'hFFFF,imm}; //FFFF로 해야함!
            endcase
        end
    endmodule

module forwarding_unit (
    input [4:0] idex_rs, idex_rt,          // ID/EX 단계의 레지스터 번호
    input [4:0] exmem_rd, memwb_rd,        // EX/MEM, MEM/WB 단계의 목적 레지스터
    input exmem_RegWrite,memwb_RegWrite,

    output reg [1:0] forwardA, forwardB
    // 00 reg file 읽음
    // 10 EX/MEM 단계 값으로 포워딩
    // 01 MEM/WB 단계 값으로 포워딩
    );

    always @(*) begin
        // default
        forwardA = 2'b00;
        forwardB = 2'b00;
        //EX harzard : EX/MEM.rd == ID/EX.rs
        if (exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rs))
            forwardA = 2'b10;

        //EX harzard : ex/mem.rd == ID/EX.rt
        if (exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rt))
            forwardB = 2'b10;
        // MEM hazard: MEM/WB.rd == ID/EX.rs
        if (memwb_RegWrite && (memwb_rd != 0) &&
            !(exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rs)) &&
            (memwb_rd == idex_rs))
            //위 조건은 EX hazard랑 겹치지 않아야하는 조건
            forwardA = 2'b01;
        // MEM hazard: MEM/WB.rd == ID/EX.rt
        if (memwb_RegWrite && (memwb_rd != 0) &&
            !(exmem_RegWrite && (exmem_rd != 0) && (exmem_rd == idex_rt)) &&
            (memwb_rd == idex_rt))
            //위 조건은 EX hazard랑 겹치지 않아야하는 조건
            forwardB = 2'b01;
    end
    
    endmodule

module stall_unit (
    input idex_MemRead,
    //input memwb_RegWrite,

    input [4:0] idex_rt,
    input [4:0] ifid_rs, ifid_rt,
    //input [4:0] memwb_rd,

    output stall
    );
    /*forwarding과 stall의 중복은 forward unit에서 이미 확인

    assign stall = idex_MemRead && ((idex_rt == ifid_rs) || (idex_rt==ifid_rt)) // lw data mem에서만 사용 -> 
                                //forwarding이 불가능한 경우 
                                && !(memwb_RegWrite && (memwb_rd !=0)
                                && ((memwb_rd == ifid_rs)|| (memwb_rd == ifid_rt)));
    */
    assign stall = idex_MemRead && ((idex_rt == ifid_rs) || (idex_rt==ifid_rt));

    endmodule

//ID/EX
module IDEXreg (
    input clk,rstn,

    input [31:0] ifid_nextpcin,
    input [5:0] opcodein,
    input [4:0] rsin,rtin,rdin,
    input [15:0] immin,
    input [5:0] functin,
    
    input stall,flush,

    input [1:0] ALUopin,
    input [31:0] extended_immin, readdata1in,readdata2in,
    input RegDstin,ALUSrcin, MemtoRegin, RegWritein, MemReadin, MemWritein, Branchin,

    output [31:0] ifid_nextpcout,
    output [5:0] opcodeout,
    output [4:0] rsout,rtout,rd_final_out,

    output [15:0] immout,
    output [5:0] functout,

    output [1:0] ALUopout,
    output [31:0] extended_immout, readdata1out,readdata2out,
    output RegDstout, ALUSrcout, MemtoRegout,RegWriteout, MemReadout, MemWriteout, Branchout
    );
    
    wire control_write = ~stall|flush;

    wire [1:0] ALUop_gated = flush ? 2'b00 : ALUopin;
    wire RegDst_gated = flush ? 1'b0 : RegDstin;

    wire [4:0] rd_final = RegDst_gated ? rdin : rtin; //rd값 mux 구현

    wire ALUSrc_gated = flush ? 1'b0 : ALUSrcin;
    wire MemtoReg_gated = flush ? 1'b0 : MemtoRegin;
    wire RegWrite_gated = flush ? 1'b0 : RegWritein;
    wire MemRead_gated = flush ? 1'b0 : MemReadin;
    wire MemWrite_gated = flush ? 1'b0 : MemWritein;
    wire Branch_gated = flush ? 1'b0 : Branchin;

    wire [31:0] rs_input = flush ? 32'b0 : rsin;
    wire [31:0] rt_input = flush ? 32'b0 : rtin;
    wire [31:0] rd_final_input = flush ? 32'b0 : rd_final;

    dff #(.WIDTH(32)) idexnextpc (clk, rstn, control_write, ifid_nextpcin,ifid_nextpcout);

    dff#(6) idexopcode (clk, rstn, control_write, opcodein, opcodeout);
    dff#(5) idexrs (clk,rstn, control_write, rs_input, rsout);
    dff#(5) idexrt (clk,rstn, control_write, rt_input, rtout);
    dff#(6) idexrdfinal (clk, rstn, control_write, rd_final_input, rd_final_out);

    dff#(16)ideximm (clk,rstn, control_write, immin, immout);
    dff#(6) idexfunct (clk,rstn, control_write, functin,functout);

    dff #(2) idexaluop (clk, rstn, control_write, ALUop_gated, ALUopout);

    dff #(1) idexregest (clk, rstn, control_write, RegDst_gated, RegDstout);
    
    dff #(1) idexalusrc (clk, rstn, control_write, ALUSrc_gated, ALUSrcout);
    dff #(1) idexmemtoreg (clk, rstn, control_write, MemtoReg_gated, MemtoRegout);
    dff #(1) idexregwrite (clk, rstn, control_write, RegWrite_gated, RegWriteout);
    dff #(1) idexMemRead (clk, rstn, control_write, MemRead_gated, MemReadout);
    dff #(1) idexmemwrite (clk, rstn, control_write, MemWrite_gated, MemWriteout);
    dff #(1) idexBranch (clk, rstn, control_write, Branch_gated, Branchout);

    //dff #(5) idexwritereg (clk, rstn,writeregin,writeregout );
    dff #(.WIDTH(32)) idexextendedimm (clk, rstn,  control_write, extended_immin, extended_immout );
    dff #(.WIDTH(32)) idexreaddata1 (clk, rstn,  control_write, readdata1in ,readdata1out );
    dff #(.WIDTH(32)) idexreaddata2 (clk, rstn,  control_write, readdata2in ,readdata2out );

    endmodule

//EX
module shiftmodule (
    input [31:0] extended_imm,
    output [31:0] shiftimm
    );
    assign shiftimm = extended_imm <<2;

    endmodule    

module ALU_control (
    input [5:0] opcode,funct,
    input [1:0] ALUop,
    output reg [3:0] ALUCtrl
    );
    //임시
    parameter addr = 6'b100000;
    parameter subr = 6'b100010;
    parameter andr = 6'b100100;
    parameter orr  = 6'b100101;
    
    /*비활성화
    parameter Rtype = 2'b10;
    parameter lw=2'b00;
    parameter sw=2'b00;
    parameter beq=2'b01;
    */
    //임시로 설정
    parameter addi   = 6'h08;
    parameter andi   = 6'h0c;

    always @(*) begin
        ALUCtrl = 4'h0; 
        case(ALUop)
        2'b10 :  case(funct)
            addr : ALUCtrl=4'b0010;//add
            subr : ALUCtrl=4'b0110;//sub
            andr : ALUCtrl=4'b0000;//and
            orr  : ALUCtrl=4'b0001;//or
            endcase
        2'b11 :  case(opcode)
            //임시로 ALUCtrl 4'bit 값 설정
            addi : ALUCtrl=4'b0010; //add
            andi : ALUCtrl=4'b0000; //and
            endcase
        2'b00 : ALUCtrl=4'b0010; // lw,sw는 add operation사용
        2'b01 : ALUCtrl=4'b0110; // branch는 sub operation사용
        endcase

    end
    
    endmodule

module ALU (
    input [31:0] src1,src2,
    input [3:0] ALUCtrl,
    output reg [31:0] ALUresult,
    output zero
    );

    always @(*) begin
        case (ALUCtrl)
            4'b0010 : ALUresult = src1 + src2 ;   //add
            4'b0110 : ALUresult = src1 - src2 ;   //sub
            4'b0000 : ALUresult = src1 & src2 ;   //and
            4'b0001 : ALUresult = src1 | src2 ;   //or
        endcase
    end

    assign zero = (ALUresult == 0);

    endmodule

module muxforhazard #(
    parameter WIDTH = 32,
    parameter WIDTH_en = 2
    )
    (
    input [WIDTH-1:0] idex_readdata1_in,idex_readdata2_in,
    input [WIDTH-1:0] exmem_ALU_result ,memwb_writedata,
    input [WIDTH_en-1:0] en_forwardA, en_forwardB,     //forward A/B
    output reg [WIDTH-1:0] idex_readdata1_out, idex_readdata2_out    
    );
    always @(*) begin                                   //forward에서 데이터를 바꿔줘야함!!
        case (en_forwardA)
            default : idex_readdata1_out = idex_readdata1_in;
            2'b10: idex_readdata1_out = exmem_ALU_result;
            2'b01: idex_readdata1_out = memwb_writedata;
        endcase

        case (en_forwardB)
            default : idex_readdata2_out = idex_readdata2_in;
            2'b10: idex_readdata2_out = exmem_ALU_result;
            2'b01: idex_readdata2_out = memwb_writedata;
        endcase
    end
        
    endmodule

//EX/MEM
module EXMEMreg (
    input clk,rstn,

    input [31:0] mux_readdata2in,
    input [31:0] ALU_Resultin,
    input zeroin,
    input [4:0] rdin,
    input [4:0] rd_final_in,

    input MemtoRegin, RegWritein, MemReadin, MemWritein, Branchin,

    output [31:0] mux_readdata2out,
    output [31:0] ALU_Resultout,
    output        zeroout,
    output [4:0] rd_final_out,

    output MemtoRegout,RegWriteout, MemReadout, MemWriteout, Branchout
    );
    dff #() exmemmux(clk, rstn, 1'b1 ,mux_readdata2in,mux_readdata2out);  
    dff #() exmemALU_Result (clk,rstn,1'b1 ,ALU_Resultin,ALU_Resultout);
    dff #() exmemzero (clk,rstn,1'b1 ,zeroin,zeroout);

    dff #(5) exmemrdf (clk, rstn,1'b1 , rd_final_in, rd_final_out);

    dff #(1) exmemmemtoreg (clk, rstn,1'b1 , MemtoRegin,MemtoRegout);
    dff #(1) exmemregwrite (clk, rstn, 1'b1 ,RegWritein,RegWriteout);
    dff #(1) exmemMemRead (clk, rstn,1'b1 , MemReadin,MemReadout);
    dff #(1) exmemmemwrite (clk, rstn,1'b1 , MemWritein,MemWriteout);
    dff #(1) exmembranch (clk, rstn,1'b1 , Branchin,Branchout);

    endmodule

//MEM
module datamemory (
    input clk,rstn, //memory모듈 구현이라 그런가? 필요한듯
    //즉, 순차회로인거임. 이전에는 값이 바뀌면 작동하는 조합 논리 회로였던 반면에.
    input [31:0] address,
    input [31:0] writedata,
    input MemWrite,MemRead,
    
    output[31:0] readdata
    );
    reg [31:0] mem [0:63];
    integer i;
    always @(posedge clk or negedge rstn) begin
        if(!rstn)begin // 초기화
            for(i=0; i<32;i=i+1)begin
                mem[i] <=0;
            end
        end else if (MemWrite) begin
            mem[address[5:0]] <=writedata;
        end
    end
    assign readdata = MemRead? mem[address[5:0]]:'bx;
    
    endmodule

//MEMWB
module MEMWBreg (
    input clk,rstn,

    input [31:0] readdatain,
    input [31:0] ALU_Resultin,
    input [4:0] rdin,
    input [4:0] rd_final_in,
    input MemtoRegin, RegWritein,

    output [31:0] readdataout,
    output [31:0] ALU_Resultout,

    output [4:0] rd_final_out,
    output MemtoRegout,RegWriteout
    );

    dff #() memwbreaddata(clk,rstn,1'b1 ,readdatain,readdataout);    

    dff #() memwbALU_Result(clk, rstn, 1'b1 ,ALU_Resultin, ALU_Resultout);

    dff #(5) exmemrdf (clk, rstn, 1'b1 ,rd_final_in, rd_final_out);
    dff #(1) memwbmemtoreg(clk, rstn, 1'b1 ,MemtoRegin, MemtoRegout);
    dff #(1) memwbregwrite(clk, rstn, 1'b1 ,RegWritein, RegWriteout);

    endmodule

//WB
module mux #(
    parameter WIDTH = 32
    )
    (
    input [WIDTH-1:0] a,b,   //각각 rt, sign extended rt
    input en,           //ALUSrc
    output reg [WIDTH-1:0] c     //ALU 피연산자 src2
    );
    always @(*) begin
        case (en)
            1'b0: c = a;
            1'b1: c = b;
        endcase
    end
        
    endmodule

module dff #(
    parameter WIDTH = 32
    )(
    input clk, rstn,
    input en,
    input [WIDTH-1:0] D,
    output reg [WIDTH-1:0] Q
    );
    //en = 1 입력 전달
    //en = 0 Q 할당이 없어서 이전 값 유지. -> 이건 다른 코딩에서도 유효한듯. 기억하자
    //Q에 뭐가 들어간게 없는데 이전 값 유지?? 업데이트를 안했다??
    //업데이트를 안하니까 유지되는거지.
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            Q<=0;
        end else if(en)begin
            Q<=D;
        end
    end
    endmodule


