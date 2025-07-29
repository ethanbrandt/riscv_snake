snake: snake.o
	riscv64-linux-gnu-ld snake.o itoa.o -o snake
snake.o: snake.s
	riscv64-linux-gnu-as snake.s -o snake.o