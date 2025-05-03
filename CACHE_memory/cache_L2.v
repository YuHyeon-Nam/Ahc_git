module cache_L2 (
    input clk,rstn,
    input [31:0] addr,datain,
    input we,re,

    input [511:0] dramdata, //dram 64byte 블록(512bit)
    input dramready, // dram 데이터 준비 신호

    output reg [31:0] dataout,
    output reg hit,valid,
    output reg memreq //dram 신호
);

parameter TAGWIDTH = 18; // 32->256KB
parameter INDEXWIDTH = 8;
parameter  OFFSETWIDTH= 6;
parameter  BLOCKSIZE = 64;
parameter SETSIZE = 8; //8-way
parameter SETCOUNT = 1 << INDEXWIDTH; //32세트, 2진수 8비트 가정, 5번 shift 2^5-> 32비트.

//캐시 메모리 배열
reg [31:0] datamem [0:SETCOUNT-1][0:SETCOUNT-1][0:BLOCKSIZE/4-1];
//데이터 256세트 8way
reg [TAGWIDTH-1:0] tagmem [0:SETCOUNT-1][0:SETCOUNT-1]; //각 라인 태그 저장
reg validmem [0:SETCOUNT-1][0:SETCOUNT-1];
reg dirtymem [0:SETCOUNT-1][0:SETCOUNT-1]; //캐시 데이터가 메모리와 달라진 경우 표시. 즉 작성시 무조건 표시?
reg [2:0] lrumem [0:SETCOUNT-1][0:SETCOUNT-1];//8way -> 3비트로 확장

wire [TAGWIDTH-1:0] tag = addr[31:OFFSETWIDTH+INDEXWIDTH];
wire [INDEXWIDTH-1:0] index = addr[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [OFFSETWIDTH-1:0] offset = addr[OFFSETWIDTH-1:0];
//addr에서 31~11는 tag에 할당, index는 10~6에 할당, offset은 5~0에 할당.
//index는 set선택, j는 way(라인=블록)선택, offset은 특정 word 선택
integer i,j;
reg [2:0] lrumin;
reg [2:0] lrureplace; //교체 대상 way
reg [2:0] hitway; //히트된 way
reg [31:0] dataoutreg; // 파이프라인 레지스터
//파이프라인 출력 처리
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        dataoutreg<=0;
        dataout<=0;
        valid<=0;
    end else begin
        if(hit&&re)begin
            dataoutreg<=datamem[index][hitway][offset[5:2]]; //히트 데이터
            dataout <= dataoutreg; // 1사이클 지연
            valid <=1;
        end else if (dramready && validmem[index][lrureplace]) begin
            dataout <= datamem[index][lrureplace][offset[5:2]]; //미스 후 로드된 데이터
            valid <=1;
        end else begin
            valid <=0;
        end

    end
end

// main cache logic
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        for (i=0; i<SETCOUNT; i=i+1) //setcount(5) -> 4까지만 작동=4번작동
            for(j=0; j<SETSIZE; j=j+1)begin //setsize(4) - 4way
                validmem[i][j]<=0;
                dirtymem[i][j]<=0;
                lrumem[i][j]<=j[2:0]; //여기서 j를 넣는게 초기화(0이 가장 최근이란 뜻으로 쓰이므로)
                tagmem[i][j]<=0;
            end
        hit<=0;
        valid<=0;
    end else begin //정상동작
        hit<=0; //동기식 설계에서 기본값을 설정하기 위한 패턴.
        valid<=0; //<=은 비차단 대입이라, 다음 클럭 엣지에서 작용. 안전한 설계 관행

        //cache hit check
        for(j=0; j<SETSIZE;j=j+1)begin
            if(validmem[index][j] && tagmem[index][j]==tag)begin
                hit<=1;
                hitway<=j[2:0];
                //L2는 read 동작을 안해서 비활성화?
                /*if(re)begin
                    dataout<=datamem[index][j][offset[5:2]];//32비트워드 읽음
                    //세트->way->word 표현
                    valid<=1;
                    //validmem과 valid는 다른것. validmem=캐시라인 유효 데이터
                    //valid는 출력신호. 읽기 동작의 결과가 유효한지 cpu에 알려줌.
                end*/
                if(we) begin
                    datamem[index][j][offset[5:2]]<=datain;
                    //여길 보면 지금 캐시메모리(datamem)만 변경되었음
                    //즉, 주메모리(dram등)과는 데이터가 달라진 상태.
                    dirtymem[index][j]<=1;
                    //따라서, dirtymem을 통해 데이터가 달라진 상태라고 표현.
                    //이 값을 받아서 나중에, 주메모리 작성시 and조건으로 묶을 수 있을것.
                end
                //LRU 업데이트
                lrumem[index][j]<=0; //0을 통해서 가장 최근에 사용됨으로 표시.
                //39번 코드 참고
                for(i=0; i<SETSIZE; i=i+1)
                    if(i!=j && lrumem[index][i]<7)
                    //좌변, 해당 인덱스에 다른 way들을 확인(?)
                    //우변, 다른 라인들을 '덜최근'으로 밀어냄.
                        lrumem[index][i]<=lrumem[index][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
                    
            end
        end
        //cache miss 처리
        if(!hit && (re||we))begin
            //L1과 DRAM간 데이터 전송 처리예시
            //mem_load[index][lrureplace] = dram_data;
            //LRU 교체
            lrumin=7;//(최대 우선순위 설정,즉 3이상 LRUMEM값 찾기)
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[index][j]>=lrumin) begin
                    lrumin=lrumem[index][j];
                    //최대 우선순위가 3이었잖아? 근데 4가 있으면 4이상을 찾아야하니
                    //그 값으로 업데이트하는거임!!
                    lrureplace=j[2:0];
                    //업데이트 동시에 그 위치(way) 저장.
                end
            end
            //DRAM 요청
            memreq<=1;
            if(dramready)begin
                //load from dram to 64byte block
                for(i=0; i<BLOCKSIZE/4;i=i+1)
                    datamem[index][lrureplace][i]<=dramdata[i*32+:32];
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
    end
end

endmodule