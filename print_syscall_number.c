#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>

int main(void) {
	printf("%d\n", open(".", O_DIRECTORY, 511));
	printf("%d\n", O_DIRECTORY);
}
