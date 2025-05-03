module cpu (
    input clk,rstn
    );

    wire [31:0] addr;
    wire [31:0] instruction;
    
    wire [31:0] fixednextpc; //최종 주소

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
    wire [31:0] ifid_pc, ifid_instruction, ifid_nextpc;
    IFIDreg         (
                    clk, 
                    rstn,
                    addr, 
                    instruction, 
                    nextpc,
                    
                    ifid_pc,
                    ifid_instruction,
                    ifid_nextpc
                    );

    //ID

    wire [5:0] opcode = ifid_instruction[31:26];
    wire [4:0] rs = ifid_instruction[25:21];
    wire [4:0] rt = ifid_instruction[20:16];
    wire [4:0] rd = ifid_instruction[15:11];
    wire [15:0] imm = ifid_instruction[15:0];
    wire [5:0] funct = ifid_instruction[5:0];

    wire [1:0] ALUop;
    wire RegDst,ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch;

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

    wire [4:0] WriteReg;
    mux #(.WIDTH(5))
        muxforregisters
                    (rt,
                    rd,
                    RegDst,
                    WriteReg
                    );

    
    wire [31:0] writedata; //input인데 미리 선언?으로 들어감
    wire [31:0] readdata1,readdata2;
    regsiters regs  (clk,
                    rstn,
                    memwb_RegWrite, //이거 사용
                    rs, //id 단계 사용
                    rt, //id 단계 사용
                    memwb_WriteReg,
                    memwb_writedata,
                    readdata1,
                    readdata2
                    );
    
    wire[31:0] extended_imm;
    singextension # (.MSB(32))
                    set(
                    imm,
                    extended_imm
                    );

    //IDEX 
    wire idexRegDst, idexALUSrc, idexMemtoReg, idexRegWrite, idexMemRead, idexMemWrite, idexBranch;
    wire [1:0] idexALUop;
    wire [31:0] idexwritedata, idexextendedimm, idexreaddata1, idexreaddata2;
    wire [31:0] idex_pc,idex_instruction,idex_nextpc;

    wire [5:0] idex_opcode ;
    wire [4:0] idex_rs;
    wire [4:0] idex_rt ;
    wire [4:0] idex_rd ;
    wire [15:0] idex_imm ;
    wire [5:0] idex_funct;

    IDEXreg idexreg (
                    clk,rstn,

                    ifid_pc,ifid_instruction,ifid_nextpc,
                    opcode,rs,rt,rd,imm,funct,
                    ALUop, writedata, extended_imm, readdata1, readdata2, RegDst, ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch, writedata,extended_imm,readdata1,readdata2,

                    idex_pc,idex_instruction,idex_nextpc,
                    idex_opcode,idex_rs, idex_rt,idex_rd, idex_imm,idex_funct,
                    idexALUop,idexwritedata, idexextendedimm,idexreaddata1,idexreaddata2,idexRegDst,idexALUSrc,idexMemtoReg,idexRegWrite,idexMemRead,idexMemWrite,idexBranch,
                    );

    //EX 
    /*          idex_pc,
                    idex_instruction,
                    idex_nextpc,

                    idex_opcode,
                    idex_rs,
                    idex_rt,
                    idex_rd,
                    idex_imm,
                    idex_funct,

                    idexALUop,
                    idexwritedata,
                    idexextendedimm,
                    idexreaddata1,
                    idexreaddata2,
                    idexRegDst,
                    idexALUSrc,
                    idexMemtoReg,
                    idexRegWrite,
                    idexMemRead,
                    idexMemWrite,
                    idexBranch,
                    
                    idexwritedata,
                    idexextended_imm,
                    idexreaddata1,
                    idexreaddata2,
    */
    wire [31:0] idex_mux_readdata2;
    mux #()    muxx(idexreaddata2,
                    idexextended_imm,
                    idexALUSrc, //en이지 이게.
                    idex_mux_readdata2 //32bit
                    );

    wire [3:0] ALUCtrl;
    ALU_control AC (idex_opcode,
                    idex_funct,
                    idexALUop,
                    ALUCtrl //4bit
                    );

    wire [31:0] AR_DMaddr;
    wire zero;
    ALU ALUzero (
                    .src1(idexreaddata1),
                    .src2(idex_mux_readdata2),
                    .ALUCtrl(ALUCtrl),
                    .ALUresult(AR_DMaddr), //4bit
                    .zero(zero)
                    );

    wire b;
    assign b = idexBranch & zero;
    //and (b, Branch, zero);

    wire [31:0] shiftimm;
    shiftmodule sm  (
                    idexextended_imm,
                    shiftimm
                    );

    //EXMEM
    wire [31:0] exmem_mux_readdata2,exmem_AR_DMaddr,exmem_shiftimm;
    wire [3:0] exmem_ALUCtrl;
    wire exmem_zero;
    wire [31:0] exmem_readdata2;
    EXMEMreg emr    (
                    clk,
                    rstn,

                    idex_mux_readdata2,
                    ALUCtrl,
                    AR_DMaddr,
                    zero,
                    shiftimm,

                    idex_pc,
                    idex_instruction,
                    idex_nextpc,
                    idex_opcode,
                    idex_rs,
                    idex_rt,
                    idex_rd,
                    idex_imm,
                    idex_funct,
                    idexALUop,
                    idexwritedata,
                    idexextendedimm,
                    idexreaddata1,
                    idexreaddata2,
                    idexRegDst,
                    idexALUSrc,
                    idexMemtoReg,
                    idexRegWrite,
                    idexMemRead,
                    idexMemWrite,
                    idexBranch,
                    
                    idexwritedata,
                    idexextended_imm,
                    idexreaddata1,
                    idexreaddata2,

                    exmem_mux_readdata2,
                    exmem_ALUCtrl,
                    exmem_AR_DMaddr,
                    exmem_zero,
                    exmem_shiftimm,

                    exmem_pc,
                    exmem_instruction,
                    exmem_nextpc,
                    exmem_opcode,
                    exmem_rs,
                    exmem_rt,
                    exmem_rd,
                    exmem_imm,
                    exmem_funct,
                    exmem_ALUop,
                    exmem_writedata,
                    exmem_extended_imm,
                    exmem_readdata1,
                    exmem_readdata2,
                    exmem_RegDst,
                    exmem_ALUSrc,
                    exmem_MemtoReg,
                    exmem_RegWrite,
                    exmem_MemRead,
                    exmem_MemWrite,
                    exmem_Branch,
                    exmem_writedata,
                    exmem_extended_imm,
                    exmem_readdata1,
                    exmem_readdata2
                    );
    //MEM
    wire [31:0] readdata;
    datamemory DM   (
                    .clk(clk),
                    .rstn(rstn),
                    .address(exmem_AR_DMaddr),
                    .writedata(exmem_readdata2),
                    .MemWrite(exmem_MemWrite),
                    .MemRead(exmem_MemRead),
                    .readdata(readdata)
                    );


    //MEMWB
    
    wire [31:0] memwb_readdata;

    MEMWBreg MWr    (
                    clk,
                    rstn,

                    readdata,

                    exmem_mux_readdata2,
                    exmem_ALUCtrl,
                    exmem_AR_DMaddr,
                    exmem_zero,
                    exmem_shiftimm,

                    exmem_pc,
                    exmem_instruction,
                    exmem_nextpc,
                    exmem_opcode,
                    exmem_rs,
                    exmem_rt,
                    exmem_rd,
                    exmem_imm,
                    exmem_funct,
                    exmem_ALUop,
                    exmem_writedata,
                    exmem_extended_imm,
                    exmem_readdata1,
                    exmem_readdata2,
                    exmem_RegDst,
                    exmem_ALUSrc,
                    exmem_MemtoReg,
                    exmem_RegWrite,
                    exmem_MemRead,
                    exmem_MemWrite,
                    exmem_Branch,
                    exmem_writedata,
                    exmem_extended_imm,
                    exmem_readdata1,
                    exmem_readdata2,

                    memwb_readdata,

                    memwb_mux_readdata2,                     
                    memwb_ALUCtrl,                     
                    memwb_AR_DMaddr,                     
                    memwb_zero,                     
                    memwb_shiftimm,                      
                    memwb_pc,                     
                    memwb_instruction,                     
                    memwb_nextpc,                     
                    memwb_opcode,                     
                    memwb_rs,                     
                    memwb_rt,                     
                    memwb_rd,                     
                    memwb_imm,                     
                    memwb_funct,                     
                    memwb_ALUop,                     
                    memwb_writedata,                     
                    memwb_extended_imm,                     
                    memwb_readdata1,                     
                    memwb_readdata2,                     
                    memwb_RegDst,                     
                    memwb_ALUSrc,                     
                    memwb_MemtoReg,                     
                    memwb_RegWrite,                     
                    memwb_MemRead,                     
                    memwb_MemWrite,                     
                    memwb_Branch,                     
                    memwb_writedata,                     
                    memwb_extended_imm,                     
                    memwb_readdata1,                     
                    memwb_readdata2  
                    );

    //WB
    mux muxforwirtedata
                    (
                    memwb_AR_DMaddr,
                    memwb_readdata,
                    memwb_MemtoReg,
                    memwb_writedata
                    );
    

    wire [31:0] branchaddr;
    ALU aluzeroformux
                    (
                    .src1(nextpc),
                    .src2(shiftimm),
                    .ALUCtrl(4'b0000),
                    .ALUresult(branchaddr),
                    .zero()
                    //output
                    );
    
    mux muxforpc    (
                    .a(nextpc),
                    .b(branchaddr),
                    .en(b),
                    .c(fixednextpc)
                    );
    endmodule

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

module regsiters (
    input clk,rstn,
    input RegWrite, //reg에 write하는지 신호 주는듯?
    input [4:0] rs, rt,
    input [4:0] WriteReg, //regdst로 결정된 rd와 rt값의 mux 결과
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
            end else if (RegWrite && WriteReg!=0) begin
                array[WriteReg]<=writedata;
            end        
        end
        assign readdata1 = array[rs];
        assign readdata2 = array[rt];
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

module dff #(
    parameter WIDTH = 32
    )(
    input clk, rstn,
    input en,
    input [WIDTH-1:0] D,
    output reg [WIDTH-1:0] Q
    );
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            Q<=0;
        end else if(en)begin
            Q<=D;
        end
    end
    endmodule

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

module singextension #(
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
                1'b1: extended_imm = {16'h1111,imm};
            endcase
        end
    endmodule

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

