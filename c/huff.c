#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>

const unsigned char dc_entry0[] = {0, 2, 3, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
const unsigned char dc_data0[] = {0x00, 0x01, 0x04, 0x03, 0x02, 0x05, 0x06, 0x07};

const unsigned char dc_entry1[] = {1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0};
const unsigned char dc_data1[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};

const unsigned char ac_entry0[] = {0, 2, 2, 2, 1, 4, 1, 4, 2, 3, 0, 2, 1, 3, 2, 7};
const unsigned char ac_data0[] = {0x00, 0x01, 0x03, 0x02, 0x11, 0x12, 0x04, 0x31, 0x05, 0x21, 0x41, 0x51, 0x13, 0x61, 0x32, 0x71, 0x22, 0x06, 0x91, 0x52, 0x42, 0x92, 0x72, 0x07, 0xC1, 0xB2, 0xD1, 0xA1, 0x53, 0x83, 0x33, 0x73, 0xB1, 0x81, 0x82, 0xF0};

const unsigned char ac_entry1[] = {1, 1, 1, 1, 1, 0, 1, 3, 3, 4, 2, 2, 2, 1, 5, 1};
const unsigned char ac_data1[] = {0x00, 0x01, 0x02, 0x11, 0x03, 0x04, 0x31, 0x41, 0x32, 0x61, 0x51, 0x05, 0x71, 0x81, 0x91, 0x52, 0xB1, 0xA1, 0x33, 0x62, 0xC1, 0xE1, 0xB2, 0x34, 0x72, 0xE2, 0xA2, 0x13, 0x42};

const unsigned char quan_tb[] = {0x08, 0x06, 0x06, 0x07, 0x06, 0x07, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x09, 0x09, 0x09, 0x0A, 0x0A, 0x0A, 0x09, 0x09, 0x09, 0x09, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0C, 0x0C, 0x0C, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0E, 0x0D, 0x0D, 0x0D, 0x0C, 0x0D, 0x0E, 0x0E, 0x0F, 0x0F, 0x0F, 0x12, 0x12, 0x11, 0x11, 0x15, 0x15, 0x15, 0x19, 0x19, 0x1F};

const unsigned char zigzag[] = {0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63};

struct dht_tb {
	int bit;
	int data; //compressed
	unsigned char value; //decompressed
};

struct dht_tb_p {
	int count;
	struct dht_tb *table;
};

void dht_gen(const char* entry, const char* data, struct dht_tb_p* output) {
	output->count = 0;
	for (int i = 0; i < 16; i++) output->count += entry[i];
	output->table = malloc(output->count * sizeof(struct dht_tb));

	int p = 0, huff = 0;
	for (int i = 0; i < 16; i++) {
		for (int j = 0; j < entry[i]; j++) {
			output->table[p].bit = i + 1;
			output->table[p].data = huff;
			output->table[p].value = data[p];
			//printf("bit:%x, data:%x, value:%x\n", output->table[p].bit, output->table[p].data, output->table[p].value);
			p++; huff++;
		}
		huff <<= 1;
	}
	return;
}

FILE* buf_fd;
unsigned int buf_ping = 0;
unsigned int buf_pong = 0;
int left_bit = 0;

void query_init(FILE* fd){
	buf_fd = fd;
	fread(&buf_ping, sizeof(unsigned int), 1, buf_fd);
	buf_ping = htonl(buf_ping);
}

void query_move(int length){
//	printf("now_ping:%x, now_pong:%x\n", buf_ping, buf_pong);
//	printf("now_ping:%x ", buf_ping);
//	printf("move:%x\n", length);
//	printf("now_left_bit:%x\n", left_bit);
	if (length == 0) return;
	buf_ping <<= length;
	buf_ping |= (buf_pong & (0xFFFFFFFF << (32 - length))) >> (32 - length);
	buf_pong <<= length;
	left_bit = left_bit - length;
	if (left_bit <= 0) {
		if (feof(buf_fd)) {
			printf("FIXME: End of File!\n");
			exit(-1);
		}
		fread(&buf_pong, sizeof(unsigned int), 1, buf_fd);
//		printf("fread 4 bytes:%x\n", buf_pong);
		buf_pong = htonl(buf_pong);
		left_bit += 32;
		if (left_bit == 32) return;
		buf_ping |= (buf_pong & (0xFFFFFFFF << left_bit)) >> left_bit;
		buf_pong <<= 32 - left_bit;
	}
}

unsigned int query_fetch(int length) {
	if (length == 0) return 0;
	return buf_ping >> (32 - length);
}

unsigned int decode_huffman(struct dht_tb_p *tb){
	for (int i = 0; i < tb->count; i++) {
		if (query_fetch(tb->table[i].bit) == tb->table[i].data) {
			query_move(tb->table[i].bit);
//			printf("bit:%x, from:%x, to:%x\n", tb->table[i].bit, tb->table[i].data, tb->table[i].value);
			return tb->table[i].value;
		}
	}
	printf("FIXME! Not founded in Huffman Table!\n");
	printf("FIXME! buf_ping:%x\n", buf_ping);
	exit(-1);
	return 0;
}

int16_t decode_data(int length) {
	unsigned int result = query_fetch(length);
	int sign = length == 0 ? 1 : result & (1 << (length - 1)); //0 is negative and 1 is positive
	unsigned int result_d = result | ((sign ? 0x00000000 : 0xFFFFFFFF) << length);
	result_d = result_d + (sign ? 0 : 1);
	//printf("data_raw:%x data_len:%x data_decoded:%x\n", result, length, result_d);
	query_move(length);
	return (int16_t)result_d;
}

int main(){
	int test = 0;
	FILE *fsrc = fopen("test.raw","rb+");
	FILE *fdst = fopen("output.bin","wb+");
	FILE *fdst2 = fopen("output.test.txt","w+");

//	printf("DEBUG: DHT Table:\n");
	struct dht_tb_p table[4];
	dht_gen(dc_entry0, dc_data0, &table[0]);
	dht_gen(dc_entry1, dc_data1, &table[1]);
	dht_gen(ac_entry0, ac_data0, &table[2]);
	dht_gen(ac_entry1, ac_data1, &table[3]);

	query_init(fsrc);

//	printf("DEBUG: Start Decoding:\n");
//	int16_t lastDC[3] = {0, 0, 0};
	int16_t lastDC[6] = {0, 0, 0, 0, 0, 0};

	for (int y0 = 0; y0 < 68; y0++)
	for (int x0 = 0; x0 < 120; x0++) {
		const int pack[] = {0, 2, 0, 2, 0, 2, 0, 2, 1, 3, 1, 3};
//		const int pack[] = {0, 2, 1, 3, 1, 3};
//		printf("y0:%d, x0:%d\n", y0, x0);
		for (int i = 0; i < 6; i++) {
			int16_t block[64];
			memset(block, 0, 64 * sizeof(int16_t));

//			printf("DC%d:\n", i);
//			printf("Use table: %d %d\n", pack[2*i], pack[2*i+1]);
			int result = decode_huffman(&table[pack[2 * i]]);
			int zero = result >> 4;
			int length = result & 0xF;

			test++;
//			printf("(%x, %x);\n", zero, length);

			int16_t *last = &lastDC[i < 4 ? 0 : i - 3];
//			int16_t *last = &lastDC[i];
			*last = *last + decode_data(length);
			block[0] = *last * quan_tb[0];

//			printf("%x\n", block[0]);

			for (int j = 1; j < 64; j++) {
				result = decode_huffman(&table[pack[2 * i + 1]]);
				if (result == 0) {
//					printf("(%x, %x);\n", 0, 0);
//					printf("EOB.\n");
					break; //EOB
				}
				zero = result >> 4;
				length = result & 0xF;
//				printf("(%x, %x);\n", zero, length);
				test++;

				j += zero;
				if (j >= 64) {
					printf("FIXME! too many zero!\n");
					exit(-1);
				}
				int16_t data_tmp = decode_data(length);
				block[zigzag[j]] = data_tmp * quan_tb[zigzag[j]];
			}
			fwrite(&block, sizeof(int16_t), 64, fdst);
//			for (int i = 0; i < 8; i++) fprintf(fdst2, "%x %x %x %x %x %x %x %x\n",
//				block[8*i], block[8*i+1], block[8*i+2], block[8*i+3],
//				block[8*i+4], block[8*i+5], block[8*i+6], block[8*i+7]);
//			fprintf(fdst2, "\n");
		}
	}
	fclose(fsrc);
	fclose(fdst);
	fclose(fdst2);
	printf("test:%x\n", test);
	return 0;
}
