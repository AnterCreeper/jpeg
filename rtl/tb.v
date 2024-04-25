`include "define.v"

module tb_HuffDecoder();
reg clk;
reg rst;

reg cfg;

reg wr_huff;
reg wr_sel;
reg[7:0] wr_huff_size;
reg[7:0] wr_huff_code;

wire[7:0] wr_huff_tb;
assign wr_huff_tb = wr_sel ? wr_huff_code : wr_huff_size;

reg[1:0] wr_map_mode;

wire[23:0] rd_addr;
reg[31:0] rd_data;

wire[3:0] size;
wire[3:0] zero;
wire[3:0] len;

wire[2:0] fsm;

wire quan_tb_sel;
wire eob;

wire[6:0] huff_counter;
wire[31:0] data_stream;

wire data_dc;
wire[1:0] data_type;

HuffDecoder huff(
    .clk(clk), //this module will fetch data at positive edge.
    .rst(rst), //pull high to reset to default status.
    
    .cfg(cfg), //pull high to enter config mode or idle respectly.
    
    .wr(wr_huff),
    .wr_sel(wr_sel),
    //{wr, wr_sel}
    //10: huff_size_tb
    //11: huff_code_tb
    //00: idle
    //01: huff_map

    .wr_huff_tb(wr_huff_tb),
    .wr_map_mode(wr_map_mode),
    
    .rd_addr(rd_addr),
    .rd_data(rd_data),
        
    .fsm(fsm),
    .huff_counter(huff_counter),

    .data_type(data_type),
    .quan_tb_sel(quan_tb_sel),
    
    .eob(eob),
    .huff_size(size),
    .data_zero(zero),
    .data_len(len),
    
    .data_stream(data_stream)
);

reg wr_shuff;
reg[7:0] wr_quan_tb;

wire quan_tb_gate;
assign quan_tb_gate = 1;

reg[3:0] shuf_rd_addr;
wire[127:0] shuf_rd_data;

Shuffle shuf(
    .clk(clk), //this module will fetch data at positive edge.
    .rst(rst), //pull high to reset to default status.

    .wr(wr_shuff),
    .wr_quan_tb(wr_quan_tb),

    .fsm(fsm),

    .data_type(data_type),
    .quan_tb_gate(quan_tb_gate),
    .quan_tb_sel(quan_tb_sel),
    .huff_counter(huff_counter),

    .eob(eob),
    .huff_size(size),
    .data_zero(zero),
    .data_len(len),

    .data_stream(data_stream),
    
    .notify(notify),
    .rd_addr(shuf_rd_addr),
    .rd_data(shuf_rd_data)
);

integer fd_input_data;
integer fd_input_code;
integer fd_input_quan;
integer fd_output;
integer fd_output_mat;

reg[31:0] mem[0:32767];
reg[7:0] code[0:255];
reg[7:0] quan[0:64];

assign rd_data = mem[rd_addr];

initial clk = 0;
always #1 clk = ~clk;

initial begin
    rst = 1;
    cfg = 0;
    wr_huff = 0;
    wr_sel = 0;
    wr_huff_size = 0;
    wr_huff_code = 0;
    wr_map_mode = 0;
    wr_shuff = 0;
    shuf_rd_addr = 4'hf;
end

initial begin
    fd_input_data = $fopen("tb_input.bin", "rb");
    if(fd_input_data == 0)
    begin
        $display("$open input file failed") ;
        $stop;
    end
    $fread(mem, fd_input_data);
    $fclose(fd_input_data);
    
    fd_input_code = $fopen("tb_code.bin", "rb");
    if(fd_input_code == 0)
    begin
        $display("$open code file failed") ;
        $stop;
    end
    $fread(code, fd_input_code);
    $fclose(fd_input_code);
    
    fd_input_quan = $fopen("tb_quan.bin", "rb");
    if(fd_input_quan == 0)
    begin
        $display("$open quan file failed") ;
        $stop;
    end
    $fread(quan, fd_input_quan);
    $fclose(fd_input_quan);
    
    fd_output = $fopen("tb_output.bin", "wb");
    if(fd_output == 0)
    begin
        $display("$open output file failed") ;
        $stop;
    end
    fd_output_mat = $fopen("tb_output_mat.bin", "wb");
    if(fd_output_mat == 0)
    begin
        $display("$open output mat file failed") ;
        $stop;
    end
end

integer counter;
integer pos;
integer test;

initial begin
    counter=0; pos=0; test=0;
    
    //start testing configure procedure
    #1
    rst=0;
    cfg=1;
    wr_huff=1;
    wr_shuff=0;
    
    for (integer i=0; i<4; i=i+1)
    begin
        wr_sel=0;
        for (integer j=0; j<16; j=j+1)
        begin
            wr_huff_size<=code[pos];
            wr_huff_code<=0;
            pos<=pos+1;
            counter<=counter+code[pos];
            #2;
        end
        wr_huff_size<=0;
        wr_huff_code<=0;
        #2
        wr_sel=1;
        for (integer j=0; j<counter; j=j+1)
        begin
            wr_huff_size<=0;
            wr_huff_code<=code[pos];
            pos<=pos+1;
            if (j == counter - 1) 
            begin
                counter=0;
            end
            #2;
        end
    end
    wr_huff_size = 0;
    wr_huff_code = 0;

    wr_huff=0;
    wr_sel=1;
    wr_map_mode=`SAMP_420;
    
    #2;
    wr_sel=0;
    wr_map_mode=`SAMP_420;
    
    #2;
    wr_map_mode=0;
    wr_shuff=1;
    for(integer i=0; i<64; i++)
    begin
        wr_quan_tb <= quan[i];
        #2;
    end
    
    #2;
    cfg=0;
    wr_shuff=0;
    //starting testing decoding procedure
    
    for(integer i=0; i<68*120*6; i++)
    begin
        #12;
        $fwrite(fd_output, "(%x, %x);\n", zero, len);
        test++;
        
        for(integer j=1; j<64; j++)
        begin
            #12;
            if(zero == 0 && len == 0)
            begin
                $fwrite(fd_output, "(0, 0);\n");
                break;
            end
            j += zero;
            $fwrite(fd_output, "(%x, %x);\n", zero, len);
            test++;
        end
    end
    
    #128;
    
    rst=1;
    #2;
    
    //end testing.
    $stop;
    
end

reg test_begin;

initial test_begin = 0;
always @(posedge clk)
begin
    if (notify) 
    begin
        shuf_rd_addr <= 0;
        //$fwrite(fd_output_mat, "\n");
    end else
    begin
        if (shuf_rd_addr < 8) shuf_rd_addr <= shuf_rd_addr + 1;
    end
    if (shuf_rd_addr == 0) test_begin <= 1;
    if (shuf_rd_addr == 8) test_begin <= 0;
    //if (shuf_rd_addr == 1)
        //$fwrite(fd_output_mat, "%x\n", shuf_rd_data[15:0]);
    if (test_begin)
        $fwrite(fd_output_mat, "%x %x %x %x %x %x %x %x\n"
            ,shuf_rd_data[15:0], shuf_rd_data[31:16], shuf_rd_data[47:32], shuf_rd_data[63:48]
            ,shuf_rd_data[79:64], shuf_rd_data[95:80], shuf_rd_data[111:96], shuf_rd_data[127:112]);
end

endmodule
