module Shuf_rom( //zigzag
    input[4:0] addr
    output reg[6:0] data
);

reg[6:0] rom[0:63];
//6:3 column
//2:0 row

initial
begin
    $readmemb("zigzag.txt", rom);
end

assign data <= rom[addr];
endmodule

module Shuf_ram( //quantize
    input clk
    
    input wr
    input[5:0] wr_addr
    input reg[7:0] wr_data
    
    input tb_sel
    input[4:0] addr
    output reg[7:0] data
);

reg[7:0] ram[1:0][63:0];

always @(posedge clk)
begin
    if(wr)
    begin
        ram[wr_addr[5]][wr_addr[4:0]] <= wr_data;
    end else
    begin
        data <= ram[tb_sel][addr];
    end
end
endmodule

module Shuf_buffer(
    input clk
    input rst

    input mv
    
    input wr
    input[6:0] wr_addr
    input[15:0] wr_data
    
    input[3:0] rd_addr
    output[127:0] rd_data
);

reg[2:0] buffer_fsm;

reg[1:0] buffer_id_rd;
reg[1:0] buffer_id_wr;

reg[15:0] buffer[2:0][119:0];

integer i j k;

always @(*)
begin
    for(i=0;i<3;i=i+1) if(buffer_fsm[i])
    begin
        for(j=0;j<120;j=j+1) buffer[i][j] <= 0;
    end
    case(buffer_fsm)
    3'b001: begin buffer_id_rd <= 1; buffer_id_wr <= 2; end
    3'b010: begin buffer_id_rd <= 2; buffer_id_wr <= 0; end
    3'b100: begin buffer_id_rd <= 0; buffer_id_wr <= 1; end
    endcase
end

always @(posedge clk or posedge rst)
begin
    if(rst) buffer_fsm=1;
    else
    begin
        if(mv) buffer_fsm <= {buffer_fsm[1:0] buffer_fsm[2]};
        if(wr) buffer[buffer_id_wr][buf_addr] <= buf_data;
        for(k=0;k<8;k=k+1) rd_data[8*k+:8] <= buffer[buffer_id_rd][buf_addr << 3 + k];
    end
end
endmodule

module Shuf_fetch(
    input clk
    input rst

    input wr
    input[5:0] wr_addr
    input[7:0] wr_data
    
    input[2:0] fsm_in
    input[6:0] huff_counter
    
    input[31:0] data_stream

    input eob
    input quan_tb_sel
    input[3:0] huff_size
    input[3:0] data_zero
    input[3:0] data_len

    output reg buf_notify //notify buffer to flip pages.
    
    output reg buf_wr
    output reg[6:0] buf_addr
    output reg[15:0] buf_data
);
    
reg[2:0] fsm;

reg[3:0] size;
reg zero;
reg sign;
reg[15:0] data;

reg ram_sel;
reg[4:0] ram_addr;
wire[7:0] ram_data;

reg[4:0] rom_addr;
wire[6:0] rom_data;

Shuf_ram qt( //quantize
    .clk(clk)
    
    .wr(wr)
    .wr_addr(wr_addr)
    .wr_data(wr_data)
    
    .tb_sel(ram_sel)
    .addr(ram_addr)
    .data(ram_data)
);

Shuf_rom zz(
    .addr(rom_addr)
    .data(rom_data)
);

always @(posedge clk)
begin
    if (rst)
    begin
        fsm <= 0;
        
        size <= 0;

        zero <= 0;
        sign <= 0;
        data <= 0;

        ram_sel  <= 0;        
        ram_addr <= 0;

        rom_addr <= 0;
            
        buf_wr <= 0;
        buf_addr <= 0;
        buf_data <= 0;
    end else
    begin
        fsm <= fsm_in;
        if (fsm == 2) buf_wr <= 0;
        if (fsm == 4)
        begin
            size <= data_len;

            zero <= data_len == 0;
            sign <= data_stream[31 - huff_size];
            data <= data_stream >> (31 - huff_size - data_len);

            ram_sel  <= quan_tb_sel;        
            ram_addr <= huff_counter[4:0];

            rom_addr <= huff_counter[4:0];
        end
        if (fsm == 5)
        begin
            buf_notify <= #4 ;
            buf_wr <= #4 1;
        
            //this calculate takes 6 cycle latency
            buf_addr <= #4 rom_data;
            if (zero)
            begin
                sign = 0;
                data = 1;
            end
            buf_data = #4 (data + {16{~sign}} << size + sign) * ram_data;
        end
    end
end
endmodule

module Shuffle(
    input clk //this module will fetch data at positive edge.
    input rst //pull high to reset to default status.

    input wr
    input[7:0] wr_quan_tb
    
    input[2:0] fsm

    input quan_tb_gate
    input quan_tb_sel
    input[6:0] huff_counter
    
    input[3:0] huff_size
    input[3:0] data_zero
    input[3:0] data_len
    
    input[31:0] data_stream
    
    input notify
    input[3:0] rd_addr
    output[127:0] rd_data
);

wire tb_sel;
assign tb_sel = quan_tb_gate ? 0 : quan_tb_sel;

reg[5:0] wr_addr;

wire sf_sb_wr;
wire[6:0] sf_sb_wr_addr;
wire[15:0] sf_sb_wr_data;

Shuf_buffer sb(
    .clk(clk)
    .rst(rst)
    
    .notify(notify)
    
    .wr(sf_sb_wr)
    .wr_addr(sf_sb_wr_addr)
    .wr_data(sf_sb_wr_data)
    
    .rd_addr(rd_addr)
    .rd_data(rd_data)
);

Shuf_fetch sf(
    .clk(clk)
    .rst(rst)

    .wr(wr)
    .wr_addr(wr_addr)
    .wr_data(wr_quan_tb)
    
    .fsm_in(fsm)
    .huff_counter(huff_counter)
    
    .data_stream(data_stream)

    .eob(eob)
    .quan_tb_sel(tb_sel)
    .huff_size(huff_size)
    .data_zero(data_zero)
    .data_len(data_len)

    .buf_notify(notify)
    
    .buf_wr(sf_sb_wr)
    .buf_addr(sf_sb_wr_addr)
    .buf_data(sf_sb_wr_data)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_addr <= 0;
    end else
    begin
        if(wr)
        begin
            wr_addr <= wr_addr + 1;
        end
    end
end
endmodule
