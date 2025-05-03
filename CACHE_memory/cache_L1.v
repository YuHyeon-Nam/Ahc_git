module cache_L1 (
    input clk,rstn,
    input [31:0] addr,datain,
    input we,re,
    output reg [31:0] dataout,
    output reg hit,valid
);

parameter TAGWIDTH = 21;
parameter INDEXWIDTH = 5;
parameter  OFFSETWIDTH= 6;
parameter  BLOCKSIZE = 64;
parameter SETSIZE = 4; //4-way
parameter SETCOUNT = 1 << INDEXWIDTH; //32세트, 2진수 8비트 가정, 5번 shift 2^5-> 32비트.

//캐시 메모리 배열
reg [31:0] datamem [0:SETCOUNT-1][0:SETCOUNT-1][0:BLOCKSIZE/4-1];
//데이터 (64B = 16워드)
reg [TAGWIDTH-1:0] tagmem [0:SETCOUNT-1][0:SETCOUNT-1]; //각 라인 태그 저장
reg validmem [0:SETCOUNT-1][0:SETCOUNT-1];
reg dirtymem [0:SETCOUNT-1][0:SETCOUNT-1]; //캐시 데이터가 메모리와 달라진 경우 표시. 즉 작성시 무조건 표시?
reg [1:0] lrumem [0:SETCOUNT-1][0:SETCOUNT-1];//LRU 카운터, 즉 LRU 교체를 위한 우선순위 정보

wire [TAGWIDTH-1:0] tag = addr[31:OFFSETWIDTH+INDEXWIDTH];
wire [INDEXWIDTH-1:0] index = addr[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [OFFSETWIDTH-1:0] offset = addr[OFFSETWIDTH-1:0];
//addr에서 31~11는 tag에 할당, index는 10~6에 할당, offset은 5~0에 할당.
//index는 set선택, j는 way(라인=블록)선택, offset은 특정 word 선택
//offset은 [5:0]이 존재하는데 [5:2]만 사용 상위 4bit -> 워드(0~15)를 지정
//하위 2bit은 byte를 지정하는 부분임. 워드->바이트 선택의 구조인듯.
//64바이트 캐리 라인에서 워드 4바이트를 선택하기 위해 사용되는데,
//4비트만으로 지정가능.
integer i,j;
reg [1:0] lrumin;
reg [1:0] lrureplace; //cache miss 발생한 way를 가리킴

always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        for (i=0; i<SETCOUNT; i=i+1) //setcount(5) -> 4까지만 작동=4번작동
            for(j=0; j<SETSIZE; j=j+1)begin //setsize(4) - 4way
                validmem[i][j]<=0;
                dirtymem[i][j]<=0;
                lrumem[i][j]<=j; //여기서 j를 넣는게 초기화(0이 가장 최근이란 뜻으로 쓰이므로)
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
                if(re)begin
                    dataout<=datamem[index][j][offset[5:2]];//32비트워드 읽음
                    //세트->way->word 표현
                    valid<=1;
                    //validmem과 valid는 다른것. validmem=캐시라인 유효 데이터
                    //valid는 출력신호. 읽기 동작의 결과가 유효한지 cpu에 알려줌.
                end
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
                    if(i!=j && lrumem[index][i]<3)
                    //좌변, 해당 인덱스에 다른 way들을 확인(?)
                    //우변, 다른 라인들을 '덜최근'으로 밀어냄.
                        lrumem[index][i]<=lrumem[index][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
                    
            end
        end
        if(!hit && (re||we))begin //미스처리
            //LRU 교체
            lrumin=3;//(최대 우선순위 설정,즉 3이상 LRUMEM값 찾기)
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[index][j]>=lrumin) begin
                    lrumin=lrumem[index][j];
                    //최대 우선순위가 3이었잖아? 근데 4가 있으면 4이상을 찾아야하니
                    //그 값으로 업데이트하는거임!!
                    lrureplace=j;
                    //업데이트 동시에 그 위치(way) 저장.
                end
            end
            //새 데이터 할당
            tagmem[index][lrureplace]<=tag;
            //새 태그 저장
            validmem[index][lrureplace]<=1;
            dirtymem[index][lrureplace]<=we?1:0;
            if(we)
                datamem[index][lrureplace][offset[5:2]]<=datain;
            lrumem[index][lrureplace]<=0;
            for(i=0;i<SETSIZE;i=i+1)
                if(i!=lrureplace&&lrumem[index][i]<3)
                    lrumem[index][i]<=lrumem[index][i]+1;
        end        
    end
end

endmodule