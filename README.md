# RISC-V SNAKE
Snake clone programmed in RISC-V assembly for the linux terminal

### Compilation Specifications
I programmed and compiled this on Ubuntu 22.04.3 LTS using QEMU. While this project should be compatible with other distros and RISC-V emulators, I have not tested them.

### Project Purpose
This project was created in a weekend to apply the knowledge I learned in my Computer Organization & Assembly class. This was quite out of scope for the class and was not created for class credit but more as a challenge to myself.

### What I Learned
This project forced me to understand how many parts of the linux terminal function. The game runs at a locked refresh rate and a "frame" is displayed every 0.15 s. To get the input each frame without echoing or triggering an input wait interrupt I used a combination of linux system calls to set and restore terminal flags (O_ECHO & O_NONBLOCK). This combined with the 0.15 s sleep between frames allowed me to create a real-time gameloop. Each gameframe is constructed line by line and pushed onto the stack, when each line is on the stack, I output the whole screen at once. Overall I think this project was an interesting challenge and I'm glad I took it on. If you would like to look through the source code, I have done my best to comment the syscalls and some game logic.
