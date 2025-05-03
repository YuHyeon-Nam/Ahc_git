module cache (
    input clk, rstn,
    input i_cpu_req,i_cpu_write,
    input [5:0] i_cpu_addr,
    input [31:0] i_cpu_wdata,
    output o_cpu_resp,
    output [31:0] o_cpu_rdata,

    output o_mem_req, o_mem_write,
    output [5:0] o_mem_addr,
    output [31:0] o_mem_wdata,
    input i_mem_resp, //response
    input [31:0] i_mem_rdata
);
    //output no reg -> 내부 신호로 처리 후 넘기는 방식을 선택

reg [3:0] validmem, wbmem;
wire cpuen = i_cpu_req & o_cpu_resp; // hand shake
wire cpuwe = i_cpu_req & o_cpu_resp & i_cpu_write; // en에 추가 조건이라 생각하면 이해완.
wire cpure = i_cpu_req & o_cpu_resp & ~i_cpu_write;

wire memen = o_mem_req & i_mem_resp;
wire memwe = o_mem_req & i_mem_resp & o_mem_write;
wire memre = o_mem_req & i_mem_resp & ~o_mem_write;

wire ccwe = memre | cpuwe; //cache write enable
wire [1:0] ccwa = i_cpu_addr[1:0]; //write address
wire ccre = i_cpu_req;
wire [1:0] ccra = i_cpu_addr[1:0]; //read address
//cache는 index 부분을 통해 data를 확인 -> addr 중 하위 2bit만을 사용

reg ccred; // ccre는 레벨 트리거로 동작하기 때문에, 엣지 트리거와 동시에 변경하면 불안정한신호
// 이를 방지하기 위해 엣지 트리거로 전달해 동기화 신호에 안정된 신호 전달
reg validrd,wbrd; // valid와 writeback의 유효성 확인 신호 reading data?
wire [3:0] tagrd;
wire [31:0] datard;

reg memwed; //마찬가지로 엣지 트리거 사용을 위함

always @(posedge clk, negedge rstn) begin
    if (!rstn) ccred<=0; //초기화
    else ccred<=ccre; 
end

wire hit = ccred & validrd && tagrd == i_cpu_addr[5:2];
//(cred & validrd) && (tagrd == i_cpu_addr[5:2]) &와 &&는 우선순위 동일 ==는 더 높음.

wire empty = ccred & ~validrd; //ccred는 준비되어있으나 데이터 값(유효)이 없는 경우
wire diff = ccred & validrd && tagrd != i_cpu_addr[5:2];
//위에 보니까 따로 tag index offset 구분 안한 느낌
//hit과 동일하지만, index에 대해 tag값이 다른 경우 diff-> 1

wire miss = empty|diff; //즉 tag값이 다르거나, valid하지 않은 경우를 cache miss로 정함
wire memno = hit || ccred&~wbrd&i_cpu_write; // 메모리 동작할 필요 없음. 즉 안넘김
wire memwb = diff & wbrd; //tag값이 다른 경우 writeback
wire memrd = miss & ~i_cpu_write; // memory에서 data를 읽어오는 경우는 miss가 일어나고 read인경우

assign o_cpu_resp = hit || memno || (memrd ? memre : memwe);
assign o_cpu_rdata = hit? datard : memre?i_mem_rdata: 'bX;

always @(posedge clk, negedge rstn) begin
    if (!rstn)  memwed  <=0;
    else        memwed  <=memwe;
end

assign o_memreq = ~memwed&(memwb|memrd);
// memory we가 일어나지 않은 상태에서, (중복방지?)
//writeback 혹은 read data 신호가 발생시 req요청을 보냄.(접근해야한다는 의미)

assign o_mem_addr = memwb?{tagrd,i_cpu_addr[1:0]} : i_cpu_addr; //write back이 일어난 경우엔, tag값을 새로 저장 및 way값을 가져옴

//write back이 아닌 경우엔 i_cpu_addr임. 그대로 사용. 즉, read상황을 이야기하는건가?
assign o_mem_wdata = datard; //writeback 상황에서 데이터를 받음. 그리고 이 값은 cache에 저장된 data와 동일하여 가져옴
assign o_mem_write = wbrd; //writeback 신호에 따라, main memory에 write 신호를 전달.

//cache controller
always @(posedge clk, negedge rstn)
    if (!rstn) validmem<=0;
    else if (ccwe) validmem[ccwa] <= 1;

always@(posedge clk, negedge rstn)
    if (!rstn) validrd <=0;
    else if (ccwe) validrd <=validmem[ccra];

always@(posedge clk, negedge rstn)
    if (!rstn) wbmem <=0;
    else if (cpuwe) wbmem[ccwa] <=1;
    else if (memre) wbmem[ccwa] <=0;
    else if (memwe) wbmem[ccwa] <=i_cpu_write;

always@(posedge clk, negedge rstn)
    if (!rstn) wbrd <=0;
    else if (ccre) wbrd <= wbmem[ccra];

wire [3:0] tagwd = memre? o_mem_addr[5:2]: cpuwe? i_cpu_addr[5:2]:'bX;
//tag write data, tag값이 불일치 한 경우 적음.
//메모리가 re상태면 메모리 주소에서 index 하위 4비트를 가져옴(tag값).
//re가 아닌 경우 cpu we인지 확인. 그 경우 cpu 주소 하위 4비트 가져옴

wire [31:0] datawd = memre? i_mem_rdata: cpuwe?i_cpu_wdata: 'bX;
//data write data?라고 해야하나 data를 직접적으로 써야하는 경우임.

tpsram #(.DEPTH(4),. WIDTH(4)) u_tag(clk, ccwe,ccwa,tagwd,ccre,ccra,tagrd);
tpsram #(.DEPTH(4),. WIDTH(32)) u_data(clk, ccwe,ccwa,datawd,ccre,ccra,datard);
//위 sram 두개 -> 투포트?


endmodule