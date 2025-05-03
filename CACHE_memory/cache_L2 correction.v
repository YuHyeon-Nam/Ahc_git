module cache_L2_corr (
    input clk,rstn,
    input [31:0] addr,datain,
    input we,re,

    output reg [31:0] dataout,
    output reg hit,valid,
    //L3 요청 인터페이스    
    input L3ready,
    input [511:0] L3data,
    output reg [31:0] L3addr,
    output reg L3req //requset
);

parameter TAGWIDTH = 18; // 32->256KB
parameter INDEXWIDTH = 8;
parameter  OFFSETWIDTH= 6;
parameter  BLOCKSIZE = 64;
parameter SETSIZE = 8; //8-way
parameter SETCOUNT = 1 << INDEXWIDTH; //32세트, 2진수 8비트 가정, 5번 shift 2^5-> 32비트.

//캐시 메모리 배열
reg [31:0] datamem [0:SETCOUNT-1][0:SETSIZE-1][0:BLOCKSIZE/4-1];
//데이터 256세트 8way
reg [TAGWIDTH-1:0] tagmem [0:SETCOUNT-1][0:SETSIZE-1]; //각 라인 태그 저장
reg validmem [0:SETCOUNT-1][0:SETSIZE-1];
reg dirtymem [0:SETCOUNT-1][0:SETSIZE-1]; //캐시 데이터가 메모리와 달라진 경우 표시. 즉 작성시 무조건 표시?
reg [2:0] lrumem [0:SETCOUNT-1][0:SETSIZE-1];//8way -> 3비트로 확장

wire [TAGWIDTH-1:0] tag = addr[31:OFFSETWIDTH+INDEXWIDTH];
wire [INDEXWIDTH-1:0] index = addr[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [OFFSETWIDTH-1:0] offset = addr[OFFSETWIDTH-1:0];
//addr에서 31~11는 tag에 할당, index는 10~6에 할당, offset은 5~0에 할당.
//index는 set선택, j는 way(라인=블록)선택, offset은 특정 word 선택
integer i,j;
reg [2:0] lrumin;
reg [2:0] lrureplace; //교체 대상 way
reg [2:0] hitway; //히트된 way
reg hitreg, validreg;
reg [31:0] dataoutreg; // 파이프라인 레지스터

// main cache logic
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        for (i=0; i<SETCOUNT; i=i+1) //setcount(5) -> 4까지만 작동=4번작동
            for(j=0; j<SETSIZE; j=j+1)begin //setsize(4) - 4way
                validmem[i][j]<=0;
                dirtymem[i][j]<=0;
                lrumem[i][j]<=j[2:0];
                tagmem[i][j]<=0;
            end
        hitreg<=0;
        validreg<=0;
        L3req<=0;
        dataoutreg<=0;
        dataout<=0;

    end else begin //정상동작
        hitreg<=0;
        validreg<=0;
        L3req <=0;

        //cache hit check
        for(j=0; j<SETSIZE;j=j+1)begin
            if(validmem[index][j] && tagmem[index][j]==tag)begin
                hitreg<=1;
                hitway<=j[2:0];
                if(we) begin
                    datamem[index][j][offset[5:2]]<=datain;
                    dirtymem[index][j]<=1;
                end
                if (re) begin
                    dataoutreg <= datamem[index][j][offset[5:2]];
                    validreg <=1;
                end
                //LRU 업데이트
                lrumem[index][j]<=0;
                for(i=0; i<SETSIZE; i=i+1)
                    if(i!=j && lrumem[index][i]<7)
                        lrumem[index][i]<=lrumem[index][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
            end
        end

        //파이프라인 출력 처리 -> hit시 dataout 하는걸로 간소화
        /*if(hit&&re)begin
            dataoutreg<=datamem[index][hitway][offset[5:2]]; //히트 데이터
            dataout <= dataoutreg; // 1사이클 지연
            validreg <=1;
        end else if (L3ready && validmem[index][lrureplace]) begin
            dataout <= datamem[index][lrureplace][offset[5:2]]; //미스 후 로드된 데이터
            validreg <=1;
        end*/

        //cache miss 처리
        if(!hitreg && (re||we))begin
            lrumin=7;
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[index][j]>=lrumin) begin
                    lrumin=lrumem[index][j];
                    lrureplace=j[2:0];
                end
            end
            if(validmem[index][lrureplace] && dirtymem[index][lrureplace]) begin
                L3req <= 1;
                L3addr <= {tagmem[index][lrureplace],index,6'b0};
            end else begin
                L3req <= 1;
                L3addr <= {addr[31:6],6'b0};
            end
            if(L3ready)begin
                for(i=0; i<BLOCKSIZE/4;i=i+1)
                    datamem[index][lrureplace][i]<=L3data[i*32+:32];
                tagmem[index][lrureplace]<=tag;
                validmem[index][lrureplace]<=1;
                dirtymem[index][lrureplace]<=we?1:0;
                
                if(we)
                    datamem[index][lrureplace][offset[5:2]]<=datain;
                lrumem[index][lrureplace]<=0;
                for(i=0;i<SETSIZE;i=i+1)
                    if(i!=lrureplace&&lrumem[index][i]<7)
                        lrumem[index][i]<=lrumem[index][i]+1;
            end
        end        
        //출력 동기화
        hit <= hitreg;
        valid<=validreg;
        dataout<=dataoutreg;
    end
end

endmodule