module shiftmodule (
    input [31:0] extended_imm,
    output [31:0] shiftimm
    );
    assign shiftimm = extended_imm <<2;

    endmodule    

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

module IFIDreg (
    input clk, rstn,
    input [31:0] pcin, instructionin, nextpcin,
    output [31:0] pcout, instructionout, nextpcout
    );
    dff #() dffpc (clk, rstn, 1'b1,pcin,pcout);
    dff #() dffint (clk,rstn, 1'b1,instructionin,instructionout);   
    dff #() dffnextpc (clk,rstn,1'b1,nextpcin,nextpcout); 
    endmodule

module IDEXreg (
    input clk,rstn,

    input [31:0] ifid_pcin, ifid_instructionin, ifid_nextpcin,
    input [5:0] opcodein,
    input [4:0] rsin,rtin,rdin,
    input [15:0] immin,
    input [5:0] functin,

    input [1:0] ALUopin,
    input [31:0] writedatain, extended_immin, readdata1in,readdata2in,
    input RegDstin,ALUSrcin, MemtoRegin, RegWritein, MemReadin, MemWritein, Branchin,

    output [31:0] ifid_pcout, ifid_instructionout, ifid_nextpcout,
    output [5:0] opcodeout,
    output [4:0] rsout,rtout,rdout,
    output [15:0] immout,
    output [5:0] functout,

    output [1:0] ALUopout,
    output [31:0] writedataout, extended_immout, readdata1out,readdata2out,
    output RegDstout, ALUSrcout, MemtoRegout,RegWriteout, MemReadout, MemWriteout, Branchout
    );

    dff#() idexpc   (clk, rstn, ifid_pcin,ifid_pcout);
    dff#() idexinstruction (clk, rstn, ifid_instructionin, ifid_instructionpout);
    dff#() idexnextpc (clk, rstn, ifid_nextpcin,ifid_nextpcout);

    dff#(6) idexopcode (clk, rstn, opcodein, opcodeout);
    dff#(5) idexrs (clk,rstn,rsin,rsout);
    dff#(5) idexrt (clk,rstn,rtin,rtout);
    dff#(5) idexrd (clk,rstn,rdin,rdout);
    dff#(16)ideximm (clk,rstn,immin,immout);
    dff#(6) idexfunct (clk,rstn,functin,functout);

    dff #(2) idexaluop (clk, rstn, ALUSrcin, ALUSrcout);
    dff #(1) idexregest (clk, rstn, RegDstin,RegDstout);
    dff #(1) idexalusrc (clk, rstn, ALUSrcin,ALUSrcout);
    dff #(1) idexmemtoreg (clk, rstn, MemtoRegin,MemtoRegout);
    dff #(1) idexregwrite (clk, rstn, RegWritein,RegWriteout);
    dff #(1) idexMemRead (clk, rstn, MemReadin,MemReadout);
    dff #(1) idexmemwrite (clk, rstn, MemWritein,MemWriteout);
    dff #(1) idexbranch (clk, rstn, Branchin,Branchout);

    //dff #(5) idexwritereg (clk, rstn,writeregin,writeregout );
    dff #() idexwritedata (clk, rstn, writedatain, writedataout );
    dff #() idexextendedimm (clk, rstn, extended_immin, extended_immout );
    dff #() idexreaddata1 (clk, rstn, readdata1in ,readdata1out );
    dff #() idexreaddata2 (clk, rstn, readdata2in ,readdata2out );
    endmodule
