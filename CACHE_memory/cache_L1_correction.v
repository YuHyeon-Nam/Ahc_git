module cache_L1_corr (
    input clk,rstn,
    input [31:0] addr,datain,
    input we,re,
    output reg [31:0] dataout,
    output reg hit,valid,
    //L2 요청 인터페이스
    input L2ready,
    input [511:0] L2data,
    output reg [31:0] L2addr,
    output reg L2req // request
);

parameter TAGWIDTH = 21;
parameter INDEXWIDTH = 5;
parameter  OFFSETWIDTH= 6;
parameter  BLOCKSIZE = 64;
parameter SETSIZE = 4; //4-way
parameter SETCOUNT = 1 << INDEXWIDTH; 

//캐시 메모리 배열
reg [31:0] datamem [0:SETCOUNT-1][0:SETSIZE-1][0:BLOCKSIZE/4-1];
//데이터 (64B = 16워드)
reg [TAGWIDTH-1:0] tagmem [0:SETCOUNT-1][0:SETSIZE-1]; 
reg validmem [0:SETCOUNT-1][0:SETSIZE-1];
reg dirtymem [0:SETCOUNT-1][0:SETSIZE-1];
reg [1:0] lrumem [0:SETCOUNT-1][0:SETSIZE-1];

wire [TAGWIDTH-1:0] tag = addr[31:OFFSETWIDTH+INDEXWIDTH];
wire [INDEXWIDTH-1:0] index = addr[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [OFFSETWIDTH-1:0] offset = addr[OFFSETWIDTH-1:0];

integer i,j;
reg [1:0] lrumin;
reg [1:0] lrureplace;

reg hitreg,validreg;
reg[31:0] dataoutreg;

always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        for (i=0; i<SETCOUNT; i=i+1) 
            for(j=0; j<SETSIZE; j=j+1)begin 
                validmem[i][j]<=0;
                dirtymem[i][j]<=0;
                lrumem[i][j]<=j;
                tagmem[i][j]<=0;
            end
        hitreg<=0;
        validreg<=0;
        L2req<=0;
        dataout<=0;
        dataoutreg<=0;

    end else begin 
        hitreg<=0;
        L2req<=0;

        //cache hit check
        for(j=0; j<SETSIZE;j=j+1)begin
            if(validmem[index][j] && tagmem[index][j]==tag)begin
                hitreg<=1;
                if(re)begin
                    dataoutreg<=datamem[index][j][offset[5:2]];//32비트워드 읽음
                    validreg<=1;
                end
                if(we) begin
                    datamem[index][j][offset[5:2]]<=datain;
                    dirtymem[index][j]<=1;
                end
                //LRU 업데이트
                lrumem[index][j]<=0;
                for(i=0; i<SETSIZE; i=i+1)
                    if(i!=j && lrumem[index][i]<3)
                        lrumem[index][i]<=lrumem[index][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
                    
            end
        end
        if(!hitreg && (re||we))begin //미스처리
            //LRU 교체
            lrumin=3;
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[index][j]>=lrumin) begin
                    lrumin=lrumem[index][j];
                    lrureplace=j[1:0];
                end
            end
            //Write back if dirty -> dram에 쓰겠다는거지. 그래서 L2에 전달. 이건 L2에서 L3로도 아마 추가할 거임.
            if(validmem[index][lrureplace] && dirtymem[index][lrureplace]) begin
                L2req <= 1;
                L2addr <= {tagmem[index][lrureplace],index,6'b0};
                //L2가 writeback 할 수 있다 가정.
                // {}는 비트 연결 신호로, 결국 21비트 tagmem 5bit index, 6bit 0을 하나로
                //총 32비트 짜리를 만들어서 넣는거임. 언제?
                //dirty mem 과 valid가 같은, writeback을 해야할때.
            end else begin //writeback이 아닌 경우? l2addr에 그냥 addr을 넣는다?
                L2req <= 1;
                L2addr <=addr;
            end
            if (L2ready) begin
                for (i=0; i<BLOCKSIZE/4; i=i+1)
                    datamem[index][lrureplace][i] <= L2data[i*32+:32];
                    /*l2_data는 512비트 벡터([511:0])입니다.
                    i가 0일 때: [0*32+:32] → [0+:32] → [31:0] (첫 번째 32비트 워드).
                    i가 1일 때: [1*32+:32] → [32+:32] → [63:32] (두 번째 32비트 워드).
                    i가 15일 때: [15*32+:32] → [480+:32] → [511:480] (마지막 32비트 워드).
                    
                    무조건 32비트 단위로 끊기게 됨. 이걸 32비트짜리 datamem에 넣는거지 배열따라서
                    */
                tagmem[index][lrureplace]<=tag;
                validmem[index][lrureplace]<=1;
                dirtymem[index][lrureplace]<=we?1:0;
                if (we)
                    datamem[index][lrureplace][offset[5:2]]<=datain;
                lrumem[index][lrureplace]<=0;
                for(i=0;i<SETSIZE;i=i+1)
                    if(i!=lrureplace&&lrumem[index][i]<3)
                        lrumem[index][i]<=lrumem[index][i]+1;
                
            end
        end
        //출력 동기화
        hit <= hitreg;
        valid <= validreg;
        dataout <= dataoutreg;        
    end
end

endmodule