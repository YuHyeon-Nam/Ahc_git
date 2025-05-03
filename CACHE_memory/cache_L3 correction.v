module cache_L3_corr (
    //다중코어 사용 전재
    input clk,rstn,
    input [31:0] addrcore1,addrcore2,dataincore1,dataincore2,
    input wecore1,wecore2,recore1,recore2,
    //DRAM 요청 인터페이스
    input [511:0] dramdata, //dram 64byte 블록(512bit)
    input dramready, // dram 데이터 준비 신호

    output reg [31:0] dataoutcore1,dataoutcore2,
    output reg hitcore1,hitcore2,validcore1,validcore2,
    output reg memreq, //dram 신호
    
    output reg [511:0] wbdata,
    output reg wbreq
);

parameter TAGWIDTH = 14; // 32->256KB
parameter INDEXWIDTH = 12;
parameter  OFFSETWIDTH= 6;
parameter  BLOCKSIZE = 64;
parameter SETSIZE = 16; //16-way
parameter SETCOUNT = 1 << INDEXWIDTH;

//캐시 메모리 배열
reg [31:0] datamem [0:SETCOUNT-1][0:SETSIZE-1][0:BLOCKSIZE/4-1];
//데이터 256세트 8way
reg [TAGWIDTH-1:0] tagmem [0:SETCOUNT-1][0:SETSIZE-1]; //각 라인 태그 저장
reg validmem [0:SETCOUNT-1][0:SETSIZE-1];
reg dirtymem [0:SETCOUNT-1][0:SETSIZE-1]; //캐시 데이터가 메모리와 달라진 경우 표시. 즉 작성시 무조건 표시?
reg [3:0] lrumem [0:SETCOUNT-1][0:SETSIZE-1];//16way -> 4비트로 확장
reg [1:0] mesimem [0:SETCOUNT-1][0:SETSIZE-1];//m,e,s,i
//각 캐시 라인(SET * way)에 mesi 상태 저장. 총 set*set만큼있음.