module EXMEMreg (
    input clk,rstn,

    input [31:0] mux_readdata2in,
    input [3:0]  ALUCtrlin,
    input [31:0] AR_DMaddrin,
    input        zeroin,
    input [31:0] shiftimmin,

    input [31:0] ifid_pcin, ifid_instructionin, ifid_nextpcin,
    input [5:0] opcodein,
    input [4:0] rsin,rtin,rdin,
    input [15:0] immin,
    input [5:0] functin,

    input [1:0] ALUopin,
    input [31:0] writedatain, extended_immin, readdata1in, readdata2in,
    input RegDstin,ALUSrcin, MemtoRegin, RegWritein, MemReadin, MemWritein, Branchin,

    output [31:0] mux_readdata2out,
    output [3:0]  ALUCtrlout,
    output [31:0] AR_DMaddrout,
    output        zeroout,
    output [31:0] shiftimmout,

    output [31:0] ifid_pcout, ifid_instructionout, ifid_nextpcout,
    output [5:0] opcodeout,
    output [4:0] rsout,rtout,rdout,
    output [15:0] immout,
    output [5:0] functout,

    output [1:0] ALUopout,
    output [31:0] writedataout, extended_immout, readdata1out,readdata2out,
    output RegDstout, ALUSrcout, MemtoRegout,RegWriteout, MemReadout, MemWriteout, Branchout
    );
    dff #() exmemmux(clk, rstn, mux_readdata2in,mux_readdata2out);
    dff #(4) exmemctrl (clk,rstn,ALUCtrlin,ALUCtrlout);    
    dff #() exmemARDMaddr (clk,rstn,AR_DMaddrin,AR_DMaddrout);
    dff #() exmemzero (clk,rstn,zeroin,zeroout);
    dff #() exmemshift (clk,rstn,shiftimmin,shiftimmout);  

    dff#() exmempc   (clk, rstn, ifid_pcin,ifid_pcout);
    dff#() exmeminstruction (clk, rstn, ifid_instructionin, ifid_instructionpout);
    dff#() exmemnextpc (clk, rstn, ifid_nextpcin,ifid_nextpcout);

    dff#(6) exmemopcode (clk, rstn, opcodein, opcodeout);
    dff#(5) exmemrs (clk,rstn,rsin,rsout);
    dff#(5) exmemrt (clk,rstn,rtin,rtout);
    dff#(5) exmemrd (clk,rstn,rdin,rdout);
    dff#(16)exmemimm (clk,rstn,immin,immout);
    dff#(6) exmemfunct (clk,rstn,functin,functout);

    dff #(2) exmemaluop (clk, rstn, ALUSrcin, ALUSrcout);
    dff #(1) exmemregest (clk, rstn, RegDstin,RegDstout);
    dff #(1) exmemalusrc (clk, rstn, ALUSrcin,ALUSrcout);
    dff #(1) exmemmemtoreg (clk, rstn, MemtoRegin,MemtoRegout);
    dff #(1) exmemregwrite (clk, rstn, RegWritein,RegWriteout);
    dff #(1) exmemMemRead (clk, rstn, MemReadin,MemReadout);
    dff #(1) exmemmemwrite (clk, rstn, MemWritein,MemWriteout);
    dff #(1) exmembranch (clk, rstn, Branchin,Branchout);

    //dff #(5) idexwritereg (clk, rstn,writeregin,writeregout );
    dff #() exmemwritedata (clk, rstn, writedatain, writedataout );
    dff #() exmemextendedimm (clk, rstn, extended_immin, extended_immout );
    dff #() exmemreaddata1 (clk, rstn, readdata1in ,readdata1out );
    dff #() exmemreaddata2 (clk, rstn, readdata2in ,readdata2out );
    endmodule


