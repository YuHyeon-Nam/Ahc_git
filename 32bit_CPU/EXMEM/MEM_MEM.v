module mem (
    input clk,reset,mem_read,mem_write,
    input [31:0] address,write_data,
    output reg [31:0] read_data
);
reg [31:0] data_mem [0:255];
always @(posedge clk) begin
    if(mem_write) begin
        data_mem[address[7:0]]<=write_data; //address LSB
        //address[7:0]은 32비트에서 하위 8비트까지의 값을 계산함.
        //그 값이 다시 data_mem에서 작용.
        //그러면 256개 중에서 "그 값"번째 요소에 접근함.
    end
end

always @(*) begin //조합논리, 오른쪽 값이 변하는 경우 발동.
                  //read_data변경은 상관없음.
                  //mem_read, address, data_mem 변하면 발동.
    if (mem_read) begin
        read_data=data_mem[address[7:0]];
    end else begin
        read_data = 32'd0;
    end
end
    
endmodule