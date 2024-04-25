module Trans_map(
    input[127:0] data_in[14:0],
    output[127:0] data_out[14:0]
);

always @(*)
begin
    data_out[0] <= data_in[0];
    
    data_out[1] <= {data_in[1][127:32],
    data_in[1][15:0], data_in[1][31:16]};
    
    data_out[2] <= {data_in[2][127:48],
    data_in[2][15:0], data_in[2][31:16], data_in[2][47:32]};
    
    data_out[3] <= {data_in[3][127:64],
    data_in[3][15:0], data_in[3][31:16], data_in[3][47:32], data_in[3][63:48]};
    
    data_out[4] <= {data_in[4][127:80],
    data_in[4][15:0], data_in[4][31:16], data_in[4][47:32], data_in[4][63:48],
    data_in[4][79:64]};
    
    data_out[5] <= {data_in[5][127:96],
    data_in[5][15:0], data_in[5][31:16], data_in[5][47:32], data_in[5][63:48],
    data_in[5][79:64], data_in[5][95:80]};
    
    data_out[6] <= {data_in[6][127:112],
    data_in[6][15:0], data_in[6][31:16], data_in[6][47:32], data_in[6][63:48],
    data_in[6][79:64], data_in[6][95:80], data_in[6][111:96]};
    
    data_out[7] <= {data_in[7][15:0], data_in[7][31:16], data_in[7][47:32], data_in[7][63:48],
    data_in[7][79:64], data_in[7][95:80], data_in[7][111:96], data_in[7][127:112]};
    
    data_out[8] <= {data_in[8][31:16], data_in[8][47:32], data_in[8][63:48], data_in[8][79:64],
    data_in[8][95:80], data_in[8][111:96], data_in[8][127:112],
    data_in[8][15:0]};
    
    data_out[9] <= {data_in[9][47:32], data_in[9][63:48], data_in[9][79:64], data_in[9][95:80],
    data_in[9][111:96], data_in[9][127:112],
    data_in[9][31:0]};
    
    data_out[10] <= {data_in[10][63:48], data_in[10][79:64], data_in[10][95:80], data_in[10][111:96],
    data_in[10][127:112],
    data_in[10][47:0]};
    
    data_out[11] <= {data_in[11][79:64], data_in[11][95:80], data_in[11][111:96], data_in[11][127:112],
    data_in[11][63:0]};
    
    data_out[12] <= {data_in[12][95:80], data_in[12][111:96], data_in[12][127:112],
    data_in[12][79:0]};
    
    data_out[13] <= {data_in[13][111:96], data_in[13][127:112],
    data_in[13][95:0]};
    
    data_out[14] <= data_in[14];
end
endmodule