//주소 분할
wire [TAGWIDTH-1:0] tagcore1 = addrcore1[31:OFFSETWIDTH+INDEXWIDTH];
wire [TAGWIDTH-1:0] tagcore2 = addrcore2[31:OFFSETWIDTH+INDEXWIDTH];
wire [INDEXWIDTH-1:0] indexcore1 = addrcore1[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [INDEXWIDTH-1:0] indexcore2 = addrcore2[OFFSETWIDTH+INDEXWIDTH-1:OFFSETWIDTH];
wire [OFFSETWIDTH-1:0] offsetcore1 = addrcore1[OFFSETWIDTH-1:0];
wire [OFFSETWIDTH-1:0] offsetcore2 = addrcore2[OFFSETWIDTH-1:0];
//addr에서 31~11는 tag에 할당, index는 10~6에 할당, offset은 5~0에 할당.
//index는 set선택, j는 way(라인=블록)선택, offset은 특정 word 선택
integer i,j;
reg [3:0] lrumin;
reg [3:0] lrureplace; //교체 대상 way
reg [3:0] hitwaycore1,hitwaycore2;
reg [31:0] pipelinedata1, pipelinedata2;
reg hitcore1reg,hitcore2reg,validcore1reg,validcore2reg;

// main cache logic
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        for (i=0; i<SETCOUNT; i=i+1) //setcount(5) -> 4까지만 작동=4번작동
            for(j=0; j<SETSIZE; j=j+1)begin //setsize(4) - 4way
                validmem[i][j]<=0;
                dirtymem[i][j]<=0;
                lrumem[i][j]<=j[3:0]; //여기서 j를 넣는게 초기화(0이 가장 최근이란 뜻으로 쓰이므로)
                tagmem[i][j]<=0;
                mesimem[i][j]<=2'b00; //invalid 초기화
            end
        hitcore1<=0;
        hitcore2<=0;
        memreq<=0;
        wbreq <=0;
    end else begin //정상동작
        hitcore1<=0; //동기식 설계에서 기본값을 설정하기 위한 패턴.
        hitcore2<=0;
        memreq<=0;
        wbreq<=0;

        //cache hit check for core1
        for(j=0; j<SETSIZE;j=j+1)begin
            if(validmem[indexcore1][j] && tagmem[indexcore1][j]==tagcore1)begin
                hitcore1<=1;
                hitwaycore1<=j[3:0];
                case (mesimem[indexcore1][j])
                2'b11: begin //modified, 데이터 및 더티 업데이트.
                    if (wecore1)begin
                        datamem[indexcore1][j][offsetcore1[5:2]]<=dataincore1;
                        dirtymem[indexcore1][j]<=1;
                    end
                end
                2'b10: begin //exclusive, modified로 전이, 더티비트 설정
                    if (wecore1)begin
                        datamem[indexcore1][j][offsetcore1[5:2]]<=dataincore1;
                        dirtymem[indexcore1][j]<=1;
                        mesimem[indexcore1][j]<=2'b11; // modified??
                    end else if (recore1)begin
                        mesimem[indexcore1][j]<=2'b01; // shared??
                    end
                end
                2'b01: begin //shared
                    if (wecore1)begin
                        datamem[indexcore1][j][offsetcore1[5:2]]<=dataincore1;
                        dirtymem[indexcore1][j]<=1; 
                        mesimem[indexcore1][j]<=2'b11; /// modified
                        for (i=0; i<SETCOUNT; i=i+1)
                            for(j=0; j<SETSIZE; j=j+1)
                                if(validmem[i][j] && tagmem[i][j]==tagcore1)
                                    mesimem[i][j]<=2'b00;
                            /*mesimem[indexcore2][j]<=2'b00; // invalid
                            //다른 코어 동일 데이터 무효화(간소화)*/
                    end
                end
                2'b00:hitcore1<=0;  //invalid
            endcase
                lrumem[indexcore1][j]<=0;
                for(i=0; i<SETSIZE; i=i+1)
                    if(i!=j && lrumem[indexcore1][i]<15)
                        lrumem[indexcore1][i]<=lrumem[indexcore1][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
            end
        end

        //cache hit check for core2
        for(j=0; j<SETSIZE;j=j+1)begin
            if(validmem[indexcore2][j] && tagmem[indexcore2][j]==tagcore2)begin
                hitcore2<=1;
                hitwaycore2<=j[3:0]; // 3:0??
                case (mesimem[indexcore2][j])
                    2'b11: begin //modified
                        if (wecore2)begin
                            datamem[indexcore2][j][offsetcore2[5:2]]<=dataincore2;
                            dirtymem[indexcore2][j]<=1;
                        end
                    end
                    2'b10: begin //exclusive
                        if (wecore2)begin
                            datamem[indexcore2][j][offsetcore2[5:2]]<=dataincore2;
                            dirtymem[indexcore2][j]<=1;
                            mesimem[indexcore2][j]<=2'b11; // modified??
                        end else if (recore2)begin
                            mesimem[indexcore2][j]<=2'b01; // shared??
                        end
                    end
                    2'b01: begin //shared
                        if (wecore2)begin
                            datamem[indexcore2][j][offsetcore2[5:2]]<=dataincore2;
                            dirtymem[indexcore2][j]<=1; 
                            mesimem[indexcore2][j]<=2'b11; /// modified
                            for (i=0; i<SETCOUNT; i=i+1)
                            for(j=0; j<SETSIZE; j=j+1)
                                if(validmem[i][j] && tagmem[i][j]==tagcore2)
                                    mesimem[i][j]<=2'b00;
                            /*mesimem[indexcore2][j]<=2'b00; // invalid
                            //다른 코어 동일 데이터 무효화(간소화)*/
                        end
                    end
                    2'b00: begin //invalid
                        hitcore2<=0; // 무효 상태 -> no hit
                    end
                endcase
                //LRU 업데이트
                lrumem[indexcore2][j]<=0; //0을 통해서 가장 최근에 사용됨으로 표시.
                //39번 코드 참고
                for(i=0; i<SETSIZE; i=i+1)
                    if(i !=j && lrumem[indexcore2][i]<15)
                    //좌변, 해당 인덱스에 다른 way들을 확인(?)
                    //우변, 다른 라인들을 '덜최근'으로 밀어냄.
                        lrumem[indexcore2][i]<=lrumem[indexcore2][i]+1; //lrumem[index][i]값에 +1하는거임. 즉, 밀어내게 됨. 0이 가장 최신이니.
            end
        end

        //cache miss 처리 for core1
        if(!hitcore1 && (recore1||wecore1))begin
            lrumin=15;
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[indexcore1][j]>=lrumin) begin
                    lrumin=lrumem[indexcore1][j];
                    lrureplace=j[3:0];
                end
            end
            // Write-back if dirty
            if (validmem[indexcore1][lrureplace] && dirtymem[indexcore1][lrureplace]) begin
                wbreq <= 1;
                for (i = 0; i < BLOCKSIZE/4; i = i + 1)
                    wbdata[i*32+:32] <= datamem[indexcore1][lrureplace][i];
            end
            //DRAM 요청 for core1
            memreq<=1;
            if(dramready)begin
                //load from dram to 64byte block
                for(i=0; i<BLOCKSIZE/4;i=i+1)
                    datamem[indexcore1][lrureplace][i]<=dramdata[i*32+:32];
                tagmem[indexcore1][lrureplace]<=tagcore1;
                validmem[indexcore1][lrureplace]<=1;
                dirtymem[indexcore1][lrureplace]<=wecore1 ? 1:0;
                mesimem[indexcore1][lrureplace]<=wecore1 ? 2'b11:2'b01; // modified

                if(wecore1)
                datamem[indexcore1][lrureplace][offsetcore1[5:2]]<=dataincore1;
            lrumem[indexcore1][lrureplace]<=0;
            for(i=0;i<SETSIZE;i=i+1)
                if(i!=lrureplace&&lrumem[indexcore1][i]<15)
                    lrumem[indexcore1][i]<=lrumem[indexcore1][i]+1;
            end
        end
        //cache miss 처리 for core2
        if(!hitcore2 && (recore2 || wecore2))begin
            //L1과 DRAM간 데이터 전송 처리예시
            //mem_load[index][lrureplace] = dram_data;
            //LRU 교체
            lrumin=15;//(최대 우선순위 설정,즉 3이상 LRUMEM값 찾기)
            for(j=0; j<SETSIZE; j=j+1)begin
                if (lrumem[indexcore2][j]>=lrumin) begin
                    lrumin=lrumem[indexcore2][j];
                    //최대 우선순위가 3이었잖아? 근데 4가 있으면 4이상을 찾아야하니
                    //그 값으로 업데이트하는거임!!
                    lrureplace=j[3:0];
                    //업데이트 동시에 그 위치(way) 저장.
                end
            end
            // Write-back if dirty
            if (validmem[indexcore2][lrureplace] && dirtymem[indexcore2][lrureplace]) begin
                wbreq <= 1;
                for (i = 0; i < BLOCKSIZE/4; i = i + 1)
                    wbdata[i*32+:32] <= datamem[indexcore2][lrureplace][i];
            end
            //DRAM 요청 for core2
            memreq<=1;
            if(dramready)begin
                //load from dram to 64byte block
                for(i=0; i<BLOCKSIZE/4;i=i+1)
                    datamem[indexcore2][lrureplace][i]<=dramdata[i*32+:32];
                tagmem[indexcore2][lrureplace]<=tagcore2;
                validmem[indexcore2][lrureplace]<=1;
                dirtymem[indexcore2][lrureplace]<=wecore2?1:0;
                mesimem[indexcore2][lrureplace]<=wecore2 ? 2'b11:2'b01; // modified
                
                if(wecore2)
                    datamem[indexcore2][lrureplace][offsetcore2[5:2]]<=dataincore2;
                lrumem[indexcore2][lrureplace]<=0;
                for(i=0;i<SETSIZE;i=i+1)
                    if(i!=lrureplace && lrumem[indexcore2][i]<15)
                        lrumem[indexcore2][i]<=lrumem[indexcore2][i]+1;
            end
        end
        hitcore1 <= hitcore1reg;
        hitcore2 <= hitcore2reg;
        validcore1 <=validcore1reg;
        validcore2 <=validcore2reg;
        dataoutcore1<=pipelinedata1;
        dataoutcore2<=pipelinedata2;
        
    end
end
//pipe line output for core1
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        pipelinedata1<=0;
        pipelinedata2<=0;
        validcore1reg<=0;
        validcore2reg<=0;

    end else begin
        //core 1 출력
        if(hitcore1&&recore1 && mesimem[indexcore1][hitwaycore1]!=2'b00)begin
            pipelinedata1<=datamem[indexcore1][hitwaycore1][offsetcore1[5:2]]; //히트 데이터
            validcore1reg <=1;
        end else if (dramready && validmem[indexcore1][lrureplace]) begin
            pipelinedata1 <= datamem[indexcore1][lrureplace][offsetcore1[5:2]]; //미스 후 로드된 데이터
            validcore1reg<=1;
        end else begin
            validcore1reg <=0;
        end
        //core 2 출력
        if(hitcore2&&recore2 && mesimem[indexcore2][hitwaycore2]!=2'b00)begin
            pipelinedata2<=datamem[indexcore2][hitwaycore2][offsetcore2[5:2]]; //히트 데이터
            validcore2reg <=1;
        end else if (dramready && validmem[indexcore2][lrureplace]) begin
            pipelinedata2 <= datamem[indexcore2][lrureplace][offsetcore2[5:2]]; //미스 후 로드된 데이터
            validcore2reg<=1;
        end else begin
            validcore2reg <=0;
        end
    end
end
endmodule