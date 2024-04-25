#include <stdio.h>

#define clamp(x) (x) > 0 ? ((x) < 255 ? (x) : 255) : 0

void yuv2rgb(unsigned char* rgb, unsigned char y, unsigned char u, unsigned char v) {
	rgb[2] = clamp(y + 1.370705 * (v - 128.0)                         );
	rgb[1] = clamp(y - 0.698001 * (v - 128.0) - 0.337633 * (u - 128.0));
	rgb[0] = clamp(y + 1.732446 * (u - 128.0)                         );
//	rgb[2] = v;
//	rgb[1] = v;
//	rgb[0] = v;
}

int main(){
        FILE *fdst = fopen("yuv.bmp","wb+");
	const unsigned char header[] = {0x42, 0x4D, 0x36, 0xEC, 0x5E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x80, 0x07, 0x00, 0x00, 0x38, 0x04, 0x00, 0x00, 0x01, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEC, 0x5E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
	fwrite(header, 1, sizeof(header), fdst);
	for (int y0 = 1079; y0 >= 0; y0--) {
		for (int x0 = 0; x0 < 1920; x0++) {
			unsigned char rgb[3];
			int pos = x0 & 255;
			int id = (y0 >> 8) & 3;
			unsigned char y = ((id == 0) || (id == 3)) ? pos : 0;
			unsigned char u = ((id == 1) || (id == 3)) ? pos : 0;
			unsigned char v = ((id == 2) || (id == 3)) ? pos : 0;
			yuv2rgb(rgb, y, u, v);
			fwrite(&rgb, sizeof(unsigned char), 3, fdst);
		}
	}
	fclose(fdst);
	return 0;
}