module MEMWBreg (
    input clk,rstn,

    input [31:0] readdatain,

    input [31:0] mux_readdata2in,
    input [3:0]  ALUCtrlin,
    input [31:0] AR_DMaddrin,
    input        zeroin,
    input [31:0] shiftimmin,

    input [31:0] ifid_pcin, ifid_instructionin, ifid_nextpcin,
    input [5:0] opcodein,
    input [4:0] rsin,rtin,rdin,
    input [15:0] immin,
    input [5:0] functin,

    input [1:0] ALUopin,
    input [31:0] writedatain, extended_immin, readdata1in, readdata2in,
    input RegDstin,ALUSrcin, MemtoRegin, RegWritein, MemReadin, MemWritein, Branchin,

    output [31:0] readdataout,

    output [31:0] mux_readdata2out,
    output [3:0]  ALUCtrlout,
    output [31:0] AR_DMaddrout,
    output        zeroout,
    output [31:0] shiftimmout,

    output [31:0] ifid_pcout, ifid_instructionout, ifid_nextpcout,
    output [5:0] opcodeout,
    output [4:0] rsout,rtout,rdout,
    output [15:0] immout,
    output [5:0] functout,

    output [1:0] ALUopout,
    output [31:0] writedataout, extended_immout, readdata1out,readdata2out,
    output RegDstout, ALUSrcout, MemtoRegout,RegWriteout, MemReadout, MemWriteout, Branchout
    );

    dff #() memwbreaddata(clk,rstn,readdatain,readdataout);    


    dff #() exmemmux(clk, rstn, mux_readdata2in,mux_readdata2out);
    dff #(4) exmemctrl (clk,rstn,ALUCtrlin,ALUCtrlout);    
    dff #() exmemARDMaddr (clk,rstn,AR_DMaddrin,AR_DMaddrout);
    dff #() exmemzero (clk,rstn,zeroin,zeroout);
    dff #() exmemshift (clk,rstn,shiftimmin,shiftimmout);  

    dff#() exmempc   (clk, rstn, ifid_pcin,ifid_pcout);
    dff#() exmeminstruction (clk, rstn, ifid_instructionin, ifid_instructionpout);
    dff#() exmemnextpc (clk, rstn, ifid_nextpcin,ifid_nextpcout);

    dff#(6) exmemopcode (clk, rstn, opcodein, opcodeout);
    dff#(5) exmemrs (clk,rstn,rsin,rsout);
    dff#(5) exmemrt (clk,rstn,rtin,rtout);
    dff#(5) exmemrd (clk,rstn,rdin,rdout);
    dff#(16)exmemimm (clk,rstn,immin,immout);
    dff#(6) exmemfunct (clk,rstn,functin,functout);

    dff #(2) exmemaluop (clk, rstn, ALUSrcin, ALUSrcout);
    dff #(1) exmemregest (clk, rstn, RegDstin,RegDstout);
    dff #(1) exmemalusrc (clk, rstn, ALUSrcin,ALUSrcout);
    dff #(1) exmemmemtoreg (clk, rstn, MemtoRegin,MemtoRegout);
    dff #(1) exmemregwrite (clk, rstn, RegWritein,RegWriteout);
    dff #(1) exmemMemRead (clk, rstn, MemReadin,MemReadout);
    dff #(1) exmemmemwrite (clk, rstn, MemWritein,MemWriteout);
    dff #(1) exmembranch (clk, rstn, Branchin,Branchout);

    //dff #(5) idexwritereg (clk, rstn,writeregin,writeregout );
    dff #() exmemwritedata (clk, rstn, writedatain, writedataout );
    dff #() exmemextendedimm (clk, rstn, extended_immin, extended_immout );
    dff #() exmemreaddata1 (clk, rstn, readdata1in ,readdata1out );
    dff #() exmemreaddata2 (clk, rstn, readdata2in ,readdata2out );
    endmodule