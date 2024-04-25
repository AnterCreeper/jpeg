#include <stdio.h>
#include <stdint.h>
#include <math.h>

#define PI 3.1415926536

int main(){
	int16_t mat[8][8];
	for (int i = 0; i < 8; i++)
	for (int j = 0; j < 8; j++) {
		double a = 0;
		if(i) a = sqrt((double)0.25);
		else a = sqrt((double)0.125);
		a = a*cos((j+0.5)*PI*i/8)*32768;
		if (a > 32767) printf("Out of Range!\n");
		mat[i][j] = a;
	}
	FILE* fd = fopen("dct.txt" ,"w");
	for(int i = 0; i < 64; i++) fprintf(fd, "%x ", mat[i >> 3][i & 7]);
	fclose(fd);
	return 0;
}
