#include <stdio.h>
#include <stdint.h>

int16_t dct_mat[8][8] = {
    {0x2d41, 0x2d41, 0x2d41, 0x2d41, 0x2d41, 0x2d41, 0x2d41, 0x2d41},
    {0x3ec5, 0x3536, 0x238e, 0x0c7c, 0xf384, 0xdc72, 0xcaca, 0xc13b},
    {0x3b20, 0x187d, 0xe783, 0xc4e0, 0xc4e0, 0xe783, 0x187d, 0x3b20},
    {0x3536, 0xf384, 0xc13b, 0xdc72, 0x238e, 0x3ec5, 0x0c7c, 0xcaca},
    {0x2d41, 0xd2bf, 0xd2bf, 0x2d41, 0x2d41, 0xd2bf, 0xd2bf, 0x2d41},
    {0x238e, 0xc13b, 0x0c7c, 0x3536, 0xcaca, 0xf384, 0x3ec5, 0xdc72},
    {0x187d, 0xc4e0, 0x3b20, 0xe783, 0xe783, 0x3b20, 0xc4e0, 0x187d},
    {0x0c7c, 0xdc72, 0x3536, 0xc13b, 0x3ec5, 0xcaca, 0x238e, 0xf384}
};

#define clamp(x) (x) > 0 ? ((x) < 255 ? (x) : 255) : 0
unsigned char min = 128;
unsigned char max = 128;

void idct(int16_t* block, unsigned char* output, int id){
	int32_t buf[8][8];
	for(int i = 0; i < 8; i++)
		for(int j = 0; j < 8; j++){
			buf[i][j] = block[j] * dct_mat[0][i];
			buf[i][j] += block[8+j] * dct_mat[1][i];
			buf[i][j] += block[16+j] * dct_mat[2][i];
			buf[i][j] += block[24+j] * dct_mat[3][i];
			buf[i][j] += block[32+j] * dct_mat[4][i];
			buf[i][j] += block[40+j] * dct_mat[5][i];
			buf[i][j] += block[48+j] * dct_mat[6][i];
			buf[i][j] += block[56+j] * dct_mat[7][i];
		}
	int16_t buf_1[8][8];
	for(int i = 0; i < 8; i++)
		for(int j = 0; j < 8; j++) buf_1[i][j] = buf[i][j] >> 15;

	int32_t buf_2[8][8];
	for(int i = 0; i < 8; i++)
		for(int j = 0; j < 8; j++){
			buf_2[i][j] = buf_1[i][0] * dct_mat[0][j];
			buf_2[i][j] += buf_1[i][1] * dct_mat[1][j];
			buf_2[i][j] += buf_1[i][2] * dct_mat[2][j];
			buf_2[i][j] += buf_1[i][3] * dct_mat[3][j];
			buf_2[i][j] += buf_1[i][4] * dct_mat[4][j];
			buf_2[i][j] += buf_1[i][5] * dct_mat[5][j];
			buf_2[i][j] += buf_1[i][6] * dct_mat[6][j];
			buf_2[i][j] += buf_1[i][7] * dct_mat[7][j];
		}
	for(int i = 0; i < 8; i++)
		for(int j = 0; j < 8; j++)
	{
	        int16_t tmp = buf_2[i][j] >> 15;
		output[8*i+j] = clamp(tmp + 128);
//(unsigned char)(clamp(tmp + 128));
// + 128);
		if(id < 4) {
			if (output[8*i+j] > max) max = output[8*i+j];
			if (output[8*i+j] < min) min = output[8*i+j];
		}
	}
	return;
}

// void preprocess(unsigned char* rgb, float y, float u, float v){
// 	rgb[2] = clamp((int)v);
// 	rgb[1] = clamp((int)u);
// 	rgb[0] = clamp((int)y);
// }

void serialize(unsigned char (*in)[64], unsigned char (*out)[192]){
	for(int y0 = 0; y0 < 16; y0++)
		for(int x0 = 0; x0 < 16; x0++)
	{
		int id = (x0 >> 3) + (y0 >> 3) * 2;
		int pos = (x0 & 7) + (y0 & 7) * 8;
		int pos_ = (x0 >> 1) + (y0 >> 1) * 8;
	        out[id][3*pos] = in[id][pos];
	        out[id][3*pos+1] = in[4][pos_];
	        out[id][3*pos+2] = in[5][pos_];
		//preprocess(&out[id][3*pos], in[id][pos], in[4][pos_], in[5][pos_]);
	}
	return;
}

int main(){
	unsigned char mem[68][120][4][64*3];
        FILE *fsrc = fopen("output.bin","rb+");
        FILE *fdst = fopen("output.bin.2","wb+");
        for (int y0 = 0; y0 < 68; y0++)
        for (int x0 = 0; x0 < 120; x0++) {
		unsigned char output[6][64];
		for (int i = 0; i < 6; i++) {
			int16_t block[64];
			fread(block, sizeof(int16_t), 64, fsrc);
			idct(block, output[i], i);
		}
		serialize(output, mem[y0][x0]);
	}
	for (int y0 = 1079; y0 >= 0; y0--) {
		for (int x0 = 0; x0 < 1920; x0++) {
			int block = ((x0 >> 3) & 1) + ((y0 >> 3) & 1) * 2;
			int id = (x0 & 7) + (y0 & 7) * 8;
			fwrite(&mem[y0 >> 4][x0 >> 4][block][3 * id], sizeof(unsigned char), 3, fdst);
		}
	}
	printf("min=%x max=%x\n", min, max);
	fclose(fsrc);
	fclose(fdst);
	return 0;
}
